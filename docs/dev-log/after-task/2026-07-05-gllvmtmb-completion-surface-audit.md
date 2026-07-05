# After Task: gllvmTMB Completion Surface Audit

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Curie / Grace / Rose / Shannon`

## 1. Goal

Quantify the current state of the gllvmTMB completion Ultra-Plan after the
first truth-lock repairs, using local focused evidence rather than stale issue
counts. This was an audit-only checkpoint: no API, likelihood, formula grammar,
dashboard metric, public claim, Totoro job, or DRAC job changed.

## 2. Implemented

- Confirmed the branch was clean at `14c44ac2` and ahead of origin by 182
  commits before the audit note edits.
- Ran focused missing-response, missing-predictor, mixed-family, profile route,
  derived-confint, Lambda-confint, bootstrap-confint, profile-refit, and
  profile-proportion tests.
- Inspected the internal profile route matrix against the maintainer concern
  that profile likelihood must account for `unit`, `unit_obs`, `cluster`,
  `cluster2`, and structural-dependence split tiers.
- Recorded the current truth: route-level profile support exists for several
  unit/unit_obs/phy derived targets; cluster and cluster2 remain diagonal-only;
  spatial is partial/planned for several derived totals; augmented structural
  targets remain blocked except the `rho:unit_slope` selected-entry canary.

## 3. Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-gllvmtmb-completion-surface-audit.md`

## 3a. Decisions and Rejected Alternatives

Decision: treat this as a focused truth audit, not a package-code PR.

Rationale: the focused tests did not expose a live local failure. The important
work was to separate covered routing from heavy-gated calibration and to avoid
starting new profile or bootstrap compute while local route truth was still
being checked.

Rejected alternative: open a broad non-Gaussian or structural-profile
implementation immediately. That would mix new feature work with unresolved
surface accounting.

Confidence: medium-high for route truth, low for coverage calibration because
heavy gates were deliberately not run.

## 4. Checks Run

```sh
git status --short --branch
git rev-parse --short HEAD
rg -n '^\\| [A-Z0-9-]+ \\|.*\\| `(partial|blocked|opt-in|planned)` \\|' docs/design/35-validation-debt-register.md
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-response-gaussian.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-response-traits.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-data-robustfix.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-predictor-gaussian.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-predictor-binary.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-predictor-ordered.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-predictor-categorical.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-missing-predictor-phylo.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-ci.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-curves.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-derived-refit.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-proportions.R")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R")'
rg -n "unit_obs|cluster2|cluster|tier|level|unit_slope|phylo|spatial|animal|kernel" R/z-confint-gllvmTMB.R R/profile-derived.R R/profile-route-matrix.R R/extract-correlations.R R/extract-omega.R tests/testthat/test-profile-route-matrix.R tests/testthat/test-confint-derived.R tests/testthat/test-profile-derived-curves.R tests/testthat/test-profile-proportions.R tests/testthat/test-confint-lambda.R
```

Results:

- Missing response: no failures; heavy recovery cells skipped as designed.
- Missing predictors: no failures; heavy recovery/calibration cells skipped as
  designed.
- Mixed-family focused smoke: 13 pass.
- Profile route matrix: 282 pass.
- Derived CI / Lambda / bootstrap / proportions profile helpers: no failures;
  many endpoint or recovery cells remain heavy-gated.

## 5. Tests of the Tests

No tests were added or modified. This audit re-ran existing focused tests to
determine whether the next slice should be a repair or a promotion/calibration
gate.

## 6. Consistency Audit

Pattern:

```sh
rg -n "unit_obs|cluster2|cluster|tier|level|unit_slope|phylo|spatial|animal|kernel" R/z-confint-gllvmTMB.R R/profile-derived.R R/profile-route-matrix.R R/extract-correlations.R R/extract-omega.R tests/testthat/test-profile-route-matrix.R tests/testthat/test-confint-derived.R tests/testthat/test-profile-derived-curves.R tests/testthat/test-profile-proportions.R tests/testthat/test-confint-lambda.R
```

Verdict: the current profile route story is explicit and guarded. It is not a
blanket profile guarantee across all structural-dependence surfaces.

## 7. Roadmap Tick

N/A. No validation-debt row changed because no capability moved from partial or
blocked to covered.

## 7a. GitHub Issue Ledger

No issue was closed or commented from this audit. Several open issue rows appear
stale relative to this branch, but the audit did not use GitHub state changes.

## 8. What Did Not Go Smoothly

The open-issue surface is noisy relative to this long-running branch. The better
operating method is now validation-register-first, then focused tests, then
issue reconciliation only for rows that still fail locally.

## 9. Team Learning

Ada: the full Ultra-Plan is not a three-day task if release truth and
calibration are included. Current overall progress is about 15%.

Fisher: profile support must be discussed by estimand and tier. `pdHess = TRUE`
or a passing route test is not interval calibration.

Curie: focused tests are green for the audited routing surfaces, but many known
DGP and recovery tests remain behind `GLLVMTMB_HEAVY_TESTS=1`.

Grace: no Totoro or DRAC job should start from this checkpoint; the next compute
manifest needs frozen denominators and host provenance.

Rose: wording must keep "route covered" separate from "coverage calibrated" and
must not turn structural-point extraction into interval support.

Shannon: keep future commits small; this audit is intentionally documentation
only.

## 10. Known Limitations And Next Actions

- Full completion remains a multi-week arc: roughly 2-3 focused weeks, or
  3-5 calendar weeks if review, release checks, Totoro/DRAC calibration, and
  documentation synchronization are included.
- Next best implementation slice: choose one remaining real surface from the
  validation register rather than broadening immediately. Strong candidates are
  a non-Gaussian family-safety repair, a structural random-slope extractor
  boundary, or a small profile-calibration canary with a frozen manifest.
- Do not claim complete missing-data support, mixed-family intervals,
  source-specific `lv = ~ env`, or all structural profile intervals from this
  audit.
