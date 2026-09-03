const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const phoneme = @import("phoneme.zig");
const Phoneme = phoneme.Phoneme;
const phonemes = phoneme.phonemes;
const diacritics = phoneme.diacritics;
const SoundToken = @import("../parser/sound_lexer.zig").SoundToken;

const SoundErrors = error{
    UnknownSoundToken,
};

pub fn getSound(st: SoundToken, a: Allocator) ![:0]const u8 {
    switch (st.type) {
        .Whitespace => {
            var result = try a.allocSentinel(u8, 1, 0);
            result[0] = " "[0];
            return result;
        },
        .Phoneme => return phonemeSound(st.ph.?, a),
        else => return error.UnknownSoundToken,
    }
}

pub fn phonemeSound(ph: Phoneme, a: Allocator) [:0]const u8 {
    if (ph.orig) |s| {
        var dest = a.allocSentinel(u8, s.len, 0) catch unreachable;
        @memcpy(dest[0..], s);
        return dest;
    }
    assert(!ph.unknw);
    const found = findSound(ph, a);
    return found;
}

fn findSound(ph: Phoneme, a: Allocator) [:0]const u8 {
    return a_star(ph, a);
}

const QueueContext = struct { dest: PhFeatures };
const QueueMember = struct {
    f: PhFeatures,
    cost: u32,
    from: ?usize = null,
    sound: []const u8,
};
fn queueCompare(context: QueueContext, a: QueueMember, b: QueueMember) Order {
    const a_d = a.cost + a.f.dist(context.dest);
    const b_d = b.cost + b.f.dist(context.dest);
    return if (a_d == b_d) Order.eq else if (a_d < b_d) Order.lt else Order.gt;
}

const PriorityQueue = std.PriorityQueue(QueueMember, QueueContext, queueCompare);
const VisitedList = std.ArrayList(QueueMember);

fn a_star(ph: Phoneme, a: Allocator) [:0]const u8 {
    const dest: PhFeatures = ph.ftrs;

    var heap: PriorityQueue = .initContext(.{ .dest = dest });
    defer heap.deinit(a);

    var visited = VisitedList.initCapacity(a, 0) catch unreachable;
    defer visited.deinit(a);

    for (phonemes) |phc| {
        const itm = QueueMember{ .f = phc.ftrs, .cost = 1, .sound = phc.orig orelse unreachable };
        if (phc.ftrs.eql(dest)) return parseSound(&.{}, null, phc.orig orelse unreachable, a);
        heap.push(a, itm) catch unreachable;
    }

    while (heap.pop()) |itm| {
        //TODO: prevent transaction to unknown routes a > b
        if (visited.items.len > 1000) break;
        const edge_idx = visited.items.len;
        visited.append(a, itm) catch unreachable;
        const edge = visited.items[edge_idx];
        d_loop: for (diacritics) |d| {
            const next = edge.f.applyChange(d.ftrs);
            for (visited.items) |v| {
                if (next.eql(v.f)) continue :d_loop;
            }
            if (next.eql(dest)) return parseSound(visited.items, edge_idx, d.orig orelse unreachable, a);
            for (heap.items) |h| {
                if (next.eql(h.f)) continue :d_loop;
            }
            const new = QueueMember{ .f = next, .cost = 1 + edge.cost, .from = edge_idx, .sound = d.orig orelse unreachable };
            heap.push(a, new) catch unreachable;
        }
    }
    return "?";
}

fn parseSound(visited: []const QueueMember, from: ?usize, last: []const u8, a: Allocator) [:0]const u8 {
    var idx = from;
    var length = last.len;
    while (idx) |i| {
        length += visited[i].sound.len;
        idx = visited[i].from;
    }
    var sound = a.allocSentinel(u8, length, 0) catch unreachable;
    idx = from;
    var end = length;
    var start = length - last.len;
    @memcpy(sound[start..end], last);
    end = start;
    while (idx) |i| {
        const qm = visited[i];
        idx = qm.from;
        start = end - qm.sound.len;
        @memcpy(sound[start..end], qm.sound);
        end = start;
    }
    // if (orig) |_| {
    //     temp = orig;
    //     while (temp.?.from) |from| {
    //         temp = from;
    //     }
    //     const s_len = temp.?.sound.len;
    //
    //     for (s_len..sound.len) |j| {
    //         for (s_len..j) |i| {
    //             if (i == j) continue;
    //             if (sound[i] < sound[j]) {
    //                 const s = sound[i];
    //                 sound[i] = sound[j];
    //                 sound[j] = s;
    //             }
    //         }
    //     }
    // }

    return sound;
}

const sstype = [:0]const u8;
const sort_sounds = [_]u8{
    '\u{02D0}', //ː
    '\u{02B0}', //ʰ
    '\u{02B2}', //ʲ
    '\u{02B7}', //ʷ
    '\u{02E0}', //ˠ
    '\u{02E4}', //ˤ
    '\u{02DE}', //˞
    '\u{0303}', //◌̃
    '\u{0329}', //◌̩
    '\u{0330}', //˷ • ◌̰
    '\u{0324}', //◌̤
    '\u{0325}', //˳ • ◌̥
    '\u{0320}', //ˍ • ◌̠
    '\u{032A}', //◌͏̪
};

const testing = @import("std").testing;
const memeq = @import("std").mem.eql;
const GeneralPA = @import("std").heap.DebugAllocator;
const expect = testing.expect;
const PhFeatures = @import("ph_features.zig").PhFeatures;
const Feature = @import("features.zig").Feature;
const print = std.debug.print;

test "find simple sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    const ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = 68440605, .mnsMsk = 453741762 } };
    const sound = phonemeSound(ph, a);

    try expect(memeq(u8, sound, "ɒ"));
    a.free(sound);
    try expect(gpa.detectLeaks() == 0);
}

test "find sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);
    ph.ftrs.removeFtr(Feature.constricted_glottis);
    ph.ftrs.addFtr(Feature.spread_glottis);

    const sound = phonemeSound(ph, a);
    try expect(memeq(u8, sound, "nʰ̥"));

    // clean
    a.free(sound);
    try expect(gpa.detectLeaks() == 0);
}

test "n - m̥" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);
    ph.ftrs.removeFtr(Feature.coronal);
    ph.ftrs.addFtr(Feature.labial);

    const sound = phonemeSound(ph, a);
    try expect(memeq(u8, sound, "m̥"));

    // clean
    a.free(sound);
    try expect(gpa.detectLeaks() == 0);
}

pub fn main() void {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);
    ph.ftrs.addFtr(Feature.labial);
    ph.ftrs.addFtr(Feature.round);

    const sound = phonemeSound(ph, a);
    print("sound {s}", .{sound});
}
