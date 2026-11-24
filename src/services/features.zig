const std = @import("std");
const Context = @import("../middle/context.zig").Context;

extern fn commonFeatures(input: [*:0]const u8) [*:0]const u8;
extern fn distinctiveFeatures(input: [*:0]const u8) [*:0]const u8;
extern fn destroyStr(input: [*:0]const u8) void;

pub fn on_common_features(ctx: *Context) !void {
    var arena = std.heap.ArenaAllocator.init(ctx.shared.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var body_buf: [4096]u8 = undefined;
    const body = try ctx.request.body().copyTo(&body_buf);
    if (!std.unicode.utf8ValidateSlice(body)) return error.InvalidUtf8;

    const req = try a.dupeSentinel(u8, body, 0);
    const res_cmn = commonFeatures(req);
    const res_dis = distinctiveFeatures(req);
    defer destroyStr(res_cmn);
    defer destroyStr(res_dis);

    return ctx.response.jsonValue(200, .{
        .common = std.mem.span(res_cmn),
        .distinctive = std.mem.span(res_dis),
    });
}
