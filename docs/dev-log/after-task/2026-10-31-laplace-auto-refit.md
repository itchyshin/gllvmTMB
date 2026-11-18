## 1. Goal

Implement maintainer decision A on #1389: when the Laplace-accuracy audit
fires, refit with AGHQ automatically and report that fit.

## 2. Implemented

- `gllvmTMBcontrol(laplace_auto_refit = TRUE)` (new, default on). After the
  Laplace fit, if the audit (`.gllvmTMB_laplace_accuracy()`) reports optimism
  above `laplace_warn_thresh`, `gllvmTMB()` refits with `aghq = 9`, emits a
  classed message (`gllvmTMB_laplace_auto_refit`), and returns the AGHQ fit with
  provenance in `fit$laplace_auto_refit`.
- `gllvmTMBcontrol()` now stores `aghq_explicit` so an explicit `aghq = FALSE`
  is respected.
- The fit-time warning reuses the audit result when no refit happened (no second
  audit evaluation).
- `.bootstrap_refit_control()` sets `laplace_auto_refit = FALSE` (sibling fix).

## 3. Mathematical Contract

No likelihood, TMB or family change; `src/gllvmTMB.cpp` untouched. The refit is
the existing `aghq = 9` route at its defaults, including the default loading
ridge (`tau = 2`).

## 4. Files Changed

`R/gllvmTMB.R`, `R/bootstrap-sigma.R`, `man/gllvmTMBcontrol.Rd`, `NEWS.md`,
`docs/dev-log/decisions.md`, `tests/testthat/test-degenerate-laplace-optima.R`,
this report.

## 5. Evidence and Checks

See the PR body for full-suite counts (PR vs main) and CI state. Synthetic
fixture (probit, d = 2, n = 80, seed 5): Laplace logLik -279.48, quadrature at
the same parameters -296.61 (optimism 17.1); AGHQ refit -286.58 (ridge 2),
-286.41 (no ridge).

## 6. Tests of the Tests

The regression tests use a real, unmocked firing fixture (no psychTools), and
check the refit, the opt-out, each exclusion, and the failure fallback. The
older mocked warning tests now pass `laplace_auto_refit = FALSE` so they still
exercise the warning.

Full-suite regressions found and handled (PR vs main): `test-control-field-surface`
(new internal control field declared), `test-confirmatory-lambda` and
`test-missing-response-nongaussian` (both now pass `laplace_auto_refit = FALSE`
with a comment: the first needs `getLoadings()`, which AGHQ fits do not support;
the second compares two fits that must use the same estimator).

## 7. Issue Ledger and Roadmap

Refs #1389. (a) Resolved by #1727: `getLoadings()`/`extract_ordination()` now work on AGHQ fits (see the 2026-10-31 follow-up in decisions.md). Open for the maintainer: (b) whether the auto-refit should be
unpenalised (`aghq_ridge = Inf`).
Siblings not changed: `coverage-study`, `check-identifiability`, `cv-internal`
and `extract-two-psi-cross-check` call `gllvmTMB()` at default control, so they
inherit the new default.
