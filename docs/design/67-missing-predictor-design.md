# Design 67 -- Missing-PREDICTOR design + drmTMB borrow-map (gllvmTMB lane)

**Status: DESIGN / ANALYSIS ONLY (2026-05-31).** No engine code, no TMB fits.
This document elaborates the gllvmTMB lane for the missing-PREDICTOR phases of
Design 59 (the shared FIML-via-Laplace contract): Phases 2a / 2b / 2c
(continuous Gaussian `mi()`), Phase 3 (phylogenetic `mi()`), and Phase 5
(non-Gaussian / categorical predictors). It is grounded in the drmTMB lane's
ALREADY-IMPLEMENTED predictor handling, which has run ahead of the Design 59
section 7 phase text and is the concrete porting source.

Part of GitHub issue #332 (gllvmTMB missing-data umbrella). Companion to the
Phase 0 audit (`docs/dev-log/after-task/2026-05-31-missing-data-phase0-audit.md`)
and Design 59 (`docs/design/59-missing-data-layer.md`, the authoritative
contract text -- NOT edited here; refinements proposed in section 7 below for
the maintainer to apply).

> **Doc-number note.** The gllvmTMB `docs/design/66-*` slot is already taken by
> the open DRAFT capstone power-study PR (#369). This missing-predictor design
> therefore takes the next free number, **67**, to avoid colliding with an
> in-flight PR. The number is cosmetic; the contract anchor remains Design 59.

---

## 0. Scope, non-goals, and conservative order

**In scope (design only):** the `impute_model(formula, family=)` user surface
for gllvmTMB; the per-predictor-type engine sketch for the stacked-long /
multivariate-`traits()` engine; the drmTMB -> gllvmTMB borrow-map; proposed
(not applied) Design 59 section 7 refinements and a draft #332 ledger comment.

**Explicit non-goals (unchanged from Design 59 section 4):** measurement error
(observed `x` is exact); MNAR/bootstrap-SE/phylo-signal are section 9 verification
gates, not API; no Bayesian path; `engine="laplace"` only (`"em"`/`"profile"`
reserved). No `simulate_imputed()` before MD5/Phase 5.

**Conservative order (binding for this lane), mirroring drmTMB's landed
ladder:**

1. Phase 2a -- one continuous OBSERVATION-level Gaussian `mi(x)`, FIXED
   covariate model. `x_mis` latent + Laplace. (= drmTMB MD3a, `mi_family==0`.)
2. Phase 2b -- obs-level Gaussian `mi(x)` + grouped random intercept
   `x ~ z + (1|group)`. (= drmTMB MD3b.)
3. Phase 2c -- GROUP/SPECIES-level Gaussian `mi(x)` broadcast to long rows
   (level-mismatch index). (= drmTMB MD4 level-mismatch.)
4. Phase 3 -- phylogenetic Gaussian `mi(x)` via `phylo(1|species)` reusing
   `Ainv_phy_rr`. (= drmTMB MD4 structured.)
5. Phase 5 (binary) -- `impute_model(x ~ z, family = binomial())`, exact
   2-state SUM. (= drmTMB `mi_family==1`.)
6. Phase 5 (ordered) -- `impute_model(x ~ z, family = cumulative_logit())`,
   finite-state SUM. (= drmTMB `mi_family==2`.)
7. Phase 5 (unordered) -- `impute_model(x ~ z, family = categorical())`,
   baseline-softmax finite-state SUM. (= drmTMB `mi_family==3`.) **Factors
   last**, per Design 59 section 7 ("factors last").

Each step lands only with its slice issue and its section 9 tests written first
(tests-as-binding-contract). Continuous (Laplace) before discrete (sum); fixed
before grouped before structured; ordered before unordered.

---

## 1. `impute_model(formula, family=)` API for gllvmTMB

### 1.1 The surface (mirrors drmTMB exactly in shape)

The missing-predictor surface is the Design 59 section 4 surface plus a thin
`impute_model()` wrapper that drmTMB has already shipped and exported:

```r
gllvmTMB(
  traits(t1, t2, t3) ~ z + mi(x) + (1 | site),
  data    = d,
  missing = miss_control(predictor = "model"),
  impute  = list(x = impute_model(x ~ z, family = binomial()))
)
```

Key rule, identical to drmTMB: **the family lives in the PREDICTOR model, not
in the response formula.** `mi(x)` marks a covariate as missing; the
`impute = list(x = <impute_model or bare formula>)` entry declares how `x` is
modelled. The response family is whatever `traits()` / the response side
already dispatches (Gaussian, binomial, Poisson, ..., ordinal_probit fid 14).
A missing categorical PREDICTOR and an ordinal RESPONSE trait are independent
dimensions and may co-occur.

A bare two-sided formula in `impute` is sugar for a Gaussian predictor model
(matching drmTMB `drm_standardize_impute_model()`):

```r
impute = list(x = x ~ z)                                   # Gaussian (sugar)
impute = list(x = impute_model(x ~ z))                     # Gaussian (explicit)
impute = list(x = impute_model(x ~ z, family = binomial())) # binary, logit
impute = list(x = impute_model(x ~ z, family = cumulative_logit())) # ordered
impute = list(x = impute_model(x ~ z, family = categorical()))      # unordered
```

The LHS of the `impute` formula must equal the `mi()` variable; the name of
the list element, if present, must also match (drmTMB enforces both in
`drm_validate_single_impute_formula()` -- port the same guards).

### 1.2 Family map (predictor families, NOT response families)

| `impute_model(family=)` | drmTMB `mi_family` | predictor likelihood | integration of missing `x` | reuses gllvmTMB machinery |
|---|---|---|---|---|
| `gaussian()` (default / bare formula) | 0 | `x ~ N(eta_x, sigma_x^2)` | `x_mis` latent, **Laplace** | new `x_mis` param + sparse prior reuse |
| `binomial(link="logit")` | 1 | Bernoulli/logit | **exact 2-state SUM** (no latent) | logit kernel (reuse fid 1 link math) |
| `cumulative_logit()` | 2 | ordered cumulative-logit | **finite-state SUM** over K states | cutpoint reconstruction (mirror fid 14 / ordinal) |
| `categorical()` | 3 | baseline-category softmax | **finite-state SUM** over K states | new softmax block |
| future: multinomial / beta / count / lognormal | -- | per-family | continuous -> Laplace; discrete -> SUM; unbounded-continuous -> Laplace | family-specific later slices |

**Future families decision rule (the split that organises Phase 5+):**
- *Continuous* predictor families (lognormal, Gamma, beta/logit-normal) ->
  Laplace path: a latent `x_mis` (possibly on a transformed/link scale) +
  the family's log-density as the covariate nll. These are extensions of the
  Gaussian Phase-2a machinery, not new in kind.
- *Discrete/finite-support* predictor families (binary, ordered, unordered,
  count-with-small-support) -> finite-state SUM path: NO latent `x_mis`; the
  missing cell is marginalised by summing the response x predictor-prior
  product over the support. Count with unbounded support (Poisson/NB) is the
  awkward case -- it has no finite state set, so it needs either truncation to
  a finite window (a SUM with a documented truncation bound) or a
  continuous-relaxation Laplace approximation; **defer until a slice decides**,
  and do not promise it in v1.

drmTMB validates families in `drm_impute_family_type()` and rejects
unsupported ones with a "needs later family-specific slices" message -- port
the same allow-list + error so gllvmTMB fails loudly, not silently, on an
unimplemented predictor family.

### 1.3 `cumulative_logit()` / `categorical()` provenance

drmTMB exports `cumulative_logit()` (a `drm_family`) and `categorical()` (a
`drm_impute_family`). gllvmTMB already has an ORDINAL RESPONSE family
(`ordinal_probit`, fid 14, Hadfield threshold model) but **no exported
`cumulative_logit()` / `categorical()` constructors**. For the predictor
surface gllvmTMB needs constructors of the same NAME and return-shape as
drmTMB's (the shared-contract "aligned names", section 4b). Two design options:

- (A) Add gllvmTMB `cumulative_logit()` / `categorical()` constructors that
  return predictor-family objects (parallel to drmTMB). Cleanest for the
  shared surface.
- (B) Accept drmTMB-style family tags but document the predictor link choice
  (logit cumulative vs the existing probit threshold response).

Recommend (A) for surface alignment, with an explicit note that the PREDICTOR
ordered family is **cumulative LOGIT** (matching drmTMB), distinct from the
RESPONSE `ordinal_probit`. Keeping the predictor link = logit avoids a silent
probit/logit mismatch with the drmTMB lane and keeps the finite-state SUM math
identical across packages. (If a later slice wants a probit predictor link, it
is a named extension, not the v1 default.)

---

## 2. Engine design per predictor type (stacked-long / multivariate engine)

### 2.0 The one structural fact that drives everything

gllvmTMB's likelihood is **stacked-long**: a single loop
`for (int o = 0; o < y.size(); o++)` with `family_id_vec(o)` dispatch, where
each row `o` is one `(unit, trait)` cell (Phase 0 audit section 4;
`src/gllvmTMB.cpp:1394`). A missing PREDICTOR `x` is a UNIT-level (or
group/species-level) quantity that enters `X_fix` (the `n_obs x p` long design
matrix) **broadcast across all trait rows of that unit**. This is the central
difference from drmTMB, where `mi_col` indexes a single response's design.

Consequence: a single missing `x` value for unit `u` appears in EVERY long row
`o` with `unit(o) == u` -- across all traits. So:
- the Gaussian latent `x_mis(u)` is shared by all of unit `u`'s trait rows
  (one latent per missing unit-value, not per long row);
- the discrete SUM at unit `u` must sum over the WHOLE trait vector of that
  unit jointly, because the same hypothetical `x = k` feeds every trait's eta
  simultaneously. This is the multivariate complication section 2.3 spells out.

drmTMB's `mi_x_full` is length = response rows and `mi_col` is one design
column; gllvmTMB's analogue is a per-UNIT `x_full(u)` mapped to long rows via a
`mi_unit_id(o)` index (the level-mismatch index, already a planned Phase 2c
first-class feature, Design 59 section 7 / audit). Build `mi_unit_id` once; reuse it
for Gaussian and discrete alike.

### 2.1 Gaussian predictor (Phases 2a/2b/2c/3) -- Laplace latent

Direct analogue of drmTMB `mi_family==0` (`src/drmTMB.cpp:760-828`):

- **Parameter:** `PARAMETER_VECTOR(x_mis)`, length = number of missing
  UNIT-level values (NOT long rows). Appended to the TMB `random` set
  (Phase 0 audit section 3 hook: `R/fit-multi.R:~2435`), integrated by
  Laplace.
- **Reconstruction:** `x_full(u) = observed ? x_obs(u) : x_mis(j)`; then for
  each long row `o`, `eta(o) += b_fix(mi_col) * (x_full(mi_unit_id(o)) -
  X_fix(o, mi_col))`. (drmTMB does the same `mu += beta * (x_full - X_mu_col)`
  delta-correction at `src/drmTMB.cpp:804`; the delta form lets the existing
  `X_fix %*% b_fix` term stand and only corrects the missing entries.)
- **Covariate nll:** `x_full(u) ~ N(eta_x(u), sigma_x^2)` summed over UNITS,
  where `eta_x = X_x %*% beta_x` (+ optional grouped/structured intercept).
  This is one Gaussian density block, evaluated at unit level (NOT long).
- **Phase 2b (grouped):** add `sd_x_group * u_x_group(group(u))` to `eta_x` and
  a standard-normal prior on `u_x_group`; `u_x_group` joins `random`. Mirrors
  drmTMB `has_mi_group` (`src/drmTMB.cpp:765-773`).
- **Phase 2c (level-mismatch):** `x` is GROUP/SPECIES-level; one latent per
  group, broadcast to long rows via `mi_unit_id`/`mi_group_id`. Validate one
  observed value per group (Design 59 section 7). drmTMB MD4 is the analogue.
- **Phase 3 (phylo):** covariate prior `x_species ~ N(alpha, sigma_x^2 A)` =
  `GMRF(Q_A)`, `Q_A = A^{-1}`, reusing the EXISTING sparse `Ainv_phy_rr`
  (`src/gllvmTMB.cpp:217`) -- no dense n^2. Mirrors drmTMB `has_mi_struct`
  block (`src/drmTMB.cpp:774-791`), which uses `GMRF(Q_mi_struct)` with a
  sparse precision + log-det. gllvmTMB's `Ainv_phy_rr` + `log_det_A_phy_rr`
  are exactly the inputs that block needs.
- **Identifiability guard:** Level-1 independent covariate field is the
  default; `correlate_with="response"` (eigenvector-orthogonalized) is the
  opt-in Level-2 joint field (Design 59 section 3). For the multivariate engine the
  confounding risk is sharper (the shared phylo field feeds BOTH the covariate
  model and every trait's eta), so the eigenvector guard matters more here than
  in drmTMB -- flag for the Phase 4 identifiability gate.
- **Output:** `imputed()` returns the `x_mis` conditional mode + SE from
  `sdr$diag.cov.random` at the `x_mis` positions (drmTMB
  `drm_imputed_missing_predictor_se`, `R/missing-data.R:2129-2147`). EBLUP
  language only.

**Why Laplace here and not a SUM:** continuous `x` has uncountable support;
the integral over `x_mis` is what Laplace approximates. This is the standard
TMB random-effect path -- `x_mis` is "just another random effect".

### 2.2 Discrete predictor (Phase 5) -- finite-state SUM, NOT a Laplace integral

This is the conceptual crux and the part the task flags. For a discrete
missing predictor with finite support `{1, ..., K}`, drmTMB does **NOT**
declare a latent parameter. Instead it marginalises EXACTLY by summing over
the K states in the RESPONSE likelihood:

```
p(y_o | z) = sum_{k=1..K} p(y_o | x = k, z) * p(x = k | z)
```

In log space, with `logspace_add` for stability (drmTMB binary
`src/drmTMB.cpp:853`; ordinal `:936-940`; categorical `:1016-1020`):

```
nll -= logspace_add_over_states( log p(x=k | z)  +  log p(y_o | x=k, z) )
```

Three drmTMB instances, all the same pattern:
- **Binary** (`mi_family==1`): K=2. `log_p1 = -logspace_add(0, -eta_x)`,
  `log_p0 = -logspace_add(0, eta_x)`; `nll -= logspace_add(log_p1 + log_y1,
  log_p0 + log_y0)` (`src/drmTMB.cpp:840-853`).
- **Ordered** (`mi_family==2`): cutpoints from `theta_ord`
  (`mi_cutpoints(0)=theta_ord(0)`, then `+= exp(theta_ord(j))` --
  log-increment parametrization IDENTICAL to gllvmTMB's ordinal_probit
  `ordinal_log_increments`, `src/gllvmTMB.cpp:1569-1570`); per-state
  `log_prob` via `log_inv_logit` / `log1m_inv_logit` /
  `log_inv_logit_diff`; sum over states (`src/drmTMB.cpp:864-940`).
- **Unordered** (`mi_family==3`): baseline-category softmax,
  `eta_state(0)=0`, `eta_state(k) = X_x %*% beta_x[block k]`; log-prior =
  `eta_state(k) - logsumexp(eta_state)`; sum over states
  (`src/drmTMB.cpp:966-1042`).

**Critical engine consequence -- the response likelihood for a
missing-predictor row is REPLACED, not added to.** In drmTMB the ordinary
Gaussian response term is gated OFF for discrete-missing rows:

```cpp
// src/drmTMB.cpp:1163-1170
if (observed_y(i) == 1 &&
    !(has_mi == 1 && mi_family != 0 && mi_observed(i) == 0)) {
  nll -= weights(i) * dnorm(y(i), mu(i), obs_sigma(i), true);
}
```

because the per-state `dnorm(y | x=k)` is ALREADY folded into the
`logspace_add` mixture term. gllvmTMB MUST replicate this gate in its
stacked-long loop: for a row `o` whose unit has a missing discrete predictor,
the family-dispatch block (`src/gllvmTMB.cpp:1394-1588`) must NOT also add its
ordinary `nll -=` term -- the mixture term already accounts for `y_o`.

**State-design matrix.** For each hypothetical state `k`, the response eta
needs `x` set to `k`. drmTMB precomputes `X_mi_state_mu`, a stacked
`(n * n_state) x p` matrix: row `i*n_state + state` is `model.matrix` with the
predictor column forced to category `k`
(`drm_missing_predictor_state_design`, `R/missing-data.R:1567-1607`). The
response eta for state `k` is then `mu(i) - fixed_mu(i) + state_fixed_mu`
(swap the predictor's fixed contribution). gllvmTMB needs the long analogue:
`X_fix_state`, a `(n_obs * n_state) x p` stacked matrix, with the broadcast
`mi_col` set to each `k`. Memory note: `n_obs` is already long (units x
traits); times `n_state` this is large but still O(n_obs * K * p) sparse-ish;
fine for v1 small-K factors, flag for a memory check on big K.

### 2.3 How the discrete SUM interacts with the MULTIVARIATE response

This is the genuinely new gllvmTMB problem with no drmTMB precedent
(drmTMB is uni-/bivariate; gllvmTMB is fully multivariate via `traits()` +
latent axes + trait covariance).

For unit `u` with a missing discrete predictor, the SAME hypothetical `x = k`
feeds the eta of EVERY trait row of `u`. Two sub-cases:

- **(i) Conditionally-independent traits given the latent structure.** If, GIVEN
  the latent axes / random effects, the trait cells of unit `u` are independent
  (the standard gLLVM conditional-independence assumption -- responses are
  independent given `eta`), then the joint response density factorises:
  `p(y_{u,.} | x=k, latent) = prod_t p(y_{u,t} | x=k, latent)`. So the
  per-unit mixture is:
  ```
  p(y_{u,.} | latent) = sum_k  p(x=k | z_u) * prod_t p(y_{u,t} | x=k, latent)
  ```
  i.e. sum over K of (predictor-prior x PRODUCT of per-trait densities). In log
  space: `logspace_add_over_k( log p(x=k|z) + sum_t log p(y_{u,t}|x=k) )`.
  This is a per-UNIT mixture, evaluated by accumulating each trait row's
  `log p(y_{u,t}|x=k)` into a per-unit, per-state accumulator, THEN
  `logspace_add` over states once per unit. The loop must therefore group long
  rows by unit (the `mi_unit_id` index again) -- a per-row independent SUM is
  WRONG because it would treat each trait as its own separate mixture and
  double-count the predictor prior.

- **(ii) Latent axes / random effects integrated by Laplace.** The latent axes
  `b`, phylo fields, etc. are ALSO integrated out (Laplace). The clean and
  correct ordering is: condition on the latent modes inside the inner Laplace
  problem, do the FINITE-STATE SUM over `k` analytically at each inner
  evaluation (the SUM is exact, cheap, and differentiable), and let the OUTER
  Laplace integrate the continuous latent. I.e. the discrete `x` is summed
  EXACTLY *inside* the integrand; only the continuous latent is Laplace-
  approximated. This is consistent with drmTMB, where the SUM happens at every
  `nll` evaluation while the continuous random effects (if any) are Laplace-
  integrated around it. **Do NOT** try to make discrete `x` a Laplace latent --
  that is the error this whole section guards against.

**Practical engine shape for the multivariate discrete SUM:**
1. Build per-state response contributions for all long rows
   (`X_fix_state`, family-dispatch per state -- the existing per-family kernels
   work unchanged, just evaluated with the state-substituted eta).
2. Accumulate `log p(y_{u,t} | x=k)` into `acc(u, k)` over trait rows of `u`.
3. Add `log p(x=k | z_u)` (predictor prior) to `acc(u, k)`.
4. `nll -= logspace_add_over_k( acc(u, .) )` once per unit `u`.
5. Gate OFF the ordinary per-row response term for these rows (the section 2.2 gate).
6. Report posterior state weights `p(x=k | y_u)` and the EBLUP-style expected
   score / modal category (drmTMB `mi_state_probability` + `expected_score`,
   `src/drmTMB.cpp:941-955`).

**Weak-identifiability tie-in (Design 59 section 9).** In the multivariate case the
predictor prior `p(x=k|z)` is informed by the OBSERVED `x` values, and the
response-side evidence for the missing `x` is the WHOLE trait vector of the
unit. If few units have observed `x`, or the traits are weakly associated with
`x`, the SUM is dominated by the prior and the imputation is unreliable -- the
same family of cautions as the section 9 weak-identifiability warning. Surface a
count of observed-vs-missing predictor values and (optionally) a warning when
the response provides little discrimination among states.

### 2.4 Family-machinery interaction summary

- The discrete SUM reuses the EXISTING per-family kernels (Gaussian, binomial,
  Poisson, ..., ordinal_probit) unchanged -- it only changes WHICH eta they are
  evaluated at (state-substituted) and that their contribution is summed inside
  a `logspace_add` rather than added directly. No new response family is
  introduced by missing predictors.
- The Gaussian latent path reuses the existing `random`/`MakeADFun`/Laplace
  plumbing and the sparse `Ainv_phy_rr` prior plumbing -- no new integrator.
- ordinal_probit (fid 14) is a RESPONSE family and is orthogonal to a missing
  ordered PREDICTOR (cumulative_logit). They share only the log-increment
  cutpoint parametrization, which is a reuse opportunity (port the
  reconstruction loop), not a semantic link.

---

## 3. Borrow-map: drmTMB -> gllvmTMB

Legend: **PORT** = lift with minimal change; **ADAPT** = same idea, real
rework for stacked-long/multivariate; **NEW** = no drmTMB precedent.

### 3.1 R surface / parsing

| drmTMB function (`R/missing-data.R`) | gllvmTMB equivalent | port? | difference |
|---|---|---|---|
| `miss_control(response,predictor,engine)` | reuse near-verbatim | PORT | already in Design 59 section 4 surface; gllvmTMB adds nothing |
| `impute_model(formula, family=)` | same name + return shape | PORT | trivial; the wrapper is package-agnostic |
| `categorical()` / `cumulative_logit()` constructors | add gllvmTMB constructors | PORT (add) | gllvmTMB lacks exported predictor-family constructors (section 1.3) |
| `drm_impute_family_type()` allow-list + errors | port allow-list | PORT | same families; same loud-failure on unsupported |
| `drm_standardize_impute_model()` | port | PORT | bare-formula -> Gaussian sugar |
| `drm_find_mi_calls()` / `mi()` token | reuse gllvmTMB parser slot | ADAPT | gllvmTMB parser is multi-formula (`R/parse-multi-formula.R`); `mi()` must be detected in `traits()`/per-trait formulas. Boole confirms the slot (Design 59 section 8) |
| `drm_validate_single_impute_formula()` (LHS=var, name match, no nested mi, no `.`) | port guards | PORT | identical validation logic |
| `drm_prepare_gaussian_mi_setup()` | ADAPT | ADAPT | gllvmTMB intercepts at `R/fit-multi.R:937` (audit section 2), not drmTMB's per-parameter model.frame |
| `drm_validate_ordinal_missing_predictor()` (>=3 levels) | port | PORT | same finite-state validation |
| `drm_extract_impute_structured_intercept()` (`phylo/spatial/animal/relmat`) | ADAPT to gllvmTMB markers | ADAPT | reuse gllvmTMB's own structured tokens; gllvmTMB has richer phylo/spatial grammar |

### 3.2 R model-build

| drmTMB function | gllvmTMB equivalent | port? | difference |
|---|---|---|---|
| `drm_build_gaussian_missing_predictor_model()` | `gll_build_gaussian_mi_model()` | ADAPT | builds per-UNIT `x_full`, `mi_unit_id` (long->unit map); drmTMB builds per-response-row |
| `drm_build_gaussian_mi_random_intercept()` (2b) | ADAPT | ADAPT | group at unit level; mirror `has_mi_group` |
| `drm_build_gaussian_mi_structured_intercept()` (phylo via `build_structured_mu_structure`) | reuse gllvmTMB phylo builder | ADAPT | gllvmTMB already builds `Ainv_phy_rr`; point the covariate prior at it |
| `drm_build_bernoulli_missing_predictor_model()` | `gll_build_binary_mi_model()` | ADAPT | 2-state; needs `X_fix_state` long stacking |
| `drm_build_ordinal_missing_predictor_model()` | `gll_build_ordered_mi_model()` | ADAPT | K-state; cutpoint starts |
| `drm_build_categorical_missing_predictor_model()` | `gll_build_unordered_mi_model()` | ADAPT | K-state softmax; baseline level |
| `drm_missing_predictor_state_design()` -> `X_mi_state_mu` ((n*K) x p) | `gll_mi_state_design()` -> `X_fix_state` ((n_obs*K) x p) | ADAPT | the BIG structural port: stacked over LONG rows x states, not response rows x states. section 2.2 memory caveat |
| `drm_missing_predictor_metadata()` | `gll_mi_metadata()` | PORT | populates `fit$missing_data$predictors` registry (shared-contract slot, Design 59 section 4b) |
| `drm_empty_missing_predictor_model()` | port shape | PORT | no-op default keeps non-mi fits unchanged |
| `drm_tmb_missing_predictor_data()` | `gll_tmb_mi_data()` | ADAPT | packs `tmb_data` slots; names differ (gllvmTMB long) |

### 3.3 C++ likelihood (`src/drmTMB.cpp` -> `src/gllvmTMB.cpp`)

| drmTMB C++ block | gllvmTMB equivalent | port? | difference |
|---|---|---|---|
| `DATA`/`PARAMETER` mi slots (`mi_family`, `mi_col`, `mi_x`, `mi_observed`, `mi_missing_index`, `X_mi`, `mi_n_state`, `X_mi_state_mu`, `x_miss`, `beta_mi`, `theta_ord`) | add gllvmTMB analogues + `mi_unit_id` | ADAPT | add the long->unit index `mi_unit_id`; `X_mi_state_mu`->`X_fix_state` |
| `mi_family==0` Gaussian latent (`:760-828`) | gllvmTMB Gaussian block | ADAPT | `x_full` per unit; `eta(o) += b_fix(mi_col)*(x_full(mi_unit_id(o)) - X_fix(o,mi_col))`; sum covariate nll over UNITS |
| `has_mi_group` (`:765-773`) | port | PORT | standard-normal grouped intercept |
| `has_mi_struct` GMRF(Q) (`:774-791`) | point at `Ainv_phy_rr` | ADAPT | reuse existing sparse phylo precision + log-det |
| `mi_family==1` binary 2-state SUM (`:830-862`) | gllvmTMB binary SUM | ADAPT | per-UNIT mixture over trait rows (section 2.3), not per-row |
| `mi_family==2` ordered K-state SUM (`:864-964`) | gllvmTMB ordered SUM | ADAPT | per-UNIT; reuse fid-14 cutpoint reconstruction |
| `mi_family==3` unordered K-state SUM (`:966-1042`) | gllvmTMB softmax SUM | ADAPT | per-UNIT; baseline category |
| ordinary-response gate for discrete-missing rows (`:1163-1170`) | replicate in long loop | ADAPT (CRITICAL) | gate each family-dispatch block (`:1394-1588`) so discrete-missing rows don't double-count `y` |
| `mi_x_full`/`mi_state_probability`/`expected_score` REPORT | port REPORT/ADREPORT | PORT | EBLUP outputs + state posteriors |

### 3.4 Extractors / output

| drmTMB | gllvmTMB | port? | difference |
|---|---|---|---|
| `imputed()` generic + `imputed.drmTMB` (`R/missing-data.R:2034-2127`) | `imputed.gllvmTMB` | PORT | same return frame (`variable, original_row, model_row, observed, estimate, std_error, source, uncertainty_status`) |
| `drm_imputed_missing_predictor_se()` (Gaussian: `sdr$diag.cov.random` at `x_miss`; discrete: NA) | port | PORT | identical SE logic; discrete -> NA SE in v1 |
| -- (drmTMB has no trait split) | add `imputed_predictors()` / `imputed_traits()` | NEW | Design 59 section 4 names a gllvmTMB-specific split (missing trait CELLS vs missing covariates) |
| `predict_missing()` (responses) | gllvmTMB Phase 1 (already scoped, audit section "Phase 1 hook 6") | -- | separate from predictors; not in this doc's scope |

### 3.5 Concrete Phase-2a porting targets (do FIRST)

The minimum viable joint model (one continuous obs-level Gaussian `mi(x)`,
fixed covariate model) is the smallest correct slice. Port these, in order:

1. R surface: `miss_control()` reuse + `impute_model()` + `drm_standardize_impute_model()` + `drm_validate_single_impute_formula()` guards (PORT, package-agnostic).
2. `mi()` detection in the gllvmTMB multi-formula parser slot (ADAPT; Boole confirms).
3. `gll_build_gaussian_mi_model()` from `drm_build_gaussian_missing_predictor_model()` Gaussian branch only -- build `x_obs`, `missing_index`, `mi_unit_id`, `X_x`, `beta_x` start, `sigma_x` start (ADAPT for unit-level).
4. C++: add the mi DATA/PARAMETER slots + the `mi_family==0` block, ported from `src/drmTMB.cpp:760-828`, with the `mi_unit_id` broadcast (ADAPT).
5. `random` append + `MakeADFun` (audit section 3 hooks `:2435`, `:2456`).
6. `imputed.gllvmTMB` + `drm_imputed_missing_predictor_se()` (PORT).
7. `fit$missing_data$predictors` registry via `gll_mi_metadata()` (PORT shape).

section 9 tests written FIRST: recovery sim (recover `beta`, `beta_x`, and the
missing `x` EBLUP within band + SE coverage); no-op (no `mi()` -> fit
unchanged); deterministic-ish match against a complete-case fit on a
fully-observed sibling dataset.

---

## 4. Key API + engine decisions (summary for reviewers)

1. **Family lives in the predictor model** (`impute_model(family=)`), never in
   the response formula. Bare formula = Gaussian sugar. Mirror drmTMB exactly.
2. **Two integration regimes, decided by predictor support:** continuous ->
   `x_mis` latent + Laplace; discrete/finite -> exact finite-state SUM (NO
   latent). The SUM is a finite MIXTURE in the RESPONSE likelihood, summed
   EXACTLY inside the integrand; only continuous quantities are Laplace-
   approximated.
3. **The discrete SUM REPLACES the ordinary per-row response term** for
   missing-predictor rows (drmTMB gate `src/drmTMB.cpp:1163-1170`); gllvmTMB
   must replicate this gate in its stacked-long family loop or it double-counts
   `y`.
4. **Multivariate twist (NEW vs drmTMB):** the per-unit discrete mixture must
   sum over states of the PRODUCT of the unit's per-trait densities, grouped by
   a `mi_unit_id` index -- a per-row SUM is wrong.
5. **Reuse, don't reinvent:** `Ainv_phy_rr` (Phase 3 covariate prior), the
   ordinal log-increment cutpoint reconstruction (ordered predictor), the
   existing per-family kernels (state-substituted eta), the `random`/Laplace
   plumbing.
6. **Conservative order:** Gaussian fixed (2a) -> grouped (2b) -> level-mismatch
   (2c) -> phylo (3) -> binary -> ordered -> unordered (5). Continuous before
   discrete; ordered before unordered; factors last. Each slice TDD with section 9
   tests first.
7. **Doc number 67** (66 taken by open PR #369).

---

## 5. Open questions for the maintainer

1. **Constructor names (section 1.3):** add gllvmTMB `cumulative_logit()` /
   `categorical()` predictor-family constructors (option A) vs accept drmTMB's?
   Recommend A for surface alignment; confirm the predictor ordered link is
   LOGIT (matching drmTMB), distinct from the probit `ordinal_probit` response.
2. **`X_fix_state` memory (section 2.2):** `(n_obs * K) x p` is large when n_obs (long)
   and K are big. Acceptable for small-K factors in v1; needs a guard/limit on
   K and possibly an on-the-fly state-eta computation (avoid materialising the
   full stacked matrix) for big factors. Defer the optimisation; cap K in v1.
3. **`correlate_with="response"` in multivariate (section 2.1):** confounding is
   sharper here than in drmTMB (shared field feeds covariate model + every
   trait). Confirm the eigenvector-orthogonalized Level-2 field is deferred to
   Phase 4 (Design 59 section 10 open decision 3) and that Phase 3 ships Level-1
   independent only.
4. **Count predictors (section 1.2):** Poisson/NB have no finite support. Confirm they
   are NOT promised in v1; a slice later decides truncated-SUM vs continuous
   relaxation.

---

## 6. Verification mapping (the section 9 gates, per phase)

| Phase | Gate (Design 59 section 9) |
|---|---|
| 2a | recovery sim (`beta`, `beta_x`, `x` EBLUP + SE coverage); no-op; complete-case match |
| 2b | recovery with grouped covariate intercept; `b_x` independent of response RE |
| 2c | level-mismatch: one observed value per group; broadcast correctness |
| 3 | phylo recovery: high vs low signal -> borrowing helps when strong, degrades to ~independent when weak (Penone/Johnson/Molina-Venegas); phylo-signal gate flags weak |
| 5 binary | 2-state SUM matches an independent brute-force marginalisation; expected-probability EBLUP recovery |
| 5 ordered | K-state SUM matches brute force; expected-score recovery; >=3-level guard |
| 5 unordered | K-state softmax SUM matches brute force; modal-category recovery; baseline-level invariance |
| all | sentinel/no-op non-regression; weak-identifiability warning when observed `x` or response discrimination is thin (section 2.3) |

A shared cross-package check: for the SAME small dataset and a single missing
predictor, gllvmTMB-with-one-trait and drmTMB-univariate should agree on the
imputed value and `beta_x` (collapses the multivariate engine to the drmTMB
case) -- a strong contract test that the borrow is faithful.

---

## 7. PROPOSED EDITS (NOT APPLIED -- for maintainer/me to review and apply)

> These are drafts. Design 59 is the authoritative contract and is NOT edited
> by this doc. #332 is NOT posted to by this agent. Apply manually after review.

### 7.1 Proposed Design 59 section 7 refinements (Phases 2a -> 5)

The drmTMB lane has IMPLEMENTED more than the section 7 phase text describes (binary,
ordered, AND unordered finite-state predictors, plus the `impute_model()`
surface). Proposed edits to keep the shared contract in sync:

- **section 4 surface line** -- add `impute_model()` to the named surface:
  > "...plus the **`mi(x)`** formula token, `impute = list(x = x ~ model)`,
  > and the **`impute_model(formula, family=)`** wrapper (bare formula =
  > Gaussian; `family=` selects the predictor model: `gaussian()` Laplace
  > latent, `binomial(link="logit")` exact 2-state sum, `cumulative_logit()`
  > and `categorical()` finite-state sum). The predictor family lives in the
  > predictor model, never in the response formula."

- **section 4 output line** -- note discrete EBLUP semantics:
  > "Discrete missing predictors report fitted conditional state probabilities
  > / expected scores / modal category (NOT latent modes); `std_error` is `NA`
  > for finite-state routes in v1."

- **section 7 Phase 5** -- replace the one-line "non-Gaussian / bounded / categorical"
  bullet with the split + order:
  > "**Phase 5 -- non-Gaussian / bounded / categorical predictors.** Two
  > integration regimes by support: *continuous* families (lognormal, Gamma,
  > beta/logit-normal) extend the Phase-2a Laplace-latent path; *discrete /
  > finite-support* families (binary, ordered, unordered) use an EXACT
  > finite-state SUM `p(y|z)=sum_k p(y|x=k,z)p(x=k|z)` -- a finite mixture in
  > the response likelihood, NOT a Laplace integral, that REPLACES the ordinary
  > per-row response term for missing-predictor rows. Conservative order within
  > Phase 5: binary -> ordered (cumulative_logit) -> unordered (categorical);
  > **factors last**. Count predictors (Poisson/NB) have no finite support and
  > are deferred (truncated-SUM vs continuous-relaxation TBD by a later slice).
  > In gllvmTMB the SUM is per-UNIT over the product of the unit's per-trait
  > densities (the multivariate twist; see gllvmTMB Design 67 section 2.3)."

- **section 7 Phase 2a/2b/2c** -- add the `mi_unit_id` level-mismatch index as the
  shared mechanism (it is reused by Phase 5 discrete too):
  > "The level-mismatch index (`mi_unit_id`: long-row -> missing-unit/group map)
  > is built once in Phase 2a and reused by 2b/2c AND by the Phase 5 discrete
  > per-unit SUM."

- **section 5 gllvmTMB glue** -- add the discrete-row response gate hook:
  > "For discrete missing predictors, the per-family blocks
  > (`src/gllvmTMB.cpp:1394-1588`) must be gated so a discrete-missing row does
  > NOT add its ordinary `nll` term (the per-state density is folded into the
  > mixture sum) -- mirror drmTMB `src/drmTMB.cpp:1163-1170`."

### 7.2 Draft #332 ledger comment (DO NOT POST -- for maintainer review)

```
gllvmTMB missing-PREDICTOR lane -- design alignment with drmTMB (Design 67)

Posting to align the shared contract now that the drmTMB lane has IMPLEMENTED
the predictor routes ahead of the Design 59 section 7 phase text.

API alignment (both lanes):
- impute_model(formula, family=) is the predictor-model surface. The family
  lives in the PREDICTOR model, never in the response formula. Bare formula =
  Gaussian sugar. drmTMB exports impute_model() + cumulative_logit() +
  categorical(); gllvmTMB will add matching constructors (aligned names, not
  identical signatures -- shared-contract Section 4b).
- Family map: gaussian() = Laplace latent; binomial(link="logit") = exact
  2-state sum; cumulative_logit() = ordered finite-state sum; categorical() =
  unordered baseline-softmax finite-state sum. Discrete routes report
  conditional probabilities / expected scores (NA SE in v1); Gaussian reports
  conditional mode + likelihood SE.

Engine alignment:
- Continuous predictors -> latent x_mis + Laplace. Discrete predictors -> EXACT
  finite-state SUM (no latent); a finite mixture in the response likelihood
  that REPLACES the ordinary per-row response term for missing-predictor rows
  (drmTMB gate src/drmTMB.cpp:1163-1170). gllvmTMB replicates this in its
  stacked-long family loop.
- gllvmTMB multivariate twist: the per-unit discrete SUM is over the PRODUCT of
  the unit's per-trait densities (grouped by a mi_unit_id index), not per-row.

Conservative order (gllvmTMB lane, matching drmTMB's landed ladder):
  Phase 2a Gaussian fixed -> 2b grouped -> 2c level-mismatch -> 3 phylo
  (Ainv reuse) -> 5 binary -> 5 ordered -> 5 unordered. Factors last.
  Continuous before discrete; ordered before unordered. Each slice TDD with the
  Section 9 gates written first (tests-as-binding-contract).

Cross-package contract test proposed: gllvmTMB-with-one-trait == drmTMB-
univariate on the same single-missing-predictor dataset (imputed value +
beta_x agree) -- collapses the multivariate engine to the drmTMB case.

Full design: gllvmTMB docs/design/67-missing-predictor-design.md (#332).
(Doc number 67, not 66 -- 66 is taken by the open capstone power-study PR
#369.)
```
