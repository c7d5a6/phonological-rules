const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const cmnFtr = @import("sounds/ph_features.zig").commonFeatures;
const dstFtr = @import("sounds/ph_features.zig").distinctiveFeatures;
pub const Rule = @import("matchers/rule.zig").Rule;
pub const SoundLexer = @import("parser/sound_lexer.zig").SoundLexer;
pub const SoundToken = @import("parser/sound_lexer.zig").SoundToken;
pub const find_match = @import("matchers/matcher.zig").find_match;
const StrArray = @import("sounds/ph_features.zig").StrArray;
const ResultRule = @import("ffi_types.zig").ResultRule;
const Result = @import("ffi_types.zig").Result;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
const a: std.mem.Allocator = if (builtin.is_test)
    std.testing.allocator
else switch (builtin.mode) {
    .Debug => debug_allocator.allocator(),
    else => std.heap.smp_allocator,
};

export fn version() [*:0]const u8 {
    const str: [*:0]const u8 = @ptrCast(config.version);
    return str;
}

const FeaturesResult = extern struct {
    features: [*:0]const u8,
    export fn destroy(self: FeaturesResult) void {
        destroyStr(self.features);
    }
};

export fn commonFeatures(input: [*:0]const u8) FeaturesResult {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result: StrArray = cmnFtr(a, input[0..len]) catch unreachable;
    defer result.deinit(a);

    const ar = a.allocSentinel(u8, result.items.len, 0) catch unreachable;
    @memcpy(ar, result.items);

    const str: [*:0]const u8 = @ptrCast(ar);
    return .{ .features = str };
}

export fn distinctiveFeatures(input: [*:0]const u8) [*:0]const u8 {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result: StrArray = dstFtr(a, input[0..len]) catch unreachable;
    defer result.deinit(a);

    const ar = a.allocSentinel(u8, result.items.len, 0) catch unreachable;
    @memcpy(ar, result.items);

    const str: [*:0]const u8 = @ptrCast(ar);
    return str;
}

export fn destroyStr(input: [*:0]const u8) void {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}
    const array: []const u8 = input[0 .. len + 1];

    a.free(array);
}

export fn createRule(input: [*:0]const u8) *ResultRule {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var rr = a.create(ResultRule) catch unreachable;
    const e_rule = Rule.init(a, input[0..len]);

    if (e_rule) |r| {
        const rule_ptr = a.create(Rule) catch unreachable;
        rule_ptr.* = r;
        rr.rule = rule_ptr;
        rr.is_error = false;
    } else |_| {
        rr.is_error = true;
        rr.rule = null;
    }

    return rr;
}

export fn destroyRule(rrule: *ResultRule) void {
    if (rrule.rule) |r| {
        r.destroy();
        a.destroy(r);
    }
    a.destroy(rrule);
}

export fn applyRule(input: [*:0]const u8, rule: *Rule) *Result {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result = a.create(Result) catch unreachable;
    const e_res_srt = rule.apply(a, input[0..len]);

    if (e_res_srt) |res| {
        result.is_error = false;
        result.result = res.ptr;
    } else |_| {
        result.is_error = true;
        result.result = null;
    }
    return result;
}

export fn destroyRuleResult(result: *Result) void {
    if (result.result) |res| {
        destroyStr(res);
    }
    a.destroy(result);
}

test "new string" {
    const res = commonFeatures("abc");
    defer destroyStr(res.features);
}

test "destroyRule frees a successful rule" {
    const rr = createRule("[+voice -syllabic]>[-voice]");
    defer destroyRule(rr);
    try std.testing.expect(!rr.is_error);
    try std.testing.expect(rr.rule != null);
}

test "destroyRule frees a failed create" {
    const rr = createRule("[+voice]>[-voice][]");
    defer destroyRule(rr);
    try std.testing.expect(rr.is_error);
    try std.testing.expectEqual(null, rr.rule);
}

test "create apply destroy pairing and reuse" {
    const rr = createRule("[+voice -syllabic][-voice]>[-voice][]");
    defer destroyRule(rr);
    try std.testing.expect(!rr.is_error);
    try std.testing.expect(rr.rule != null);

    const first = applyRule("pods", rr.rule.?);
    defer destroyRuleResult(first);
    try std.testing.expect(!first.is_error);
    try std.testing.expect(first.result != null);
    try std.testing.expectEqualStrings("pots", std.mem.span(first.result.?));

    const second = applyRule("riabt͡ʃik", rr.rule.?);
    defer destroyRuleResult(second);
    try std.testing.expect(!second.is_error);
    try std.testing.expect(second.result != null);
    try std.testing.expectEqualStrings("riapt͡ʃik", std.mem.span(second.result.?));
}

test "version" {
    // std.debug.print("* * * version {any}", .{config.version});
}

test {
    _ = @import("ffi_types.zig");
    _ = @import("matchers/rule.zig");
    _ = @import("matchers/rule_tests.zig");
    _ = @import("matchers/rule_fuzz.zig");
    std.testing.refAllDecls(@This());
    // or refAllDeclsRecursive
}
