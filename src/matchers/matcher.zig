const std = @import("std");
const SoundToken = @import("../parser/sound_lexer.zig").SoundToken;
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;

const PatternTokenType = enum {
    Whitespace,
    End,
    Mask,
};

const PatternToken = struct {
    type: PatternTokenType,
    mask: PhFeatures,
};

fn find_match(source: []const SoundToken, from: u64, pattern: []const PatternToken) ?u64 {
    var m = from;

    while (m + pattern.len <= source.len) {
        var i: u64 = 0;
        while (i < pattern.len) {
            switch (pattern[i].type) {
                .End => unreachable,
                .Whitespace => if (source[m + i].type != .Whitespace) break,
                .Mask => {
                    if (source[m + i].type != .Phoneme) break;
                    if (!source[m + i].ph.?.ftrs.contain(pattern[i].mask))
                        break;
                },
            }
            i += 1;
        }
        if (i == pattern.len)
            return m;
        m += 1;
    }
    return null;
}

const SoundLexer = @import("../parser/sound_lexer.zig").SoundLexer;

test "find matching" {
    // A
    const input = "aːbʰa";

    var lexer = SoundLexer.init(input);
    var sounds: [3]SoundToken = undefined;
    var i: u64 = 0;
    while (try lexer.nextToken()) |t| {
        sounds[i] = t;
        i += 1;
    }

    var c = PhFeatures{};
    c.removeFtr(.syllabic);
    var v = PhFeatures{};
    v.addFtr(.syllabic);

    const pattern = [_]PatternToken{
        PatternToken{ .type = .Mask, .mask = c },
        PatternToken{ .type = .Mask, .mask = v },
    };

    // A
    const match = find_match(sounds[0..], 0, pattern[0..]);
    std.debug.print("Match: {any}\n", .{match});

    // A
    //                  input:    aːbʰa
    //                  pattern:  v c v
    //                  index:    0 1 2
    //                              ^
    try std.testing.expect(match == 1);
}
