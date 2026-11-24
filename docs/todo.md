# Todo

Work in this order. Finish parsing before matching, and matching before changing. Each item names the files that already own that behavior.

Current rule shape is `match > change`, split in `src/matchers/rule.zig` (`Rule.init`). The match side is lexed by `src/parser/match_lexer.zig`, the change side by `src/parser/change_lexer.zig`. The input string (not the rule) is lexed by `src/parser/sound_lexer.zig` and `src/parser/phoneme_read.zig`. A hit is a fixed-length span from `src/matchers/matcher.zig` (`find_match`). The rewrite is the loop in `Rule.apply` in `src/matchers/rule.zig`.

Target shape, from `docs/rules.md`:

```
<match> > <change> / <before> _ <after>
```

`/` and the environment are optional, so existing rules keep working. `before` and `after` may be empty (`/_a`, `/a_`).

One open choice before coding `X`: `docs/rules.md` defines `X` as any number of segments (like `*`). A single segment of any kind is already `[]` in `src/parser/match_lexer.zig`. This plan treats `X` as the star, and leaves `[]` as the one-segment wildcard.

## 1. Parsing

Store the new rule. Do not change which spans match or what gets written yet.

- [ ] **Split environment off the change side.** `Rule.init` in `src/matchers/rule.zig` stops the match lexer at `>` and gives the rest to `ChangeLexer`. Teach `src/parser/change_lexer.zig` to stop at `/` the same way the match lexer stops at `>`. Keep `before` and `after` on `Rule` (the struct already has a `// Context` comment). Environment length is independent of the match/change length check in `Rule.init`.
- [ ] **Lex `before _ after` with the match lexer.** Reuse `src/parser/match_lexer.zig` for both sides of `_`. `_` is only legal in the environment. Reject a missing `_` after `/`, a second `_`, or a second `/` via `src/parser/lexer_errors.zig`.
- [ ] **Class letters `V` and `C`.** In `src/parser/match_lexer.zig`, before `readPhoneme`, map `V` to `[+syllabic]` and `C` to `[+consonantal]`. Feature names and bits live in `src/sounds/features.zig` and `src/sounds/ph_features.zig`. These letters are not inventory glyphs (`src/sounds/constants/phonemes.zig`); today `readPhoneme` would keep them as unknown phonemes with empty features. They belong on the match side and in the environment, not on the change side.
- [ ] **Class letter `X`.** In `src/parser/match_lexer.zig`, add a token kind for “any number of segments”. Do not lower it to a `PhFeatures` mask. `find_match` cannot consume it until step 2.
- [ ] **Tests for the parse only.** Lexer tests sit at the bottom of `src/parser/match_lexer.zig` and `src/parser/change_lexer.zig`. Init tests sit in `src/matchers/rule.zig`. Cover `V > [] / _ C`, an `X` token, a missing `_`, and an old rule with no `/`.

## 2. Matching

Use the tokens from step 1. Still rewrite only the focus, and only when match and change have the same length.

- [ ] **Context check around the focus.** `find_match` in `src/matchers/matcher.zig` returns the start index of a fixed pattern. Extend it so a hit at that index also requires `before` on the left and `after` on the right. The returned index stays the focus, so `Rule.apply` does not rewrite the environment. Call site is the loop in `Rule.apply` (`src/matchers/rule.zig`).
- [ ] **`V` and `C` match as masks.** Once the lexer stores them as feature masks, the existing `Mask` arm in `find_match` is enough. Add cases under `src/matchers/rule_tests/` (same style as `nasalization.zig` and `voicing_assimilation.zig`).
- [ ] **`X` matches a variable span.** `find_match` currently requires `m + pattern.len <= source.len` and steps one token at a time. An `X` token has no fixed length, so that walk has to allow a run of segments (including empty, if `X` is `*`). `X` in `before` or `after` must not move the focus index. `X` in the focus is out of scope until step 3, because the rewrite still assumes one change token per focus token.
- [ ] **Sound-string lexer stays as it is.** `src/parser/sound_lexer.zig` tokenizes the word being rewritten. `V`, `C`, `X`, `/`, and `_` are rule syntax, not IPA input.

## 3. Changing

Rewrite using a match that already knows context and `X`.

- [ ] **Apply only the focus.** `Rule.apply` in `src/matchers/rule.zig` copies unmatched tokens, then walks `self.change` in lockstep with the matched span. After step 2, that span must still be the focus, not `before` or `after`.
- [ ] **Keep equal focus and change lengths** until deletion exists. `MatchChangeLengthMismatch` in `src/matchers/rule.zig` stays. Environment tokens are not part of that count.
- [ ] **Deletion `∅` (next, from `docs/rules.md`).** Change lexer (`src/parser/change_lexer.zig`) and the `.Phoneme` / `.Mask` switch in `Rule.apply`. A focus token paired with `∅` writes nothing, so the equal-length rule has to allow a shorter written result without treating that as `MatchChangeLengthMismatch`.

## Later (not this pass)

Listed in `docs/rules.md`, no lexer support yet:

- Word edges `[word` and `]word`, and `]Utterance`, as environment tokens in `src/parser/match_lexer.zig`. Matching them means “no segment on that side” in `find_match`.
- Greek-letter indexes such as `place_i` (feature agreement). Needs a new token; masks in `src/sounds/ph_features.zig` cannot express “same value as another slot”.
- The arrow in `docs/rules.md` examples is `→`. The parser accepts `>` only (`TransitionToChangeSet` in `src/parser/match_lexer.zig`).

Public entry points to retest when a phase changes behavior, not before: `src/lib.zig` (`createRule`, `applyRule`) and `src/services/rules.zig` (`on_apply_rule`). Rule behavior tests stay in `src/matchers/rule_tests/`.
