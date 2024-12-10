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
        if (self.orig) |s| {
            var dest = a.allocSentinel(u8, s.len, 0) catch unreachable;
            @memcpy(dest[0..], s);
            return dest;
        }
        const found = findSound(self.*, a);
        return found;
    }
};

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

    fn applyChange(self: PhFeatures, change: PhFeatures) PhFeatures {
        var p = self.plsMsk;
        var m = self.mnsMsk;
        p |= change.plsMsk;
        p &= ~change.mnsMsk;
        m |= change.mnsMsk;
        m &= ~change.plsMsk;
        return PhFeatures{ .plsMsk = p, .mnsMsk = m };
    }

    fn eql(self: PhFeatures, phf: PhFeatures) bool {
        return self.plsMsk == phf.plsMsk and self.mnsMsk == self.mnsMsk;
    }

    fn dist(self: PhFeatures, phf: PhFeatures) u32 {
        return bitCnt(self.plsMsk ^ phf.plsMsk) + bitCnt(self.mnsMsk ^ phf.mnsMsk);
    }
};

const phonemes: [consts.featureTable.len]Phoneme = ph_res: {
    @setEvalBranchQuota(100000);
    var phs: [consts.featureTable.len]Phoneme = undefined;
    for (consts.featureTable, 0..) |ft, i| {
        const phf = consts.getPhonemes(ft);
        phs[i] = Phoneme{ .orig = ft.snd, .ftrs = PhFeatures{ .plsMsk = phf.p, .mnsMsk = phf.m } };
    }
    break :ph_res phs;
};

const diacritics: [consts.diacriticTable.len]Phoneme = d_res: {
    @setEvalBranchQuota(100000);
    var phs: [consts.diacriticTable.len]Phoneme = undefined;
    for (consts.diacriticTable, 0..) |ft, i| {
        const phf = consts.getPhonemes(ft);
        phs[i] = Phoneme{ .orig = ft.snd, .ftrs = PhFeatures{ .plsMsk = phf.p, .mnsMsk = phf.m } };
    }
    break :d_res phs;
};

const testing = @import("std").testing;
const memeq = @import("std").mem.eql;
const GeneralPA = @import("std").heap.GeneralPurposeAllocator;
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
    print("Number of constants diacritics are {d} with size {d}\n", .{ diacritics.len, @sizeOf(Phoneme) * diacritics.len });
    print("{any}\n", .{diacritics[0]});
    for (diacritics) |ph| {
        try expect(ph.ftrs.plsMsk & ph.ftrs.mnsMsk == 0);
    }
}

test "find simple sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = 68440605, .mnsMsk = 453741762 } };
    const sound = ph.sound(a);
    try expect(memeq(u8, sound, "ɒ"));
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
}

test "find sound" {
    var gpa = GeneralPA(.{}){};
    const a = gpa.allocator();

    var ph = Phoneme{ .ftrs = PhFeatures{ .plsMsk = phonemes[43].ftrs.plsMsk, .mnsMsk = phonemes[43].ftrs.mnsMsk } };
    ph.ftrs.removeFtr(Feature.voice);
    const sound = ph.sound(a);
    try expect(memeq(u8, sound, "n̥"));
    a.free(sound);
    const leaked = gpa.detectLeaks();
    try expect(!leaked);
}
