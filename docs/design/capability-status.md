# gllvmTMB capability status (R twin of GLLVM.jl)

GENERATED FILE -- edit `dev/gapclose/build-capability-status.R`, not this file directly. Regenerate with `Rscript dev/gapclose/build-capability-status.R`.

Mission Control input for the R side of the gllvmTMB <-> GLLVM.jl twin board. Every row here is machine-derived from `docs/design/35-validation-debt-register.md`, the honest validation-debt ledger -- this file adds no new claims, it only translates that ledger's vocabulary into the shared R<->Julia status vocabulary GLLVM.jl's own `docs/design/capability-status.md` uses, so the two can be joined by `tools/parity_ledger.R`.

**Provenance.** Source: `docs/design/35-validation-debt-register.md` at the commit this file was generated against. Row names are copied byte-for-byte from GLLVM.jl's ledger wherever the concept is genuinely shared (both ledgers already describe those cells in R's own vocabulary). Where the R-canonical name differs from GLLVM.jl's spelling of the same concept, the `Aliases` column carries GLLVM.jl's exact string so `tools/parity_ledger.R` still joins them.

**Vocabulary (translated from the register's `covered / partial / opt-in / blocked` 4-state vocabulary, `docs/design/35-validation-debt-register.md` Vocabulary section):**

- `implemented` -- register status `covered`: a test file with concrete assertions at the depth advertised.
- `scope-limited` -- register status `partial` or `opt-in`: tests exist but coverage is shallower than advertised, or the capability needs a non-default argument. `scope-limited (opt-in)` marks the opt-in case.
- `point-fit-recovery` -- a `scope-limited` row whose register text specifically scopes the evidence to point estimation / recovery, with no interval or calibration claim (used for the ISDM rows).
- `planned` -- register status `blocked` (or the parser-syntax `claimed` / `reserved` values, if either leaks into a mapped row): advertised but currently broken, undefined, or not yet built.
- `rejected` -- register status `blocked`, where the register's OWN text says the capability is withdrawn or deliberately refused by decision (not merely untested). See `FORCE_REJECTED` in the generator script for the exact quotes.

**Known name collisions** (same token, different meaning on each side -- see the row-level notes below and `tools/parity_ledger.R`'s `--check-names` mode, which asserts these never join to the wrong Julia row): `cumulative_logit`, `categorical`, `ordinal_probit` (vs Julia's combined `ordinal_probit / cumulative_logit`), `student` (nu fixed vs estimated), `aghq` (public knob vs internal kernel), `unique` (the Psi companion modifier; the bridge drops it entirely).

## Response families

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| gaussian | implemented |  | FAM-01, CRAN07-AA-01, CRAN07-AA-02 |  |
| binomial | scope-limited |  | FAM-02, FAM-03, FAM-04, CRAN07-AA-06 | Julia keeps one combined `binomial` row across links; R's register splits logit/probit/cloglog into FAM-02/03/04. |
| betabinomial | implemented |  | FAM-05 |  |
| poisson | scope-limited |  | FAM-06, CRAN07-AA-04 |  |
| nbinom1 | implemented |  | FAM-07 |  |
| nbinom2 | scope-limited |  | FAM-08, CRAN07-AA-05, CRAN07-AA-05B |  |
| Gamma | implemented |  | FAM-09 |  |
| beta | implemented |  | FAM-10 |  |
| lognormal | implemented |  | FAM-11 |  |
| student | implemented |  | FAM-12 | COLLISION (divergence, not a false join): both packages call this family `student`, but gllvmTMB's `student()` ESTIMATES the degrees-of-freedom `nu` per trait (`R/families.R`, `log_df_student` in gllvmTMB.cpp) while GLLVM.jl's Student-t parity is paid only at a FIXED nu on both sides -- see the parity tool's NOTED_DIVERGENCES table. |
| tweedie | implemented |  | FAM-13 |  |
| ordinal_probit | implemented |  | FAM-14 | COLLISION guard: this is the probit-link ordinal cumulative model only. Julia's row is the COMBINED `ordinal_probit / cumulative_logit`; gllvmTMB has no logit-link ordinal response family, so that half is a genuine port gap (see parity tool disposition table). |
| truncated_poisson | scope-limited |  | FAM-15 |  |
| truncated_nbinom2 | scope-limited |  | FAM-15 |  |
| truncated_nbinom1 | planned |  | FAM-16 |  |
| censored_poisson | scope-limited |  | FAM-24 |  |
| delta_gamma | implemented |  | FAM-17 |  |
| delta_lognormal | implemented |  | FAM-17 |  |
| zi_poisson / zi_nbinom2 / zi_binomial (zero-inflated count families) | scope-limited | zip / zinb / zib | FAM-21, FAM-22, FAM-23 | DIVERGENCE: gllvmTMB's zi_nbinom2 REUSES the ordinary per-trait nbinom2() dispersion (log_phi_nbinom2, one value per trait); GLLVM.jl's ZINB/ZINegBin uses ONE SHARED SCALAR NB2 dispersion r across all species (its ZINBCovFit docstring). Both `implemented`-shaped statuses describe different parameterisations, same as the `student` nu divergence above. |
| multinomial / categorical (response family) | scope-limited | multinomial / categorical | FAM-20, FAM-20A, FAM-20B, FAM-20C, FAM-20D, FAM-20E, FAM-20F | COLLISION guard: this is gllvmTMB's RESPONSE family `multinomial()`. Do not confuse with the unrelated `categorical` register row MIS-31, which is a missing-PREDICTOR imputation family (see the Missing data group). |
| Mixed-family response vector | scope-limited |  | MIX-01, MIX-02, MIX-03, MIX-04, MIX-05, MIX-06, MIX-07, MIX-08, MIX-09, MIX-10 |  |

## Covariance grid source × mode

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| none × indep (`indep()` / ordinary independent RE) | scope-limited |  | FG-05, FG-07, FG-09 | FG-05 (`unique()` standalone) and FG-09 (`scalar()` modifier) are soft-deprecated modifier spellings of this same indep cell, per CLAUDE.md's modifier doctrine -- not separate modes. |
| none × dep (`dep()` / unstructured trait covariance) | scope-limited |  | FG-08 |  |
| none × latent (`latent()` / ordinary LV GLLVM) | scope-limited |  | FG-04, FG-06, CRAN07-AA-03, RE-12 |  |
| phylogenetic × indep (`phylo_indep()`) | scope-limited |  | FG-12, PHY-04, PHY-05, PHY-11, PHY-12, PHY-13, PHY-14, PHY-15, PHY-16, RE-14, STR-RHO-FIX, STR-RHO-EST, STR-RHO-WORKFLOW |  |
| phylogenetic × dep (`phylo_dep()`) | implemented |  | PHY-05, PHY-18 |  |
| phylogenetic × latent (`phylo_latent()`) | implemented |  | PHY-01, PHY-02, PHY-03, PHY-09, PHY-10, PHY-17 |  |
| animal × indep (`animal_indep()`) | scope-limited |  | ANI-03, ANI-11, STR-RHO-FIX, STR-RHO-EST, STR-RHO-WORKFLOW |  |
| animal × dep (`animal_dep()`) | implemented |  | ANI-04, ANI-12 |  |
| animal × latent (`animal_latent()`) | scope-limited |  | ANI-01, ANI-02, ANI-05, ANI-09, ANI-10 |  |
| spatial × indep (`spatial_indep()`) | scope-limited |  | FG-13, SPA-03, SPA-04, SPA-05, SPA-06, SPA-07, STR-RHO-FIX, STR-RHO-EST, STR-RHO-WORKFLOW, STR-RHO-SPA |  |
| spatial × dep (`spatial_dep()`) | scope-limited |  | SPA-04, SPA-10, STR-RHO-SPA |  |
| spatial × latent (`spatial_latent()`) | scope-limited |  | SPA-02, SPA-09, STR-RHO-SPA |  |
| kernel × indep (`kernel_indep()`) | scope-limited |  | KER-02, STR-RHO-FIX, STR-RHO-EST, STR-RHO-WORKFLOW |  |
| kernel × dep (`kernel_dep()`) | implemented |  | KER-02 |  |
| kernel × latent (`kernel_latent()`) | implemented |  | KER-02, KER-03 |  |
| phylo_latent + `lv = ~ x` (Phylo Model A public intervals) | planned |  | LV-08 |  |
| Latent scores on covariates `latent(..., lv = ~ x)` ordinary | scope-limited |  | FG-18, RE-13, LV-01, LV-02, LV-03, LV-04, LV-05, LV-06, LV-07, LV-09, JUL-01A, EXT-31 |  |
| Response-column slope family (`slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, `spatial_slope()`) | scope-limited | Response-column slope family (`slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, `spatial_slope()`; Gaussian long-format, predictor-only) | FG-19, FG-15, PHY-06, ANI-06, SPA-11, KER-04 |  |
| Internal IID column coefficients (`column_coef()`) | scope-limited | Internal IID column coefficients (#1216) | FG-20 |  |
| Column-slope covariance helpers incl. diagonal phylogenetic column slopes | scope-limited | Column-slope covariance helpers incl. diagonal phylogenetic column slopes (#1196) | FG-20 |  |
| Fixed-effect covariates `X` (shared site design) | implemented |  | FG-02, MIX-01, MIX-02, MIS-34 |  |

## Grouping levels

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| grouping level × unit | scope-limited |  | MIS-01, MIS-02, MIS-11, RE-01, RE-02, RE-03, RE-10, FG-01, FG-03 |  |
| grouping level × unit_obs | implemented |  | FG-10, RE-04, RE-06, RE-07, RE-09 |  |
| grouping level × cluster | implemented |  | RE-08 |  |
| grouping level × cluster2 | implemented |  | RE-05, RE-11, FG-11 |  |

## Estimators

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| ML default (Gaussian closed-form / non-Gaussian Laplace) | implemented |  | MIS-13 |  |
| REML (Gaussian pilot twin) | implemented |  | MIS-33 |  |
| AGHQ estimator | scope-limited |  | MIS-35, MIS-36 | COLLISION (divergence, not a false join): gllvmTMB's `aghq` is a public opt-in knob (`gllvmTMBcontrol(aghq = FALSE | k | "auto")`); GLLVM.jl's own AGHQ-shaped kernel code (src/families/aghq_grid.jl) is internal-only and unreceipted as a public capability -- both `missing` on Julia's ledger. See the parity tool's NOTED_DIVERGENCES table for "AGHQ shape". |
| VA / ELBO alternative (selected families; not R-default) | scope-limited |  | VA-01, VA-02, VA-03, VA-04, VA-05, VA-06, VA-07, VA-08, VA-09, VA-10, VA-11, VA-12, VA-13 | Withdrawn: `integration = "eva"` is not an admitted value -- "the EVA engine and template remain research-only", a considered refusal, not a pending gap. |
| MSPL point/interval estimator (`estimator = "mspl"`) | scope-limited |  | MSPL-01, MSPL-02, MSPL-03, MSPL-04, MSPL-05 | R-only estimator; GLLVM.jl's ledger has no MSPL row (expected to appear R-only in the parity report). |

## Intervals

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Point extraction (coef / loadings / Σ_y / correlations) | implemented |  | EXT-01, EXT-02, EXT-03, EXT-14, EXT-16, EXT-17, EXT-18 |  |
| Wald intervals | implemented |  | CI-01, CI-09 |  |
| Profile-likelihood intervals | scope-limited |  | CI-02, CI-05, CI-11, CI-12 |  |
| Parametric bootstrap intervals | implemented |  | CI-03, EXT-13, EXT-20, EXT-21, EXT-22, EXT-23, EXT-24 |  |
| Simulation-validated coverage certificate (broad grid) | scope-limited |  | CI-08 |  |
| Mixed-family intervals | planned |  | CI-10 |  |
| extract_correlations() methods (point / Fisher-z / Wald / bootstrap / profile) | implemented |  | EXT-04 |  |
| `slope_sd_ci()` Wald log-scale augmented-slope intervals | scope-limited |  | CI-14 |  |
| Marginal slope-SD intervals (phylo Cholesky / loadings-only augmented slope) | scope-limited |  | CI-15 |  |
| Canonical repeatability profile | planned |  | CI-04 |  |
| Nonlinear communality profile | rejected |  | CI-06 | Withdrawn: public nonlinear communality profile is withdrawn (FG-13 note: "nonlinear communality/correlation/proportion profile intervals are withdrawn and blocked"). |
| Nonlinear correlation profile | rejected |  | CI-07 | Withdrawn: public nonlinear correlation profile is withdrawn (same FG-13 note). |
| extract_proportions() delta-family nonlinear profile | rejected |  | EXT-11 | Withdrawn: extract_proportions() delta-family nonlinear profile is withdrawn (same FG-13 note; distinct from EXT-34's covered boundary contract). |
| extract_proportions() zero-denominator boundary / wide-format contract | implemented |  | EXT-34 |  |
| Standardized-loading joint-delta inference and scale-labelled decision routes | implemented |  | CI-13 |  |

## Post-fit and extractors

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Post-fit summary, comparison, and plotting extractor surface | implemented |  | EXT-05, EXT-06, EXT-07, EXT-08, EXT-09, EXT-10, EXT-12, EXT-15, EXT-19, EXT-25, EXT-26, EXT-27, EXT-28, EXT-29, EXT-30, EXT-32, EXT-33, EXT-35, EXT-36, EXT-37, PHY-07, PHY-08, ANI-07, ANI-08, SPA-08, LAM-01, LAM-02, LAM-03, LAM-04 |  |

## Diagnostics

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Diagnostics and fit-health surface | scope-limited |  | DIA-01, DIA-02, DIA-03, DIA-04, DIA-05, DIA-06, DIA-07, DIA-08, DIA-09, DIA-10, DIA-11, DIA-12, DIA-13, DIA-14, CRAN07-AA-07 |  |

## Missing data

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Missing responses (NA / mask) | scope-limited |  | MIS-21, MIS-22, MIS-24, VA-03, VA-10 |  |
| Missing predictor `mi()` | scope-limited |  | MIS-23, MIS-25, MIS-26, MIS-27, MIS-28, MIS-29, MIS-32, MIS-37 |  |
| cumulative_logit (missing-predictor family) | implemented |  | MIS-30 | COLLISION guard: this is R's ORDERED missing-PREDICTOR imputation family inside `mi()`/`miss_control()`. Julia's `cumulative_logit` name refers to the unrelated ordinal RESPONSE family (see the `ordinal_probit` row above) -- must not join to it. |
| categorical (missing-predictor family) | implemented |  | MIS-31 | COLLISION guard: this is R's UNORDERED missing-PREDICTOR imputation family inside `mi()`/`miss_control()`. R's response-side unordered family is `multinomial()` (see `multinomial / categorical (response family)` above), not this row. |

## Integrated SDM

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Integrated two-source model admitted through public `gllvmTMB()` | point-fit-recovery |  | ISDM-01 |  |
| Multi-source integrated model (`isdm_sources()`, n_sources >= 2) | point-fit-recovery |  | ISDM-02 |  |
| `predict()` on integrated (`isdm_sources()` / two-source) fits | point-fit-recovery |  | ISDM-03 |  |
| Internal paired baseline-vs-rep3 response-information study | planned |  | ISDM-RESP-INFO | Internal-only investigation; not a public capability. R-only, no Julia twin expected. |

## Bridge

| Capability | Status | Aliases | Register rows | Note |
|---|---|---|---|---|
| Julia bridge unit-tier covariance and ordination accessors | scope-limited |  | JUL-01A |  |
| Lean `engine = "julia"` reduced-rank bridge (`GLLVM.bridge_fit`) | scope-limited |  | JUL-01 |  |

## Unmapped-by-design register rows

Register rows deliberately NOT translated into a ledger capability row above, with a written reason each (mirrors DRM.jl's `tools/parity_ledger.py` `NOT_CAPABILITY` / `DELIBERATELY_NOT_PORTED` precedent). Every register row is accounted for either in a table above or here -- `--check` fails if a new register row is neither.

| Register row | Reason |
|---|---|
| COE-01 | R-only cross-lineage coevolution capability; no Julia twin row |
| COE-02 | R-only cross-lineage coevolution capability; no Julia twin row |
| COE-03 | R-only cross-lineage coevolution capability; no Julia twin row |
| COE-04 | R-only cross-lineage coevolution capability; no Julia twin row |
| FAM-18 | R-only aspirational mixture families (gamma_mix/lognormal_mix/nbinom2_mix), blocked on the R side too; no Julia twin to compare against |
| FAM-19 | R-only aspirational generalized-gamma family (gengamma), blocked on the R side too; no Julia twin |
| FG-14 | meta_V() parser row; folds into the MET-* meta-analysis rows above, all R-only |
| FG-16 | R-only legacy `gllvmTMB_wide()` matrix constructor, soft-deprecated; no Julia twin |
| FG-17 | Deliberately rejected parser grammar (slash-form nesting `(1 | g1/g2)`); no Julia grammar-rejection concept to compare against |
| KER-01 | R-only cross-lineage coevolution kernel builder (make_cross_kernel()); GLLVM.jl's ledger tracks no coevolution row to compare against |
| MET-01 | R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin |
| MET-02 | R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin |
| MET-03 | R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin |
| MET-04 | R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin |
| MIS-03 | R-only legacy `gllvmTMB_wide()` matrix constructor, soft-deprecated; duplicate of FG-16 |
| MIS-04 | R-only unified weight-column handling; internal plumbing, no distinct Julia-comparable capability |
| MIS-05 | R S3-method ergonomics (simulate.gllvmTMB_multi()); Julia's ledger does not track simulate() as a capability row |
| MIS-06 | R S3-method ergonomics (tidy.gllvmTMB_multi()); Julia's ledger does not track print/tidy/plot as capability rows |
| MIS-07 | R S3-method ergonomics (predict.gllvmTMB_multi()); folded operationally into extractor/bridge rows elsewhere, not a distinct ledger row |
| MIS-08 | R S3-method ergonomics (print.gllvmTMB_multi()); Julia's ledger does not track this |
| MIS-09 | R S3-method ergonomics (plot.gllvmTMB_multi() dispatcher); Julia's ledger does not track this |
| MIS-10 | R-only brms-style formula sugar; a syntax convenience, not a modelling capability |
| MIS-12 | R-only gllvmTMBcontrol() control-object infrastructure; no Julia twin |
| MIS-14 | R-only argument-validation infrastructure (gllvmTMB-args.R); no Julia twin |
| MIS-15 | R-only profile_targets() controlled vocabulary; internal plumbing, not a capability |
| MIS-16 | R-side optimizer starting-value engineering (init_strategy); internal robustness measure, no Julia-comparable capability |
| MIS-17 | R-side optimizer starting-value engineering (phi clamp); internal robustness measure |
| MIS-18 | R-side optimizer starting-value engineering (start_method = res); internal robustness measure |
| MIS-19 | R-side optimizer starting-value engineering (start_method = indep / start_from); internal robustness measure |
| MIS-20 | R-side optimizer starting-value engineering (restart_history/start_provenance); internal robustness measure |
| MIS-38 | API hygiene only (#1190 unused unit_obs/cluster warning) -- Julia's own ledger explicitly lists this under 'Not capability (API hygiene in 0.7.1, nothing to mirror): unused grouping-slot warnings (#1190)', so it is deliberately excluded on both sides |
| SPA-01 | R-side SPDE mesh construction (make_mesh()); pre-fit geospatial prep, no Julia twin capability (cf. drmTMB's identical make_mesh precedent) |

