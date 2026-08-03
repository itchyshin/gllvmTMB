# TMB side of the stan-oracle fixed-parameter check

Target model, long-format ordinary Gaussian, `unit`-level reduced-rank
latent factor plus its diagonal companion:

```
value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)
family = gaussian()
```

`n_traits = 3`, `n_unit = 15`, `d_B = 1` (rank), 2 replicates per
`(unit, trait)` cell (`N = 90` rows). The extra replicate (vs. 1) is
load-bearing -- see the "sigma_eps" note below.

Script: `dev/stan-oracle/tmb-side.R`. Fixture: `tmb-fixture.rds` /
`tmb-fixture.json`, written by that script.

## What is evaluated

`fit <- gllvmTMB(...)` is fit once (Laplace, `random != NULL`) purely to
obtain a valid `fit$tmb_obj`, i.e. a correctly shaped `fit$tmb_data` /
`fit$tmb_params` / `fit$tmb_map` triple for the `"gllvmTMB"` DLL.
Convergence quality is irrelevant and was not checked.

A second TMB object is then built from that SAME triple with
`random = NULL`:

```r
joint_obj <- TMB::MakeADFun(
  data = fit$tmb_data, parameters = fit$tmb_params, map = fit$tmb_map,
  random = NULL, DLL = "gllvmTMB", silent = TRUE
)
```

This is the same move `.eva_make_objective()` in `R/eva-proto.R` makes
(`TMB::MakeADFun(..., random = NULL)`), just reusing the *main* engine's
DLL/data/parameters instead of the standalone EVA prototype's. With
`random = NULL`, nothing is Laplace-integrated: `joint_obj$fn(theta)` is
the JOINT negative log-density of data + all latent/random blocks,
evaluated pointwise at `theta`, i.e.

```
joint_obj$fn(theta) = -log p(y, z_B, s_B | b_fix, log_sigma_eps, theta_rr_B, theta_diag_B)
```

with `theta` the full concatenation of what were "fixed" AND "random"
parameters under the original Laplace fit.

`length(theta) = 70` for this fixture. Order and names come from
`names(joint_obj$par)`, in the order TMB concatenates the `parameters`
list (using only the entries that are NOT fully mapped off):

| block           | length | positions | scale / transform |
|-----------------|-------:|-----------|--------------------|
| `b_fix`         | 3      | 1–3       | natural scale (identity link); trait intercepts, ordered `traita, traitb, traitc` (matches `levels(df$trait)` = `a,b,c`; `colnames(fit$tmb_data$X_fix)`) |
| `log_sigma_eps` | 1      | 4         | log-SD of the Gaussian observation residual; `sigma_eps = exp(log_sigma_eps)` |
| `theta_rr_B`    | 3      | 5–7       | UNCONSTRAINED packed loadings of `Lambda_B` (n_traits x d_B = 3 x 1). Packing (ported from glmmTMB's `rr` covstruct): first `d_B` entries are the diagonal, remaining entries fill the strict lower triangle column-major. For `d_B = 1`, this packing is trivial: `theta_rr_B == Lambda_B[, 1]` directly, i.e. `theta_rr_B[i] = Lambda_B[i, 1]` for `i = 1..3`. No sign or positivity constraint is applied to any entry — this is the diagonal position `(1,1)` too, which is *not* forced positive at evaluation time (only the optimizer's own default init/lower bounds nudge a fitted diagonal toward one sign; `fn()` itself accepts any real value here). |
| `z_B`           | 15     | 8–22      | latent factor scores, UNCONSTRAINED (raw `N(0,1)` draws). Stored as a `d_B x n_sites = 1 x 15` matrix (`PARAMETER_MATRIX(z_B)`), so with `d_B = 1` the flattened (column-major) order is exactly one score per unit, in unit order `1..15` (0-indexed `site_id` 0..14 in `fit$tmb_data`). |
| `theta_diag_B`  | 3      | 23–25     | log-SD of the diagonal ("unique"/Psi) companion: `sd_B = exp(theta_diag_B)`, one entry per trait, same trait order as `b_fix`. |
| `s_B`           | 45     | 26–70     | the diagonal ("unique") random-effect VALUES themselves, UNCONSTRAINED (raw `N(0, sd_B[trait])` draws), natural (additive-to-`eta`) scale — not a further transform of `theta_diag_B`. Stored as an `n_traits x n_sites = 3 x 15` matrix (`PARAMETER_MATRIX(s_B)`), so the flattened (column-major) order is trait-fastest within each unit: `(trait=a,unit=1), (trait=b,unit=1), (trait=c,unit=1), (trait=a,unit=2), ...`. |

Total: `3 + 1 + 3 + 15 + 3 + 45 = 70`.

