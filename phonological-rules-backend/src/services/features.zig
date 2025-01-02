const std = @import("std");
const Allocator = std.mem.Allocator;
const zap = @import("zap");
const Request = zap.Request;
const Context = @import("../middle/context.zig").Context;
const ControllerError = @import("../routes/router-errors.zig").ControllerError;

extern fn commonFeatures(input: [*:0]const u8) [*:0]const u8;
extern fn destroyCommonFeatures(input: [*:0]const u8) void;

const F = struct {
    features: []const u8,
};

pub fn on_common_features(a: Allocator, r: Request, c: *Context, params: anytype) ControllerError!void {
    _ = params;
    _ = c;
    if (r.body) |body| {
        std.debug.print("\n\tBody: {s}\n", .{body});
        const req = a.allocSentinel(u8, body.len, 0) catch unreachable;
        defer a.free(req);
        @memcpy(req[0..body.len], body);
        std.debug.print("\n\tREQ[{d}]: {s}\n", .{ body.len, req });
        const res_p = commonFeatures(req);
        defer destroyCommonFeatures(res_p);
        var len: u64 = 0;
        while (res_p[len] != 0) : (len += 1) {}
        // const res = res_p[0..len];
        std.debug.print("\n\tRES[{d}]: {any}\n", .{ len, &res_p });
        const json = std.json.stringifyAlloc(a, F{ .features = res_p[0..len] }, .{ .escape_unicode = false, .emit_null_optional_fields = false }) catch unreachable;
        std.debug.print("\n\tJSON: {s}\n", .{json});
        a.free(json);
        r.setContentType(.JSON) catch return;
        r.sendJson(json) catch return;
    }
}
