# Design 73 -- Predictor-Informed Latent Scores

**Status:** C1 ordinary unit-tier parser + TMB support for Gaussian and
pure binomial logit/probit/cloglog fits; ordinary Gaussian response masks are
validated when the `lv` predictors remain observed and complete at the unit
level; the R-to-Julia bridge also has point-only complete-response Poisson,
NB2, Gamma, and Beta routes. Native TMB Gaussian recovery and interval
evidence now cover the current ordinary Gaussian cells, and unsupported native
family/link plus REML/lv-formula boundaries have fail-loud guard tests, but
broader interval, family, tier, source-specific, and bridge parity claims remain
gated row by row.
**Maintained by:** Boole (formula grammar), Gauss (TMB implementation),
Noether (math contract), Emmy (extractor contract), Curie (simulation
tests), Fisher (identifiability and inference), Rose (scope audit).
**Validation rows:** `FG-18`, `RE-13`, `EXT-31`, `LV-01` through
`LV-07` in `docs/design/35-validation-debt-register.md`.

This design adds an `lv = ~ ...` argument to ordinary `latent()` terms.
The argument is a term-local fixed-effect formula for the mean of the
latent scores. It is not a random-effects formula, not a loading model,
and not a replacement for trait-specific fixed effects. The current
implementation admits only the C1 ordinary unit-tier surface: native
TMB Gaussian fits, including response masks when `lv` predictors are
observed and complete, native TMB pure-binomial standard-link fits, and a
narrow R-to-Julia bridge point route for complete-response Gaussian,
Poisson, NB2, Gamma, Beta, and binomial standard-link fits. All other rows
remain planned or blocked as listed below.

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
single-family `binomial()` with one of the package's three supported
binary links (`"logit"`, `"probit"`, or `"cloglog"`) and the same
ordinary unit-tier score-mean model. Bridge-only Poisson, NB2, Gamma, and
Beta point routes are also admitted for complete-response `engine = "julia"`
fits with `unique = FALSE`, no fixed-effect `X`, no response mask, and no
CIs. Native TMB count-family support, nonstandard binomial links, ordinal, NB1,
mixed-family, response-mask bridge, and delta/hurdle bridge rows remain blocked
until their own validation rows move. Unsupported native family/link calls fail
loudly; that guard is not support for those families.

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
admission uses the same linear predictor inside the selected binomial
likelihood, `y_it ~ Binomial(n_it, g^{-1}(eta_it))`, for logit,
probit, or cloglog links.

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

- C1 native TMB support covers **ordinary unit-tier Gaussian and pure
  binomial logit/probit/cloglog `latent()` only**. The R-to-Julia bridge
  additionally admits complete-response Poisson, NB2, Gamma, and Beta point
  routes under the bridge restrictions in Section 4a.
- `lv` accepts a one-sided fixed-effect formula only.
- Random-effect bars, offsets, `mi()`, smooth terms, and response or
  trait columns inside `lv` are rejected; top-level guard tests cover
  random-effect bars, `offset()`, `mi()`, and smooth terms.
- `lv = ~ x` is accepted, but the intercept is dropped internally.
  The parser records a fit note and tests equivalence to
  `lv = ~ 0 + x`.
- Predictors in `lv` must be constant within the grouping level of the
  outer `latent()` term. The parser errors rather than averaging.
- Any ordinary fixed-effect RHS covariate is rejected in C1 when a
  predictor-informed `lv` term is present. This includes exact overlap
  such as `x + latent(..., lv = ~ x)` and non-overlap formulas such as
  `z + latent(..., lv = ~ x)`. The combined `X + X_lv` regime remains
  gated until it has its own derivation and recovery evidence.
- `REML = TRUE` with `lv` is rejected by a top-level guard test. REML /
  AI-REML language remains Gaussian-only and needs a separate derivation even
  for this Gaussian C1 surface.
- Other non-Gaussian families, native count-family `lv`, nonstandard binomial
  links, ordinal `lv`, and mixed-family `lv` fits are rejected until their own
  validation rows move. The native fail-loud guards currently cover binomial
  cauchit, ordinal-probit, mixed Gaussian/binomial/Poisson family lists,
  Poisson, NB1, NB2, lognormal, Gamma, Beta, Tweedie, Student-t, truncated
  Poisson, truncated NB2, beta-binomial, delta-lognormal, and delta-Gamma.
- C1 supports at most one ordinary unit-tier `latent()` term carrying
  `lv`.
