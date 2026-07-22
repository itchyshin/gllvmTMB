# Design 70 -- Missing-data simulation study (ADEMP)

**Status: DESIGN / ANALYSIS ONLY (2026-05-31).** No code, no runs. This document
specifies the simulation study that will become the evidence engine for the
gllvmTMB missing-data methods paper. It designs the data-generating mechanisms,
estimands, comparators, performance measures, factorial grid, replicate budget,
and phase-to-sub-study map. It does NOT implement any helper, fit any model, or
produce any result. Implementation is deferred until the corresponding engine
phases (Design 67) land with their per-slice tests.

The study follows the ADEMP framework of Morris, White & Crowther (2019,
*Stat Med* 38:2074-2102) and the transparent-reporting items of Williams, Kim et
al. (2024, *MEE*). The structure below is ADEMP: Aims (A), Data-generating
mechanisms (D), Estimands/targets (E), Methods/comparators (M), Performance
measures (P), followed by the replicate-budget justification, the phase map, the
compute-budget realism note, the honest-limitations section, and the Williams
11-item self-audit.

## Companion documents and contract anchors

- **Design 59** (`docs/design/59-missing-data-layer.md`) -- the authoritative
  shared FIML-via-Laplace contract. The six scientific claims this study must
  support are the Aims; the Section 9 verification gates are the per-phase
  acceptance criteria. NOT edited here.
- **Design 67** (`docs/design/67-missing-predictor-design.md`) -- the gllvmTMB
  missing-PREDICTOR lane: the Phase 2a/2b/2c/3/5 ladder, the stacked-long
  multivariate engine, the `mi_unit_id` level-mismatch index, the per-unit
  discrete SUM, the `Ainv_phy_rr` phylo reuse, and the Section 6 cross-package
  contract test. This study's DGMs and sub-study boundaries mirror that ladder.
- **drmTMB Phase 18** (`drmTMB/docs/design/41-phase-18-simulation-programme.md`
  and the per-surface ADEMP sheets 47-58, 144-148) -- the sister package's
  simulation programme. This document deliberately matches its rigour, its
  truth/estimator-table discipline, its MCSE-from-coverage budgeting, and its
  Williams self-audit format so the two packages report consistently.
- **drmTMB missing-data lane** (`drmTMB/docs/design/149-missing-data-design.md`,
  slices MD0-MD7a) -- the porting source and the matched-estimand comparator for
  the cross-package contract test.

This study is to the gllvmTMB missing-data layer what drmTMB Phase 18 is to
drmTMB: the operating-characteristic evidence layer. It is a SEPARATE programme
from the gllvmTMB capability-recovery suite (Design 61); it admits a sub-study
only after that sub-study's engine phase is fitted and has focused recovery
tests, exactly as Phase 18 admits a surface only after it has a fitted
likelihood (Phase 18 first-rule-is-scope).

---

## A -- Aims

The primary aim is to quantify, with honest Monte Carlo uncertainty, WHEN the
gllvmTMB model-based missing-data layer (FIML via TMB-Laplace) recovers the true
parameters and missing values with acceptable bias and near-nominal coverage,
and WHEN it does not. The six aims below are the Design 59 scientific claims
restated as testable, falsifiable propositions. Each names the comparison, the
metric that decides it, and the boundary beyond which the claim is NOT made.

