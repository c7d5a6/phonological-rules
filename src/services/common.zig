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
    var out: std.Io.Writer.Allocating = .init(a);
    defer out.deinit();
    std.json.Stringify.value(
        Version{ .version = ver[0..len] },
        .{ .escape_unicode = true, .emit_null_optional_fields = false },
        &out.writer,
    ) catch unreachable;
    const json = out.written();
    std.debug.print("\n\tJSON: {s}\n", .{json});
    r.setContentType(.JSON) catch return;
    r.sendJson(json) catch return;
}
