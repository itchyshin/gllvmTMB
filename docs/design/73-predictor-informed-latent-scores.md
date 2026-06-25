# Design 73 -- Predictor-Informed Latent Scores

**Status:** C1 ordinary unit-tier parser + TMB support for Gaussian and
pure binomial-probit fits; Gaussian recovery and interval calibration
still pending.
**Maintained by:** Boole (formula grammar), Gauss (TMB implementation),
Noether (math contract), Emmy (extractor contract), Curie (simulation
tests), Fisher (identifiability and inference), Rose (scope audit).
**Validation rows:** `FG-18`, `RE-13`, `EXT-31`, `LV-01` through
`LV-07` in `docs/design/35-validation-debt-register.md`.

This design adds an `lv = ~ ...` argument to ordinary `latent()` terms.
The argument is a term-local fixed-effect formula for the mean of the
latent scores. It is not a random-effects formula, not a loading model,
and not a replacement for trait-specific fixed effects. The current
implementation admits only the C1 ordinary unit-tier surface: Gaussian
fits plus a narrow pure binomial-probit admission. All other rows remain
planned or blocked as listed below.

The first public target remains ordinary Gaussian unit-tier support:

```r
latent(1 | unit, d = 2, lv = ~ reporting_quality + policy_used)
```

The equivalent long-form target is:

```r
latent(0 + trait | unit, d = 2,
       lv = ~ reporting_quality + policy_used)
```

The first admitted binary target is deliberately narrower:
single-family `binomial(link = "probit")` with the same ordinary
unit-tier score-mean model. Binary logit, cloglog, ordinal, count,
Gamma, Beta, mixed-family, and delta/hurdle `lv` fits remain blocked
until their own validation rows move.

## Model Contract

For ordinary unit-tier `latent()`, the score-mean contract is:

$$
\eta_{it} =
X_{it}\beta + \lambda_t^\top z_i + q_{it},
$$

$$
z_i = M_i\alpha + e_i,\qquad e_i \sim N(0, I_K),
$$

$$
\Sigma_\text{unit} = \Lambda\Lambda^\top + \Psi,
$$

$$
B_\text{lv} = \Lambda\alpha^\top.
$$

Here `M_i` is the unit-level model matrix built from the `lv` formula,
`alpha` is the predictor-to-axis coefficient matrix, `e_i` is the
latent-score innovation, and `q_it` is the diagonal `Psi` companion
already supplied by ordinary `latent()`. Gaussian responses use the
identity-link Gaussian observation likelihood. The first binary
admission uses the same linear predictor inside the probit likelihood,
`y_it ~ Binomial(n_it, Phi(eta_it))`.

Use **innovation** for `e_i` in user prose. Do not call it the
"residual" score, because `unique = FALSE` already means "drop the
diagonal `Psi` companion" in the surrounding
`latent()` vocabulary. A future mean-only model

$$
z_i = M_i\alpha
$$

with no innovation is a separate reduced-rank fixed-effect or
constrained-ordination mode. It must not be hidden inside the ordinary
`latent()` argument.

## Prior Art And Positioning

This feature is not a novelty claim for latent-variable regression.
It is a `gllvmTMB` grammar and TMB implementation of a known idea:
predictors inform the latent axes while unmeasured variation remains in
the latent-score innovation.

