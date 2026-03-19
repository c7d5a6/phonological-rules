const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const cmnFtr = @import("sounds/ph_features.zig").commonFeatures;
const dstFtr = @import("sounds/ph_features.zig").distinctiveFeatures;
const Rule = @import("matchers/rule.zig").Rule;
const StrArray = @import("sounds/ph_features.zig").StrArray;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const a: std.mem.Allocator = if (builtin.is_test)
    std.testing.allocator
else if (builtin.mode == .Debug) gpa.allocator() else gpa.allocator();

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

const ResultRule = struct {
    is_error: bool,
    rule: ?*Rule,
};

export fn createRule(input: [*:0]const u8) *ResultRule {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var rr = a.create(ResultRule) catch unreachable;
    const e_rule = Rule.init(input[0..len]);

    if (e_rule) |r| {
        const rule_ptr = a.create(Rule) catch unreachable;
        rule_ptr.* = r;
        rr.rule = rule_ptr;
        rr.is_error = false;
    } else |_| {
        rr.is_error = true;
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

const Result = struct {
    is_error: bool,
    result: ?[*:0]const u8,
};

export fn applyRule(input: [*:0]const u8, rule: *Rule) *Result {
    var len: u64 = 0;
    while (input[len] != 0) : (len += 1) {}

    var result = a.create(Result) catch unreachable;
    const e_res_srt = rule.apply(a, input[0..len]);

    if (e_res_srt) |res| {
        const result_str = a.allocSentinel(u8, res.len, 0) catch unreachable;
        @memcpy(result_str, res);

        const str_prt: [*:0]const u8 = @ptrCast(result_str);
        result.is_error = false;
        result.result = str_prt;
    } else |_| {
        result.is_error = false;
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

test "version" {
    // std.debug.print("* * * version {any}", .{config.version});
}

test {
    _ = @import("matchers/rule.zig");
    std.testing.refAllDeclsRecursive(@This());
    // or refAllDeclsRecursive
}
