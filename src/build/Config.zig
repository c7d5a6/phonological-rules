/// Build configuration. This is the configuration that is populated during `zig build`.
const Config = @This();

const std = @import("std");
const GitVersion = @import("GitVersion.zig");

/// The version of the next release.
///
/// TODO: When Zig 0.14 is released, derive this from build.zig.zon directly.
/// Until then this MUST match build.zig.zon and should always be the
/// _next_ version to release.
const app_version: std.SemanticVersion = .{ .major = 0, .minor = 2, .patch = 0 };

version: std.SemanticVersion = .{ .major = 0, .minor = 0, .patch = 0 },

pub fn init(b: *std.Build) !Config {
    var config: Config = .{};

    //---------------------------------------------------------------
    // Version

    const version_string = b.option(
        []const u8,
        "version-string",
        "A specific version string to use for the build. " ++
            "If not specified, git will be used. This must be a semantic version.",
    );

    config.version = if (version_string) |v|
        // If an explicit version is given, we always use it.
        try std.SemanticVersion.parse(v)
    else version: {
        const vsn = GitVersion.detect(b) catch |err| switch (err) {
            // If Git isn't available we just make an unknown dev version.
            error.GitNotFound,
            error.GitNotRepository,
            => break :version .{
                .major = app_version.major,
                .minor = app_version.minor,
                .patch = app_version.patch,
                .pre = "dev",
                .build = "0000000",
            },
            else => return err,
        };

        if (vsn.tag) |tag| {
            const expected = b.fmt("v{d}.{d}.{d}", .{
                app_version.major,
                app_version.minor,
                app_version.patch,
            });

            if (!std.mem.eql(u8, tag, expected)) {
                @panic("tagged releases must be in vX.Y.Z format matching build.zig");
            }

            break :version .{
                .major = app_version.major,
                .minor = app_version.minor,
                .patch = app_version.patch,
            };
        }
        break :version .{
            .major = app_version.major,
            .minor = app_version.minor,
            .patch = app_version.patch,
            .pre = vsn.branch,
            .build = vsn.short_hash,
        };
    };

    return config;
}
