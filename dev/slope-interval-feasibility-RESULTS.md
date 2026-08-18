# Are confidence intervals on random-SLOPE variance parameters mechanically reachable today?

**Date:** 2026-08-18
**Branch/worktree:** `claude/rand-slope-surface-20260818`, `/private/tmp/gllvmtmb-randslope`
**Script:** `dev/slope-interval-feasibility.R` (log: `dev/slope-interval-feasibility-OUTPUT.log`, from the final clean run)

## The question

Random slopes enter gllvmTMB via TMB `PARAMETER_VECTOR`/`PARAMETER_MATRIX` blocks — i.e.
FIXED effects from TMB's point of view. `TMB::sdreport()` returns `par.fixed`/`cov.fixed`
for every fixed parameter **without needing `ADREPORT`**. The exported ADREPORT list in
`src/gllvmTMB.cpp` contains no slope-SD entry, which is why the capability board's INTERVAL
column reads "POINT" for random slopes. This probe asks: is a Wald/delta-method interval on a
random-slope variance parameter **mechanically computable** from what a fit already returns —
not whether such an interval would be well-calibrated.

**Two distinct engine routes both produce "random slopes" but engage different parameter
blocks**, discovered empirically (the first attempt's assumption was wrong):

- **Route A** — `phylo_indep(1 + x | species, tree = tree)`. Desugars to `phylo_slope()`'s
  block-diagonal-per-trait Cholesky engine. The slope variance lives in **`theta_dep_chol`**,
  NOT in `theta_diag_B_slope` / `theta_rr_B_slope` as originally hypothesised. Confirmed by
  reading `tests/testthat/test-phylo-indep-slope-gaussian.R`'s own header comment and by
  inspecting `sd_report$par.fixed`'s block-name table directly (no `theta_*_B_slope` entries
  appear for this route).
- **Route B** — ordinary (non-source-specific) `latent(0 + trait + (0 + trait):x | unit, d = K)`.
  This is the route that engages **`theta_diag_B_slope`** (the augmented diagonal Psi companion,
  on by default for Gaussian) and **`theta_rr_B_slope`** (the augmented reduced-rank loadings),
  per `R/fit-multi.R` ~1220-1260 (`rr_is_latent_augmented` / `diag_is_unique_augmented`, grouped
  by the `unit` tier). Formula/fixture shape copied from
  `tests/testthat/test-ordinary-latent-random-regression.R`.

## Fit specifications (final, clean runs)

**Route A:**
```r
value ~ 0 + trait + phylo_indep(1 + x | species, tree = tree_A)
family = gaussian(); control = gllvmTMBcontrol(se = TRUE)
```
`n_sp = 60`, `n_traits = 3`, `n_rep = 6`, `n_obs = 1080`. DGP: 3 independent per-trait
(intercept, slope) phylogenetic blocks (`ape::rcoal(60)`), true `s2_int = c(.4,.6,.3)`,
`s2_slope = c(.3,.5,.2)`, residual SD 0.3 — same shape as
`tests/testthat/test-phylo-indep-slope-gaussian.R`'s fixture.

**Route B:**
```r
value ~ 0 + trait + (0 + trait):temperature +
  latent(0 + trait + (0 + trait):temperature | individual, d = 2)
family = gaussian() (default); control = gllvmTMBcontrol(se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS"))
```
`n_ind = 50`, `n_traits = 3`, `n_rep = 6`, `n_obs = 900`. DGP: `Lambda_aug %*% z_i` (rank-2
loadings, copied from the test file) **plus explicit idiosyncratic Psi noise**
(`psi_sd = 0.2` on every one of the 6 augmented (intercept, slope) x trait coordinates) added
on top of the loadings term.

**First-attempt failure, corrected (see "What changed between attempts" below):** the first
Route A fit (`n_sp=25, n_rep=4`) had `opt$convergence = 1`, `pdHess = FALSE`. The first Route B
fit (`n_ind=30`, no explicit Psi noise in the DGP) had `pdHess = FALSE`, one `NaN` SE, and
several SEs of magnitude 10^1–10^4 alongside `theta_diag_B_slope` estimates near `-7` to `-20`
(i.e. `exp(theta) ~ 1e-3` to `1e-9`) — a boundary/Heywood collapse. Both are reported below as
part of the evidence, not discarded.

## Findings — computability (structural)

`object$sd_report` is non-NULL on every fit attempted (converged or not), `class = "sdreport"`.
The slope blocks appear in `names(fit$sd_report$par.fixed)` for both routes, matching
`names(fit$opt$par)` (the same lookup pattern already used in
`R/profile-derived.R:1317-1318` for `theta_rr_B_slope`/`theta_diag_B_slope`, confirming that
precedent):

```
Route A par.fixed block table:  b_fix(3)  log_sigma_eps(1)  theta_dep_chol(9)
Route B par.fixed block table:  b_fix(6)  log_sigma_eps(1)  theta_diag_B_slope(6)  theta_rr_B_slope(11)
```

So the **structural** answer is yes for both routes: the slope-variance parameters are
ordinary TMB fixed effects, present in `par.fixed`, with a `cov.fixed` diagonal available —
this holds regardless of whether a given fit's Hessian is PD.

