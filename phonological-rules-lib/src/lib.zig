const std = @import("std");
const builtin = @import("builtin");
const cmnFtr = @import("sounds/ph_features.zig").commonFeatures;
const StrArray = @import("sounds/ph_features.zig").StrArray;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const a: std.mem.Allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

export fn commonFeatures(input: [*:0]const u8) [*:0]const u8 {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}
    var result: StrArray = cmnFtr(a, input[0..len]) catch unreachable;
    defer result.deinit();

    result.append(0) catch unreachable;
    const str: [*:0]const u8 = @ptrCast(result.items);

    return str;
}

test "new string" {
    _ = commonFeatures("abc");
}