| # | Claim (Design 59) | Testable form | Decided by | Honest boundary |
|---|---|---|---|---|
| A1 | FIML recovers truth | Under MCAR and MAR-on-observed-covariate, the response-mask fit and the `mi()` predictor fit recover the true response coefficients, covariate coefficients, variance components, latent loadings, and (predictors) the missing-value conditional modes, with CI coverage within MCSE of nominal. | Bias near 0 (within MCSE); Wald/profile coverage in `0.95 +/- 2*MCSE`; EBLUP recovery correlation high. | NOT claimed under MNAR (A6); coverage claims need the formal replicate budget, not pilots. |
| A2 | FIML beats complete-case on EFFICIENCY | At the same n and missingness fraction, FIML has lower empirical SE and RMSE than listwise deletion for shared parameters, because masked/partial rows still inform shared structure (latent axes, trait covariance, structured fields). | Ratio `empSE_CC / empSE_FIML > 1` and `RMSE_CC / RMSE_FIML > 1`, both with MCSE on the ratio; largest where co-observed cells / shared fields carry the most cross-information. | Efficiency gain shrinks toward 1 when missingness is light or rows share little structure; report the gain, do not assert it is always large. |
| A3 | FIML beats ad-hoc SINGLE imputation on BIAS + coverage | Mean-fill and regression-fill single imputation understate uncertainty (too-narrow CIs, undercoverage) and can bias variance components; FIML propagates the imputation uncertainty through the same Hessian. | FIML coverage near nominal while single-imputation coverage is below nominal (CI too narrow); single-imputation variance-component bias visible. | This shows single imputation is deficient, NOT that FIML is uniquely correct; a correctly specified MI (A4) is the fair high bar. |
| A4 | FIML is asymptotically comparable to correctly specified MI | When the MI imputation model MATCHES the FIML covariate model, FIML and MI (e.g. `mice`, or the pigauto sister path) give comparable point estimates, SE, and coverage; FIML is one congenial joint fit with no completed-dataset ensemble and no Rubin pooling. | Bias, empSE, and coverage agree within MCSE in the congenial case; divergence documented (and explained) when MI's imputation model is misspecified or uses extra flexibility FIML lacks. | NOT a claim that FIML dominates MI; they are complementary (Design 59 Sections 1b, 2). Equivalence is asymptotic and congenial-model-conditional. |
| A5 | Structured borrowing helps when signal is strong, degrades gracefully when weak | Phylogenetic (and spatial) borrowing in the covariate model improves missing-predictor recovery under strong phylogenetic signal, and collapses to approximately the independent-field result under weak signal -- it does not actively harm. | Strong-signal cell: phylo-`mi()` RMSE for missing `x` < independent-`mi()` RMSE. Weak-signal cell: phylo-`mi()` approximately equal to independent (no large RMSE inflation); the phylo-signal gate flags the weak case. | NOT a claim that phylo borrowing always helps (Penone 2014; Johnson 2021; Molina-Venegas 2024 say it adds noise when signal is weak); "graceful degradation" is the testable promise, not "always beneficial". |
| A6 | Robustness / failure modes are honestly characterised | Under MNAR-on-latent, FIML is biased; the study measures and reports the bias as a LIMITATION, not a fix. Under thin observed-predictor data, identifiability is weak and the weak-identifiability warning should fire. | MNAR cells: report residual bias and coverage shortfall vs MCAR/MAR; do not propose MNAR as solved. Thin-data cells: warning-fire rate and inflated SE/coverage degradation. | The layer does NOT correct MNAR. Any MNAR sensitivity tooling (`sensitivity_mnar(delta=)`) is a diagnostic, not a correction; this study sets the honest expectation. |

Secondary aims, shared with the drmTMB programme for cross-package consistency:

- record convergence rate, non-positive-definite-Hessian rate, boundary hits,
  and warning rate per cell, never silently dropping hard fits from denominators
  (Williams item 10);
- attach a Monte Carlo standard error to every aggregate metric (Williams item
  11);
- pair each simulation wave with the relevant gllvmTMB tutorial/example for
  real-data motivation (Williams item 9).

Non-aims (kept out so the study stays tractable and honest): this study does NOT
benchmark runtime against Julia twins (that is a separate comparator lane, cf.
drmTMB #60); does NOT evaluate measurement-error models (Design 59 Section 4
non-goal); does NOT evaluate the Level-2 joint response-covariate field beyond
the single confounding-identifiability check in the Phase 4 sub-study; and does
NOT make Bayesian/posterior claims (EBLUP language only).

---

## D -- Data-generating mechanisms

All DGMs descend from one gLLVM `traits()` generative model. Each sub-study
fixes most of it and varies a small set of factors, exactly as drmTMB Phase 18
keeps each DGP "a small named surface, not a giant all-features grid".

### D.0 The common gLLVM trait DGP

For unit `u = 1, ..., n` and trait `t = 1, ..., m`, generate a multivariate
trait matrix on the link scale and then map through the per-trait family. The
structural fact (Design 67 Section 2.0) is that the engine is stacked-long: each
`(u, t)` cell is one row; a unit-level predictor is broadcast across that unit's
trait rows.

```text
# Latent axes (shared, rank d): the Lambda Lambda^T low-rank trait covariance
b_u            ~ MVN(0, I_d)                      # d latent scores per unit
Lambda         : m x d loading matrix             # trait loadings on the axes
# Trait-specific (unique) residual axis
psi_t          ~ Normal(0, sigma_unique_t^2)      # per-(u,t) unique deviation
# Optional structured UNIT-level field (phylo / spatial), used in D3/D4 only
u_struct       ~ MVN(0, sigma_f^2 * C)            # C from tree or coords
# Linear predictor for cell (u, t)
eta_{u,t} = beta0_t + beta_x_t * x_u
            + (Lambda %*% b_u)_t                  # shared latent contribution
            + psi_{u,t}                           # unique trait contribution
            + a_t * u_struct[level(u)]            # structured field (D3/D4)
# Response family map (per trait t)
y_{u,t} ~ Family_t( g_t^{-1}(eta_{u,t}) , phi_t ) # gaussian/binomial/poisson/...
```

