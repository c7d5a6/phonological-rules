# Rule environments, classes and variable spans

Design notes for extending the rule language. The task list lives in Lific
(project [PHRUL](https://issues.c7d5a6.com/PHRUL/overview)); this file keeps the
reasoning that does not fit in an issue. Small items (arrow `→`, word edges,
Greek-letter indexes, ...) are tracked only as issues.

## Where rules are handled today

Rule shape is `match > change`, split in `Rule.init` (`src/matchers/rule.zig`).

| Piece | File |
| --- | --- |
| match side lexer | `src/parser/match_lexer.zig` |
| change side lexer | `src/parser/change_lexer.zig` |
| input string (not the rule) | `src/parser/sound_lexer.zig`, `src/parser/phoneme_read.zig` |
| a hit (fixed-length span) | `find_match` in `src/matchers/matcher.zig` |
| the rewrite | loop in `Rule.apply`, `src/matchers/rule.zig` |
| rule examples from the source book | `docs/rules.md` |

Public entry points to retest whenever behaviour changes: `src/lib.zig`
(`createRule`, `applyRule`) and `src/services/rules.zig` (`on_apply_rule`).
Behaviour tests live in `src/matchers/rule_tests/`.

## Target shape

```
<match> > <change> / <before> _ <after>
```

`/` and the environment are optional, so existing rules keep working. `before`
and `after` may be empty (`/_a`, `/a_`). The environment only *constrains* where
the focus (`match`) applies; it is never rewritten.

## Why three phases, in this order

Each phase can ship and be tested on its own, and later phases depend on earlier
ones:

1. **Parsing** stores the new rule without changing which spans match or what is
   written ([PHRUL-1](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-1) to
   [PHRUL-5](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-5)).
2. **Matching** uses the stored tokens to check the environment around a hit
   ([PHRUL-6](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-6) to
   [PHRUL-8](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-8)). The returned
   index stays the focus.
3. **Changing** rewrites using a match that already knows its context
   ([PHRUL-9](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-9),
   [PHRUL-10](https://issues.c7d5a6.com/PHRUL/issues/PHRUL-10)).

## Decisions and constraints worth remembering

- **Environment length is independent** of the match/change length check in
  `Rule.init` (`MatchChangeLengthMismatch`). Only the focus and change must agree.
- **`V` and `C` are lexer shorthands, not phonemes.** `V` = `[+syllabic]`,
  `C` = `[+consonantal]` (feature bits in `src/sounds/features.zig`). Without
  special handling `readPhoneme` would turn them into unknown phonemes with empty
  features (they are not in `src/sounds/constants/phonemes.zig`). They are valid
  on the match side and in the environment, not on the change side.
- **`X` is the star, `[]` stays the one-segment wildcard.** `docs/rules.md`
  defines `X` as any number of segments. A single arbitrary segment is already
  `[]` in `match_lexer.zig`. `X` therefore needs its own token kind and must not
  be lowered to a `PhFeatures` mask; `find_match` cannot use it until it supports
  variable spans.
- **`find_match` assumes a fixed length.** It requires
  `m + pattern.len <= source.len` and steps one token at a time. `X` in
  `before`/`after` must not move the focus index. `X` inside the focus is out of
  scope until Changing, because `Rule.apply` pairs one change token per focus
  token.
- **Deletion (`∅`) breaks the equal-length rule.** A focus token paired with `∅`
  writes nothing, so `MatchChangeLengthMismatch` has to allow a shorter written
  result.
- **The word being rewritten is lexed separately.** `V`, `C`, `X`, `/` and `_`
  are rule syntax, not IPA input; `sound_lexer.zig` stays as it is.
- **Errors for malformed environments** go through
  `src/parser/lexer_errors.zig`: missing `_` after `/`, a second `_`, or a
  second `/`.