- `extract_Sigma()` keeps its current meaning:
  `Lambda Lambda^T + Psi` for the model's conditional unit-tier
  covariance. It does not add empirical variance induced by the
  observed `lv` predictors.
- The primary public estimand is the latent-predictor trait effect,
  written as `B_lv = Lambda %*% t(alpha)` in the internal math notation,
  not raw `alpha`, because `alpha` depends on the latent-axis convention.

## Tier Grammar

The metadata should be designed for future tier-local `lv` formulas,
but C1 exposes only ordinary unit-tier support.

| Tier / source | Eventual target | C1 behaviour |
|---|---|---|
| `latent(... | unit, lv = ~ x_unit)` | Unit-level latent-score mean | C1 partial: ordinary Gaussian plus pure binomial logit/probit/cloglog on the TMB path, and a narrow complete-response Gaussian, Poisson, NB2, Gamma, Beta, and binomial logit/probit/cloglog `engine = "julia"` point route; smoke/algebra evidence, focused native Gaussian recovery, standard-link binary latent-predictor trait-effect recovery, and rank-1 multi-trial standard-link binomial interval evidence |
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
  unsupported tiers/sources, unsupported native-TMB non-Gaussian families,
  unsupported bridge families, unsupported binary links, and `REML = TRUE`.
- Reject augmented random-regression combinations such as
  `latent(1 + x | unit, d = K, lv = ~ z)` until a separate design
  proves the combined target.
- At that stage, runtime still aborted before TMB construction. Later
  C1 slices added `alpha_lv_B`, ADREPORT output, point-estimate
  extractors, and `ADREPORT(B_lv_unit)` standard-error extraction for
  positive-definite `sdreport()` fits; focused Gaussian recovery is now
  partial, and interval evidence remains pending.

### 3. TMB PR

Status: landed for the C1 ordinary Gaussian unit-tier smoke/algebra
gate, focused native TMB Gaussian recovery, and the first pure-binomial
logit/probit/cloglog trait-scale `B_lv` recovery/algebra gate. Interval
coverage and broader family recovery are still Stage 5 work.

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

Status: landed as C1 extractors for the admitted Gaussian and
pure-binomial standard-link R-side fits. Trait-scale `B_lv` standard
errors are returned only when `se = TRUE` produces a positive-definite
`sdreport()` for `ADREPORT(B_lv_unit)`. Focused Gaussian recovery and
rank-1 delta-SE validation now exist, but interval claims are deliberately
withheld until coverage/calibration evidence lands.

- Add `extract_lv_effects(fit, level = "unit",
  type = "trait_effect")`.
- Extend `extract_ordination()` with
  `component = c("total", "mean", "innovation")`.
- Return raw `alpha` as the default axis / CLV effect table, with a
  rotation warning and Wald SE / CI columns when the fitted loading
  constraint and a positive-definite `sdreport()` make them available.
- Return `B_lv` as the explicit induced trait-scale effect table, with
  `wald_sdreport_no_ci_validation` standard errors and Wald CI columns
  from `ADREPORT(B_lv_unit)` output when available. Coverage calibration
  remains target- and regime-specific.

### 4a. R-to-Julia bridge PR

Status: landed for narrow Gaussian, Poisson, NB2, Gamma, Beta, and binomial
logit/probit/cloglog point routes only. The R bridge builds the same
unit-level `X_lv` design through the Design 73 parser setup and passes it
to `GLLVM.bridge_fit(X_lv = ...)` for complete Gaussian, Poisson, NB2,
Gamma, Beta, and binomial logit/probit/cloglog
`latent(..., unique = FALSE, lv = ~ x)` rows with no fixed-effect `X`, no
response mask, and `ci_method = "none"`.

- Retained Julia payloads are `lv_effects`, `alpha_lv`,
  `scores_mean`, and `scores_innovation`.
- `extract_lv_effects()` defaults to the Julia bridge `alpha_lv` axis
  table and reports `lv_effects` only through `type = "trait_effect"`.
  Bridge rows are point estimates only unless a retained Wald payload is
  present: `std.error = NA` and
  `uncertainty_status =
  "julia_bridge_point_estimate_only_no_ci_validation"`.
- `extract_ordination(component = c("total", "mean", "innovation"))`
  is routed for those retained Gaussian, Poisson, NB2, Gamma, Beta, and
  binomial bridge score payloads.
