const Feature = @import("features.zig").Feature;
const assert = @import("std").debug.assert;
const bitCnt = @import("./utils/bits.zig").bitCnt;

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

    pub fn addFtr(self: *PhFeatures, f: Feature) void {
        self.plsMsk |= f.mask();
        self.mnsMsk &= ~f.mask();
        // TODO: disable features?
    }

    pub fn removeFtr(self: *PhFeatures, f: Feature) void {
        self.mnsMsk |= f.mask();
        self.plsMsk &= ~f.mask();
        // TODO: disable features?
    }

    pub fn disableFtr(self: *PhFeatures, f: Feature) void {
        self.plsMsk &= ~f.mask();
        self.mnsMsk &= ~f.mask();
    }

    pub fn applyChange(self: PhFeatures, change: PhFeatures) PhFeatures {
        var p = self.plsMsk;
        var m = self.mnsMsk;
        p |= change.plsMsk;
        p &= ~change.mnsMsk;
        m |= change.mnsMsk;
        m &= ~change.plsMsk;
        return PhFeatures{ .plsMsk = p, .mnsMsk = m };
    }

    pub fn eql(self: PhFeatures, phf: PhFeatures) bool {
        return self.plsMsk == phf.plsMsk and self.mnsMsk == self.mnsMsk;
    }

    pub fn dist(self: PhFeatures, phf: PhFeatures) u32 {
        return bitCnt(self.plsMsk ^ phf.plsMsk) + bitCnt(self.mnsMsk ^ phf.mnsMsk);
    }
};

const testing = @import("std").testing;
// const memeq = @import("std").mem.eql;
// const GeneralPA = @import("std").heap.GeneralPurposeAllocator;
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
