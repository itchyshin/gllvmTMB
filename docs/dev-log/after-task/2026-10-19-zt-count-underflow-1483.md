# After Task: zero-truncated Poisson / NB2 truncation term in the far left tail (#1483)

**Branch**: `claude-a/gllvmTMB-1483`
**Date**: `2026-10-19`
**Roles (engaged)**: `Ada (single lane), Rose (neighbour audit)`

## 1. Goal

Fix #1483: the zero-truncated Poisson (fid 10) and NB2 (fid 11) rows renormalised with `logspace_sub(0, log P(0))`, which is `log(0)` once `exp(eta)` underflows. Write a test that fails on `main` first, then the smallest fix that makes it pass.

## 2. Implemented

- The failure starts far earlier than the issue's `eta < -745`. On `main` (measured on a fixed fixture, all three intercepts set to `eta`, loadings ~0):

  | quantity | first non-finite `eta` |
  |---|---|
  | Laplace gradient (`obj$gr`) | -237 |
  | Laplace objective (`obj$fn`) and the row kernel's Hessian | -355 |
  | row kernel gradient | -706 |
  | row kernel objective | -746 |

  The k-th derivative of `logspace_sub(0, -a)` in `log a` carries `1 / a^k`, which overflows long before `a` itself rounds to 0. Both families give the same thresholds.
- New helper `gll_log1mexp_neg_exp(log_a)` = `log(1 - exp(-a))` from `log a`. Below `log a = -20` it uses the series `log a - a / 2 + a^2 / 24` (truncation below 1e-37); above it, the old `logspace_sub(0, -a)`. Each branch gets its own clamped input (`log a <= -20` for the series, `[-20, 700]` for `logspace_sub`), so the branch that is not selected stays finite. That is the convention in the #1479 helper block.
- New helper `gll_nbinom_log_neg_log_p0(log_mu, log_size)` = `log(-log P(0))` for NB2. It uses the same `log1p(x) / x` ratio as `gll_nbinom_log_p0` but never multiplies by `exp(log_mu)`.
- fid 10 is now `y eta - exp(eta) - lgamma(y + 1) - gll_log1mexp_neg_exp(eta)`. `dpois(y, exp(eta))` formed `y log(exp(eta))`, which is `-Inf` once `exp(eta)` is 0.
- fid 11 is now `gll_dnbinom_mu_size(...) - gll_log1mexp_neg_exp(gll_nbinom_log_neg_log_p0(...))`.
- After the fix nothing is non-finite down to `eta = -1000` (Laplace `fn`/`gr`, kernel `fn`/`gr`/`he`, step 1).

## 3. Files Changed

- `src/gllvmTMB.cpp`: two helpers after `gll_nbinom_log_p0`; the fid 10 and fid 11 rows.
- `tests/testthat/test-cpp-numeric-edges.R`: header line for #1483; one new test.
- `NEWS.md`: one bullet.
- `docs/dev-log/after-task/2026-10-19-zt-count-underflow-1483.md`: this report.

## 3a. Decisions and Rejected Alternatives

- **Keep `logspace_sub` above the cut; do not reuse `gll_log_cloglog_p()`.** That function computes the same quantity, but its middle branch is `log(1 - exp(-lambda))` with no `expm1`, which is wrong by up to ~5e-8 near `eta = -20`. Swapping it in would have made ordinary ZT fits less accurate. Confidence: high (arithmetic on the double spacing near 1).
- **Cut at -20, not near -700.** A cut close to the underflow line would keep more of the old path, but the unselected `logspace_sub` branch would then be evaluated at `a ~ 1e-304`, where its second and third derivatives (`1 / a^2`, `1 / a^3`) overflow. That is exactly the Laplace failure being fixed. At -20 every derivative order used is finite. Confidence: high (measured: gradient and Hessian match the analytic forms to 1.4e-14 on both sides of the cut).
- **Upper evaluation cap at `log a = 700`.** Follows the #1479 helper rule that nothing is `exp()`'d past ~exp(700). For fid 10 the `- exp(eta)` term is still `-Inf` above `eta = 709.8`, as before; that is unchanged here.
- **`poisson()` and `zi_poisson()` not touched.** Same `dpois(y, exp(eta))` form, measured non-finite from `eta = -709` (section 10). That is a separate issue with no truncation term, so it is outside #1483.

## 4. Checks Run

