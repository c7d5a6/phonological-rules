const std = @import("std");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

const lexer = @import("parser/sound_lexer.zig");
const phonemeSound = @import("sounds/ph_sound.zig").phonemeSound;

test "test" {
    _ = lexer;
}

test "change sounds" {
    const in = "namodatiei aɳd gʰ'eːwHeti";
    std.debug.print("Converted: {s}\n", .{in});
    std.debug.print("     into: ", .{});

    var lxr = lexer.SoundLexer.init(in);

    while (try lxr.nextToken()) |t| {
        switch (t.type) {
            .Whitespace => std.debug.print(" ", .{}),
            .Diacritic => std.debug.print("*", .{}),
            .Phoneme => {
                var nPh = t.ph.?.copy();
                if (nPh.ftrs.hasM(.syllabic)) {
                    nPh.ftrs.removeFtr(.voice);
                    nPh.ftrs.removeFtr(.coronal);
                    nPh.ftrs.addFtr(.labial);
                } else {
                    nPh.ftrs.removeFtr(.front);
                }
                const sound = phonemeSound(nPh, std.testing.allocator);
                std.debug.print("{s}", .{sound});
                std.testing.allocator.free(sound);
            },
        }
    }
    std.debug.print("\n\n\n", .{});
}
