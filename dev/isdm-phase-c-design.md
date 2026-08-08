# Phase C (#943) — ADEMP design for the ISDM misspecification campaign

**Author role:** Fisher (statistical-inference review).
**Status:** DESIGN ONLY. Nothing here has been run. This document is the implementation
contract; an implementing agent should need no further judgment calls.
**Lane:** `claude/experiment-integrated-sdm`, worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm` only. No PR, no merge, no push,
no `src/` edit, no package edit. `devtools::load_all()` the worktree; `NOT_CRAN=true`.

**Predecessors, assumed read:**
`docs/dev-log/after-task/2026-08-08-isdm-gate-phase-a.md`,
`dev/isdm-gate-findings.md`, `dev/isdm-plumbing.R`, `dev/isdm-gate-harness.R`,
`dev/isdm-phase-c-reuse-map.md`, `dev/isdm-wide-format-probe.md`.

---

## 0. Why this arm exists, stated as a defect in the previous arm

Phase A generated data from exactly the model it fitted. Under that design, "the integrated
model outperforms naive pooling" is true **by construction**; the campaign measured
*recovery*, which is a necessary check and not evidence of *benefit*. Phase A said so itself
(§10: *"A simulation generated from the fitted model cannot fail"*).

Phase C fits a model that is **structurally incapable of representing the truth**. The fitted
presence-only bias term is a per-source, per-species **constant** `gamma[d,j]`. The generated
recording bias is a **site-level field** that varies across space and correlates with the
environmental predictor. That mismatch is not a nuisance to be minimised — it *is* the
experiment.

### 0.1 The headline question is about the factor structure, not the slopes

`u_i` is site-level. Unmodelled recording bias is site-level. **The factors are the natural
sink.** Two species over-recorded in the same places load on a common factor and are reported
as positively associated: a *sampling* correlation reported as a residual *ecological* one.
Since the correlation matrix is the headline output of a GLLVM, this measurement decides how
the method may be described in the paper.

Corpus position (already researched; do not re-search): Tobler et al. 2019 demonstrate this
corrupted-correlation mechanism by simulation for **presence–absence**, with species-specific
bias correlated with habitat as the driver. The **presence-only** case is absent from the
literature because existing multispecies-PO models structurally cannot raise the question.

### 0.2 One correction to the framing, made before any code is written

The fitted model has **no spatial term** on `xi` (it is `Lambda u + eps`, i.i.d. across units).
To such a model, a spatially smooth bias field and an i.i.d. bias field of the same variance
are **not automatically different objects**. Spatial smoothness enters the problem through
exactly three channels and no others:

1. **Correlation with `x`** (parameter `rho`) — a smooth bias field can correlate with a smooth
   environmental field; an i.i.d. one essentially cannot at realistic `n`. This is what
   confounds `beta`.
2. **Cross-species sharing** (parameter `omega`) — whether the same places are over-recorded
   for every species. This is what makes the bias *factor-like*.
3. **Effective rank** — a smooth field concentrates its variance in few spatial directions, so
   it is *more* representable by a small number of factors than white noise of the same
   variance. This is a real mechanism and is measured on its own ladder (G6, `phi`).

Consequence for honesty: this campaign may **not** be described as "we simulated spatial
sampling bias and the model absorbed it." It must be described as "bias with controlled
environmental correlation, cross-species sharing and effective rank." Channel (3) is the only
one where the word *spatial* is load-bearing, and it is on its own ladder so it can be reported
separately or not at all.

---

## A — AIMS

### A1. Primary aim, as a measurable estimand

Let `R` be the planted `T x T` ecological residual correlation matrix on the shared linear
predictor, and `R_hat(m)` the matrix the fitted arm `m` reports. Define the **signed
off-diagonal distortion**

```
D_bias(m) = mean_{j<k} ( R_hat(m)_{jk} - R_{jk} )          # T(T-1)/2 pairs
```

**The aim is the curve `D_bias(m, kappa)` as a function of bias amplitude `kappa`, for each
arm `m`, with Monte Carlo standard error.** The headline deliverable is a curve, not a number:
a single cell cannot distinguish "the method is broken" from "we chose a punishing constant."

### A2. Secondary aims

- **A2a — attribution.** Is any measured distortion attributable to the *unmodelled bias
  structure*, rather than to finite-sample noise or to the estimator's own behaviour? Answered
  by the paired contrast against an **oracle** arm that observes the bias field (arm A6).
  This is the Phase C analogue of Phase A's PP/BB control cells, and it exists for the same
  reason: without it a positive result is unattributable.
- **A2b — does integration help *here*, where the truth is not the fitted model?** Paired
  per-seed contrasts A1 (PO-only) and A3 (naive pooled) against A5 (integrated + offsets).
  This is the question Phase A structurally could not ask.
- **A2c — separation of the two damages.** Bias to `beta` (environmental slopes) and
  distortion of `R` are different failures with different drivers. Pre-registered claim:
  `beta` damage is driven by `rho`, `R` damage by `kappa` and `omega`. Measured separately.
- **A2d — dose-response shape and thresholds.** At what `kappa` does the corruption criterion
  (§P3) first fire, per arm?

### A3. Explicitly NOT aims

Real GBIF data; detection probability; disjoint PO/PA units (declared deferred in Phase A §3a
and still deferred); a fitted spatial random field; model selection over `d`; any claim about
the package's exported API. **No capability is advertised by this slice.**

---

## D — DATA-GENERATING MECHANISM

### D1. Units, coordinates, and the two arms

`n` cells on a regular `sqrt(n) x sqrt(n)` lattice over the unit square; cell `i` has
coordinates `s_i`. A lattice (not a random point pattern) is used so that `n` and spatial range
are not confounded across the `n`-ladder.

Each cell contributes, for each of `T` species, **two rows**:

- a **PO row**: Poisson count `y ~ Poisson(exp(eta_po))`, `family = poisson()`;
- a **PA row**: `y ~ Binomial(k, p)`, `cloglog(p) = eta_pa`,
  `family = binomial(link = "cloglog")`, with `k = 3` repeat visits (see D6).

PO cells and PA sites are the **same** latent units, as in Phase A (§3a): the model has no
spatial kernel on `xi`, so disjoint units would transfer zero information through `xi` and the
arms would be testing a different question.

### D2. The ecological process (shared, bias-free)

```
u_i          ~ N(0, I_d)            i.i.d. across cells, d = 2                (design stream)
eps_ij       ~ N(0, psi_j)          i.i.d. across (cell, species)             (design stream)
xi_ij        = Lambda_j . u_i + eps_ij
eta_eco_ij   = beta0_j + beta_j * x_i + xi_ij
```

`u` is **i.i.d., not spatially structured**, deliberately: the fitted model assumes i.i.d.
latent scores, so a spatially structured `u` would introduce a *second* misspecification and
make the first unattributable. Single-misspecification principle. Recorded as a limitation and
as the obvious next arm.

The estimand `Sigma = Lambda Lambda' + diag(psi)` lives on this **ecological** linear
predictor. Scoring therefore uses
`extract_Sigma(fit, level = "unit", part = "total", link_residual = "none")` — `link_residual`
would add an observation-scale quantity that was never planted, and `"auto"` is additionally
defective for a trait spanning two families (Phase A §10, `R/extract-sigma.R:134-145`, 1548).