## Findings — demonstrated on a healthy fit (numbers)

Both final runs: `opt$convergence == 0`, `fit$sd_report$pdHess == TRUE`, all reported SEs
finite and positive.

**Route A — `theta_dep_chol`, slope sub-entries** (index 2 of each trait's 3-entry
(int-diag, slope-diag, off-diag) block, log-SD scale):

| trait | theta_hat | se(theta_hat) | sd_hat = exp(theta_hat) | true slope SD | ratio |
|---|---|---|---|---|---|
| 1 | -0.410418 | 0.151135 | 0.6634 | 0.5477 | 1.21 |
| 2 | -0.452731 | 0.159720 | 0.6360 | 0.7071 | 0.90 |
| 3 | -0.001243 | 0.121124 | 0.9988 | 0.4472 | 2.23 |

Worked example (trait 1, 95% CI):
```
theta_hat = -0.410418, se(theta_hat) = 0.151135
sd_hat = exp(theta_hat) = 0.663373
delta-method se(sd_hat) = sd_hat * se(theta_hat) = 0.100259
95% CI (delta method, symmetric on SD scale)   = [0.466869, 0.859877]
95% CI (exponentiated link-scale Wald, >0 guaranteed) = [0.493300, 0.892081]
```

**Route B — `theta_diag_B_slope`** (log-SD scale, true value 0.2 on all 6 entries by
construction):

| entry | theta_hat | se(theta_hat) | sd_hat = exp(theta_hat) | true | ratio |
|---|---|---|---|---|---|
| 1 | -1.993085 | 0.475181 | 0.1363 | 0.2 | 0.68 |
| 2 | -1.549038 | 0.325480 | 0.2125 | 0.2 | 1.06 |
| 3 | -1.729032 | 0.229196 | 0.1775 | 0.2 | 0.89 |
| 4 | -1.416405 | 0.175992 | 0.2425 | 0.2 | 1.21 |
| 5 | -1.581826 | 0.208864 | 0.2057 | 0.2 | 1.03 |
| 6 | -1.602128 | 0.430420 | 0.2015 | 0.2 | 1.01 |

Worked example (entry 1, 95% CI):
```
theta_hat = -1.993085, se(theta_hat) = 0.475181
sd_hat = exp(theta_hat) = 0.136274
delta-method se(sd_hat) = 0.064755
95% CI (delta method, symmetric on SD scale)   = [0.009357, 0.263192]
95% CI (exponentiated link-scale Wald, >0 guaranteed) = [0.053696, 0.345851]
```

**Route B — `theta_rr_B_slope`** (loadings block; reported for completeness, NOT
back-transformable per-element — see below): all 11 entries had finite, positive SEs in the
0.04–0.08 range at this N; estimates ranged -0.39 to 0.50.

**Sanity signal (not a recovery claim):** Route B's `theta_diag_B_slope` recovers the true
`psi_sd = 0.2` closely on a single seed (ratios 0.68–1.21 across 6 entries). Route A's slope SDs
recover reasonably for traits 1–2 (ratios 1.21, 0.90) but trait 3 is off by >2x (ratio 2.23) on
this single seed — expected single-seed noise, not evidence of a systematic bias (no averaging
was done).

## Delta-method back-transform requirement

Both `theta_dep_chol` (Route A slope sub-entries) and `theta_diag_B_slope` (Route B) are
**univariate log-SDs**: a natural-scale interval requires
`sd_hat = exp(theta_hat)`, `se(sd_hat) = exp(theta_hat) * se(theta_hat)` (delta method,
`d/dtheta exp(theta) = exp(theta)`), giving either a symmetric-on-SD-scale Wald interval
`sd_hat ± z*se(sd_hat)` or the exponentiated link-scale interval
`exp(theta_hat ± z*se(theta_hat))` (strictly positive, generally preferable near the boundary).

`theta_rr_B_slope` (Route B loadings, when the fit uses the reduced-rank route) has **no**
simple per-element back-transform: `Sigma_B_slope = Lambda_B_slope %*% t(Lambda_B_slope)` is a
nonlinear function of *multiple* `theta_rr_B_slope` entries at once. A CI on a derived quantity
(e.g. a per-trait slope SD from the loadings alone, or any entry of `Sigma_B_slope`) needs the
full relevant `cov.fixed` sub-block propagated through that quadratic form — a multivariate
delta method / numerical Jacobian (e.g. `numDeriv::jacobian()`), not `exp()` per element.

## Existing extractor check

`grep -rln 'theta_diag_B_slope\|theta_rr_B_slope' R/` → `R/profile-derived.R`, `R/fit-multi.R`
only.

- `R/profile-derived.R:1317-1318` indexes both names via `par_names <- names(fit$opt$par)`, but
  only inside the `rho:unit_slope` **correlation** profile path (`confint_inspect`-style
  profile likelihood), which is explicitly gated
  `"{.code rho:unit_slope} profile intervals are currently a Gaussian-only canary"` and aborts
  for any non-Gaussian family. It does not surface a variance/SD interval for the slope blocks.
