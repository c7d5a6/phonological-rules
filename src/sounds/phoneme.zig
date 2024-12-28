const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Feature = @import("features.zig").Feature;
const phfeatures = @import("ph_features.zig");
const PhFeatures = phfeatures.PhFeatures;
const consts = @import("constants/phonemes.zig");

pub const Phoneme = struct {
    const Self = @This();

    orig: ?[]const u8 = null,
    ftrs: PhFeatures,
    unknw: bool = false,

    pub fn setPhSound(ph: *Self, sound: []const u8) void {
        ph.orig = sound;
        for (phonemes) |p| {
            if (p.orig.?.len == sound.len and std.mem.eql(u8, p.orig.?, sound)) {
                ph.ftrs = p.ftrs;
                return;
            }
        }
        ph.unknw = true;
        ph.ftrs = PhFeatures{};
    }

    pub fn setSoundWithDiacritic(ph: *Self, sound: []const u8, diacritic: []const u8) void {
        if (ph.orig) |orig| {
            assert(std.mem.eql(u8, orig, sound[0..orig.len]));
        }
        ph.orig = sound;
        for (diacritics) |d| {
            if (d.orig.?.len == diacritic.len and std.mem.eql(u8, d.orig.?, diacritic)) {
                ph.ftrs = ph.ftrs.applyChange(d.ftrs);
                return;
            }
        }
        ph.unknw = true;
        ph.ftrs = PhFeatures{};
    }

    pub fn copy(ph: Self) Self {
        return Self{
            .orig = if (ph.unknw) ph.orig else null,
            .ftrs = ph.ftrs,
            .unknw = ph.unknw,
        };
    }

    pub fn applyChanges(ph: Self, change: PhFeatures) Self {
        return Self{
            .orig = if (ph.unknw) ph.orig else null,
            .ftrs = ph.ftrs.applyChange(change),
            .unknw = ph.unknw,
        };
    }
};

pub const phonemes: [consts.featureTable.len]Phoneme = ph_res: {
    @setEvalBranchQuota(100000);
    var phs: [consts.featureTable.len]Phoneme = undefined;
    for (consts.featureTable, 0..) |ft, i| {
        const phf = consts.getPhonemes(ft);
        phs[i] = Phoneme{ .orig = ft.snd, .ftrs = PhFeatures{ .plsMsk = phf.p, .mnsMsk = phf.m } };
    }
    break :ph_res phs;
};

pub const diacritics: [consts.diacriticTable.len]Phoneme = d_res: {
    @setEvalBranchQuota(100000);
    var phs: [consts.diacriticTable.len]Phoneme = undefined;
    for (consts.diacriticTable, 0..) |ft, i| {
        const phf = consts.getPhonemes(ft);
        phs[i] = Phoneme{ .orig = ft.snd, .ftrs = PhFeatures{ .plsMsk = phf.p, .mnsMsk = phf.m } };
    }
    break :d_res phs;
};

const testing = @import("std").testing;
const expect = testing.expect;

test "consts" {
    print("Number of constants symbols are {d} with size {d}\n", .{ phonemes.len, @sizeOf(Phoneme) * phonemes.len });
    print("{any}\n", .{phonemes[0]});
    for (phonemes) |ph| {
        try expect(ph.ftrs.plsMsk & ph.ftrs.mnsMsk == 0);
    }
    print("Number of constants diacritics are {d} with size {d}\n", .{ diacritics.len, @sizeOf(Phoneme) * diacritics.len });
    print("{any}\n", .{diacritics[0]});
    for (diacritics) |ph| {
        try expect(ph.ftrs.plsMsk & ph.ftrs.mnsMsk == 0);
    }
}