### D3. The environmental covariate

`x_i` is a standardised Gaussian field on the lattice with exponential covariance
`C(h) = exp(-h / phi)`, `phi = 0.15` (roughly seven effective patches per side at unit scale),
mean 0, variance 1. Smooth, because temperature is smooth, and because an i.i.d. `x` could not
correlate with a smooth bias field at any realistic `n`.

Implementation: `L <- chol(C_phi + 1e-8 I)` once per `(n, phi)`, **cached across seeds** —
`C` is `n x n`, and at `n = 1600` a fresh Cholesky per fit would dominate the runtime.

### D4. The bias field — the ladder variable, fully parameterised

For species `j` at cell `i`, the bias entering the **PO rows only**:

```
b_ij = kappa * [ rho * x_i  +  sqrt(1 - rho^2) * ( sqrt(omega) * g_i
                                                 + sqrt(1 - omega) * h_ij ) ]
```

where `g` and `h_.1 ... h_.T` are independent standardised Gaussian fields drawn with the
**same** kernel `C_phi` as `x`, all drawn from a **separate RNG stream** (D8).

This construction gives, exactly and by design:

| quantity | value | meaning |
|---|---|---|
| `Var(b_ij)` | `kappa^2` | bias amplitude, on the log-intensity scale |
| `cor(b_ij, x_i)` | `rho`, for **every** species | environment confounding — the ladder |
| `cor(b_ij, b_ik)`, `j != k` | `rho^2 + (1 - rho^2) * omega` | cross-species bias sharing |
| effective rank | falls as `phi` rises | factor-likeness of the bias |

Note the derived column: **total cross-species sharing is `rho^2 + (1-rho^2)*omega`, not
`omega`** — the `x`-aligned component is shared across species by construction. This must be
carried in the results table as `bias_sharing` and used when interpreting `omega` contrasts.
Do not report `omega` as if it were the sharing.

`kappa` is expressed on the same scale as the ecological latent: `sd(xi_ij)` is
`sqrt(Sigma_jj) ~ 1.05` under the planted values (D7), so **`kappa = 1` means recording bias
of the same magnitude as real ecological signal** — realistic-to-severe; `kappa = 2` is a
declared stress case, not a claim about GBIF.

### D5. Shared vs species-specific bias — both, and why

Per the task and per Tobler et al. 2019, realistic bias is **species-specific** (different taxa
attract different recorder effort) yet **correlated with habitat**, so a purely shared surface
would *understate* the Tobler mechanism. Both are therefore designed as levels of `omega`, and
the prediction is directional rather than agnostic:

- `omega = 1` **shared** — every species over-recorded in the same places. This is exactly a
  rank-1 addition to the site-level linear predictor with a constant loading vector, i.e. a
  spurious factor in its purest form. Expected **largest** `D_bias`.
- `omega = 0.5` **partial** — the reference case, and the closest to Tobler's setting once the
  `rho^2` term is included.
