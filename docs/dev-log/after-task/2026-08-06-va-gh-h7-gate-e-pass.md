# After Task: VA(GH) H = 7 Gate E pass

## 1. Goal

Repair and independently re-test the seven scalar cells that failed the first
Gate E review, then record one honest 18-cell arithmetic/light verdict before
changing public defaults or launching Arc 2.

## 2. Implemented

The repair removes likelihood-changing clamps, stabilises Beta-family shapes and
zero-truncation normalisers, preserves fixed Tweedie power and Student df through
the adapter/TMB map, validates Student df metadata, and profiles fitted nuisance
parameters in fixed-effect VA-Wald covariance. Failure-discriminating right- and
left-tail, adapter, map, routing, gradient, Hessian, and constructor tests landed.

Gate E is PASS for all 18 scalar family/link cells. This report does not itself
change the public H, evaluator, or family fence; that promotion is the next slice.

## 3. Files Changed

Engine/API: `R/approximation-engine.R`, `R/families.R`, `R/va-r3-proto.R`,
`R/va-routing.R`, and `inst/tmb/gllvmTMB_va_r3.cpp`.

Tests: `tests/testthat/helper-va-all-family-oracles.R`,
`tests/testthat/test-approximation-engine.R`,
`tests/testthat/test-student-recovery.R`,
`tests/testthat/test-va-all-family-compiled.R`, and
`tests/testthat/test-va-routing-oracle.R`.

Evidence/process: `docs/design/110-va-gh-h7-all-scalar-families.md`,
`docs/dev-log/audits/2026-08-06-va-gh-h7-gate-e.md`, this report, and
`docs/dev-log/check-log.md`.

## 3a. Decisions and Rejected Alternatives

> **Decision**: Require independent tail densities and finite AD derivatives before
> changing any cell from NOT PASS to PASS.
> **Rationale**: Mild fixtures missed model-changing clamps and one shared
> normaliser defect.
> **Rejected alternative**: Treat healthy optimisation as likelihood correctness.
> **Confidence**: high.

> **Decision**: Keep Gate E distinct from Arc-2 recovery/coverage evidence.
> **Rationale**: Arithmetic correctness is necessary but cannot prove estimator
> recovery or uncertainty calibration.
> **Rejected alternative**: Advertise the all-family light pass as full validation.
> **Confidence**: high.

## 4. Files Touched

Section 3 is exhaustive. No public default, fence, README, NEWS, vignette, roxygen
claim, generated Rd file, pkgdown output, campaign runner, or remote-compute file
changed in this Gate E slice.

## 5. Checks Run

The targeted adapter/compiled/Student suite completed cleanly. The complete Arc 1
bundle—compiled arithmetic, independent oracles, 18 all-family light fits,
VA-Wald intervals, R3 prototype, and public routing—completed cleanly, with every
light cell healthy. `git diff --check` passed. The independent likelihood reviewer
recomputed all seven repaired cells using separate quadrature/density code and
returned PASS for each.

Full package tests, documentation generation, pkgdown, `R CMD check`, cross-OS CI,
Totoro, DRAC, gllvm, and GLLVM.jl were not run in this slice.

## 6. Tests of the Tests

The new cases satisfy failure-before-fix: they reproduce the former right-tail
clamps, the newly found far-left truncation error, dropped fixed metadata, and the
VA-Wald nuisance-conditioning defect. The left-tail cases also call the Hessian,
because an unsafe unselected `CondExp` branch can leave value/gradient finite while
killing second derivatives. Independent stable oracles replace underflowing
`tweedie::dtweedie()` and precision-losing base NB1 calculations.

## 7. Roadmap Tick

N/A. Design 110 and the Gate E audit carry this phase state. Public capability and
validation-debt rows remain for the promotion slice.

## 7a. Issue Ledger

No issue was created or changed. `gh pr list --state open` could not reach GitHub;
`git log --all --oneline --since="6 hours ago"` showed no foreign local lane.

## 8. Consistency Audit

`rg -n "fixed_tweedie_power|fixed_student_df" R tests/testthat` confirmed router,
adapter, fitter, objective map, and tests all carry the metadata. `rg -n
"va_r3_log1mexp" inst/tmb/gllvmTMB_va_r3.cpp` confirmed one shared stable helper
serves the affected truncation paths. `git diff --check` passed.

## 9. What Did Not Go Smoothly

The first Gate E fixtures were too mild and missed six clamps. The initial repair
then exposed an adapter call that both passed arguments to the wrong function and
dropped them before fitting. Finally, independent negative-tail probing found a
second truncation defect in a shared AD-safety helper. Treating each discovery as
a repeated-defect class produced the broader, stronger test matrix now retained.

## 10. Known Residuals

Gate E proves arithmetic/light health, not recovery depth or uncertainty coverage.
Public H remains 61, public auto still selects JJ for pure logit, and the public
fence still admits only three families until the next promotion slice. Arc 2 is
authorised but unlaunched. Multinomial and non-scalar architectures remain separate.

## 11. Team Learning

Gauss supplied the load-bearing independent density/AD verdict and found both the
adapter and far-left normaliser failures. Curie designed the failure-before-fix
matrix and identified where common R density functions lose extreme-tail precision.
Rose traced constructor metadata end-to-end and identified malformed Student df as
a neighbouring fail-open. Ada integrated the repairs without changing public scope
before the per-cell verdict existed.

## 12. Cross-Product Coverage

This phase covers the 18 scalar family/link cells in the ordinary private R3 VA
objective, fixed family metadata, H=7 arithmetic, compiled AD, all-family light fits,
fixed-effect profiled-Schur VA-Wald algebra, and retained latent posterior SD plumbing.
It does not cover multinomial, every covariance keyword/provider, missing predictors,
random slopes, full recovery/coverage, reader-facing promotion, or remote campaign
execution.