- NB1, ordinal, mixed-family `X_lv`, fixed-effect `X` plus `X_lv`,
  response masks plus `X_lv`, and any CI/profile/bootstrap route remain
  gated under `JUL-01`, `JUL-01A`, and `LV-01`. The same fixed-effect
  `X + X_lv` boundary is enforced on the native path before fitting.

### 4b. Native Wald coverage campaign

Status: local r500 production-size evidence exists for the current ordinary
Gaussian cells and for the rank-1 multi-trial binomial standard-link cells. The
dev-only runner `dev/lv-wald-coverage.R` defines four ordinary Gaussian cells:

| Cell | Target |
|---|---|
| `gaussian-d1-n72-t3` | Rank-1, small `n`, three traits |
| `gaussian-d1-n144-t3` | Rank-1, larger `n`, three traits |
| `gaussian-d2-n96-t4` | Rank-2, small/moderate `n`, four traits |
| `gaussian-d2-n160-t4` | Rank-2, larger `n`, four traits |

ADEMP mapping for this slice:

- Aim: estimate empirical Wald coverage for the trait-scale
  `B_lv = Lambda alpha^T` entries from native TMB
  `ADREPORT(B_lv_unit)`.
- Data-generating mechanism: complete-response Gaussian ordinary
  unit-tier `latent(..., lv = ~ x)`, fixed known `Lambda`, `alpha`,
  and `Psi`, with `e_i ~ N(0, I_K)` and one unit-level predictor `x`.
- Estimands: `B_lv` entries are primary; fit health and failure rates
  are reported alongside them. Raw `alpha` and raw `Lambda` are not
  coverage targets.
- Method: refit the matching `gllvmTMB()` model with `se = TRUE` and
  compute nominal 95% Wald intervals from extractor `estimate` and
  `std.error`.
- Performance: coverage, coverage MCSE, bias, bias MCSE, RMSE,
  convergence, positive-definite Hessian, `sdreport()` availability,
  CI availability, and wall time.

Production admission requires at least 500 reps per cell, one recorded
seed per replicate/SLURM array task, per-replicate RDS outputs,
`sessionInfo()`, and failed-fit denominators. With 500 eligible reps,
nominal 95% coverage has MCSE about 0.01; a 0.92--0.98 band is the
initial audit range. Passing the dev harness or a one-rep smoke is not
coverage evidence.

The 2026-06-28 local r500 run met that replicate bar for the four current
ordinary Gaussian cells. It attempted 500 fits/cell, all optimizer-converged,
and wrote the compact evidence artifacts under
`docs/dev-log/artifacts/lv-wald-coverage/`:

- `2026-06-28-local-r500-summary.csv`
- `2026-06-28-local-r500-excluded-replicates.csv`
- `2026-06-28-local-r500-t-vs-z.csv`

All 28 target/method rows passed the 0.92--0.98 coverage band with
coverage 0.9269--0.9610 and MCSE 0.0088--0.0119. The denominator audit
is part of the evidence, not a side note: all optimizer runs converged,
but non-positive-definite Hessian rows reduced `n_eligible` to 487 in
`gaussian-d1-n72-t3`, 487 in `gaussian-d2-n96-t4`, and 479 in
`gaussian-d2-n160-t4`; `gaussian-d1-n144-t3` retained all 500 eligible
fits. The `wald_t_unit` comparator was never worse than `wald_z` in this
grid and improved 12 of 14 target rows by 0.0020--0.0063. Profile or
bootstrap rescue is therefore not required for these four ordinary
Gaussian cells, but remains a separate inference slice if later cells
under-cover.

The same harness now also defines the first pure-binomial standard-link
interval cells:

| Cell | Target |
|---|---|
| `binomial-logit-d1-n160-t3` | Rank-1, multi-trial logit, three traits |
| `binomial-probit-d1-n160-t3` | Rank-1, multi-trial probit, three traits |
| `binomial-cloglog-d1-n160-t3` | Rank-1, multi-trial cloglog, three traits |

The 2026-06-30 local r500 binomial run met the same replicate bar for
these three standard-link cells. It attempted 500 fits/cell across logit,
probit, and cloglog, all optimizer-converged, all had positive-definite
Hessians, all had usable `sdreport()` output, and all 1,500 fitted replicates
remained eligible for interval summaries. Compact evidence artifacts are
recorded under `docs/dev-log/artifacts/lv-wald-coverage/`:

