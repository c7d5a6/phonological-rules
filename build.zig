const std = @import("std");

const lib_version: std.SemanticVersion = .{ .major = 0, .minor = 1, .patch = 0 };
// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Version
    const opt_version_string = b.option([]const u8, "version-string", "Override Lib version string. Default is to find out with git.");
    const version_slice = if (opt_version_string) |version| version else "0.1.0";
    const version = try b.allocator.dupeZ(u8, version_slice);
    const semver = try std.SemanticVersion.parse(version);
    // std.debug.print("Version {s}\nSemantic {any}", .{ version, semver });

    // Options
    const options = b.addOptions();
    options.addOption([:0]const u8, "version", version);

    // Build
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_ph = b.addSharedLibrary(.{
        .name = "ph_lib",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .version = semver,
    });
    lib_ph.root_module.addOptions("config", options);
    b.installArtifact(lib_ph);

    //
    // Backend artifact
    //
    const backend = b.addExecutable(.{
        .name = "phonological-rules-backend",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const libC = b.addStaticLibrary(.{
        .name = "regez",
        .optimize = .Debug,
        .target = target,
    });
    //
    // Regez
    libC.addIncludePath(b.path("c-src"));
    libC.addCSourceFiles(.{
        .files = &.{"c-src/regez.c"},
    });
    libC.linkLibC();
    backend.linkLibrary(libC);
    backend.addIncludePath(b.path("c-src"));
    backend.linkLibC();
    b.installArtifact(backend);
    //
    // ZAP
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
    });
    backend.root_module.addImport("zap", zap.module("zap"));
    backend.linkLibrary(zap.artifact("facil.io"));
    //
    // PH
    backend.addLibraryPath(b.path("libs"));
    backend.linkSystemLibrary("ph_lib");

    const run_cmd = b.addRunArtifact(backend);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //
    // Tests
    //
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addOptions("config", options);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
