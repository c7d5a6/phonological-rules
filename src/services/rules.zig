const std = @import("std");
const Allocator = std.mem.Allocator;
const zap = @import("zap");
const Request = zap.Request;
const Context = @import("../middle/context.zig").Context;
const ControllerError = @import("../routes/router-errors.zig").ControllerError;
const Rule = @import("../matchers/rule.zig").Rule;

extern fn commonFeatures(input: [*:0]const u8) [*:0]const u8;

const ResultRule = struct {
    is_error: bool,
    rule: ?*Rule,
};

extern fn createRule(input: [*:0]const u8) *ResultRule;
extern fn destroyRule(rrule: *ResultRule) void;

const Result = struct {
    is_error: bool,
    result: ?[*:0]const u8,
};

extern fn applyRule(input: [*:0]const u8, rule: *Rule) *Result;
extern fn destroyRuleResult(result: *Result) void;

pub fn on_apply_rule(a: Allocator, r: Request, c: *Context, params: anytype) ControllerError!void {
    _ = params;
    _ = c;
    r.parseBody() catch return error.InternalError;
    const body = r.body orelse return error.InternalError;

    const ApplyRule = struct { rule: []const u8, str: []const u8 };
    const apply_rule = std.json.parseFromSlice(ApplyRule, a, body, .{}) catch return error.InternalError;
    const rule_str = a.allocSentinel(u8, apply_rule.value.rule.len, 0) catch unreachable;
    defer a.free(rule_str);
    @memcpy(rule_str[0..rule_str.len], apply_rule.value.rule);
    const str = a.allocSentinel(u8, apply_rule.value.str.len, 0) catch unreachable;
    defer a.free(str);
    @memcpy(str[0..str.len], apply_rule.value.str);

    const rrule = createRule(rule_str);
    std.debug.print("Rule \"{s}\" created {any}\n", .{rule_str, rrule});
    defer destroyRule(rrule);
    if (rrule.is_error or rrule.rule == null) {
        std.debug.print("Rule \"{s}\" is error\n", .{rule_str});
        r.sendError(error.InternalError, null, 401);
        return;
    }

    const result = applyRule(str, rrule.rule.?);
    defer destroyRuleResult(result);
    if (result.is_error or result.result == null) {
        r.sendError(error.InternalError, null, 401);
        return;
    }

    r.setContentType(.TEXT) catch return;
    var len: u64 = 0;
    while (result.result.?[len] != 0) : (len += 1) {}
    r.sendBody(result.result.?[0..len]) catch return;
}
