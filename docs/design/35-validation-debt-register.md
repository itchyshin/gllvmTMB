# Validation-Debt Register

**Maintained by:** Rose (validation-debt audit / overpromise
prevention) and Shannon (cross-team coordination + persona-
active row ownership).
**Ratified by:** Ada (orchestrator) on phase-boundary close.
**Reviewers:** the row-owner persona named per row, plus the
persona named in the lead column of the relevant design doc.

This is the **honest ledger** of advertised capability vs
test evidence. Every advertised capability in
`docs/design/00-vision.md`, `README.md`,
`vignettes/articles/*.Rmd`, `NEWS.md`, and roxygen has a row
here with one of four status states + test-evidence path +
diagnostic status + interval status.

**The register exists to prevent the overpromise crisis of
2026-05-15** (article-port batch overpromised capabilities;
/loop auto-pilot bypassed Pat + Rose reviews; maintainer
flagged repeated mistakes that the drmTMB team does NOT make).
drmTMB Doc #34 is the template; this register mirrors the
discipline.

## Vocabulary

The validation-debt register uses **drmTMB's 4-state
vocabulary** (`covered / partial / opt-in / blocked`), which
is different from the parser-syntax 4-state vocabulary
(`covered / claimed / reserved / planned`) used in
`docs/design/01-formula-grammar.md` and
`docs/design/06-extractors-contract.md`.

The two vocabularies coexist because they describe different
things:

- **Parser-syntax vocabulary** answers *"is this syntax
  accepted by the parser?"* — `claimed` means the parser
  takes it but no end-to-end test confirms the fit + extractor
  path.
- **Validation-debt vocabulary** answers *"is this advertised
  capability backed by evidence?"* — `covered` means a test
  file with concrete assertions; `partial` means tests exist
  but not at the depth advertised; `opt-in` means works with
  a non-default argument that must be explicit; `blocked`
  means advertised but currently broken / undefined / removed.

| Status | Meaning | When to use |
|--------|---------|-------------|
| `covered` | Tests exist with concrete assertions at the depth advertised | Most M0 single-family Gaussian capabilities |
| `partial` | Tests exist but coverage is shallower than the advertised claim | Most non-Gaussian / mixed-family extractors |
| `opt-in` | Works but only with a non-default argument; user must opt in explicitly | E.g. `link_residual = "auto"` until PR #101 made it default |
| `blocked` | Advertised but currently broken, undefined, or requires removal from public surface | E.g. delta-family mixed-family latent-scale correlation |

## How the register is maintained

1. **Every PR that touches an advertised capability appends or
   updates a row.** The after-task report references the
   register row by ID.
2. **Phase-boundary close gates require** this register to
   reflect the state of the merged code. Shannon's coordination
   audit at each phase boundary cross-checks the register
   against the actual test suite.
3. **The overpromise-preventer rule**: if a row claims
   `covered` but Rose's pre-publish audit cannot point at a
   test file with concrete assertions, the row is downgraded
   to `partial` or `blocked` before publication.
4. **Phase 0B's job** is to walk every `partial` and `blocked`
   row to either `covered` (with new tests) or **honestly
   marked** (with public-surface tightening: NEWS entry +
   article revert + README matrix update).

## Status snapshot (Phase 0A close, 2026-05-16)

This snapshot is the input to Phase 0B. Every row marked
`partial` or `blocked` gets walked in Phase 0B; every row
marked `covered` gets a Rose audit confirming the test
evidence is real.

### Section 1 — Formula grammar (3×5 keyword grid)