The closest R-package precedent is `gllvm`: its
[reference page](https://jenniniku.github.io/gllvm/reference/gllvm.html)
exposes `num.lv.c`, `num.RR`, and `lv.formula`, with `num.lv.c`
described as latent variables informed by predictors with a residual
term and `num.RR` as constrained latent variables without that residual
term. The
[`gllvm` ordination-with-predictors vignette](https://jenniniku.github.io/gllvm/articles/vignette6.html)
also distinguishes concurrent ordination, constrained ordination, and
partial versions where the ordinary predictor formula and `lv.formula`
cannot include the same variables. This design follows the same
conceptual split but uses `gllvmTMB`'s term-local stacked-trait grammar.

The SEM/MIMIC language is also relevant: a latent variable can be
regressed on observed covariates while still measured through loadings.
[`lavaan`](https://lavaan.ugent.be/tutorial/syntax1.html) supplies the
broad syntax precedent for separating measurement relations from
regressions. Other packages such as
[`boral`](https://rdrr.io/cran/boral/man/boral.html), Hmsc, `MCMCglmm`,
`brms`, and GALAMM are comparison points for ordination, row effects,
and latent-variable modelling, not evidence that this specific
`gllvmTMB` surface is implemented.

## Non-Negotiable Decisions

- C1 supports **ordinary unit-tier Gaussian and pure binomial-probit
  `latent()` only**.
- `lv` accepts a one-sided fixed-effect formula only.
- Random-effect bars, offsets, `mi()`, smooth terms, and response or
  trait columns inside `lv` are rejected.
- `lv = ~ x` is accepted, but the intercept is dropped internally.
  The parser records a fit note and tests equivalence to
  `lv = ~ 0 + x`.
- Predictors in `lv` must be constant within the grouping level of the
  outer `latent()` term. The parser errors rather than averaging.
- Exact fixed-effect overlap is rejected in C1: if `x` appears in
  `lv = ~ x`, the same expanded predictor cannot also appear in the
  ordinary fixed-effect RHS.
- `REML = TRUE` with `lv` is rejected. REML / AI-REML language remains
  Gaussian-only and needs a separate derivation even for this Gaussian
  C1 surface.
- Other non-Gaussian families and binary logit/cloglog `lv` fits are
  rejected until their own validation rows move.
- C1 supports at most one ordinary unit-tier `latent()` term carrying
  `lv`.
- `extract_Sigma()` keeps its current meaning:
  `Lambda Lambda^T + Psi` for the model's conditional unit-tier
  covariance. It does not add empirical variance induced by the
  observed `lv` predictors.
- The primary public estimand is `B_lv = Lambda %*% t(alpha)`, not raw
  `alpha`, because `alpha` depends on the latent-axis convention.

## Tier Grammar

The metadata should be designed for future tier-local `lv` formulas,
but C1 exposes only ordinary unit-tier support.

| Tier / source | Eventual target | C1 behaviour |
|---|---|---|
| `latent(... | unit, lv = ~ x_unit)` | Between-unit latent-score mean | C1 partial: ordinary Gaussian plus pure binomial-probit; smoke/algebra evidence and binary-probit `B_lv` recovery, not interval calibration |
| `latent(... | unit_obs, lv = ~ x_obs)` | Within-unit/session latent-score mean | Reject as planned |
| `latent(... | cluster, lv = ~ x_cluster)` | Cluster latent-score mean if a reduced-rank cluster slot is added | Reject as planned |
| `latent(... | cluster2, lv = ~ x_cluster2)` | Not valid today; `cluster2` is diagonal-only | Reject |
| `phylo_latent(..., lv = ~ x)` | Species score mean with phylogenetic innovation | Reject as planned |
| `animal_latent(..., lv = ~ x)` | Individual/pedigree score mean | Reject as planned |
| `spatial_latent(..., lv = ~ x)` | Site or mesh score mean | Reject until the site-vs-mesh target is derived |
| `kernel_latent(..., lv = ~ x)` | Dense-kernel score mean | Reject until single-kernel equivalence gates land |

Each future tier needs its own `M_h`, `alpha_h`, `Lambda_h`, `Psi_h`,
and innovation `e_h`. Tiers remain independent unless a later design
adds cross-tier covariance with simulation evidence.

## Implementation Stages

### 1. Design/spec PR

This PR is the design/spec stage. It creates this document, updates
the existing grammar/random-effect/likelihood/testing/extractor
contracts, and adds validation rows. It does not change R parser code,
the TMB template, roxygen, vignettes, README, NEWS, or pkgdown
navigation.

### 2. Parser/API PR

- Guard slice (landed first): if parsed term metadata contains `lv`, abort
  before fitting so current releases cannot silently ignore score
  predictors.
- Parser/API preflight slice (landed after the guard): add
  `lv = NULL` to `latent()`, store `extra$lv_formula` only on the
  rewritten reduced-rank term, never on the auto-added diagonal `Psi`
  companion, and build `X_lv_B` at the unit level, not the row level.
- Validate one-sided formulas, predictor availability, intercept
  dropping (`lv = ~ x` equals `lv = ~ 0 + x`), factor expansion,
  within-unit constancy, rank, fixed-RHS overlap, unsupported terms,
  unsupported tiers/sources, unsupported non-Gaussian families and
  binary links, and `REML = TRUE`.
- Reject augmented random-regression combinations such as
  `latent(1 + x | unit, d = K, lv = ~ z)` until a separate design
  proves the combined target.
- At that stage, runtime still aborted before TMB construction. Later
  C1 slices added `alpha_lv_B`, ADREPORT output, and point-estimate
  extractors; recovery evidence remains pending.

### 3. TMB PR

Status: landed for the C1 ordinary Gaussian unit-tier smoke/algebra
gate and the first pure binomial-probit trait-scale `B_lv`
recovery/algebra gate. Broader recovery and interval evidence are still
Stage 5 work.

- Add data flags and matrices: `use_lv_B`, `n_lv_B`, `X_lv_B`.
- Add parameter matrix `alpha_lv_B[p_lv, d_B]`, unconstrained and
  mapped off when inactive.
- Preserve the existing innovation prior `z_B ~ N(0, I)`.
- Change only the score contribution:

```cpp
score_k = z_B(k, s) + sum_h X_lv_B(s, h) * alpha_lv_B(h, k);
eta(o) += sum_k Lambda_B(t, k) * score_k;
```

- Report `alpha_lv_B`, `U_lv_mean_B`, `U_B_total`, and
  `ADREPORT(B_lv_unit = Lambda_B %*% t(alpha_lv_B))`.

### 4. Extractor PR

Status: landed as point-estimate C1 extractors for the admitted
Gaussian and binomial-probit R-side fits. Standard errors and interval
claims are deliberately withheld until recovery/calibration evidence
lands.

- Add `extract_lv_effects(fit, level = "unit",
  type = "trait_effect")`.
- Extend `extract_ordination()` with
  `component = c("total", "mean", "innovation")`.
- Return raw `alpha` only with a rotation warning.
- Return `B_lv` as the preferred trait-scale effect table, with
  standard errors only when the ADREPORT path is validated.

### 5. Public docs/article PR

Only after C1 recovery evidence, add a Tier-1 article:
**Explaining Latent Ecological Axes With Predictors**.

The article must show long and `traits(...)` wide calls side by side,
use distinct fixed-effect and LV predictors, and include a scope box:
IN ordinary Gaussian and pure binomial-probit unit-tier; PLANNED other
non-Gaussian links/families, `unit_obs`, `cluster`, `cluster2`, phylo,
animal, spatial, kernel, and mean-only reduced-rank modes.

## Test Contract

CRAN-safe tests for the parser/API PR:

- Long and wide ordinary unit-tier `lv` formulas are accepted.
- `lv = ~ x` and `lv = ~ 0 + x` build the same `X_lv`.
- Random-effect syntax, offsets, `mi()`, smooths, missing predictors,
  response/trait columns, rank-deficient designs, nonconstant
  within-unit predictors, exact fixed-RHS overlap, `REML = TRUE`,
  unsupported non-Gaussian families/links, unsupported tiers/sources,
  and augmented random-regression combinations fail loudly.
- Small Gaussian rank-1 fit reaches finite reports and correct
  extractor dimensions.
- Pure binomial-probit rank-1 fit reaches finite reports, rejects
  binary logit/cloglog at preflight, recovers trait-scale `B_lv` on a
  small multi-trial fixture, and preserves
  `total = innovation + mean`.

Heavy tests under `GLLVMTMB_HEAVY_TESTS=1`:

- Rank-1 and rank-2 Gaussian recovery of `B_lv`.
- Bernoulli single-trial binomial-probit recovery and separation
  diagnostics.
- Factor predictors and rare-level behaviour.
- Missing-response compatibility when the `lv` predictors remain
  observed and constant within unit.
- Variance/correlation edge regimes.
- Optional `gllvm` comparator for the ordinary concurrent-ordination
  subset where parameterisations align.

Recovery targets should use rotation-invariant or rotation-aware
quantities:

- `B_lv` entries: max absolute error about `< 0.25` for rank 1.
- `Sigma` off-diagonal pattern: correlation `> 0.90` CRAN,
  `> 0.95` heavy.
- `Psi`: broad but finite recovery band.

Do not use raw `alpha` or raw `Lambda` alone as the main pass/fail
target for `K > 1`.

## GLLVM.jl Parity Boundary

This is a twin-lane concept for `gllvmTMB` and `GLLVM.jl`, but parity
must move row by row. The R-side design should make the future Julia
bridge input explicit (`X_lv_B`, `alpha_lv_B`, total/mean/innovation
scores, and `B_lv`), but public docs must not imply that the Julia
engine supports `lv` until a named Julia bridge row is implemented and
validated.

## Reviewer Checklist

- **Boole:** `lv` is term-local, one-sided, fixed-effect-only, and not
  confused with random slopes.
- **Noether:** equations, R syntax, and TMB score contribution describe
  the same model.
- **Gauss:** C++ changes preserve the existing innovation prior and
  only shift the score mean.
- **Curie:** recovery tests target `B_lv`, `Sigma`, and `Psi`, not raw
  axis-specific coefficients alone.
- **Fisher:** identifiability guards cover fixed/LV overlap,
  intercept dropping, rank deficiency, and non-Gaussian deferral.
- **Emmy:** extractors return labelled total/mean/innovation scores and
  trait-scale `B_lv`.
- **Pat/Darwin:** examples explain "predictors explain the latent
  ecological axis" without causal overclaiming.
- **Rose:** public prose cites validation rows and does not advertise
  structured-source or broader non-Gaussian support before evidence
  exists.
- **Shannon:** only one PR is open and work happens from a clean
  `/private/tmp` worktree.
