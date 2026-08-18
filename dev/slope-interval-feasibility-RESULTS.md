# Are confidence intervals on random-SLOPE variance parameters mechanically reachable today?

**Date:** 2026-08-18
**Branch/worktree:** `claude/rand-slope-surface-20260818`, `/private/tmp/gllvmtmb-randslope`
**Script:** `dev/slope-interval-feasibility.R` (log: `dev/slope-interval-feasibility-OUTPUT.log`, from the final clean run)

## Provenance note -- an indexing bug was caught and fixed here

**The first version of this file had a genuine bug in Route A**, caught by an
adversarial review pass (Rose) and verified independently against
`src/gllvmTMB.cpp:1909-1935`, `R/lambda-constraint.R`'s
`dep_chol_crossblock_pins()`, and `R/fit-multi.R`'s wiring before any number
below was changed. Two distinct problems, both in Route A only:

1. **Indexing.** The first version assumed `theta_dep_chol`'s 9 free entries
   (for `n_traits = 3`) pack as 3-entry `(diag_int, diag_slope, offdiag)`
   blocks per trait, i.e. slope diagonals at positions 2, 5, 8. The actual
   packing is ALL diagonals first, THEN the strictly-lower triangle
   column-major -- so the slope diagonals are at positions **2, 4, 6**, and
   position 5 is trait 3's *intercept*, not a slope. Position 8 is a
   raw-scale off-diagonal Cholesky entry, and the first version wrongly
   `exp()`-transformed it as if it were a log-SD.
2. **A deeper issue survives correct indexing.** Under `phylo_indep(1+x|g)`
   the within-trait intercept-slope Cholesky entry is FREE (uncorrelated
   dep-slope pins keep the *within*-block correlation estimated; only
   *cross*-block entries are pinned to 0 for the block-diagonal `indep`
   variant). So the marginal slope variance is `L21^2 + L22^2`
   (`L22 = exp(diag_slope)`, `L21` = the free raw off-diagonal), not
   `exp(diag_slope)^2` alone. The first version's "theta_dep_chol diagonal
   entries are all univariate log-SDs" claim was therefore wrong for the
   slope coordinate (it remains true for the intercept coordinate, where
   `Var(intercept) = L11^2` has no such contamination).

**Route A's quantitative table below is fully recomputed** with the correct
indices and a multivariate delta method (2x2 `(diag_slope, L21)` `cov.fixed`
submatrix, gradient via `numDeriv::grad()`). Route B, the structural
computability finding (`sd_report` non-NULL, blocks present by name), and the
"no existing exported extractor" result were **not affected** by this bug and
are unchanged from the first version.

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

**Route A — `theta_dep_chol` (CORRECTED; see the provenance note above).**
The 9 free entries pack as: positions 1–6 are the 2*n_traits diagonals
interleaved `(int_1, slope_1, int_2, slope_2, int_3, slope_3)` (log-SD scale),
positions 7–9 are the n_traits within-block off-diagonal Cholesky entries
`L21` (raw scale), one per trait in trait order. The slope diagonal alone is
NOT the slope SD: `Var(slope_t) = L21_t^2 + exp(diag_slope_t)^2`, so the
correct SD and its SE come from a **multivariate** delta method over the 2x2
`(diag_slope, L21)` `cov.fixed` submatrix (gradient via `numDeriv::grad()`),
not `exp()` of a single parameter:

| trait | diag_slope theta_hat | se | L21 (raw) | se(L21) | naive `exp(diag_slope)` | **correct** `sqrt(L21²+L22²)` | multivariate delta-method SE | true slope SD | ratio |
|---|---|---|---|---|---|---|---|---|---|
| 1 | -0.410418 | 0.151135 | 0.086342 | 0.155792 | 0.663373 (wrong) | **0.668968** | 0.100236 | 0.5477 | 1.22 |
| 2 | -0.640056 | 0.175236 | -0.001243 | 0.121124 | 0.527263 (≈ correct here) | **0.527265** | 0.092396 | 0.7071 | 0.75 |
| 3 | -0.589356 | 0.175386 | -0.009469 | 0.134129 | 0.554684 (≈ correct here) | **0.554765** | 0.097337 | 0.4472 | 1.24 |

(The "naive" and "correct" columns are numerically close in this particular
fit only because the fitted `L21` values happen to be small relative to
`L22` — traits 2–3's true within-trait correlation was small/zero in the DGP.
Trait 1's true `rho = 0.45` shows a larger, though still modest, naive/correct
gap. The point is structural: whether the gap is large or small in a given
fit, the CORRECT computation always requires the 2x2 covariance submatrix,
not just the single diagonal SE.)