- `omega = 0` **idiosyncratic** — species-specific bias, shared only through the `x`-aligned
  part (`rho^2`). At `rho = 0` this is bias with **zero** cross-species sharing, which should
  inflate the *unique* variances `psi` rather than the common factors. It is the internal
  control that distinguishes "bias corrupts the factors" from "bias corrupts everything."

The `omega = 0, rho = 0` cell is load-bearing: if `D_bias` is large *there*, the mechanism is
not the one claimed and the analysis must be re-derived (see P4, refutation condition R3).

### D6. Observation model, and the `k = 3` decision

```
PO:  eta_po_ij  = log(A_i) + eta_eco_ij + a0_j + b_ij ,   y ~ Poisson(exp(eta_po))
PA:  eta_pa_ij  = log(a)   + eta_eco_ij               ,   y ~ Binomial(k, 1 - exp(-exp(eta_pa)))
```

`a = 1` (log-offset 0) on PA rows, as in Phase A — a legal zero offset on a non-count family
(`R/offset.R:148`), and an *identifying assumption*, not a convenience: the PA arm identifies
`beta0 + log a`, which is what makes `beta0` identified, which is what identifies `a0`. `A_i ~
Uniform(50, 200)` in the same area units, drawn once per seed in the design stream.

> **Decision: `k = 3` repeat visits on the PA rows, not `k = 1`.**
> **Rationale.** `R/fit-multi.R:4976` maps `theta_diag_B` **off** — not floors it — when every
> row of a trait is single-trial Bernoulli. Under `k = 1`, the **PA-only arm (A2)** can
> therefore estimate only `Sigma = Lambda Lambda'` while every other arm estimates
> `Lambda Lambda' + diag(psi)`. That is an **estimand mismatch across arms**, and since arm
> comparison is the entire point, it would silently make A2 incomparable rather than merely
> noisy. `k = 3` is ecologically ordinary (repeat-visit occupancy surveys), leaves the cloglog
> change-of-support exact per visit, and restores one common estimand across all six arms.
> **Rejected alternative:** keep `k = 1` and score A2 against the best rank-`d` correlation
> approximation to `R` as its achievable floor. Rejected as extra machinery that buys a
> comparison nobody would trust.
> **Feasibility is NOT assumed** — gate P0-3 must confirm that a multi-trial binomial is
> expressible through the `attr(family_list, "family_var") <- "source"` route. If it is not,
> the fallback is `k = 1` **plus** the rank-`d` floor for A2 only, recorded as a deviation.
> `k = 1` is in any case run as a documented sensitivity (G5).

### D7. Planted truth — exact values, to be copied verbatim

`T = 8`, `d = 2`, `unique = TRUE`.

```r
LAMBDA <- rbind(                      # 8 x 2, lower-triangular convention on rows 1..d
  sp1 = c( 0.90,  0.00),
  sp2 = c( 0.70,  0.65),
  sp3 = c( 0.55, -0.60),
  sp4 = c(-0.45,  0.70),
  sp5 = c( 0.80,  0.20),
  sp6 = c(-0.65, -0.50),
  sp7 = c( 0.25,  0.75),
  sp8 = c( 0.60, -0.15)
)
PSI   <- c(sp1=0.30, sp2=0.45, sp3=0.35, sp4=0.55, sp5=0.25, sp6=0.50, sp7=0.40, sp8=0.30)
BETA  <- c(sp1=0.80, sp2=0.50, sp3=-0.40, sp4=0.30, sp5=-0.70, sp6=0.60, sp7=0.10, sp8=-0.25)
BETA0 <- rep(-1.2, 8)                 # calibrated once in the pilot, then FROZEN (P0-4)
A0    <- c(-2.8, -3.2, -2.5, -3.0, -3.4, -2.7, -3.1, -2.9)   # PO thinning intercepts, fixed
```

`Lambda` deliberately carries **both signs** in both columns, so the planted `R` contains
strongly positive, near-zero and strongly negative pairs (e.g. `R_13 ~ +0.44`,
`R_34 ~ -0.60`). A design in which every planted correlation is positive would put a ceiling on
the very inflation the campaign is trying to detect, and would be unable to observe sign flips.
This is a **required** property of any substituted `Lambda`.

`BETA0` calibration: the pilot reports pooled realised PA prevalence `mean(p_ij)`. If it falls
outside `[0.25, 0.50]`, `BETA0` is shifted by a single common constant to bring it inside, and
then **frozen before the campaign**. Prevalence matters because Phase A established that the
Bernoulli-cloglog per-observation information is capped
(`I = t^2 e^{-t} / (1 - e^{-t}) <= 0.648`) while the Poisson's is unbounded — so at low
prevalence the PO arm dominates the joint fit and can drag `xi` unopposed. Recording the
realised prevalence per cell is mandatory (`realised_prevalence` column); it is a covariate of
the result, not a constant.

### D8. RNG discipline — common random numbers, non-negotiable

The headline is a **paired** difference against the `kappa = 0` null at the same seed. That
pairing is only exact if the ecological data are bit-identical across `kappa`. Therefore:

1. `set.seed(seed)` → **design stream**, drawn in this fixed order and in this order only:
   `x` field; `u` (n x d); `eps` (n x T); `A` (n); `U_po` (n x T `Uniform(0,1)`);
   `U_pa` (n x T `Uniform(0,1)`).
