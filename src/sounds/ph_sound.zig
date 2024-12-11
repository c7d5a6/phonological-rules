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

    // for (phonemes) |phc| {
    //     if (ph.ftrs.eql(phc.ftrs)) return phc.orig.?;
    //     for (diacritics) |d| {
    //         const newSet = phc.ftrs.applyChange(d.ftrs);
    //         if (ph.ftrs.eql(newSet)) {
    //             const phc_len = if (phc.orig) |s| s.len else 0;
    //             const d_len = if (d.orig) |s| s.len else 0;
    //             var sound = a.allocSentinel(u8, phc_len + d_len, 0) catch unreachable;
    //             if (phc.orig) |s|
    //                 @memcpy(sound[0..phc_len], s);
    //             if (d.orig) |s|
    //                 @memcpy(sound[phc_len..], s);
    //             return sound;
    //         }
    //     }
    // }
    // unreachable;
    return a_star(ph, a);
}

const QueueContext = struct { dest: PhFeatures };
const QueueMember = struct {
    f: PhFeatures,
    cost: u32,
    from: ?*const QueueMember = null,
    sound: [:0]const u8,
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

    var heap = PriorityQueue.init(a, QueueContext{ .dest = dest });
    defer heap.deinit();

    var visited = VisitedList.init(a);
    defer visited.deinit();

    for (phonemes) |phc| {
        const itm = QueueMember{ .f = phc.ftrs, .cost = 1, .sound = phc.orig orelse unreachable };
        if (phc.ftrs.eql(dest)) return parseSound(null, phc.orig orelse unreachable, a);
        heap.add(itm) catch unreachable;
    }

    while (heap.removeOrNull()) |itm| {
        const edge_ptr = visited.addOne() catch unreachable;
        edge_ptr.* = itm;
        const edge = edge_ptr.*;
        print("heap  {any} \n", .{heap.peek()});
        print("heap remove {*} \n", .{edge_ptr});
        print("visited heap {b}/{b} with sound {s}\n", .{ edge.f.plsMsk, edge.f.mnsMsk, parseSound(&edge, "", a) });
        d_loop: for (diacritics) |d| {
            print("{s} :d\n", .{d.orig.?});
            const next = edge.f.applyChange(d.ftrs);
            for (visited.items) |v| {
                if (next.eql(v.f)) continue :d_loop;
            }
            print("not visited\n", .{});
            if (next.eql(dest)) return parseSound(&edge, d.orig orelse unreachable, a);
            print("not dest\n", .{});
            for (heap.items) |h| {
                if (next.eql(h.f)) continue :d_loop;
            }
            print("not in heap\n", .{});
            print("add cost {d}\n", .{1 + edge.cost});
            print("add edge {any}\n", .{edge});
            const new = QueueMember{ .f = next, .cost = 1 + edge.cost, .from = edge_ptr, .sound = d.orig orelse unreachable };
            print("add new {any}\n", .{new});
            heap.add(new) catch unreachable;
            print("*peek heap {any}\n", .{heap.peek()});
            print("put in heap\n", .{});
        }
        print("**** ended cycle put in heap\n", .{});
        print("*peek heap {any}\n", .{heap.peek()});
    }
    unreachable;
}

fn parseSound(orig: ?*const QueueMember, last: [:0]const u8, a: Allocator) [:0]const u8 {
    print("parse sound \n", .{});
    var temp = orig;
    var length = last.len;
    while (temp) |qm| {
        temp = qm.from;
        // print("qm sound {s}\n", .{qm.sound});
        length += qm.sound.len;
    }
    var sound = a.allocSentinel(u8, length, 0) catch unreachable;
    temp = orig;
    var end = length;
    var start = length - last.len;
    @memcpy(sound[start..end], last);
    end = start;
    while (temp) |qm| {
        temp = qm.from;
        start = end - qm.sound.len;
        @memcpy(sound[start..end], qm.sound);
        end = start;
    }

    return sound;
}

const testing = @import("std").testing;
const memeq = @import("std").mem.eql;
const GeneralPA = @import("std").heap.GeneralPurposeAllocator;
const expect = testing.expect;
const PhFeatures = @import("ph_features.zig").PhFeatures;
const Feature = @import("features.zig").Feature;
const print = std.debug.print;

test "find simple sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    const ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = 68440605, .mnsMsk = 453741762 } };
    const sound = phonemeSound(ph, a);

    print("sound {s}", .{sound});
    try expect(memeq(u8, sound, "ɒ"));
    a.free(sound);
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
}

test "find sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);
    ph.ftrs.removeFtr(Feature.constricted_glottis);
    ph.ftrs.addFtr(Feature.spread_glottis);

    const sound = phonemeSound(ph, a);
    print("sound {s}", .{sound});
    try expect(memeq(u8, sound, "n̥"));

    // clean
    a.free(sound);
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
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
