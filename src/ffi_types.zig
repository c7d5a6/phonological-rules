const std = @import("std");
const Rule = @import("matchers/rule.zig").Rule;

pub const ResultRule = extern struct {
    is_error: bool,
    rule: ?*Rule,
};

pub const Result = extern struct {
    is_error: bool,
    result: ?[*:0]const u8,
};

test "ResultRule and Result use C layout" {
    try std.testing.expectEqual(0, @offsetOf(ResultRule, "is_error"));
    try std.testing.expectEqual(@sizeOf(*Rule), @offsetOf(ResultRule, "rule"));
    try std.testing.expectEqual(0, @offsetOf(Result, "is_error"));
    try std.testing.expectEqual(@sizeOf(?[*:0]const u8), @offsetOf(Result, "result"));
}
