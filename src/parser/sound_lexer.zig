const std = @import("std");
const unicode = std.unicode;
const util = @import("../utils/symbols.zig");
const isWhitespace = util.isWhitespace;
const isDiacritics = util.isDiacritics;
const Phoneme = @import("../sounds/phoneme.zig").Phoneme;
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;

const LexerError = error{WrongPlaceForDiacritic};

pub const SoundLexer = struct {
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

    pub fn nextToken(sl: *Self) LexerError!?SoundToken {
        const start = sl.iterator.i;
        const slice = sl.iterator.nextCodepointSlice() orelse return null;
        // const token = unicode.utf8Decode(slice);
        if (isWhitespace(slice)) {
            while (isWhitespace(sl.iterator.peek(1))) {
                _ = sl.iterator.nextCodepoint();
            }
            return SoundToken{ .type = .Whitespace, .text = sl.iterator.bytes[start..sl.iterator.i] };
        }
        if (isDiacritics(slice)) {
            return error.WrongPlaceForDiacritic;
        }

        var ph = Phoneme{ .ftrs = PhFeatures{} };
        ph.setPhSound(slice);
        while (isDiacritics(sl.iterator.peek(1))) {
            const d_slice = sl.iterator.nextCodepointSlice().?;
            ph.setSoundWithDiacritic(sl.iterator.bytes[start..sl.iterator.i], d_slice);
        }

        return SoundToken{ .text = slice, .type = .Phoneme, .ph = ph };
    }
};

const SoundToken = struct {
    type: PhonemeTokenType,
    text: []const u8,
    ph: ?Phoneme = null,
};

const PhonemeTokenType = enum {
    Phoneme,
    Diacritic,
    Whitespace,
};

test "Test print" {
    const source = "cʰɛm̥";
    var lexer = SoundLexer.init(source);
    while (try lexer.nextToken()) |t| {
        std.debug.print(" {s} : {any}, {any}\n", .{ t.text, t.type, t.ph });
    }
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
