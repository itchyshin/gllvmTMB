# Stan side of the independent joint-density oracle

Role: Stan model author. Date: 2026-08-03.

**Independence statement.** The Stan program was written from
`dev/stan-oracle/model-spec.md` alone. No file under `src/` was opened, no R file
that constructs a TMB objective was opened, and neither `dev/stan-oracle/tmb-side.R`
nor `dev/stan-oracle/tmb-side.md` was read. The only other input was
`dev/stan-oracle/tmb-fixture.json`, which is data.

## 1. Files

| path | what it is |
|---|---|
| `dev/stan-oracle/gllvm_ordinary.stan` | the model — exactly the three density terms boxed in spec §7.1 |
| `dev/stan-oracle/stan-side.R` | driver: compile, `log_prob` at fixed values, write JSON |
| `dev/stan-oracle/stan-value.json` | the result |

## 2. Interface and the exact call

**rstan 2.32.7** (`StanHeaders` 2.32.10, R 4.6.0). cmdstanr 0.9.0 is also installed
but was not used: rstan exposes `unconstrain_pars()` / `log_prob()` directly on a
`stanfit` shell, which is the shortest path to a fixed-parameter evaluation with no
sampler.

```r
sm   <- rstan::stan_model("gllvm_ordinary.stan")
fit0 <- rstan::sampling(sm, data = stan_data, chains = 0)   # shell only, no draws
upars <- rstan::unconstrain_pars(fit0, pars)                # named list -> unconstrained vector
lp    <- rstan::log_prob(fit0, upars,
                         adjust_transform = FALSE,          # <-- NO constraint Jacobians
                         gradient = FALSE)
```

`chains = 0` prints `the number of chains is less than 1; sampling not done` and
returns a `stanfit` with no draws. **No sampling is ever run.**

### Why `adjust_transform = FALSE` is load-bearing

It is not cosmetic. Measured on this fixture:

```
log_prob(..., adjust_transform = TRUE ) = -438.2551705767
log_prob(..., adjust_transform = FALSE) = -429.5886976357
difference                              =   -8.6664729410
                    sum(log psi) + log(sigma_eps) =   -8.6664729410
```

The difference is exactly the `lower=0` transform Jacobian for the three `psi`
entries and `sigma_eps`, as it must be. TMB applies none, and spec §0
("No Jacobian adjustments") requires none, so `FALSE` is the only comparable
setting. A run with the default `TRUE` would be off by ~8.67 and would look like a
model error.

## 3. Parameter order Stan expects

Declaration order in the `parameters` block, each block flattened **column-major**:

| # | block | declared type | entries | unconstrained representation |
|---|---|---|---|---|
| 1 | `mu` | `vector[n_t]` | 3 | identity |
| 2 | `Lambda` | `matrix[n_t, K]` | 3 | identity (column-major) |
| 3 | `psi` | `vector<lower=0>[n_t]` | 3 | **log** |
| 4 | `sigma_eps` | `real<lower=0>` | 1 | **log** |
| 5 | `z` | `matrix[n_u, K]` | 15 | identity (column-major) |
| 6 | `q` | `matrix[n_u, n_t]` | 45 | identity (column-major) |
| | **total** | | **70** | |

`log_prob()` takes the **unconstrained** vector; the driver never hand-builds it,
it passes a named list of **constrained, natural-scale** values through
`unconstrain_pars()`, so the ordering above is documentation rather than a
dependency.

The total, 70, equals the length of the fixture's `theta$values`. The block sizes
line up one-for-one with the fixture's `theta$blocks`
(`b_fix` 3, `theta_rr_B` 3, `theta_diag_B` 3, `log_sigma_eps` 1, `z_B` 15,
`s_B` 45) — though in a different declaration order (Stan puts `sigma_eps` after
`psi`; the fixture puts `log_sigma_eps` fourth overall).

`Sigma_unit` is a `generated quantities` value only and contributes nothing to
`target`. `T` is reserved in the Stan language (truncation syntax), so the trait
count is spelled `n_t`.

## 4. Where the fixture's parameterisation did NOT line up with Stan's declarations

