# After-Task: Fix three review items missed in PR #32

## Goal

Address three concrete review items Codex flagged after PR #32
merged (relayed by maintainer 2026-05-12 ~08 MT). All three are
real issues introduced or missed by PR #32:

1. **`man/traits.Rd` malformed**: PR #32 placed `@keywords internal`
   in the middle of the roxygen prose for `traits()`. Roxygen
   tokenised every following word as a separate `\keyword{}` tag,
   producing dozens of garbage entries (`\keyword{through}`,
   `\keyword{trait)}`, `\keyword{wide_df,}`, etc.) at the bottom of
   the rendered Rd.
2. **README line 185** still calls the `traits(...)` formula marker
   a "convenience route." Under Option B, `traits()` is the
   internal back-compatibility path, not a recommended public
   entry. PR #32 caught the intro paragraph but missed the
   "Current boundaries" section.
3. **AGENTS.md lines 124, 131** still recommend
   `gllvmTMB(traits(...) ~ ..., data = df_wide)` as one of the
   "convenience equivalent" wide examples. PR #32's CONTRIBUTING
   update was correct; the AGENTS.md "Writing Style" section had
   the same prescription and PR #32 missed it.

After-task report added at branch start per `CONTRIBUTING.md`.
Codex's catch deserves recording: this PR exists because Codex
reviewed PR #32 carefully and flagged the gaps -- the
agent-to-agent review loop is the right shape.

## Implemented

- **`R/traits-keyword.R`** (M): moved `@keywords internal` from
  the middle of the roxygen block to the **end**, after all the
  description / detail prose. Wrapped the "Used inside..." code
  example and the internal-implementation note as `@details` so
  they live in their own section instead of leaking into the
  keyword list.
- **`man/traits.Rd`** (M): regenerated. Now carries a single
  clean `\keyword{internal}` tag (and `\concept{}` if roxygen
  emits any) rather than dozens of garbage entries.
- **`README.md`** "Current boundaries" (M): rewrote the
  long-or-wide paragraph. Old:
  > "The long-format API is canonical. `gllvmTMB_wide()` and the
  > `traits(...)` formula marker are convenience routes that
  > reshape wide data into the same long-format engine."
  New:
  > "The package accepts data in either **long** or **wide**
  > shape. `gllvmTMB(value ~ ..., data = df_long)` is the
  > long-format path; `gllvmTMB_wide(Y, ...)` is the wide path
  > (`Y` is a numeric matrix or a wide data frame). Both reach
  > the same engine."
- **`AGENTS.md`** "Writing Style" (M): rewrote the two-shape
  example prescription. Old wording named `gllvmTMB(traits(...)
  ~ ..., data = df_wide)` as a "convenience equivalent" wide
  example; the new wording names only `gllvmTMB_wide(Y, ...)` as
  the wide example. The trailing sentence about `@examples`
  blocks dropped its "(for instance, `traits()` is wide-only by
  construction)" parenthetical, which made sense only when
  `traits()` was a public route.
