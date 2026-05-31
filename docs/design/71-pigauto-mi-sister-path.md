# Design 71 -- pigauto MI sister-path + `with_pigauto()` handoff

**Status: DESIGN / ANALYSIS ONLY (2026-05-31).** No engine code, no TMB
fits, no R API shipped here. This document studies the sister package
`pigauto` and designs how it relates to the gllvmTMB in-model FIML
missing-data layer (Design 59) as the deliberate **alternative
(multiple-imputation) path**. It deepens Design 59 section 1b (which
already records the two-path strategy and reserves the `with_pigauto()`
helper name) and supplies: a precise FIML-vs-MI contrast table, an honest
"when to use which", the `with_pigauto()` handoff interface sketch, and a
framing note for the missing-data article (GitHub issue #365).

Companions: Design 59 (`docs/design/59-missing-data-layer.md`, the
authoritative FIML contract -- NOT edited here), Design 67
(`docs/design/67-missing-predictor-design.md`, the gllvmTMB
missing-PREDICTOR lane), Design 04 (`docs/design/04-sister-package-scope.md`,
the where-gllvmTMB-sits map). Part of GitHub issue #332 (missing-data
umbrella); feeds issue #365 (the "Handling missing data" article).

> **Doc-number note.** The next free `docs/design/` slot at the time of
> writing is 71 (existing run: ... 65, 67; 66 is held by an in-flight
> capstone power-study PR per Design 67's header). 68-70 are unused. This
> document takes **71**. The number is cosmetic; the contract anchor
> remains Design 59.

---

## 0. Scope and method

**In scope (design / analysis only):** an evidence-based description of
what `pigauto` does (verified against its public pkgdown site); a precise
contrast between gllvmTMB's frequentist FIML/Laplace path and pigauto's
multiple-imputation (MI) path; honest selection guidance; the
`with_pigauto()` handoff helper interface sketch (shape, not code), the
gllvmTMB surface it would require, and its congeniality caveat; and 3-4
framing sentences for the article.

**Out of scope:** any change to the Design 59 contract; any pigauto
internals beyond its documented surface; any claim that one path
dominates the other.

**Method / evidence rule.** Every factual claim about pigauto below is
sourced to a specific page of its public documentation site
(`https://itchyshin.github.io/pigauto/`), with the page named inline.
Claims about gllvmTMB are sourced to files in this repository. Anything
not directly stated in those sources is marked **(inference)**.

**Source pages consulted (pigauto pkgdown site, fetched 2026-05-31):**

- `index.html` -- purpose, engine blend, workflow steps, input
  requirements, outputs.
- `reference/index.html` -- the function list and one-line descriptions.
- `articles/getting-started.html` -- the worked `impute` ->
  `multi_impute` -> `with_imputations` -> `pool_mi` workflow with code.
- `articles/tree-uncertainty.html` -- `multi_impute_trees()` and the
  Nakagawa & de Villemereuil (2019) tree-uncertainty route.
- `articles/gnn-architecture.html` -- the ResidualPhyloDAE GNN, the blend
  formula, the BM baseline, conformal intervals, MI-draw mechanics.
- `articles/common-pitfalls.html` -- weak-signal, small-validation-set,
  imbalanced-category, and tail-extrapolation cautions.
- `reference/pool_mi.html` -- the `pool_mi()` signature, accepted model
  classes, Rubin's-rules formulae, and output columns.

---

## 1. What pigauto actually does (verified from its docs)

### 1.1 Purpose and one-line scope

pigauto's stated purpose (index page) is: **"Missing trait data should
not stop a comparative analysis."** It "fills gaps in species trait
matrices by combining phylogenetic trees, cross-trait correlations, and
optional environmental covariates, then propagates imputation uncertainty
downstream." The getting-started article expands the acronym as
**"Phylogenetic Imputation via Graph AUTO-encoders."** It is a
**standalone, preprocessing** imputer: it imputes missing cells of a
species x trait matrix *before* the user's analysis, and is **agnostic to
the downstream analysis model**.

### 1.2 The imputation engine (a blended, calibrated predictor)

The engine (index + gnn-architecture pages) blends a phylogenetic
**baseline** with a **graph-neural-network (GNN) correction**, gated
per-trait by a calibration weight:

- **Baseline.** "Brownian-motion conditional imputation for
  continuous/count/ordinal/proportion traits, and phylogenetic label
  propagation for binary/categorical traits" (index). The continuous BM
  baseline is the GLS conditional mean under a BM model on the tree:
  `y ~ N(beta*1, sigma^2 * R)` with `R = cov2cor(vcv(tree))`, giving the
  conditional `mu_M = beta*1 + R_MO R_OO^{-1} (y_O - beta*1_O)` and a
  conditional variance term (gnn-architecture). Discrete traits use
  kernel-weighted label propagation `Pr(y_i = k) propto sum_j A_ij *
  1(y_j = k)` (gnn-architecture).

- **GNN delta.** "An attention-based graph neural network trained on the
  phylogenetic topology, cross-trait correlations, and any user
  covariates" (index). The gnn-architecture page names the model
  **ResidualPhyloDAE**: an encoder MLP over the trait matrix +
  species-level spectral (Laplacian-eigenvector) features + covariates,
  L pre-norm graph-transformer blocks with **per-head learnable
  phylogenetic attention bias** `B_h = -D^2 / (2 beta_h^2)` (D^2 the
  squared cophenetic-distance matrix), and a decoder MLP.

- **Calibrated blend.** The documented inference-time prediction
  (gnn-architecture) is

      yhat_i = (1 - r_cal) * mu_i^{BM/joint-MVN}
             + r_cal * delta_i^{GNN}
             + cov_linear(u_i)

  where `r_cal in (0, gate_cap]` is "a per-trait gate calibrated on a
  held-out validation split" (index), selected by validation grid search.
  "When the baseline is already good enough, the gate closes and the GNN
  stays out of the way" (getting-started).
  *(Design 59 section 1b records a `pred = (1-r_cal)*baseline +
  r_cal*GNN_delta` form and a newer three-way BM/GNN/MEAN blend in local
  specs; the public site shows the BM/GNN form plus an additive
  `cov_linear(u)` covariate term. Treat the exact blend as current, not
  timeless.)*

### 1.3 Uncertainty quantification (conformal + multiple imputation)

pigauto provides two distinct uncertainty layers:

- **Conformal prediction intervals** on a single imputation. "Split
  conformal residual quantile on the val set: `s = q_{1-alpha}(|y -
  yhat|_val)`", giving `yhat_i +- s_t` with ">=95% marginal coverage on
  the original scale" (gnn-architecture). Surfaced as
  `pred$conformal_lower` / `pred$conformal_upper` /
  `pred$conformal_coverage` (getting-started).

- **Multiple imputation (MI) draws** for downstream Rubin pooling. The
  default draws "missing cells from `N(mu, s/1.96)` on the transformed
  scale -- calibrated against actual residuals"; an MC-Dropout alternative
  "runs M stochastic GNN passes in training mode" (gnn-architecture).

### 1.4 The MI workflow (impute -> analyse-each -> pool)

The getting-started and reference pages document a four-function MI
pipeline:

1. `impute(traits, tree)` -- point imputation + conformal intervals;
   returns `$completed` (observed values preserved, NAs filled),
   `$imputed_mask` (logical matrix, TRUE where filled), and the
   `$prediction$conformal_*` bounds.
2. `multi_impute(traits, tree, m = 50L)` -- "Generate M complete datasets
   for multiple imputation" (reference) -- M stochastic completed
   datasets.
3. `with_imputations(mi, function(d) ...)` -- "Fit a downstream model on
   every imputed dataset" (reference). The callback receives each
   completed data frame `d` (and, in the tree-uncertainty route, the
   matching `tree`).
4. `pool_mi(fits)` -- "Pool downstream model fits across multiple
   imputations (Rubin's rules)" (reference).

Worked example (getting-started, verbatim structure):

    mi   <- multi_impute(traits, tree, m = 50L)
    fits <- with_imputations(mi, function(d) {
      lm(log(Wing.Length) ~ log(Mass) + Trophic.Level, data = d)
    })
    pool_mi(fits)

The demoed downstream models are `lm()` and `nlme::gls()` with
`ape::corBrownian()` (getting-started). pigauto is **model-agnostic**:
`pool_mi()` does not care which engine produced the fits, only that each
implements `coef()` / `vcov()` (see 1.6).

### 1.5 Tree (phylogenetic) uncertainty

`multi_impute_trees(traits, trees, m_per_tree = ...)` (tree-uncertainty
article) imputes across a posterior set of `T` trees, producing
`T x m_per_tree` completed datasets, each tagged with its source tree;
`with_imputations()` then fits each with its matching tree and `pool_mi()`
pools across both imputation and tree variation in one Rubin step. The
recommended cheap default is "`T = 50` posterior trees ... one imputation
per tree (`M = 50` total)". The article cites **Nakagawa & de Villemereuil
(2019), Systematic Biology 68(4):632-641** as the canonical
phylogenetic-uncertainty-via-MI approach.

### 1.6 Input requirements

- **Traits:** the imputation target -- missing values (NAs) are allowed
  (index).
- **Tree:** a phylogenetic tree is **required** (index).
- **Covariates (predictors):** the index page states covariates "**Must be
  fully observed.** Numeric columns are z-scored; factor/ordered columns
  are one-hot encoded automatically." (The getting-started article shows a
  `covariates =` argument and helper builders but does **not** restate the
  completeness requirement; the index page is taken as authoritative on
  it.) **This is the load-bearing boundary: pigauto imputes missing
  *traits* but cannot itself handle missing *predictors / covariates*.**

### 1.7 Outputs

- `$completed` (filled matrix) and `$imputed_mask` (index,
  getting-started).
- Conformal bounds `$prediction$conformal_lower/upper` and
  `$conformal_coverage` (getting-started).
- For MI: the set of completed datasets and, from `pool_mi()`, a tidy
  pooled coefficient table.

`pool_mi()` (reference page) has signature

    pool_mi(fits, conf.level = 0.95,
            coef_fun = stats::coef, vcov_fun = stats::vcov,
            df_fun = NULL)

accepts "a list of model fits of length M >= 2" where "any model class
implementing `coef()` and `vcov()` works (e.g. `stats::lm`, `nlme::gls`,
`lme4::lmer`, `glmmTMB::glmmTMB`, `phylolm::phylolm`,
`phylolm::phyloglm`)", applies the standard Rubin combination
`Tvar = W + (1 + 1/M) B` (with `W` the within- and `B` the
between-imputation variance), and returns a data frame with columns
`term, estimate, std.error, df, statistic, p.value, conf.low, conf.high,
fmi` (fraction of missing information) and `riv` (relative increase in
variance). The `coef_fun` / `vcov_fun` arguments let a caller supply
custom extractors for model classes whose `coef()` / `vcov()` do not
match the default shape -- **this is the hook the gllvmTMB handoff uses
(section 3).**

### 1.8 What could NOT be verified

- The **exact current blend** (two-way BM/GNN vs three-way BM/GNN/MEAN):
  the public site shows the BM/GNN + `cov_linear` form; Design 59
  section 1b mentions a newer three-way form in local specs. Not
  reconciled here; treated as "current, not timeless".
- Whether `pool_mi()` dispatches through `broom::tidy()` for any class:
  the reference page describes **custom `coef_fun` / `vcov_fun`
  extractors**, not broom, so this is taken as the supported contract.
  **(inference)** that broom is not on the critical path.
- The precise pigauto **version** behind the rendered site (no version
  string was read from the pages consulted).
- Internal source files named in Design 59 section 1b
  (`phylo_signal.R`, `pagel_lambda.R`, `cross_validate.R`,
  `evaluate_imputation.R`, `henderson_s_inv.R`) were **not** inspected
  for this design (site-only study); their existence is taken from
  Design 59, not re-verified.

---

## 2. FIML vs MI -- the precise contrast

Both paths target the same problem (analysis with missing data under a
missing-at-random working assumption) but factor it differently. gllvmTMB
FIML keeps **one congenial joint model** and integrates the missing
quantities **inside** the likelihood; pigauto MI uses a **separate
imputation model**, generates `M` completed datasets, and pools with
Rubin's rules. They are **complementary, not competitors** (Design 59
section 1b; Schafer & Graham 2002 show the two are asymptotically
equivalent under a correctly specified, congenial model).