The fixture stores the **engine's internal vector**; the Stan program declares
**natural-scale** quantities per spec §5/§8. Four mismatches, three of which the
spec itself flags as unresolvable without reading `src/` (§11 items 1–3).

### 4.1 `log_sigma_eps` → `sigma_eps` (unambiguous)

Fixture stores a **log-SD**, Stan declares `real<lower=0> sigma_eps` (an SD).
`sigma_eps = exp(-1.38629436111989) = 0.25`. The name settles it.

### 4.2 `theta_diag_B` → `psi` — log-**SD**, not log-variance (spec §11 item 1)

Stan declares `vector<lower=0>[n_t] psi` as **variances** (spec §4.2 commits to
psi = variance). The spec records the repo prose as self-contradictory on this
point: `00-vision.md`/`AGENTS.md` write `diag(psi)` (variance) while
`04-random-effects.md` writes `Psi = diag(psi_t^2)`, `psi_t^2 = exp(2 theta~_t)`
(so their `psi_t` is an SD).

**Resolved: `exp(theta_diag_B)` is an SD**, i.e.

```
psi (variance) = exp(2 * theta_diag_B) = (0.09, 0.0625, 0.1225)
```

The competing reading `psi = exp(theta_diag_B) = (0.30, 0.25, 0.35)` is wrong here
and shifts the joint by **+8.94** — a factor-of-`psi` error that would not announce
itself as an error, exactly as the spec warns.

### 4.3 `theta_rr_B` → `Lambda` — the leading diagonal is **NOT** exponentiated (spec §11 item 2)

This is the one that contradicted the spec's own reading, and it is the most
important finding on the Stan side.

Spec §6.2 states the rotation convention as lower-triangular with a strictly
positive diagonal, "implemented internally on the log scale,
`lambda_kk = exp(lambda~_kk)`". Combined with the fixture's `theta_` prefix
(which does mark log scale for `theta_diag_B`), the spec-derived reading is
`Lambda[1,1] = exp(0.8) = 2.2255`.

**That is not what the fixture holds.** The value that reproduces the fixture is
the plain one:

```
Lambda = (0.8, 0.6, -0.4)'     # T x K = 3 x 1, natural scale, no exp
```

The `exp` reading shifts the joint by **−792.25**. So either the engine does not
exponentiate the leading diagonal of the reduced-rank block, or the fixture author
transported an already-natural-scale `Lambda`. Which of the two is true cannot be
decided without reading `src/`, and does not need to be: **for transporting values
between the two sides, `theta_rr_B` is used as-is.** The `theta_` prefix is
therefore *not* a reliable marker of log scale in this fixture — `theta_diag_B` is
logged, `theta_rr_B` is not.

Note this is untested for `K > 1`: with `K = 1` there is exactly one diagonal
entry and no packing question. For `K >= 2` the **packing order** of the
lower-triangular block (column-major full matrix vs. packed lower triangle) is a
further unknown this fixture cannot resolve.

### 4.4 `s_B` → `q` — level-major unpacking (spec §11 item 2)

`s_B` is a flat length-45 vector; Stan declares `matrix[n_u, n_t] q`. The spec
fixes the mathematics (`q_{lt}`, `n_u x n_t`) but not the storage order.

**Resolved: level-major** — trait varies fastest within unit, i.e.
`matrix(s_B, nrow = n_u, ncol = n_t, byrow = TRUE)`. This is the lme4/glmmTMB
random-effect ordering (blocks of `p` terms per level). The transposed reading
shifts the joint by **−102.20**.

`z_B` has `K = 1`, so its layout is not exercised and remains unverified.

### 4.5 What was *not* a mismatch

`b_fix` is already natural-scale and maps directly to `mu` in trait order
(`a`, `b`, `c`). Spec §11 item 3 — whether the engine's random-effect vector is
literally `(z, q)` — is answered affirmatively by the result below: the fixture's
70-long vector decomposes as `(z, q)` with `n_u*K + n_u*T = 60` latent scalars and
the hierarchical form (b) is pointwise comparable, so the check did **not** have to
be re-scoped to marginal likelihoods.