- `R/fit-multi.R` only *constructs* these parameter blocks (data/parameter setup); no
  SE-surfacing there.
- `R/profile-targets.R` — `grep -n 'B_slope'` → **no match**. The `profile_targets()` inventory
  (the function `confint_inspect()` consults) does not list any `B_slope` target at all.
- `R/confint-inspect.R` documents a general Wald path via `fit$sd_report$cov.fixed` (delta
  method) for whatever `profile_targets()` lists, but since `B_slope` is absent from that
  inventory, this general machinery does not currently reach the slope blocks either.

**Conclusion: no existing exported function surfaces a slope-variance interval.** The
plumbing (`sd_report$par.fixed` / `cov.fixed`) is there; the R-level extractor is not built.

## VERDICT

**Reachable (computability only) — for both routes, on a healthy fit.** `object$sd_report` is
populated by default (`se = TRUE` is the `gllvmTMB()` default), the slope-variance parameters
(`theta_dep_chol`'s slope sub-entries for Route A; `theta_diag_B_slope` for Route B) appear by
name in `par.fixed`, and their `cov.fixed` diagonal gives finite, positive SEs **when the fit
converges with a PD Hessian**. A univariate exp()-delta-method CI is then a two-line
computation with no engine change required. `theta_rr_B_slope` (loadings) is reachable as raw
numbers but requires a multivariate delta method for any derived natural-scale quantity — not
a two-line computation.

**Caveat that is itself a finding:** getting a healthy (PD-Hessian) fit was NOT automatic.
Both routes' first attempts, at markedly smaller N, produced non-PD Hessians —
Route A failed to converge outright (`opt$convergence = 1`); Route B converged but with a
Heywood-collapsed `theta_diag_B_slope` (one `NaN` SE, others 10^1–10^4 in magnitude) because
the probe's first DGP had **zero** true Psi variance, sitting exactly on the boundary the
parameter estimates. A non-PD-Hessian SE is not usable as a standard error regardless of
whether the number is finite — this is a real fragility of the slope-block SEs at small N /
near the variance boundary, not just a probe-design artifact, since the package's own
`tests/testthat/test-ordinary-latent-random-regression.R` deliberately runs Route B fits with
`se = FALSE` rather than requesting SEs on this route.

## What this does NOT establish

- **No coverage or calibration evidence.** This probe checks only whether a number comes out
  finite and positive on one converged fit; it says nothing about whether a nominal 95% Wald
  interval built from these SEs would actually cover the true value 95% of the time. Design
  80's calibration arc and D-112 own that question; this probe is explicitly out of that scope.
- **Single seed, no replication.** All numbers above come from one seed per route. The
  "sanity signal" recovery ratios (0.68–2.23) are not evidence of unbiasedness or
  finite-sample accuracy.
- **Gaussian only.** Both routes were fit under `family = gaussian()`. Non-Gaussian families are
  untested here; `R/profile-derived.R`'s own gate marks the analogous correlation-profile path
  Gaussian-only for exactly this reason, and there is no reason to assume it transfers.
- **PD Hessian is a per-fit property, not a guarantee.** The healthy fits reported here required
  deliberately choosing N and a DGP that keeps true slope/Psi SDs away from the zero boundary.
  Smaller N, boundary-adjacent true values, or different formula shapes (e.g. the loadings-only
  `unique = FALSE` variant, or non-Gaussian families) may reproduce the non-PD failures seen on
  the first attempts. This probe does not characterize where that boundary is.
- **`theta_rr_B_slope` natural-scale intervals are not demonstrated**, only shown to have finite
  per-element SEs on the unconstrained loadings scale — the multivariate delta-method
  computation needed for a natural-scale CI was described but not implemented or run.
- **No claim about what a shipped extractor should look like** (API shape, naming, whether it
  belongs in `confint_inspect()`/`profile_targets()` or a new function) — this is a
  computability probe, not a design proposal.

## What changed between attempts (for the record)

1. First Route A attempt used the deprecated global `phylo_tree =` argument and a smaller DGP
   (`n_sp=25, n_rep=4`); it also incorrectly assumed the slope block was
   `theta_diag_B_slope`/`theta_rr_B_slope`. Correcting the formula to the in-keyword
   `phylo_indep(1 + x | species, tree = tree)` form and reading the actual `par.fixed` block
   table showed the real block is `theta_dep_chol`.
2. That corrected Route A fit at `n_sp=25` still had `opt$convergence = 1`, `pdHess = FALSE`.
   Scaling to `n_sp=60, n_rep=6` (still small) produced a clean fit.
3. First Route B attempt (`n_ind=14`, matching the test file's own fixture) was not run with
   `se = TRUE` in the original test; running it here at `n_ind=30` with `se = TRUE` converged
   but had `pdHess = FALSE` and a boundary-collapsed `theta_diag_B_slope` because the DGP had no
   true Psi variance. Adding explicit `psi_sd = 0.2` idiosyncratic noise to the DGP and scaling
   to `n_ind=50, n_rep=6` produced a clean fit with `theta_diag_B_slope` recovering ~0.2 as
   expected.
