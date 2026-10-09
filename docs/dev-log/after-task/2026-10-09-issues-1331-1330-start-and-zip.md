# After Task: default start (#1331) and zero-inflated convergence (#1330)

**Branch**: `claude/fix-1331-1330`
**Date**: `2026-10-09`
**Roles (engaged)**: Claude Code (implementation and evidence)

## 1. Goal

Find and fix the root causes of two Wave 1 campaign findings:

- #1331: the default single start sometimes stops at a lower local optimum
  while reporting `convergence = 0`, a positive-definite Hessian and a small
  gradient.
- #1330: `zi_poisson()` latent fits fail to converge in 38% (zi = 0.2) and
  18% (zi = 0.5) of datasets simulated from the fitted model.

## 2. Implemented

**#1331: an extra data-informed start.**

- *Root cause.* The default start pairs SVD-seeded latent scores with a
  fixed loading pattern (0.5 on the diagonal, 0 elsewhere). The scores carry
  the residual correlation directions, but the loadings do not.
- *New start.* `.gllvmTMB_svd_latent_start()` builds loadings and scores from
  one rank-`d` SVD of the unit × trait residual matrix. It rotates them to the
  packed lower-triangular layout with a positive diagonal.
- *How the fit uses it.* `gllvmTMB()` now runs it as restart 2 (label `"svd"`)
  after the default start. The jittered `n_init` restarts follow it. The svd
  start replaces the default fit only if both hold:
  - it lowers the objective by more than `1e-6 * max(1, |obj|)`;
  - it does not swap a converged fit for a non-converged one.
- *Opt-out.* `gllvmTMBcontrol(svd_start = FALSE)` restores the single start.
- *When it is skipped:* `start_from`, `start_method`, MSPL, a mapped
  `theta_rr_B`, and `lv =` predictors.

**#1330: start values and diagnosis.**

- *Start-value bug.* `zi_poisson` (fid 17), `zi_nbinom2` (18) and
  `censored_poisson` (21) were missing from the log-link set of the
  intercept start. Their intercepts therefore started from OLS on raw counts
  (4.5 for a mean count near 5, i.e. mu ≈ 90). They now start from
  `log(y + 0.5)`. `zi_binomial` (19) now takes the empirical-logit start.
- *Measured root cause of the remaining failures.* The zero-inflated
  likelihood is not log-concave in eta: for y = 0 its curvature is negative
  once mu is moderate. A unit's conditional curvature (prior plus data) can
  therefore cancel to zero along one latent direction. The Laplace objective
  contains `+0.5 log det` of that curvature, so it falls without bound as
  the optimiser tunes the loadings toward the cancellation.
- *Evidence for that cause:*
  - All 20 remaining failures stop with a unit-block eigenvalue between
    3e-8 and 8e-4. Healthy fits sit at 0.4 to 0.8.
  - Near the stopping point, `fn(p ± 1e-6)` moves by about 1.3 units, so
    the objective is a spike, not an optimum.
  - Barriers at curvature 1e-3, 1e-2 and 0.1 each moved the stop onto the
    barrier, at `0.5 log(10)` per decade. No interior optimum exists.
  - A Poisson warm start lands on the same attractor.
  - This is a failure of the Laplace approximation, not of starts or
    parameterisation.
- *New diagnostic.* `.gllvmTMB_min_random_curvature()` computes the smallest
  eigenvalue of the inner Hessian, block by block over its connected
  components. It is stored as `fit_health$min_random_curvature` for
  zero-inflated fits.
  - The zero-inflated warning now names this cause when the curvature is
    below `1e-3`, and no longer suggests more random starts in that case.
  - `check_gllvmTMB()` gains a `laplace_curvature` row (PASS/FAIL).

## 3. Files Changed

- `R/init-warmstart.R`: `.gllvmTMB_svd_latent_start()`.
- `R/fit-multi.R`:
  - log-link and zi_binomial start sets;
  - svd start computation and restart loop (labels, tie tolerance,
    converged guard);
  - `.gllvmTMB_min_random_curvature()`;
  - zero-inflated warning;
  - curvature recorded in `fit_health`.
- `R/gllvmTMB.R`, `man/gllvmTMBcontrol.Rd`: `svd_start` argument,
  validation, docs, `n_init` doc.
- `R/diagnose.R`: `laplace_curvature` check row.
- `tests/testthat/test-svd-start-1331.R` (new),
  `tests/testthat/test-zi-start-curvature-1330.R` (new).
- `tests/testthat/test-restart-selection-1335.R`,
  `tests/testthat/test-stage39-multi-start.R`: restart-count expectations
  (see 3a).
- `NEWS.md`.

## 3a. Decisions and Rejected Alternatives

- **Default behaviour change (svd start on by default).**
  - *Rationale:* it is deterministic and uses no RNG, so seeded `n_init`
    jitters are unchanged. Restart 1 is still the old start, and ties keep
    the old fit exactly; the #1335 parity pin's objective is unchanged.
  - *Cost:* one extra optimisation per latent fit.
  - *Rejected:* default `n_init > 1`. It costs 3-10× on every fit, is
    RNG-dependent, and on the Poisson cells best-of-3 still missed 1 of 2.
- **The svd start does not fix the negative binomial cells, and the PR says
  so.**
  - On NB2 n = 150, phi = 0.5, default+svd still missed 8 of 50 (the default
    alone also missed 8); `n_init = 10` missed 0.
  - On NB2 n = 60, default+svd missed 19 of 50 against 27 for the default.
  - The NB2 local optima differ in which traits' dispersion sits on the
    Poisson plateau (phi → ∞). Resetting plateau traits' `log_phi` and
    re-optimising was tried and did not help (8 → 8 misses).
