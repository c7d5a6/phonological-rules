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

pub fn isWhitespace(smb: []const u8) bool {
    for (whilespaces) |ws| {
        if (ws.len == smb.len and std.mem.eql(u8, ws, smb)) {
            return true;
        }
    }
    return false;
}
