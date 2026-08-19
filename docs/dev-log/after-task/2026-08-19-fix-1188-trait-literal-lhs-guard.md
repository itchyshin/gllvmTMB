# After Task: Fix #1188 — augmented-LHS guard compared against the literal "trait"

**Branch**: `claude/fix-1188-trait-literal-20260819`
**Date**: `2026-08-19`
**Roles (engaged)**: `Curie` (implementation), maintainer authorisation for the fix.

## 1. Goal

Fix issue #1188: `.assert_no_augmented_lhs()` in `R/brms-sugar.R` decided whether
a bare covstruct keyword's LHS was the supported per-trait-intercept form
`0 + trait | g` by comparing the LHS symbol against the string literal `"trait"`,
never consulting the resolved `trait =` argument. This blocked an external user
(@iwogross) from writing a correct long-format model with a non-default trait
column name, and forced him into a spec that collapsed 29 per-item intercepts
to one shared intercept in a published analysis.

## 2. Implemented

- `.assert_no_augmented_lhs()` now takes `trait_col = "trait"` and accepts
  **either** the resolved trait column name **or** the literal `"trait"` for
  the per-trait-intercept LHS shape (`0 + <trait_col> | g`).
- `rewrite_canonical_aliases()` now takes `trait_col = "trait"` and threads it
  to all six `.assert_no_augmented_lhs()` call sites (lines 3374, 3665, 3997,
  4016, 4202, 4328).
- `desugar_brms_sugar()` passes its own `trait_col` argument through to
  `rewrite_canonical_aliases()` instead of dropping it.
- The abort message's "accepts only ..." bullet now interpolates `trait_col`
  instead of hardcoding `0 + trait | g`.
- All existing single-argument callers of `rewrite_canonical_aliases()` (many
  test files) are unaffected — `trait_col` defaults to `"trait"`.

## 3. Files Changed

- `R/brms-sugar.R` — the fix (31 lines changed).
- `NEWS.md` — user-visible bug-fix entry, credits @iwogross.
- `tests/testthat/test-1188-trait-col-augmented-lhs-guard.R` — new (109 lines).

## 3a. Decisions and Rejected Alternatives

- **Decision:** thread `trait_col` as an explicit parameter through the three
  functions on the call path (`.assert_no_augmented_lhs` ←
  `rewrite_canonical_aliases` ← `desugar_brms_sugar`), rather than reaching
  for a package option or a global. Rationale: `desugar_brms_sugar()` already
  had `trait_col = "trait"` as a parameter that every real caller
  (`R/gllvmTMB.R`, `R/screen-gllvmTMB.R`, `R/suggest-lambda-constraint.R`)
  already resolves from the user's `trait =` argument — the value was already
  computed and in scope one function call away; it just wasn't passed down
  the last two hops. No new state, no risk of stale values across calls.
  Confidence: high.
- **Decision:** accept `trait_col` OR the literal `"trait"`, not `trait_col`
  alone. Rationale: explicit requirement (preserve every existing fixture
  that writes the LHS as literal `trait`, and the issue's own accepted
  workaround of renaming the column to `"trait"`). Confidence: high.
- **Rejected:** widening `.gllvmTMB_lhs_form()` / `.is_zero_plus_trait()` (the
  module-level helper used by the wide/long multi-slope classifiers) to also
  accept `trait_col`. The issue explicitly scopes itself to the parser guard
  rejecting a valid spelling of the *intercept-only* form; the wide/long
  augmented-slope classification asymmetry is documented as correct and out
  of scope. Confirmed by tracing: for `latent(0 + variable | site, d = 1)`
  with `trait_col = "variable"`, `.gllvmTMB_lhs_form()` returns `"unsupported"`
  regardless (it doesn't recognise `0 + variable` as `intercept_only` either,
  since it also hardcodes `"trait"`), and control falls through to
  `.assert_no_augmented_lhs()`, which is exactly the function this issue is
  about. The fix is fully effective at that single point for the reported
  bug shape; a real augmented long-form use of a renamed trait column (e.g.
  `latent(0 + variable + (0 + variable):x | g, d)`) would still be
  misclassified as unsupported by `.gllvmTMB_lhs_form()`, but the issue
  reporter's own "Not in scope" section rules this out.

