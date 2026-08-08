# ISDM plumbing check: do the PO and PA arms genuinely share parameters?

Script: `dev/isdm-plumbing.R`. Package: `gllvmTMB` **0.6.0** (installed, loaded
via `library(gllvmTMB)`, no `devtools::load_all()`). R 4.6.0. Full run log:
`/tmp/isdm-plumbing-log2.txt` (paths quoted below are copy-pasted from that
run, not paraphrased). Rerun with `Rscript dev/isdm-plumbing.R`.

## Exact DGP used (reproducible)

One ecological intensity per cell i: `log(mu_i) = b0 + x_i*b + xi_i`.

- **PO arm**: `Y_po_i ~ Poisson(lambda_i)`,
  `log(lambda_i) = log(A_i) + b0 + x_i*b + xi_i + a0 + w_i*alpha`.
- **PA arm** (derived, not assumed): `cloglog(p_i) = log(a_i) + b0 + x_i*b + xi_i`,
  `Y_pa_i ~ Bernoulli(p_i)`.
- `b0` and `b` are the SAME parameters in both arms; the PA arm carries no
  `a0`/`alpha` term at all (`is_po`-gated in the formula, see below).

**Area units (constraint 2, verified done correctly):** PA survey area
`a_i = 1` for every site (`log(a_i) = 0`, a legal ZERO offset on the binomial
rows). PO cell areas `A_i ~ Uniform(50, 200)`, **varying across cells** and
expressed in the SAME units as the PA plots (i.e. "how many PA-plots' worth
of area cell i is") — not independently rescaled. This is what exercises the
offset machinery rather than letting `a0` silently absorb a unit mismatch.

**Same latent unit (constraint 1):** the shared score `u_i ~ N(0, 1)` is
drawn ONE PER CELL, `xi_i = lambda_load * u_i`, and both the PO row and the
PA row for cell i use the SAME `xi_i`.

**No aggregation (constraint 3):** PO and PA responses are simulated
directly on the fitting grid (`n_cell` cells); nothing is aggregated from a
finer/continuous field.

**Formula grammar used** (single trait `"sp1"`, since these are
single-species checks): an indicator `is_po = 1{source == "po"}` and a
zeroed-on-PA bias covariate `w` (set to 0 on PA rows) let one formula carry
both arms with `b0`/`b` shared and `a0`/`alpha` PO-only:
```r
value ~ 1 + x + is_po + is_po:w + offset(off) + latent(0 + trait | cell, d = 1, unique = FALSE)
```
`off` = `log(A_i)` on PO rows, `log(a_i) = 0` on PA rows.
`family = list(po = poisson(), pa = binomial(link = "cloglog"))` with
`attr(family, "family_var") <- "source"`, `cluster = "trait"` (per the prior
probe's finding that the default `cluster` collapses more than intended).

`latent(..., unique = FALSE)` was used deliberately for T2-T4: with a single
trait, `latent()`'s default per-trait Psi companion (`Sigma = Lambda*Lambda' + Psi`)
is NOT separately identifiable from the loading (Lambda and Psi both just
add to the same scalar variance with nothing to break the tie) — confirmed
directly in the T4 trap-check section below and by a failed `pdHess` when
tested with the default `unique = TRUE`.

**Planted truth (T2-T4):** `b0 = 0.0`, `b = 0.4`, `a0 = -3.0`, `alpha = 0.3`,
`lambda_load = 0.5` (loading on `u`), `sigma_u = 1`. `n_cell = 400`.

**Seed scheme:** T1 uses one dedicated dataset (`seed = 11`, `n_cell = 300`,
its own planted values `b0=0.2, b=0.5, a0=-1.0, alpha=0.3`, chosen
independently of T2-T4). T2-T4 use `seed = 1000 + i` for `i = 1..20` (20
seeds), with T3's permutation drawing an independent second seed stream
(`seed + 500000`) so the permutation itself is reproducible without
colliding with the DGP seed.

---

## T1 — Analytic cross-check (load-bearing)

Fixed-effects-only fit (`fit1$random` is `character(0)`: confirmed no random
effects, so `fit1$tmb_obj$fn()` IS the exact joint NLL, not a Laplace
approximation). Parameter ordering from `fit1$X_fix_names`:
`"(Intercept)" "x" "is_po" "is_po:w"`, matching `fit1$opt$par`'s four
`b_fix` entries in that order.

Independent R NLL: `-sum(dpois(y_po, lambda, log=TRUE)) - sum(dbinom(y_pa, 1, p, log=TRUE))`
built from the SAME formulas as the DGP, evaluated at each parameter vector.

```
true         par=(  0.200,  0.500, -1.000,  0.300)  TMB=1202.73264093  R=1202.73264093  diff=4.547e-13
zero         par=(  0.000,  0.000,  0.000,  0.000)  TMB=9803.34630490  R=9803.34630490  diff=-9.095e-12
arbitrary    par=(  1.000, -1.000,  2.000, -0.500)  TMB=1276399.99400244  R=1276399.99400244  diff=2.328e-10
fitted-opt   par=(-33.573,  0.493, 32.781,  0.309)  TMB=6749.74726080  R=7961.60885806  diff=-1.212e+03
```

Three of four points (`true`, `zero`, `arbitrary`) agree to numerical
precision (1e-10 to 1e-13) — no constant offset needed; TMB's objective
includes the full Poisson normalising constant
(`sum(lgamma(y_po1+1)) = 72779.41`, confirmed by using `dpois(..., log=TRUE)`,
which already carries `-lgamma(y+1)`, on both sides).

**The fourth point (`fitted-opt`) is `fit1$opt$par` itself, and it disagreed
by 1212 — investigated rather than accepted at face value:**

1. `fit1$sd_report$pdHess` is **FALSE** — already a red flag that `fit1`'s
   default single-restart run is NOT a genuine optimum, despite
   `opt$convergence == 0`.
2. A b0-sweep (b, a0, alpha held at truth) shows TMB and an unclamped,
   numerically-stable R computation (`log(p) = log(-expm1(-mu))`,
   `log(1-p) = -mu`) track EXACTLY until b0 pushes the cloglog probability
   below `1e-12`, where they start to diverge (from b0=-25 onward):
   ```
   b0=-25.0000  TMB=507961.2380  R=507961.2380  diff=0.0000
   b0=-28.0000  TMB=570688.1160  R=570763.2380  diff=-75.1220
   b0=-33.5728  TMB=686212.2801  R=687424.0049  diff=-1211.7248
   ```
3. Traced to `src/gllvmTMB.cpp:2192-2195`: the binomial kernel clamps
   `p` to `[1e-12, 1-1e-12]` before `dbinom()` — a documented numerical
   safety guard ("Numerical safety: clip away from 0/1 to prevent log(0)"),
   applied identically on every row. Replicating that SAME clamp in R at
   `fit1$opt$par`:
   ```
   R NLL with the SAME [1e-12, 1-1e-12] clamp: 6749.747261
   TMB fn() at the same point:                 6749.747261
   diff: -9.095e-12  (numerical-precision only)
   ```
   This closes the gap completely — it is a documented, intentional
   numerical-safety clamp, not a family-dispatch error.
4. A refit with more restarts (`gllvmTMBcontrol(n_init = 8, init_jitter = 1.0)`)
   recovers the true optimum: `pdHess = TRUE`, `opt$par = (0.188, 0.493,
   -0.980, 0.309)` against planted `(0.2, 0.5, -1.0, 0.3)`, objective
   `1200.57` (vs. the default-start run's `6749.75` and the true-parameter
   NLL of `1202.73`). This confirms the default single-restart `fit1` had
   genuinely landed in a clamp-flattened local optimum — the same
   raw-`y` OLS starting-value footgun the prior probe documented (T3 there),
   now shown to actually flip `pdHess` to FALSE and produce badly wrong
   point estimates with default settings, not merely cost extra iterations.

**VERDICT: T1 PASSED.** TMB's objective agrees with an independently coded
joint NLL to numerical precision at every parameter vector tested, including
a pathological one once its documented `[1e-12, 1-1e-12]` clamp is
replicated in R — the right family is genuinely applied to the right rows,
with no dispatch error anywhere. Separately (not a T1 failure, but an
important operational finding): the default single-restart optimizer can
land in a clamp-flattened degenerate optimum for this design and falsely
report `convergence = 0`; `pdHess = FALSE` correctly flagged it, and
`n_init > 1` with jitter recovers the true optimum.

---

## T2 — Beta recovery, one species, joint fit, 20 seeds, n_cell = 400

```
n_ok=20/20  convergence: all 0   pdHess: all TRUE
planted b = 0.400
mean(b_hat) = 0.39591   SD(b_hat) = 0.03692
bias = -0.00409   MCSE(bias) = 0.00826
```
(individual `b_hat` across the 20 seeds: 0.313, 0.394, 0.426, 0.412, 0.378,
0.424, 0.423, 0.402, 0.453, 0.350, 0.366, 0.411, 0.424, 0.460, 0.394, 0.339,
0.376, 0.380, 0.416, 0.378). Wall time: 3.53 s for 20 fits.

Bias (-0.0041) is small relative to its MCSE (0.0083, i.e. bias/MCSE ≈ -0.5)
— not distinguishable from zero at this seed count.

**VERDICT: b recovers with no detectable bias (bias -0.004, MCSE 0.008) and
every one of the 20 fits converges with a positive-definite Hessian.**

---

## T3 — Does the PA arm actually contribute? (PA responses permuted)

Design preserved, PA `value` permuted across cells (`sample()` on the PA-row
subset only; `x`, `w`, `off`, `cell` untouched). Same 20 seeds, same joint
formula/fit.

```
n_ok=20/20  convergence: all 0   pdHess: all TRUE
planted b = 0.400
mean(b_hat) = 0.35977   SD(b_hat) = 0.03495
bias = -0.04023   MCSE(bias) = 0.00781
```

```
T2 (joint, PA intact):    mean(b_hat) = 0.39591  bias = -0.00409  MCSE = 0.00826
T3 (joint, PA permuted):  mean(b_hat) = 0.35977  bias = -0.04023  MCSE = 0.00781
Difference in mean b_hat (T3 - T2): -0.03614
Welch two-sample t-test: t = 3.1792, df = 37.886, p = 0.00294
95% CI on the difference: (0.0131, 0.0592)
```

Destroying the PA arm's information roughly **10x's the bias** (-0.004 to
-0.040) and the shift is statistically distinguishable from T2's estimates
(Welch p = 0.003, seed-paired MCSEs of comparable size ~0.008 in both arms,
so this is a genuine shift in the point estimate, not just added noise).

**VERDICT: The PA arm is NOT inert — permuting its responses significantly
worsens `b` recovery, so T2's clean recovery reflects real joint information
sharing, not a vacuous PA contribution.**

---

## T4 — Arm comparison (PO-only vs PA-only vs joint)

Same 20 seeds, same cells, same planted truth. PO-only formula:
`value ~ 1 + x + w + offset(off) + latent(0 + trait | cell, d=1, unique=FALSE)`,
family `poisson()`. PA-only formula:
`value ~ 1 + x + offset(off) + latent(0 + trait | cell, d=1, unique=FALSE)`,
family `binomial(link="cloglog")`.

```
arm                mean(b_hat)       bias       MCSE
joint (T2)            0.39591   -0.00409    0.00826
PO-only               0.39544   -0.00456    0.00862
PA-only               0.38949   -0.01051    0.01906
```
n_ok = 20/20 for both arms; all convergence = 0, all pdHess = TRUE. Wall
times: 1.53 s (PO-only) and 1.38 s (PA-only) for 20 fits each.

All three arms recover `b` with small bias relative to MCSE. PA-only has
~2.3x the MCSE of the joint fit (0.0191 vs 0.0083), consistent with a single
0/1 draw per cell carrying less information about `b` than a Poisson count.

**PO-only intercept confound (illustration, seed 1001):**
```
PO-only fit$X_fix_names: "(Intercept)" "x" "w"
PO-only fit$opt$par:    -2.9958025   0.3119918   0.2215508 (+ theta_rr_B)
planted b0 + a0 = 0.0 + -3.0 = -3.0
```
The PO-only intercept (-2.996) matches `b0 + a0` (-3.0), not `b0` alone
(0.0), exactly as expected — PO-only cannot separate `b0` from `a0`.
Consequently only `b` (not `b0`) is scored for PO-only above, as instructed.

**`diag_B_skip` trap (`R/fit-multi.R:4976`) check:**
Our PA-only fits use `latent(..., unique = FALSE)`, so there is no per-trait
Psi (`theta_diag_B`) to pin — the trap has nothing to fire on
(`diag_B_skip = 0` for the seed-1001 PA-only fit under our setup). Refitting
the SAME PA-only data with the package's **default** `latent(unique = TRUE)`
(i.e. NOT our chosen `unique = FALSE`) DOES fire the trap:
```
Skipping the default between-unit Psi for 1 binary/categorical-contrast trait...
convergence: 0  pdHess: TRUE
diag_B_skip: 1 (trap fired, Psi pinned to 1e-6)
```
— and, separately, refitting the JOINT (PO+PA) data with the same default
`unique = TRUE` does NOT fire the trap (`diag_B_skip: 0`, because Poisson
rows are present so not every row of the trait is single-trial Bernoulli),
but DOES fail with `pdHess = FALSE` for a different, more fundamental reason
(see T2's DGP section note above): with a single trait, Lambda and Psi are
never separately identifiable regardless of family — the trap only auto-fixes
the specific all-Bernoulli-single-trial case, not the general single-trait
Lambda/Psi confound. This is exactly why T2-T4 deliberately use
`unique = FALSE` throughout: it sidesteps both problems uniformly rather
than relying on the trap's narrower auto-fix.

**VERDICT: PO-only and PA-only both recover `b` (not `b0` for PO-only, which
is structurally confounded with `a0` as expected) with small bias; PA-only
is noisier (MCSE ~2.3x the joint fit's); the `diag_B_skip` trap does fire
for a PA-only fit under the package's default `latent(unique=TRUE)` but was
inert in our main comparison because T2-T4 use `unique=FALSE` throughout for
a separate, more fundamental single-trait identifiability reason.**

---

## Overall

T1's analytic cross-check is a clean **PASS**: TMB dispatches the Poisson
likelihood to PO rows and the binomial-cloglog likelihood to PA rows exactly
as specified, with no dropped/extra additive constant, agreeing with an
independently coded R computation to numerical precision at every tested
parameter vector (including, once its documented safety clamp is replicated,
a pathological one). T2 recovers the shared slope `b` cleanly across 20
seeds (bias -0.004, MCSE 0.008); T3 shows the PA arm is genuinely
informative (destroying it roughly 10x's the bias, p = 0.003); T4 shows both
single arms separately recover `b` with PA-only markedly noisier, and
surfaces the `diag_B_skip` trap as real but not load-bearing in our
`unique = FALSE` setup. Two operational footguns are worth carrying forward:
(1) the default single-restart optimizer can land in a clamp-flattened local
optimum for extreme-prevalence cloglog designs, flagged correctly by
`pdHess = FALSE`; (2) a single-trait `latent(unique = TRUE)` (the package
default) is not identifiable — `unique = FALSE` is required for
single-species/single-trait ISDM-style fits.
