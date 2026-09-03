# Measuring optimizations

Library only: no HTTP. Keep behavior the same: same tokens, same `contain()` matching, same IPA out.

## Profiler

Times parse, match, and apply on a fixed corpus (`scripts/profile.zig`).

```sh
zig build profile -Doptimize=ReleaseFast
```

This builds `zig-out/bin/ph_profile` and prints a table:

```
optimize=ReleaseFast  clock=awake
corpus     phase           iters    ns/op
short      sound parse     20000      …
short      rule parse      20000      …
short      match           20000      …
short      apply            2000      …
astar      apply            2000      …
```

| Column | Meaning |
| --- | --- |
| corpus | `short` (`pods`), `affricate` (`riabt͡ʃik`), `astar` (mask change that drops `orig` and runs A*), `long` (repeated IPA) |
| phase | `sound parse` is `SoundLexer`; `rule parse` is `Rule.init`; `match` is `find_match`; `apply` is `Rule.apply` (includes `phonemeSound`) |
| iters | Timed repetitions after a short warmup |
| ns/op | Wall time (`Io.Clock.awake`) per repetition |

Compare before and after a change on the same machine, same `-Doptimize=ReleaseFast`. The `astar` / `apply` row is the IPA-reconstruction path. `match` is already tiny on these words; do not chase it first.

For a call graph:

```sh
zig build -Doptimize=ReleaseFast
perf record --call-graph dwarf ./zig-out/bin/ph_profile
perf report
```

## Fuzzer

Corpus smoke tests run with `zig build test`. The long run:

```sh
zig build test --fuzz
```

Uses the library tests only (`src/matchers/rule_fuzz.zig`), not HTTP. Zig 0.16 Debug fuzzing uses LLVM and `scripts/test_runner.zig` (stock runner fails to compile in Debug `--fuzz`). Open the printed web UI for runs, unique inputs, and coverage. Coverage is over the whole test binary (std, runner, all unit tests), not the library alone.

---

# Optimization TODO

Suggestions for making match, parse, and change faster. Ranked by likely payoff. Do not start with match: SPE-sized patterns on short words are already cheap.

Measure before and after with `zig build profile -Doptimize=ReleaseFast`. Keep behavior: same tokens, same `contain()` matching, same IPA out.

## 1. Change / IPA reconstruction (do first)

After a bracket mask, `Phoneme.applyChanges` drops `orig`. `Rule.apply` then calls `phonemeSound` → A* over the inventory × diacritics graph (`src/sounds/ph_sound.zig`). The search seeds the heap with every table phoneme, then linearly scans `visited` and the heap on each expansion. ~140 bases × ~14 diacritics, O(visits² × diacritics), cap 1000, then `"?"`.

Hayes matrices are ternary (`+` / `−` / `0`), so “which glyph is this bundle?” is a search, not a row lookup. That is the wrong algorithm for the common path (`p` + `[+voice]` → `b`, `n` + `[−voice]` → `n̥`).

- [ ] **Keep the source glyph on small changes.** If the mask is a single table diacritic (or a no-op `[]`), keep `orig` and append the mark. A* only when the segment identity changes.
- [ ] **Comptime map `(plsMsk, mnsMsk)` → inventory glyph.** Exact table hits become O(1) / binary search. Still needed: novel bundles (base + several diacritics).
- [ ] **Cache A* misses** keyed by the two masks, process-wide or per `Rule` arena.
- [ ] **Fix A* membership.** Hash-set (or sorted) visited feature pairs instead of scanning `visited` and `heap.items`. Do not seed every base if a close glyph is already known (the pre-change phoneme).
- [ ] **Stop allocating a sentinel copy in `getSound` / `phonemeSound` when `orig` is present.** `Rule.apply` already has a result buffer; copy the slice into it. Whitespace does not need a heap `" "`.

## 2. Parse / table lookup

Every glyph linearly scans the phoneme table (`Phoneme.setPhSound`). Every diacritic scans `diacritics`. Every `[+voice]` walks `ftr_names`. Tables are small, so this is constants unless a lot of text is tokenized.

- [ ] **Index phonemes by first UTF-8 codepoint** (or first byte). Linear scan only the bucket. Same idea for diacritics.
- [ ] **Comptime sorted table + binary search** on `orig` as an alternative to a first-codepoint index. Hash maps are usually worse: glyphs are 1–3 bytes and the table already fits in cache.
- [ ] **Feature-name lookup:** bucket by first letter or length, or a small comptime map. Avoid scanning all ~30 names per specifier.
- [ ] **Share `[+feat −feat]` parsing** between `MatchLexer` and `ChangeLexer` (correctness first; tiny speed win).

## 3. Match (lowest priority)

`find_match` is a sliding window: for each start, `contain()` on each pattern slot. O(n × k) bit-mask tests. Words are ~20 segments; rules are 1–3 slots. KMP / Boyer–Moore do not apply: predicates are subset tests, not equality.

Skip until rules run over long texts or many rules per string.

- [ ] **First-slot bit filter:** skip positions whose type or masks cannot satisfy `pattern[0]`.
- [ ] **Tiny DFA / compiled predicate** of the match masks if applying many rules to a corpus.
- [ ] Only then consider SIMD `contain()` on batches of `PhFeatures`. Not worth it for single-word HTTP apply.

## Out of scope here

- SPE context `/ C _ D` (skipped as a product feature; it would change match complexity, not just constants).
- Insertion / deletion (unequal match/change length).
- Removing debug prints in `Rule.apply` (noise, not an algorithm).