Row-owner: **Boole** (formula-grammar parser).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| FG-01 | Long format with `traits(...)` LHS | `covered` | `test-traits-keyword.R`, `test-canonical-keywords.R` | M0 baseline |
| FG-02 | Long format with explicit `value`-stacked long data + `trait =` argument | `covered` | `test-canonical-keywords.R`, `test-keyword-grid.R` | Option A uniform naming |
| FG-03 | Wide format via `traits(t1, t2, ...) ~ ...` | `covered` | `test-traits-keyword.R`, `test-wide-weights-matrix.R` | |
| FG-04 | `latent(0 + trait \| unit, d = K)` standalone | `covered` | `test-stage2-rr-diag.R`, `test-keyword-grid.R` | |
| FG-05 | `unique(0 + trait \| unit)` standalone | `covered` | `test-stage2-rr-diag.R`, `test-cross-sectional-unique.R` | |
| FG-06 | `latent + unique` paired | `covered` | `test-stage2-rr-diag.R`, `test-mixed-response-sigma.R` | |
| FG-07 | `indep(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R` | only Gaussian verified |
| FG-08 | `dep(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R` | only Gaussian verified |
| FG-09 | `scalar(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R` | only Gaussian verified |
| FG-10 | Two-tier nested `unit / unit_obs` | `covered` | `test-multi-random-intercepts.R`, `test-olre-separation.R` | |
| FG-11 | Crossed random effects (e.g. site × year) | `partial` | `test-stage1-stacked-fixed-effects.R` | smoke only; not exhaustive |
| FG-12 | `phylo_*` family (5 keywords) | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-hadfield.R`, `test-phylo-mode-dispatch.R`, `test-phylo-q-decomposition.R`, `test-phylo-vcv-optional.R` | M0 baseline |
| FG-13 | `spatial_*` family (6 keywords) | `partial` | `test-stage4-spde.R`, `test-spatial-latent-recovery.R`, `test-spatial-mode-dispatch.R`, `test-spatial-orientation.R` | smoke + mode-dispatch; full coverage Phase 0B |
| FG-14 | `meta_V(value, V = V)` | `partial` | `test-block-V.R` | block-V verified; named-V verified; single-V Phase 0B |
| FG-15 | `phylo_slope()` random-slope keyword | `partial` | `test-phylo-slope.R` | smoke only; full M1 |
| FG-16 | `gllvmTMB_wide(Y, ...)` legacy constructor | `blocked` | n/a | removed in 0.2.0 per maintainer (NEWS entry pending) |
| FG-17 | Slash form `(1 \| g1/g2)` nesting | `blocked` | `test-augmented-lhs-guard.R` | parser rejects with snapshot-pinned error |

### Section 2 — Response families (15 advertised)

Row-owner: **Gauss** (TMB likelihood per family).

| ID | Family | Status | Test evidence | Notes |
|----|--------|--------|---------------|-------|
| FAM-01 | gaussian (identity) | `covered` | many tests | M0 baseline |
| FAM-02 | binomial (logit) | `covered` | `test-m2-2a-binary-recovery.R`, `test-m2-2b-binary-cis-extractors.R`, `test-m2-2b-glmmTMB-cross-check.R`, `test-multi-trial-binomial.R`, `test-stage33-non-gaussian.R` | M2.2-A: Σ recovery at d = 1. M2.2-B: CIs (Wald + Fisher-z + bootstrap) + 4 ratio extractors + glmmTMB cross-package agreement |
| FAM-03 | binomial (probit) | `covered` | `test-m2-2a-binary-recovery.R`, `test-stage33-non-gaussian.R` | M2.2-A walks; Σ recovery + identification (σ²_d = 1 by construction) |
| FAM-04 | binomial (cloglog) | `covered` | `test-m2-2a-binary-recovery.R`, `test-stage33-non-gaussian.R` | M2.2-A walks; Σ recovery + σ²_d = π²/6 verified |
| FAM-05 | betabinomial | `partial` | `test-betabinomial-recovery.R` | recovery test exists; full M2 |
| FAM-06 | poisson (log) | `covered` | `test-stage33-non-gaussian.R` | |
| FAM-07 | nbinom1 | `partial` | `test-nb2-recovery.R` | nbinom2 verified; nbinom1 smoke only |
| FAM-08 | nbinom2 | `covered` | `test-nb2-recovery.R` | recovery test |
| FAM-09 | gamma (log) | `partial` | `test-family-gamma.R` | smoke only |
| FAM-10 | beta (logit) | `partial` | `test-beta-recovery.R` | recovery test |
| FAM-11 | lognormal | `partial` | `test-family-lognormal.R` | smoke only |
| FAM-12 | student-t | `partial` | `test-student-recovery.R` | recovery test |
| FAM-13 | tweedie | `partial` | `test-tweedie-recovery.R` | recovery test |
| FAM-14 | ordinal_probit | `partial` | `test-ordinal-probit.R` | smoke only; full M2 work |
| FAM-15 | truncated_poisson / truncated_nbinom* | `partial` | `test-truncated-recovery.R` | recovery tests |
| FAM-16 | censored_poisson | `partial` | (not located) | smoke only |
| FAM-17 | delta_* families (10 variants) | `blocked` | `test-delta-gamma-recovery.R`, `test-delta-lognormal-recovery.R` | engine works for single-family delta; mixed-family delta + latent-scale correlation undefined (two-scales problem); deferred to post-CRAN per `02-family-registry.md` |
| FAM-18 | gamma_mix / lognormal_mix / nbinom2_mix | `blocked` | n/a | mixture families exported but not validated |
| FAM-19 | gengamma | `blocked` | n/a | exported but not validated |

### Section 3 — Random-effects structures

Row-owner: **Boole + Fisher** (random-effects design lead).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| RE-01 | Random intercepts only (`s = 0`) | `covered` | `test-multi-random-intercepts.R` | M0 baseline |
| RE-02 | One random slope (`s = 1`) | `partial` | `test-phylo-slope.R` | M1 scope per `04-random-effects.md` |
| RE-03 | Two or more random slopes (`s ≥ 2`) | `blocked` | n/a | M1 caps at s = 1 (validation evidence required for s = 2, 3 promotion) |
| RE-04 | Nested `unit / unit_obs` | `covered` | `test-multi-random-intercepts.R`, `test-olre-separation.R` | M0 baseline |
| RE-05 | Crossed (e.g. site × year) | `partial` | `test-stage1-stacked-fixed-effects.R` | smoke only |
| RE-06 | OLRE (observation-level random effect) | `covered` | `test-olre-separation.R`, `test-extract-omega.R`, `test-extractors-extra.R` | |
| RE-07 | `sigma_eps` auto-suppression for OLRE | `covered` | `test-sigma-eps-autosuppress.R` | |
| RE-08 | Cluster-level random effect (`cluster` argument) | `covered` | `test-cluster-rename.R` | |
| RE-09 | `latent + unique` paired in within-unit tier | `partial` | `test-mixed-response-unique-nongaussian.R` | smoke; M1 expand |
| RE-10 | Augmented LHS guard (engine-internal variable name clashes) | `covered` | `test-augmented-lhs-guard.R` | |

### Section 4 — Phylogenetic GLLVM

Row-owner: **Noether + Boole** (phylo-specific math + parser).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| PHY-01 | Hadfield & Nakagawa sparse A⁻¹ | `covered` | `test-phylo-hadfield.R` | M0 baseline |
| PHY-02 | `phylo_latent + phylo_unique` paired | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` | M0 baseline |
| PHY-03 | Three-piece phylo fallback | `covered` | `test-phylo-q-decomposition.R` | |
| PHY-04 | `phylo_scalar(0 + trait \| sp)` | `partial` | `test-stage35-phylo-rr.R` | per the design doc |
| PHY-05 | `phylo_indep / phylo_dep` | `partial` | `test-stage35-phylo-rr.R` | smoke only; full Phase 0B |
| PHY-06 | Phylo-slope keyword `phylo_slope()` | `partial` | `test-phylo-slope.R` | M1 scope |
| PHY-07 | `extract_phylo_signal()` Adams (2014) | `covered` | `test-extract-omega.R`, `test-extractors-extra.R` | |
| PHY-08 | `extract_communality()` $H^2 + C^2 + \psi^2 = 1$ partition | `covered` | `test-extractors.R`, `test-extractors-extra.R` | |
| PHY-09 | Phylogenetic mode dispatch (paired vs three-piece) | `covered` | `test-phylo-mode-dispatch.R` | |
| PHY-10 | Optional `phyloVCV` argument | `covered` | `test-phylo-vcv-optional.R` | |