| Axis | gllvmTMB FIML / Laplace (Design 59) | pigauto MI |
|---|---|---|
| Where missingness is handled | **In-likelihood**, one fit: missing predictors are latent variables integrated out by Laplace; missing responses are masked (`is_y_observed`) and predicted | **Outside** the analysis: a separate imputation step produces `M` completed datasets, analysed independently |
| Number of models | One (the analysis model *is* the imputation model) | Two stages (imputation model, then the user's analysis model) |
| Congeniality | Automatic -- imputation and analysis share one likelihood, so the two are congenial by construction | The user's responsibility -- the GNN/BM imputation model and the downstream analysis model are separate and may be **uncongenial** (section 3.4) |
| Uncertainty propagation | Joint Hessian (`sdreport`): predictor-imputation uncertainty enters every parameter's SE through the same curvature as the random effects (frequentist; EBLUP + prediction SE) | Rubin's rules: within- + between-imputation variance, `Tvar = W + (1+1/M)B`; reports `fmi`, `riv`; optional conformal intervals on the imputations themselves |
| Inference flavour | Frequentist ML; conditional modes / EBLUPs; Wald / profile / bootstrap CIs. **No** posterior, **no** pooling | Frequentist MI combining rules (Rubin 1987) over `M` analyses; conformal coverage as a distribution-free UQ add-on |
| What it imputes | Missing **responses AND missing predictors** | Missing **traits** only (covariates / predictors **must be complete**, section 1.6) |
| Imputation model class | Structured, parametric, level-aware (phylo / spatial / animal / relmat / latent), tied to the analysis model | Flexible / black-box: attention GNN + BM baseline + covariate-linear term; mixed trait types; tree uncertainty |
| What it REQUIRES | A **fixed, structured analysis model**; a correctly specified joint factorization `p(y|x) p(x)`; the missingness to sit in the response or a modelled predictor | A **tree**; **complete covariates**; a held-out validation split big enough to calibrate the gate; the user to choose `M` and a congenial analysis model |
| Computational cost | One fit (latent dimension grows by the missing-predictor count); no ensemble | One imputer fit/training + `M` analysis fits + pooling; cost scales with `M` (>=50 for stable SEs, >=100*max(fmi) for p-values, per getting-started) |
| Output objects | `predict_missing()` (response cells), reserved `imputed()` (predictor EBLUPs + SE), `fit$missing_data` registry (Design 59 section 4) | `$completed`, `$imputed_mask`, conformal bounds; `M` datasets; `pool_mi()` tidy table with `fmi`/`riv` |
| Diagnostics / gates | Sentinel-invariance, recovery sims, phylo-signal gate, MNAR sensitivity, bootstrap-SE cross-check (Design 59 section 9) | Conformal coverage on val set; weak-signal (`lambda < 0.3`), small-validation-set, imbalanced-category, tail-extrapolation cautions (common-pitfalls) |
| When preferable | Analysis model fixed + structured (our case); missingness in the response or a modelled predictor; want one transparent likelihood | Analysis model varies / is unknown; covariates need flexible/black-box imputation; want reusable completed datasets for arbitrary downstream tools; want tree-uncertainty MI |

**Honest symmetry note.** Neither is uniformly better. FIML is efficient
and transparent *when its joint model is correct*, but a misspecified
covariate model biases estimates and its Laplace SEs can be negatively
biased under non-normality (Design 59 section 3; Allison 2003). MI is
robust to the analysis model varying and can use a far richer imputation
model, but its validity rests on congeniality and a well-calibrated
imputer, and it pays an `M`-fold compute cost. The two converge under a
correct, congenial specification (Schafer & Graham 2002).

---

## 3. When to use which (honest), and the `with_pigauto()` handoff

### 3.1 Decision guidance

**Prefer gllvmTMB FIML (Design 59) when:**

- the **analysis model is fixed and structured** -- a gllvmTMB
  stacked-trait GLLVM with known phylo / spatial / latent structure (our
  case);
- the **missingness is in the response** (masked + predicted) **or in a
  predictor you are willing to model** with a structured, level-aware
  covariate model (`mi(x)`, Design 67);
- you want **one transparent likelihood** and joint-Hessian uncertainty,
  with no completed-dataset ensemble to manage.

**Prefer pigauto MI when:**

- the **analysis model varies or is not yet decided** -- you want
  completed trait matrices to feed *several* downstream tools, or tools
  gllvmTMB's in-model path does not cover;
- the covariate / trait imputation wants a **flexible, black-box**
  model (the attention GNN + BM blend, mixed trait types) rather than a
  structured parametric one;
- you specifically want **phylogenetic-tree-uncertainty MI**
  (`multi_impute_trees()`) or distribution-free **conformal** intervals
  on the imputations;
- you want **imputed datasets as a deliverable** for downstream
  consumers.

**They are complementary.** A user can pick FIML or MI for the *same*
data. A natural division of labour: pigauto imputes the **complete
covariate block** the user wants (its strength), then gllvmTMB FIML
handles **response masking and any remaining modelled missing predictor**
in-likelihood -- though mixing the two on the *same* missing cells
double-counts and is discouraged.

### 3.2 The case the handoff exists for

gllvmTMB FIML's in-model path is **not appropriate** when the missing
covariates need **non-structured, black-box** imputation that the
parametric `mi()` covariate model cannot express -- e.g. many
heterogeneous predictors, strong nonlinear cross-trait structure, or when
the user wants the imputation decoupled from the analysis model entirely.
For those cases gllvmTMB should not pretend to impute in-model; it should
**hand the data to pigauto** for MI and then act as a *downstream analysis
model* inside pigauto's `with_imputations()` / `pool_mi()` loop. That
bridge is `with_pigauto()`.

### 3.3 `with_pigauto()` -- interface sketch (shape, not code)

The helper name `with_pigauto()` is already reserved by Design 59
section 1b. Note the naming relationship: pigauto's own callback driver is
**`with_imputations()`**; `with_pigauto()` is the **gllvmTMB-side
convenience wrapper** that drives pigauto's pipeline with a gllvmTMB fit as
the downstream model and returns a Rubin-pooled gllvmTMB-flavoured result.
It is **optional sugar** -- everything it does can be written by hand with
`pigauto::multi_impute()` + `with_imputations()` + `pool_mi()`.

Intended shape (illustrative; subject to the section 3.5 gllvmTMB-surface work):

    with_pigauto(
      formula,                 # a gllvmTMB analysis formula (traits(...) ~ ...)
      data,                    # data with missing COVARIATES (NAs allowed)
      tree,                    # phylogeny pigauto requires
      ...,                     # passed to gllvmTMB() (family, covariance keywords, control)
      m            = 50L,      # number of imputations (pigauto default)
      trees        = NULL,     # optional posterior trees -> multi_impute_trees()
      pigauto_args = list(),   # covariates=, gate caps, etc. forwarded to pigauto
      effects      = "fixed",  # which gllvmTMB tidy() effect class to pool
      pool         = TRUE      # FALSE returns the M fits unpooled
    )

Behaviour (the bridge, in four steps):

1. **Impute.** Call `pigauto::multi_impute(data, tree, m = m)` (or
   `multi_impute_trees(data, trees, ...)` when `trees` is supplied) to get
   `M` completed datasets. The missing **covariates** are filled by
   pigauto; the gllvmTMB **responses** are passed through unchanged (see
   the section 3.4 caveat on who imputes responses).
2. **Fit-each.** For each completed dataset `d` (and matching tree, in the
   tree-uncertainty route), fit `gllvmTMB(formula, data = d, ...)`. This
   is `pigauto::with_imputations(mi, function(d, tree) gllvmTMB(...))`
   wrapped so the gllvmTMB call is the callback body.
3. **Extract.** From each fit, extract the per-term **estimate + standard
   error** that Rubin pooling needs. The natural source is the existing
   broom tidier `tidy.gllvmTMB_multi()` (`R/methods-gllvmTMB.R:614`),
   which already returns `term / estimate / std.error` for
   `effects = "fixed"` (and `ran_pars` / `cutpoint` classes). See section 3.5.
4. **Pool.** Apply Rubin's rules. Two equivalent routes:
   - Pass the `M` gllvmTMB fits to `pigauto::pool_mi()` with **custom
     `coef_fun` / `vcov_fun`** adapters (section 3.5) so pigauto's existing
     combiner does the work and the user gets pigauto's familiar
     `fmi`/`riv` table; or
   - pool the `M` `tidy()` tables with a small internal Rubin combiner and
     return a gllvmTMB-flavoured tidy table. **Reusing pigauto's
     `pool_mi()` is preferred** -- it is the tested combiner and keeps the
     two packages' MI semantics identical.

`with_pigauto()` returns either the pooled table (`pool = TRUE`) or the
list of `M` fits plus the imputation object (`pool = FALSE`), so advanced
users can pool a custom quantity.

### 3.4 What gllvmTMB must expose (the real work behind the sketch)

The handoff is mostly an **integration / adapter** task, not new engine
work. Concretely gllvmTMB needs:

1. **A multi-fit driver** -- fitting the same formula on `M` datasets.
   This is a thin loop over `gllvmTMB()`; no engine change. (May reuse
   existing multi-fit plumbing.)

2. **A Rubin-poolable extractor contract.** Pooling needs, per quantity,
   an **estimate** and its **SE** (and ideally a full covariance for
   multi-parameter quantities). The audit of this repo found:
   - `tidy.gllvmTMB_multi()` **already returns** `term / estimate /
     std.error` for fixed effects (and `ran_pars` / `cutpoint`) --
     directly poolable for those classes;
   - there are **no `coef.gllvmTMB` / `vcov.gllvmTMB` methods** in
     `NAMESPACE` (only `S3method(tidy, gllvmTMB_multi)` and
     `export(tidy)`), so `pool_mi()`'s **defaults** (`stats::coef` /
     `stats::vcov`) will **not** work out of the box.
   - **Consequence:** the handoff must supply `pool_mi()` with
     **`coef_fun` / `vcov_fun` adapters** built from gllvmTMB's
     `tidy()` / `sdreport` output (estimate vector + a covariance block
     with matching names), OR pool the `tidy()` tables directly. The
     `coef_fun` / `vcov_fun` arguments exist precisely for classes like
     this (pool_mi reference page).

