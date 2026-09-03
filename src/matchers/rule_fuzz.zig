const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;
const Rule = @import("rule.zig").Rule;
const SoundLexer = @import("../parser/sound_lexer.zig").SoundLexer;
const MatchLexer = @import("../parser/match_lexer.zig").MatchLexer;
const ChangeLexer = @import("../parser/change_lexer.zig").ChangeLexer;
const phonemes = @import("../sounds/phoneme.zig").phonemes;
const ftr_names = @import("../sounds/features.zig").features;

const max_input = 64;
const max_ipa_phonemes = 8;

const corpus = [_][]const u8{
    "pods",
    "riabt͡ʃik",
    "[+voice -syllabic][-voice]>[-voice][]",
    "[]>[]",
    "p>[+voice]",
    "n>[-voice]",
    "an",
};

const byte_weights = [_]std.testing.Smith.Weight{
    .rangeAtMost(u8, 0x00, 0xff, 1),
    .rangeAtMost(u8, 0x20, 0x7e, 4),
    .value(u8, '>', 8),
    .value(u8, '[', 4),
    .value(u8, ']', 4),
    .value(u8, '+', 4),
    .value(u8, '-', 4),
};

test "fuzz lexers on valid utf8" {
    try std.testing.fuzz({}, fuzzLexers, .{ .corpus = &corpus });
}

test "fuzz structured apply" {
    try std.testing.fuzz({}, fuzzApply, .{ .corpus = &corpus });
}

fn fuzzLexers(_: void, smith: *std.testing.Smith) !void {
    @disableInstrumentation();
    var buf: [max_input]u8 = undefined;
    const len = smith.sliceWeightedBytes(&buf, &byte_weights);
    const source = buf[0..len];
    if (!unicode.utf8ValidateSlice(source)) return;

    drainSound(source);
    drainMatch(source);
    drainChange(source);
    try initRuleOnArena(source);
}

fn drainSound(source: []const u8) void {
    var lexer = SoundLexer.init(source);
    while (lexer.nextToken() catch return) |_| {}
}

fn drainMatch(source: []const u8) void {
    var lexer = MatchLexer.init(source);
    while (lexer.nextToken() catch return) |_| {}
}

fn drainChange(source: []const u8) void {
    var lexer = ChangeLexer.init(source);
    while (lexer.nextToken() catch return) |_| {}
}

/// Rule.init error paths may skip deinit; an arena still reclaims the attempt.
fn initRuleOnArena(source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var rule = Rule.init(arena.allocator(), source) catch return;
    rule.destroy();
}

fn fuzzApply(_: void, smith: *std.testing.Smith) !void {
    @disableInstrumentation();
    const a = std.testing.allocator;
    var ipa_buf: [256]u8 = undefined;
    const ipa = writeIpa(smith, &ipa_buf);
    try expectIdentity(a, "[]>[]", ipa);

    var one_buf: [32]u8 = undefined;
    const one = writeOneGlyph(smith, &one_buf);
    var ident_buf: [72]u8 = undefined;
    const ident = try std.fmt.bufPrint(&ident_buf, "{s}>{s}", .{ one, one });
    try expectIdentity(a, ident, one);

    var mask_buf: [72]u8 = undefined;
    const mask_rule = writeMaskRule(smith, &mask_buf);
    try expectApplyUtf8(a, mask_rule, ipa);
}

fn writeIpa(smith: *std.testing.Smith, buf: []u8) []u8 {
    var used: usize = 0;
    var n: usize = 0;
    while (n < max_ipa_phonemes) {
        const glyph = phonemes[smith.index(phonemes.len)].orig.?;
        assert(glyph.len > 0);
        if (used + glyph.len > buf.len) break;
        @memcpy(buf[used..][0..glyph.len], glyph);
        used += glyph.len;
        n += 1;
        if (smith.eosWeightedSimple(7, 1)) break;
    }
    if (used == 0) {
        const glyph = phonemes[0].orig.?;
        @memcpy(buf[0..glyph.len], glyph);
        used = glyph.len;
    }
    return buf[0..used];
}

fn writeOneGlyph(smith: *std.testing.Smith, buf: []u8) []u8 {
    const glyph = phonemes[smith.index(phonemes.len)].orig.?;
    assert(glyph.len > 0);
    assert(glyph.len <= buf.len);
    @memcpy(buf[0..glyph.len], glyph);
    return buf[0..glyph.len];
}

fn writeMaskRule(smith: *std.testing.Smith, buf: []u8) []u8 {
    const left = ftr_names[smith.index(ftr_names.len)];
    const right = ftr_names[smith.index(ftr_names.len)];
    const lsign: u8 = if (smith.boolWeighted(1, 1)) '+' else '-';
    const rsign: u8 = if (smith.boolWeighted(1, 1)) '+' else '-';
    return std.fmt.bufPrint(
        buf,
        "[{c}{s}]>[{c}{s}]",
        .{ lsign, left.name, rsign, right.name },
    ) catch unreachable;
}

fn expectIdentity(a: std.mem.Allocator, rule_str: []const u8, input: []const u8) !void {
    var rule = try Rule.init(a, rule_str);
    defer rule.destroy();
    const out = try rule.apply(a, input);
    defer a.free(out);
    try std.testing.expectEqualStrings(input, out);
}

fn expectApplyUtf8(a: std.mem.Allocator, rule_str: []const u8, input: []const u8) !void {
    var rule = try Rule.init(a, rule_str);
    defer rule.destroy();
    const out = try rule.apply(a, input);
    defer a.free(out);
    try std.testing.expect(unicode.utf8ValidateSlice(out));
}
