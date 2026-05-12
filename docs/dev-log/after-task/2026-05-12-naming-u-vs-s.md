# After-Task: Pin "two-U" vs S/s naming convention in decisions.md

## Goal

Make durable the U-vs-S naming distinction the maintainer named
2026-05-12 ~12:30 MT ("we need to use S rather than U"). Codex
caught the same issue independently in their pre-sweep check
and is adding a check-log note to their `codex/long-wide-example-sweep`
branch + a private Codex memory note. This PR is the parallel
Claude-side record in `decisions.md` so the convention survives
beyond Codex's per-branch notes and into the canonical scope log.

The distinction: **"two-U" is a legacy task label / nickname**
(it matches existing function names like `compare_dep_vs_two_U()`
and file paths like `R/extract-two-U-cross-check.R`); **public
math notation uses `S` / `s`** for the unique-variance diagonal,
matching the engine algebra `Sigma = Lambda Lambda^T + diag(s)`.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/decisions.md`** (M): appended the
  "2026-05-12 -- Naming convention: 'two-U' is a task label;
  public math uses S / s" entry recording:
  - what stays "two-U" (file names, function names, task labels
    in dev-log / PR titles / dispatch queues);
  - what uses `S` / `s` (roxygen prose, article body text,
    vignettes, README / CONTRIBUTING / design-doc math, `\eqn{}`
    equations);
  - the rationale (function-name "U" = task-label nickname;
    math-notation "S/s" = canonical algebra);
  - the recording context (Codex flag + maintainer ratification
    + Codex's parallel check-log note on the sweep branch).
- **`docs/dev-log/after-task/2026-05-12-naming-u-vs-s.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Append-only
decisions.md entry + after-task report.

The naming convention this entry pins is *editorial* (what
notation to write in user-facing prose), not *algebraic* (the
engine algebra is unchanged; the entry codifies that the engine
algebra is the source of truth).

## Files Changed

- `docs/dev-log/decisions.md`
- `docs/dev-log/after-task/2026-05-12-naming-u-vs-s.md` (new)

## Checks Run

- Pre-edit lane check: 0 open PRs at branch start (PR #38 just
  merged); no Codex push pending on `decisions.md`. Safe.
- Cross-check against existing repo state:
  ```sh
  git ls-tree -r --name-only origin/main | rg "two.U|two_U"
  ```
  verdict: 5 R/ + 5 man/ + 2 tests/ files carry "two-U" in the
  path; these stay (the entry says so).
- Cross-check against math notation in code:
  ```sh
  rg -n "diag\\(s|diag\\(S|s_phy|s_non|S_phy|S_non" R/ docs/
  ```
  verdict: the engine and docs already use S/s for the unique
  diagonal where math is being written; the entry codifies the
  existing convention rather than introducing a new one.

## Tests Of The Tests

No new test. The implicit test: when a future Codex / Claude PR
writes user-facing math, the math uses `S/s`. If a PR drifts and
writes `diag(U)` in roxygen or vignette prose, the next Shannon
audit should catch the drift via `rg "diag\\(U" R/ vignettes/`.

This entry is the *reference* a reviewer uses to call out the
drift. It is also the *protocol* the next Codex run will read
when picking up item #1 (phylo / two-U doc-validation), where
the article body must use `S/s` even though the article slug
and file path may retain "two-U" as the nickname.

## Consistency Audit

```sh
rg -nE "two[_-]U" docs/dev-log/decisions.md
```

verdict: each "two-U" appearance in `decisions.md` is in a
context where it functions as a task label / file-path reference
/ function-name reference -- never as math notation. Consistent
with the new entry.

```sh
rg -nE "diag\\(s|Lambda.*Lambda\\^T \\+ diag" docs/dev-log/decisions.md
```

verdict: the new entry uses `diag(s)`, `diag(s_phy)`,
`diag(s_non)` consistently. No `diag(U)` math in `decisions.md`.

## What Did Not Go Smoothly

I introduced a small layout bug in the initial edit (a leftover
"end of duplicated rationale-suffix" placeholder and an orphaned
sentence fragment from the previous section) that I had to clean
up in a follow-up edit. The fix was mechanical -- two minutes of
re-edit -- but recorded here as a lesson: when appending a new
section to a long append-only doc, the `old_string` in the Edit
tool should target the **last full line** of the previous
section, not a mid-line phrase. Targeting mid-line creates the
risk of orphaning the rest of that line.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Codex (implementer)** flagged the U-vs-S issue in their
  pre-sweep check and committed to adding a check-log note +
  Codex memory note. The agent-to-agent loop worked: the
  maintainer named the convention in chat, Codex caught it in
  their sweep validation, Claude (this PR) records it
  durably in `decisions.md`.
- **Noether (math consistency)** -- the entry pins the
  algebraic correspondence. The engine uses `S/s`; the public
  prose must match. No drift in either direction.
- **Pat (applied user)** -- a future user reading `?compare_dep_vs_two_U`
  expects the roxygen to use `S/s` in the math even if the
  function name says "two_U". The entry makes that expectation
  explicit.
- **Rose (cross-file consistency)** -- the `rg` audits above
  are Rose-style. The next Shannon audit should re-run them as
  a regression check.

## Known Limitations

- The naming convention is enforced by documentation, not by
  code or CI. A linter could in principle catch `diag(U)` in
  roxygen prose, but the cost of that linter exceeds the
  benefit at current package size. Manual review + the Shannon
  `rg` pattern is the soft enforcement layer.
- The entry does NOT propose renaming existing `compare_dep_vs_two_U()`
  / `compare_indep_vs_two_U()` / `extract_two_U_via_PIC()`
  functions. Renaming is a separate API-change decision the
  maintainer can revisit later (it would be a high-risk PR per
  the merge-authority rule).
- The decisions.md entry does not modify PR #37 or PR #38 even
  though both contain "two-U" task-label references. Those
  references are correct (they're labels, not math), so no
  amendment is needed. The new entry is the standing
  clarification for any future ambiguity.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible:
   append-only `decisions.md` + after-task, no source change.
2. Codex's sweep PR will land with its own check-log note about
   the U/S convention; the two notes are complementary (this PR
   is the canonical scope record; Codex's sweep check-log is
   the per-branch note).
3. When item #1 (phylo / two-U doc-validation) lands, the
   article body must use `S/s` in math per this entry. The
   reviewer (Claude per the PR #37 dispatch queue) should
   `rg "diag\\(U|U_phy|U_non"` on the article and reject any
   hit.
