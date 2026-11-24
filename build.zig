const std = @import("std");
const Config = @import("src/build/Config.zig");

pub fn build(b: *std.Build) !void {
    // --- Version (git tag / branch+hash, or -Dversion-string=)
    const cfg = try Config.init(b);
    const version = try b.allocator.dupeSentinel(u8, b.fmt("{f}", .{cfg.version}), 0);
    const lib_semver: std.SemanticVersion = .{
        .major = cfg.version.major,
        .minor = cfg.version.minor,
        .patch = cfg.version.patch,
    };

    // --- Options
    const options = b.addOptions();
    options.addOption([:0]const u8, "version", version);
    const build_service = b.option(
        bool,
        "service",
        "Build the Baz HTTP service (-Dservice=false for library only; Baz needs exactly Zig 0.17.0)",
    ) orelse true;

    // --- Build
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Modules
    const lib_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/lib.zig"),
    });

    // --- Lib Module
    const lib_ph = b.addLibrary(.{
        .name = "ph_lib",
        .root_module = lib_module,
        .linkage = .dynamic,
        .version = lib_semver,
    });
    lib_ph.root_module.addOptions("config", options);
    // lib_ph.linkLibC();
    b.installArtifact(lib_ph);

    // Test
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,
        // Zig 0.16 Debug self-hosted --fuzz has empty coverage PCs and panics
        // in std.Build.Fuzz.addEntryPoint. LLVM populates the PC table.
        .use_llvm = true,
    });
    lib_unit_tests.root_module.addOptions("config", options);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // --- Steps
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const profile_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("scripts/profile.zig"),
        .imports = &.{
            .{ .name = "ph", .module = lib_module },
        },
    });
    const profile_exe = b.addExecutable(.{
        .name = "ph_profile",
        .root_module = profile_mod,
    });
    b.installArtifact(profile_exe);
    const profile_run = b.addRunArtifact(profile_exe);
    const profile_step = b.step("profile", "Time library parse, match, and apply");
    profile_step.dependOn(&profile_run.step);

    if (build_service) try buildService(b, target, optimize, lib_ph);
}

fn buildService(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    lib_ph: *std.Build.Step.Compile,
) !void {
    const baz = b.dependency("baz", .{ .target = target, .optimize = optimize });
    const backend_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
        // Baz itself needs no libc, but the shared ph_lib loads against it.
        .link_libc = true,
        .imports = &.{
            .{ .name = "baz", .module = baz.module("baz") },
        },
    });

    // --- Backend Module
    const backend = b.addExecutable(.{
        .name = "phonological-rules-backend",
        .root_module = backend_module,
    });
    // PH
    // Keep the shared lib reachable next to the binary (`zig-out/lib`, `./libs`).
    backend.root_module.addRPathSpecial("$ORIGIN/../lib");
    backend.root_module.addRPathSpecial("$ORIGIN/libs");
    backend.root_module.linkLibrary(lib_ph);
    b.installArtifact(backend);

    // --- Steps
    const run_cmd = b.addRunArtifact(backend);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Service-side unit tests (route params)
    const service_tests = b.addTest(.{ .root_module = backend_module });
    const service_test_step = b.step("test-service", "Run HTTP service unit tests");
    service_test_step.dependOn(&b.addRunArtifact(service_tests).step);
}