Worked example (trait 1, 95% CI, multivariate delta method):
```
diag_slope theta_hat = -0.410418, se = 0.151135
L21 (raw off-diag)   = 0.086342, se = 0.155792
naive sd_hat = exp(diag_slope)        = 0.663373  (WRONG shortcut, for contrast)
correct sd_hat = sqrt(L21^2 + L22^2)  = 0.668968
multivariate delta-method se(sd_hat)  = 0.100236
95% CI (symmetric Wald, clipped at 0) = [0.472509, 0.865427]
```
There is no `exp()`-based positivity-guaranteed variant here (unlike the
univariate log-SD case) because `g = sqrt(L21^2 + L22^2)` is not a
monotonic transform of a single normally-approximated parameter; the
symmetric Wald interval on the SD scale, clipped at 0, is the natural
choice.

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
`psi_sd = 0.2` closely on a single seed (ratios 0.68–1.21 across 6 entries). Route A's
correctly-computed slope SDs land at ratios 1.22 / 0.75 / 1.24 across the 3 traits on this single
seed — a wider spread than Route B's but not obviously pathological for one seed with no
averaging; no claim of bias or unbiasedness is made either way.

## Delta-method back-transform requirement

**Route B's `theta_diag_B_slope` is a genuine univariate log-SD**: a natural-scale interval
requires `sd_hat = exp(theta_hat)`, `se(sd_hat) = exp(theta_hat) * se(theta_hat)` (delta method,
`d/dtheta exp(theta) = exp(theta)`), giving either a symmetric-on-SD-scale Wald interval
`sd_hat ± z*se(sd_hat)` or the exponentiated link-scale interval
`exp(theta_hat ± z*se(theta_hat))` (strictly positive, generally preferable near the boundary).
This is a two-line computation.

**Route A's `theta_dep_chol` slope coordinate is NOT a univariate log-SD** (corrected from the
first version of this file — see the provenance note above). Its intercept diagonal alone would
be (`Var(intercept_t) = exp(diag_int_t)^2`), but the slope diagonal shares a Cholesky block with
a free within-trait off-diagonal entry: `Var(slope_t) = L21_t^2 + exp(diag_slope_t)^2`. A
natural-scale interval on the slope SD therefore needs the **same multivariate treatment** as
`theta_rr_B_slope` below: the 2x2 `(diag_slope, L21)` `cov.fixed` submatrix propagated through
`g(theta, L21) = sqrt(exp(2*theta) + L21^2)` via a delta method / numerical Jacobian (this file
uses `numDeriv::grad()`). This is demonstrated above, not just described — but it is not a
two-line computation.

`theta_rr_B_slope` (Route B loadings, when the fit uses the reduced-rank route) has **no**
simple per-element back-transform either: `Sigma_B_slope = Lambda_B_slope %*% t(Lambda_B_slope)`
is a nonlinear function of *multiple* `theta_rr_B_slope` entries at once. A CI on a derived
quantity (e.g. a per-trait slope SD from the loadings alone, or any entry of `Sigma_B_slope`)
needs the full relevant `cov.fixed` sub-block propagated through that quadratic form — a
multivariate delta method / numerical Jacobian, not `exp()` per element. Unlike Route A's slope
coordinate, this was described but not numerically demonstrated in this probe.

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

**Reachable (computability only) — for both routes, on a healthy fit, but the two routes need
different arithmetic and the file previously overstated Route A's.**

- **Route B (`theta_diag_B_slope`) — reachable via a two-line univariate delta method.**
  `object$sd_report` is populated by default, `theta_diag_B_slope` appears by name in
  `par.fixed`, its `cov.fixed` diagonal gives a finite positive SE on a healthy fit, and it is a
  genuine log-SD: `sd_hat = exp(theta_hat)`, `se(sd_hat) = sd_hat * se(theta_hat)`. Demonstrated
  above with a worked 95% CI.
- **Route A (`theta_dep_chol` slope coordinate) — reachable, but only via a multivariate delta
  method / numerical Jacobian, not a two-line computation.** The slope-variance parameter shares
  its Cholesky block with a free within-trait off-diagonal entry, so
  `Var(slope) = L21^2 + exp(diag_slope)^2` depends on two parameters and their covariance. This
  probe demonstrates the correct computation (2x2 `cov.fixed` submatrix, `numDeriv::grad()`) and
  reports a worked 95% CI, but it is materially more work than Route B's exp() shortcut — the
  same order of effort as `theta_rr_B_slope`'s loadings block.
- **`theta_rr_B_slope` (loadings)** is reachable as raw numbers with finite/positive per-element
  SEs, but has no per-element back-transform at all; a natural-scale quantity needs the full
  relevant `cov.fixed` sub-block through `Sigma = Lambda Lambda^T` — described here, not
  numerically demonstrated.

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
  "sanity signal" recovery ratios (Route A: 1.22/0.75/1.24; Route B: 0.68-1.21) are not evidence
  of unbiasedness or finite-sample accuracy.
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
4. **Adversarial review (Rose) caught an indexing bug in Route A after this file's first
   version was written and reported.** See the provenance note at the top of this file for the
   full correction: the free-parameter packing of `theta_dep_chol` is diagonals-first, not
   3-entry per-trait blocks, and the slope diagonal alone is not the slope variance because of
   the free within-block off-diagonal Cholesky entry. Route A's quantitative table, worked
   example, delta-method section, and verdict were all rewritten to reflect the correct
   indexing and the multivariate delta method it requires. Route B and the structural/extractor
   findings were independently re-verified and are unchanged.
