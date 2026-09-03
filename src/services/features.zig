const std = @import("std");
const Allocator = std.mem.Allocator;
const zap = @import("zap");
const Request = zap.Request;
const Context = @import("../middle/context.zig").Context;
const ControllerError = @import("../routes/router-errors.zig").ControllerError;

extern fn commonFeatures(input: [*:0]const u8) [*:0]const u8;
extern fn distinctiveFeatures(input: [*:0]const u8) [*:0]const u8;
extern fn destroyStr(input: [*:0]const u8) void;

const F = struct {
    common: []const u8,
    distinctive: []const u8,
};

pub fn on_common_features(a: Allocator, r: Request, c: *Context, params: anytype) ControllerError!void {
    _ = params;
    _ = c;
    r.parseBody() catch return error.InternalError;
    const body = r.body orelse return error.InternalError;
    if (!std.unicode.utf8ValidateSlice(body)) {
        r.sendError(error.InvalidUtf8, null, 400);
        return;
    }
    std.debug.print("\n\tBody: {s}\n", .{body});
    const req = a.allocSentinel(u8, body.len, 0) catch unreachable;
    defer a.free(req);
    @memcpy(req[0..body.len], body);
    std.debug.print("\n\tREQ[{d}]: {s}\n", .{ body.len, req });
    const res_cmn = commonFeatures(req);
    const res_dis = distinctiveFeatures(req);
    defer destroyStr(res_cmn);
    defer destroyStr(res_dis);
    var len_cmn: u64 = 0;
    while (res_cmn[len_cmn] != 0) : (len_cmn += 1) {}
    var len_dis: u64 = 0;
    while (res_dis[len_dis] != 0) : (len_dis += 1) {}
    std.debug.print("\n\tRES[{d}]: {any}\n", .{ len_cmn, &res_cmn });
    std.debug.print("\n\tRES[{d}]: {any}\n", .{ len_dis, &res_dis });
    var out: std.Io.Writer.Allocating = .init(a);
    defer out.deinit();
    std.json.Stringify.value(
        F{ .common = res_cmn[0..len_cmn], .distinctive = res_dis[0..len_dis] },
        .{ .escape_unicode = true, .emit_null_optional_fields = false },
        &out.writer,
    ) catch unreachable;
    const json = out.written();
    std.debug.print("\n\tJSON: {s}\n", .{json});
    r.setContentType(.JSON) catch return;
    r.sendJson(json) catch return;
}
