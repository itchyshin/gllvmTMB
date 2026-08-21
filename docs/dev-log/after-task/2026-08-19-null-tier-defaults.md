# After Task: `unit_obs` / `cluster` default to `NULL`, not concrete column names

**Branch**: `claude/null-tier-defaults-20260819`
**Date**: `2026-08-19`
**Roles (engaged)**: `Curie (implementation)`

## 1. Goal

`gllvmTMB()`'s `unit_obs` and `cluster` arguments are optional grouping
slots, but their old defaults (`"site_species"`, `"species"`) read as
required column names. An external user (iwogross, a paper x item
systematic map with no sites and no species) manufactured meaningless
`site_species` / `cluster` columns purely to satisfy the signature, and
hit an unhelpful `"Column site not found in data"` error that did not
say which argument wanted the column. This slice changes the defaults to
`NULL` (resolved internally to the historical values, bit-identically)
and fixes the error message to name the argument.

## 2. Implemented

- `unit_obs` and `cluster` now default to `NULL` in `gllvmTMB()`'s
  signature. Resolution (`unit_obs <- unit_obs %||% "site_species"`,
  `cluster <- cluster %||% "species"`) happens at the top of the function
  body, before any consumer, using the package's existing `%||%`
  (`R/fit-multi.R`).
- Passing `unit_obs = NULL` / `cluster = NULL` explicitly is equivalent
  to omitting them (both resolve the same way).
- The internal `site`/`species` aliasing (deprecated `site =` / `species
  =` arguments) is untouched and still works: the `missing(cluster)`
  check at the `species` alias conflict guard is provably redundant with
  its accompanying `identical(cluster, "species")` check (verified by
  case analysis: when `cluster` is not passed, `missing()` is `TRUE` AND
  `cluster` equals the default, so both branches already agreed before
  this change) so reassigning `cluster` earlier does not change its
  behaviour, even though `missing()` on a reassigned parameter always
  reports `FALSE` post-reassignment in R.
- Fixed the misleading `sprintf("Column %s not found in data", col)`
  error (was the literal error the motivating user hit) with two
  `cli::cli_abort()` calls, one for `trait` and one for `unit`, each
  naming the argument and the value that was looked for -- in the style
  of the existing `unit_obs` error already in the file.
- Roxygen docs for `unit_obs` and `cluster` now say "Optional." and
  describe what happens when omitted (no register codes).
- NEWS.md entry describing the behaviour change and its motivation.

## 3. Files Changed

- `R/gllvmTMB.R` -- signature, early resolution, error-message fix,
  roxygen `@param` text for `unit_obs` / `cluster`.
- `man/gllvmTMB.Rd` -- regenerated via `devtools::document()`.
- `NEWS.md` -- new entry (development version 0.7.0 section; no
  DESCRIPTION bump, per instruction).
- `tests/testthat/test-null-tier-defaults.R` -- new test file (5
  `test_that()` blocks).
- `docs/dev-log/after-task/2026-08-19-null-tier-defaults.md` -- this
  report.
- `docs/dev-log/check-log.md` -- entry (see below).

## 3a. Decisions and Rejected Alternatives

- **Decision:** resolve `unit_obs`/`cluster` at the very top of the
  function body (before `estimator_missing <- missing(estimator)`),
  rather than immediately before their first `identical()`/`%in%` use
  further down. **Rationale:** "EARLY, before any consumer" per the
  task brief; the wide-format `traits()` recursion (lines ~695-750)
  merely forwards `unit_obs`/`cluster` into a recursive `gllvmTMB()`
  call, which re-resolves independently, so resolving before or after
  that branch is behaviourally identical -- top-of-function is simplest
  and least likely to be missed by a future edit. **Confidence:** high
  (proved by the bit-identical fit evidence below, which exercises the
  post-recursion long-format path).
- **Decision:** did NOT touch `gllvmTMB_multi_fit()`'s own
  `unit_obs = "site_species"` internal default (`R/fit-multi.R:700`).
  **Rationale:** that is a `@noRd` internal helper always called from
  `gllvmTMB()` with `unit_obs = unit_obs` (the already-resolved,
  never-NULL value) -- its own default is dead code, out of scope for a
  public-signature change. **Rejected alternative:** changing it too,
  for "consistency" -- rejected as scope creep on an internal function
  the task did not ask about. **Confidence:** high.
- **Decision:** did not modify the `!missing(cluster) &&
  !identical(cluster, "species")` conflict check at the `species=`
  deprecated-alias guard. **Rationale:** proved redundant by case
  analysis (see Implemented, above) -- the `missing()` term never
  changes the outcome, in either the old or new code, so no textual
  change is needed. **Rejected alternative:** replacing `missing()`
  with a manually-captured flag -- rejected as unnecessary surface
  area on the surgical-change principle. **Confidence:** high (verified
  empirically in a scratch R session: `missing(x)` after `x <- ...`
  reassignment always reports `FALSE`, confirming the check degrades to
  `!identical(cluster, "species")`, which is exactly the redundant
  branch).

