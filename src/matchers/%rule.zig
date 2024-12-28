const std = @import("std");
const builtin = @import("builtin");
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;
const PatternToken = @import("../parser/match_lexer.zig").PatternToken;
const MatchLexer = @import("../parser/match_lexer.zig").MatchLexer;
const SoundToken = @import("../parser/sound_lexer.zig").SoundToken;
const SoundLexer = @import("../parser/sound_lexer.zig").SoundLexer;
const find_match = @import("../matchers/matcher.zig").find_match;
const getSound = @import("../sounds/ph_sound.zig").getSound;

const PTArray = std.ArrayList(PatternToken);
const STArray = std.ArrayList(SoundToken);
const StrArray = std.ArrayList(u8);

const Rule = struct {
    const Self = @This();
    a: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    match: PTArray,
    // Changeset,
    // Context
    pub fn init(rule_in: [:0]const u8) !Self {
        const a = if (builtin.is_test)
            std.testing.allocator
        else if (builtin.mode == .Debug)
            std.heap.GeneralPurposeAllocator({})
        else
            std.heap.c_allocator;
        var match = try PTArray.initCapacity(a, 3);
        var matcher = MatchLexer.init(rule_in);
        while (try matcher.nextToken()) |t| {
            try match.append(t);
        }
        return Self{
            .a = a,
            .arena = std.heap.ArenaAllocator.init(a),
            .match = match,
        };
    }

    pub fn destroy(self: *const Self) void {
        self.arena.deinit();
        self.match.deinit();
    }

    pub fn apply(self: *Self, alloc: std.mem.Allocator, input: [:0]const u8) ![:0]const u8 {
        const aa = self.arena.allocator();
        defer _ = self.arena.reset(.retain_capacity);
        var result = try StrArray.initCapacity(aa, input.len);
        var sound = try STArray.initCapacity(aa, input.len);
        defer result.deinit();
        defer sound.deinit();

        var lexer = SoundLexer.init(input);

        while (try lexer.nextToken()) |t| {
            try sound.append(t);
        }

        var i: u64 = 0;
        while (i < sound.items.len) {
            const n_i = find_match(sound.items, i, self.match.items) orelse sound.items.len;
            while (i < n_i) {
                const s = try getSound(sound.items[i], aa);
                try result.appendSlice(s);
                i += 1;
            }
            var m: u64 = 0;
            while (i + m < sound.items.len and m < self.match.items.len) {
                var st: SoundToken = sound.items[i + m];
                if (st.type == .Phoneme) {
                    var ph = PhFeatures{};
                    ph.removeFtr(.voice);
                    st.ph = st.ph.?.applyChanges(ph);
                }
                const s = try getSound(st, aa);
                try result.appendSlice(s);
                m += 1;
            }
            i += m;
        }

        const newsound = try alloc.allocSentinel(u8, result.items.len, 0);
        @memcpy(newsound[0..], result.items);
        return newsound;
    }
};

const expectEqualDeep = std.testing.expectEqualDeep;

test "change sounds" {
    const input1 = "riabt͡ʃik";
    const input2 = "pods";
    var rule = try Rule.init("[+voice -syllabic][-voice]");
    defer rule.destroy();

    const out1 = try rule.apply(std.testing.allocator, input1);
    const out2 = try rule.apply(std.testing.allocator, input2);
    defer std.testing.allocator.free(out1);
    defer std.testing.allocator.free(out2);

    try expectEqualDeep(out1, "riapt͡ʃik");
    try expectEqualDeep(out2, "pots");
}
