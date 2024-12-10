const Feature = @import("../features.zig").Feature;

const FeatureTableType = struct { snd: [:0]const u8, ftrTbl: *const [28:0]u8 };

//syllabic,stress,long,consonantal,sonorant,continuant,delayed_release,approximant,tap,trill,nasal,voice,spread_gl,constr_gl,LABIAL,round,labiodental,CORONAL,anterior,distributed,strident,lateral,DORSAL,high,low,front,back,tense
fn getFeature(i: comptime_int) Feature {
    return switch (i) {
        0 => Feature.syllabic,
        1 => Feature.stress,
        2 => Feature.long,
        3 => Feature.consonantal,
        4 => Feature.sonorant,
        5 => Feature.continuant,
        6 => Feature.delayed_release,
        7 => Feature.approximant,
        8 => Feature.tap,
        9 => Feature.trill,
        10 => Feature.nasal,
        11 => Feature.voice,
        12 => Feature.spread_glottis,
        13 => Feature.constricted_glottis,
        14 => Feature.labial,
        15 => Feature.round,
        16 => Feature.labiodental,
        17 => Feature.coronal,
        18 => Feature.anterior,
        19 => Feature.distributed,
        20 => Feature.strident,
        21 => Feature.lateral,
        22 => Feature.dorsal,
        23 => Feature.high,
        24 => Feature.low,
        25 => Feature.front,
        26 => Feature.back,
        27 => Feature.tense,
        else => unreachable,
    };
}

const Ftype = struct { p: u32, m: u32 };
pub fn getPhonemes(ftt: FeatureTableType) Ftype {
    var plusMask: u32 = 0;
    var minusMask: u32 = 0;
    for (ftt.ftrTbl, 0..) |fch, i| {
        const f = getFeature(i);
        switch (fch) {
            '+' => {
                plusMask |= f.mask();
            },
            '-' => {
                minusMask |= f.mask();
            },
            '0' => {},
            else => unreachable,
        }
    }
    return Ftype{ .p = plusMask, .m = minusMask };
}