## 4. Checks Run

- `devtools::load_all(".")` -- loads clean.
- `devtools::document(quiet = TRUE)` -- regenerated `man/gllvmTMB.Rd`
  correctly (3 pre-existing, unrelated `@export`/`@exportS3Method`
  warnings on `AIC.gllvmTMB_multi` / `BIC.gllvmTMB_multi` /
  `anova.gllvmTMB_multi` in `R/aghq-report.R` -- confirmed present on
  `origin/main` before this change, not introduced by it).
- `pkgdown::check_pkgdown()` -- "No problems found."
- `NOT_CRAN=true` `testthat::test_file("tests/testthat/test-null-tier-defaults.R")`
  -- all pass.
- `NOT_CRAN=true` `testthat::test_file("tests/testthat/test-reader-facing-no-register-codes.R")`
  -- passes (no register codes leaked into the new roxygen text).
- `NOT_CRAN=true devtools::test(".")` -- full suite, run detached to
  completion. See verbatim tail in the reply to the dispatcher; PASS
  count / FAIL count recorded there.
- Manual bit-identical proof (two separate worktrees, one at
  `origin/main` HEAD `147da385` and one with this change, same RNG-seeded
  fixture): fitting `value ~ 0 + trait + latent(0 + trait | site, d = 1)`
  gaussian on a 12-site x 4-trait long-format fixture with NO `species`
  and NO `site_species` column gives identical `logLik` (`-47.057686517392817`,
  `identical()` TRUE, not just equal-to-tolerance) and identical
  `fit$opt$par` across three calls: (a) old signature with explicit
  `unit_obs = "site_species", cluster = "species"` on `origin/main`
  before this change, (b) new signature with both omitted, (c) new
  signature with both passed explicitly as `NULL`.

## 5. Tests of the Tests

- "unit_obs = NULL / cluster = NULL explicit gives the same fit as
  omitting them and as the old string defaults" -- would fail (was
  manually verified failing, pre-change, using distinct RNG seeds or an
  unresolved `NULL` reaching `%in% names(data)`) if the `%||%`
  resolution were missing or misplaced; the manual before/after proof
  above is the same check run independently outside testthat.
- "a data frame with no `site_species` and no `species` column fits
  without error" -- exercises the existing graceful-absence synthesis
  path (`data$site_species <- factor(paste(...))`, placeholder
  `species` factor); this already worked pre-change and is a regression
  guard, not new behaviour.
- "a missing `trait`/`unit` column aborts naming the argument" --
  regex-asserts on the literal argument name and value in the message
  text; would fail against the old `sprintf("Column %s not found in
  data", col)` message, which named neither.
- "a non-default `unit_obs` absent from data still aborts with the
  existing helpful message" -- regression guard on the
  already-cli_abort-styled message at the top of the validation block,
  untouched by this change.

## 6. Consistency Audit

- `rg 'unit_obs\s*=\s*"site_species"|cluster\s*=\s*"species"' R/*.R`
  -- only roxygen `@examples` comments elsewhere (`R/brms-sugar.R`,
  `R/animal-keyword.R`, `R/extract-*.R`) and the internal
  `gllvmTMB_multi_fit()` default, all passing explicit values or dead
  internal defaults; none affected by this change.
- `git diff --name-only origin/main...HEAD -- R/ src/ DESCRIPTION` --
  `R/gllvmTMB.R` only under `R/`; no `src/` change; no `DESCRIPTION`
  change (confirmed, per instruction: no capability headline, no
  version bump).
- No other call site relies on `gllvmTMB()`'s own `unit_obs`/`cluster`
  defaults except through the public entry point itself.

## 7. Roadmap Tick

N/A -- small API-signalling fix, not a roadmap item.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This was dispatched
directly by the maintainer from an external user report (motivation
section above), not tracked as a GitHub issue at request time.

## 8. What Did Not Go Smoothly

- Confirming the `missing(cluster)` redundancy required an empirical R
  check (reassigning a formal parameter makes `missing()` report
  `FALSE` afterward, regardless of the original call) rather than
  reasoning from the R language docs alone -- worth remembering for any
  future default-signalling change that touches a parameter checked
  with `missing()` downstream.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Curie: a default that reads as a required value (a concrete ecology
noun) rather than as "optional, supply if you have it" (`NULL`) is
itself a usability bug, independent of what the default resolves to.
The fix here changes zero runtime behaviour for any existing caller and
only changes what the signature *signals* -- exactly the kind of
low-risk, high-clarity change worth landing on its own, separate from
any accuracy or feature work.

## 10. Known Limitations And Next Actions

- `unit`'s default (`"site"`) is unchanged by design (per the task
  brief: `unit` is genuinely required, and renaming its default is a
  separate design decision). A user with no column named `site` and no
  `unit` argument passed will still hit the (now argument-named)
  "unit is not a column in data" error -- that is correct, not a bug,
  since `unit` truly is mandatory.
- No further slices identified; this is a complete, bounded change.
