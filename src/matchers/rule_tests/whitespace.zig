const utils = @import("rule_test_utils.zig");

test "whitespace is a match and change token" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "a a",
            .output = "a b",
            .rule = "a a>a b",
        },
        .{
            .input = "p t",
            .output = "p t",
            .rule = "p t>p t",
        },
    };

    try utils.expectRuleCases(&cases);
}