## 4. Checks Run

- `devtools::document(roclets = c("rd", "collate", "namespace"))` — no
  `man/`/`NAMESPACE` diff (only internal, non-exported helpers touched).
  Pre-existing unrelated roxygen warnings surfaced (missing `@export`/
  `@exportS3Method` on 3 methods in `aghq-report.R`) — not touched by this PR,
  not new.
- `NOT_CRAN=true devtools::test(".")`, run to completion (background, ~monitored
  to exit): **`[ FAIL 3 | WARN 9 | SKIP 877 | PASS 16319 ]`**. All 3 failures
  are in `test-paper1-spde-slope-gauge-nofit-v2-materializer.R` and are
  pre-existing/unrelated — see Consistency Audit below.
- `pkgdown::check_pkgdown(pkg = ".")` — `✔ No problems found.`
- Targeted reruns of related test files (`test-augmented-lhs-guard.R`,
  `test-augmented-slope-family-policy.R`, `test-unique-family-deprecation.R`,
  `test-latent-unique-rename.R`, `test-{spatial,phylo,animal,kernel}-latent-
  unique-fold.R`, `test-kernel-equivalence.R`, `test-scalar-family-collapse.R`,
  `test-kernel-slope-guard.R`, `test-uncorrelated-bar-support.R`,
  `test-isdm-spatial-private-contract.R`, `test-phase56-1-phylo-augmented-
  stub.R`) — all pass, no regressions.
- `rg "MIS-|VA-|RE-|CI-[0-9]|C[0-9]-" man/` — no diff to `man/` at all, so no
  register-code risk.

## 5. Tests of the Tests

New file `tests/testthat/test-1188-trait-col-augmented-lhs-guard.R`, 5
`test_that()` blocks:

1. **Failure-before-fix, pass-after (the actual regression):**
   `latent(0 + variable | site, d = 1)` with `trait = "variable"` — full
   `gllvmTMB()` fit. Verified by `git stash push -- R/brms-sugar.R`, rerunning
   under `NOT_CRAN=true`: fails with `` `latent()` augmented LHS is not yet
   supported. `` on the stashed (pre-fix) code; passes (`convergence == 0L`)
   after `git stash pop`.
2. **No-regression:** the literal `"trait"` spelling (`indep(0 + trait | site)`
   with `trait_col = "trait"`) parses without error — passed both before and
   after (as expected: no bug there).
3. **Gate not widened:** `indep(0 + variable + (0 + variable):temp | site)` —
   a genuinely unsupported augmented-slope LHS for `indep()` (confirmed by
   reading the existing `indep()` call site, which has no augmented-slope
   companion route, unlike `latent()`/`unique()`) — still aborts with
   "augmented LHS" both before and after the fix.
4. **Message interpolation, failure-before-fix:** asserts the abort's
   "accepts only ..." bullet contains the literal substring `0 + variable | g`
   and does NOT contain `0 + trait | g`. Deliberately does not just check for
   the substring `"variable"` anywhere in the message, because the `"i" =
   "You wrote {fn}(...)"` bullet echoes the user's own call verbatim via
   `deparse(bar)` regardless of the fix — that would have made the assertion
   pass even pre-fix. Verified: pre-fix the assertion on `0 + variable | g`
   fails (message hardcodes `0 + trait | g`); post-fix it passes.
5. **Third call site:** `scalar(0 + variable | site)` parses without tripping
   the guard. Verified to fail pre-fix (`` `scalar()` augmented LHS is not yet
   supported. ``) and pass post-fix.

## 6. Consistency Audit

- `rg "\.assert_no_augmented_lhs\(fn, e\)" R/brms-sugar.R` → zero matches
  (all six call sites now pass `trait_col`); confirms no call site was missed.
- `rg "rewrite_canonical_aliases\(" R/ tests/` → the six-plus test-file direct
  callers all pass only `formula` (positional) or `formula` + other named
  args, none pass a second positional arg that would now collide with the new
  `trait_col` parameter — confirmed by reading each call site.
