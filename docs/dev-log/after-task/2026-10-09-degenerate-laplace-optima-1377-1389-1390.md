# After Task: Degenerate converged optima (#1377, #1389, #1390)

**Branch**: `claude/fix-1389-1390-1377`
**Date**: `2026-10-09`
**Roles (engaged)**: Claude Code (diagnosis, implementation, checks)

## 1. Goal

Three converged fits from the 3 Oct 2026 real-data sweep returned a logLik that
was far above the true marginal likelihood, and `check_gllvmTMB()` did not
report it. Each fit (or the check) must now prevent or report its degenerate
optimum, and the root cause of each must be explained.

## 2. Implemented

- **#1377 (Gamma, root cause = floating-point cancellation).** TMB's
  `dgamma(y, k, mu / k, log = TRUE)` forms `k log k`, `k log y`, `k y / mu`
  and `lgamma(k)` separately. At `log_phi_gamma` 41-68 (shape 1e18-1e29)
  those terms are about 1e30. Their rounding error (about 1e15) is larger
  than the true value, so the density came out as +1e16 instead of going to
  -Inf. `n_init` then picked that start because its objective was the
  lowest. New `gll_dgamma_mean_shape()` in `src/gllvmTMB.cpp` computes the
  algebraically identical
  `-k (r - 1 - log r) - log y + (k log k - k - lgamma k)`.
  It uses a series for `r - 1 - log r` near `r = 1` and Stirling's series for
  the last bracket when `k > 50`. It replaces both Gamma call sites: fid 4,
  and the fid 13 `delta_gamma` positive part. USairpollution, `n_init = 10`:
  seeds 20261003/5/10/14/17/18 all now return -1297.334874 (native Julia:
  -1297.3350), with conv 0. A Gamma shape >= 1e8 is now the
  `boundary_phi_gamma` boundary flag and a per-trait
  `boundary_phi_gamma_<trait>` row. On USairpollution the `manu` trait sits
  there (shape 2.8e8): it is a genuine Gamma Heywood case at the true
  optimum, which the old code did not report.
- **#1390 (ordinal Psi, root cause = non-identified scale + Laplace).** With
  one observation per (trait, unit), `P(y = k)` depends on
  `(tau_k - eta) / sqrt(1 + psi)` only. The marginal likelihood is therefore
  flat along psi, the cutpoints and the loading. Laplace is not invariant
  along that ridge and drifts up it. The per-trait identifiability gate that
  already mapped off the default `latent()` Psi for single-trial binary now
  also covers `ordinal_probit` / `ordinal_logit` traits whose cells hold one
  observation. Traits with replicated cells keep their Psi. On sat.act,
  `unique = TRUE` now gives -4140.307, and the issue's exact integral agrees
  to 1e-4. It was -3825.5, which was 521 too high.
- **#1389 (Laplace optimism, root cause = the approximation itself).** No
  fit-side statistic can see this. A second, independent codebase
  (GLLVModels.jl) reaches the same optimum, so the error is in the Laplace
  objective, not the optimiser. A new `check_gllvmTMB()` row,
  `laplace_accuracy`, re-evaluates the marginal logLik at the fitted
  parameters. It uses the AGHQ engine's adapted tensor Gauss-Hermite tape
  (adaptation from the fitted Laplace object; a double-only evaluation with
  no taping or refit; k = 15 / 9 / 5 nodes per axis for d = 1 / 2 / 3). It
  warns when Laplace is above that value by more than
  `laplace_accuracy_thresh = 2`. On ability, probit d=2: quadrature
  -12510.97 against the issue's -12510.80, optimism +67.5, WARN. Logit d=2:
  -12455.26 against -12455.25, PASS. The check takes about 2 s on 23k rows.

## 3. Files Changed

- `src/gllvmTMB.cpp`: `gll_dgamma_mean_shape()`; fid 4 and fid 13 call sites.
- `R/fit-multi.R`: ordinal arm of the B-tier auto-Psi gate; message text.
- `R/diagnose.R`: `boundary_phi_gamma` flag, `.gllvmTMB_gamma_shapes()`,
  `boundary_phi_gamma_<trait>` and `laplace_accuracy` rows, three new
  `check_gllvmTMB()` arguments.
- `R/laplace-accuracy.R` (new): `.gllvmTMB_laplace_accuracy()`.
- `man/check_gllvmTMB.Rd`: new arguments, edited by hand (no roxygen run, to
  avoid churn from a roxygen2 version mismatch).
- `tests/testthat/test-degenerate-laplace-optima.R` (new).
- `NEWS.md`, `docs/design/35-validation-debt-register.md` (DIA-08, FAM-14).

## 3a. Decisions and Rejected Alternatives

- Fix the Gamma density rather than clamp `log_phi_gamma`. A clamp would hide
  the cancellation at the clamp value and bias genuine boundary fits; the
  stable form makes the objective correct everywhere.
- Gate ordinal Psi only for single-observation cells, not for every ordinal
  trait. Replication identifies psi.
- Rejected for #1389: lowering `loading_relative_thresh` (7.71 < 8). That would
  tune a proxy to one dataset; the quadrature measures the actual error.
- `laplace_accuracy_thresh = 2` is a judgement (an AIC-scale error), not
  calibrated against a fit pool. Only optimism warns, because a Laplace that
  is too pessimistic does not make a fit look better than it is.

## 4. Checks Run

- New test file: `[ FAIL 0 | PASS 32 ]`.
- Issue reproductions: see section 2 (scripts were run from a scratch directory).
- `Rscript dev/gapclose/build-capability-status.R --check`: up to date.
- `devtools::test()` (full suite): see the PR body for the final counts. Every
  failing file also fails on the pre-fix build in this environment (R 4.3.3,
  Ubuntu apt TMB 1.9.10 / glmmTMB, CRAN unreachable).

## 5. Tests of the Tests

Run against a pre-fix build (`HEAD` before this branch, installed to a
separate library): the Gamma-density test fails, the ordinal-gate test fails
twice, the replicated-ordinal test passes (as intended: it guards the scope
of the gate), and the four `laplace_accuracy` tests error, because the
function does not exist there.

## 6. Consistency Audit

`rg "dgamma\(" src/` returns only the comment in the new helper. Both Gamma
call sites are converted.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

#1377, #1389, #1390: addressed by this PR (not closed by the agent).

## 8. Follow-up

- `laplace_accuracy` covers z_B-only fits with d <= 3. Fits that keep a free
  Psi or other random blocks are not audited. One example is an explicit
  `indep()` on a single-observation ordinal trait, which the gate leaves
  alone because it is a deliberate model choice.
- Calibrate `laplace_accuracy_thresh` on a fit pool; decide whether a WARN
  should also be emitted at fit time.
