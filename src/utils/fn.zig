const eql = @import("std").mem.eql;

pub fn eq(a: ?[]const u8, b: []const u8) bool {
    if (a == null) return false;
    if (a.?.len != b.len) return false;
    return eql(u8, a.?, b);
}
