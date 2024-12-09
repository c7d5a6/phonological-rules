pub fn bitCnt(u: u32) u32 {
    var x = u;
    var n: u32 = 0;
    while (x > 0) {
        n += 1;
        x &= x - 1;
    }
    return n;
}

const expect = @import("std").testing.expect;

test "bit count" {
    const n: u32 = 0b11100011100011100011100011100011;
    try expect(bitCnt(n) == 17);
}
