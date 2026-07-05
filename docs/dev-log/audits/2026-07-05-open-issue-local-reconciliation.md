# Open Issue Local Reconciliation

**Date**: 2026-07-05 03:58 MDT
**Branch**: `codex/r-bridge-grouped-dispersion`
**Head when audited**: `0b95b1a6`
**Roles**: Ada, Fisher, Curie, Rose, Shannon

## Purpose

The GitHub issue list still shows many open tickets that this long local branch
appears to have already fixed. This audit records the spot-checked local
evidence so the next reviewer does not re-fix solved problems or mistake stale
GitHub state for live package state.

This is a reconciliation artifact only. It does not close GitHub issues, push a
branch, change Mission Control, widen package APIs, or claim new interval
calibration.

## Current Branch Truth

- `git status --short --branch`: clean, ahead of
  `origin/codex/r-bridge-grouped-dispersion` by 192 commits.
- `git rev-parse --short HEAD`: `0b95b1a6`.
- `gh pr list --repo itchyshin/gllvmTMB --state open`: no open PR rows returned.
- Recent commits already contain many small local issue repairs, including
  inference, extractor, bridge, parser, and family-boundary guards.

## Spot-Checked Remote-Open Issues That Are Locally Fixed

| Issue | Local evidence | Local verdict |
| --- | --- | --- |
| #606 profile-to-bootstrap Sigma fallback ignores `nsim` / `seed` | `.confint_sigma_profile(object, parm, level, nsim, seed)` forwards caller controls into `.confint_sigma_bootstrap()`; `tests/testthat/test-sigma-profile-bootstrap-controls.R` is the regression; after-task `2026-07-04-sigma-profile-bootstrap-controls.md`. | Fixed locally; GitHub still open. |
| #620 / #621 Sigma Wald bounds use residual/Psi-only intervals for total Sigma | `.confint_sigma_wald()` now returns unavailable bounds for reduced-rank total Sigma instead of filling theta-diagonal bounds; CI-01 register row cites closure; after-task `2026-07-04-wald-sigma-total-variance-guard.md`. | Fixed locally; GitHub still open. |
| #702 correlation bootstrap merge leaves `interval_method = "none"` on missing rows | After-task `2026-07-04-correlation-plot-missing-interval-method.md` records `interval_method = "missing"` for requested-but-absent bootstrap intervals. | Fixed locally; GitHub still open. |
| #696 Julia bridge dispersion length mismatch is hidden as all-NA | `.gllvm_julia_dispersion_vector()` now errors when dispersion payload length is neither 1 nor the number of traits; `tests/testthat/test-julia-bridge.R` includes the length-mismatch regression; JUL-01 addendum records closure. | Fixed locally; GitHub still open. |
| #684 / #685 multi-start non-finite objective and selected-restart mismatch | `fit-multi.R` restart selection now excludes non-finite objectives from `best_opt` and selected provenance; MIS-20 register row cites #684/#685; after-task `2026-07-04-multistart-nonfinite-selection-guard.md`. | Fixed locally; GitHub still open. |
| #686 kernel separability compares permuted kernels positionally | `diagnose_kernel_separability()` aligns named kernels before similarity checks; COE-04 addendum records #686 closure; after-task `2026-07-04-kernel-separability-dimname-alignment.md`. | Fixed locally; GitHub still open. |
| #683 `extract_ICC_site()` returns NaN on zero total variance | EXT-12 register row records `NA`, not `NaN`, for zero-denominator ICC; after-task `2026-07-04-extractor-zero-boundary-guards.md`. | Fixed locally; GitHub still open. |
| #642 Julia bridge duplicate `(trait, unit)` long rows silently overwrite | `.gllvm_julia_assert_unique_trait_unit_cells()` guards response, X, and binomial-trial pivots; `tests/testthat/test-julia-bridge.R` includes duplicate-cell rejection; after-task `2026-07-04-julia-bridge-duplicate-trait-unit-guard.md`. | Fixed locally; GitHub still open. |
| #668 communality no-Psi `cli_abort()` hint bullet is swallowed | `profile-derived.R` and `profile-derived-curves.R` use vector-form `cli_abort()` for the actionable hint; after-task `2026-07-04-communality-profile-no-psi-cli-hint.md`. | Fixed locally; GitHub still open. |
| #678 median over integer `family_id` / `link_id` can fabricate a family/link | `predict.gllvmTMB_multi()` now uses `.modal_integer_id()` in the `newdata` response-scale family/link lookup; EXT-33 records the boundary; `tests/testthat/test-missing-data-robustfix.R` includes the even-mix `c(2, 4)` regression; after-task `2026-07-04-predict-newdata-modal-family-link.md`. | Fixed locally; GitHub still open. |

## Previously Observed Local-Fixed Cluster

The same branch also appears to have local fixes for #653, #643, #654, #660,
#679, #687, #614, #615, #693, #645, #704, #703, #674, #673, #625, #626, #627,
#629, #628, #662, #610, #589, #593, #632, #631, #641, #640, #604, #590, #596,
#582, #588, #587, #611, and #612. These were identified from local code,
validation-register rows, check-log entries, and after-task reports during the
same completion-arc triage, but this audit's detailed table is limited to the
issues rechecked at `0b95b1a6`.

## Still Real Work, Not Solved By Issue Reconciliation

The issue cleanup does not finish the Ultra-Plan. The remaining large work is
mostly capability depth and release truth:

- interval calibration: #565 and related profile/bootstrap/ADEMP evidence;
- release readiness: #486 plus final `devtools::check()` / pkgdown / NEWS /
  CRAN-facing synchronization;
- broader family validation and power simulation: #348 / #349;
- structural and coevolution expansion: #361 and the kernel/coev rows that
  remain explicitly partial;
- R-first policy decisions: #488 and bridge drift stay quiet unless Shinichi
  explicitly reopens Julia parity;
- design-expansion issues such as #622, #697, and #705 are not quick bug-fix
  tickets and should be scoped as separate slices.

## Operating Decision

Stop using the raw GitHub-open count as the main progress meter for this branch.
Use this order instead:

1. Validation register and after-task evidence.
2. Local focused tests for the touched surface.
3. Issue reconciliation comments or closures only after the branch is pushed or
   a PR is prepared.
4. New implementation only for issues that still fail against current local
   code.

## Next Best Slice

Prepare a review/merge package before adding broad capability. The next
practical slice is a focused validation pack for the already-fixed issue
cluster:

```sh
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-extractors-extra.R", reporter = "summary")'
```

Only after that pack is green should the branch move to full documentation,
pkgdown, and package check gates.

## Validation Pack Run After This Audit

The first focused pack was run after writing the audit:

```sh
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-extractors-extra.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
git diff --check
```

Results:

- `test-sigma-profile-bootstrap-controls.R`: default run skipped the heavy row
  as designed; heavy run passed 4 checks.
- `test-profile-route-matrix.R`: passed.
- `test-confint-lambda.R`: non-heavy checks passed; heavy rows skipped as
  designed.
- `test-extractors-extra.R`: passed, including the expected residual-floor
  informational message.
- `test-julia-bridge.R`: passed default R-side checks; 13 live-GLLVM rows
  skipped because `GLLVM_JL_PATH` was not configured.
- `git diff --check`: passed.
