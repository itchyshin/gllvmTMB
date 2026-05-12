# gllvmTMB Methods Paper — Outline (draft)

**Status**: very-early draft outline (2026-05-12). Phase 6 prep
per `ROADMAP.md`. The outline is structural -- section headings,
expected content, open questions, and target word counts -- not
draft prose. The maintainer + Pat / Darwin / Boole / Gauss /
Noether revise this outline before any prose drafting begins.

**Target venue**: Journal of Statistical Software (JSS) or a
similar methods-software journal (Methods in Ecology and
Evolution methods article; PLOS Computational Biology software
note). JSS is the most common venue for the TMB-family papers
(Kristensen et al. 2016, glmmTMB Brooks et al. 2017, sdmTMB
Anderson et al. 2025). Target length: 25-35 typeset pages.

**Authorship**: per `inst/CITATION` and `Authors@R`, Nakagawa
is the sole author of the package. The methods paper authorship
is the maintainer's call; this outline assumes Nakagawa as
first/corresponding author.

## Title (candidates)

- **gllvmTMB: stacked-trait, long-format multivariate generalised
  linear latent variable models with TMB** (matches the package
  Title field; verbose but precise)
- **gllvmTMB: a TMB engine for multivariate GLLVMs with
  phylogenetic and spatial extensions** (shorter; foregrounds the
  three things the package adds over `gllvm`)
- **One engine, many traits: fast multivariate GLLVMs in
  gllvmTMB** (catchier; less precise)

Decision deferred.

## Abstract (≈200 words)

Outline:

1. **The gap.** Ecological, evolutionary, behavioural, and
   morphometric studies routinely measure several traits per
   unit. Joint modelling -- of cross-trait covariance,
   phylogenetic structure, spatial structure, and mixed-family
   responses -- requires a multivariate stacked-trait engine.
   Existing options (`gllvm` for VA-GLLVM, `MCMCglmm` for
   Bayesian phylogenetic multivariate, `brms` for general
   Bayesian, `glmmTMB` for single-response GLMMs) each cover
   part of the surface but leave gaps.
2. **What gllvmTMB does.** Two user-facing data shapes (long
   format with `(unit, trait)` rows; wide format with `(unit,
   trait)` matrix or wide data frame). A 3 x 5 covariance
   keyword grid pairing correlation structure (`none`,
   `phylo_*`, `spatial_*`) with mode (`scalar`, `unique`,
   `indep`, `dep`, `latent`). Mixed-family per trait. Engine
   built on Template Model Builder for Laplace-approximated
   maximum-likelihood inference.
3. **Validation.** Simulation recovery on four canonical use
   cases (morphometrics, joint species distribution modelling,
   behavioural syndromes, phylogenetic comparative).
   Comparator validation against `gllvm`, `MCMCglmm`, and (for
   single-response cases) `glmmTMB`.
4. **Software.** R package at https://github.com/itchyshin/gllvmTMB,
   GPL-3 licensed, pre-CRAN preview at v0.2.0.

## 1. Introduction (≈3-4 pages)

### 1.1 The multi-trait modelling gap

Motivating examples (one paragraph each):

- **Joint species distribution modelling**. Site x species
  occurrence matrices; the user wants species loadings on a
  shared environmental gradient plus residual cross-species
  covariance.
- **Functional biogeography**. Site x species x trait cube;
  the user wants to map trait composition across an
  environmental gradient.
- **Morphometrics**. Individual x measurement matrix; the user
  wants a size-and-shape decomposition with explicit
  trait-specific residual variances.
- **Behavioural syndromes**. Individual x trait matrix with
  repeated measurements; the user wants behavioural-axis
  scores and reaction-norm slopes.
- **Phylogenetic comparative**. Species x trait matrix with a
  known phylogeny; the user wants phylogenetic signal per trait
  and cross-trait covariance with phylogenetic structure.
- **Meta-analysis**. Study x outcome matrix with a known
  sampling covariance; the user wants `meta_known_V(V = V)`.

