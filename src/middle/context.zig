const std = @import("std");
const web = @import("baz");

/// App-wide state, borrowed by every request as `ctx.shared`.
pub const Shared = struct {
    allocator: std.mem.Allocator,
};

/// Per-request state, available as `ctx.locals`. All fields need defaults.
pub const Locals = struct {};

pub const Application = web.AppWithLocals(Shared, Locals);
pub const Context = Application.Context;
