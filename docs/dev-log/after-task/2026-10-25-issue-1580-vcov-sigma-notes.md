# After Task: vcov profile hint and extract_Sigma part notes

**Branch**: `cursor/issue-1580-vcov-sigma-notes-c93d`
**Date**: `2026-10-25`
**Roles (engaged)**: Emmy, Pat, Rose

## 1. Goal

Close two remaining #1580 items: `vcov()` offered `method = "profile"`
although it has no `method` argument, and `extract_Sigma(part =
"shared" / "unique")` printed that a link residual was added when
nothing was added.

## 2. Implemented

`vcov()` now passes `route = NULL` into `.confint_require_sdreport()`,
which omits the method hint. The residual note in `extract_Sigma()` is
recorded only when `part = "total"`.

## 3. Files Changed

- `R/z-confint-gllvmTMB.R`
- `R/vcov-coef.R`
- `R/extract-sigma.R`
- `tests/testthat/test-issue-1580-vcov-sigma-notes.R`
- `tests/testthat/test-standard-errors.R`
- `NEWS.md`
- `docs/dev-log/after-task/2026-10-25-issue-1580-vcov-sigma-notes.md`
- `docs/dev-log/check-log.d/2026-10-25-issue-1580-vcov-sigma-notes.md`

## 3a. Decisions and Rejected Alternatives

Decision: omit the method hint for `vcov()` rather than invent a
`method` argument. Rationale: the issue asked to stop naming an
argument that does not exist. Confidence: high.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-10-25-issue-1580-vcov-sigma-notes.md`.

## 5. Tests of the Tests

The vcov test fails if the profile hint returns. The extract_Sigma test
fails if `part = "shared"` still stores or prints the residual note,
and it checks that `part = "total"` still records the note.

## 6. Consistency Audit

- `rg -n "route = NULL" R/vcov-coef.R R/z-confint-gllvmTMB.R`
- `rg -n "identical\\(part, \"total\"\\)" R/extract-sigma.R`

## 7. Roadmap Tick

N/A

## 7a. GitHub Issue Ledger

- Inspected #1580. Print/summary de-duplication and
  extract_cross_correlations quieting already landed. This slice is
  the vcov hint and the extract_Sigma part note. Remaining items
  (sigma_eps naming indep(), multinomial internals, kernel_latent
  note, summary repeated three times) stay open, so the PR uses
  Refs #1580.

## 8. What Did Not Go Smoothly

None.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Emmy: the shared sdreport gate now lets a caller suppress a remedy
that it does not implement.

Pat: the vcov error now names `standard_errors(fit)` only.

Rose: NEWS states both items and does not claim the whole issue
closed.

## 10. Known Limitations And Next Actions

Still open on #1580: sigma_eps auto-suppression naming `indep()`,
multinomial mapped-off internals, kernel_latent phylo-equivalent
note, and the repeated unique=FALSE summary line.
