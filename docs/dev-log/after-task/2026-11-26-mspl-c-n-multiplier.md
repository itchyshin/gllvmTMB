# After Task: MSPL c_N Multiplier Prerequisite

**Branch**: `codex/prior-table-current-main-r-20261125-v2`
**Date**: 2026-11-26
**Roles (engaged)**: No named review agents were launched; cross-lane source review was incorporated.

## 1. Goal

Carry the MSPL c_N multiplier prerequisite needed by the shared-table gllvmTMB candidate. Keep the multiplier private, preserve its default value of one, and preserve the Gamma unique-variance table prior refusal on the MSPL route.

## 2. Implemented

The fit builder now provides an inert `mspl_c_n_multiplier = 1` TMB data value for every fit. The MSPL resolver accepts only a single finite positive value, multiplies its resolved rate by that value, and passes the value to the TMB objective. The C++ objective scales the Gaussian/Hirose branch once and the mutually exclusive Bernoulli/Poisson/fallback branch once. The public `gllvmTMBcontrol()` formals are unchanged. The prior-table/MSPL refusal remains covered.

## 3. Mathematical Contract

For a private multiplier `m > 0`, the MSPL rate becomes `c_N^* = m c_N`; the default `m = 1` preserves the existing objective. The base rates are `2 sqrt(p_free / N_eff)` for Bernoulli, `2 sqrt(p_free / max(sum(y), 1))` for Poisson, `sqrt(2 / N_units)` for Gaussian/Hirose, and `1` for the current C++ fallback family modes. The multiplier scales the MSPL penalty contribution, while the unpenalized likelihood remains unchanged. This adds no public control formal or family likelihood and keeps the MSPL/Psi-prior refusal.

## 4. Files Changed

- `R/fit-multi.R`
- `R/mspl.R`
- `src/gllvmTMB.cpp`
- `tests/testthat/test-mspl-c-n-multiplier.R`
- `docs/dev-log/check-log.d/2026-11-26-prior-table-mspl-c-n-multiplier.md`
- `docs/dev-log/after-task/2026-11-26-mspl-c-n-multiplier.md`

No public documentation, generated help, NEWS, or roadmap entry changed because the multiplier remains a private source-level control and the default is unchanged.

## 5. Checks Run

- `OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter="mspl-c-n-multiplier|mspl-beta-public-door|mspl-nb2-fenced-tape", reporter="summary", stop_on_failure=TRUE)'`: passed. The existing Beta public-door test emitted its known implicit-unit deprecation warning; no failure occurred.
- `git diff --check`: passed.
- Full gllvmTMB suite: not run on this changed source.

## 6. Tests Of The Tests

Before source wiring, the focused test observed the missing TMB data field, identical multiplier-one/two objective values, and absent invalid-value errors. After wiring, it verifies default objective value and gradient agreement with a freshly rebuilt multiplier-one tape, multiplier sensitivity of objective and gradient, and the exact resolved rates for Bernoulli, Gaussian/Hirose, Poisson/event-count, and Beta fallback mode 6. It also checks malformed values and the Gamma-table/MSPL refusal. The Beta test checks only multiplier plumbing on the planned Beta door; it does not claim general Beta MSPL validation.

The gradient agreement between the existing fitted TMB object and a newly built tape has absolute differences below `7e-13` in the fixed fixture; a relative tolerance of `1e-6` accommodates this Laplace-tape numerical difference. The multiplier-one/two gradient sensitivity comparison remains a separate assertion and passes.

## 7. Consistency Audit

- `rg -n "mspl_N_units|MakeADFun" tests/testthat | rg "mspl_N_units|mspl.*MakeADFun|MakeADFun.*mspl"`: found the existing MSPL AD-function rebuild test and the new test; no additional manually assembled MSPL TMB data list needs the scalar.
- `rg -n "mspl_c_n_multiplier" R/fit-multi.R R/mspl.R src/gllvmTMB.cpp tests/testthat/test-mspl-c-n-multiplier.R`: source wiring, default value, resolver validation, objective branches, and focused tests agree on the same field name.
- `git diff --check`: no whitespace errors.

## 8. Roadmap Tick

N/A; no roadmap row changed.

## 9. GitHub Issue Ledger

Read-only PR checks inspected gllvmTMB #1965 (open draft at the prior candidate head 9d74123), #981 (open, multiplier donor), and #1964 (open draft; its `R/fit-multi.R` hunks are separate from the multiplier hunk). No PR comment, issue update, or new issue was made.

## 10. What Did Not Go Smoothly

An initial version placed the tests in the broad MSPL API file, so I moved them to a dedicated file. A first formula edit used an unsupported `latent(unit=...)` argument and was removed; the supported `gllvmTMB(unit="site")` argument now avoids the deprecation warning in the new fixture. A separate rebuilt-tape gradient comparison needed a tolerance reflecting sub-picounit absolute differences. Cross-lane review identified the need to exercise all rate branches; the final test covers the Gaussian, Poisson, and fallback cases in addition to Bernoulli.

## 11. Team Learning

Cross-lane review correctly asked for explicit Gaussian/Hirose, Poisson/event-count, and fallback-family coverage. It also checked the C++ control flow; the Gaussian assignment and non-Gaussian post-selection multiplication occur in mutually exclusive branches, so every tested family receives one multiplier application.

## 12. Design And Documentation Updates

No formula grammar, public API, family likelihood, or user-facing model documentation changed. The exact internal behavior and check boundary are recorded in the check-log shard above.

## 13. Known Limitations And Next Actions

The changed source is committed in this candidate branch, but the full gllvmTMB suite has not been run on it. Historical 9d74123 suite evidence does not cover these edits. Regenerate the complete test-file selection, run and reconcile the full R suite on this exact source, then update draft PR #1965. The four-package gate is still open: DRModels attempt-04 ended with one `is_converged(ok)` assertion failure in shard 1 and shard 2 exit 0; resolve that fixture/contract mismatch and rerun DRModels. No merge or release is authorized by this report.