pub const featureTable = [_]FeatureTableType{
    FeatureTableType{ .snd = "\u{0252}", .ftrTbl = "+---++0+---+--++--000-+-+-+0" }, //ɒ
    FeatureTableType{ .snd = "\u{0251}", .ftrTbl = "+---++0+---+------000-+-+-+0" }, //ɑ
    FeatureTableType{ .snd = "\u{0276}", .ftrTbl = "+---++0+---+--++--000-+-++-0" }, //ɶ
    FeatureTableType{ .snd = "\u{0061}", .ftrTbl = "+---++0+---+------000-+-+--0" }, //a
    FeatureTableType{ .snd = "\u{00E6}", .ftrTbl = "+---++0+---+------000-+-++-0" }, //æ
    FeatureTableType{ .snd = "\u{028C}", .ftrTbl = "+---++0+---+------000-+---+-" }, //ʌ
    FeatureTableType{ .snd = "\u{0254}", .ftrTbl = "+---++0+---+--++--000-+---+-" }, //ɔ
    FeatureTableType{ .snd = "\u{006F}", .ftrTbl = "+---++0+---+--++--000-+---++" }, //o
    FeatureTableType{ .snd = "\u{0264}", .ftrTbl = "+---++0+---+------000-+---++" }, //ɤ
    FeatureTableType{ .snd = "\u{0258}", .ftrTbl = "+---++0+---+------000-+----+" }, //ɘ
    FeatureTableType{ .snd = "\u{0153}", .ftrTbl = "+---++0+---+--++--000-+--+--" }, //œ
    FeatureTableType{ .snd = "\u{0259}", .ftrTbl = "+---++0+---+------000-+-----" }, //ə
    FeatureTableType{ .snd = "\u{0065}", .ftrTbl = "+---++0+---+------000-+--+-+" }, //e
    FeatureTableType{ .snd = "\u{025E}", .ftrTbl = "+---++0+---+--++--000-+-----" }, //ɞ
    FeatureTableType{ .snd = "\u{00F8}", .ftrTbl = "+---++0+---+--++--000-+--+-+" }, //ø
    FeatureTableType{ .snd = "\u{025B}", .ftrTbl = "+---++0+---+------000-+--+--" }, //ɛ
    FeatureTableType{ .snd = "\u{0275}", .ftrTbl = "+---++0+---+--++--000-+----+" }, //ɵ
    FeatureTableType{ .snd = "\u{026F}", .ftrTbl = "+---++0+---+------000-++--++" }, //ɯ
    FeatureTableType{ .snd = "\u{0075}", .ftrTbl = "+---++0+---+--++--000-++--++" }, //u
    FeatureTableType{ .snd = "\u{028A}", .ftrTbl = "+---++0+---+--++--000-++--+-" }, //ʊ
    FeatureTableType{ .snd = "\u{0268}", .ftrTbl = "+---++0+---+------000-++---+" }, //ɨ
    FeatureTableType{ .snd = "\u{0289}", .ftrTbl = "+---++0+---+--++--000-++---+" }, //ʉ
    FeatureTableType{ .snd = "\u{0079}", .ftrTbl = "+---++0+---+--++--000-++-+-+" }, //y
    FeatureTableType{ .snd = "\u{0069}", .ftrTbl = "+---++0+---+------000-++-+-+" }, //i
    FeatureTableType{ .snd = "\u{028F}", .ftrTbl = "+---++0+---+--++--000-++-+--" }, //ʏ
    FeatureTableType{ .snd = "\u{026A}", .ftrTbl = "+---++0+---+------000-++-+--" }, //ɪ
    FeatureTableType{ .snd = "ŋ+", .ftrTbl = "---++-0---++------000-++-+-0" }, //ŋ+
    FeatureTableType{ .snd = "\u{029F}", .ftrTbl = "---+++0+---+------000+++-+-0" }, //ʟ
    FeatureTableType{ .snd = "\u{026B}", .ftrTbl = "---+++0+---+-----++--++---+0" }, //ɫ
    FeatureTableType{ .snd = "\u{0274}", .ftrTbl = "---++-0---++------000-+---+0" }, //ɴ
    FeatureTableType{ .snd = "\u{0280}", .ftrTbl = "---+++0+-+-+------000-+---+0" }, //ʀ
    FeatureTableType{ .snd = "\u{0272}", .ftrTbl = "---++-0---++-----+-+--++-+-0" }, //ɲ
    FeatureTableType{ .snd = "\u{028E}", .ftrTbl = "---+++0+---+-----+-+-+++-+-0" }, //ʎ
    FeatureTableType{ .snd = "\u{014B}", .ftrTbl = "---++-0---++------000-++-000" }, //ŋ
    FeatureTableType{ .snd = "ŋ˗", .ftrTbl = "---++-0---++------000-++--+0" }, //ŋ˗
    // FeatureTableType{ .snd = "ʟ", .ftrTbl = "---+++0+---+------000+++-000" }, //ʟ
    FeatureTableType{ .snd = "ʟ̠", .ftrTbl = "---+++0+---+------000+++--+0" }, //ʟ̠
    FeatureTableType{ .snd = "\u{0273}", .ftrTbl = "---++-0---++-----+-----00000" }, //ɳ
    FeatureTableType{ .snd = "\u{0299}", .ftrTbl = "---+++0+-+-+--+---000--00000" }, //ʙ
    FeatureTableType{ .snd = "\u{026D}", .ftrTbl = "---+++0+---+-----+---+-00000" }, //ɭ
    FeatureTableType{ .snd = "\u{027A}", .ftrTbl = "---+++0++--+-----++--+-00000" }, //ɺ
    FeatureTableType{ .snd = "\u{027B}", .ftrTbl = "---+++0+---+-----+-----00000" }, //ɻ
    FeatureTableType{ .snd = "\u{027D}", .ftrTbl = "---+++0++--+-----+-----00000" }, //ɽ
    FeatureTableType{ .snd = "\u{0072}", .ftrTbl = "---+++0+-+-+-----++----00000" }, //r
    FeatureTableType{ .snd = "\u{006E}", .ftrTbl = "---++-0---++-----++----00000" }, //n
    FeatureTableType{ .snd = "\u{006D}", .ftrTbl = "---++-0---++--+---000--00000" }, //m
    FeatureTableType{ .snd = "l", .ftrTbl = "---+++0+---+-----++--+-00000" }, //l
    FeatureTableType{ .snd = "\u{027E}", .ftrTbl = "---+++0++--+-----++----00000" }, //ɾ
    FeatureTableType{ .snd = "\u{0271}", .ftrTbl = "---++-0---++--+-+-000--00000" }, //ɱ
    FeatureTableType{ .snd = "\u{0294}", .ftrTbl = "---+---------+----000--00000" }, //ʔ
    FeatureTableType{ .snd = "ɣ+", .ftrTbl = "---+-++----+------000-++-+-0" }, //ɣ+
    FeatureTableType{ .snd = "x+", .ftrTbl = "---+-++-----------000-++-+-0" }, //x+
    FeatureTableType{ .snd = "k+", .ftrTbl = "---+--------------000-++-+-0" }, //k+
    FeatureTableType{ .snd = "ɡ+", .ftrTbl = "---+-------+------000-++-+-0" }, //ɡ+
    FeatureTableType{ .snd = "k+͡x+", .ftrTbl = "---+--+-----------000-++-+-0" }, //k+͡x+
    FeatureTableType{ .snd = "ɡ+͡ɣ+", .ftrTbl = "---+--+----+------000-++-+-0" }, //ɡ+͡ɣ+
    FeatureTableType{ .snd = "\u{0127}", .ftrTbl = "---+-++-----------000-+-+-+0" }, //ħ
    FeatureTableType{ .snd = "\u{0295}", .ftrTbl = "---+-+-----+------000-+-+-+0" }, //ʕ
    FeatureTableType{ .snd = "\u{0281}", .ftrTbl = "---+-++----+------000-+---+0" }, //ʁ
    FeatureTableType{ .snd = "\u{0071}", .ftrTbl = "---+--------------000-+---+0" }, //q
    FeatureTableType{ .snd = "\u{03C7}", .ftrTbl = "---+-++-----------000-+---+0" }, //χ
    FeatureTableType{ .snd = "\u{0262}", .ftrTbl = "---+-------+------000-+---+0" }, //ɢ
    FeatureTableType{ .snd = "\u{0255}", .ftrTbl = "---+-++----------++++-++-+-0" }, //ɕ
    FeatureTableType{ .snd = "ɉ", .ftrTbl = "---+-------+-----+-+--++-+-0" }, //ɉ
    FeatureTableType{ .snd = "ʝ", .ftrTbl = "---+-++----+-----+-+--++-+-0" }, //ʝ
    FeatureTableType{ .snd = "\u{0063}", .ftrTbl = "---+-------------+-+--++-+-0" }, //c
    FeatureTableType{ .snd = "\u{00E7}", .ftrTbl = "---+-++----------+-+--++-+-0" }, //ç
    FeatureTableType{ .snd = "d͡ʑ", .ftrTbl = "---+--+----+-----++++-++-+-0" }, //d͡ʑ
    FeatureTableType{ .snd = "t͡ɕ", .ftrTbl = "---+--+----------++++-++-+-0" }, //t͡ɕ
    FeatureTableType{ .snd = "ɣ", .ftrTbl = "---+-++----+------000-++-000" }, //ɣ
    FeatureTableType{ .snd = "ɣ̠", .ftrTbl = "---+-++----+------000-++--+0" }, //ɣ̠
    FeatureTableType{ .snd = "x", .ftrTbl = "---+-++-----------000-++-000" }, //x
    FeatureTableType{ .snd = "x̠", .ftrTbl = "---+-++-----------000-++--+0" }, //x̠
    FeatureTableType{ .snd = "k", .ftrTbl = "---+--------------000-++-000" }, //k
    FeatureTableType{ .snd = "k̠", .ftrTbl = "---+--------------000-++--+0" }, //k̠
    FeatureTableType{ .snd = "ɡ", .ftrTbl = "---+-------+------000-++-000" }, //ɡ
    FeatureTableType{ .snd = "ɡ̠", .ftrTbl = "---+-------+------000-++--+0" }, //ɡ̠
    FeatureTableType{ .snd = "ʑ", .ftrTbl = "---+-++----+-----++++-++-+-0" }, //ʑ
    FeatureTableType{ .snd = "ʈ", .ftrTbl = "---+-------------+-----00000" }, //ʈ
    FeatureTableType{ .snd = "ɖ", .ftrTbl = "---+-------+-----+-----00000" }, //ɖ
    FeatureTableType{ .snd = "ɬ", .ftrTbl = "---+-++----------++--+-00000" }, //ɬ
    FeatureTableType{ .snd = "ʐ", .ftrTbl = "---+-++----+-----+--+--00000" }, //ʐ
    FeatureTableType{ .snd = "ɸ", .ftrTbl = "---+-++-------+---000--00000" }, //ɸ
    FeatureTableType{ .snd = "ʂ", .ftrTbl = "---+-++----------+--+--00000" }, //ʂ
    FeatureTableType{ .snd = "ʒ", .ftrTbl = "---+-++----+-----+-++--00000" }, //ʒ
    FeatureTableType{ .snd = "z", .ftrTbl = "---+-++----+-----++-+--00000" }, //z
    FeatureTableType{ .snd = "v", .ftrTbl = "---+-++----+--+-+-000--00000" }, //v
    FeatureTableType{ .snd = "t", .ftrTbl = "---+-------------++----00000" }, //t
    FeatureTableType{ .snd = "ʃ", .ftrTbl = "---+-++----------+-++--00000" }, //ʃ
    FeatureTableType{ .snd = "s", .ftrTbl = "---+-++----------++-+--00000" }, //s
    FeatureTableType{ .snd = "p", .ftrTbl = "---+----------+---000--00000" }, //p
    FeatureTableType{ .snd = "f", .ftrTbl = "---+-++-------+-+-000--00000" }, //f
    FeatureTableType{ .snd = "d", .ftrTbl = "---+-------+-----++----00000" }, //d
    FeatureTableType{ .snd = "b", .ftrTbl = "---+-------+--+---000--00000" }, //b
    FeatureTableType{ .snd = "θ", .ftrTbl = "---+-++----------+++---00000" }, //θ
    FeatureTableType{ .snd = "ɮ", .ftrTbl = "---+-++----+-----++--+-00000" }, //ɮ
    FeatureTableType{ .snd = "ð", .ftrTbl = "---+-++----+-----+++---00000" }, //ð
    FeatureTableType{ .snd = "β", .ftrTbl = "---+-++----+--+---000--00000" }, //β
    FeatureTableType{ .snd = "d͡ʒ", .ftrTbl = "---+--+----+-----+-++--00000" }, //d͡ʒ
    FeatureTableType{ .snd = "d͡z", .ftrTbl = "---+--+----+-----++-+--00000" }, //d͡z
    FeatureTableType{ .snd = "d͡ɮ", .ftrTbl = "---+--+----+-----++--+-00000" }, //d͡ɮ
    FeatureTableType{ .snd = "d̠͡ɮ̠", .ftrTbl = "---+--+----+-----+-+-+-00000" }, //d̠͡ɮ̠
    FeatureTableType{ .snd = "t͡ʃ", .ftrTbl = "---+--+----------+-++--00000" }, //t͡ʃ
    FeatureTableType{ .snd = "t̠͡ɬ̠", .ftrTbl = "---+--+----------+-+-+-00000" }, //t̠͡ɬ̠
    FeatureTableType{ .snd = "t͡s", .ftrTbl = "---+--+----------++-+--00000" }, //t͡s
    FeatureTableType{ .snd = "t͡ɬ", .ftrTbl = "---+--+----------++--+-00000" }, //t͡ɬ
    FeatureTableType{ .snd = "t̪͡s̪", .ftrTbl = "---+--+----------++++--00000" }, //t̪͡s̪
    FeatureTableType{ .snd = "t̪͡ɬ̪", .ftrTbl = "---+--+----------+++-+-00000" }, //t̪͡ɬ̪
    FeatureTableType{ .snd = "d̪͡z̪", .ftrTbl = "---+--+----+-----++++--00000" }, //d̪͡z̪
    FeatureTableType{ .snd = "d̪͡ɮ̪", .ftrTbl = "---+--+----+-----+++-+-00000" }, //d̪͡ɮ̪
    FeatureTableType{ .snd = "ʈ͡ʂ", .ftrTbl = "---+--+----------+--+--00000" }, //ʈ͡ʂ
    FeatureTableType{ .snd = "ɖ͡ʐ", .ftrTbl = "---+--+----+-----+--+--00000" }, //ɖ͡ʐ
    FeatureTableType{ .snd = "p͡f", .ftrTbl = "---+--+-------+-+-000--00000" }, //p͡f
    FeatureTableType{ .snd = "b͡v", .ftrTbl = "---+--+----+--+-+-000--00000" }, //b͡v
    FeatureTableType{ .snd = "p͡ɸ", .ftrTbl = "---+--+-------+---000--00000" }, //p͡ɸ
    FeatureTableType{ .snd = "b͡β", .ftrTbl = "---+--+----+--+---000--00000" }, //b͡β
    FeatureTableType{ .snd = "t̪͡θ", .ftrTbl = "---+--+----------+++---00000" }, //t̪͡θ
    FeatureTableType{ .snd = "d̪͡ð", .ftrTbl = "---+--+----+-----+++---00000" }, //d̪͡ð
    FeatureTableType{ .snd = "c͡ç", .ftrTbl = "---+--+----------+-+--++-+-0" }, //c͡ç
    FeatureTableType{ .snd = "ɉ͡ʝ", .ftrTbl = "---+--+----+-----+-+--++-+-0" }, //ɉ͡ʝ
    FeatureTableType{ .snd = "k͡x", .ftrTbl = "---+--+-----------000-++-000" }, //k͡x
    FeatureTableType{ .snd = "k̠͡x̠", .ftrTbl = "---+--+-----------000-++--+0" }, //k̠͡x̠
    FeatureTableType{ .snd = "ɡ͡ɣ", .ftrTbl = "---+--+----+------000-++-000" }, //ɡ͡ɣ
    FeatureTableType{ .snd = "ɡ̠̠͡ɣ̠", .ftrTbl = "---+--+----+------000-++--+0" }, //ɡ̠̠͡ɣ̠
    FeatureTableType{ .snd = "q͡χ", .ftrTbl = "---+--+-----------000-+---+0" }, //q͡χ
    FeatureTableType{ .snd = "ɢ͡ʁ", .ftrTbl = "---+--+----+------000-+---+0" }, //ɢ͡ʁ
    FeatureTableType{ .snd = "ɧ", .ftrTbl = "---+-++----------+-++-++-000" }, //ɧ
    FeatureTableType{ .snd = "k͡p", .ftrTbl = "---+----------+---000-++-000" }, //k͡p
    FeatureTableType{ .snd = "g͡b", .ftrTbl = "---+-------+--+---000-++-000" }, //g͡b
    FeatureTableType{ .snd = "p͡t", .ftrTbl = "---+----------+--++-+--00000" }, //p͡t
    FeatureTableType{ .snd = "b͡d", .ftrTbl = "---+-------+--+--++-+--00000" }, //b͡d
    FeatureTableType{ .snd = "ɰ", .ftrTbl = "----++0+---+------000-++-00+" }, //ɰ
    FeatureTableType{ .snd = "ɰ̠", .ftrTbl = "----++0+---+------000-++--++" }, //ɰ̠
    FeatureTableType{ .snd = "w", .ftrTbl = "----++0+---+--++--000-++--++" }, //w
    FeatureTableType{ .snd = "ɥ", .ftrTbl = "----++0+---+--++--000-++-+-+" }, //ɥ
    FeatureTableType{ .snd = "j", .ftrTbl = "----++0+---+------000-++-+-+" }, //j
    FeatureTableType{ .snd = "ɹ", .ftrTbl = "----++0+---+-----+-+---00000" }, //ɹ
    FeatureTableType{ .snd = "ʋ", .ftrTbl = "----++0+---+--+-+-000--00000" }, //ʋ
    FeatureTableType{ .snd = "ʍ", .ftrTbl = "-----++-----+-++--000-++--++" }, //ʍ
    FeatureTableType{ .snd = "ɦ", .ftrTbl = "-----++----++-----000--00000" }, //ɦ
    FeatureTableType{ .snd = "h", .ftrTbl = "-----++-----+-----000--00000" }, //h
};

