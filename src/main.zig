const std = @import("std");
const web = @import("baz");
const builtin = @import("builtin");
const routes = @import("routes/routes.zig");
const context = @import("middle/context.zig");
const header = @import("middle/header.zig");
const Application = context.Application;

const port = 3003;

pub const std_options: std.Options = .{
    .log_level = if (builtin.mode == .debug) .info else .err,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .auth, .level = if (builtin.mode == .debug) .info else .err },
    },
};

pub fn main(init: std.process.Init) !void {
    var shared: context.Shared = .{ .allocator = init.gpa };

    const app = try Application.init(.{
        .allocator = init.gpa,
        .io = init.io,
        .shared = &shared,
        .server = .{
            .port = port,
            .bind_address = .{ 0, 0, 0, 0 },
            .connections = 128,
            .shards = 1,
            .output_bytes = 96 * 1024,
        },
        // /api/rules/apply returns whole strings; the default 8 KiB is tight.
        .response = .{ .body_bytes = 32 * 1024 },
        .middleware = &.{header.middleware},
        .on_error = routes.on_error,
    });
    defer app.deinit();

    try routes.register(app);
    try app.start();
    std.log.info("Listening on 0.0.0.0:{d}", .{app.port()});
    try app.run();
}