- Build: `pkgbuild::compile_dll()` on `main` @ `3203f6b3` and on the branch (R 4.6.0, macOS arm64, TMBad). A separate `git worktree` of `main` was built for the comparisons.
- New test against `main` (final test file copied into the `main` worktree): 58 of its 92 expectations fail, in both families. The Laplace gradient is non-finite at every `eta` from -300 down (14), the Laplace objective from -400 down (12 finiteness + 12 value), the closed-form gradient at the four underflow points (8), and on the kernel tape `fn` at -800 (2), `gr` at -720 and -800 (4) and `he` at -400, -720 and -800 (6). The other nine tests in the file pass on `main`. Against the branch the whole file passes; the two #1386 tests skip under `skip_on_cran()` when `NOT_CRAN` is unset.
- Ordinary fits, `main` vs branch, ZT-Poisson and ZT-NB2 with a real `d = 1` latent factor (80 units x 4 traits):
  - joint negative log-likelihood (`obj$env$f`, no Laplace) at an identical full parameter vector: difference 0 for both families; gradient difference at most 2.8e-14 over 412 / 416 coordinates.
  - fitted objective: difference 5e-12 (Poisson) and 1.5e-11 (NB2); both converge (code 0).
  - Laplace `fn` at a fixed off-optimum point differs by 5.4e-9 for NB2. The joint objective is identical, so this comes from the inner Newton solve starting from a different `u` after a different outer path, not from the kernel.
