const std = @import("std");

pub const SoundRule = struct {};
pub fn compile_rule(source: [:0]const u8) SoundRule {}
pub fn new_sound(source: [:0]const u8, rule: SoundRule) [:0]const u8 {}
pub fn free_sound(source: [:0] const u8) void {}
pub fn free_rule(rule: SoundRule) void {}
