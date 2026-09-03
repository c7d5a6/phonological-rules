const utils = @import("rule_test_utils.zig");

test "vowel nasalizes before a nasal" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "an",
            .output = "ãn",
            .rule = "[+syllabic][+nasal]>[+nasal][]",
        },
        .{
            .input = "am",
            .output = "ãm",
            .rule = "[+syllabic][+nasal]>[+nasal][]",
        },
        .{
            .input = "ta",
            .output = "ta",
            .rule = "[+syllabic][+nasal]>[+nasal][]",
        },
    };

    try utils.expectRuleCases(&cases);
}
