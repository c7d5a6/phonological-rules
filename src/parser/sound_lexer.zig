const std = @import("std");
const unicode = std.unicode;
const util = @import("../utils/symbols.zig");
const isWhitespace = util.isWhitespace;

const SoundLexer = struct {
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

    pub fn nextToken(sl: *Self) ?SoundToken {
        const start = sl.iterator.i;
        const slice = sl.iterator.nextCodepointSlice() orelse return null;
        // const token = unicode.utf8Decode(slice);
        if (isWhitespace(slice)) {
            while (isWhitespace(sl.iterator.peek(1))) {
                _ = sl.iterator.nextCodepoint();
            }
            return SoundToken{ .type = .Whitespace, .text = sl.iterator.bytes[start..sl.iterator.i] };
        }

        return SoundToken{ .text = slice, .type = .Phoneme };
    }
};

const SoundToken = struct {
    type: PhonemeTokenType,
    text: []const u8,
};

const PhonemeTokenType = enum {
    End,
    Phoneme,
    Diacritic,
    Whitespace,
};

test "Test print" {
    const source = "cʰɛm̥pa\nHello       world!😊!!!\n and you!";
    var lexer = SoundLexer.init(source);
    while (lexer.nextToken()) |t| {
        std.debug.print(" {s} : {any}\n", .{ t.text, t.type });
    }
}

test "test" {
    const view = unicode.Utf8View.init("Hello") catch unreachable;
    var iterator = view.iterator();
    std.debug.print(" len : {d}\n", .{"\u{FEFF}".len});

    std.debug.print(" {s}\n", .{iterator.peek(0)});
    std.debug.print(" {s}\n", .{iterator.peek(1)});
    std.debug.print(" {s}\n", .{iterator.peek(2)});
    std.debug.print(" {s}\n", .{iterator.peek(3)});
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