2. `set.seed(seed + 1e6L)` → **bias stream**: `g` field, then `h_.1 ... h_.T` fields.
   These are drawn **standardised**; `kappa`, `rho`, `omega` are applied afterwards as
   arithmetic. Changing `kappa` therefore does not perturb the ecological data at all.
3. Responses by **inversion**, not by `rpois`/`rbinom`:
   `y_po = qpois(U_po, exp(eta_po))`, `y_pa = qbinom(U_pa, k, p_pa)`.
   Inversion is monotone in the rate, so raising `kappa` shifts the counts up without
   re-randomising them — the paired contrast then isolates the bias, not the draw.
   *Caveat to state in the report*: inversion induces a positive coupling between the null and
   biased datasets. That is the intended variance reduction; unpaired (independent-stream)
   summaries are also reported for the primary endpoint so the pairing cannot be accused of
   manufacturing the effect.

### D9. Data frame schema (long format)

`n * T * 2` rows. Long format is used (not `traits()` wide) because the existing harness is
long and the wide probe (`dev/isdm-wide-format-probe.md`) confirmed the two are equivalent for
this shape — wide buys nothing here.

| column | type | value |
|---|---|---|
| `cell` | factor | `1..n` |
| `trait` | factor | `sp1..spT` |
| `source` | factor | `po` / `pa` |
| `x` | numeric | environmental covariate, replicated over rows of the cell |
| `bstar` | numeric | `b_ij` on PO rows, **0** on PA rows — consumed only by arm A6 |
| `is_po` | numeric | 1 on PO rows, 0 on PA rows |
| `off` | numeric | `log(A_i)` on PO rows, `0` on PA rows |
| `ntrials` | integer | `1` on PO rows, `k` on PA rows |
| `value` | integer | response |

```r
family_list <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(family_list, "family_var") <- "source"
```

---

## E — ESTIMANDS, and what is identified before anything is scored

### E1. The target

```
Sigma = Lambda Lambda' + diag(psi)      (T x T, on the ecological linear predictor)
R     = cov2cor(Sigma)                  (the headline estimand)
```

Secondary estimands: `beta` (T environmental slopes), `psi` (T unique variances),
`Lambda` (up to rotation).

### E2. Identification — stated before scoring, per the measurement discipline

- **Absolute intensity is not identified from presence-only data alone** (Fithian et al. 2015;
  reproduced empirically in Phase A). In arm A1 the intercept estimates `beta0_j + a0_j`, and
  since `a0_j` is species-specific, `beta0_j` is **not** recoverable in A1 at all. **A1's
  intercepts are therefore not scored.** Nothing in the headline depends on them: `R` is a
  property of the latent covariance, not of the intercepts.
- **`Lambda` is identified only up to an orthogonal rotation**, with the package imposing
  lower-triangular + positive diagonal. `R = cov2cor(Lambda Lambda' + diag(psi))` is
  **rotation-invariant**. That invariance is precisely why `R` is the headline and `Lambda` is
  secondary — the headline metric requires no Procrustes step and cannot be corrupted by an
  alignment choice. `Lambda` recovery is reported only after an orthogonal Procrustes fit, and
  is explicitly secondary.
- **`psi` is identified** in every arm given `k = 3` (D6). Under the `k = 1` fallback it is not
  identified in A2, and A2's row must then carry `diag_B_skip > 0` and be reported separately.
- **`beta_j` is identified in every arm.**
- **The bias parameters are not the target.** `a0_j` and the fitted `gamma[d,j]` are nuisance;
  no claim is made about recovering them, and under `kappa > 0` no true value for them exists.

### E3. What "distortion" means, precisely

Over the `m = T(T-1)/2 = 28` unordered pairs:

| symbol | definition | role |
|---|---|---|
| `D_bias` | `mean_{j<k}(R_hat - R)_{jk}` | **PRIMARY.** Signed. Directional prediction: `> 0`. |
| `D_rmse` | `sqrt(mean_{j<k}(R_hat - R)^2_{jk})` | magnitude, sign-blind |
| `D_max`  | `max_{j<k} |R_hat - R|_{jk}` | worst pair |
| `D_z`    | `mean_{j<k}(atanh(R_hat) - atanh(R))_{jk}` | variance-stabilised check on `D_bias` |
| `signflip` | fraction of pairs with `sign(R_hat) != sign(R)` among pairs with `|R| > 0.1` | decision-relevant: would a user draw the wrong ecological conclusion |
| `diag_rmse` | `rmse(diag(Sigma_hat), diag(Sigma))` | is the damage in the variances instead? |
| `psi_rmse` | `rmse(psi_hat, psi)` | distinguishes common-factor from unique-variance contamination |
| `lambda_proc_rmse` | RMSE after orthogonal Procrustes | secondary |
| `beta_bias` | `mean_j(beta_hat_j - beta_j)` | the *other* damage; driven by `rho` |
| `beta_rmse` | `rmse(beta_hat, beta)` | |

**All headline quantities are reported as paired per-seed differences from the `kappa = 0` null
at the same seed**, e.g. `dD_bias(kappa, s) = D_bias(kappa, s) - D_bias(0, s)`. A raw `D_rmse`
is never zero at finite `n`; only the paired difference isolates the bias.