- `2026-06-30-local-binomial-r500-summary.csv`
- `2026-06-30-local-binomial-r500-excluded-replicates.csv`
- `2026-06-30-local-binomial-r500-t-vs-z.csv`
- `2026-06-30-local-binomial-r500-session-info.txt`

All 18 target/method rows passed the 0.92--0.98 coverage band, with coverage
0.920--0.952 and MCSE 0.0096--0.0121. The excluded-replicate artifact is
header-only because no replicate failed convergence, Hessian, `sdreport()`, or
CI availability checks. The `wald_t_unit` comparator improved four of nine
paired target rows by 0.002, tied the other five, and was never worse. This
promotes the narrow native binomial interval subclaim for the three rank-1
multi-trial standard-link cells only; `LV-05` remains partial for native
count-family, nonstandard binomial-link, ordinal, mixed-family, response-mask,
source/tier-expanded, and Julia-bridge interval support.

### 5. Public docs/article PR

Only after C1 recovery evidence, add a Tier-1 article:
**Explaining Latent Ecological Axes With Predictors**.

The article must show long and `traits(...)` wide calls side by side,
use distinct fixed-effect and LV predictors, and include a scope box:
IN ordinary Gaussian and pure binomial logit/probit/cloglog native
unit-tier fits; PARTIAL bridge-only Poisson point rows; PLANNED native
count-family support, other non-Gaussian families, mixed-family rows,
`unit_obs`, `cluster`, `cluster2`, phylo, animal, spatial, kernel, and
mean-only reduced-rank modes.

## Test Contract

CRAN-safe tests for the parser/API PR:

- Long and wide ordinary unit-tier `lv` formulas are accepted.
- `lv = ~ x` and `lv = ~ 0 + x` build the same `X_lv`.
- Random-effect syntax, offsets, `mi()`, smooths, missing predictors,
  response/trait columns, rank-deficient designs, nonconstant
  within-unit predictors, exact fixed-RHS overlap, `REML = TRUE`,
  unsupported native-TMB non-Gaussian families, unsupported bridge
  families, unsupported tiers/sources, and augmented random-regression
  combinations fail loudly.
- Small Gaussian rank-1 fit reaches finite reports and correct
  extractor dimensions.
- Pure binomial logit/probit/cloglog rank-1 fits reach finite reports,
  recover trait-scale `B_lv` on small multi-trial fixtures, and preserve
  `total = innovation + mean`.

Heavy tests under `GLLVMTMB_HEAVY_TESTS=1`:

- Rank-1 and rank-2 Gaussian recovery of `B_lv` and `Sigma`
  (covered by `test-lv-gaussian-recovery.R`, with rank 2 heavy-gated).
- Native Wald coverage harness checks for the grid layout, one
  recorded seed per task, failed-fit denominators, MCSE formulas,
  normal-critical and unit-df t-critical comparator rows, binomial
  standard-link cell metadata/DGP construction, and opt-in one-fit
  Gaussian/binomial smokes (`test-lv-wald-coverage-harness.R`). The local
  r500 Gaussian evidence artifacts are external validation evidence; the
  package tests remain harness and smoke checks, not a shortcut for
  rerunning production coverage fits on CRAN.
- `dev/lv-wald-coverage-slurm.sh` writes/tests/submits the matching
  one-seed-per-SLURM-array-task campaign and collects summaries after the
  array finishes. The wrapper is launch infrastructure only; it is not
  production evidence until the array output exists and is audited.
- Bernoulli single-trial binomial recovery and separation
  diagnostics.
- Factor predictors and rare-level behaviour.
- Missing-response compatibility when the `lv` predictors remain
  observed and constant within unit (covered for ordinary Gaussian native TMB
  by `test-lv-missing-response.R`).
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
must move row by row. Named Julia bridge rows now exist only for the
complete-response Gaussian, Poisson, NB2, Gamma, Beta, and binomial
logit/probit/cloglog point routes described above. Public docs must not imply
native count-family support, NB1, ordinal, mixed-family `X_lv`, Julia bridge
response masks with `X_lv`, fixed-effect `X` plus `X_lv`, CI/profile/bootstrap
support, or broad native-vs-Julia parity until those rows are implemented and
validated. Current parser guards reject fixed-effect `X + X_lv` formulas on
both the overlapping and non-overlapping covariate paths, and top-level guards
reject unsupported family/link plus REML/lv-formula calls before fitting.

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
