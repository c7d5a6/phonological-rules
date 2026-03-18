const std = @import("std");

const lib_version: std.SemanticVersion = .{ .major = 0, .minor = 1, .patch = 0 };

pub fn build(b: *std.Build) !void {
    // --- Version
    const opt_version_string = b.option([]const u8, "version-string", "Override Lib version string. Default is to find out with git.");
    const version_slice = if (opt_version_string) |version| version else "0.1.0";
    const version = try b.allocator.dupeZ(u8, version_slice);
    const semver = try std.SemanticVersion.parse(version);

    // --- Options
    const options = b.addOptions();
    options.addOption([:0]const u8, "version", version);

    // --- Build
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Modules
    const lib_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/lib.zig"),
    });
    const backend_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    const regez_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });

    // --- Lib Module
    const lib_ph = b.addLibrary(.{
        .name = "ph_lib",
        .root_module = lib_module,
        .linkage = .dynamic,
        .version = semver,
    });
    lib_ph.root_module.addOptions("config", options);
    b.installArtifact(lib_ph);

    // Test
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_module,
    });
    lib_unit_tests.root_module.addOptions("config", options);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // --- Backend Module
    const backend = b.addExecutable(.{
        .name = "phonological-rules-backend",
        .root_module = backend_module,
    });
    const libC = b.addLibrary(.{
        .name = "regez",
        .linkage = .static,
        .root_module = regez_module
    });
    libC.addIncludePath(b.path("c-src"));
    libC.addCSourceFiles(.{
        .files = &.{"c-src/regez.c"},
    });
    libC.linkLibC();
    configureArtifact(b, backend, libC);
    // ZAP
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });
    backend.root_module.addImport("zap", zap.module("zap"));
    backend.linkLibrary(zap.artifact("facil.io"));
    // PH
    // backend.addLibraryPath(b.path("libs"));
    backend.linkLibrary(lib_ph);
    b.installArtifact(backend);

    // --- Steps
    const run_cmd = b.addRunArtifact(backend);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn configureArtifact(b: *std.Build, artifact: *std.Build.Step.Compile, libC: *std.Build.Step.Compile) void {
    artifact.linkLibrary(libC);
    artifact.addIncludePath(b.path("c-src"));
    artifact.linkLibC();
}