`x_u` is the focal covariate. In response-missingness sub-studies it is fully
observed; in predictor-missingness sub-studies a fraction of `x_u` is set
missing under the chosen mechanism and modelled by the `impute` covariate model.
The shared latent axes and (where present) the structured field are exactly the
channels through which masked/partial rows inform shared parameters -- the
mechanistic basis of the A2 efficiency claim and the A5 borrowing claim.

Default fixed values (held constant unless a sub-study varies them), chosen to be
ecologically plausible and non-extreme, in the spirit of the drmTMB Gaussian
location-scale sheet:

| Quantity | Default | Note |
|---|---|---|
| latent rank `d` | 1 (Gaussian core), up to 2 in D5 | one shared axis is the safest public example (Design 61) |
| loadings `Lambda` | moderate, identified (sign/scale constraints per engine) | strong enough that traits co-vary detectably |
| `beta0_t` | spread around 0 | trait-specific intercepts |
| `beta_x_t` | nonzero, moderate (e.g. 0.5) per trait | the focal response coefficient family A1 targets |
| `sigma_unique_t` | moderate | trait-specific residual scale |
| Gaussian residual / family `phi_t` | family-appropriate moderate | not so noisy it masks signal |

### D.1 Missingness mechanisms (the cross-cutting factor)

Three mechanisms, applied either to response trait CELLS (D2) or to the
predictor `x_u` (D3-D5). MCAR and MAR are the regimes where FIML is valid
(Rubin 1976; Little & Rubin 2019); MNAR is the honest-failure regime (A6).

| Mechanism | Definition (probability a value is missing) | Role |
|---|---|---|
| MCAR | constant `P(miss) = p`, independent of all data | the clean baseline; A1 recovery and A2/A3 efficiency/bias claims |
| MAR-on-observed | `logit P(miss) = c0 + c1 * w`, where `w` is a FULLY OBSERVED covariate (never the missing value itself, never the latent axes) | the realistic regime FIML must still handle; A1 coverage under MAR |
| MNAR-on-latent | `logit P(miss) = c0 + c1 * (value or its latent driver)` -- missingness depends on the unobserved value / latent score | A6 failure regime; bias is the reported outcome, NOT corrected |

The MAR mechanism conditions on an observed covariate that IS in the covariate
model (congenial), so the FIML/MI comparison (A4) is fair. A separate MAR
variant conditioning on an observed covariate NOT in the covariate model can be
added as a misspecification probe (note it as a deliberate divergence point for
A4), but it is not in the smoke grid.

### D.2 Sub-study DGMs (one per fitted engine phase)

Each sub-study is a named surface mapped to its Design 67 phase. The "vary
first" column lists the factors that move in the smoke grid; the full grid
extends them (Section "Factorial grid").

| Sub-study | Phase (Design 67) | What is missing | DGP specialisation | Vary first |
|---|---|---|---|---|
| **S1 response mask** | Phase 1 | response trait CELLS | the D.0 core; mask a fraction of `y_{u,t}` cells; predictors complete | `n`, `m` (n_trait), missingness fraction, mechanism (MCAR/MAR) |
| **S2a continuous predictor, fixed covariate model** | Phase 2a | obs-level `x_u` (continuous Gaussian) | `impute = list(x = x ~ z)`, `z` fully observed; no covariate random block | `n`, missingness fraction, mechanism, covariate-model signal (R^2 of `x ~ z`) |
| **S2b continuous predictor, grouped** | Phase 2b | obs-level `x_u` | `impute = list(x = x ~ z + (1|group))` | adds: groups, obs per group, group-SD |
| **S2c group/species-level predictor** | Phase 2c | group/species-level `x` broadcast to units | level-mismatch via `mi_unit_id`; one observed value per group | adds: group count, broadcast fan-out |
| **S3 phylogenetic predictor (flagship for A5)** | Phase 3 | species-level `x` | `impute = list(x = x ~ 1 + phylo(1|species, tree=tree))`, Level-1 independent default | adds: **phylogenetic signal strength**, tree size, tree shape/imbalance |
| **S5-bin / S5-ord / S5-unord discrete predictor** | Phase 5 | obs/unit-level categorical `x` | `impute_model(x ~ z, family = binomial()/cumulative_logit()/categorical())`; exact finite-state SUM, per-unit over the trait product (Design 67 Section 2.3) | adds: number of categories K, category balance, predictor family |