- Kernel gradient and Hessian vs the analytic ZT-Poisson derivatives at 13 points from `eta = -2` to -900, including `-20 +/- 1e-7`: worst absolute errors 1.4e-14 (gradient) and 7.9e-15 (Hessian).
- `devtools::document()`: no `.Rd` change. It rewrites `S3method(stats::sigma, ...)` in `NAMESPACE`, which is pre-existing drift from #1407's hand edit (also recorded by #1538 and #1599). Not committed.
- Full suite, `devtools::test()` on the branch with the routine gate (heavy tests off, `OPENBLAS_NUM_THREADS=1`): 692 files, 4,401 tests, 30,844 expectations in 149.7 min. 29,873 passed, 887 tests skipped, and 22 expectations failed in 15 tests (3 of them errors). The new #1483 test passed 92 of 92.
- All 15 also fail on a clean `main` @ `3203f6b3` build (the 12 files re-run there with `devtools::test(filter = ...)`). Fourteen fail identically on every run: `test-aghq-multistart-convergence.R` (#843), `test-control-field-surface.R`, `test-interval-calibration-ci09.R`, `test-interval-calibration-claims.R` (2 tests), `test-isdm-diagnostic-contract.R` and `test-isdm-diagnostic-receipts.R` (`source()` cannot open a file), `test-loading-unpack-contract.R`, `test-plot-visual-snapshots.R` (3 snapshots), `test-reader-facing-no-register-codes.R`, `test-restart-selection-1335.R`, and `test-va-r3-prototype.R` (truncated-NB2 seed 12, `healthy_starts` 3 not 4; this runs on the separate VA template, which this branch does not change). That is the list #1538 recorded on `main` @ `a6ccd827`, plus the two iSDM `source()` errors.
- The fifteenth, `test-paper1-spde-slope-gauge-trust-region-materializer.R` ("the parent supervisor records a clean isolated child exit"), gives a bare `Rscript --vanilla -e "cat('child-ok')"` child a 2-second deadline and never reaches the engine. Under `devtools::test()` it timed out on the branch twice (full suite, one isolated run) and passed twice; on `main` it passed twice and timed out once. Called directly, the launcher finished in 0.38 to 0.58 s from both checkouts (12 runs). Load average was about 70 on 20 cores throughout.
- After the full suite, on the final binary: the 10 test files that touch these families or this source (`cpp-numeric-edges`, `exact-rq-residuals-families`, `link-residual-15-family-fixture`, `matrix-truncated`, `mspl-truncated-phase4-oracles`, `simulate-families`, `structured-rho-family-oracle`, `tmb-ad-safe-clamps`, `truncated-recovery`, `zz-mspl-fenced-family-tapes`) gave 93 tests, 6,150 expectations, 0 failures, 0 errors, 13 skips.
- `tools/recertify-c17.py` and `tools/capability_ledger.py` do not exist in this repository, so there was no C17 or ledger step. No Julia package lives here, so no `Pkg.test()`.

## 5. Tests of the Tests

The new test fails on `main` at every regime it covers. The ordinary cells (`eta = -5, -30`) pass on both builds, so the R reference is right where the old kernel was right. The `eta` grid has one point in each failure regime from the table in section 2 (-300: gradient only; -400 and -700: objective too; -745.2 and below: `mu` is exactly 0). At the underflow points the gradient is checked against the closed form `-sum(y - 1)` per trait. The kernel-only tape (random effects at 0, only `b_fix` free) checks `he()` directly, because a non-finite unselected `CondExp` branch shows up only in the Hessian (the failure mode recorded in `gll_log1mexp()`).

## 6. Consistency Audit

- `grep -rn "logspace_sub" src inst/tmb`: one call left, `src/gllvmTMB.cpp:363`, the new helper's guarded branch (the other hits are its comment and the binaries). None in `inst/tmb`.
- `grep -nE "fid == 1[01]\b|== 10\b|== 11\b|truncnb2" src/gllvmTMB.cpp`: fid 10 and 11 are evaluated only in the row loop changed here; the other hits are the parameter declaration and `REPORT(phi_truncnb2)`.
- `grep -n "dpois(" src/gllvmTMB.cpp`: still used by fid 2 (`poisson`, line 3594), fid 17 (`zi_poisson`, `y > 0`, line 3874) and fid 21 (`censored_poisson`, uncensored rows, line 3928). See section 10.
- `grep -n "tiny_u = Type(1e-300)" inst/tmb/gllvmTMB_va_r3.cpp`: the VA template's fam 10 / 11 already write the Poisson part on the `eta` scale, but `va_r3_log1mexp()` floors `u` at 1e-300, so its truncation term is approximate (finite) below `eta ~ -690`. Read, not run. Not changed.
- Open PRs touching `src/gllvmTMB.cpp`: #1506 (tweedie power clamp, other lines). No open PR or remote branch changes the ZT rows (all `origin/*` refs scanned for `logspace_sub`, `fid == 10/11` and `truncnb2` hunks; the only hit is #1479's merged branch).

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

- **#1483**: fixed by this branch (fid 10 and 11, all regimes above). No PR opened (finish-first rule for this lane).
- No new issue filed. Suggested follow-up issue, text below in section 10.

## 8. What Did Not Go Smoothly

- The issue put the threshold at `eta < -745`, the point where the value itself breaks. The Laplace fit fails much earlier (-237) through derivative overflow; that only came out by scanning `fn` and `gr` separately. The test grid was widened after the scan.
- The first full-suite launch used the tool's background mode, which caps at 2 hours; it was stopped within a minute and relaunched under `nohup`.
- The suite took 149.7 min against an estimate of 1.5 to 2 h, because other lanes kept the Mac's load average near 70. It was left to finish rather than restarted.
- I edited a comment in `src/gllvmTMB.cpp` (the ZT-NB2 row no longer calls `gll_nbinom_log_p0` directly) 13 minutes into the suite. A test inside the suite rebuilt the DLL in place 9 minutes later, so the suite's last part ran on the rebuilt binary. The edit is comment-only; the affected test files were re-run on the final binary afterwards (section 4).

## 9. Team Learning

Rose: a log-scale helper that is exact in value can still break the fit through its derivatives. When a kernel can see `a -> 0`, scan `gr()` (and `he()` on a kernel tape) along the whole tail, not just `fn()`. Here the Laplace gradient failed 500 units of `eta` before the value did.

## 10. Known Limitations And Next Actions

- `poisson()` (fid 2) and `zi_poisson()` (fid 17, `y > 0` rows) use `dpois(y, exp(eta))`. Measured on this branch: Laplace `fn` and `gr` non-finite from `eta = -709`. `nbinom2()` and `zi_nbinom2()` are finite to -800. `censored_poisson()` (fid 21) has the same `dpois` form on uncensored rows and `log(pgamma(mu, C))` on censored rows, which is `log(0)` once `mu` is 0 (read, not run). Suggested issue: "Poisson, zi_poisson, censored_poisson: dpois(y, exp(eta)) is non-finite below eta ~ -709; write y * eta - exp(eta) - lgamma(y + 1)".
- R-side `truncated_poisson()$linkinv` and `truncated_nbinom2()$linkinv` return `mu / (-expm1(log P(0)))`, which is `0 / 0 = NaN` once `exp(eta)` is 0 (the limit is 1). Read, not run.
- The VA template's truncation term is approximate below `eta ~ -690` (section 6).
- Every such regime is far from any optimum for `y >= 1` data. The practical exposure is a bad start or a line-search step, not a converged fit.
