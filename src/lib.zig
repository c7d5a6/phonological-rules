const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const cmnFtr = @import("sounds/ph_features.zig").commonFeatures;
const dstFtr = @import("sounds/ph_features.zig").distinctiveFeatures;
const StrArray = @import("sounds/ph_features.zig").StrArray;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const a: std.mem.Allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.mode == .Debug) gpa.allocator() else gpa.allocator();

export fn version() [*:0]const u8 {
    const str: [*:0]const u8 = @ptrCast(config.version);
    return str;
}

const FeaturesResult = extern struct {
    features: [*:0]const u8,
    export fn destroy(self: FeaturesResult) void {
        destroyStr(self.features);
    }
};

export fn commonFeatures(input: [*:0]const u8) FeaturesResult {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result: StrArray = cmnFtr(a, input[0..len]) catch unreachable;
    defer result.deinit();

    const ar = a.allocSentinel(u8, result.items.len, 0) catch unreachable;
    @memcpy(ar, result.items);

    const str: [*:0]const u8 = @ptrCast(ar);
    return .{ .features = str };
}

export fn distinctiveFeatures(input: [*:0]const u8) [*:0]const u8 {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result: StrArray = dstFtr(a, input[0..len]) catch unreachable;
    defer result.deinit();

    const ar = a.allocSentinel(u8, result.items.len, 0) catch unreachable;
    @memcpy(ar, result.items);

    const str: [*:0]const u8 = @ptrCast(ar);
    return str;
}

fn destroyStr(input: [*:0]const u8) void {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}
    const array: []const u8 = input[0 .. len + 1];

    a.free(array);
}

test "new string" {
    const res = commonFeatures("abc");
    defer destroyStr(res.features);
}

test "version" {
    // std.debug.print("* * * version {any}", .{config.version});
}
