const context = @import("context.zig");
const Application = context.Application;
const Context = context.Context;

/// Global middleware: CORS and cache headers on every response.
/// Baz itself answers `OPTIONS` (with `Allow`) and 404/405.
pub const middleware: Application.Middleware = .{ .before = before };

fn before(ctx: *Context) !Application.Decision {
    try addHeaders(ctx);
    return .continue_request;
}

/// Also called from `on_error`: Baz discards the draft (headers included)
/// when a handler fails, and browsers hide error bodies without CORS.
pub fn addHeaders(ctx: *Context) !void {
    try ctx.response.header("Access-Control-Allow-Origin", "*");
    try ctx.response.header("Access-Control-Allow-Methods", "GET, POST, DELETE, PATCH, OPTIONS");
    try ctx.response.header("Access-Control-Allow-Headers", "*");
    try ctx.response.header("Expires", "0");
}
