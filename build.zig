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
    // The zap-based service does not build on Zig 0.17 (zap is archived and
    // removed from build.zig.zon). See docs/zap-to-baz.md.
    const build_service = b.option(
        bool,
        "service",
        "Build the zap HTTP service (not yet Zig 0.17 compatible, see docs/zap-to-baz.md)",
    ) orelse false;

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
    // --- Modules
    const regez_c = b.addTranslateC(.{
        .root_source_file = b.path("c-src/regez_translate.h"),
        .target = target,
        .optimize = optimize,
    });
    regez_c.addIncludePath(b.path("c-src"));
    const backend_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "regez", .module = regez_c.createModule() },
        },
    });
    const regez_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    regez_module.addIncludePath(b.path("c-src"));
    regez_module.addCSourceFiles(.{
        .files = &.{"c-src/regez.c"},
    });

    // --- Backend Module
    const backend = b.addExecutable(.{
        .name = "phonological-rules-backend",
        .root_module = backend_module,
    });
    const libC = b.addLibrary(.{ .name = "regez", .linkage = .static, .root_module = regez_module });
    configureArtifact(b, backend, libC);
    // ZAP
    // Fails with "no dependency named 'zap'" until zap/Baz is back in build.zig.zon.
    const zap = try b.dependencyLazy("zap", .{
        .target = target,
        .optimize = optimize,
    });
    backend.root_module.addImport("zap", zap.module("zap"));
    const facil = zap.artifact("facil.io");
    backend.root_module.linkLibrary(facil);
    // Ship facil.io with the backend and make the runtime loader look next to
    // the deployed binary, instead of the build machine's `.zig-cache` path.
    b.installArtifact(facil);
    // Support both local `zig-out/bin` execution (`../lib`) and your deployed
    // layout (`./libs`).
    backend.root_module.addRPathSpecial("$ORIGIN/../lib");
    backend.root_module.addRPathSpecial("$ORIGIN/libs");
    // PH
    // backend.addLibraryPath(b.path("libs"));
    backend.root_module.linkLibrary(lib_ph);
    b.installArtifact(backend);

    // --- Steps
    const run_cmd = b.addRunArtifact(backend);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn configureArtifact(b: *std.Build, artifact: *std.Build.Step.Compile, libC: *std.Build.Step.Compile) void {
    artifact.root_module.linkLibrary(libC);
    artifact.root_module.addIncludePath(b.path("c-src"));
    artifact.root_module.link_libc = true;
}
