# Design 59 — Model-based missing-data layer for `gllvmTMB` + `drmTMB`

**Status: ACCEPTED shared-contract design (2026-05-31)** — endorsed by the gllvmTMB (Claude) and drmTMB (Codex) leads. This document is the authoritative *contract text*. Cross-team coordination — slice scheduling, blockers, checkpoint outcomes — lives in **GitHub Issues** (the missing-data umbrella + per-slice issues), per the agreed protocol (GitHub Issues = cross-repo ledger; repo-tracked design docs = contract text; no writing into each other's local files). Implementation proceeds per slice — no engine code lands without its slice issue and tests.

**Frequentist maximum-marginal-likelihood (FIML) via TMB-Laplace — a frequentist _alternative to multiple imputation_. No Bayesian path.**
**A shared plan that both teams execute IN PARALLEL** against a common contract (§4b): the gllvmTMB lane (Claude) and the drmTMB lane (Codex) build the *same vocabulary, data contract, `mi()` grammar, output API, and test specs*, but each owns its package's glue and phases. Claude elaborates the gllvmTMB lane; the drmTMB (Codex) team elaborates theirs (§7b).

---

## 1. Context & motivation

Both packages currently handle missing **responses** only partially (gllvmTMB drops missing response cells before building the TMB likelihood; drmTMB complete-cases) and **error** on missing **predictors**. We want an ASReml-style *integrated, model-based* missing-data system exposed as fit-function **arguments**, covering responses and predictors, where the covariate model can inherit the analysis model's biological covariance (phylogeny, animal/relmat, spatial, species, site, latent axes).

It must be **frequentist** — **missing predictors are latent variables integrated out by the Laplace approximation; missing responses are represented by observation masks in the likelihood and predicted from the fitted model**. Point estimates of latent quantities are conditional modes / EBLUPs; uncertainty comes from the joint Hessian (`sdreport`). No MCMC, no priors, no posterior. The surface borrows brms's `mi()` token but swaps Stan-MCMC for TMB-Laplace. Intended outcome: missing response traits, missing predictors, latent trait covariance, phylogeny, spatial structure, and (in gllvmTMB) multivariate borrowing all in **one likelihood** — more transparent than detached multiple imputation because the imputation model is part of the formula, not hidden preprocessing.

**Positioning — this is a frequentist _alternative to multiple imputation_.** One model fit and one likelihood; no ensemble of completed datasets and no Rubin between-imputation pooling. Missing predictors are estimated jointly *inside* the model; missing responses are masked and predicted afterward — the resulting uncertainty propagates through the same Hessian as every other parameter. Multiple imputation stays available as the **sister path** (pigauto, §1b) when its flexibility (rich GNN imputation, mixed trait types, tree uncertainty) is wanted — the two are complementary, and a user can pick FIML or MI for the same data.

## 1b. Relationship to `pigauto` (sister package) — the two-path strategy

`pigauto` ("Fill in Missing Species Traits Using a Phylogenetic Tree") is the **standalone, preprocessing** path: a phylogenetic **trait-imputation engine** — a Brownian-motion / label-propagation baseline blended with a **graph-neural-network** delta (it currently uses *calibrated blends such as* `pred = (1−r_cal)·baseline + r_cal·GNN_delta`, with newer three-way BM/GNN/MEAN calibration in local specs; treat the formula as current, not timeless) — that produces completed datasets and propagates uncertainty by **multiple imputation + Rubin's rules** (`impute()` → `multi_impute(m=50)` → `with_imputations()` → `pool_mi()`), with conformal intervals and tree-uncertainty support (Nakagawa & de Villemereuil 2019). It imputes missing **traits** but **requires covariates to be fully observed**, and is agnostic to the downstream model (it demos `glmmTMB(propto())` and `nlme::gls(corBrownian())`).

This missing-data layer is the deliberate **alternative path**: **in-model, frequentist FIML** — missing predictors are latent variables in the **same** likelihood and missing responses are masked then predicted, no preprocessing, joint estimation; it handles **missing predictors**, which pigauto cannot. The two are **complementary**:

| | `pigauto` (sister) | this layer |
|---|---|---|
| When | impute first, analyse second | impute *inside* the fit |
| Uncertainty | multiple imputation + Rubin's rules | one Laplace likelihood; EBLUP + joint-Hessian SE |
| Imputes | missing **traits** (covariates must be complete) | missing **responses AND predictors** |
| Engine | GNN + BM baseline + conformal | TMB Laplace |
| Downstream model | any (incl. gllvmTMB/drmTMB) | the fit itself |

**Interoperability — kept SEPARATE from the engine (Codex revision).** Do **not** put `engine = "mi"` inside `miss_control()`: `mi()` means "latent missing predictor *inside* the model," while MI means "multiple imputation *outside* the model" — conflating them in one control confuses users. Instead, pigauto interop is a **separate documented workflow / `with_pigauto()` helper**: `pigauto::multi_impute()` → fit gllvmTMB/drmTMB on each completed set → `pool_mi()`. Reuse pigauto's phylo-signal tools (`phylo_signal.R` / `pagel_lambda.R`) and evaluation/calibration framework (`cross_validate.R`, `evaluate_imputation.R`) for our §9 gates; `henderson_s_inv.R` is the same BLUP machinery as our EBLUP output. gllvmTMB/drmTMB become documented downstream targets for pigauto's `with_imputations()`; pigauto is the recommended route for rich GNN imputation, mixed trait types, or tree uncertainty the in-model layer won't initially cover.

## 2. Statistical background (grounded)

- **Why ML is valid here.** FIML is **valid under MAR with distinct parameters and a correctly specified joint model** (Rubin 1976; Little & Rubin 2019; Schafer & Graham 2002) — and efficient when those hold. Because missing **predictors** are where the joint-model specification gets sharp, **model-checking and sensitivity analysis are part of the design**, not an afterthought.
- **Missing covariates → joint factorization.** Factorize `p(y | x, θ_y) · p(x | θ_x)` and marginalize the missing `x` (Ibrahim 1990; Ibrahim, Chen & Lipsitz 1999; Ibrahim, Chen, Lipsitz & Herring 2005).
- **Why Laplace, not EM.** EM (Dempster, Laird & Rubin 1977) is natural only in the Gaussian/linear case; TMB's **Laplace + AD** (Kristensen et al. 2016; Skaug & Fournier 2006) integrates *all* latent quantities — `b`, `b_x`, `x_mis` — in one step. glmmTMB (Brooks et al. 2017) and sdmTMB (Anderson et al. 2025) are the precedents.
- **What "imputed value" means.** The **EBLUP / conditional mode** + prediction SE from the joint precision (Robinson 1991; Harville 1976) — a BLUP, *not* a posterior mean.
- **FIML as the alternative to MI.** FIML and proper multiple imputation are asymptotically equivalent under a correctly specified model (Schafer & Graham 2002; Collins, Schafer & Kam 2001), but FIML needs no completed-dataset ensemble and no Rubin pooling — it is the single-fit, transparent **alternative to multiple imputation**. MI remains available as the pigauto sister path (§1b) for the cases where its flexibility pays off.

## 3. Key implications from the literature (these shape defaults)

- **Structured confounding is the real risk of the ambitious joint model.** When the covariate model and response share the *same* structured field, `β_x` is confounded (Dupont, Marques & Kneib 2023, *Demystifying Spatial Confounding* — the established spatial result; **Wang, Edge, Schraiber & Pennell 2025 preprint, PMC, not peer-reviewed** — the phylogenetic analogue, promising but treat as indicative). **Consequence:** Level-1 **independent** covariate model is the default; the Level-2 joint field is opt-in, with the literature's eigenvector-fixed-effect ("phylo+/spatial+") orthogonalization as its recommended form.
- **Phylogenetic imputation must be conservative + diagnosed.** Phylo imputation *adds noise* when signal is weak (Penone et al. 2014; Johnson et al. 2021; Molina-Venegas 2024). **Consequences:** level-aware inheritance only; a phylo-signal/reliability **gate** before trusting an imputation; warn against **circular** downstream reuse; MNAR sensitivity (trait databases are typically MNAR).
- **Multi-source models often outperform phylogeny-alone and should be allowed** (Gendre et al. 2024; Sánchez-Martínez et al. 2024) — the covariate-model formula accepts arbitrary structured + fixed terms.
- **SE robustness.** Laplace/FIML SEs can be negatively biased under non-normality (Allison 2003) → bootstrap-SE cross-check as a **gate**.
- **MNAR rigor.** Pattern-mixture / delta-adjustment sensitivity (Rotnitzky, Robins & Scharfstein 1998; Vansteelandt et al. 2006; Molenberghs & Verbeke 2007) as a **gate**.

## 4. Locked design decisions — v1 surface is boring & sharp (Codex)

- **Estimator ⟂ engine — but v1 ships only the clean defaults.** **`estimator` is NOT a public v1 argument** — `ML` is the internal default; the public `estimator=` arg (and REML) is **deferred** until REML's likelihood/extractor boundary is proven (avoids a one-legal-value public argument — Codex review #6; open decision §10). V1 **engine is `laplace` only**; `"em"` (Gaussian special case) and `"profile"` are **reserved names, not yet accepted**. **No MI engine in `miss_control()`** (pigauto is the separate §1b path).
- **Surface (the whole v1 API):** `missing = miss_control(response = "drop"|"include", predictor = "fail"|"model", engine = "laplace")` (`response="drop"` = current complete-case; `"include"` = observed-response mask), plus the **`mi(x)`** formula token and `impute = list(x = x ~ covariate-model)`. (No public `estimator=` arg in v1 — ML is the internal default.)
- **Output — responses and predictors are different objects (Codex):** missing **responses** are *predicted/reconstructed*, not latent covariates → **`predict_missing()`** / fitted-row reconstruction; **`imputed()`** is reserved for missing **predictors** (conditional modes/EBLUP + SE). `simulate_imputed()` is **deferred to MD5 / Phase 5** and, if shipped, means **Gaussian-approximation or parametric-bootstrap draws** (never posterior-like). gllvmTMB adds `imputed_traits()`, `imputed_predictors()`. EBLUP/empirical-best-prediction language, never "posterior".
- **Missing responses:** `is_y_observed` **mask** + full response index (not deletion); likelihood gated `if (is_y_observed[i])`.
- **Missing predictors:** `PARAMETER_VECTOR(x_mis)` → `x_full` (observed + latent) in `eta`; covariate-model likelihood added; `x_mis` joins the TMB `random` set, integrated out.
- **Level-aware inheritance** (NOT blind copy): species→phylo/animal/relmat; site→spatial; obs→obs/site/species; trait→trait-cov/latent.
- **Conservative default / ambitious opt-in:** Level-1 independent default; Level-2 joint field opt-in via `correlate_with = "response"` (eigenvector-orthogonalized, §3).
- **NOT in the v1 surface — they are verification gates (§9), not API:** MNAR sensitivity, bootstrap SE, phylo-signal diagnostics. Keep v1 small enough to land.
- **Non-goal — measurement error (Codex alignment).** Missing predictors treat observed `x` as **exact** (only `x_mis` is latent). **Measurement error** — true `x` latent even when observed, needing an observation model `x_obs | x_true` (known SEs / replicates / validation data) — is **out of scope for v1 (Phase 1–3 / MD1–MD5)**. The missing-predictor registry + `fit$missing_data` are designed so a **later ME lane can reuse the latent-covariate machinery** (possible future `me(x, se = se_x)`); **v1 exposes only `mi(x)`** for missing predictors.

## 4b. The shared contract (BOTH teams build to this — the detailed common ground)

This is the coordination spine. Both lanes implement **semantically aligned** (not byte-identical) versions of the following — the contract binds **concepts and tests**, not signatures (gllvmTMB has trait-cell indexing; drmTMB has one/two-response indexing + `rho12`):

- **Vocabulary:** `response = "drop"|"include"`; `predictor = "fail"|"model"`; `engine = "laplace"` (v1; `"em"`/`"profile"` reserved names, not yet accepted); `estimator`: not a public v1 arg (ML internal; deferred — §10); the `mi(x)` token; the `impute = list(var = var ~ model)` covariate-model list; EBLUP / conditional-mode / prediction-SE language (no posterior terms); `predict_missing()` (responses) vs `imputed()` (predictors).
- **Internal data contract** (carried through every fit): `original_row`, `model_row`, `observed_y`, `y`, `weights`, `offsets`, per-distributional-parameter / per-trait model matrices, grouping & structured-effect indices.
- **Fit-object contract (Codex review #5):** a semantically-aligned `fit$missing_data` slot in both packages — `original_row`, `model_row`, `observed_y`, response-pattern counts, predictor registry, slice/version metadata. `nobs()` stays likelihood-contributing; original-row counts surface via `fit$missing_data` / `summary()$missing` / `check_*()`, never by redefining `nobs()`. The registry is designed so a later **measurement-error** lane can reuse the latent-covariate machinery (§4 non-goal).
- **`mi()` parser semantics:** detect `mi(var)` in any model/parameter formula → build a **missing-data registry** `{type, level, missing_index, observed_index, covariate_formula, link/bounds}`; do NOT pass NA through ordinary `model.matrix`.
- **Covariate-model contract:** the `impute` formula reuses each package's existing structured tokens (`phylo()/spatial()/animal()/relmat()` + fixed terms); level-aware default; independent Level-1 unless `correlate_with="response"`.
- **TMB hook contract:** `x_mis` (+ `b`, `b_x`) declared random and integrated by Laplace; the covariate prior reuses the package's existing sparse `Ainv`/`GMRF(Q)` machinery (no dense `n²`).
- **Output API names:** `predict_missing()`, `imputed()`, and `simulate_imputed()` (a **reserved/deferred MD5 name**, per §4) — **aligned names and return fields** (EBLUP + SE semantics), not identical signatures.
- **Shared TEST specs (written first):** the recovery / known-answer / coverage tests each lane must pass at each slice (§9). Tests are the binding contract — shared *design + tests first; duplicated helper code; package extraction only after Phase 2*.

## 5. Architecture — shared design first, code later

Per Codex: **shared vocabulary, contract, and tests first; duplicated helper code initially; extract a shared package only after Phase 2.** gllvmTMB and drmTMB have different data shapes and formula grammars, so the "shared layer" is a **design contract + test suite (§4b)**, not shared code on day one.

**gllvmTMB glue (Claude elaborates; line-refs verified against `main` `2c02b51` in the Phase 0 audit, `docs/dev-log/after-task/2026-05-31-missing-data-phase0-audit.md`):** args at `gllvmTMB()` `R/gllvmTMB.R:360`; response drop currently at `R/gllvmTMB.R:638-700` (`drop_missing_response_rows()`) + the wide pivot `R/traits-keyword.R:366-372` (`pivot_longer(values_drop_na=TRUE)` — gate these for the mask, **before** the pivot); intercept `mi()` columns after `model.frame(..., na.action = na.pass)` at `R/fit-multi.R:937-938` (errors on NA predictor at `:1010-1014`); append `"x_mis"` to `random` at `R/fit-multi.R:2416-2435`, `MakeADFun` at `:2456-2460`; reuse the sparse `Ainv_phy_rr` from the phylo block; `src/gllvmTMB.cpp` likelihood loop `:1366` + family blocks `:1372-1541` (no per-obs gate yet) gets the `is_y_observed` mask, `x_full` reconstruction + covariate nll.

**drmTMB glue (Codex elaborates, §7b):** args at `drmTMB()` `R/drmTMB.R:86`; intercept after per-parameter `model.frame`/`model.matrix` `R/drmTMB.R:767-781` (+ `R/sparse-fixed.R`); append `"x_mis"` to `spec$random_names` `R/drmTMB.R:221-225`; reuse `animal(..., Ainv=)` `R/formula-markers.R:124`; the bivariate partial-pair likelihood in `src/drmTMB.cpp`.

## 6. Predictor mechanics in detail (the hard part)

Observed-data likelihood, missing `x` integrated out jointly with the random effects:

  `L(θ) = ∫ p(y_obs | x_obs, x_mis, b, θ_y) · p(x_obs, x_mis | b_x, θ_x) · p(b, b_x | θ_b) d x_mis db db_x`

In TMB: declare `b`, `b_x`, `x_mis` in the `random` set; Laplace replaces the integral with the joint mode + Gaussian curvature; AD gives exact marginal-likelihood gradients; outer optimization maximizes over `θ`. `sdreport` then yields `x̂_mis` (conditional mode = EBLUP) + SE from the inverse joint Hessian block. Phylo covariate model `x_species ~ N(α, σ_x² A)` = `GMRF(Q_A)`, `Q_A = A⁻¹`, reusing the existing sparse `Ainv`. **Identifiability guard:** default independent fields identify `β_x`; `correlate_with="response"` adds eigenvector fixed effects to avoid confounding (§3).

## 7. Phased rollout (shared phase arc; each team builds its lane in parallel)

- **Phase 0 — audit** (gllvmTMB) / **MD0** (drmTMB): confirm complete-case gates, model-frame assumptions, extractor row counts, TMB data shapes. Stop before syntax.
- **Phase 1 — response-missingness contract.** `miss_control(response="include", predictor="fail")`; `is_y_observed` mask + original-row IDs; **`predict_missing()`** (not `imputed()`) for missing response cells. gllvmTMB: formalize existing drop→mask. drmTMB MD1 (univariate) + **MD2 bivariate partial pairs** (§7b). *(The "easy" win.)*
- **Phase 2a — one continuous OBSERVATION-level missing predictor, FIXED covariate model** (≙ drmTMB MD3a; Codex review #1). `mi(x)` + `impute = list(x = x ~ fully_observed_predictors)` — no random covariate block. Minimal viable joint model: `x_mis` latent, Gaussian covariate nll, `imputed()` EBLUP.
- **Phase 2b — obs-level missing predictor with a grouped random intercept** (≙ drmTMB MD3b). `impute = list(x = x ~ 1 + z + (1|group))`, a separate `b_x` block kept independent of the response random effects.
- **Phase 2c — GROUP/SPECIES-level missing predictor broadcast to observation rows** (≙ drmTMB MD4). The **level-mismatch index** (group-level value used at obs level — brms-style) is a **first-class feature**; validate one observed value per group.
- **Phase 3 — phylogenetic missing predictors (flagship).** `impute = list(body_mass = body_mass ~ 1 + phylo(1|species, tree=tree))`, Level-1 independent default; the phylo-signal/reliability + circularity/MNAR **gates** (§9) apply.
- **Phase 4 — spatial / animal / relmat + gLLVM multivariate borrowing + multi-source covariate models + Level-2 joint field (eigenvector-orthogonalized).**
- **Phase 5 — non-Gaussian / bounded / categorical predictors.** lognormal/Gamma, beta/logit-normal, Poisson/NB, ordinal threshold; **factors last**.

## 7b. drmTMB lane — Codex co-design (slices MD0–MD5 + bivariate partial pairs)

*The drmTMB (Codex) team owns and will further elaborate this lane in their own design doc; captured here so the shared contract stays in sync.*

**Current boundary (confirmed, Codex):** complete-case gate at `R/drmTMB.R:3502` (line 3484 starts variable collection); bivariate Gaussian drops the whole pair if `y1` or `y2` is missing; the paired residual-`rho12` likelihood at `src/drmTMB.cpp:1985` assumes both responses present. Not an observed-data likelihood; `nobs()`/fitted/residuals report fitted rows.

**Bivariate Gaussian partial pairs (MD2 — drmTMB-specific):** three row patterns — both observed → `log p(y1,y2 | μ1,μ2,σ1,σ2,ρ12)`; only `y1` → `log p(y1|μ1,σ1)`; only `y2` → `log p(y2|μ2,σ2)`. One-response rows inform their marginal location/scale but **NOT `ρ12`** (complete pairs are the residual-correlation evidence). Diagnostics report complete-pair vs one-response counts separately. **Both-responses-missing rows are kept in original-row accounting** (zero likelihood, still predictable), not dropped/errored (Codex review #3). A **weak-identifiability warning** fires when complete pairs are too few to identify `ρ12` relative to one-response rows (Codex review #4). **Dense known-`V` excluded** from the first response mask (needs component-level slicing) — deferred. *(gllvmTMB analog: an observed trait cell informs its own species mean/loadings, but cross-trait species correlation needs co-observed cells.)*

**drmTMB slice ladder (maps onto §7):**
| Slice | Scope | Stop |
|---|---|---|
| MD0 | source audit | before syntax |
| MD1 | response mask API (univariate Gaussian) + original-row IDs + `observed_y` | before predictors/EM/summaries/families |
| MD2 | bivariate partial `y1`/`y2` patterns + pair-vs-one-response diagnostics (no dense `V`) | before known-`V` slicing / mixed-response families |
| MD3 | continuous Gaussian `mi()` (= Phase 2a) | before structured covariate models |
| MD4 | structured `mi()` (`phylo/spatial/animal/relmat`, level-aware) | before auto-inheritance / joint y–x field |
| MD5 | imputation summaries: `imputed()` (predictors) + `predict_missing()` (responses), conditional modes + likelihood SE | before posterior terms / credible intervals / MI pooling |

**Out of scope (Codex):** bipartite host–parasite phylogenetic models, higher-dimensional multivariate, Bayesian imputation, external MI workflows.

## 8. Cross-team coordination & PARALLEL execution protocol

**Both teams run simultaneously against the §4b shared contract.** No code collision because the shared layer is *design + tests*, not shared code initially; each team owns its package's glue and phases.

1. **Agree the §4b shared contract** (vocabulary, data contract, `mi()` semantics, output API names, test specs) — the single binding artifact.
2. Promote this plan into a **shared design doc** in **both** repos: `gllvmTMB/docs/design/NN-missing-data-layer.md` and `drmTMB/docs/design/NN-missing-data-layer.md`; add a **`drmTMB/docs/dev-log/coordination-board.md`** entry. The drmTMB team elaborates §7b (their "bets") in their doc; Claude elaborates the gllvmTMB lane.
3. **Parallel cadence:** Phase 0/MD0 audits in parallel → Phase 1/MD1(+MD2) in parallel → **sync checkpoint** (re-confirm shared contract still holds) → Phase 2a/MD3 → checkpoint → … Each checkpoint reconciles the shared vocabulary + test suite before the next slice.
4. **Reviews:** Rose (scope honesty) + Fisher (covariate-model identifiability, §3) before Phase 2a lands; Boole confirms the `mi()` formula-grammar slot in each parser.
5. **Hosting (§10):** duplicated helper code through Phase 2; extract a shared package only after the surface stabilizes.

## 9. Verification (gates — per slice, per package)

- **Recovery sims** (Curie): known missingness + covariate structure; recover analysis-model `β` AND the missing values; EBLUP point recovery within band + **SE/interval coverage** at nominal level.
- **Deterministic match (Phase 1/MD1):** independent univariate Gaussian with missing responses equals the complete-case coefficient/likelihood on observed rows, original-row accounting preserved.
- **Sentinel-invariance (Phase 1/MD1 — SHARED spec, both lanes; Codex review #2):** set the missing-response sentinel to two very different values (`0` and `1e6`) → the fit (logLik, coefficients, gradient) is **byte-identical**; any difference means a sentinel leaked past the `observed_y` mask.
- **Weak-identifiability warning (Codex review #4):** few complete pairs / co-observed cells relative to one-response rows → warn (`ρ12` in drmTMB; cross-trait species correlation needs co-observed cells in gllvmTMB).
- **Bivariate pattern check (MD2):** independent likelihood check of all three patterns; one-response rows inform only their marginal; `ρ12` identified by complete pairs.
- **Phylo recovery (Phase 3):** high vs low phylogenetic signal — borrowing helps when strong, **degrades to ≈independent when weak** (matching Penone/Johnson/Molina-Venegas); the **phylo-signal gate** flags the weak case.
- **Identifiability check (Phase 4):** confirm `β_x` bias under a shared-field joint model and that eigenvector orthogonalization removes it (reproduce Dupont 2023 / Wang 2025-preprint remedy on a sim).
- **Gates (not v1 API):** bootstrap-SE cross-check (Allison caution); **`sensitivity_mnar(delta=)`**; phylo-signal/reliability diagnostic. These run in verification; they are not in the §4 surface.
- **Non-regression:** complete-data fits unchanged when no `mi()`/missing cells present (mask/registry is a no-op).
- Local `devtools::test()` + `pkgdown::check_pkgdown()` + `R CMD check`; honest fitted-vs-planned status. Staged user-facing claims per §7b.

## 10. Open decisions (to confirm at approval)

1. **Shared-layer hosting** — shared **design + vocabulary + tests now**; **duplicated helper code through Phase 2**; **extract a shared package only after Phase 2** proves the surface. (Codex-endorsed.)
2. **REML scope** — **deferred from the v1 public surface**; ML is the clean default. Revisit only after Phase 0 proves the exact Gaussian-only boundary where REML's likelihood + extractors are well-defined.
3. **Ambitious joint field** — ship the eigenvector-orthogonalized form from Phase 4, or defer the joint field until the independent default is proven?

## 11. Evidence base (curated; anchors in **bold**)

**Frequentist foundations** — Rubin (1976) *Biometrika* 63:581–592; Little & Rubin (2019) 3rd ed., Wiley; **Schafer & Graham (2002)** *Psych. Methods* 7:147–177; von Hippel (2009) *Sociol. Methodol.* 39:265–291; Enders (2010/2022) Guilford; Allison (2003) *J. Abnorm. Psychol.* 112:545–557; Dempster, Laird & Rubin (1977) *JRSS-B* 39:1–38.
**Missing covariates in GLMs** — Ibrahim (1990) *JASA* 85:765–769; Ibrahim, Chen & Lipsitz (1999) *Biometrics* 55:591–596; **Ibrahim, Chen, Lipsitz & Herring (2005)** *JASA* 100:332–346.
**Latent-field / measurement-error** — Gómez-Rubio, Cameletti & Blangiardo (2019) arXiv:1912.10981; Carroll, Ruppert, Stefanski & Crainiceanu (2006) CRC; Bürkner brms missing-values vignette.
**TMB / Laplace / EBLUP** — **Kristensen, Nielsen, Berg, Skaug & Bell (2016)** *JSS* 70(5); Skaug & Fournier (2006) *CSDA* 51:699–709; Brooks et al. (2017) *R Journal* 9(2):378–400; Anderson, Ward, English, Barnett & Thorson (2025) *JSS* 115(2); **Robinson (1991)** *Statist. Sci.* 6:15–32; Harville (1976) *JASA* 71:320–330; ASReml (Gilmour et al.).
**Structured confounding** — Dupont, Marques & Kneib (2023) arXiv:2309.16861 (spatial, established); **Wang, Edge, Schraiber & Pennell (2025 preprint, PMC — not peer-reviewed)** (phylogenetic; indicative).
**Phylo / ecological imputation + cautions** — Bruggeman et al. (2009) *NAR* 37:W179–W184; Goolsby, Bruggeman & Ané (2017) *MEE* 8:22–27; Penone et al. (2014) *MEE* 5:961–970; **Molina-Venegas (2024)** *MEE*; Johnson, Isaac, Paviolo & González-Suárez (2021) *GEB* 30:51–62; Nakagawa & Freckleton (2008) *TREE* 23:592–596 & (2011) *BES* 65:2049–2060; Gendre et al. (2024) *MEE* 15:1624–1638; Sánchez-Martínez et al. (2024) *MEE*; Nakagawa & de Villemereuil (2019) *Syst. Biol.* (tree uncertainty; used by pigauto).
**JSDM / gLLVM** — Warton et al. (2015) *TREE* 30:766–779; Ovaskainen et al. (2017) *Ecol. Lett.* 20:561–576; Hui (2016) *MEE* 7:744–750.
**MNAR sensitivity** — Rotnitzky, Robins & Scharfstein (1998) *JASA* 93:1321–1339; Vansteelandt et al. (2006) *Statist. Sinica* 16:953–979; Molenberghs & Verbeke (2007) Wiley.

*(Scout verification flags: Wang et al. 2025 is a non-peer-reviewed preprint — cite as such; Harville 1976 / Henderson via Robinson 1991 survey.)*

## 12. Out-of-scope handoff context

Live status that stales quickly — CI health, commit hashes, queued side-items (`animal_unique(1+x|id)` routing; spatial-slope base `extract_Sigma`; the red `test-spde-slope-base-engine.R:145` tolerance fix; `cluster2`) — is tracked in the coordination-board / session memory, **not** in this durable design doc. Implementation of this plan is deferred; both teams start at Phase 0 / MD0 when greenlit.