### Section 5 — Spatial GLLVM

Row-owner: **Boole + Gauss** (SPDE inheritance from sdmTMB).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| SPA-01 | SPDE mesh construction via `make_mesh()` | `covered` | `test-mesh.R` | inherited from sdmTMB |
| SPA-02 | `spatial_latent` + `spatial_unique` paired | `partial` | `test-spatial-latent-recovery.R` | recovery test exists; full Phase 0B verification |
| SPA-03 | `spatial_scalar` | `partial` | `test-stage4-spde.R` | smoke only |
| SPA-04 | `spatial_indep / spatial_dep` | `partial` | `test-stage4-spde.R` | smoke only |
| SPA-05 | Spatial mode dispatch | `covered` | `test-spatial-mode-dispatch.R` | |
| SPA-06 | Spatial orientation handling (X/Y) | `covered` | `test-spatial-orientation.R`, `test-utm-conversions.R` | |
| SPA-07 | Spatial deprecation (legacy aliases) | `covered` | `test-spatial-deprecation.R` | |

### Section 6 — Meta-analysis (meta_V)

Row-owner: **Fisher + Boole** (meta-analysis with known V).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| MET-01 | Single-V `meta_V(value, V = V)` (additive scale, default) | `partial` | `test-block-V.R` | block-V verified; named-V verified; single-V smoke only |
| MET-02 | Block-V within-study correlation | `covered` | `test-block-V.R` | |
| MET-03 | `meta_V(scale = "proportional")` (Nakagawa 2022) | `blocked` | n/a | post-CRAN; not yet implemented |
| MET-04 | `corvidae-two-stage` two-stage workflow | `partial` | n/a | article pulled to `dev/workshop-articles/` in PR-0C.PULL (Gaussian meta-analytical example; deferred per maintainer 2026-05-16 — restore once a live cross-check fixture exists) |