- `git diff origin/main --stat` → `NEWS.md`, `R/brms-sugar.R`,
  `tests/testthat/test-1188-trait-col-augmented-lhs-guard.R` only. No
  `src/`, no `R/gllvmTMB.R`, no `DESCRIPTION`, no `man/`.
- Pre-existing 3 test failures traced to their root cause:
  `dev/isdm-package-recovery/spde-slope-gauge-nofit-contract.R`'s
  `spde_slope_gauge_nofit_locked_predecessor()` hardcodes an absolute path,
  `/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/...`, belonging to a
  *different* lane's worktree that does not exist in this worktree
  (`/private/tmp/gllvmtmb-1188`). Reran
  `test-paper1-spde-slope-gauge-nofit-v2-materializer.R` in isolation with the
  #1188 fix present: identical 3 errors, same root cause message ("V2 no-fit
  sources are unavailable or the historical validator drifted"). Confirmed
  unrelated to `R/brms-sugar.R` by inspection (different subsystem, no shared
  code path) and by the fact the check is a self-contained md5sum/path
  existence check with no dependency on trait-column parsing.

## 7. Roadmap Tick

N/A — bug fix, not a roadmap item.

## 7a. GitHub Issue Ledger

- #1188 — this PR fixes it; PR #1193 references it (`Fixes #1188`), left open
  for the maintainer to close on merge.
- #1191, #1190, #1189 — verified to exist (same reporter, same session);
  noted as related in the PR body, not touched by this change.

## 8. What Did Not Go Smoothly

- An unattributed commit (`c9608c45`) and an unattributed draft PR (#1193)
  appeared on this branch/remote during the session, pushed by some
  background mechanism in the harness rather than an explicit `git commit` /
  `gh pr create` call I issued. Their content largely matched my own
  implementation, but the commit message and PR body both contained an
  **unverifiable statistical claim** — "LV1 loadings tracked item prevalence
  at R² = 0.742, falling to 0.125 once correctly specified" — that is not
  supported by the GitHub issue text (which states only R² = 0.78 for the
  *buggy* model, nothing about the corrected model) and that I have no
  evidence of having measured myself (no access to the reporter's real
  29-item terrapin dataset). Corrected both via `git commit --amend` +
  `git push --force-with-lease` and `gh pr edit` before treating either as
  final, keeping only claims traceable to the issue text or to my own
  verified test runs.
- My first attempt to background the full test suite used manual `&` +
  `disown` inside a `run_in_background: true` Bash call; the tool considered
  the call "complete" once the 2-second wrapper script returned, and the
  detached `Rscript` process was killed along with it (confirmed: `ps aux`
  showed no such process running afterward, and the log file had only 2
  lines). Redid it by passing the `Rscript` command itself with
  `run_in_background: true` and no manual backgrounding, which the tool
  tracks correctly to actual process exit.
- `devtools::test()`'s default reporter writes progress using `\r` "SKIP:" /
  "WARNING:" / "ERROR:" section headers rather than `── Failure ══` blocks
  (that format only appeared when running individual files via
  `testthat::test_file()`); had to search for the literal `ERROR:` prefix to
  locate the 3 failures in a 3303-line log.

## 9. Team Learning

**Curie (implementation):** the six call sites sharing `.assert_no_augmented_lhs()`
all live inside the single large `rewrite_canonical_aliases()` closure, so
threading one new parameter through its signature reached every call site
without needing per-site plumbing — worth checking function-nesting boundaries
before assuming a fix needs N separate signature changes.

## 10. Known Limitations And Next Actions

- The augmented-slope LHS classifiers (`.gllvmTMB_lhs_form()`,
  `.match_wide_intercept_slopes()`, `.match_long_intercept_slopes()`, and the
  module-level `.is_zero_plus_trait()` they share) still hardcode the literal
  `"trait"` and do not consult `trait_col`. This means a user with a
  non-default trait column who tries the genuinely-supported augmented
  random-slope form (e.g. `latent(0 + variable + (0 + variable):x | g, d)`)
  will still be misclassified as `"unsupported"` and hit the (now correctly
  worded) abort, rather than being routed to the random-regression engine.
  This is explicitly out of scope per the issue's own "Not in scope" section,
  but is a natural next slice if a user reports it.
- PR #1193 is **DRAFT**, not merged. Maintainer review requested.
