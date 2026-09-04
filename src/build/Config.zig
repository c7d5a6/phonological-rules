/// Build configuration. This is the configuration that is populated during `zig build`.
const Config = @This();

const std = @import("std");
const GitVersion = @import("GitVersion.zig");

/// The version of the next release.
///
/// TODO: When Zig 0.14 is released, derive this from build.zig.zon directly.
/// Until then this MUST match build.zig.zon and should always be the
/// _next_ version to release.
const app_version: std.SemanticVersion = .{ .major = 0, .minor = 3, .patch = 0 };

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
            const dotted = b.fmt("{d}.{d}.{d}", .{
                app_version.major,
                app_version.minor,
                app_version.patch,
            });
            const expected_v = b.fmt("v{s}", .{dotted});
            if (!std.mem.eql(u8, tag, dotted) and !std.mem.eql(u8, tag, expected_v)) {
                @panic("tagged releases must be X.Y.Z or vX.Y.Z matching Config.zig app_version");
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
            .pre = sanitizePre(b, vsn.branch, vsn.changes),
            .build = vsn.short_hash,
        };
    };

    return config;
}

/// Semver pre-release identifiers may only use [0-9A-Za-z-].
fn sanitizePre(b: *std.Build, branch: []const u8, dirty: bool) []const u8 {
    const suffix: []const u8 = if (dirty) ".dirty" else "";
    const out = b.allocator.alloc(u8, branch.len + suffix.len) catch @panic("OOM");
    for (branch, 0..) |ch, i| {
        out[i] = switch (ch) {
            'A'...'Z', 'a'...'z', '0'...'9', '-' => ch,
            else => '-',
        };
    }
    if (suffix.len > 0) @memcpy(out[branch.len..], suffix);
    return out;
}
