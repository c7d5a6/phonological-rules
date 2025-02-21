const std = @import("std");
const Allocator = std.mem.Allocator;
const zap = @import("zap");
const Request = zap.Request;
const Context = @import("../middle/context.zig").Context;
const ControllerError = @import("../routes/router-errors.zig").ControllerError;

extern fn version() [*:0]const u8;

const Version = struct {
    version: []const u8,
};

pub fn on_version(a: Allocator, r: Request, c: *Context, params: anytype) ControllerError!void {
    _ = params;
    _ = c;

    const ver = version();
    var len: u64 = 0;
    while (ver[len] != 0) : (len += 1) {}
    std.debug.print("\n\tRES[{d}]: {any}\n", .{ len, &ver });
    const json = std.json.stringifyAlloc(
        a,
        Version{ .version = ver[0..len] },
        .{ .escape_unicode = true, .emit_null_optional_fields = false },
    ) catch unreachable;
    std.debug.print("\n\tJSON: {s}\n", .{json});
    defer a.free(json);
    r.setContentType(.JSON) catch return;
    r.sendJson(json) catch return;
}