The shared problem: cross-trait covariance is the inferential
target, but each domain has its own machinery and its own
software. gllvmTMB unifies the engine.

### 1.2 Related software (≈1 page)

A condensed version of `docs/design/04-sister-package-scope.md`
(see PR #48). Per-package position:

- `gllvm` (Niku et al.): the foundational multivariate GLLVM
  package. Variational approximation or Laplace; numeric
  response matrix input; less syntactic surface. gllvmTMB
  positions as the TMB-Laplace alternative with formula
  grammar, the 3 x 5 keyword grid, and integrated phylogenetic
  / spatial paths.
- `glmmTMB` (Brooks et al. 2017): the reference TMB single-
  response GLMM package. gllvmTMB extends with the multi-trait
  stacked layer and the latent factor covariance keywords.
- `sdmTMB` (Anderson et al. 2025): the reference single-
  response spatial TMB package. gllvmTMB inherits the
  SPDE / mesh code and reuses it for the multivariate spatial
  layer.
- `MCMCglmm` (Hadfield 2010): the canonical Bayesian
  multivariate phylogenetic GLMM. gllvmTMB provides the
  ML / REML alternative with faster runtime.
- `brms` (Bürkner 2017): the general Bayesian alternative.
  gllvmTMB provides ML / REML with profile-likelihood CIs.

### 1.3 What this paper adds

1. A unified stacked-trait formula grammar (the 3 x 5 keyword
   grid).
2. Two parallel data shapes (long / wide) reaching the same
   engine.
3. Phylogenetic and spatial extensions in one engine, with the
   four-component decomposition explicit:
   `Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy)`,
   `Sigma_non = Lambda_non Lambda_non^T + diag(s_non)`,
   `Omega = Sigma_phy + Sigma_non`.
4. Simulation recovery on each canonical use case.
5. ML / REML inference with profile-likelihood, Fisher-z Wald,
   and bootstrap CI options.

## 2. Methods (≈10-12 pages)

### 2.1 The stacked-trait model

Long-format representation: one row per `(unit, trait)`
observation, with covariance keywords on the formula RHS.

The full model in mathematical notation:

```
y_{i,t} = mu_t + eta_{i,t} + e_{i,t}
mu_t        = trait-specific fixed-effect intercept (per-trait)
eta_{i,t}   = sum_K (lambda_{t,k} u_{i,k}) + s_t * v_{i,t}     # latent + unique
            + sum_K (lambda_phy_{t,k} z_{i,k}) + s_phy_t * w_{i,t}  # phylo decomposition
            + sum_K (lambda_sp_{t,k} q_{i,k}) + s_sp_t * r_{i,t}    # spatial decomposition
e_{i,t} ~ Family_t(...)
```

where:
- `u, v` are unit-level latent variates and unit-level unique
  variates;
- `z, w` are phylogenetically-correlated latent and unique
  variates (correlation kernel: `phylo_vcv` or `phylo_tree`'s
  implied A inverse);
- `q, r` are spatially-correlated latent and unique variates
  (correlation kernel: SPDE GMRF on the supplied mesh).

The four-component covariance decomposition is then:

```
Sigma_total = Lambda Lambda^T + diag(s)
            + Lambda_phy Lambda_phy^T + diag(s_phy)
            + Lambda_sp Lambda_sp^T + diag(s_sp)
            + residual_t,
```

with `residual_t` the family-specific (Gaussian / binomial /
Poisson / etc.) residual scale.

### 2.2 The 3 x 5 covariance keyword grid

(Reproduces the canonical grid from `AGENTS.md` and `CLAUDE.md`,
with one paragraph per cell explaining when to use it.)

### 2.3 The two data shapes

Long: `gllvmTMB(value ~ ..., data = df_long, unit = "...")`
Wide: `gllvmTMB_wide(Y, ...)` accepting matrix or wide data
frame.

`traits(...)` formula LHS marker is the parser-internal path
with compact RHS sugar. (Show the long form / sugar form / matrix
form side by side -- the three-way fit pattern from the
morphometrics article.)

### 2.4 Inference

- Laplace approximation via TMB.
- Optimisation via `nlminb()` or `optimx()`.
- Standard errors via `sdreport()`.
- CIs: Wald (default), profile-likelihood, Fisher-z (for
  correlations specifically), bootstrap.

### 2.5 Phylogenetic representation

Sparse A inverse following Hadfield & Nakagawa (2010); details
on the matrix construction and the TMB template's handling of
the sparse precision.

### 2.6 Spatial representation

SPDE / GMRF approximation following Lindgren et al. (2011),
inherited from `sdmTMB`. Mesh construction via `fmesher`.

### 2.7 Mixed-family fits

`family = list(...)` keyed by trait. The engine routes each
row to its family-specific likelihood via `family_id_vec`.

## 3. Simulation studies (≈4-5 pages)

For each canonical use case, simulate a known DGP, fit with
`gllvmTMB`, and check recovery:

1. **Morphometric ordination** (T = 5 traits, n = 100
   individuals, rank d = 2): recover Lambda up to rotation and
   sign; recover unique variances; recover trait covariance.
2. **Joint species distribution model** (T = 20 species, n =
   200 sites, binomial responses, rank d = 3 + env covariates):
   recover loadings, env slopes, and species residual
   covariance.
3. **Behavioural syndromes** (T = 4 traits, n = 50 individuals
   with repeated measures, mixed-family): recover individual-
   level covariance and reaction-norm slopes.
4. **Phylogenetic comparative** (T = 6 traits, n = 100 species,
   known phylogeny, four-component decomposition): recover both
   the phylo and non-phylo components; verify
   `compare_dep_vs_two_U()` and `compare_indep_vs_two_U()`
   diagnostics.

Each simulation uses fixed seeds. Recovery is evaluated on the
5-row alignment table (per the `add-simulation-test` skill):
symbolic parameter vs estimated value vs sampling distribution.

## 4. Applied examples (≈4-5 pages)

One worked example per canonical use case. Each example shows:

- The data, with citation if from a published study.
- The model formula (long-format canonical + wide-format
  matrix-in side by side).
- The fit + a key extractor output (loadings, correlations,
  communality, or ordination plot).
- An interpretive paragraph naming the biological / behavioural
  / morphometric meaning.

This mirrors the Tier-1 articles already in
`vignettes/articles/`; the paper version is more condensed.

## 5. Comparator validation (≈2-3 pages)

Cross-check against established packages on shared use cases:

- **gllvmTMB vs `gllvm`**: same data, both packages fit; compare
  log-likelihood, loadings (up to rotation), and trait
  covariances. Expect agreement within numerical tolerance.
- **gllvmTMB vs `glmmTMB`**: single-response slice (e.g., one
  trait fitted alone with `glmmTMB`'s random intercept) should
  match the per-trait marginal from gllvmTMB.
- **gllvmTMB vs `MCMCglmm`**: multivariate phylogenetic slice;
  expect agreement on point estimates within MCMC sampling
  noise. Speed comparison: gllvmTMB seconds-to-minutes;
  MCMCglmm minutes-to-hours.

## 6. Discussion (≈2-3 pages)

### 6.1 Strengths

- Unified formula grammar across non-phylo / phylo / spatial.
- Two data shapes; users pick the one matching their data on
  disk.
- TMB / Laplace speed.
- Mixed-family per trait.
- Profile-CI + Wald + bootstrap options.

### 6.2 Limitations and future work

- Random slopes (`(1 + x | g)` syntax) are not yet implemented.
- Zero-inflated count families (zip / zinb) are planned but not
  yet in the engine.
- SPDE barrier meshes are inherited-but-not-validated for the
  multivariate case.
- Bayesian inference is out of scope (use `MCMCglmm` or `brms`).

### 6.3 Software development practice

A brief paragraph naming the development pattern: the dual-team
(Claude / Codex) collaboration model, the after-task discipline,
the Shannon coordination audits. This is not central to the
methods paper but worth a paragraph for software-engineering
readers.

## 7. Code availability and reproducibility (≈0.5 page)

- Package: `https://github.com/itchyshin/gllvmTMB`
- License: GPL-3
- Reproducible code for every figure / simulation in the paper:
  archived as a Zenodo deposit at submission time.
- Vignettes (Tier-1 articles in
  `vignettes/articles/`) are the long-form companion to the
  paper.

## 8. Acknowledgements (draft)

Acknowledge:

- The TMB project (Kristensen et al. 2016) for the engine.
- The `sdmTMB` team (Anderson, Ward, English, Barnett) for the
  inherited SPDE / mesh code.
- The `gllvm` team (Niku, Hui, Warton, Taskinen) for the
  conceptual foundation.
- The `MCMCglmm` (Hadfield) and `brms` (Bürkner) packages as
  Bayesian comparators.
- The maintainer's lab / collaborators (specific people TBD by
  the maintainer).
- Funding sources (TBD).

## 9. Author contributions

(per JSS / journal convention; CRediT taxonomy)

- **Nakagawa**: conceptualisation, methodology, software,
  validation, formal analysis, writing -- original draft.
- (Additional authors TBD by the maintainer if collaborators
  are added.)

## 10. References

(BibTeX-style; mirrors `inst/CITATION` for the package +
related-software citations plus the applied / methodological
references for each simulation and applied example.)

Core citations (already known):

- Kristensen et al. (2016) TMB. JSS 70(5).
- Anderson et al. (2025) sdmTMB. JSS 115(2).
- Hadfield & Nakagawa (2010) phylogenetic mixed models.
- Niku et al. (2019) gllvm. Methods Ecol Evol.
- Brooks et al. (2017) glmmTMB. The R Journal.
- Hadfield (2010) MCMCglmm. JSS 33(2).
- Bürkner (2017) brms. JSS 80(1).
- Lindgren et al. (2011) SPDE/GMRF approach.
- Warton et al. (2015) gllvm-style methods.

Plus applied / domain citations for each simulation study (TBD).

## Open questions for the maintainer

1. **First author + co-authors**: who else is on the paper?
2. **Target venue**: JSS, MEE, or a software-note journal?
3. **Simulation scope**: four canonical use cases (as above), or
   a subset?
4. **Applied example datasets**: which published datasets are
   we allowed to redistribute / cite?
5. **Comparator-validation depth**: a serious benchmark study or
   a brief illustration?
6. **Submission timeline**: target submission month / year?
7. **CRAN-first vs paper-first**: are we waiting for CRAN
   acceptance before paper submission, or going parallel?

## What this outline is NOT

- Not draft prose. Each section is bullet points + structure;
  the actual writing happens after the outline is ratified.
- Not the final author list, dataset selection, or venue
  decision. Those are maintainer calls.
- Not a substitute for the existing `vignettes/articles/`
  Tier-1 examples. Those remain the long-form companion; the
  paper is the condensed methods summary.
- Not a release announcement. The release blog post is a
  separate artefact (when the time comes).

## Next actions

1. Maintainer reviews the outline structure and answers the
   "open questions" section above.
2. After ratification, a Phase 6 PR drafts the actual prose for
   each section, one section at a time, with the relevant role
   (Pat / Darwin / Gauss / Noether / Fisher) reviewing per
   section.
3. Simulation studies (section 3) become Codex work: produce
   the simulation scripts, recover parameters, generate figures.
4. Applied examples (section 4) cross-reference the Tier-1
   vignettes; one figure per example.
5. Comparator validation (section 5) becomes a separate Codex
   PR: cross-check scripts against `gllvm`, `glmmTMB`,
   `MCMCglmm`.
6. References list (section 10) gets filled in continuously as
   the prose is drafted.
