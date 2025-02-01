const std = @import("std");
const Feature = @import("features.zig").Feature;
const features = @import("features.zig").features;
const assert = @import("std").debug.assert;
const bitCnt = @import("./utils/bits.zig").bitCnt;
const SoundLexer = @import("../parser/sound_lexer.zig").SoundLexer;

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

    pub fn hasP(self: PhFeatures, f: Feature) bool {
        return 0 != self.plsMsk & f.mask();
    }

    pub fn hasM(self: PhFeatures, f: Feature) bool {
        return 0 != self.mnsMsk & f.mask();
    }

    pub fn addFtr(self: *PhFeatures, f: Feature) void {
        self.plsMsk |= f.mask();
        self.mnsMsk &= ~f.mask();
        // TODO: disable features?
    }

    pub fn removeFtr(self: *PhFeatures, f: Feature) void {
        self.mnsMsk |= f.mask();
        self.plsMsk &= ~f.mask();
        switch (f) {
            .dorsal => {
                self.disableFtr(Feature.high);
                self.disableFtr(Feature.low);
                self.disableFtr(Feature.front);
                self.disableFtr(Feature.back);
            },
            .coronal => {
                self.disableFtr(Feature.anterior);
                self.disableFtr(Feature.distributed);
                self.disableFtr(Feature.strident);
            },
            else => {},
        }
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

    pub fn contain(self: PhFeatures, phf: PhFeatures) bool {
        return ((self.plsMsk & phf.plsMsk) == phf.plsMsk) and ((self.mnsMsk & phf.mnsMsk) == phf.mnsMsk);
    }
};

pub const StrArray = std.ArrayList(u8);

pub fn commonFeatures(a: std.mem.Allocator, input: []const u8) !StrArray {
    var result = try commonFeatures_(input);
    var out = StrArray.init(a);
    var i: u64 = 0;
    while (i < features.len) {
        const f: Feature = @enumFromInt(i);
        var has = false;
        if (result.hasP(f)) {
            try out.appendSlice(if (out.items.len == 0) "+" else " +");
            has = true;
        }
        if (result.hasM(f)) {
            try out.appendSlice(if (out.items.len == 0) "-" else " -");
            has = true;
        }
        if (has) try out.appendSlice(@tagName(f));
        i += 1;
    }
    return out;
}

pub fn commonFeatures_(input: []const u8) !PhFeatures {
    var lexer = SoundLexer.init(input);
    var result = PhFeatures{ .mnsMsk = 0xFFFFFFFF, .plsMsk = 0xFFFFFFFF };
    while (try lexer.nextToken()) |t| {
        if (t.type == .Phoneme) {
            result.plsMsk = result.plsMsk & t.ph.?.ftrs.plsMsk;
            result.mnsMsk = result.mnsMsk & t.ph.?.ftrs.mnsMsk;
        }
    }
    return result;
}

pub fn distinctiveFeatures(a: std.mem.Allocator, input: []const u8) !StrArray {
    var result = try distinctiveFeatures_(input);
    var out = StrArray.init(a);
    var i: u64 = 0;
    while (i < features.len) {
        const f: Feature = @enumFromInt(i);
        if (result.hasP(f) and result.hasM(f)) {
            if (out.items.len != 0) try out.appendSlice(" ");
            try out.appendSlice(@tagName(f));
        }
        i += 1;
    }
    return out;
}

fn distinctiveFeatures_(input: []const u8) !PhFeatures {
    var lexer = SoundLexer.init(input);
    var rAnd = PhFeatures{ .mnsMsk = 0xFFFFFFFF, .plsMsk = 0xFFFFFFFF };
    var rOr = PhFeatures{ .mnsMsk = 0x00000000, .plsMsk = 0x00000000 };
    var init = false;
    while (try lexer.nextToken()) |t| {
        if (t.type == .Phoneme) {
            if (!init) {
                result = t.ph;
                init = true;
            }
            result.plsMsk = result.plsMsk ^ t.ph.?.ftrs.plsMsk;
            result.mnsMsk = result.mnsMsk ^ t.ph.?.ftrs.mnsMsk;
        }
    }
    return result;
}

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

test "comonFeatures" {
    const out = try commonFeatures(std.testing.allocator, "blkszt");
    defer out.deinit();

    std.debug.print("Common Features: {s}\n", .{out.items});
}

test "distinctiveFeatures" {
    const result1 = try distinctiveFeatures_("dt");
    const result2 = try distinctiveFeatures_("pt");
    const result3 = try distinctiveFeatures_("ptd");

    var i: u64 = 0;
    while (i < features.len) {
        const f: Feature = @enumFromInt(i);
        if (result1.hasP(f) or result2.hasP(f) or result3.hasP(f)) {
            std.debug.print("Distinctive feature +{s}: {any} {any} {any}\n", .{ @tagName(f), result1.hasP(f), result2.hasP(f), result3.hasP(f) });
        }
        if (result1.hasM(f) or result2.hasM(f) or result3.hasM(f)) {
            std.debug.print("Distinctive feature -{s}: {any} {any} {any}\n", .{ @tagName(f), result1.hasM(f), result2.hasM(f), result3.hasM(f) });
        }
        i += 1;
    }

    std.debug.print("Distinctive Features: {any}\n", .{result1});
    std.debug.print("Distinctive Features: {any}\n", .{result2});
    std.debug.print("Distinctive Features: {any}\n", .{result3});
}