pub const diacriticTable = [_]FeatureTableType{
    FeatureTableType{ .snd = "\u{0329}", .ftrTbl = "+000000000000000000000000000" }, //◌̩
    FeatureTableType{ .snd = "\u{0330}", .ftrTbl = "000000000000-+00000000000000" }, //˷ • ◌̰
    FeatureTableType{ .snd = "\u{0324}", .ftrTbl = "000000000000+-00000000000000" }, //◌̤
    FeatureTableType{ .snd = "\u{0325}", .ftrTbl = "00000000000-0000000000000000" }, //˳ • ◌̥
    FeatureTableType{ .snd = "\u{0320}", .ftrTbl = "000000000000000000-+00000000" }, //ˍ • ◌̠
    FeatureTableType{ .snd = "\u{032A}", .ftrTbl = "000000000000000000++00000000" }, //◌͏̪
    //+ fronted velar
    //- backed velar
    //' stress
    FeatureTableType{ .snd = "\u{02D0}", .ftrTbl = "00+0000000000000000000000000" }, //ː
    FeatureTableType{ .snd = "\u{02B0}", .ftrTbl = "000000000000+-00000000000000" }, //ʰ
    FeatureTableType{ .snd = "\u{02B2}", .ftrTbl = "0000000000000000000000++-+-0" }, //ʲ
    FeatureTableType{ .snd = "\u{02B7}", .ftrTbl = "00000000000000++000000000000" }, //ʷ
    FeatureTableType{ .snd = "\u{02E0}", .ftrTbl = "0000000000000000000000++--+0" }, //ˠ
    FeatureTableType{ .snd = "\u{02E4}", .ftrTbl = "0000000000000000000000+-+-+0" }, //ˤ
    FeatureTableType{ .snd = "\u{0303}", .ftrTbl = "0000000000+00000000000000000" }, //◌̃
    FeatureTableType{ .snd = "\u{02DE}", .ftrTbl = "00000000000000000+++-0000000" }, //˞
    // FeatureTableType{ .snd = "\u{02BC}", .ftrTbl = "000000000000-+00000000000000" }, //ʼ - The same as ~
};
