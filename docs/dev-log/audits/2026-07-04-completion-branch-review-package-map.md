# Completion Branch Review Package Map

**Date**: 2026-07-04
**Branch**: `codex/r-bridge-grouped-dispersion`
**Head when written**: `64d8a47d`
**Roles**: Ada, Rose, Shannon, Grace

## Why This Exists

This branch is no longer a small feature branch. It should be reviewed as a
package of slices, or split from a fresh base, before any public merge.

Current evidence:

- `git status --short --branch`: clean, ahead of origin by 112 commits.
- `git log --oneline --no-merges origin/main..HEAD | wc -l`: 174 commits.
- `git diff --shortstat origin/main...HEAD`: 516 files changed, 78275
  insertions, 16063 deletions.
- Changed-file top-level counts: docs 317, man 62, tests 52, R 35,
  vignettes 30, plus small inst/data-raw/src/tool/root metadata changes.

## Review Slices

### Slice A: Route-Matrix And Inference Truth-Lock

Primary files:

- `R/z-confint-gllvmTMB.R`
- `R/bootstrap-sigma.R`
- `R/profile-derived.R`
- `R/profile-derived-curves.R`
- `R/profile-targets.R`
- `R/communality-ci.R`
- `R/phylo-signal-ci.R`
- `tests/testthat/test-confint-bootstrap.R`
- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-profile-targets.R`
- `tests/testthat/test-sigma-profile-bootstrap-controls.R`

Review question: do all interval routes fail loud or return honest
`interval_status` metadata, without implying calibration?

Minimum checks:

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
```

Heavy/profile checks remain opt-in and must not become public calibration
claims unless run with an explicit design.

### Slice B: Extractors And Plotting

Primary files:

- `R/extract-correlations.R`
- `R/extract-sigma.R`
- `R/extract-sigma-table.R`
- `R/plot-covariance-tables.R`
- `R/plot-gllvmTMB.R`
- `R/rotate-loadings.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `tests/testthat/test-rotate-compare-loadings.R`

Review question: do plot helpers display supplied uncertainty and metadata
honestly, without computing or implying new calibration?

Minimum checks:

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-gllvmTMB.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-covariance-tables.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-rotate-compare-loadings.R", reporter = "summary")'
```

### Slice C: Julia Bridge Truth Matrix

Primary files:

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- bridge-facing Rd topics

Review question: does the bridge ledger describe actual R transport and native
GLLVM.jl payloads without claiming R parity where it is only gated or point-only?

Minimum checks:

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Live GLLVM.jl checks require an explicit `GLLVM_JL_PATH`; skipped live tests are
not parity evidence.

### Slice D: Formula Grammar, Unique/Psi, And Structural Dependencies

Primary files:

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `R/unique-keyword.R`
- `R/kernel-helpers.R`
- `R/kernel-keywords.R`
- `R/traits-keyword.R`
- `src/gllvmTMB.cpp`
- parser/keyword tests
- `docs/design/01-formula-grammar.md`
- `docs/design/04-random-effects.md`

Review question: do public examples and guards agree with the current syntax,
especially around `unique`, `latent`, source-specific structural tiers, and
fail-loud boundaries?

Minimum checks:

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-keyword-grid.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R", reporter = "summary")'
```

### Slice E: Coevolution / Kernel Capability

Primary files:

- `R/kernel-helpers.R`
- `R/kernel-keywords.R`
- `R/extract-two-psi-cross-check.R`
- `tests/testthat/test-coevolution-prototype.R`
- `tests/testthat/test-coevolution-recovery.R`
- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`

Review question: is this still internal/partial where recovery is narrow, and
does wording avoid promoting exploratory coevolution surfaces beyond evidence?

Minimum checks:

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-prototype.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-recovery.R", reporter = "summary")'
```

Run the larger two-kernel file only after deciding the time budget.

### Slice F: Public Docs, Rd, Articles, Mission Control

Primary files:

- `README.md`
- `NEWS.md`
- `man/*.Rd`
- `vignettes/articles/*.Rmd`
- `docs/dev-log/dashboard/*`
- `_pkgdown.yml`
- `docs/design/35-validation-debt-register.md`

Review question: do user-facing claims map to validation rows, and do internal
articles stay internal where evidence is still partial?

Minimum checks:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
```

Run `devtools::check(args = "--no-manual", quiet = TRUE)` only after the focused
slice checks are green.

## Recommended Review Order

1. Route-matrix/inference truth-lock.
2. Extractors and plotting.
3. Formula grammar and source-guard boundaries.
4. Julia bridge truth matrix, if this branch keeps bridge content.
5. Coevolution/kernel content.
6. Public docs/Rd/pkgdown/release hardening.

## Consolidation Decision

Do not keep adding capability to this branch. If more implementation is needed,
start from this map and either:

- split review slices from a fresh base, or
- prepare one deliberately large review PR with sectioned evidence and a clear
  "no public calibration claim" boundary.

No push or PR action is authorized by this note.

## 2026-07-05 Validation Update

Head before this validation slice: `f0a84dc1`.

The minimum review-map checks have now been run locally with opt-in gates where
the default test files otherwise skip the meaningful rows:

- Slice A inference truth-lock: `test-confint-bootstrap.R`,
  `test-confint-derived.R`, and `test-profile-targets.R` passed under
  `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`.
- Slice B extractor/plotting: `test-plot-gllvmTMB.R`,
  `test-plot-covariance-tables.R`, and `test-rotate-compare-loadings.R`
  passed.
- Slice C Julia bridge truth matrix: `test-julia-bridge.R` passed default
  R-side checks; 13 live-GLLVM rows skipped because `GLLVM_JL_PATH` was not
  configured.
- Slice D formula grammar / structural guards: `test-canonical-keywords.R`
  passed with only the expected INLA skips; `test-keyword-grid.R` and
  `test-ordinary-latent-random-regression.R` passed under `NOT_CRAN=true`.
- Slice E coevolution/kernel: `test-coevolution-prototype.R` and
  `test-coevolution-recovery.R` passed under
  `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`.
- Slice F public docs/release gates: `devtools::document(quiet = TRUE)` left
  the tree clean, dashboard JSON validated, `pkgdown::check_pkgdown()` reported
  no problems, and `devtools::check(args = "--no-manual", quiet = TRUE)` passed
  after fixing the source-audit test path for `R CMD check`.

Not run: the large `test-coevolution-two-kernel.R` heavy sweep, live
`GLLVM_JL_PATH` bridge tests, INLA-dependent spatial parser rows, vdiffr visual
snapshots, and broad Totoro/DRAC calibration campaigns.
