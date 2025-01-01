const std = @import("std");

pub const Context = struct {
    session: ?Session = null,
};
// note: it MUST have all default values!!!
// This is so that it can be constructed via .{}
// as we can't expect the listener to know how to initialize our context structs
// Just some arbitrary struct we want in the per-request context
// note: it MUST have all default values!!!
pub const Session = struct {
    info: []const u8 = undefined,
    token: []const u8 = undefined,
};

// just a way to share our allocator via callback
pub const SharedAllocator = struct {
    // static
    var allocator: std.mem.Allocator = undefined;

    const Self = @This();

    // just a convenience function
    pub fn init(a: std.mem.Allocator) void {
        allocator = a;
    }

    // static function we can pass to the listener later
    pub fn getAllocator() std.mem.Allocator {
        return allocator;
    }
};
