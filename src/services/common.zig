const std = @import("std");
const Context = @import("../middle/context.zig").Context;

extern fn version() [*:0]const u8;

pub fn on_version(ctx: *Context) !void {
    return ctx.response.jsonValue(200, .{ .version = std.mem.span(version()) });
}
