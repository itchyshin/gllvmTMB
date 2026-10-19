## 1. Goal

Finish PR #1538 (refs #1379): `extract_repeatability(method = "wald")` must not return NaN or unflagged intervals from a Hessian that is not positive-definite.

## 2. Implemented

- An all-non-finite fixed-effect covariance stops through `.confint_require_sdreport()` with class `gllvmTMB_confint_nonfinite_se`, as `confint(method = "wald")` already did. Before, the function returned NaN `lower` and `upper` with no message.
- A finite covariance with `pdHess = FALSE` warns with class `gllvmTMB_repeatability_nonpd_hessian`, names `pdHess = FALSE`, and still returns the point estimate. Before, it returned ordinary-looking intervals.
- Follow-up in this session: the shared gate's error offered `method = "profile"` as the way out. `extract_repeatability()` has withdrawn its profile route and aborts on it, so that advice led to a second error. The gate now takes `route` (default `"profile"`), and `extract_repeatability()` passes `"bootstrap"`, which matches its own pdHess warning.

No likelihood, family, formula grammar or `src/` change.

## 3a. Decisions and Rejected Alternatives

- A `route` argument on the shared gate, rather than a copy of the non-finite check inside `extract_repeatability()`. One detector and one condition class stay shared across `confint()`, `vcov()` and `extract_repeatability()`.
- The `NAMESPACE` rewrite that `devtools::document()` proposes (`S3method(stats::sigma, ...)` to `S3method(sigma, ...)`) was not committed. It is drift already on main: commit 273b7776 (#1407) hand-edited `NAMESPACE` without changing the roxygen tag, so committing the rewrite would revert #1407. #1599 made the same call.
- `NEWS.md` not edited, as in the original PR. The proposed line is in the PR body.

## 4. Files Touched

- `R/extract-repeatability.R`: the two gates, with `route = "bootstrap"`.
- `R/z-confint-gllvmTMB.R`: `route` argument on `.confint_require_sdreport()`; the default keeps every existing message.
- `tests/testthat/test-extract-repeatability-wald-pdhess.R`: new; error, warning and silent cases, and an assertion that the error names `method = "bootstrap"` and not `method = "profile"`.
- `docs/dev-log/after-task/2026-10-19-extract-repeatability-wald-pdhess.md`: this report.

## 5. Checks Run

- Installed builds of `main` @ `a6ccd827` and of the branch into separate temporary libraries (`R CMD INSTALL`, R 4.6.0, macOS arm64).
- `test-extract-repeatability-wald-pdhess.R` against `main`: 3 failures and 1 error. Against the branch: 8 of 8 pass.
- `GLLVMTMB_HEAVY_TESTS=1` on the new file plus `test-extract-repeatability-bootstrap.R`, `test-m1-6-extract-repeatability-mixed-family.R`, `test-standard-errors.R` and `test-m2-2b-binary-cis-extractors.R`: 124 expectations, 0 failures, 0 errors, 0 skips.
- Full suite, `devtools::test()` with the routine gate (heavy tests off, as CI runs it): 691 files, 4,403 tests, 30,784 expectations in 1 h 18 min: 29,818 passed, 887 tests skipped, and 18 expectations failed in 12 tests (one of which also errored). All 12 fail the same way on a clean `main` @ `a6ccd827` checkout with the `main` build, so none comes from this PR. `test-control-field-surface.R`, `test-loading-unpack-contract.R` and the two `test-interval-calibration-*` files are source-scan tests named in #1563, which skip under `R CMD check`. The others are `test-aghq-multistart-convergence.R` (the #843 test), `test-plot-visual-snapshots.R` (three visual snapshots), `test-reader-facing-no-register-codes.R`, `test-restart-selection-1335.R` and `test-va-r3-prototype.R` (the seed-12 truncated-NB2 case that #1599 also recorded on base).
- `devtools::document()` with roxygen 8.0.0: no `.Rd` change; the `NAMESPACE` drift above was restored to the committed text.
- The rendered gate messages for `confint()` (non-finite and missing `sd_report`) and `vcov()` are identical on `main` and on the branch.

## 6. Tests of the Tests

The forcing file fails on `main` in two of its three tests: the error case (no error thrown, and the new message assertion errors because `main` returns a data frame), and the warning case (no warning). The silent case passes on both, as it should. The finite-covariance cases pin `cov.fixed` to `diag(1e-3, k)` because the fit's own covariance is all-NaN on some BLAS builds (CI, and this Mac at seed 1), which would otherwise route those cases into the error gate.

## 7a. Issue Ledger

- **#1379**: open. This PR handles `extract_repeatability()` only, so it says `Refs`. The communality, phylo-signal, proportions and loading-uncertainty Wald readers named in the issue are untouched.
- **#1393**: open. `bootstrap_Sigma()` refits drop `unit_obs`, so `extract_repeatability(method = "bootstrap")` returns NA bounds on any fit with a custom `unit_obs` column, including the #1379 fixture. Reproduced on `main` and on the branch (every refit fails with "Unsupported grouping"). The new advice names this route because it is the only other interval method the function accepts; the bug itself belongs to #1393.

## 8. Consistency Audit

- Callers of `.confint_require_sdreport()`: `confint()` (two calls), `vcov()` (one), `extract_repeatability()` (one). Only the last passes `route`.
- `vcov()`'s refusal also offers `method = "profile"`, though `vcov()` has no `method` argument. That predates this PR and is left unchanged.
- No open PR edits the same lines: #1550, #1565 and #1567 touch these two files in other hunks.

## 9. What Did Not Go Smoothly

The first two installs started before the temporary library folders existed, because the worktree checkout ran past the tool timeout and the `mkdir` after it had not yet run. Both were re-run once the checkout finished.

## 10. Known Residuals

- The bootstrap route returns NA bounds for custom `unit_obs` fits (#1393).
- The remaining Wald readers in #1379.
- `vcov()` refusal advice, as noted in section 8.
- No `NEWS.md` entry yet.

## 11. Team Learning

A shared refusal's advice is only right for callers that accept the route it names. When a caller has withdrawn that route, pass the caller's own working route, and check it by running it rather than by reading the documentation.

## 12. Cross-Product Coverage

| Surface | Coverage |
|---|---|
| `extract_repeatability(method = "wald")`, all-non-finite covariance | ✓ typed error, names `method = "bootstrap"` |
| `extract_repeatability(method = "wald")`, finite covariance, `pdHess = FALSE` | ✓ typed warning, point estimate kept |
| `extract_repeatability(method = "wald")`, PD Hessian | ✓ silent, unchanged |
| `confint()` and `vcov()` refusals | ✓ messages identical to `main` |
| `extract_repeatability(method = "bootstrap")` on custom `unit_obs` fits | ✗ does NOT cover; NA bounds, tracked in #1393 |
| Other Wald readers in #1379 | ✗ does NOT cover |