3. **Pooling of the right `extract_*` outputs.** gllvmTMB's scientific
   payload is not only fixed effects -- it is the covariance / correlation
   / communality surface (`extract_Sigma`, `extract_correlations`,
   `extract_communality`, `extract_Omega`, `extract_repeatability`,
   `extract_phylo_signal`, ...; `R/extractors.R`, `R/extract-*.R`). For
   these, the design should specify **which are on a scale where Rubin
   pooling is meaningful**: pooling is well-defined for **unbounded,
   approximately-normal** estimands (fixed effects on the link scale,
   log-variances, Fisher-z-transformed correlations), and **misleading**
   for bounded or non-normal ones (raw correlations near +-1, variances
   near 0, communalities in [0,1]) unless pooled on a transformed scale
   and back-transformed. **Recommendation:** v1 of the handoff pools
   **fixed effects only** (the unambiguous case via `tidy()`); pooling of
   structured-covariance extractors is a **documented later extension**
   with explicit per-extractor scale rules, not part of the first sketch.

No new TMB template, no new `mi()` grammar, and no change to Design 59 are
required for `with_pigauto()` -- it lives entirely above the fit.

### 3.5 The congeniality caveat (must be documented)

The central honest caveat (Design 59 section 1b; Meng 1994 on
congeniality; Schafer & Graham 2002): **pigauto's imputation model and the
gllvmTMB analysis model are separate, and may be uncongenial.** pigauto
imputes covariates with an attention-GNN + BM blend trained on tree +
cross-trait structure + covariates; gllvmTMB then fits a structured GLLVM.
If the imputation model omits structure the analysis model relies on (or
vice versa), the Rubin-pooled SEs can be biased -- typically
**conservative** when the imputer is richer than the analyst, and
**anti-conservative** when it is poorer. The handoff docs must:

