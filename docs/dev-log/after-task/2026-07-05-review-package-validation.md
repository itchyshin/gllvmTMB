# Review Package Validation

**Branch**: `codex/r-bridge-grouped-dispersion`
**Start head**: `f0a84dc1`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Curie / Grace / Rose / Shannon`

## 1. Goal

Move the gllvmTMB completion branch from issue reconciliation toward a
reviewable package by running the existing review-map validation ladder and
repairing only current-state failures.

## 2. Implemented

- Ran the minimum checks from the completion branch review package map.
- Re-ran the skipped-by-default inference and coevolution checks under
  `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true` where required for meaningful
  evidence.
- Fixed one `R CMD check` failure in `test-tmb-ad-safe-clamps.R`: the test now
  searches source-tree and `00_pkg_src` candidates for `src/gllvmTMB.cpp`, then
  skips only when the source file is unavailable in an installed-package test
  context. The local source-tree test still reads and audits the C++ file.
- Recorded the validation update in the review package map.

## 3. Files Changed

- `tests/testthat/test-tmb-ad-safe-clamps.R`
- `docs/dev-log/audits/2026-07-04-completion-branch-review-package-map.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-review-package-validation.md`

## 3a. Decisions And Rejected Alternatives

Decision: keep the `gll_clamp()` source audit active for source-tree runs, but
skip when source files are unavailable under installed-package `R CMD check`.

Rationale: the source audit tests C++ implementation text, not runtime R API
behavior. The package check installs the package and may not expose the source
tree at the same relative path.

Rejected alternative: remove or weaken the source audit. That would lose the
AD-safe clamp regression for local/source-tree validation.

## 4. Checks Run

Focused review-map checks:

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-keyword-grid.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-gllvmTMB.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-plot-covariance-tables.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-rotate-compare-loadings.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-prototype.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-recovery.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R", reporter = "summary")'
```

Public/release gates:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
git diff --check
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Results:

- Slice A inference checks passed under the heavy gate.
- Slice B extractor/plot checks passed.
- Slice C `test-julia-bridge.R` had already passed default R-side checks in the
  previous reconciliation slice; live rows remain skipped without
  `GLLVM_JL_PATH`.
- Slice D grammar/structural checks passed under `NOT_CRAN=true`; INLA rows
  remain skipped because INLA is not installed.
- Slice E bounded coevolution checks passed under the heavy gate.
- `devtools::document(quiet = TRUE)` left the tree clean.
- Dashboard JSON validation passed.
- `pkgdown::check_pkgdown()` reported no problems.
- First `devtools::check(args = "--no-manual", quiet = TRUE)` failed only on
  `test-tmb-ad-safe-clamps.R` path resolution under `R CMD check`.
- After the test-path fix, `test-tmb-ad-safe-clamps.R` passed locally and
  `devtools::check(args = "--no-manual", quiet = TRUE)` passed with
  `0 errors`, `0 warnings`, and `0 notes`.

## 5. Tests Of The Tests

The new source-path logic was verified two ways:

- source-tree `test-tmb-ad-safe-clamps.R` still reads `src/gllvmTMB.cpp` and
  passes all seven clamp assertions;
- installed-package `R CMD check` no longer errors when the direct source path
  is unavailable.

## 6. Consistency Audit

This slice did not change package API, formula grammar, likelihood code,
dashboard metrics, or public claims. It only fixed a test portability issue and
recorded validation evidence.

## 7. Roadmap Tick

No validation-debt status row changed. The practical status moved from
"focused checks mostly green" to "review package has passed local no-manual
package check."

## 7a. GitHub Issue Ledger

No GitHub issues were closed or commented. No push or PR was opened.

## 8. What Did Not Go Smoothly

The broad package check found a source-path assumption that focused repo-root
tests missed. That is exactly why the full check gate belongs before any PR
claim.

## 9. Team Learning

Ada: the branch is now much closer to a reviewable package, but it remains too
large to keep widening casually.

Fisher: passing route and package checks still does not prove interval coverage.

Curie: opt-in tests must be run with the right environment variables; default
skips are not evidence.

Grace: local `R CMD check --no-manual` is green; live bridge, INLA, vdiffr, and
large heavy sweeps remain explicit follow-ups.

Rose: document the first failed check as well as the passing rerun, so the next
reviewer knows what was actually fixed.

## 10. Known Limitations And Next Actions

- Not run: `test-coevolution-two-kernel.R` heavy sweep, live `GLLVM_JL_PATH`
  bridge tests, INLA spatial rows, vdiffr snapshots, Totoro/DRAC calibration,
  or a full heavy test campaign.
- Next best action: either prepare/push a review PR if authorized, or run the
  next explicitly scoped heavy/cross-system lane with a frozen denominator plan.
