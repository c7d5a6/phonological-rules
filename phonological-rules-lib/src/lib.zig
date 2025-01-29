const std = @import("std");
const builtin = @import("builtin");
const cmnFtr = @import("sounds/ph_features.zig").commonFeatures;
const dstFtr = @import("sounds/ph_features.zig").distinctiveFeatures;
const StrArray = @import("sounds/ph_features.zig").StrArray;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const a: std.mem.Allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.mode == .Debug) gpa.allocator() else gpa.allocator();

export fn commonFeatures(input: [*:0]const u8) [*:0]const u8 {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result: StrArray = cmnFtr(a, input[0..len]) catch unreachable;
    defer result.deinit();

    const ar = a.allocSentinel(u8, result.items.len, 0) catch unreachable;
    @memcpy(ar, result.items);

    const str: [*:0]const u8 = @ptrCast(ar);
    return str;
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

export fn destroyStr(input: [*:0]const u8) void {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}
    const array: []const u8 = input[0 .. len + 1];

    a.free(array);
}

export fn commonNumber(i: usize) usize {
    return i + 4;
}

test "new string" {
    _ = commonFeatures("abc");
}
