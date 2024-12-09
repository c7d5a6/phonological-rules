const assert = @import("std").debug.assert;
const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const Feature = @import("features.zig").Feature;
const consts = @import("constants/phonemes.zig");
const bitCnt = @import("./utils/bits.zig").bitCnt;

pub const Phoneme = struct {
    orig: ?[:0]const u8 = null,
    ftrs: PhFeatures,

    pub fn sound(self: *Phoneme, a: Allocator) [:0]const u8 {
        if (self.orig) |s| return s;
        self.orig = findSound(self.*);
        return self.orig.?;
    }
};

fn findSound(ph: Phoneme) [:0]const u8 {
    for (phonemes) |phc| {
        if (ph.ftrs.eql(phc.ftrs)) return phc.orig.?;
        // for(
    }
    unreachable;
}

pub const PhFeatures = struct {
    plsMsk: u32 = 0,
    mnsMsk: u32 = 0,

    fn setPlsMask(self: *PhFeatures, mask: u32) void {
        assert(self.mnsMsk & mask == 0);
        self.plsMsk = mask;
    }

    fn setMnsMask(self: *PhFeatures, mask: u32) void {
        assert(self.plsMsk & mask == 0);
        self.mnsMsk = mask;
    }

    fn addFtr(self: *PhFeatures, f: Feature) void {
        self.plsMsk |= f.mask();
        self.mnsMsk &= ~f.mask();
        // TODO: disable features?
    }

    fn removeFtr(self: *PhFeatures, f: Feature) void {
        self.mnsMsk |= f.mask();
        self.plsMsk &= ~f.mask();
        // TODO: disable features?
    }

    fn disableFtr(self: *PhFeatures, f: Feature) void {
        self.plsMsk &= ~f.mask();
        self.mnsMsk &= ~f.mask();
    }

    fn eql(self: PhFeatures, phf: PhFeatures) bool {
        return self.plsMsk == phf.plsMsk and self.mnsMsk == self.mnsMsk;
    }

    fn dist(self: PhFeatures, phf: PhFeatures) u32 {
        return bitCnt(self.plsMsk ^ phf.plsMsk) + bitCnt(self.mnsMsk ^ phf.mnsMsk);
    }
};

const phonemes: [consts.featureTable.len]Phoneme = res: {
    @setEvalBranchQuota(100000);
    var phs: [consts.featureTable.len]Phoneme = undefined;
    for (consts.featureTable, 0..) |ft, i| {
        const phf = consts.getPhonemes(ft);
        phs[i] = Phoneme{ .orig = ft.snd, .ftrs = PhFeatures{ .plsMsk = phf.p, .mnsMsk = phf.m } };
    }
    break :res phs;
};

const testing = @import("std").testing;
const expect = testing.expect;

test "addFtr" {
    var phf = PhFeatures{ .plsMsk = 0, .mnsMsk = 1 };
    phf.addFtr(Feature.syllabic);
    try expect(phf.plsMsk == 1);
    try expect(phf.mnsMsk == 0);
}

test "removeFtr" {
    var phf = PhFeatures{ .plsMsk = 1, .mnsMsk = 0 };
    phf.removeFtr(Feature.syllabic);
    try expect(phf.plsMsk == 0);
    try expect(phf.mnsMsk == 1);
}

test "disable ftr" {
    var phf = PhFeatures{ .plsMsk = 1, .mnsMsk = 3 };
    phf.disableFtr(Feature.syllabic);
    phf.disableFtr(Feature.consonantal);
    try expect(phf.plsMsk == 0);
    try expect(phf.mnsMsk == 0);
}

test "distance" {
    const phf1 = PhFeatures{ .plsMsk = 0b1010, .mnsMsk = 0b0101 };
    const phf2 = PhFeatures{ .plsMsk = 0b1000, .mnsMsk = 0b0100 };
    try expect(phf1.dist(phf1) == 0);
    try expect(phf1.dist(phf2) == 2);
}

test "consts" {
    // print("Const {?s} with masks \np{b} \nm{b}", .{ phonemes[0].original, phonemes[0].features.plsMsk, phonemes[0].features.mnsMsk });
    print("Number of constants symbols are {d} with size {d}\n", .{ phonemes.len, @sizeOf(Phoneme) * phonemes.len });
    print("{any}\n", .{phonemes[0]});
    for (phonemes) |ph| {
        try expect(ph.ftrs.plsMsk & ph.ftrs.mnsMsk == 0);
    }
}

test "find simple sound" {
    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = 68440605, .mnsMsk = 453741762 } };
    print("Sound of mask is {s}\n", .{ph.sound()});
}
