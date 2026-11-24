# Issues

Work is tracked in Lific, project **PHRUL**: <https://issues.c7d5a6.com/PHRUL/overview>.
Design reasoning that is too long for an issue lives in `docs/` and is linked from
the issue (for example `docs/rule-environments.md`).

## What goes where

| Put it in | When |
| --- | --- |
| An issue | A task that can be described fully in a few paragraphs: what, where (files), done when. |
| A doc in `docs/` | A big or complex problem (parsing, matching) where the *why* and the constraints matter. Link the issues from the doc and the doc from the issues. |
| Neither | Small fixes done on the spot, and anything already visible in code or git history. |

Do not keep task checklists in doc files; they go stale. Small things belong only in
issues.

## Creating issues (rule for Claude)

**Never create, edit or delete issues without confirmation** (closing finished ones is
covered by "After the work is done" below). Even when the user says "this should be an
issue":

1. Propose the issues in chat first: title, module, priority, status and a one-line
   description for each. Batch related ones in a single proposal.
2. Wait for a clear yes (or edits). Approval covers only what was listed.
3. Then create them, and report the identifiers (`PHRUL-NN`).

Reading (briefing, list, search) needs no confirmation. Starting work on an issue the
user named is fine.

## After the work is done

When a task finishes, check the related issues (`get_briefing`, or `list_issues` for the
module) against what was actually done:

1. Compare each open issue with the change: files touched, tests added, behaviour the
   issue asked for.
2. If an issue is clearly finished and verified (tests pass, command output, URL
   checked), close it with `status=done` and `evidence` saying how, then tell the user
   which issues were closed.
3. If it is only partly done, leave it open and say what is missing; add a comment only
   if that helps the next session.
4. If unsure whether it counts as done, ask instead of closing.
5. New work found along the way is not created automatically: propose it as described
   above.

Never close an issue on the strength of "it should work"; the evidence must come from
something that was run or inspected in this session.

### Conventions

- **Modules:** `Parsing`, `Matching`, `Changing` (rule language, in that order),
  `Service` (HTTP backend and deploy). Check `list_resources(module)` before inventing one.
- **Title:** short, imperative, one change. One issue is one self-contained change.
- **Description:** what and why, the files that own the behaviour, and a link to the
  relevant doc. Add acceptance criteria when it is not obvious.
- **Status:** `backlog` by default, `todo` when it is next, `active` while being worked.
- **Priority:** `high` only for what blocks other work or a release.
- **Dependencies:** link blockers (`blocks`) instead of writing "after X" in text.
- **Close with evidence:** say how it was verified (test name, command, URL).
- Never put secrets (`.env` values, keys, tokens) in issues.
