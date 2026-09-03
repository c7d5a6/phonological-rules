# Phonological Rules

A Zig library and HTTP service for representing IPA sounds as distinctive features (Hayes 2009) and applying rewrite rules of the form **match → change**.

## What it does

Given an IPA string and a rule, the engine:

1. Tokenizes the string into phonemes (with optional diacritics and affricate ties).
2. Looks up each phoneme in a feature table.
3. Finds spans whose features match the left-hand side of the rule.
4. Applies the right-hand side feature changes and maps the result back to IPA.

It can also report **common** features (shared by every phoneme in a string) and **distinctive** features (those that vary across the string).

## Architecture

```
IPA / rule strings
        │
        ▼
┌───────────────────┐     C ABI (src/lib.zig)      ┌──────────────────────────┐
│  ph_lib           │◄─────────────────────────────│  HTTP backend (zap)      │
│  parsers          │     createRule / applyRule   │  :3003                   │
│  feature table    │     commonFeatures           │  POST /api/rules/apply   │
│  matcher + apply  │     distinctiveFeatures      │  POST /api/features/...  │
└───────────────────┘                              └──────────────────────────┘
```

| Piece | Role |
| --- | --- |
| `src/sounds/` | Feature bits, IPA ↔ feature lookup, IPA reconstruction after a change |
| `src/parser/` | Lexers for sound strings, rule match side, and rule change side |
| `src/matchers/` | Sequential pattern match and rule application |
| `src/lib.zig` | Shared library exported to the backend |
| `src/main.zig` + `src/routes/` | HTTP server wrapping the library |

Feature geometry follows Hayes, *Introductory Phonology* (2009): manner, vowel, place, and laryngeal features stored as plus/minus masks.

## HTTP API

Listens on `0.0.0.0:3003`.

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| `GET` | `/api/hello` | — | HTML ping |
| `GET` | `/api/version` | — | `{ "version": "…" }` |
| `POST` | `/api/features/common` | raw IPA text | `{ "common": "+consonantal …", "distinctive": "voice …" }` |
| `POST` | `/api/rules/apply` | `{ "rule": "…", "str": "…" }` | rewritten IPA as text |

Example rule application:

```json
{
  "rule": "[+voice -syllabic][-voice]>[-voice][]",
  "str": "riabt͡ʃik"
}
```

→ `riapt͡ʃik` (voiced obstruent devoices before a voiceless consonant).

---

## Input rules

All text is **UTF-8**. Invalid UTF-8 is not accepted.

There are two kinds of input: **sound strings** (what a rule is applied to, or what feature queries see) and **rule strings**.

### Sound strings

A sound string is a sequence of:

1. **Phonemes** — one IPA symbol from the table below, optionally followed by one or more diacritics.
2. **Affricates / double articulations** — two phonemes joined by the tie bar `͡` (U+0361), each side optionally with diacritics: `t͡ʃ`, `d̪͡z̪`, `p͡f`.
3. **Whitespace** — Unicode white space (space, tab, newline, NBSP, and the other White_Space characters in `src/utils/symbols.zig`). Consecutive whitespace collapses to one token.

Constraints:

- A diacritic must follow a phoneme. A string may not start with a diacritic, and a diacritic may not appear immediately after whitespace (`WrongPlaceForDiacritic`).
- After a tie bar `͡` there must be another phoneme. End of input, whitespace, or a diacritic in that position is an error (`EndAfterAffricate`, `WrongPlaceForWhitespace`, `WrongPlaceForDiacritic`).
- An unknown IPA letter is still tokenized as a phoneme, but with empty features. It will not satisfy a feature mask such as `[+voice]`. After a change, unknown sounds keep their original glyph.

### Rule strings

A rule is:

```
<match> > <change>
```

`>` is required. The change side must be present and non-empty (`NoChangeSet`).

**Match** and **change** are token sequences of the same kinds:

| Token | Syntax | Meaning on the match side | Meaning on the change side |
| --- | --- | --- | --- |
| Feature mask | `[+voice -syllabic]` | Phoneme whose features **contain** all listed `+` / `-` values | Those features are **set** on the matched phoneme; unlisted features stay as they were |
| Empty mask | `[]` | Matches any phoneme (no constraints) | Leave the phoneme unchanged |
| Literal IPA | `p`, `aː`, `n̥` | Treated as a mask of that sound’s full feature set | Treated as a change mask of that sound’s features |
| Whitespace | space, tab, etc. | Matches a whitespace token | Writes a single space |

Mask syntax inside `[` `]`:

- Each specifier is `+` or `-` immediately followed by a **feature name** (see table below). Names must match exactly, including underscores: `delayed_release`, `spread_glottis`.
- Specifiers may be separated by whitespace: `[+voice -syllabic]` or `[+voice-syllabic]`.
- Anything other than `+`/`-` plus a known feature name is `UnexpectedSymbol`.
- The closing `]` is required.

Notes:

- Match and change sides are aligned **token for token**. `[+voice][-voice]>[-voice][]` rewrites two phonemes; the second `[]` copies the second phoneme through.
- Rule lexers do **not** treat `͡` as an affricate joiner. Prefer feature masks (or a single-table affricate symbol) on the rule side rather than `t͡ʃ`.
- Diacritics on the rule side follow the same placement rule as in sound strings: they attach to a preceding phoneme, never stand alone.

### Feature names

These are the names accepted inside `[+…]` / `[-…]`:

| Group | Names |
| --- | --- |
| Manner | `syllabic`, `consonantal`, `approximant`, `sonorant`, `continuant`, `delayed_release`, `trill`, `tap`, `flap` |
| Vowels | `back`, `front`, `high`, `low`, `tense`, `round`, `long`, `nasal`, `stress` |
| Place | `labial`, `coronal`, `dorsal`, `anterior`, `distributed`, `strident`, `lateral`, `labiodental` |
| Laryngeal | `voice`, `spread_glottis`, `constricted_glottis`, `implosive` |

`flap` and `implosive` are valid in rule syntax; the built-in phoneme table does not currently assign them.

### Diacritics

Allowed after a phoneme (sound strings and literal IPA in rules):

| Glyph | Code | Effect |
| --- | --- | --- |
| ː | U+02D0 | `[+long]` |
| ʰ | U+02B0 | `[+spread_glottis -constricted_glottis]` |
| ʲ | U+02B2 | palatalization (`[+dorsal +high +front -low]`) |
| ʷ | U+02B7 | labialization (`[+labial +round]`) |
| ˠ | U+02E0 | velarization |
| ˤ | U+02E4 | pharyngealization |
| ˞ | U+02DE | rhoticity |
| ◌̃ | U+0303 | `[+nasal]` |
| ◌̩ | U+0329 | `[+syllabic]` |
| ◌̰ | U+0330 | creaky (`[+constricted_glottis -spread_glottis]`) |
| ◌̤ | U+0324 | breathy (`[+spread_glottis -constricted_glottis]`) |
| ◌̥ | U+0325 | `[-voice]` |
| ◌̠ | U+0320 | retracted |
| ◌̪ | U+032A | dental |

### Phoneme inventory

Symbols below are recognized as phonemes. Combining a base symbol with diacritics (or a listed precomposed form such as `ŋ˗`, `k̠`) is also valid.

**Vowels:** ɒ ɑ ɶ a æ ʌ ɔ o ɤ ɘ œ ə e ɞ ø ɛ ɵ ɯ u ʊ ɨ ʉ y i ʏ ɪ

**Glides / approximants / laryngeals:** ɰ ɰ̠ w ɥ j ɹ ʋ ʍ ɦ h ʔ

**Nasals, liquids, rhotics:** m ɱ n ɳ ɲ ŋ ŋ˗ ŋ+ ɴ l ɫ ɭ ʎ ʟ ʟ̠ ʎ r ʀ ɾ ɽ ɺ ɻ ʙ

**Obstruents (simple):** p b t d ʈ ɖ c ɉ k ɡ k̠ ɡ̠ k+ ɡ+ q ɢ ʔ  
f v θ ð s z ʃ ʒ ʂ ʐ ɕ ʑ ç ʝ x ɣ x̠ ɣ̠ x+ ɣ+ χ ʁ ħ ʕ ɸ β ɬ ɮ ɧ

**Affricates and double articulations** (also formable with `͡` at runtime):  
t͡s d͡z t͡ʃ d͡ʒ t͡ɕ d͡ʑ t͡ɬ d͡ɮ ʈ͡ʂ ɖ͡ʐ p͡f b͡v p͡ɸ b͡β t̪͡s̪ d̪͡z̪ t̪͡ɬ̪ d̪͡ɮ̪ t̪͡θ d̪͡ð t̠͡ɬ̠ d̠͡ɮ̠ c͡ç ɉ͡ʝ k͡x ɡ͡ɣ k̠͡x̠ ɡ̠̠͡ɣ̠ q͡χ ɢ͡ʁ k͡p g͡b p͡t b͡d k+͡x+ ɡ+͡ɣ+

### Lexer errors

| Error | When |
| --- | --- |
| `WrongPlaceForDiacritic` | Diacritic at the start of a token (after whitespace, after `[`, or after `͡`) |
| `WrongPlaceForWhitespace` | Whitespace immediately after `͡` |
| `EndAfterAffricate` | Input ends on `͡` |
| `UnexpectedSymbol` | Bad character inside `[…]` (not `+`/`-`, unknown feature name, missing `]`) |
| `NoChangeSet` | Rule has no `>`, or nothing after `>` |

---

## Build

Requires **Zig 0.16.0**.

```sh
zig build          # library + backend
zig build test     # unit tests (library; includes fuzz corpus once)
zig build test --fuzz   # long-run library fuzzer (web UI)
zig build profile -Doptimize=ReleaseFast   # parse / match / apply timings
zig build run      # HTTP server on port 3003
```

See [docs/optimizations.md](docs/optimizations.md) for how to read the profiler table and for `perf`.
