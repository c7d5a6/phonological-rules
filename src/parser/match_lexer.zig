const std = @import("std");
const unicode = std.unicode;
const utilS = @import("../utils/symbols.zig");
const utilF = @import("../utils/fn.zig");
const isWhitespace = utilS.isWhitespace;
const isDiacritics = utilS.isDiacritics;
const eq = utilF.eq;
const ftr_names = @import("../sounds/features.zig").features;
const Phoneme = @import("../sounds/phoneme.zig").Phoneme;
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;
const LexerError = @import("lexer_errors.zig").LexerError;

const PatternTokenType = enum {
    Whitespace,
    End,
    Mask,
};
const Mod = enum {
    plus,
    minus,
};

pub const PatternToken = struct {
    type: PatternTokenType,
    mask: ?PhFeatures = null,
};

pub const MatchLexer = struct {
    source: [:0]const u8,
    curPos: u32,
    iterator: unicode.Utf8Iterator,

    const Self = @This();

    pub fn init(source: [:0]const u8) Self {
        const view = unicode.Utf8View.init(source) catch unreachable;
        return Self{
            .source = source,
            .curPos = 0,
            .iterator = view.iterator(),
        };
    }

    fn skipWhitespace(ml: *Self) void {
        while (isWhitespace(ml.iterator.peek(1))) {
            _ = ml.iterator.nextCodepoint();
        }
    }

    pub fn nextToken(ml: *Self) LexerError!?PatternToken {
        var iter = &ml.iterator;
        const start = iter.i;
        const slice = iter.nextCodepointSlice() orelse return null;

        if (isWhitespace(slice)) {
            ml.skipWhitespace();
            return PatternToken{ .type = .Whitespace };
        }
        if (isDiacritics(slice)) {
            return error.WrongPlaceForDiacritic;
        }
        if (eq(slice, "[")) {
            //TODO: add wildcard modifiers
            var pattern = PatternToken{ .type = .Mask, .mask = PhFeatures{} };
            // add check for ]
            next: while (iter.peek(1).len != 0 and !eq(iter.peek(1), "]")) {
                ml.skipWhitespace();
                const mod_sl = iter.nextCodepointSlice();
                var mod: Mod = undefined;
                if (eq(mod_sl, "+")) {
                    mod = .plus;
                } else if (eq(mod_sl, "-")) {
                    mod = .minus;
                } else {
                    return error.UnexpectedSymbol;
                }
                for (ftr_names) |ftn| {
                    if (ml.source.len >= iter.i + ftn.name.len and eq(ftn.name, ml.source[iter.i .. iter.i + ftn.name.len])) {
                        switch (mod) {
                            .plus => pattern.mask.?.addFtr(ftn.f),
                            .minus => pattern.mask.?.removeFtr(ftn.f),
                        }
                        ml.iterator.i = iter.i + ftn.name.len;
                        continue :next;
                    }
                }
                return error.UnexpectedSymbol;
            }
            const end_sq_brk = iter.nextCodepointSlice();
            if (!eq(end_sq_brk, "]")) return error.UnexpectedSymbol;
            return pattern;
        }

        // TODO: return end of match
        // if(std.mem.eql(u8,slice,">"){
        // }

        var ph = Phoneme{ .ftrs = PhFeatures{} };
        ph.setPhSound(slice);
        while (isDiacritics(iter.peek(1))) {
            const d_slice = iter.nextCodepointSlice().?;
            ph.setSoundWithDiacritic(iter.bytes[start..iter.i], d_slice);
        }

        return PatternToken{ .type = .Mask, .mask = ph.ftrs };
    }
};

pub const SoundToken = struct {
    type: PhonemeTokenType,
    text: []const u8,
    ph: ?Phoneme = null,
};

const PhonemeTokenType = enum {
    Phoneme,
    Diacritic,
    Whitespace,
};

// test "Test print" {
//     const source = "cʰɛm̥";
//     var lexer = MatchLexer.init(source);
//     while (try lexer.nextToken()) |t| {
//         std.debug.print(" {any} : {any}\n", .{ t.type, t.mask });
//     }
// }

test "Parse features" {
    const source = "[+voice -flap]";

    var lexer = MatchLexer.init(source);
    const mask = try lexer.nextToken();

    try std.testing.expectEqual(mask.?.type, PatternTokenType.Mask);
    var m = PhFeatures{};
    m.addFtr(.voice);
    m.removeFtr(.flap);
    try std.testing.expectEqual(mask.?.mask, m);
}

// class PhonemeLexer extends Lexer<PhonemeToken, PhonemeTokenType> {
//
//   @override
//   PhonemeToken getToken() {
//     goNextChar();
//     if (isWhitespace(curChar)) {
//       return getWhitespaceToken();
//     }
//     if (isDiacritics(curChar)) {
//       return getTokenByType(PhonemeTokenType.Diacritic);
//     }
//     if (curChar == '\0') {
//       return getTokenByType(PhonemeTokenType.End);
//     }
//     return getTokenByType(PhonemeTokenType.Phoneme);
//   }
//
//   @override
//   PhonemeTokenType getWhitespaceType() {
//     return PhonemeTokenType.Whitespace;
//   }
//
//   @override
//   PhonemeToken newToken(PhonemeTokenType type, String text, Object? literal) {
//     return PhonemeToken(type, text, literal);
//   }
// }
