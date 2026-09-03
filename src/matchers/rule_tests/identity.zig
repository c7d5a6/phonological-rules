const utils = @import("rule_test_utils.zig");

test "empty mask copies a phoneme through" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "p",
            .output = "p",
            .rule = "[]>[]",
        },
        .{
            .input = "apa",
            .output = "apa",
            .rule = "[]>[]",
        },
    };

    try utils.expectRuleCases(&cases);
}

test "no match leaves the string unchanged" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "apa",
            .output = "apa",
            .rule = "k>b",
        },
        .{
            .input = "t͡ʃ",
            .output = "t͡ʃ",
            .rule = "k>b",
        },
    };

    try utils.expectRuleCases(&cases);
}
