const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;
const util = @import("../utils/symbols.zig");
const isWhitespace = util.isWhitespace;
const isDiacritics = util.isDiacritics;
const Phoneme = @import("../sounds/phoneme.zig").Phoneme;
const LexerError = @import("lexer_errors.zig").LexerError;
const readPhoneme = @import("phoneme_read.zig").readPhoneme;

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
            return SoundToken{ .type = .Whitespace };
        }
        if (isDiacritics(slice)) {
            return error.WrongPlaceForDiacritic;
        }

        const ph = try readPhoneme(&sl.iterator, start, slice);
        assert(ph.orig != null);
        assert(ph.orig.?.len >= slice.len);
        return SoundToken{ .type = .Phoneme, .ph = ph };
    }
};

pub const SoundToken = struct {
    type: PhonemeTokenType,
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
    try tst.expectEqualStrings("p͡f", symbol.ph.?.orig.?);
}

test "orig includes trailing diacritic" {
    var lexer = SoundLexer.init("tʰ");
    const symbol: SoundToken = try lexer.nextToken() orelse unreachable;
    try tst.expectEqual(try lexer.nextToken(), null);
    try tst.expectEqualStrings("tʰ", symbol.ph.?.orig.?);
}
