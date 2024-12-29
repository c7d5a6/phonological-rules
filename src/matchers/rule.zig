const std = @import("std");
const builtin = @import("builtin");
const PhFeatures = @import("../sounds/ph_features.zig").PhFeatures;
const PatternToken = @import("../parser/match_lexer.zig").PatternToken;
const MatchLexer = @import("../parser/match_lexer.zig").MatchLexer;
const ChangeToken = @import("../parser/change_lexer.zig").ChangeToken;
const ChangeLexer = @import("../parser/change_lexer.zig").ChangeLexer;
const SoundToken = @import("../parser/sound_lexer.zig").SoundToken;
const SoundLexer = @import("../parser/sound_lexer.zig").SoundLexer;
const find_match = @import("../matchers/matcher.zig").find_match;
const phonemeSound = @import("../sounds/ph_sound.zig").phonemeSound;
const getSound = @import("../sounds/ph_sound.zig").getSound;

const PTArray = std.ArrayList(PatternToken);
const CTArray = std.ArrayList(ChangeToken);
const STArray = std.ArrayList(SoundToken);
const StrArray = std.ArrayList(u8);

const RuleError = error{
    NoChangeSet,
};

const Rule = struct {
    const Self = @This();
    a: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    match: PTArray,
    change: CTArray,
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
        var toCS = false;
        while (try matcher.nextToken()) |t| {
            if (t.type == .TransitionToChangeSet) {
                toCS = true;
                break;
            }
            try match.append(t);
        }
        if (!toCS) return error.NoChangeSet;
        var change = try CTArray.initCapacity(a, 3);
        const change_rule = rule_in[matcher.iterator.i..];
        var changer = ChangeLexer.init(change_rule);
        while (try changer.nextToken()) |t| {
            try change.append(t);
        }

        return Self{
            .a = a,
            .arena = std.heap.ArenaAllocator.init(a),
            .match = match,
            .change = change,
        };
    }

    pub fn destroy(self: *const Self) void {
        self.arena.deinit();
        self.match.deinit();
        self.change.deinit();
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
            while (i + m < sound.items.len and m < self.change.items.len) {
                var st: SoundToken = sound.items[i + m];
                const ch: ChangeToken = self.change.items[m];
                switch (ch.type) {
                    .Whitespace => {
                        try result.appendSlice(" ");
                    },
                    .Mask => {
                        if (st.type == .Phoneme) {
                            const ph = st.ph.?.applyChanges(ch.mask.?);
                            const s = phonemeSound(ph, aa);
                            try result.appendSlice(s);
                        } else unreachable;
                    },
                    else => unreachable,
                }
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
    const r = "[+voice -syllabic][-voice]>[-voice][]";
    var rule = try Rule.init(r);
    defer rule.destroy();

    const out1 = try rule.apply(std.testing.allocator, input1);
    const out2 = try rule.apply(std.testing.allocator, input2);
    defer std.testing.allocator.free(out1);
    defer std.testing.allocator.free(out2);

    try expectEqualDeep(out1, "riapt͡ʃik");
    try expectEqualDeep(out2, "pots");
    std.debug.print("\nRule:{s}\n\t  in:{s}\n\t out:{s}\n\n\n", .{ r, input1, out1 });
    std.debug.print("\nRule:{s}\n\t  in:{s}\n\t out:{s}\n\n\n", .{ r, input2, out2 });
}

test "vakzal" {
    const input = "vakzal";
    const r = "[+dorsal -voice][+voice]>[+voice][]";
    var rule = try Rule.init(r);
    defer rule.destroy();

    const out = try rule.apply(std.testing.allocator, input);
    defer std.testing.allocator.free(out);
    std.debug.print("\nRule:{s}\n\t  in:{s}\n\t out:{s}\n\n\n", .{ r, input, out });

    try expectEqualDeep(out, "vaɡzal");
}