- **Rejected for #1330:**
  - Returning NaN or a barrier at small curvature: it moves the stop to the
    barrier.
  - Flooring the log-determinant: that changes the likelihood
    approximation.
  - AGHQ for zero-inflated rows: an integration change that needs maintainer
    sign-off.
  - Any of these would be a likelihood/integration change (high-risk per
    CLAUDE.md), so only start values and diagnosis changed.
- **Restart-count tests updated.**
  - `#1335 parity pin`: objective unchanged; restart labels are now
    `initial`, `svd`, with `initial` selected.
  - `#1333`: pinned to `svd_start = FALSE`, because the mock fails every
    nlminb call.
  - `stage39`: `n_init = 3` now records four restarts.

## 4. Checks Run

Environment: R 4.3.3 and TMB 1.9.10 from Ubuntu apt, because CRAN mirrors are
blocked by the session's network policy; fmesher and splancs were built from
GitHub sources. The campaign ran R 4.6.1 and TMB 1.9.25, so some cells differ:
for example, NB2 n = 60 fits report code 1 here at the dispersion boundary.

Campaign data were regenerated with the `gen_sim.R` posted on #1330, with
seed `20260927 + 1000 * cell + rep`.

**#1331 Poisson exemplars, default fit:**

| rep | before | after | `n_init = 10` / Julia |
|---|---|---|---|
| 29 | −359.5170 | −359.1976 | −359.1976 |
| 13 | −375.4208 | −375.2864 | −375.2864 |

**#1331 misses (more than 0.01 below the best known logLik):**

| cell | default | default + svd | `n_init = 10` |
|---|---|---|---|
| Poisson n = 24 | 2 | 0 | 0 |
| Poisson n = 60 | 1 | 0 | 0 |
| NB2 n = 60 | 27 | 19 | 3 |
| NB2 n = 150 | 8 | 8 | 0 |

**#1330 ZIP, 50 reps per cell, converged = code 0 and pdHess:**

| true zi | before | after |
|---|---|---|
| 0.2 | 31/50 | 33/50 |
| 0.5 | 41/50 | 47/50 |

- No fit that converged before fails after.
- All 20 remaining failures carry curvature below 1e-3, so they now warn
  with the cause.

**mvabund spider data (#1330 comment):**

- Intercept-only `zi_poisson` gave logLik −1.5e10 before. It now gives
  −838.52, which respects the Poisson bound of −845.69. It still reports
  code 1.
- With two covariates, the fit used to abort with "Could not evaluate";
  it now converges (code 0, −732.83).

**Tests:**

- New files: `test-svd-start-1331.R` (20 expectations) and
  `test-zi-start-curvature-1330.R` (14 expectations); all pass.
- Targeted files pass:
  - `test-restart-selection-1335.R`, `test-stage39-multi-start.R`;
  - `test-zi-families.R`, `test-zi-recovery.R`, `test-censored-poisson.R`;
  - `test-multi-start-sdreport-consistency.R`, `test-warm-nlminb-restart.R`;
  - `test-gllvmTMBcontrol.R`, `test-sanity-multi.R`,
    `test-start-method-residual.R`.
- Full suite: all 678 test files ran with `NOT_CRAN=true` against
  `pkgload::load_all()`, as one sequential pass plus four shards.
  - Totals: 28,472 expectations passed, 51 failed and 27 errored.
  - All 23 files with failures or errors were re-run on `origin/main`
    (`9354ac2`) in the same environment and fail identically there.
    The causes are environmental:
    - glmmTMB/TMB version mismatches with the apt builds;
    - missing optional packages and fixtures;
    - vdiffr snapshots;
    - an undeclared `optimizer_diagnostics` control field.
  - No failure is introduced by this branch.

## 5. Tests of the Tests

Run against the unpatched installed package:

- The zi start test fails: the intercept start equals the raw-count means.
- The curvature tests fail: no field, no helper.
- `test-svd-start-1331.R` pins both the old optimum (`svd_start = FALSE`,
  −359.5170) and the new one (−359.1976). It therefore fails if the svd
  start stops finding the higher optimum.

## 6. Consistency Audit

- `rg "start_label = if \(i == 1L\)" R/`: no remaining uses; labels come
  from `start_labels`.
- `tmb_map$theta_rr_B` partial-matches `theta_rr_B_slope` under `$`. The
  new gate therefore uses `tmb_map[["theta_rr_B"]]`. Line 6616 and other
  existing reads of that field were left unchanged.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

- #1331: fixed for the Poisson local optima. The NB2 local optima are
  documented as still needing `n_init`.
- #1330: start-value bug fixed. The remaining failures are diagnosed as a
  Laplace degeneracy, and they now warn and fail a check row. A real fix
  needs a non-Laplace integration for zero-inflated rows; that is a
  maintainer decision.
- No issue text edited.

## 8. What Did Not Go Smoothly

- CRAN access was blocked, so the dependency stack came from apt with older
  R/TMB versions than the campaign used.
- The first svd-start campaign made ZIP convergence worse. The svd restart
  reached the degenerate Laplace spike at a lower objective and was selected
  over a converged default fit. The converged guard fixed this.

## 9. Team Learning

A lower objective is not a better fit when the objective is an approximation
that can diverge. Restart selection should not prefer a non-converged restart
over a converged one on objective alone. This PR applies that rule only to
the new svd restart; whether jittered restarts should follow it is for the
maintainer.
