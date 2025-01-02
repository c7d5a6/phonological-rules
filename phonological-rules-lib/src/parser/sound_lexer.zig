const std = @import("std");
const unicode = std.unicode;
const util = @import("../utils/symbols.zig");
const isWhitespace = util.isWhitespace;
const isDiacritics = util.isDiacritics;
const isAffricateSymbol = util.isAffricateSymbol;
const Phoneme = @import("../sounds/phoneme.zig").Phoneme;
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;
const LexerError = @import("lexer_errors.zig").LexerError;

pub const SoundLexer = struct {
    source: []const u8,
    curPos: u32,
    iterator: unicode.Utf8Iterator,

    const Self = @This();

    pub fn init(source: []const u8) Self {
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
        if (isAffricateSymbol(sl.iterator.peek(1))) {
            _ = sl.iterator.nextCodepoint();
            const n = sl.iterator.nextCodepointSlice();
            if (n) |next| {
                if (isDiacritics(next)) {
                    return error.WrongPlaceForDiacritic;
                }
                if (isWhitespace(next)) {
                    return error.WrongPlaceForWhitespace;
                }
            } else {
                return error.EndAfterAffricate;
            }
            ph = Phoneme{ .ftrs = PhFeatures{} };
            ph.setPhSound(sl.iterator.bytes[start..sl.iterator.i]);
            while (isDiacritics(sl.iterator.peek(1))) {
                const d_slice = sl.iterator.nextCodepointSlice().?;
                ph.setSoundWithDiacritic(sl.iterator.bytes[start..sl.iterator.i], d_slice);
            }
        }

        return SoundToken{ .text = slice, .type = .Phoneme, .ph = ph };
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

const tst = std.testing;

test "parse diacritic" {
    var lexer = SoundLexer.init("p͡f");

    const symbol: SoundToken = try lexer.nextToken() orelse unreachable;
    const end = lexer.nextToken();

    try tst.expectEqual(end, null);
    try tst.expectEqual(symbol.type, .Phoneme);
}
