# After Task: Spatial/Phylo Dispatch Deprecation Scanner Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Boole / Grace / Rose`

## 1. Goal

Close issue #629 by making `scan_for_deprecated()` stop warning on documented
`spatial()` and `phylo()` mode-dispatch calls while preserving warnings for the
legacy aliases.

## 2. Implemented

- `scan_for_deprecated()` now treats `spatial()` bar calls with intercept-only
  LHS, explicit `mode`, or explicit `mesh` as first-class dispatch calls, not
  as the old `spatial_unique()` alias.
- `scan_for_deprecated()` now treats `phylo()` bar calls as first-class
  dispatch calls, not as the old `phylo_scalar()` alias.
- Legacy aliases still warn: `spatial(0 + trait | coords)` and
  `phylo(species)`.
- Pure parser tests cover both no-warning dispatch paths and retained-warning
  legacy paths.

## 3. Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-scan-deprecated-namespace.R`
- `tests/testthat/test-spatial-deprecation.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-spatial-phylo-dispatch-deprecation-scanner.md`

## 3a. Decisions and Rejected Alternatives

Decision: narrow the scanner warning to legacy aliases rather than changing the
dispatch rewrite.

Rationale: the rewrite already distinguishes documented mode-dispatch from
legacy aliases. The bug was only in the pre-rewrite warning pass.

Rejected alternative: keep warning on all `spatial()` / `phylo()` calls but
make the text more nuanced. That would still tell users a first-class API is
deprecated when it is not.

Confidence: high for parser-warning behavior; no likelihood or engine behavior
changed.

## 4. Checks Run

```sh
gh issue view 629 --json number,title,state,body,url
Rscript --vanilla -e 'invisible(parse("R/brms-sugar.R")); invisible(parse("tests/testthat/test-scan-deprecated-namespace.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-scan-deprecated-namespace.R")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-mode-dispatch.R")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-deprecation.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-spatial-orientation-parser.R")'
```

Outcomes:

- Parse check: `parse-ok`.
- `test-scan-deprecated-namespace.R`: 11 pass, 0 fail, 0 skip.
- `test-spatial-mode-dispatch.R`: 12 pass, 0 fail, 0 skip under
  `NOT_CRAN=true`.
- `test-spatial-deprecation.R`: 7 pass, 0 fail, 0 skip under
  `NOT_CRAN=true`.
- `test-spatial-orientation-parser.R`: 6 pass, 0 fail, 0 skip.

## 5. Tests of the Tests

Boundary case: pure scanner tests verify that the no-mode legacy alias still
warns while explicit mode-dispatch and intercept-only dispatch do not.

Feature combination: the new tests combine namespace-safe scanner traversal with
replacement-specific deprecation messages and lifecycle warning behavior.

Failure-before-fix: before the change, the no-warning spatial dispatch checks
would have received the old `spatial_unique()` lifecycle warning, and the
no-warning phylo dispatch check would have received the old `phylo_scalar()`
message.

## 6. Consistency Audit

`rg -n "spatial\\(\\).*deprecated|phylo\\(\\).*deprecated|spatial\\(\\) emits" tests/testthat docs/design R/brms-sugar.R`

Verdict: pass after wording cleanup. Remaining hits describe legacy alias
deprecation or first-class mode-dispatch boundaries.

## 7. Roadmap Tick

N/A. This is a parser/deprecation truth repair under validation row `FG-13`, not
a new modelling capability.

## 7a. GitHub Issue Ledger

- #629 inspected and repaired locally.
- #628, #662, #674, #684, #685, #696, and #703 were inspected during the same
  sweep and found already fixed/stale against this branch.

No GitHub issue was closed or commented from this local slice.

## 8. What Did Not Go Smoothly

Several open issues are stale against the current local branch, so the issue
map needs a later GitHub-close pass after the branch is reviewed or merged.

## 9. Team Learning

Ada: continue separating stale issue evidence from code changes.

Boole: pre-rewrite scanner rules must mirror parser dispatch boundaries, or
warnings can contradict the accepted grammar.

Grace: pure scanner tests are cheaper and clearer than fitting SPDE fixtures
just to test warning text.

Rose: the row stays a truth repair. It does not promote broader spatial
coverage or source-specific LV support.

## 10. Known Limitations And Next Actions

This does not change the spatial or phylogenetic engines. It only aligns warning
behavior with the grammar already implemented. Broader spatial coverage,
augmented spatial random slopes, and source-specific `lv = ~ env` remain governed
by their existing validation rows.