S3 is the flagship for A5: phylogenetic signal strength is the decisive factor.
The strong-signal level should give `C` a high Pagel's-lambda-equivalent (traits
strongly tree-structured); the weak-signal level should approach lambda ~ 0
(near-independent). A5 is the comparison of phylo-`mi()` vs independent-`mi()`
RMSE across those two levels (helps when strong; ~equal when weak), reusing
pigauto's phylo-signal tooling for the gate (Design 59 Section 1b).

The discrete sub-studies (S5-*) carry the genuinely-new multivariate
complication (Design 67 Section 2.3): the per-unit SUM is over the PRODUCT of
the unit's per-trait densities, so the DGP must generate enough co-observed
traits per unit for the response side to discriminate among states. A
single-trait degenerate cell of each S5 sub-study is also the basis of the
cross-package contract test (see M).

### D.3 Factor coverage and the predictor-family factor

The predictor-family factor (Gaussian / binary / ordered) spans S2a (Gaussian),
S5-bin, S5-ord, S5-unord. It is NOT crossed inside one grid; each predictor
family is its own sub-study with its own DGP, because the integration regime
differs (continuous -> Laplace latent; discrete -> finite-state SUM, Design 67
Section 1.2). This keeps the factorial tractable and the estimands clean,
matching Phase 18's "each family is its own surface" discipline.

---

## E -- Estimands / targets

Following Phase 18 (store BOTH the true value and the estimator output for every
target), and Design 59 (responses are PREDICTED via `predict_missing()`;
predictors yield conditional modes via `imputed()` -- EBLUP language, never
posterior). Two target classes: model parameters, and missing-value recovery.

### E.1 Model-parameter targets

| Estimand | Truth | Estimator output |
|---|---|---|
| Response fixed coefficients `beta_x_t`, `beta0_t` | DGP link-scale values | `coef()` / fixed-effect summary rows (per trait) |
| Latent loadings `Lambda` (up to rotation/sign) | DGP loadings | loading extractor; compared on a rotation/sign-invariant summary (e.g. `Lambda Lambda^T`) |
| Trait covariance / unique SDs `sigma_unique_t` | DGP values | variance-component extractor |
| Structured-field SD `sigma_f` (S3/S4) | DGP value | structured-SD extractor; direct profile target where available |
| Covariate-model coefficients `beta_x` (the `impute` model) | DGP covariate-model values | covariate-model coefficient rows in `fit$missing_data` |
| Covariate-model SD `sigma_x` and structured `sigma_x_struct` (S3) | DGP values | covariate-model variance components |

Loadings need a rotation/sign-invariant comparison because gLLVM latent axes are
identified only up to rotation; report recovery of `Lambda Lambda^T` (or
realised linear predictors) rather than raw loading entries, to avoid spurious
"bias" that is only label-switching. This is a gLLVM-specific estimand subtlety
with no drmTMB analogue and must be stated explicitly in each sub-study's report.

### E.2 Missing-value recovery targets

| Estimand | Truth | Estimator output | Recovery metric |
|---|---|---|---|
| Missing RESPONSE cell value (S1) | the masked-out `y_{u,t}` (generated, then hidden) | `predict_missing()` reconstruction | correlation / RMSE of predicted vs true masked cells; prediction-interval coverage |
| Missing CONTINUOUS predictor value (S2a-c, S3) | the masked-out `x_u` (generated, then hidden) | `imputed()` conditional mode (EBLUP) + SE | correlation / RMSE of mode vs truth; SE-based interval coverage of the latent value |
| Missing DISCRETE predictor value (S5-*) | the masked-out category | `imputed()` conditional state probabilities; expected score (ordered) / modal category (unordered) | per-state probability calibration; expected-score RMSE (ordered); modal-category accuracy (unordered); SE is `NA` in v1 (Design 67 Section 3.4) |