---

## M — METHODS (the arms)

Six arms, all fitted with `trait = "trait"`, `unit = "cell"`, `cluster = "trait"`,
`silent = TRUE`, `d = 2`, `unique = TRUE`.

| id | name | rows | family | formula (RHS after `value ~`) |
|---|---|---|---|---|
| **A1** | PO-only | `source == "po"` | `poisson()` | `0 + trait + trait:x + offset(off) + latent(0 + trait \| cell, d = 2, unique = TRUE)` |
| **A2** | PA-only | `source == "pa"` | `binomial("cloglog")` | `0 + trait + trait:x + latent(0 + trait \| cell, d = 2, unique = TRUE)` |
| **A3** | naive pooled | all | `family_list` | `0 + trait + trait:x + latent(0 + trait \| cell, d = 2, unique = TRUE)` |
| **A4** | integrated, source effects | all | `family_list` | `0 + trait + trait:x + trait:is_po + latent(0 + trait \| cell, d = 2, unique = TRUE)` |
| **A5** | integrated + offsets | all | `family_list` | `0 + trait + trait:x + trait:is_po + offset(off) + latent(0 + trait \| cell, d = 2, unique = TRUE)` |
| **A6** | **oracle bias** | all | `family_list` | `0 + trait + trait:x + trait:is_po + trait:bstar + offset(off) + latent(0 + trait \| cell, d = 2, unique = TRUE)` |

Notes that an implementer must not re-litigate:

- **A3 "naive pooling" still needs two families.** A Poisson count and a binomial cannot share
  a family; the family split by `source` is compulsory arithmetic, not a modelling choice. What
  makes A3 *naive* is the absence of any source-specific intercept **and** the absence of the
  area offset: it pretends both arms observe the same intensity with no thinning and no area.
- **A5 IS the misspecified arm.** It is exactly correct at `kappa = 0` and structurally
  incapable of representing the truth at `kappa > 0`, because `trait:is_po` is a per-species
  **constant** while the truth `b_ij` varies by cell. It needs no extra construction; the
  misspecification is a property of the DGM, not of a special formula.
- **A6 is the attribution control, not a competitor.** `bstar` is 0 on PA rows, so
  `trait:bstar` is automatically PO-only and automatically structure-matched to whatever
  `omega` produced. A6 recovers `R` under any `kappa` if and only if the *only* problem is the
  unmodelled bias field. If A5 and A6 are indistinguishable, the distortion is not attributable
  to bias structure and the premise fails (refutation R2).
- **Arms are compared on RECOVERY ONLY, never on likelihood.** A6 has `T` more free parameters
  than A5; A1/A2 fit different data. Any log-likelihood or AIC comparison across arms is
  meaningless here and is forbidden in the analysis — this is the Phase A gaussian lesson
  (a reported likelihood advantage that was entirely degrees of freedom).
- **Optimiser flags are recorded, never used as a success criterion.** Phase A: `convergence
  == 0` in 99.9% of 24,000 fits including cells where recovery was demonstrably poor.

---

## The grid, in full, with the fit count

Reference configuration (**REF**), used as the anchor of every ladder:
`kappa = 1, rho = 0.6, omega = 0.5, phi = 0.15, n = 400, T = 8, d_fit = 2, k = 3`.

`kappa = 0` collapses `rho`, `omega`, `phi` (there is no field), so it is **one** null config
per `(n, T, d_fit, k)`, shared by every bias setting at that geometry.

| block | varied | levels | bias settings | arms | seeds | fits |
|---|---|---|---|---|---|---|
| **G1 main** | `kappa` x `rho` x `omega` | `kappa in {0, .25, .5, 1, 2}`; `rho in {0, .6}`; `omega in {1, .5, 0}` | `1 + 4*2*3 = 25` | 6 | 100 | **15,000** |
| **G2 n-ladder** | `n in {100, 1600}` | (400 is in G1) | 2 (null, REF) | 6 | 50 | **1,200** |
| **G3 species-ladder** | `T in {6, 12}` | (8 is in G1) | 2 (null, REF) | 6 | 50 | **1,200** |
| **G4 `d_fit` sensitivity** | `d_fit in {1, 3}` | truth stays `d = 2` | 2 (null, REF) | 6 | 50 | **1,200** |
| **G5 `k = 1` sensitivity** | `k = 1` | the `theta_diag_B` map-off case | 2 (null, REF) | 6 | 50 | **600** |
| **G6 smoothness** | `phi in {0, 0.4}` | `0` = i.i.d. bias; effective-rank channel | 1 (REF), reusing G1's null | 6 | 50 | **600** |
| | | | | | **campaign** | **19,800** |
| **P1 pilot** | G1 configs | | 25 | 6 | 10 | **1,500** |
| | | | | | **TOTAL** | **21,300** |

`T in {6, 12}` and not `{4, ...}`: at `d = 2` the free-parameter count is
`df = 0.5[(T-d)^2 - (T+d)]`, giving `T=4 -> -1` (under-identified), `T=5 -> 0` (knife-edge),
`T=6 -> 4`, `T=8 -> 13`, `T=12 -> 41`. `T = 4` is excluded on identification grounds, exactly
as Phase A excluded `T = 2` at `d = 1`. For `T != 8`, `Lambda`, `psi`, `beta`, `A0` are the
first `T` rows of D7 (`T = 6`) or D7 recycled with a fixed jitter-free extension listed in the
harness (`T = 12`); the extension must preserve the both-signs property of D7.

