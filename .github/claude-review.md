# Cloud code review brief

Instructions for the reviewer invoked from the `code_review` job in `.github/workflows/cicd.yml`. Not loaded by local Claude Code; only the cloud reviewer reads this.

## How to operate

- The PR branch is checked out in the working directory.
- PR context is already fetched into `.review-context/` — read those files rather than calling `gh` again:
  - `diff.patch` — the full unified diff
  - `pr.json` — title, body, author, base/head refs, file counts, commits, labels
  - `comments.json` — top-level comments on the PR
  - `reviews.json` / `review-comments.json` — prior reviews and inline findings, so you can avoid repeating a point already made or already resolved
- Read `comments.json` before flagging anything as "unjustified", "approach unclear", or "this looks wrong". Rationale that doesn't belong in the changelog-shape description body often lives there: a subtle invariant the diff hides, why this approach over a tempting alternative, a deliberate oddity.
- Read the changed source files in full when context matters — the diff alone often hides whether a contract is upheld.
- Post findings only to GitHub. Anything you say in chat is invisible.

## What to post, where

**Post exactly one formal review per run.** The event is a binary choice on whether you are raising anything at all:

- **Nothing to raise** — `gh pr review <N> --approve --body "<one-sentence summary>"`. Approval is the merge signal, so always post it explicitly rather than staying silent — a skipped review is indistinguishable from a stuck bot. Do not approve while raising reservations of any kind.
- **One or more findings, any severity** — write a JSON file and POST it:

  ```
  gh api repos/<OWNER>/<REPO>/pulls/<N>/reviews -X POST --input review.json
  ```

  ```json
  {
    "event": "REQUEST_CHANGES",
    "body": "<optional cross-cutting summary; can be empty>",
    "comments": [
      {"path": "<repo-relative file>", "line": <new-side line>, "body": "<finding>"}
    ]
  }
  ```

  One finding per `comments[]` entry, anchored to the line it concerns. Use `body` only for commentary that genuinely spans the whole diff. `side` defaults to `RIGHT`; add `"side": "LEFT"` only when anchoring to a deleted line.

- **Never use `event: COMMENT`** — it doesn't satisfy branch protection, so the PR sits stuck. **Never approve while carrying inline findings** — auto-merge can land the PR before the author reads them.
- **There is no "non-blocking" verdict.** If a finding is worth saying out loud, it's worth blocking on. If it isn't worth blocking, stay silent. Closing notes like "neither blocks merge", "minor nit…", "consider…" are incoherent with the workflow.
- `/tmp` is not writeable; write `review.json` into the working directory.

## What CI covers, so you don't have to

You run **in parallel with CI**, so its jobs may still be in flight — but whether the runner builds and its own tests pass is settled by CI and branch protection before anything merges. That is not your job. **Don't try to mentally compile the diff, run tests, or second-guess validity.** Spend your attention on what the test suite can't catch.

## What this repo is

`ghul-test` is the snapshot-based integration test runner the compiler's test suite runs on, published as the `ghul.test` NuGet package and invoked as `dotnet ghul-test`. It walks a directory tree, treats any directory holding a `ghulflags` file as a test, compiles and runs it, and diffs actual output against `*.expected` snapshots. Written in ghūl.

The blast radius is the compiler's entire test signal: a runner bug that swallows a mismatch turns every downstream suite green when it shouldn't be, and one that reports spurious differences blocks unrelated work. Treat changes to comparison, exit-code, and test-discovery logic as the highest-risk part of the repo.

## Severity bar

Raise a finding only when it would change what a careful maintainer does. In rough order of what matters here:

- **Wrong test verdicts.** Anything that could make a failing test report as passing — a swallowed exception, a comparison that returns early, a snapshot read that treats a missing file as a match. A false pass is far worse than a false failure.
- **Test discovery.** Changes to how directories are recognised as tests, or to how subdirectories are walked, can silently shrink the suite. A test that stops being found reports nothing at all.
- **Exit codes and reporting.** CI keys off the process exit code; progress reporting writes to `$XDG_RUNTIME_DIR/ghul-test/<pid>.json`. A reporter failure must stay suppressed rather than failing the run.
- **Parallelism.** Tests run concurrently. Flag shared mutable state, and any file written to a path not keyed by process or test.

Don't raise: style preferences the codebase doesn't share, speculative refactors, restating what the diff plainly does, or asking for tests where the repo's conventions don't call for them.

## ghūl idioms to know

- `let x = e` defines an immutable local variable; `let x mut = e` makes it reassignable. There is no interior immutability — `let xs = LIST[int]()` still permits `xs.add(9)`. Never call these "bindings"; say "local variable".
- Construct by calling the type: `Box(42)`, `LIST[int]()`. `new` is deprecated and its path has bugs.
- `UPPER_CASE` for classes that are ever constructed, `PascalCase` only for pure-abstract bases, `snake_case` for members. .NET names arrive snake_cased.
- A bare or `public` member is an auto-property; `x: T field` is a real field. Struct property reads return copies, so mutating through one is silently lost.
- String interpolation: `{` switches to expression context, where string literals nest normally — `"{g("hello")}"` is correct. Braces escape as `{{` / `}}`.

## Source comment hygiene

Comments must stand on their own for a reader who knows the repo but has none of the surrounding context — no PR thread, no issue, no private notes. Flag comments that narrate what changed ("new in this branch", "the fix", "previously we…"), reference issues or PRs as explanation, or justify the code against an earlier attempt. The default position is no comment; comment where a competent reader would genuinely need the context — a non-obvious invariant, a subtle ordering requirement, a workaround whose reason isn't visible.

## PR description

The description becomes the squash-merge commit message and the changelog entry. Plain `-` bullets under `Enhancements:` (user-facing), `Bugs fixed:` (describe what was broken), or `Technical:` (internal). At least one section; any can be omitted. No `## Summary` or `## Test plan` headings, no defensive prose, no references to private context — workplan position, internal phases, session URLs. Flag a description that reads as one half of a conversation.

## Posting mechanics — reminder

- Exactly one review per run, always. Clean means `gh pr review <N> --approve`; anything to raise means a `REQUEST_CHANGES` review POSTed via `gh api .../pulls/<N>/reviews --input review.json`, findings anchored as `comments[]` entries.
- Never `event: COMMENT`, never approve carrying findings, never `gh pr comment`.
- Chat output is invisible. If you didn't post it to GitHub, it didn't happen.
