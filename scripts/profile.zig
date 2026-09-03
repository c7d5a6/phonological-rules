const std = @import("std");
const assert = std.debug.assert;
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Rule = @import("ph").Rule;
const SoundLexer = @import("ph").SoundLexer;
const SoundToken = @import("ph").SoundToken;
const find_match = @import("ph").find_match;

const parse_iters: u32 = 20_000;
const match_iters: u32 = 20_000;
const apply_iters: u32 = 2_000;
const warmup_iters: u32 = 8;

const Case = struct {
    name: []const u8,
    input: []const u8,
    rule: []const u8,
};

const long_input = "tanatanatanatanatana" ** 8;

const cases = [_]Case{
    .{
        .name = "short",
        .input = "pods",
        .rule = "[+voice -syllabic][-voice]>[-voice][]",
    },
    .{
        .name = "affricate",
        .input = "riabt͡ʃik",
        .rule = "[+voice -syllabic][-voice]>[-voice][]",
    },
    .{
        .name = "astar",
        .input = "papapapapapapapa",
        .rule = "p>[+voice]",
    },
    .{
        .name = "long",
        .input = long_input,
        .rule = "[+syllabic][+nasal]>[+nasal][]",
    },
};

pub fn main(init: std.process.Init) !void {
    const a = init.gpa;
    const io = init.io;
    var out_buf: [4096]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &out_buf);
    const w = &stdout.interface;

    try w.print("optimize={t}  clock=awake\n", .{@import("builtin").mode});
    try printRow(w, "corpus", "phase", "iters", "ns/op");

    for (cases) |case| {
        try timeSoundParse(io, w, case);
        try timeRuleParse(a, io, w, case);
        try timeMatch(a, io, w, case);
        try timeApply(a, io, w, case);
    }
    try w.flush();
}

fn elapsedNs(io: Io, start: Io.Timestamp) u64 {
    const d = start.durationTo(Io.Clock.awake.now(io));
    assert(d.nanoseconds >= 0);
    return @intCast(d.nanoseconds);
}

fn nsPerOp(total_ns: u64, iters: u32) u64 {
    assert(iters > 0);
    return total_ns / iters;
}

fn timeSoundParse(io: Io, w: *Io.Writer, case: Case) !void {
    var i: u32 = 0;
    while (i < warmup_iters) : (i += 1) {
        drainSound(case.input);
    }
    const start = Io.Clock.awake.now(io);
    i = 0;
    while (i < parse_iters) : (i += 1) {
        drainSound(case.input);
    }
    try printNs(w, case.name, "sound parse", parse_iters, nsPerOp(elapsedNs(io, start), parse_iters));
}

fn drainSound(input: []const u8) void {
    var lexer = SoundLexer.init(input);
    var n: usize = 0;
    while (lexer.nextToken() catch return) |_| {
        n += 1;
    }
    std.mem.doNotOptimizeAway(n);
}

fn timeRuleParse(a: Allocator, io: Io, w: *Io.Writer, case: Case) !void {
    var i: u32 = 0;
    while (i < warmup_iters) : (i += 1) {
        try parseDestroy(a, case.rule);
    }
    const start = Io.Clock.awake.now(io);
    i = 0;
    while (i < parse_iters) : (i += 1) {
        try parseDestroy(a, case.rule);
    }
    try printNs(w, case.name, "rule parse", parse_iters, nsPerOp(elapsedNs(io, start), parse_iters));
}

fn parseDestroy(a: Allocator, rule_str: []const u8) !void {
    var rule = try Rule.init(a, rule_str);
    rule.destroy();
}

fn timeMatch(a: Allocator, io: Io, w: *Io.Writer, case: Case) !void {
    var sounds = try parseSounds(a, case.input);
    defer sounds.deinit(a);
    var rule = try Rule.init(a, case.rule);
    defer rule.destroy();

    var i: u32 = 0;
    while (i < warmup_iters) : (i += 1) {
        std.mem.doNotOptimizeAway(find_match(sounds.items, 0, rule.match.items));
    }
    const start = Io.Clock.awake.now(io);
    i = 0;
    while (i < match_iters) : (i += 1) {
        std.mem.doNotOptimizeAway(find_match(sounds.items, 0, rule.match.items));
    }
    try printNs(w, case.name, "match", match_iters, nsPerOp(elapsedNs(io, start), match_iters));
}

fn parseSounds(a: Allocator, input: []const u8) !std.ArrayList(SoundToken) {
    var sounds: std.ArrayList(SoundToken) = try .initCapacity(a, input.len);
    var lexer = SoundLexer.init(input);
    while (try lexer.nextToken()) |t| {
        try sounds.append(a, t);
    }
    return sounds;
}

fn timeApply(a: Allocator, io: Io, w: *Io.Writer, case: Case) !void {
    var rule = try Rule.init(a, case.rule);
    defer rule.destroy();
    var i: u32 = 0;
    while (i < warmup_iters) : (i += 1) {
        try applyFree(a, &rule, case.input);
    }
    const start = Io.Clock.awake.now(io);
    i = 0;
    while (i < apply_iters) : (i += 1) {
        try applyFree(a, &rule, case.input);
    }
    try printNs(w, case.name, "apply", apply_iters, nsPerOp(elapsedNs(io, start), apply_iters));
}

fn applyFree(a: Allocator, rule: *Rule, input: []const u8) !void {
    const out = try rule.apply(a, input);
    defer a.free(out);
    std.mem.doNotOptimizeAway(out.len);
}

fn printNs(
    w: *Io.Writer,
    corpus: []const u8,
    phase: []const u8,
    iters: u32,
    ns_op: u64,
) !void {
    var iters_buf: [16]u8 = undefined;
    var ns_buf: [16]u8 = undefined;
    const iters_s = try std.fmt.bufPrint(&iters_buf, "{d}", .{iters});
    const ns_s = try std.fmt.bufPrint(&ns_buf, "{d}", .{ns_op});
    try printRow(w, corpus, phase, iters_s, ns_s);
}

fn printRow(
    w: *Io.Writer,
    corpus: []const u8,
    phase: []const u8,
    iters: []const u8,
    ns_op: []const u8,
) !void {
    try w.print("{s:<10} {s:<12} {s:>8} {s:>8}\n", .{ corpus, phase, iters, ns_op });
}
