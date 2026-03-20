const std = @import("std");
const Rule = @import("../rule.zig").Rule;

pub const RuleTestCase = struct {
    input: []const u8,
    rule: []const u8,
    output: []const u8,
};

pub fn expectRuleCase(case: RuleTestCase) !void {
    var rule = try Rule.init(case.rule);
    defer rule.destroy();

    const out = try rule.apply(std.testing.allocator, case.input);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(case.output, out);
}

pub fn expectRuleCases(cases: []const RuleTestCase) !void {
    for (cases) |case| {
        try expectRuleCase(case);
    }
}
