const print = @import("std").debug.print;
const assert = @import("std").debug.assert;
const Allocator = @import("std").mem.Allocator;
const Feature = @import("features.zig").Feature;
const phfeatures = @import("ph_features.zig");
const PhFeatures = phfeatures.PhFeatures;
const consts = @import("constants/phonemes.zig");

pub const Phoneme = struct {
    orig: ?[:0]const u8 = null,
    ftrs: PhFeatures,
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
