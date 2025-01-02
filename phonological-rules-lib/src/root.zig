const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

const unicode = std.unicode;

test "print" {
    const temp = "t͡ɕ";
    const view = unicode.Utf8View.init(temp) catch unreachable;
    var it = view.iterator();
    std.debug.print("{x}\n", .{it.nextCodepoint().?});
    std.debug.print("{x}\n", .{it.nextCodepoint().?});
    std.debug.print("{x}\n", .{it.nextCodepoint().?});
}