**Compute estimate.** Phase A: 24,000 fits in 6.43 core-hours (~0.96 s/fit) at `T = 6, d = 1`.
Phase C is `T = 8, d = 2` — roughly `4x` the latent dimension work and `1.3x` the rows — so
budget **~5 s/fit at `n = 400`**, giving G1 ~21 core-hours; the `n = 1600` sub-block (600 fits)
at ~60 s/fit adds ~10 core-hours; the rest ~4. **Total ~35 core-hours ~ 2 h wall on 18 cores.**
Run **locally**, consistent with Phase A's recorded deviation. **Decision rule, pre-registered:**
if the pilot's measured mean is `> 10 s/fit` at `n = 400`, the projected total exceeds
60 core-hours and the campaign is routed to **Totoro** (<=150 cores,
`OPENBLAS_NUM_THREADS=1`) instead. Do not decide this by feel after the fact.

---

## P — PERFORMANCE MEASURES

### P1. Estimators and their Monte Carlo standard errors

For each `(block, config, arm)` cell over `S` completed seeds:

| quantity | estimator | MCSE |
|---|---|---|
| mean of any metric `M` | `mean_s M_s` | `sd(M_s)/sqrt(S)` |
| **paired** `dM = M(config,s) - M(null,s)` | `mean_s dM_s` | `sd(dM_s)/sqrt(S)` |
| **paired arm contrast** `M(A_a,s) - M(A_b,s)` | `mean_s` of the difference | `sd/sqrt(S)` |
| sign-flip rate | mean of the per-seed rate | `sd(per-seed rate)/sqrt(S)` |
| curve slope `dD_bias/dkappa` | OLS on per-seed points | model SE, clustered by seed |

**Every reported mean carries its MCSE in the same table cell. A difference smaller than its
MCSE is not a difference and must not be described as one.** Medians of two clouds are
forbidden; all contrasts are paired per seed (D8 makes the pairing exact).

Power check, pre-registered: with `S = 100`, an effect is called at `>= 3 MCSE`, i.e.
`|mean dM| >= 3 sd(dM)/10`. The pilot (`S = 10`) must report `sd(dD_bias)` at REF; if
`3*sd/sqrt(100) > 0.05` (the smallest effect worth naming, §P3), seeds are raised to 200 for G1
(cost `+15,000` fits, total `36,300` — **over budget**, so the alternative is to drop `rho = 0`
from G1, halving the biased configs to `1 + 4*1*3 = 13` and running `S = 200`:
`13*6*200 = 15,600`). Choose in the pilot, record the choice, do not revisit it after seeing
campaign results.

### P2. Failure handling — pre-registered, no post-hoc filtering

- Fits that **throw** are recorded with `fit_error` and excluded; the exclusion rate is reported
  per cell. If any cell exceeds **5%** exclusions the cell is flagged in the results table and
  reported as such, not silently averaged.
- Fits that complete are **never** excluded on `convergence` or `pdHess`. Every headline number
  is reported twice: over all completed fits, and over the `pdHess == TRUE` subset. If the two
  disagree by more than one MCSE, that disagreement is itself a reported finding.
- Boundary/Heywood counts (`n_heywood_psi`, `n_heywood_loading`, thresholds as in
  `dev/isdm-gate-harness.R` lines 268-282) are a **primary outcome**, not a filter — bias
  driving `psi` to the boundary is one of the mechanisms under test.

### P3. Pre-registered criterion for "the correlation matrix is corrupted"

A cell `(arm, kappa, rho, omega)` is declared **CORRUPTED** if either:

- **C1 (magnitude).** `|mean_s dD_bias| >= 0.10` **and** `>= 3 MCSE`. The 0.10 threshold is the
  smallest shift that moves a pair across a conventional interpretive band (e.g. `|r| = 0.15`
  "negligible" to `|r| = 0.25` "weak"), and is stated before any result is seen.
- **C2 (decision).** the sign-flip rate on pairs with `|R| > 0.1` exceeds the `kappa = 0` null
  rate by `>= 0.05` **and** `>= 3 MCSE`.

A corruption is declared **ATTRIBUTABLE to the unmodelled bias structure** only if additionally:

- **C3.** the paired contrast `D_bias(A5) - D_bias(A6)` at the same `(kappa, rho, omega, seed)`
  exceeds `3 MCSE`. Without C3, C1/C2 may be reporting estimator behaviour rather than
  misspecification, and no causal language may be used.

These three thresholds (`0.10`, `0.05`, `3 MCSE`) are frozen by this document. They are not to
be adjusted after seeing results; if they turn out to be badly chosen, that is reported as a
design flaw, not corrected in place. (Phase A precedent: two mid-run corrections were made and
both made the answer *less* favourable; no threshold was ever moved.)

### P4. The single primary endpoint

Because the grid is large, one comparison is nominated as **primary** and everything else is
secondary or exploratory:

