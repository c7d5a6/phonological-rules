const std = @import("std");
const context = @import("../middle/context.zig");
const Application = context.Application;
const Context = context.Context;
const header = @import("../middle/header.zig");
const httpStatus = @import("router-errors.zig").httpStatus;
const features = @import("../services/features.zig");
const common = @import("../services/common.zig");
const rule = @import("../services/rules.zig");

pub const on_error: Application.ErrorHandler = onError;

/// Register all routes. Baz picks the most specific path, answers 404/405,
/// OPTIONS and HEAD itself.
pub fn register(app: *Application) !void {
    try app.route("GET", "/api/hello", hello);
    try app.route("GET", "/api/version", common.on_version);
    // -- Features
    try app.route("POST", "/api/features/common", features.on_common_features);
    // -- Rules
    try app.route("POST", "/api/rules/apply", rule.on_apply_rule);
}

fn hello(ctx: *Context) !void {
    return ctx.response.bytes(200, "text/html", "<html><body><h1>Hello from Baz!!!</h1></body></html>");
}

fn onError(ctx: *Context, err: anyerror) !void {
    std.log.info("request failed: {s}", .{@errorName(err)});
    try header.addHeaders(ctx);
    return ctx.response.text(httpStatus(err), @errorName(err));
}

test {
    _ = @import("params.zig");
}