### Section 7 — Mixed-family fits

Row-owner: **Boole + Fisher + Emmy** (mixed-family is the
vision-item-5 differentiator).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| MIX-01 | Engine accepts `family = list(...)` long format | `covered` | `test-stage37-mixed-family.R` | M0 baseline |
| MIX-02 | Per-row `family_var` column dispatch | `covered` | `test-stage37-mixed-family.R` | |
| MIX-03 | `extract_Sigma()` on mixed-family fits | `covered` | `test-m1-3-extract-sigma-mixed-family.R`, `test-mixed-family-extractor.R`, `test-mixed-response-sigma.R` | M1.3 (PR #151) |
| MIX-04 | `extract_correlations()` on mixed-family fits | `covered` | `test-m1-4-extract-correlations-mixed-family.R`, `test-link-residual-15-family-fixture.R`, `test-fisher-z-correlations.R` | M1.4 (PR #151) — Fisher-z + Wald + bootstrap on $\Sigma_\text{total}$; profile path operates on $\Sigma_\text{shared}$ per profile-correlation-surface audit |
| MIX-05 | `extract_communality()` on mixed-family fits | `covered` | `test-m1-5-extract-communality-mixed-family.R`, `test-mixed-family-extractor.R` | M1.5 (PR #154) |
| MIX-06 | `extract_repeatability()` on mixed-family fits | `covered` | `test-m1-6-extract-repeatability-mixed-family.R`, `test-mixed-family-extractor.R` | M1.6 (PR #154) — `vW` formula corrected to add per-family `sigma2_d` |
| MIX-07 | OLRE-bearing trait in mixed-family fits | `covered` | `test-mixed-family-olre.R`, `test-mixed-response-unique-nongaussian.R` | M0 baseline; M1.7 cross-tier integration via `test-m1-7-extract-omega-phylo-signal-mixed-family.R` |
| MIX-08 | `bootstrap_Sigma()` on mixed-family fits | `covered` | `test-m1-8-bootstrap-mixed-family.R`, `test-bootstrap-Sigma.R` | M1.8 (PR #157) — per-row family preserved via `fit$family_input` |
| MIX-09 | `link_residual = "auto"` default (PR #101) | `covered` | `test-link-residual-auto-default.R`, `test-link-residual-15-family-fixture.R`, `test-link-residual-clamp.R` | M0 baseline |
| MIX-10 | Mixed-family with delta / hurdle family (latent-scale correlation) | `blocked` | `test-check-auto-residual.R` | two-scales-undefined; safeguard errors with class `gllvmTMB_auto_residual_delta_undefined` |

### Section 8 — Extractors

Row-owner: **Emmy + Fisher** (extractor contract per
`06-extractors-contract.md`).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| EXT-01 | `extract_Sigma(level, part)` | `covered` | `test-extract-sigma.R`, `test-extractors.R` | rotation-invariant |
| EXT-02 | `extract_Sigma_B / W` legacy aliases | `covered` | `test-sigma-rename.R` | slated for `deprecate_soft()` 0.3.0 |
| EXT-03 | `extract_Omega()` cross-tier | `covered` | `test-extract-omega.R` | |
| EXT-04 | `extract_correlations()` 4 methods | `covered` (Fisher-z + Wald) / `partial` (profile + bootstrap on mixed-family) | `test-fisher-z-correlations.R`, `test-confint-bootstrap.R` | |
| EXT-05 | `extract_communality()` | `covered` | `test-extractors.R`, `test-extractors-extra.R` | |
| EXT-06 | `extract_repeatability()` | `covered` | `test-extractors-extra.R` | |
| EXT-07 | `extract_phylo_signal()` | `covered` | `test-extractors-extra.R`, `test-extract-omega.R` | |
| EXT-08 | `extract_residual_split()` | `covered` | `test-extract-omega.R`, `test-extractors-extra.R` | |
| EXT-09 | `extract_ordination()` | `covered` | `test-ordiplot-VP.R`, `test-ordiplot-multi.R` | rotation-variant; warn |
| EXT-10 | `extract_cutpoints()` ordinal-probit | `partial` | `test-ordinal-probit.R` | smoke |
| EXT-11 | `extract_proportions()` delta-family | `blocked` | n/a | post-CRAN |
| EXT-12 | `extract_ICC_site()` legacy | `covered` | `test-extractors.R` | superseded by `extract_repeatability()` |
| EXT-13 | `bootstrap_Sigma()` | `covered` (Gaussian) / `partial` (non-Gaussian) | `test-bootstrap-Sigma.R` | |
| EXT-14 | `getLoadings()` raw $\Lambda$ | `covered` | `test-rotate-compare-loadings.R` | rotation-variant; warn |
| EXT-15 | `rotate_loadings()` varimax / quartimax | `covered` | `test-rotate-compare-loadings.R`, `test-rotation-advisory.R` | |
| EXT-16 | `getLV()` legacy ordination alias | `covered` | `test-extractors.R` | slated for `deprecate_soft()` 0.3.0 |
| EXT-17 | `getResidualCor / Cov()` glmmTMB-style | `covered` | `test-extractors.R` | |

### Section 9 — Diagnostics

Row-owner: **Curie + Fisher** (diagnostic / identifiability).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| DIA-01 | `sanity_multi(fit)` | `covered` | `test-sanity-multi.R` | |
| DIA-02 | `gllvmTMB_check_consistency(fit)` (PR #105) | `covered` | `test-check-consistency.R` | |
| DIA-03 | `check_identifiability(fit, sim_reps)` (PR #105) | `covered` | `test-check-identifiability.R` | |
| DIA-04 | `check_auto_residual(fit)` (PR #104) | `covered` | `test-check-auto-residual.R` | |
| DIA-05 | `gllvmTMB_diagnose(fit)` | `covered` | `test-gllvmTMB-diagnose.R` | |
| DIA-06 | Multi-start sdreport / report consistency (PR #100) | `covered` | `test-multi-start-sdreport-consistency.R` | |
| DIA-07 | Profile-curve shape inspection (`confint_inspect()`, PR #121) | `covered` | `test-confint-inspect.R` | |

### Section 10 — Confidence intervals


Row-owner: **Fisher** (inference completeness lead).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| CI-01 | Wald CI via `confint(method = "wald")` | `covered` | `test-tidy-predict.R`, `test-stage1-stacked-fixed-effects.R` | M0 baseline |
| CI-02 | Profile CI via `confint(method = "profile")` (PR #109) | `covered` | `test-profile-ci.R`, `test-profile-targets.R` | |
| CI-03 | Bootstrap CI via `confint(method = "bootstrap")` (PR #109) | `covered` | `test-confint-bootstrap.R` | |
| CI-04 | `profile_ci_repeatability()` (PR #105) | `covered` | `test-profile-ci.R` | |
| CI-05 | `profile_ci_phylo_signal()` (PR #105) | `covered` | `test-profile-ci.R` | |
| CI-06 | `profile_ci_communality()` (PR #120) | `covered` | `test-profile-ci.R` | |
| CI-07 | `profile_ci_correlation()` (PR #122) | `covered` | `test-profile-ci.R` | |
| CI-08 | `coverage_study()` ≥ 94 % empirical coverage gate (PR #120) | `partial` (M3 walk to `covered`) | `test-coverage-study.R`; `dev/precomputed/coverage-gaussian-d2.rds` (R = 200, PR-0C.COVERAGE) | Gaussian d=2 cell at R=200 shipped via `dev/precompute-vignettes.R`; binomial / nbinom2 / ordinal-probit / mixed-family cells walk to `covered` at M3.3 |
| CI-09 | Fisher-z CI on correlations | `covered` | `test-fisher-z-correlations.R` | |
| CI-10 | profile / Wald / bootstrap on mixed-family fits | `partial` | n/a | M3 work |

### Section 11 — Lambda constraint (M2 binary IRT)

Row-owner: **Boole + Fisher** (lambda machinery is central to
M2 binary).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| LAM-01 | `lambda_constraint` argument accepted | `covered` | `test-lambda-constraint.R` | |
| LAM-02 | `lambda_constraint` Gaussian fits | `partial` | `test-lambda-constraint.R` | smoke only |
| LAM-03 | `lambda_constraint` on binary fits (confirmatory IRT) | `covered` | `test-m2-3-lambda-constraint-binary.R`, `test-m2-3-mirt-cross-check.R`, `test-m2-3-galamm-cross-check.R`, `test-lambda-constraint.R` | M2.3 walks: binary 2PL IRT recovery at d ∈ {1, 2} × n_items ∈ {20, 50} + mirt + galamm cross-checks |
| LAM-04 | `suggest_lambda_constraint()` | `covered` | `test-m2-4-suggest-lambda-constraint-binary.R`, `test-suggest-lambda-constraint.R` | M2.4 walks: suggester output structure + suggester→fit recovery cycle on binary IRT at d ∈ {1, 2, 3}; d=3 n_items=10 boundary documented |

### Section 12 — Miscellaneous public surface

Row-owner: **Emmy** (S3 surface) / **Curie** (test integration).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| MIS-01 | `gllvmTMB()` long-format constructor | `covered` | many tests | M0 baseline |
| MIS-02 | `gllvmTMB(traits(...) ~ ...)` wide format | `covered` | `test-traits-keyword.R`, `test-wide-weights-matrix.R` | |
| MIS-03 | `gllvmTMB_wide(Y, ...)` legacy constructor | `blocked` | `test-gllvmTMB-wide.R` (now tests removal) | removed in 0.2.0 |
| MIS-04 | Weight column unified handling | `covered` | `test-weights-unified.R`, `test-lme4-style-weights.R` | |
| MIS-05 | `simulate.gllvmTMB_multi()` family-aware draws (per-row family dispatch) | `covered` | `test-m1-8-bootstrap-mixed-family.R`, `test-simulate-site-trait.R` | M1.8 (PR #157) — `.draw_y_per_family()` dispatches by `family_id_vec`; 6 families (gaussian / binomial / poisson / lognormal / Gamma / nbinom2) covered; others fall back with one-time warning |
| MIS-06 | `tidy.gllvmTMB_multi()` broom-style output | `covered` | `test-tidy-predict.R` | |
| MIS-07 | `predict.gllvmTMB_multi()` link / response | `partial` | `test-tidy-predict.R` | family-aware predict typed outputs is M2 |
| MIS-08 | `print.gllvmTMB_multi()` summary label discipline | `covered` | `test-print-labels.R` | |
| MIS-09 | `plot.gllvmTMB_multi()` dispatcher | `partial` | `test-plot-gllvmTMB.R` | 5 plot types; Phase 1c-viz extends to 8+ |
| MIS-10 | brms-style sugar | `covered` | `test-brms-sugar.R` | |
| MIS-11 | `traits(...)` LHS expansion | `covered` | `test-traits-keyword.R` | |
| MIS-12 | `gllvmTMBcontrol()` control object | `covered` | `test-gllvmTMBcontrol.R` | |
| MIS-13 | Integration tour (end-to-end) | `covered` | `test-integration-tour.R` | M0 baseline |
| MIS-14 | `gllvmTMB-args.R` argument validation | `covered` | `test-gllvmTMB-args.R` | |
| MIS-15 | `profile_targets()` controlled vocabulary (PR #109) | `covered` | `test-profile-targets.R` | drmTMB-style |

## Honest scope statement

This register's honest tally as of Phase 0A close (2026-05-16):

- **102 capability rows.**
- **40 `covered`** (39 %): test evidence exists at the depth
  advertised.
- **48 `partial`** (47 %): tests exist but coverage is
  shallower than advertised; Phase 0B walks each one.
- **0 `opt-in`**: the `link_residual = "auto"` default
  (PR #101) eliminated this category for now.
- **14 `blocked`** (14 %): advertised but currently
  broken / undefined / removed.

This is not a number to be proud of; it is the honest
starting point. Phase 0B's job is to walk the 48 `partial`
rows + audit every `covered` row + correctly mark every
`blocked` row in the public surface.

**The vision's claim of "unparalleled capability" depends on
walking the `partial` mixed-family rows (MIX-03 through
MIX-08) to `covered`.** M1 milestone delivers that walk.

### Update — M1 close (2026-05-17)

Six rows walked from `partial` → `covered` in M1.10 close
gate: MIX-03, MIX-04, MIX-05, MIX-06, MIX-08, and MIS-05.
EXT-07 stayed `covered` with extended test-file evidence
(M1.7 cross-tier composition). MIX-10 stays `blocked` (delta
/ hurdle two-scales-undefined; safeguard error class
`gllvmTMB_auto_residual_delta_undefined` is the honest
answer). Per
[`docs/dev-log/after-phase/2026-05-17-m1-close.md`](../dev-log/after-phase/2026-05-17-m1-close.md).

## What this register does NOT do

- **It does not replace the test files.** Every `covered`
  entry must point at a test file; this register is the
  cross-reference, not the test.
- **It does not replace the design docs.** The design docs
  (`01` to `06`) define what the package promises; this
  register tracks whether the promise is backed by evidence.
- **It does not replace `R CMD check`.** A row marked
  `covered` can still have a failing test on a particular
  OS / R version; the per-PR after-task report records
  this.
- **It does not replace the README's stable-core feature
  matrix.** The README matrix is the user-facing
  presentation; this register is the developer-facing
  honest ledger.
- **It does not commit to milestone timings.** The
  function-first roadmap (M1 / M2 / M3 / M5 / M5.5) commits
  to ordering; this register tracks what each milestone
  delivers.

## How this register grows

Each new PR that touches an advertised capability:

1. **Identifies the row** affected (by row ID, e.g. MIX-03).
2. **Adjusts the status** with provenance: e.g. *"MIX-03
   walked from `partial` to `covered` via
   `tests/testthat/test-mixed-family-extractor-rigour.R`
   PR #XXX"*.
3. **Appends the row** (if new capability) with a row ID
   following the section-prefix convention (`FG-`, `FAM-`,
   `RE-`, `PHY-`, `SPA-`, `MET-`, `MIX-`, `EXT-`, `DIA-`,
   `CI-`, `LAM-`, `MIS-`).
4. **References the row** in the after-task report's
   "validation-debt update" section (new section added by
   Phase 0A step 9 `10-after-task-protocol.md` revision).

Phase-boundary close gates require Shannon's coordination
audit to cross-check the register against the merged code.
The audit is a Shannon-specific dev-log entry.

## Cross-references

- `docs/design/00-vision.md` — advertised capability list;
  vision item 5 is the headline differentiator backed by the
  mixed-family rows.
- `docs/design/01-formula-grammar.md` — Section 1 mirrors the
  parser-syntax status map.
- `docs/design/02-family-registry.md` — Section 2 mirrors the
  family-registry table; delta families' `blocked` status here
  matches the registry's deferred-to-post-CRAN section.
- `docs/design/03-likelihoods.md` — per-family likelihood
  contracts; per-family `partial` rows here have entries.
- `docs/design/04-random-effects.md` — Section 3 random-slope
  cap is reflected in RE-02 and RE-03.
- `docs/design/05-testing-strategy.md` — the test-file
  evidence column above points at files documented there.
- `docs/design/06-extractors-contract.md` — Section 8
  mirrors the extractor coverage matrix.
- `README.md` — Stable-core feature matrix (Phase 0A step
  10) is generated from this register's honest tally.
- `NEWS.md` — every public-surface tightening (e.g. `blocked`
  row added or `partial` → `blocked` downgrade) gets a NEWS
  entry naming the row ID.

## Persona-active engagement

- **Rose** (lead): validation-debt audit. Owns the
  overpromise-preventer rule. Every Phase 0A step 8 after-task
  report verifies a Rose-flagged inconsistency is resolved.
- **Shannon** (lead): cross-team coordination + row-ownership
  audit. Phase-boundary audits cross-check the register
  against the merged code.
- **Ada** (orchestrator): ratifies the register on every
  phase boundary. Phase 0A close, Phase 0B close, M1 close,
  M2 close, M3 close, M5 close, M5.5 close — Ada's
  ratification is the gate.
- **Row-owner personas** (per row): Boole for FG / RE / PHY
  / SPA / MET / LAM, Gauss for FAM / SPA, Fisher for CI /
  MET / MIX / DIA / LAM, Emmy for EXT / MIS, Curie for DIA
  / MIS-05, Pat for MIS user-facing surface.

Each row-owner persona is responsible for:

1. Confirming the status reflects current code.
2. Identifying the test file path that backs `covered`.
3. Flagging when an external audit (Rose, Shannon) marks the
   row inconsistent.

This is the function-first discipline made operational: every
row has a named owner; no row is anonymous.