> **PRIMARY ENDPOINT:** `mean_s dD_bias` for arm **A1 (PO-only)**, at
> `kappa = 1, rho = 0, omega = 1, phi = 0.15, n = 400, T = 8`, paired against its `kappa = 0`
> null over `S = 100` seeds.

`rho = 0` is chosen for the primary so that the endpoint measures **factor contamination
uncontaminated by slope confounding** — at `rho = 0` the bias is orthogonal to `x`, so anything
that appears in `R` cannot be an artefact of a mis-estimated `beta`. `omega = 1` is chosen
because it is the purest form of the hypothesised mechanism; if the mechanism cannot be
demonstrated there, it will not be demonstrable anywhere.

---

## PRE-REGISTERED PREDICTIONS, and what would refute them

Recorded **before any data is generated.** The hypothesis under test — call it **H_sink** — is
*"unmodelled site-level recording bias is absorbed by the latent factors and re-reported as
residual ecological association."*

### Predictions

1. **P-primary.** At the primary endpoint (P4), `mean_s dD_bias(A1) >= +0.10` at `>= 3 MCSE`.
   The sign is positive: shared over-recording inflates apparent co-occurrence.
2. **P-dose.** `dD_bias` is monotone increasing in `kappa` for A1 and A3 (per-seed Spearman
   `> 0`, and the OLS slope on `kappa` positive at `>= 3 SE`), and first crosses C1 at
   `kappa <= 1`.
3. **P-structure.** `dD_bias(omega=1) > dD_bias(omega=0.5) > dD_bias(omega=0)`, each gap
   `>= 3 MCSE`; and at `omega = 0, rho = 0` the damage appears in `psi_rmse`/`diag_rmse`
   rather than in `dD_bias`.
4. **P-integration.** The integrated arms are **less** corrupted than PO-only at the same
   `kappa`, paired: `dD_bias(A1) - dD_bias(A5) >= 3 MCSE` — because the PA rows give a
   bias-free view of the same `xi` and the joint likelihood resists moving `xi` to fit PO alone.
   **But they are still corrupted**: `A5` itself satisfies C1 at `kappa = 2`. This is the
   prediction I hold with the least confidence, and it is the one with the most interesting
   failure mode: the Bernoulli-cloglog per-observation information is capped at `0.648` while
   the Poisson's is unbounded, so at high intensity the PO arm can outvote the PA anchor
   entirely and `A5` may be no better than `A1`.
5. **P-separation.** `beta_bias` is within `3 MCSE` of zero at `rho = 0` for every `kappa`, and
   grows with `kappa` at `rho = 0.6`. `R` damage and `beta` damage have different drivers.
6. **P-rank.** `dD_bias` at `phi = 0.4` (smooth, low effective rank) exceeds `phi = 0`
   (i.i.d. bias) at matched `kappa` — the only channel in which the word *spatial* is
   load-bearing.

### Refutation conditions — H_sink dies if any of these holds

- **R1 (flat curve).** `|mean_s dD_bias| < 0.05` and within `3 MCSE` of zero for A1 across the
  entire `kappa` ladder up to `kappa = 2` (bias variance four times the ecological latent
  variance), under `omega = 1`. Then the factors do **not** absorb the bias at any strength
  this design can generate, and the mechanism is not real in this model class.
- **R2 (unattributable).** `D_bias(A5) - D_bias(A6)` is within `3 MCSE` of zero at `kappa = 2`.
  Then whatever distortion exists is not caused by the unmodelled bias structure — the oracle,
  which observes the field exactly, is no better — and the campaign's premise fails regardless
  of what the curve looks like.
- **R3 (wrong mechanism).** The corruption is as large at `omega = 0, rho = 0` (zero
  cross-species sharing) as at `omega = 1`. Then it is not a *common-factor* phenomenon and the
  "two species over-recorded in the same places load on a common factor" story is wrong even if
  a number moves; the honest report would be "bias inflates every element of `Sigma`."
- **R4 (diagonal only).** C1 fails while `diag_rmse` and `psi_rmse` rise sharply. Then the bias
  loads on the *unique* variances, not the common factors — `R` survives, and the headline
  claim about the correlation matrix cannot be made.
- **R5 (wrong sign).** `dD_bias` is significantly **negative**. The directional prediction is
  falsified; the finding would still be reportable, but as a different result, and every
  interpretive sentence written in advance would have to be discarded rather than reworded.

Any of R1-R5 is a **publishable negative** and is to be reported as prominently as a positive.
The value of this arm is that it can fail; a design that could only confirm would be Phase A
again.

---

## Implementation contract

### Files to create (none exist yet)

```
dev/isdm-phase-c-harness.R    # sim_phase_c(), fit_arm(), score_phase_c(), run_one(), run_grid()
dev/isdm-phase-c-pilot.R      # P0 gates + P1 pilot (1,500 fits)
dev/isdm-phase-c-campaign.R   # G1..G6 (19,800 fits)
dev/isdm-phase-c-analyse.R    # tables, curves, MCSEs, C1/C2/C3 verdicts
dev/isdm-phase-c-results.rds  # one row per fit
dev/isdm-phase-c-findings.md  # the primary artifact
```

### Reuse (per `dev/isdm-phase-c-reuse-map.md`)