No other parameter block is active for this formula/family (`use_rr_B = 1`,
`use_diag_B = 1`, `use_lv_B = 0`, every other `use_*` flag is 0), and
`diag_B_skip = c(0,0,0)` (no trait's Psi is pinned off), confirmed by
inspecting `fit$tmb_data`.

## `sigma_eps`: why 2 replicates per cell, not 1

With exactly 1 observation per `(unit, trait)` cell, `unique(0 + trait |
unit)`'s per-row diagonal random effect is at the SAME granularity as the
Gaussian observation residual, so the R-side fitting code
(`R/fit-multi.R`) auto-detects the confound, prints:

> Auto-suppressing `sigma_eps`: `indep(0 + trait | unit)` is at the
> per-row level, so it already absorbs the observation residual.
> Fixed at ~1/1000 of `sd(y)`...

and MAPS `log_sigma_eps` off (excludes it from `fit$tmb_params`/`theta`
entirely, fixed near zero). That collapses the Gaussian data term to a
near-degenerate spike, which (a) removes `log_sigma_eps` from `theta`,
which the task wants free, and (b) makes `joint_obj$fn()` at an
off-optimum `theta` a huge number, since residuals over a near-zero
`sigma_eps` blow up. Using 2 replicates per cell keeps `log_sigma_eps` a
genuine free parameter of `theta`, which is the more natural quantity to
cross-check against a Stan model.

## What terms are in the joint density

`joint_obj$fn(theta)` sums exactly three kinds of `nll -= dnorm(..., log
= TRUE)` contributions (`src/gllvmTMB.cpp`, `nll` accumulator, function
returns `nll` at the end — no other terms are active for this
formula/family):

1. **Data likelihood** (family id 0, Gaussian identity link), one term per
   of the 90 rows:
   `nll -= dnorm(y(o), eta(o), sigma_eps, log = TRUE)`, where
   `eta(o) = (X_fix %*% b_fix)(o) + Lambda_B[trait(o), 1] * z_B[1, unit(o)] + s_B[trait(o), unit(o)]`
   and `sigma_eps = exp(log_sigma_eps)`.

2. **Random-effect prior on `z_B`** (the reduced-rank latent factor): a
   SPHERICAL standard normal, `N(0, I)`, one `dnorm(z_B[k, s], 0, 1, log =
   TRUE)` per `(k, s)` cell, `k = 1..d_B`, `s = 1..n_sites` — 15 terms
   here (`d_B = 1`). This is `N(0, I)`, not `N(0, Sigma)`: the identifiable
   `Sigma_unit` covariance is produced by `Lambda_B %*% t(Lambda_B) +
   diag(sd_B^2)` acting on i.i.d. standard-normal `z_B`/`s_B`, not by
   giving `z_B` a non-identity prior covariance directly.

3. **Random-effect prior on `s_B`** (the diagonal/"unique" companion):
   `N(0, sd_B[trait])` per `(trait, unit)` cell (`sd_B = exp(theta_diag_B)`),
   45 terms.

## Latent-variable entry into the linear predictor

Both latent blocks enter `eta` ADDITIVELY, at the SAME `(unit, trait)`
row, alongside the fixed-effect term:

```
eta(o) = X_fix(o, ) %*% b_fix                    # trait intercept, row o
        + Lambda_B(trait(o), 1) * z_B(1, unit(o)) # reduced-rank factor term
        + s_B(trait(o), unit(o))                  # diagonal Psi term
```

(`use_lv_B = 0` here, so the latent score entering `eta` is `z_B` itself,
not a predictor-shifted `U_B_total = X_lv_B %*% alpha_lv_B + z_B`; that
extra path only activates for `lv()`-style predictor-informed latent
terms, not used in this formula.)

## Jacobian

TMB applies NO automatic Jacobian correction for any parameter
transform — confirmed by reading `src/gllvmTMB.cpp`: every `log_*` ->
`exp(log_*)` reparametrisation (`sigma_eps = exp(log_sigma_eps)`, `sd_B =
exp(theta_diag_B)`) is used as a plain substitution inside a `dnorm(...,
log = TRUE)` call, with no compensating `+ log_*` term added to `nll`.
This is correct here because none of those log-parameters is itself the
variable being integrated/marginalised over — `log_sigma_eps` and
`theta_diag_B` are ordinary (non-random) hyperparameters of the Gaussian
densities above, not random effects with their own prior needing a
change-of-variables correction. (Contrast: the `lognormal` family branch
elsewhere in the same file DOES add an explicit `- log(y(o))` Jacobian
term for its `log(y) ~ Normal(...)` reparametrisation — so the codebase
is not blind to Jacobians in general, it just correctly omits one here.)

## Verification performed

`tmb-side.R`:
- evaluates `joint_obj$fn(theta)` twice at the identical `theta` and
  asserts `identical()` (bitwise) — **passed**, and reproduced across two
  independent `Rscript` invocations (`nll = 429.5886976357` both times).
- evaluates at a `theta` perturbed only in `b_fix[1]` (+0.1) and asserts
  the value changes — **passed**, differed by `19.413779`, i.e. the
  objective is not a constant/no-op function.

## Where I could not determine the transform / left an open question

None outstanding for the parameters that are actually free at `theta`
above (`b_fix`, `log_sigma_eps`, `theta_rr_B`, `z_B`, `theta_diag_B`,
`s_B`) — every scale/transform above was confirmed by reading the exact
C++ lines in `src/gllvmTMB.cpp` (`PARAMETER_VECTOR`/`PARAMETER_MATRIX`
declarations, the `exp()` calls, and the `dnorm(..., log = TRUE)` sites),
not inferred from naming convention alone.

One caution for whoever builds the Stan side: `theta_rr_B`'s diagonal
entry (`theta_rr_B[1]`, i.e. `Lambda_B[1,1]`) has NO positivity
constraint enforced by the density itself — sign/rotation
identifiability of `Lambda_B` is a property of the OPTIMIZER's
convention (init values / lower bounds elsewhere in `R/fit-multi.R`),
not of `joint_obj$fn()`. At a hand-chosen `theta` (as used here) this is
a non-issue — evaluate at whatever real number you like — but it means
the Stan model must not silently impose `Lambda_B[1,1] > 0` (e.g. via a
`lower=0` constraint) if it wants to be evaluated at this exact `theta`,
since `theta_rr_B[1] = 0.8` (positive) in the fixture but the density is
defined for negative values too.
