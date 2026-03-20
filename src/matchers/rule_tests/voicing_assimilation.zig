const utils = @import("rule_test_utils.zig");

test "voicing assimilation: devoicing before voiceless consonants" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "riabt͡ʃik",
            .output = "riapt͡ʃik",
            .rule = "[+voice -syllabic][-voice]>[-voice][]",
        },
        .{
            .input = "pods",
            .output = "pots",
            .rule = "[+voice -syllabic][-voice]>[-voice][]",
        },
    };

    try utils.expectRuleCases(&cases);
}

test "voicing assimilation: voicing before voiced consonants" {
    const cases = [_]utils.RuleTestCase{
        .{
            .input = "vakzal",
            .output = "vaɡzal",
            .rule = "[+dorsal -voice][+voice]>[+voice][]",
        },
    };

    try utils.expectRuleCases(&cases);
}