- **Reuse `run_grid()` as-is** from `dev/isdm-gate-harness.R:318-330` — it is a generic
  dispatcher and needs no change.
- **`run_one()` must be rewritten**, not reused: it hard-codes `cfg$cell/n_units/prevalence/
  seed/arm` (harness lines 296-310). Phase C's config has `kappa, rho, omega, phi, n, T, d_fit,
  k, arm, seed, block`.
- **Reuse the scoring utilities** `.rmse()`, the `extract_Sigma(...)` call shape, and the
  Heywood thresholds (harness lines 167-282). **Do not reuse `score_fit()` wholesale**: its
  `lambda_cor`/`comm_*` machinery is `d = 1`, sign-only alignment (campaign lines 43-55) and is
  wrong at `d = 2` — replace with orthogonal Procrustes.
- **Reuse the DGM skeleton** of `dev/isdm-plumbing.R::sim_isdm()` (lines 53-81) for the PO/PA
  row construction, `family_list_joint` (line 83-84) and the `is_po`/`off` column convention.
  Replace `w <- rnorm(n_cell)` (line 57) with the field construction of §D4.
- `T_SP` and `d = 1` are hard-coded in the old harness (lines 43, 149); Phase C's harness must
  take `T` and `d_fit` as arguments from the start.

### Pre-flight gates — run in order, abort on failure, before any campaign

| gate | check | abort condition |
|---|---|---|
| **P0-1** | one REF dataset: `nrow == n*T*2`; `family_id_vec` cross-tabs cleanly against `source`; `diag_B_skip == 0` for A5 | any mismatch |
| **P0-2** | `extract_Sigma(A5)` returns a `T x T` `R` with no `NA` and `max abs(off-diagonal) < 0.999` | degenerate `R` — the headline metric would be vacuous |
| **P0-3** | multi-trial `Binomial(k=3)` expressible through `attr(family_list,"family_var") <- "source"` | fall back to `k = 1`, record the deviation, re-run P0-2 for **A2** specifically |
| **P0-4** | `kappa = 0` null, arm A5, `n = 400`, 10 seeds: `D_rmse < 0.15` and `D_bias` within `3 MCSE` of 0; pooled PA prevalence in `[0.25, 0.50]` | if the correctly specified model cannot recover `R` under the null, the campaign measures nothing — ABORT and report |
| **P0-5** | timing: mean s/fit at `n = 400` | `> 10 s` -> route to Totoro (§grid) |
| **P0-6** | all six arms fit on one REF dataset without error; `A6`'s `trait:bstar` columns appear in `X_fix_names` and are `T` in number | formula does not do what it says |

**Smoke first**: read the first cell's output before launching anything, and abort the instant
it is empty, `NA`, or structurally wrong. This is the rule that paid for itself twice in
Phase A.

### Analysis outputs (fixed in advance)

1. **Figure 1 (headline):** `dD_bias` vs `kappa`, one panel per `omega`, one line per arm,
   MCSE error bars, `rho = 0` and `rho = 0.6` as separate figures.
2. **Table 1:** the primary endpoint with MCSE, both paired and unpaired.
3. **Table 2:** C1/C2/C3 verdict per `(arm, kappa, rho, omega)`.
4. **Table 3:** ladders — `n`, `T`, `d_fit`, `k`, `phi` — each as a paired contrast against REF.
5. **Table 4:** `beta_bias` vs `rho` and `kappa` (the separation claim, P-separation).
6. **Table 5:** flags — `convergence`, `pdHess`, Heywood, exclusion rate — reported, never used.
7. An explicit **"what this does NOT cover"** section: real data, detection probability,
   disjoint units, a fitted spatial field, `d` selection, non-Gaussian latent, and the fact that
   `u` is i.i.d. by design so this campaign says nothing about spatially structured *ecology*.

---

## Known limitations of this design, stated up front

1. **`u` is i.i.d.** Only one misspecification is present, by choice. A spatially structured
   ecological latent — the case where bias and signal are genuinely confounded in space — is
   the obvious next arm and is not covered here.
2. **The bias is additive on the log scale and Gaussian.** Real recorder effort is
   heavy-tailed and clustered around roads and cities; a Gaussian field is a smooth caricature.
   `kappa = 2` is the stress case, not an estimate of GBIF.
3. **`k = 3` PA visits** is a modelling convenience adopted to keep the estimand common across
   arms (D6). It makes the PA arm more informative than a single-visit survey, which if
   anything makes prediction P-integration *easier* to satisfy — so a failure of P-integration
   under `k = 3` is strong, and a success is weaker than it looks. G5 measures the `k = 1` case.
4. **`d_fit` is fixed, not selected.** Real users choose `d`. G4 probes `d_fit in {1,3}` but
   this is not a model-selection study.
5. **The oracle A6 knows the bias field exactly.** It is an attribution instrument and an upper
   bound, not an achievable method.
6. **No claim about `gllvmTMB`'s exported API is licensed by this slice**, and nothing here
   should reach NEWS, README, a vignette, or the validation-debt register.
7. **Before any public claim**: the reference paper's authors are UNSW — Gordana Popović and
   David Warton (Dovers, Popović & Warton 2024, *MEE* 15:191-203, pkg `scampr`) — and Gordana
   is already on the advisory-board invite list.