Replicate-specific truths (the realised masked values, the realised tree/`C`
matrix, the realised covariate-model R^2) must be saved per replicate, because
they depend on the random draw -- the same discipline as Phase 18 ("save
replicate-specific truths when they depend on realised sample sizes or a
generated covariance matrix").

---

## M -- Methods / comparators

Five method families. The discipline (from Phase 18) is: fit the intended
gllvmTMB model, the deletion baseline, the single-imputation baselines, and ONE
correctly-specified MI comparator -- no comparator zoo. If a comparator cannot
target the same estimand, the report says so rather than forcing an unfair
comparison.

| Method | What it is | Targets which aims | Notes |
|---|---|---|---|
| **M-FIML** (the method under test) | gllvmTMB with `miss_control(response="include")` (S1) or `predictor="model"` + `mi()`/`impute` (S2-S5) | A1, A2, A3, A4, A5, A6 | the model-based layer; EBLUP + joint-Hessian SE |
| **M-CC** (complete-case / listwise deletion) | gllvmTMB fit after dropping units/cells with any missing focal value | A2 (efficiency baseline) | for S1, drop units with any masked trait; for S2-S5, drop units with missing `x`. Same model otherwise. |
| **M-mean** (mean-fill single imputation) | fill missing `x` (or trait) with the observed mean, then fit the SAME gllvmTMB model treating filled values as known | A3 (bias/coverage baseline) | the naivest ad-hoc fix; expected to undercover |
| **M-reg** (regression-fill single imputation) | fill missing `x` with its prediction from the covariate model `x ~ z`, then fit treating filled values as known | A3 (bias/coverage baseline) | better point fill than mean, but STILL single imputation -> understates uncertainty |
| **M-MI** (multiple imputation, correctly specified) | impute `x` with an external MI engine whose imputation model MATCHES the FIML covariate model, fit gllvmTMB on each completed set, pool via Rubin's rules | A4 (the fair high bar) | candidate engines: `mice` (Gaussian/logreg/polr imputation matching the predictor family) and/or the pigauto sister path (`multi_impute()` -> fit -> `pool_mi()`, Design 59 Section 1b). Use the pigauto path for phylo cases (S3). |

Notes on fairness and scope:

- **The cross-package contract test** (Design 67 Section 6) is a method check,
  not a comparator in the operating-characteristic sense. On a SINGLE-trait
  degenerate dataset with one missing predictor, gllvmTMB-with-one-trait and
  drmTMB-univariate must agree on the imputed value and `beta_x` (the
  multivariate engine collapses to the drmTMB case). This is a strong
  faithful-port check that runs as a deterministic test, not a Monte Carlo
  sweep; it gates the trust we place in M-FIML before the sweeps run.
- **M-MI congeniality is the crux of A4.** The headline A4 cell uses an MI
  imputation model that matches the FIML covariate model exactly; FIML ~ MI is
  the expected result. A deliberately misspecified-MI variant (wrong imputation
  family, or omitting the structured field in S3) is the documented divergence
  point -- it shows MI's correctness is model-conditional too, which is the
  honest framing (Design 59 Section 2: FIML and proper MI are asymptotically
  equivalent under a correctly specified model).
- **Nested-model comparators** for any power/Type-I question (e.g. testing
  `beta_x = 0`) are labelled nested gllvmTMB comparisons, not competing methods,
  exactly as Phase 18 treats its constant-scale nested model.
- **No Julia/`glmmTMB` runtime twins** in this study (separate lane).

---

## P -- Performance measures

Every measure is reported per cell and per estimand WITH its Monte Carlo
standard error (Williams item 11). The set matches Phase 18 plus the
missing-data-specific recovery and contrast measures.

| Measure | Formula | Reported with (MCSE) |
|---|---|---|
| Bias | `mean(theta_hat - theta_true)` | `sd(theta_hat) / sqrt(n_sim)` |
| Relative bias | `mean((theta_hat - theta_true)/theta_true)` when denominator stable | delta-method or bootstrap MCSE |
| Empirical SE | `sd(theta_hat)` | `empSE / sqrt(2*(n_sim-1))` |
| RMSE | `sqrt(mean((theta_hat - theta_true)^2))` | bootstrap MCSE |
| CI coverage | `mean(lo <= theta_true <= hi)` | `sqrt(p*(1-p)/n_sim)` |
| CI width | `mean(hi - lo)` | `sd(width)/sqrt(n_sim)` |
| Convergence rate | `mean(converged & pdHess)` | binomial MCSE |
| NPD-Hessian / boundary / warning rate | `mean(flag)` each | binomial MCSE |
| **Efficiency ratio (A2)** | `empSE_CC / empSE_FIML`; `RMSE_CC / RMSE_FIML` | bootstrap MCSE on the ratio (paired over replicates) |
| **Coverage gap (A3)** | `coverage_FIML - coverage_single` | difference-of-proportions MCSE |
| **FIML-vs-MI agreement (A4)** | bias, empSE, coverage differences FIML - MI | paired/difference MCSE |
| **Missing-value recovery** | correlation and RMSE of `imputed()`/`predict_missing()` modes vs hidden truth; expected-score RMSE (ordered); modal-category accuracy (unordered) | bootstrap / binomial MCSE as appropriate |
| **Imputation-interval coverage** | coverage of the latent-value SE interval (continuous) / prediction interval (response) vs the hidden true value | binomial MCSE |
| **Weak-identifiability warning rate (A6)** | `mean(warning_fired)` across thin-data cells | binomial MCSE |
| Runtime | median and high quantiles of elapsed seconds | bootstrap interval |

Reporting discipline (Phase 18 artifact-grain contract): keep replicate-level
rows (`artifact_grain = "replicate"`, one row per replicate x parameter x cell)
SEPARATE from aggregate rows (`artifact_grain = "aggregate"`, one row per grouped
estimand with bias/RMSE/coverage/MCSE). Replicate-level error clouds may only be
drawn from replicate rows; aggregate reports use points + MCSE bars. Failed and
warning-bearing fits stay in the manifest and the warning/error ledger; they are
NOT silently dropped from denominators without a labelled sensitivity analysis
(Williams item 10). The A2/A3/A4 contrasts must be computed PAIRED over the same
replicate (same generated dataset fit by competing methods) so the contrast MCSE
reflects the within-replicate correlation, not an unpaired difference.

---

## Replicate budget (nsim) and Monte Carlo SE justification

The binding constraint is coverage MCSE, the strictest target (Morris et al.
2019; Phase 18 coverage-MCSE planning). For a coverage probability near 0.95,

```text
MCSE(coverage) = sqrt( p*(1-p) / n_sim ),  p ~ 0.95
  n_sim =  500  -> MCSE ~ 0.0097  (about 1.0 percentage point)
  n_sim = 1000  -> MCSE ~ 0.0069  (about 0.7 percentage points)
  n_sim = 2000  -> MCSE ~ 0.0049  (about 0.5 percentage points)
```

Decision:

- **Smoke grid:** `n_sim = 20` per cell. Purpose: seed stability, output shape,
  artifact paths, and gross sanity only. CRAN-safe. Makes NO coverage, bias, or
  efficiency claims -- labelled "smoke", per Phase 18.
- **Pilot grid:** `n_sim = 100-200` per cell, for tuning the factor levels and
  catching convergence pathologies before committing compute. Labelled "pilot";
  no final coverage claims.
- **Formal grid:** `n_sim = 1000` per cell for the headline coverage tables
  (A1, A3, A6 coverage), giving ~0.7 pp coverage MCSE -- the same target the
  drmTMB programme uses for its formal grids. Bias and empSE are far better
  resolved than coverage at this n_sim, so 1000 is governed by the coverage
  requirement and is sufficient for the bias/efficiency contrasts.
- **A4 congeniality cell** may use `n_sim = 1000` paired FIML/MI runs; because MI
  itself is expensive (m completed datasets x a gllvmTMB fit each), this cell is
  the compute bottleneck and may be run on a reduced factor subset (see budget).

For the A2 efficiency ratio and A3 coverage gap, the relevant MCSE is on the
CONTRAST. Because the contrasts are paired within replicate, 1000 paired
replicates resolve a ratio difference of a few percent and a coverage gap of ~1
pp -- adequate to support "FIML beats CC/single-imputation" when the effect is
real, and adequate to report "no detectable difference" honestly when it is not.

Reproducibility (Williams items 6-8): a master seed plus per-replicate
sub-seeds (L'Ecuyer-style streams) so any cell x replicate is independently
reproducible and re-runnable; full `sessionInfo()`, package versions, TMB/engine
version, and the realised tree/`C`/covariate-model R^2 saved per cell. Per-cell
results saved as RDS with replicate seeds, fit status, warnings, elapsed time,
diagnostic rows, and interval status -- the resumable layout drmTMB uses under
`inst/sim/` (`dgp/`, `fit/`, `run/`, `reports/`). gllvmTMB has NO existing
`inst/sim/` infrastructure; the first implementation slice builds the skeleton +
seed helper + one CRAN-safe smoke test, mirroring drmTMB Phase 18 Slice 210.

---

## Phase-to-sub-study map (which sub-study gates which implementation phase)

The study admits a sub-study only after its engine phase is fitted with focused
recovery tests (the Phase 18 scope rule). The mapping is one sub-study per phase
of the Design 67 ladder; each sub-study is the operating-characteristic evidence
that the phase's Section 9 gate (Design 59) is met.

| Sub-study | Gates phase | Design 59 Section 9 gate it provides evidence for | Aims exercised |
|---|---|---|---|
| **S1 response mask** | Phase 1 | recovery sim; deterministic complete-case match on observed rows; sentinel-invariance; weak-identifiability (cross-trait correlation needs co-observed cells); non-regression | A1, A2 |
| **S2a continuous fixed** | Phase 2a | recovery (`beta`, `beta_x`, `x` EBLUP + SE coverage); no-op; complete-case match | A1, A2, A3, A4 |
| **S2b grouped** | Phase 2b | recovery with grouped covariate intercept; `b_x` independent of response RE | A1, A2 |
| **S2c level-mismatch** | Phase 2c | level-mismatch correctness; one observed value per group; broadcast | A1, A2 |
| **S3 phylogenetic** | Phase 3 | **phylo recovery: strong vs weak signal -> helps when strong, degrades to ~independent when weak; phylo-signal gate fires on weak**; identifiability (Level-1 default) | A1, A4, A5 |
| **S5-bin / S5-ord / S5-unord** | Phase 5 | finite-state SUM matches brute-force marginalisation; expected-probability / expected-score / modal-category recovery; K>=3 guard (ordered); baseline-invariance (unordered) | A1, A3 |
| **Phase 4 identifiability check** | Phase 4 | confirm `beta_x` bias under a shared-field joint model and that eigenvector orthogonalisation removes it (reproduce Dupont 2023 / Wang 2025-preprint remedy on a sim) | A5 (boundary), A6 |
| **MNAR / thin-data robustness** (cross-cutting, applied to S2a + S3) | gates the HONESTY claim across phases | MNAR bias reported as a limitation; weak-identifiability warning rate | A6 |

Cross-cutting comparators map onto aims, not phases: M-CC/M-mean/M-reg run in
every sub-study (cheap); M-MI runs in S2a (congenial Gaussian) and S3 (phylo, via
pigauto) where the A4 claim is sharpest. The cross-package contract test (M-FIML
vs drmTMB) attaches to S2a and each S5 sub-study via their single-trait
degenerate cells.

Execution cadence mirrors Design 59 Section 8: S1 lands first (the "easy win"),
then S2a (the minimal viable joint model and the first FIML-vs-CC/single/MI
contrasts), then S2b/2c, then S3 (the flagship), then S5; the Phase 4 and MNAR
robustness studies run alongside S3 once a structured covariate model exists.

---

## Compute-budget realism (local vs Totoro vs DRAC)

This is a heavy study; honest tiering matters. The cost driver is
NOT one fit but `n_sim x n_cells x n_methods`, and for M-MI an extra factor of
`m` completed datasets per replicate. D-50 keeps deterministic checks local,
uses Totoro for bounded smoke, and plans formal grids as frozen DRAC arrays
after the relevant array driver has passed its own preflight.

| Tier | What runs | Where | Replicates | Rationale |
|---|---|---|---|---|
| **Smoke** | seed/shape/no-op tests; one tiny cell per sub-study | CRAN tests + local | `n_sim = 20`, 1-2 cells | must stay CRAN-time-safe; no claims |
| **Pilot** | factor-level tuning; convergence screening; the cross-package contract test | local (Mac) | `n_sim = 100-200`, reduced grid | catch pathologies before spending formal compute; local first per the local-over-CI rule |
| **Formal (light)** | S1, S2a coverage + A2/A3 contrasts | Totoro or a short DRAC array after driver preflight and parity | `n_sim = 1000`, smoke-grid factor levels | Gaussian fits are fast, but the full attempt denominator still needs an immutable campaign bundle |
| **Formal (heavy)** | S3 phylo grid (tree sizes), S5 multivariate SUM, A4 MI cells | Planned DRAC array after driver preflight | `n_sim = 1000`, full grid, sharded | phylo fits + MI ensembles + multivariate SUM are the bottleneck; one seed/task with retained failures |

Compute guidance: freeze source, DGP, seeds, thresholds, retry policy, and result
schema before remote work. Use one CPU/task unless a benchmark proves within-fit
parallel benefit; inspect `seff` before sizing later waves. GitHub Actions is
reserved for package checks and documentation and stores no simulation output.
Use a bounded parallel replicate runner;
parallelise EITHER the replicate layer OR the MI/bootstrap inner layer, never
both at once (drmTMB's nested-parallel guard). Flag the M-MI heavy cells as the
single most expensive component and the first candidate for a reduced factor
subset if the budget binds.

---

## Honest limitations (what this study does NOT and CANNOT prove)

Stated plainly, in the discipline of Design 59's own caveats and the user's
evidence-first/no-overselling rules:

1. **MNAR is not fixed.** Under MNAR-on-latent, FIML is biased; this study
   MEASURES and REPORTS that bias (A6) but does not correct it. No result here
   should be read as "the layer handles MNAR". MNAR sensitivity tooling, if
   shipped, is a diagnostic (`sensitivity_mnar(delta=)`), not a remedy. Trait
   databases are typically MNAR (Design 59 Section 3), so this is the
   load-bearing honest caveat for real use.
2. **Phylogenetic borrowing is signal-dependent, not free.** A5 is "helps when
   strong, degrades gracefully when weak", NOT "always helps". When signal is
   weak, phylo imputation adds noise (Penone 2014; Johnson 2021; Molina-Venegas
   2024); the study's job is to show graceful degradation and a firing
   phylo-signal gate, not to advertise universal benefit. We also do not claim
   the phylogenetic-confounding remedy (Wang et al. 2025) is settled science --
   that preprint is non-peer-reviewed (Design 59 Section 11) and the Phase 4
   check reproduces an indicative remedy, not an established one.
3. **FIML ~ MI only in the congenial case, and only asymptotically.** A4
   equivalence holds when the MI imputation model matches the FIML covariate
   model (Schafer & Graham 2002). The study documents
   divergence under misspecification; it does NOT claim FIML dominates MI. They
   are complementary paths (Design 59 Sections 1b, 2).
4. **Coverage claims are conditional on a correctly specified joint model.**
   FIML coverage is near-nominal under MAR with distinct parameters and a correct
   model (Rubin 1976; Little & Rubin 2019). All A1 coverage cells use correctly
   specified covariate models; coverage under covariate-model misspecification is
   a separate, deliberately limited probe, not the headline.
5. **Laplace SEs can be optimistic under non-normality.** Allison (2003): FIML
   SEs may be negatively biased away from normality. Where the response family is
   non-Gaussian, undercoverage may reflect the Laplace SE approximation rather
   than the missing-data layer; the bootstrap-SE cross-check (Design 59 Section
   9 gate) is the honest diagnostic and should be reported alongside Wald
   coverage in non-Gaussian cells.
6. **gLLVM identifiability limits the loadings estimand.** Latent loadings are
   identified only up to rotation/sign; "bias" must be assessed on
   rotation-invariant summaries (`Lambda Lambda^T`), or it is an artefact of
   label-switching, not a real defect. This is a reporting hazard unique to the
   multivariate engine.
7. **Simulation truth is not field truth.** Every DGM is a correctly specified
   instance of the model class the layer assumes. Good operating characteristics
   here demonstrate internal validity (the estimator does what the theory says),
   NOT that real trait data obey the gLLVM/`traits()` generative model. The
   real-data tutorials (Williams item 9) carry the external-validity argument;
   this study does not.

---

## Williams (2024) 11-item self-audit

| Item | Coverage in this design |
|---|---|
| 1. Aims | A1-A6 stated as testable propositions with decision metrics and explicit non-claims (A section). |
| 2. Data-generating mechanisms | One common gLLVM `traits()` DGP (D.0), three missingness mechanisms (D.1), and seven sub-study specialisations mapped to engine phases (D.2); defaults and varied factors tabulated. |
| 3. Estimands | Model-parameter targets and missing-value-recovery targets, each with truth + estimator output; rotation-invariant loadings caveat; replicate-specific truths saved (E section). |
| 4. Methods | M-FIML, M-CC, M-mean, M-reg, and one congenial M-MI; cross-package contract test; nested comparators for power; no comparator zoo (M section). |
| 5. Performance measures | Bias, relative bias, empSE, RMSE, coverage, CI width, convergence/NPD/boundary/warning rates, the A2/A3/A4 paired contrasts, missing-value recovery, imputation-interval coverage, warning-fire rate, runtime -- each with MCSE (P section). |
| 6. Software and settings | Per-cell `sessionInfo()`, package + TMB/engine versions, and realised tree/`C`/covariate-R^2 saved; resumable `inst/sim/` layout specified (Replicate-budget section). |
| 7. Code availability | Planned under a new `inst/sim/` (dgp/fit/run/reports), built skeleton-first in the first implementation slice; reports rendered per wave. |
| 8. Replicability | Master seed + per-replicate L'Ecuyer sub-seeds; per-cell RDS with seeds, status, warnings, timing, interval status (Replicate-budget section). |
| 9. Real-data motivation | Each wave paired with the relevant gllvmTMB tutorial (morphometrics, phylogenetic GLLVM, etc.); external validity is carried by tutorials, not asserted by the sim (Limitations item 7). |
| 10. Complete results | Failed/boundary/warning fits retained in manifest + warning/error ledger, never dropped silently; paired contrasts computed within replicate (P section). |
| 11. Monte Carlo uncertainty | Coverage-MCSE budgeting: smoke n=20, pilot 100-200, formal 1000 (~0.7 pp coverage MCSE); every aggregate metric carries an MCSE (Replicate-budget section). |

## Boundary

This design sheet does NOT design: runtime benchmarking against Julia twins or
glmmTMB; measurement-error simulations; the Level-2 joint response-covariate
field beyond the single Phase 4 confounding-identifiability check; count
missing-predictor families (no finite support, deferred per Design 67 Section
1.2); multiple simultaneous missing predictors; tree-uncertainty propagation
(the pigauto sister path covers that, Design 59 Section 1b); or any
Bayesian/posterior evaluation. Each remains a separate, later, or out-of-scope
study until its engine phase and its own ADEMP sheet exist.