- state that **congeniality between pigauto's imputer and the gllvmTMB
  analysis model is the user's responsibility**, not something
  `with_pigauto()` can guarantee;
- recommend that the imputation **include the covariates and structure
  the gllvmTMB model will condition on** (pigauto accepts a `covariates =`
  block; getting-started);
- carry pigauto's own cautions through to the gllvmTMB user
  (common-pitfalls): weak phylogenetic signal (`lambda < 0.3` -- "consider
  whether a phylogenetic imputation method is the right tool at all"),
  small validation sets, imbalanced categorical traits, tail
  extrapolation;
- repeat the **circularity** warning from Design 59 section 3: do not
  impute a trait phylogenetically and then estimate phylogenetic signal in
  that same trait as if observed;
- note that pigauto handles **missing covariates** (which FIML can also
  model via `mi()`) but **not missing responses** -- so a mixed problem
  (missing responses *and* covariates needing black-box imputation) may
  combine pigauto (covariates) with gllvmTMB's response mask, taking care
  not to double-impute the same cells.

### 3.6 Why this is interoperability, NOT an engine mode

Design 59 section 4 / section 1b are explicit: **there is no `engine =
"mi"` inside `miss_control()`.** `mi(x)` (FIML) means "latent missing
predictor *inside* the model"; MI means "multiple imputation *outside* the
model" -- conflating them in one control confuses users. `with_pigauto()`
is therefore a **separate, documented handoff helper**, and the gllvmTMB
docstring already records this (`R/gllvmTMB.R:942`: "There is **no** MI
... engine here; multiple imputation is the separate `pigauto`
workflow"). This design does not change that boundary.

---

## 4. Framing note for the missing-data article (issue #365)

The following 3-4 sentences can be dropped into the gllvmTMB "Handling
missing data" article (or its "See also" / positioning section) to
position FIML as the in-model alternative to pigauto-style MI:

> gllvmTMB handles missing data **inside the model**: missing responses
> are masked and predicted, and missing predictors can be treated as
> latent variables integrated out by the same Laplace approximation used
> for the random effects, so their uncertainty propagates through one
> likelihood with no completed-dataset ensemble and no pooling step. This
> is the frequentist, in-model **alternative to multiple imputation**.
> When you instead want flexible, black-box imputation of *missing
> covariates* -- which the in-model path does not cover -- or imputed
> datasets to reuse across several downstream tools, the sister package
> [`pigauto`](https://itchyshin.github.io/pigauto/) provides
> phylogenetic multiple imputation (a graph-neural-network plus
> Brownian-motion imputer, with conformal intervals and Rubin's-rules
> pooling); a gllvmTMB fit can serve as the downstream analysis model in
> that workflow. The two paths are **complementary**: choose the in-model
> FIML path when the analysis model is fixed and structured and the
> missingness sits in the response or a modelled predictor; choose
> pigauto's multiple imputation when the analysis varies, the covariates
> need black-box imputation, or you want phylogenetic-tree-uncertainty
> multiple imputation.

---

## 5. References (anchors in **bold**)

**pigauto documentation** (public pkgdown site, fetched 2026-05-31) --
`https://itchyshin.github.io/pigauto/`: `index.html`,
`reference/index.html`, `reference/pool_mi.html`,
`articles/getting-started.html`, `articles/tree-uncertainty.html`,
`articles/gnn-architecture.html`, `articles/common-pitfalls.html`.

**Multiple imputation / Rubin's rules** -- **Rubin (1987)** *Multiple
Imputation for Nonresponse in Surveys*, Wiley; **Schafer & Graham (2002)**
*Psych. Methods* 7:147-177 (FIML and MI asymptotically equivalent under a
correct, congenial model); **Meng (1994)** *Statist. Sci.* 9:538-558
(uncongeniality); Barnard & Rubin (1999) *Biometrika* 86:948-955
(MI degrees of freedom -- the `df` pigauto reports).

**FIML foundations** (carried from Design 59 section 11) -- Rubin (1976)
*Biometrika* 63:581-592; Little & Rubin (2019), Wiley; Allison (2003)
*J. Abnorm. Psychol.* 112:545-557 (Laplace/FIML SE caution).

**Phylogenetic imputation + cautions** -- **Nakagawa & de Villemereuil
(2019)** *Syst. Biol.* 68(4):632-641 (tree-uncertainty via MI + Rubin --
pigauto's `multi_impute_trees()` basis); Penone et al. (2014) *MEE*
5:961-970; Johnson et al. (2021) *GEB* 30:51-62; Molina-Venegas (2024)
*MEE* (weak-signal imputation adds noise).

**TMB / Laplace / EBLUP** (the gllvmTMB side; carried from Design 59) --
Kristensen et al. (2016) *JSS* 70(5); Robinson (1991) *Statist. Sci.*
6:15-32 (EBLUP, not posterior).

---

## 6. Out-of-scope handoff context

Live status that stales quickly -- whether `with_pigauto()` is scheduled,
the pigauto version, CI health, commit hashes -- is **not** recorded in
this durable design doc; it belongs in the coordination board / GitHub
issues (#332 umbrella, #365 article). This document is **design / analysis
only**: it specifies the contrast, the selection rule, and the
`with_pigauto()` interface shape, but ships no code and changes no Design
59 contract. Implementation, if greenlit, lands above the fit as an
adapter (section 3.4) with its own slice issue and tests.
