const std = @import("std");

const whilespaces = [_][]const u8{
    "\u{0009}", //     0009..000D    ; White_Space # Cc   <control-0009>..<control-000D>
    "\u{000A}", // --/--
    "\u{000B}", // --/--
    "\u{000C}", // --/--
    "\u{000D}", // --/--
    "\u{0020}", //     0020          ; White_Space # Zs   SPACE
    "\u{0085}", //     0085          ; White_Space # Cc   <control-0085>
    "\u{00A0}", //     00A0          ; White_Space # Zs   NO-BREAK SPACE
    "\u{1680}", //     1680          ; White_Space # Zs   OGHAM SPACE MARK
    "\u{2000}", //     2000..200A    ; White_Space # Zs   EN QUAD..HAIR SPACE
    "\u{2001}", // --/--
    "\u{2002}", // --/--
    "\u{2003}", // --/--
    "\u{2004}", // --/--
    "\u{2005}", // --/--
    "\u{2006}", // --/--
    "\u{2007}", // --/--
    "\u{2008}", // --/--
    "\u{2009}", // --/--
    "\u{200A}", // --/--
    "\u{2028}", //     2028          ; White_Space # Zl   LINE SEPARATOR
    "\u{2029}", //     2029          ; White_Space # Zp   PARAGRAPH SEPARATOR
    "\u{202F}", //     202F          ; White_Space # Zs   NARROW NO-BREAK SPACE
    "\u{205F}", //     205F          ; White_Space # Zs   MEDIUM MATHEMATICAL SPACE
    "\u{3000}", //     3000          ; White_Space # Zs   IDEOGRAPHIC SPACE
    "\u{FEFF}", //     FEFF          ; BOM                ZERO WIDTH NO_BREAK SPACE
};

const dcrts = @import("../sounds/phoneme.zig").diacritics;
const diacritics: [dcrts.len][]const u8 = dr: {
    var res: [dcrts.len][]const u8 = undefined;
    for (&res, 0..) |*r, i| {
        r.* = dcrts[i].orig orelse unreachable;
    }
    break :dr res;
};

fn isSmth(T: type, smb: []const u8, arr: T) bool {
    for (arr) |a| {
        if (a.len == smb.len and std.mem.eql(u8, a, smb)) {
            return true;
        }
    }
    return false;
}

pub fn isWhitespace(smb: []const u8) bool {
    return isSmth(@TypeOf(whilespaces), smb, whilespaces);
}

pub fn isDiacritics(smb: []const u8) bool {
    return isSmth(@TypeOf(diacritics), smb, diacritics);
}

pub fn isAffricateSymbol(smb: []const u8) bool {
    const s = "\u{0361}";
    return (s.len == smb.len and std.mem.eql(u8, s, smb));
}