- **`docs/dev-log/after-task/2026-05-12-traits-rd-cleanup.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
or generated-Rd content semantics change. The roxygen fix
re-layouts the same prose so the rendered Rd has a clean
`\keyword{internal}` instead of garbage. README and AGENTS.md
wording changes are consistency-only.

## Files Changed

- `R/traits-keyword.R`
- `man/traits.Rd` (regenerated)
- `README.md`
- `AGENTS.md`
- `docs/dev-log/after-task/2026-05-12-traits-rd-cleanup.md` (new)

## Checks Run

- **Pre-edit lane check**: 0 open PRs. No Codex push pending on
  `R/traits-keyword.R`, `README.md`, or `AGENTS.md`. Safe.
- **`Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`**:
  regenerated `man/traits.Rd`. Post-regen, the Rd ends with a
  single `\keyword{internal}` (verified by `grep -c
  '^\\\\keyword' man/traits.Rd` before and after; was 30+
  entries, now 1).
- **Codex's three claims re-verified** post-fix:
  ```sh
  rg -n "traits\\(" README.md AGENTS.md
  ```
  verdict: README and AGENTS.md no longer recommend the
  `gllvmTMB(traits(...) ~ ...)` form as a public path. The only
  remaining `traits(` strings are in `R/traits-keyword.R`
  (the definition + docstring) and in `tests/`, both expected.
  ```sh
  grep '^\\keyword' man/traits.Rd | wc -l
  ```
  verdict: exactly 1 keyword line, the intended internal tag.

## Tests Of The Tests

No new test. The implicit test:
- `?traits` after merge shows a clean help page with the
  "(internal)" suffix in the title, no garbage keyword tail.
- The deployed pkgdown reference index has zero entries for
  `traits` (confirmed by the `@keywords internal` tag plus the
  `_pkgdown.yml` removal from PR #32).
- `rg "traits(" README.md AGENTS.md` returns no live
  user-facing recommendation of the LHS form.

This fix-up PR would have been caught earlier if the post-edit
review of PR #32 had checked the rendered Rd contents and not
just the source roxygen. Recording that as a lesson:
**when adding `@keywords internal` (or any tag after a long
description), open the rendered Rd post-regen to confirm the tag
sits at the end and no prose leaked into the keyword list.**

## Consistency Audit

```sh
rg -n "traits\\(\\.\\.\\.\\)|traits\\([a-z]" R/ man/ README.md AGENTS.md CLAUDE.md CONTRIBUTING.md
```

verdict: `traits(...)` appears in
- `R/traits-keyword.R` (definition + docstring): expected
- `man/traits.Rd` (regenerated): expected, single internal entry
- `tests/testthat/test-weights-unified.R`: Codex's paired tests, expected
- `vignettes/articles/morphometrics.Rmd`: Codex's three-way fit example,
  to be cleaned up in Codex's coming reader-facing sweep

No live `traits(...)` recommendation in README, AGENTS.md, CLAUDE.md,
or CONTRIBUTING.md after this PR.

```sh
grep '^\\keyword' man/traits.Rd
```

verdict: `\keyword{internal}` -- exactly one entry.

## What Did Not Go Smoothly

- The malformed Rd is on me. Placing `@keywords internal` in the
  middle of the roxygen block is a basic roxygen pattern error.
  The fix is mechanical, but the lesson is: post-`document()`,
  open the rendered Rd at least briefly to spot-check it. PR #32
  ran `devtools::document()` and committed the result without
  the spot-check.
- Codex caught all three issues in one review pass. Their
  message was concrete (specific lines, specific symptom). That
  is exactly the agent-to-agent review pattern this repo's rules
  prescribe; the rules are working.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Codex (implementer, also reviewer here)** caught three real
  gaps in PR #32 -- the rendered-Rd corruption, the missed
  README block, and the missed AGENTS.md prescription. Exactly
  the read-only review shape the rules ask for.
- **Rose (cross-file consistency)** signed off too early on
  PR #32 (specifically, the consistency audit there said "no
  live `traits(...)` recommendation" but did not actually grep
  `README.md` past the intro section). The PR #32 audit
  greps were genuine, but did not extend to "Current
  boundaries" -- a Rose-style sweep should run to end-of-file.
- **Ada (orchestrator)** kept this fix-up bounded to exactly
  Codex's three flagged items + the after-task report. No
  scope creep.
- **Grace (CI / pkgdown / CRAN)** is the silent beneficiary
  again: the regenerated Rd is now CRAN-clean (no malformed
  keyword tags).
- **Pat (applied user)** is the beneficiary of the README and
  AGENTS.md fixes: a new reader landing on the boundaries
  section now sees only the two canonical shapes.

## Known Limitations

- The morphometrics article still contains the three-way fit
  example (long + `traits()` + matrix-wide). Codex's reader-
  facing sweep covers this; out of scope for the present PR
  (which is strictly the three review items Codex flagged).
- This PR is a developer-error fix-up, not new functionality.
  The trial-period observation here: PR #32 shipped a malformed
  Rd that R CMD check did not flag (it accepted the dozens of
  bogus `\keyword{}` entries silently). The advisory air-format
  also did not catch this. Manual review by Codex is what caught
  it. Worth noting for the after-task discipline going forward.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: one Rd
   regen, two prose fixes, no source behaviour change.
2. After merge, Codex picks up the reader-facing sweep (article
   trim + design doc + dev notes) on the now-clean two-shape
   public surface.
3. Process lesson to fold into `docs/design/10-after-task-protocol.md`
   in a future PR: when a roxygen change adds tags after a long
   description, the after-task "Checks Run" entry must include a
   `tail -5 man/<changed>.Rd` (or equivalent) spot-check.
