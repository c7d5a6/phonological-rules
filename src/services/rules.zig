const std = @import("std");
const Context = @import("../middle/context.zig").Context;
const Rule = @import("../matchers/rule.zig").Rule;
const ResultRule = @import("../ffi_types.zig").ResultRule;
const Result = @import("../ffi_types.zig").Result;

extern fn createRule(input: [*:0]const u8) *ResultRule;
extern fn destroyRule(rrule: *ResultRule) void;

extern fn applyRule(input: [*:0]const u8, rule: *Rule) *Result;
extern fn destroyRuleResult(result: *Result) void;

pub fn on_apply_rule(ctx: *Context) !void {
    var arena = std.heap.ArenaAllocator.init(ctx.shared.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var body_buf: [16 * 1024]u8 = undefined;
    const body = try ctx.request.body().copyTo(&body_buf);

    const ApplyRule = struct { rule: []const u8, str: []const u8 };
    const apply_rule = std.json.parseFromSliceLeaky(ApplyRule, a, body, .{}) catch return error.InvalidInput;
    if (!std.unicode.utf8ValidateSlice(apply_rule.rule) or
        !std.unicode.utf8ValidateSlice(apply_rule.str))
    {
        return error.InvalidUtf8;
    }
    const rule_str = try a.dupeSentinel(u8, apply_rule.rule, 0);
    const str = try a.dupeSentinel(u8, apply_rule.str, 0);

    const rrule = createRule(rule_str);
    defer destroyRule(rrule);
    if (rrule.is_error or rrule.rule == null) return error.InvalidRule;

    const result = applyRule(str, rrule.rule.?);
    defer destroyRuleResult(result);
    if (result.is_error or result.result == null) return error.InvalidInput;

    return ctx.response.text(200, std.mem.span(result.result.?));
}
