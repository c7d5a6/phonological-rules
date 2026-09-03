const utils = @import("rule_test_utils.zig");

test "affricate identity and no-match keep the tie bar" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "t͡ʃ",
            .output = "t͡ʃ",
            .rule = "[]>[]",
        },
        .{
            .input = "at͡ʃa",
            .output = "at͡ʃa",
            .rule = "k>b",
        },
    };

    try utils.expectRuleCases(&cases);
}