## 5. How the three unknowns were resolved — disclosure

They were **measured, not guessed and not read out of `src/`**, which is what spec
§11 prescribes ("maintainer statement or empirical measurement, not source
inspection").

The driver declares a **2×2×2 grid** over the three unknowns *before* consulting
the fixture's stored value, and evaluates all 8 cells with the **same, fixed,
spec-derived Stan density**. Exactly one cell reproduces the fixture's
`joint_neg_log_density`:

| lambda_diag | psi_scale | q_layout | neg log-density |
|---|---|---|---|
| exp | sd | level_major | 1221.835645535  (spec-primary) |
| **identity** | **sd** | **level_major** | **429.588697636  ← unique match** |
| exp | variance | level_major | 1230.776567793 |
| identity | variance | level_major | 438.529619893 |
| exp | sd | trait_major | 1278.986247710 |
| identity | sd | trait_major | 531.787624818 |
| exp | variance | trait_major | 1289.801628015 |
| identity | variance | trait_major | 542.603005123 |

```
fixture joint_neg_log_density = 429.588697635680
stan   neg log-density        = 429.588697635680
absolute difference           = 1.14e-13
relative difference           = 2.65e-16      (~1 ulp)
```

**What this does and does not license.** The *density* — three terms, the linear
predictor, the variance-vs-SD handling, all `2*pi` normalising constants — was
never adjusted; it is the spec's §7.1 box verbatim, and it is what agrees. Only the
*transport* of the fixture's internal-scale numbers onto natural-scale declarations
was selected by matching, from a pre-enumerated set of 8. A wrong likelihood cannot
be rescued to ~1 ulp by any of 8 rescalings, so the agreement is genuine evidence
about the model. But the mapping itself is **measured, not independently derived**,
and should be confirmed by the maintainer before it is treated as documented
behaviour — particularly §4.3, which contradicts the design prose the spec quotes.

Both values are written to `stan-value.json`: `log_density` (the identified
mapping, −429.588697635680) and `log_density_spec_primary` (the unmeasured
spec-derived reading, −1221.835645535).

## 6. Verification performed

- **Compiles.** `rstan::stan_model()` succeeds; no warnings from the model.
- **Finite.** `log_prob` returns −429.588697635680, finite.
- **Not constant.** Perturbations (evaluated at the spec-primary cell) all move it:

  | perturbation | log-density | delta |
  |---|---|---|
  | `mu[1] += 0.10` | −1267.7530818525 | −45.917436 |
  | `z[1,1] += 0.25` | −1291.1471145565 | −69.311469 |
  | `psi[2] *= 1.50` | −1220.3563911794 | +1.479254 |

  The `psi` perturbation moving the value at all is the specific check that the
  `Psi` term is present and is not being double-counted or dropped; the `z`
  perturbation checks the latent block is actually wired into `eta`.
- **Repeatable.** Two evaluations at the same input are bit-identical.
- **Jacobian genuinely off.** The `TRUE`/`FALSE` difference equals
  `sum(log psi) + log(sigma_eps)` to machine precision (§2), so the reported value
  provably contains no constraint Jacobian.

## 7. Residual limitations

1. **`K = 1` only.** The loadings packing order, the rotation convention's
   triangular zeros, and the `z` layout are all untested. A `K >= 2` fixture would
   exercise them and is the obvious next case.
2. **Balanced design.** `N = 90 = n_u * T * 2`, no missing cells. The spec allows
   ragged data (§1); the Stan program handles it by construction (it indexes per
   row), but it is unexercised.
3. **The mapping in §4.3 is unexplained.** It contradicts the design prose. Worth a
   maintainer answer, because a doc that says `lambda_kk = exp(lambda~_kk)` while
   the stored value is natural-scale will mislead the next person who writes a
   harness.
4. **One parameter point.** Agreement at a single `(theta, z, q)` is strong but not
   a proof of agreement everywhere; a handful of additional points (and the
   difference-of-differences check of spec §7.3) would cost almost nothing.
