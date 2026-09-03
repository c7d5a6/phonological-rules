const utils = @import("rule_test_utils.zig");

test "feature mask adds a diacritic" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "n",
            .output = "n̥",
            .rule = "n>[-voice]",
        },
        .{
            .input = "a",
            .output = "aː",
            .rule = "a>[+long]",
        },
    };

    try utils.expectRuleCases(&cases);
}
