const utils = @import("rule_test_utils.zig");

test "phoneme on the change side replaces the glyph" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "p",
            .output = "b",
            .rule = "p>b",
        },
        .{
            .input = "k",
            .output = "b",
            .rule = "k>b",
        },
        .{
            .input = "aka",
            .output = "aba",
            .rule = "k>b",
        },
        .{
            .input = "t",
            .output = "t͡ʃ",
            .rule = "t>t͡ʃ",
        },
    };

    try utils.expectRuleCases(&cases);
}
