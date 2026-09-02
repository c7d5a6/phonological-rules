const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;
const util = @import("../utils/symbols.zig");
const isWhitespace = util.isWhitespace;
const isDiacritics = util.isDiacritics;
const isAffricateSymbol = util.isAffricateSymbol;
const Phoneme = @import("../sounds/phoneme.zig").Phoneme;
const phonemes = @import("../sounds/phoneme.zig").phonemes;
const diacritics = @import("../sounds/phoneme.zig").diacritics;
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;
const LexerError = @import("lexer_errors.zig").LexerError;

/// Consume one IPA segment starting at `first`, which the caller already read.
/// `start` is the byte index of `first` in `iter.bytes`.
pub fn readPhoneme(
    iter: *unicode.Utf8Iterator,
    start: usize,
    first: []const u8,
) LexerError!Phoneme {
    assert(first.len > 0);
    assert(start + first.len == iter.i);
    assert(iter.i <= iter.bytes.len);

    var ph = Phoneme{ .ftrs = PhFeatures{} };
    ph.setPhSound(first);
    applyTrailingDiacritics(&ph, iter, start);

    if (isAffricateSymbol(iter.peek(1))) {
        const tie = iter.nextCodepointSlice().?;
        assert(isAffricateSymbol(tie));

        const second = iter.nextCodepointSlice() orelse return error.EndAfterAffricate;
        if (isDiacritics(second)) {
            return error.WrongPlaceForDiacritic;
        } else {
            if (isWhitespace(second)) {
                return error.WrongPlaceForWhitespace;
            } else {
                // Lookup the full span so table rows like t͡ʃ win over t then ʃ.
                ph = Phoneme{ .ftrs = PhFeatures{} };
                ph.setPhSound(iter.bytes[start..iter.i]);
                applyTrailingDiacritics(&ph, iter, start);
            }
        }
    }

    assert(ph.orig != null);
    assert(ph.orig.?.len >= first.len);
    return ph;
}

fn applyTrailingDiacritics(ph: *Phoneme, iter: *unicode.Utf8Iterator, start: usize) void {
    while (isDiacritics(iter.peek(1))) {
        const before = iter.i;
        const mark = iter.nextCodepointSlice().?;
        assert(mark.len > 0);
        assert(iter.i > before);
        assert(iter.i > start);
        ph.setSoundWithDiacritic(iter.bytes[start..iter.i], mark);
    }
}

fn tableFeatures(sound: []const u8) ?PhFeatures {
    assert(sound.len > 0);
    for (phonemes) |p| {
        if (p.orig) |orig| {
            if (std.mem.eql(u8, orig, sound)) return p.ftrs;
        }
    }
    return null;
}

fn diacriticChange(mark: []const u8) PhFeatures {
    assert(mark.len > 0);
    for (diacritics) |d| {
        if (d.orig) |orig| {
            if (std.mem.eql(u8, orig, mark)) return d.ftrs;
        }
    }
    assert(false);
    unreachable;
}

fn readSource(source: []const u8) !Phoneme {
    assert(source.len > 0);
    const view = try unicode.Utf8View.init(source);
    var iter = view.iterator();
    const start = iter.i;
    const first = iter.nextCodepointSlice().?;
    assert(first.len > 0);
    const ph = try readPhoneme(&iter, start, first);
    try std.testing.expectEqual(source.len, iter.i);
    try std.testing.expectEqualStrings(source, ph.orig.?);
    return ph;
}

fn expectReadError(source: []const u8, expected: anyerror) !void {
    assert(source.len > 0);
    const view = try unicode.Utf8View.init(source);
    var iter = view.iterator();
    const start = iter.i;
    const first = iter.nextCodepointSlice().?;
    assert(first.len > 0);
    try std.testing.expectError(expected, readPhoneme(&iter, start, first));
}

test "linked phonemes without diacritics" {
    const tf = try readSource("t͡ʃ");
    try std.testing.expect(!tf.unknw);
    try std.testing.expectEqual(tableFeatures("t͡ʃ").?, tf.ftrs);

    const pf = try readSource("p͡f");
    try std.testing.expect(!pf.unknw);
    try std.testing.expectEqual(tableFeatures("p͡f").?, pf.ftrs);
}

test "linked phonemes with diacritic on first" {
    const ph = try readSource("t̪͡ʃ");
    // t̪͡ʃ is not a table row. Lookup after the tie replaces t̪.
    try std.testing.expect(ph.unknw);
}

test "linked phonemes with diacritic on second" {
    const ph = try readSource("t͡ʃʰ");
    try std.testing.expect(!ph.unknw);

    var expected = tableFeatures("t͡ʃ").?;
    expected = expected.applyChange(diacriticChange("ʰ"));
    try std.testing.expectEqual(expected, ph.ftrs);
}

test "linked phonemes with diacritics on both" {
    // Inventory glyph. Lookup is the span before the second-half mark.
    const dental = try readSource("t̪͡s̪");
    try std.testing.expectEqualStrings("t̪͡s̪", dental.orig.?);

    const mixed = try readSource("t̪͡ʃʰ");
    try std.testing.expect(mixed.unknw);
}

test "tie bar with nothing after is an error" {
    try expectReadError("t͡", error.EndAfterAffricate);
}

test "diacritic immediately after tie bar is an error" {
    try expectReadError("t͡ʰ", error.WrongPlaceForDiacritic);
}

test "whitespace immediately after tie bar is an error" {
    try expectReadError("t͡ ʃ", error.WrongPlaceForWhitespace);
}
