const utils = @import("rule_test_utils.zig");

test "feature mask drops orig and reconstructs the glyph" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "p",
            .output = "b",
            .rule = "p>[+voice]",
        },
        .{
            .input = "apa",
            .output = "aba",
            .rule = "p>[+voice]",
        },
        .{
            .input = "b",
            .output = "p",
            .rule = "b>[-voice]",
        },
    };

    try utils.expectRuleCases(&cases);
}
