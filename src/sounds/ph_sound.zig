const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const phoneme = @import("phoneme.zig");
const Phoneme = phoneme.Phoneme;
const phonemes = phoneme.phonemes;
const diacritics = phoneme.diacritics;

pub fn phonemeSound(ph: Phoneme, a: Allocator) [:0]const u8 {
    if (ph.orig) |s| {
        var dest = a.allocSentinel(u8, s.len, 0) catch unreachable;
        @memcpy(dest[0..], s);
        return dest;
    }
    const found = findSound(ph, a);
    return found;
}

fn findSound(ph: Phoneme, a: Allocator) [:0]const u8 {
    // var aa = Arena.init(a);
    // defer aa.deinit();

    for (phonemes) |phc| {
        if (ph.ftrs.eql(phc.ftrs)) return phc.orig.?;
        for (diacritics) |d| {
            const newSet = phc.ftrs.applyChange(d.ftrs);
            if (ph.ftrs.eql(newSet)) {
                const phc_len = if (phc.orig) |s| s.len else 0;
                const d_len = if (d.orig) |s| s.len else 0;
                var sound = a.allocSentinel(u8, phc_len + d_len, 0) catch unreachable;
                if (phc.orig) |s|
                    @memcpy(sound[0..phc_len], s);
                if (d.orig) |s|
                    @memcpy(sound[phc_len..], s);
                return sound;
            }
        }
    }
    unreachable;
}

const QueueContext = struct { dest: PhFeatures };
const QueueMember = struct { f: PhFeatures, from: ?QueueMember = null, cost: u32, sound: [:0]const u8 };
fn queueCompare(context: QueueContext, a: QueueMember, b: QueueMember) Order {
    const a_d = a.cost + a.ph.ftrs.dist(context.dest);
    const b_d = b.cost + b.ph.ftrs.dist(context.dest);
    return if (a_d == b_d) Order.eq else if (a_d < b_d) Order.lt else Order.gt;
}

const PriorityQueue = std.PriorityQueue(QueueMember, QueueContext, queueCompare);

fn a_star(ph: Phoneme, a: Allocator) []Phoneme {
    const dest: PhFeatures = ph.ftrs;
    var heap = PriorityQueue.init(a, QueueContext{ .dest = dest });
    defer heap.deinit();

    for (phonemes) |phc| {
        if (phc.ftrs.eql(dest)) return []Phoneme{phc};
        heap.add(QueueMember{ .f = phc.ftrs, .cost = 1 });
    }

    while (heap.removeOrNull()) |edge| {
        for (diacritics) |d| {
            const next = edge.f.applyChange(d.ftrs);
            if (next.eql(dest)) return []Phoneme{phc};
            heap.add(QueueMember{ .f = next, .cost = 1 + edge.cost, .from = edge });
        }
    }
    unreachable;
}

const testing = @import("std").testing;
const memeq = @import("std").mem.eql;
const GeneralPA = @import("std").heap.GeneralPurposeAllocator;
const expect = testing.expect;
const PhFeatures = @import("ph_features.zig").PhFeatures;
const Feature = @import("features.zig").Feature;

test "find simple sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    const ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = 68440605, .mnsMsk = 453741762 } };
    const sound = phonemeSound(ph, a);
    try expect(memeq(u8, sound, "ɒ"));
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
}

test "find sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);

    const sound = phonemeSound(ph, a);
    try expect(memeq(u8, sound, "n̥"));

    // clean
    a.free(sound);
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
}
