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

### Section 1 — Formula grammar (4×5 keyword grid)

Row-owner: **Boole** (formula-grammar parser).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| FG-01 | Long format with `traits(...)` LHS | `covered` | `test-traits-keyword.R`, `test-canonical-keywords.R` | M0 baseline |
| FG-02 | Long format with explicit `value`-stacked long data + `trait =` argument | `covered` | `test-canonical-keywords.R`, `test-keyword-grid.R` | Option A uniform naming |
| FG-03 | Wide format via `traits(t1, t2, ...) ~ ...` | `covered` | `test-traits-keyword.R`, `test-wide-weights-matrix.R` | |
| FG-04 | `latent(0 + trait \| unit, d = K)` standalone | `covered` | `test-stage2-rr-diag.R`, `test-keyword-grid.R` | |
| FG-05 | `unique(0 + trait \| unit)` standalone | `covered` | `test-stage2-rr-diag.R`, `test-cross-sectional-unique.R` | |
| FG-06 | `latent + unique` paired | `covered` | `test-stage2-rr-diag.R`, `test-mixed-response-sigma.R` | |
| FG-07 | `indep(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R`, `test-tiers-indep-dep-nongaussian.R` | Bare-keyword (no-V) non-Gaussian gap closed 2026-05-31 (`agent/distribution-validation-fills`): `test-tiers-indep-dep-nongaussian.R` recovers the per-trait diagonal (`indep_B` + `diag_B` flags, `extract_Sigma(part="unique")$s`) under poisson(log) within the inherited 0.30 relative count band (DGP + band from `test-tiers-poisson.R`, heavy-gated, honest-skip on non-convergence). Engine path is `unique()`-identical per `R/brms-sugar.R` (documentary keyword distinction). REMAINS `partial`: the known-V (`propto()`/`equalto()`) variant is still Gaussian-only verified -- non-Gaussian known-V is the harder phylo-dep identifiability item, not filled here. |
| FG-08 | `dep(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R`, `test-tiers-indep-dep-nongaussian.R` | Bare-keyword (no-V) non-Gaussian gap closed 2026-05-31 (`agent/distribution-validation-fills`): `test-tiers-indep-dep-nongaussian.R` recovers the full unstructured covariance (`dep_B` + `rr_B` flags, `extract_Sigma(part="shared")$Sigma`) under poisson(log) -- diagonal within the inherited 0.30 relative count band, off-diagonals within a measured 0.10 absolute band at n_unit=400 (heavy-gated, honest-skip). Engine path is `latent(d=n_traits)`-identical per `R/brms-sugar.R`. REMAINS `partial`: the known-V (`propto()`/`equalto()`) variant is still Gaussian-only verified -- non-Gaussian known-V is the harder phylo-dep item, not filled here. |
| FG-09 | `scalar(0 + trait \| unit)` | `partial` | `test-stage3-propto-equalto.R` | only Gaussian verified. NOT a cheap test-only gap: bare `scalar(0+trait\|unit)` has no standalone engine path (it is `phylo_scalar`/`spatial_scalar` known-V sugar per `R/brms-sugar.R`); the only non-Gaussian realisation is the known-V/phylo route, which is the genuinely-hard identifiability item. Left intentionally (audit 2026-05-31). |
| FG-10 | Two-tier nested `unit / unit_obs` | `covered` | `test-multi-random-intercepts.R`, `test-olre-separation.R` | |
| FG-11 | Crossed random effects (e.g. site × year) | `partial` | `test-stage1-stacked-fixed-effects.R` | smoke only; not exhaustive |
| FG-12 | `phylo_*` family (5 keywords) | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-hadfield.R`, `test-phylo-mode-dispatch.R`, `test-phylo-q-decomposition.R`, `test-phylo-vcv-optional.R` | M0 baseline |
| FG-13 | `spatial_*` family (6 keywords) | `partial` | `test-stage4-spde.R`, `test-spatial-latent-recovery.R`, `test-spatial-mode-dispatch.R`, `test-spatial-orientation.R` | smoke + mode-dispatch; full coverage Phase 0B |
| FG-14 | `meta_V(V = V)` | `partial` | `test-formula-grammar-smoke.R`, `test-traits-keyword.R`, `test-block-V.R` | V-only named and positional parser forms verified; wide `traits(...)` marker preservation verified; block-V helper verified; single-V inference validation remains partial |
| FG-15 | `phylo_slope()` random-slope keyword | `covered` | `test-phylo-slope.R`, `test-matrix-slope-*.R` | Augmented random-regression slope validated across families (local measurement 2026-05-30, 0 fail); `phylo_indep(1+x)` independent variant added this cycle. |
| FG-16 | `gllvmTMB_wide(Y, ...)` legacy constructor | `partial` | `test-gllvmTMB-wide.R`, `test-wide-weights-matrix.R` | soft-deprecated in 0.2.0; new examples use `traits(...)`; removal is a later API-change decision while export remains live |
| FG-17 | Slash form `(1 \| g1/g2)` nesting | `blocked` | `test-augmented-lhs-guard.R` | parser rejects with snapshot-pinned error |

### Section 2 — Response families (15 advertised)

Row-owner: **Gauss** (TMB likelihood per family).

| ID | Family | Status | Test evidence | Notes |
|----|--------|--------|---------------|-------|
| FAM-01 | gaussian (identity) | `covered` | many tests | M0 baseline |
| FAM-02 | binomial (logit) | `covered` | `test-m2-2a-binary-recovery.R`, `test-m2-2b-binary-cis-extractors.R`, `test-m2-2b-glmmTMB-cross-check.R`, `test-multi-trial-binomial.R`, `test-stage33-non-gaussian.R` | M2.2-A: Σ recovery at d = 1. M2.2-B: CIs (Wald + Fisher-z + bootstrap) + 4 ratio extractors + glmmTMB cross-package agreement |
| FAM-03 | binomial (probit) | `covered` | `test-m2-2a-binary-recovery.R`, `test-stage33-non-gaussian.R` | M2.2-A walks; Σ recovery + identification (σ²_d = 1 by construction) |
| FAM-04 | binomial (cloglog) | `covered` | `test-m2-2a-binary-recovery.R`, `test-stage33-non-gaussian.R` | M2.2-A walks; Σ recovery + σ²_d = π²/6 verified |
| FAM-05 | betabinomial | `covered` | `test-betabinomial-recovery.R`, `test-matrix-betabinomial.R` | Recovery green (local measurement 2026-05-30: 8 + 31 assertions, 0 fail). |
| FAM-06 | poisson (log) | `covered` | `test-stage33-non-gaussian.R` | |
| FAM-07 | nbinom1 | `covered` | `test-matrix-nbinom1.R` (31 assertions, heavy-gated), `test-tiers-nbinom1.R` (38 assertions, heavy-gated) | Was exported-but-unwired (overclaim caught, spike 2026-05-30). **Wired 2026-05-30** on review-gated branch `agent/trackd-nbinom1-wiring` (`09d4f58`): `nbinom1` = fid 15, full R↔C++ lockstep, correct NB1 linear variance (Var = μ·(1+φ), verified flat-in-μ); φ recovers to −0.9% bias when identifiable (φ-vs-latent-variance confound documented honestly); `test-matrix-nbinom1.R` self-heals 3 skips -> 31 pass; all regression families green. **Un-skipped 2026-05-31** (`agent/nbinom1-unskip`): the stale "not wired" construct-fail skip in `skip_unless_healthy_nbinom1()` is removed (a construct failure now FAILS hard; the non-convergence/non-PD health skip is kept; the `skip_if_not_heavy()` env gate is kept). Re-verified on main wiring: conv == 0, PD Hessian, phi (true 2.0) recovers to mean ~1.87 (about -6% bias) on the unit cell, intercepts within 0.19 (tol 0.40); `devtools::test(filter = "nbinom1")` under `GLLVMTMB_HEAVY_TESTS=1` is 31 pass / 0 fail / 0 skip, and skips cleanly (3 skips) when the heavy gate is off. **Tier coverage extended 2026-05-31** (`agent/nbinom1-tier-coverage`, gap G3): `test-tiers-nbinom1.R` adds a representative structured-tier parity set mirroring the nbinom2 / poisson tier tests, one structural cell per `test_that`, all heavy-gated and honest-skip-guarded on construct-fail / non-convergence / non-PD Hessian: (a) UNIT `indep(0 + trait | unit)` -- the diagonal "clean trio" cell `test-matrix-nbinom1.R` does not already walk (it covers latent / unique / latent+unique); asserts conv == 0, PD Hessian (`sd_report$pdHess`), `indep_B` flag, per-trait phi finite-positive with mean in the [phi/3, 3*phi] band, intercepts within 0.40; (b) PHYLO `phylo_unique(species)` (star tree, n_sp = 50, seed 101 -- the sibling's seed 2025 lands non-PD under the genuine NB1 draw `size = mu / phi`, a {101, 7, 42, 303, 404, 11} sweep fixed 101); asserts conv == 0, PD Hessian, `phylo_rr` flag, phi FINITE only (the phi<->phylo-variance confound legitimately pulls some per-trait phi to 0, matching the nbinom2-phylo mean-dependent convention), total phylo variance recovers via `extract_Sigma(level = "phy", part = "total")` inside the 4x trace band of `test-matrix-poisson-phylo.R`, intercept-mean within 0.6 (log); (c) SPATIAL `spatial_unique(0 + trait | site)` (per-trait independent SPDE, 100 sites, seed 20260529); asserts conv == 0, PD Hessian, `spde` flag, phi finite, kappa finite-positive, per-trait `log_tau_spde` finite, intercept-mean within 0.6 (log). All bands INHERITED from the nbinom2 / poisson / gamma sibling tier tests (no per-cell widening). `devtools::test(filter = "nbinom1")` under `GLLVMTMB_HEAVY_TESTS=1` is now 69 pass / 0 fail / 0 skip (31 matrix + 38 tiers); the 3 new tier cells skip cleanly when the heavy gate is off. Downstream extractor/simulate/profile NB1 wiring is a flagged follow-up. `truncated_nbinom1()` remains unwired. **Note (maintenance, do not fix until merge):** `R/enum.R` (single-response sdmTMB-style enum) lists `nbinom1 = 10`; the multi-trait engine uses `fit-multi.R` switch `nbinom1 = 15L`. The two constants are independent (different dispatch paths) and do not conflict today, but a maintainer wiring against `enum.R` for the multi engine would use the wrong constant. **Cross-package check added 2026-05-31** (`agent/distribution-validation-fills`): `test-crosspkg-nbinom1-glmmTMB.R` adds the NB1-vs-glmmTMB equivalence cell (the standalone fixture the poisson / nbinom2 cross-package tests had but nbinom1 lacked), mirroring `test-crosspkg-nbinom2-glmmTMB.R` exactly. On a shared 2-trait `value ~ 0 + trait + (1|site)` NB1 fixture (n = 300, glmmTMB given `dispformula = ~ 0 + trait` to match per-trait phi), gllvmTMB and glmmTMB agree to <1e-3 on per-trait intercepts and the shared random-intercept SD (0.05 absolute bands, inherited) and to ~1e-5 on per-trait dispersion phi (25% relative band, inherited). gllvmTMB's NB1 (Var = mu*(1+phi)) shares glmmTMB's nbinom1 parameterisation directly -- `exp(fixef$disp) == report$phi_nbinom1`, no NB2-style reciprocal. Honest-skip on glmmTMB-absent / non-convergence / weakly-identified phi (phi -> 0 or -> Inf in either engine). 3 cells, heavy not required (skip_on_cran-gated like its siblings); local measurement 2026-05-31 under `NOT_CRAN=true`: 3 pass / 0 fail. |
| FAM-08 | nbinom2 | `covered` | `test-nb2-recovery.R` | recovery test |
| FAM-09 | gamma (log) | `covered` | `test-family-gamma.R`, `test-matrix-gamma-unit.R`, `test-matrix-slope-gamma.R`, `test-tiers-gamma.R` | Recovery + slope + tiers green (local measurement 2026-05-30: 15 + 32, 0 fail). Prior "smoke only" under-claimed. |
| FAM-10 | beta (logit) | `covered` | `test-beta-recovery.R`, `test-matrix-beta-unit.R`, `test-matrix-slope-beta.R`, `test-tiers-beta.R` | Recovery + slope + tiers green (local measurement 2026-05-30: 15 + 36, 0 fail). |
| FAM-11 | lognormal | `covered` | `test-family-lognormal.R`, `test-matrix-lognormal.R` | Recovery green (local measurement 2026-05-30: 6 + 37, 0 fail). Prior "smoke only" under-claimed. |
| FAM-12 | student-t | `covered` | `test-student-recovery.R`, `test-matrix-student.R` | Recovery green (local measurement 2026-05-30: 13 + 49, 0 fail). |
| FAM-13 | tweedie | `covered` | `test-tweedie-recovery.R`, `test-matrix-tweedie.R` | Recovery green (local measurement 2026-05-30: 13 + 37, 0 fail). |
| FAM-14 | ordinal_probit | `covered` | `test-ordinal-probit.R`, `test-matrix-ordinal-unit.R`, `test-matrix-slope-ordinal.R`, `test-tiers-ordinal.R` | Recovery (cutpoints + intercepts, K=2/3/4) + slope + tiers green (local measurement 2026-05-30: 21 + 30, 0 fail). Prior "smoke only" inaccurate. Cross-package mirt `graded` check still outstanding. |
| FAM-15 | truncated_poisson / truncated_nbinom* | `partial` | `test-truncated-recovery.R` | recovery tests |
| FAM-16 | censored_poisson | `partial` | (not located) | smoke only |
| FAM-17 | delta_* families (10 variants) | `covered` (fixed/latent recovery); random structure **N/A by design** | `test-delta-gamma-recovery.R`, `test-delta-lognormal-recovery.R` | Single-family delta recovery green (local measurement 2026-05-30: 13 + 13 assertions, 0 fail). Per **Design 62**: two-part families are fixed-effect response distributions only — no latent/random/slope/tier structure (two link scales → species correlation undefined). Mixed-family delta latent-scale correlation remains the genuinely-blocked research item (Design 61 §B11). |
| FAM-18 | gamma_mix / lognormal_mix / nbinom2_mix | `blocked` | n/a | mixture families exported but not validated |
| FAM-19 | gengamma | `blocked` | n/a | exported but not validated |

### Section 3 — Random-effects structures

Row-owner: **Boole + Fisher** (random-effects design lead).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| RE-01 | Random intercepts only (`s = 0`) | `covered` | `test-multi-random-intercepts.R` | M0 baseline |
| RE-02 | One random slope (`s = 1`) | `covered` | `test-phylo-slope.R`, `test-matrix-slope-{poisson,nbinom2,gamma,beta,ordinal,binomial-logit,binomial-probit}.R` | Augmented random-regression slope recovers across all core families (local measurement 2026-05-30: 7 files, 0 fail) + Gaussian + animal (ANI-06) + `phylo_indep(1+x)` independent variant (this cycle). |
| RE-03 | Two or more random slopes (`s ≥ 2`) | `partial` | `test-phylo-dep-slope-s2-gaussian.R` | Gaussian `phylo_dep(1 + x1 + x2 \| sp)` **covered**: the dep path generalises from 2T to (1+s)T columns (zero C++ — the C++ dep likelihood is already dimension-general in `C = n_lhs_cols`); s = 2 recovers the full (1+s)T×(1+s)T Sigma_b within the inherited s = 1 bands (local measurement 2026-05-31: 986 expectations, 0 fail; slope-var hat {0.515, 0.293, 0.415, 0.373} vs truth {0.325, 0.266, 0.322, 0.260}). Non-Gaussian s ≥ 2 stays **reserved** (Gaussian-only family guard unchanged; full unstructured C×C not yet identifiable for non-Gaussian, PHY-18). s ≥ 3 is mechanically supported (code general in (1+s)) but not gating-tested. |
| RE-04 | Nested `unit / unit_obs` | `covered` | `test-multi-random-intercepts.R`, `test-olre-separation.R` | M0 baseline |
| RE-05 | Crossed (e.g. site × year) | `partial` | `test-stage1-stacked-fixed-effects.R` | smoke only |
| RE-06 | OLRE (observation-level random effect) | `covered` | `test-olre-separation.R`, `test-extract-omega.R`, `test-extractors-extra.R` | |
| RE-07 | `sigma_eps` auto-suppression for OLRE | `covered` | `test-sigma-eps-autosuppress.R` | |
| RE-08 | Cluster-level random effect (`cluster` argument) | `covered` | `test-cluster-rename.R` | |
| RE-09 | `latent + unique` paired in within-unit tier | `covered` | `test-mixed-response-unique-nongaussian.R`, `test-tiers-{poisson,nbinom2,gamma,beta,ordinal}.R`, `test-re09-latent-unique-unit.R` | unit_obs tier (latent+unique) recovers across core families (local measurement 2026-05-30: tiers files green, 0 fail). `test-re09-latent-unique-unit.R` (PR #366, issue #347) adds the dedicated same-grouping `latent(0+trait\|unit,d=K) + unique(0+trait\|unit)` recovery cell behind the behavioural-syndromes vignette: Lambda loading shape (Procrustes `cor_per_factor > 0.95`), Psi diagonal (deliberately wide band, split weakly identified), and total `Sigma_unit = Lambda Lambda^T + Psi` off-diagonals all recovered; `skip_if_not_heavy()` gated. Prior tier tests exercised only `unique()+unique()` / single OLRE, not a reduced-rank `latent()` block alongside `unique()`. |
| RE-10 | Augmented LHS guard (engine-internal variable name clashes) | `covered` | `test-augmented-lhs-guard.R` | |
| RE-11 | Second independent diagonal grouping (`cluster2` argument) | `covered` | `test-cluster2-rename.R`, `test-cluster2-families.R` | Issue #342 (sub-issues #355, #356). cluster2 is a renamed copy of the `cluster` (`diag_species` / `q_sp`) diagonal tier on a disjoint grouping column, so two crossed/nested plain diagonal per-trait variance components fit at once (e.g. `cluster = "site"` + `cluster2 = "year"`). Family-agnostic (contribution added to `eta` before family dispatch; no per-family C++ branch). Equivalence gate: a `cluster2`-routed `unique(0+trait\|G)` fit is byte-identical (objective + `extract_Sigma` delta = 0) to the `cluster`-routed fit on the same G (local measurement 2026-05-31: 24 pass / 0 fail, heavy crossed-recovery cell included; Gaussian site+year variances recovered within 0.30 band). Diagonal-only: `latent`/`rr`/`dep` on the cluster2 column aborts with a `unit =` redirect. Per-family recovery sweep (Slice F, #356; `test-cluster2-families.R`): for each wired family the simulated cluster2 diagonal variance is recovered within that family's sibling tier band, mirroring `test-tiers-*.R` conventions (local measurement 2026-05-31, `GLLVMTMB_HEAVY_TESTS=1`: 70 pass / 0 fail / 0 skip across gaussian, poisson, binomial, nbinom2, beta, Gamma, ordinal\_probit -- every cell conv == 0, PD Hessian, finite `sd_c2`, `extract_Sigma(level = "cluster2")$s == sd_c2^2`). cluster2 sits one level above any per-row residual / OLRE / overdispersion (shared across many rows per level), so no family is the structurally degenerate per-row case -- all seven recover, none skipped. |

### Section 4 — Phylogenetic GLLVM

Row-owner: **Noether + Boole** (phylo-specific math + parser).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| PHY-01 | Hadfield & Nakagawa sparse A⁻¹ | `covered` | `test-phylo-hadfield.R` | M0 baseline |
| PHY-02 | `phylo_latent + phylo_unique` paired | `covered` | `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` | M0 baseline |
| PHY-03 | Three-piece phylo fallback | `covered` | `test-phylo-q-decomposition.R` | |
| PHY-04 | `phylo_scalar(0 + trait \| sp)` | `covered` | `test-stage35-phylo-rr.R`, `test-phyloscalar-binary.R` | Phase B-INF Lane 2 / B1 (Design 58): binary probit recovery on shared `sigma^2_phy_scalar` (3x band, n_sp = 40, 4 binary replicates per cell) + CI smoke (`confint(parm = "lambda_phy", method = "profile")` finite). Note: `phylo_signal` parm does not apply -- the propto path sets `use$propto`, not `use$phylo_rr` / `use$phylo_diag`. |
| PHY-05 | `phylo_indep / phylo_dep` | `covered` | `test-stage35-phylo-rr.R`, `test-phylodepindep-binary.R` | Phase B-INF Lane 2 / B2 (Design 58): binary probit recovery + CI smoke (`confint(parm = "rho:phy:1,2", method = "profile")`) + `extract_correlations(tier="phy")` non-degenerate on both keywords. |
| PHY-06 | Phylo-slope keyword `phylo_slope()` | `covered` | `test-phylo-slope.R`, `test-matrix-slope-*.R`, `test-phylo-indep-slope-spike.R` | Gaussian + cross-family augmented slope recovery green; `phylo_indep(1+x)` cheap-route (cor pinned, no C++) validated this cycle (19/19). |
| PHY-07 | `extract_phylo_signal()` Adams (2014) | `covered` | `test-extract-omega.R`, `test-extractors-extra.R` | |
| PHY-08 | `extract_communality()` $H^2 + C^2 + \psi^2 = 1$ partition | `covered` | `test-extractors.R`, `test-extractors-extra.R` | |
| PHY-09 | Phylogenetic mode dispatch (paired vs three-piece) | `covered` | `test-phylo-mode-dispatch.R` | |
| PHY-10 | Optional `phyloVCV` argument | `covered` | `test-phylo-vcv-optional.R` | |
| PHY-11 | `phylo_indep(1 + x \| sp)` augmented slope under **binomial** (probit + logit) | `covered` | `test-binomial-slope-recovery.R` | Issue #341 Track B. Activated by relaxing the Gaussian-only family guard in `R/fit-multi.R` to admit `family_id in {gaussian, binomial}`; **ZERO new C++** -- the augmented-slope engine is family-agnostic (`eta += b_phy_aug . Z_phy_aug` accumulated BEFORE the C++ family dispatch), and `phylo_indep` only pins `atanh_cor_b` to 0 via the TMB map. Diagonal-Sigma_b recovery on a 6-seed grid (truth `sigma^2_int = 0.4`, `sigma^2_slope = 0.3`, `rho = 0`): every seed conv == 0 + PD Hessian + `cor_b` held EXACTLY at 0; seed-averaged recovery within a 0.25 relative band -- probit mean (`sigma^2_int = 0.364` rel 0.09, `sigma^2_slope = 0.291` rel 0.03), logit mean (`sigma^2_int = 0.354` rel 0.12, `sigma^2_slope = 0.328` rel 0.09) (local measurement 2026-05-31: 15/15 expectations pass, 0 fail). The other non-Gaussian families (poisson / nbinom2 / Gamma / Beta / ordinal) were subsequently activated the same way (PHY-12..PHY-16); families OFF the allowlist (e.g. tweedie) stay reserved fail-loud (`test-matrix-slope-phylo-indep.R`, allowlist-boundary lock). |

| PHY-12 | `phylo_indep(1 + x \| sp)` augmented slope under **poisson** (log) | `covered` | `test-phylo-indep-slope-nongaussian.R` | Issue #341 Track B. Same one-line family-allowlist relax as PHY-11 (runtime `family_id 2` added to the `R/fit-multi.R` guard); **ZERO new C++**. Diagonal-Sigma_b recovery, 6-seed grid (truth `sigma^2_int = 0.4`, `sigma^2_slope = 0.3`, `rho = 0`): every seed conv == 0 + PD Hessian + `family_id == 2` + `cor_b` held EXACTLY at 0; seed-mean within the **4x** band inherited from `test-matrix-slope-poisson.R` -- `sigma^2_int = 0.352` (ratio 0.88), `sigma^2_slope = 0.259` (ratio 0.86) (local measurement 2026-05-31). Activated only after this cell passed. |
| PHY-13 | `phylo_indep(1 + x \| sp)` augmented slope under **nbinom2** | `covered` | `test-phylo-indep-slope-nongaussian.R` | Issue #341 Track B. Allowlist relax (runtime `family_id 5`); **ZERO new C++**. Diagonal-Sigma_b recovery, 6-seed grid (truth 0.4 / 0.3 / rho 0): every seed conv == 0 + PD + `family_id == 5` + `cor_b == 0`; seed-mean within the **0.30 relative** band inherited from `test-matrix-slope-nbinom2.R` -- `sigma^2_int = 0.347` (rel 0.13), `sigma^2_slope = 0.328` (rel 0.09) (local measurement 2026-05-31). |
| PHY-14 | `phylo_indep(1 + x \| sp)` augmented slope under **Gamma** (log) | `covered` | `test-phylo-indep-slope-nongaussian.R` | Issue #341 Track B. Allowlist relax (runtime `family_id 4`); **ZERO new C++**. Diagonal-Sigma_b recovery, 6-seed grid, star tree (matching the sibling cell) (truth 0.4 / 0.3 / rho 0): every seed conv == 0 + PD + `family_id == 4` + `cor_b == 0`; seed-mean within the **3x** band inherited from `test-matrix-slope-gamma.R` -- `sigma^2_int = 0.437` (ratio 1.09), `sigma^2_slope = 0.243` (ratio 0.81) (local measurement 2026-05-31). |
| PHY-15 | `phylo_indep(1 + x \| sp)` augmented slope under **Beta** | `covered` | `test-phylo-indep-slope-nongaussian.R` | Issue #341 Track B. Allowlist relax (runtime `family_id 7`); **ZERO new C++**. Diagonal-Sigma_b recovery, 6-seed grid (truth 0.4 / 0.3 / rho 0): every seed conv == 0 + PD + `family_id == 7` + `cor_b == 0`; seed-mean within the **0.40 relative** band inherited from `test-matrix-slope-beta.R` -- `sigma^2_int = 0.347` (rel 0.13), `sigma^2_slope = 0.211` (rel 0.30) (local measurement 2026-05-31). |
| PHY-16 | `phylo_indep(1 + x \| sp)` augmented slope under **ordinal_probit** | `covered` | `test-phylo-indep-slope-nongaussian.R` | Issue #341 Track B. Allowlist relax (runtime `family_id 14`); **ZERO new C++**. Diagonal-Sigma_b recovery, 6-seed grid (truth `sigma^2_int = 0.6`, `sigma^2_slope = 0.5`, `rho = 0`, latent residual fixed `sigma_d^2 = 1`): every seed conv == 0 + PD + `family_id == 14` + `cor_b == 0`; seed-mean within the **2.5x** band inherited from `test-matrix-slope-ordinal.R` -- `sigma^2_int = 0.674` (ratio 1.12), `sigma^2_slope = 0.431` (ratio 0.86) (local measurement 2026-05-31). The Gaussian anchor cell (`test-phylo-indep-slope-gaussian.R`) was filled the same cycle (real recovery + wide/long byte-identity, replacing the Stage-3 skeleton skip). |
| PHY-17 | `phylo_latent(1 + x \| sp, d = 1)` augmented reduced-rank slope across **gaussian, binomial (probit + logit), poisson, nbinom2, Gamma, Beta, ordinal_probit** | `covered` | `test-matrix-slope-phylo-latent.R`, `test-phylo-latent-slope-gaussian.R` | Design 56 §9.5a. Activated by converting the Gaussian-only family guard in `R/fit-multi.R` to the same allowlist as PHY-11..PHY-16 (runtime `family_id in {0,1,2,4,5,7,14}`); **ZERO new C++** -- the block-diagonal reduced-rank slope eta is accumulated before the C++ family dispatch. The latent path is BLOCK-DIAGONAL (no intercept-slope correlation), so recovery targets the per-column `report$Sigma_phy_slope_slope` / `report$Sigma_phy_slope_intercept` channel (NOT the `sd_b` / `cor_b` channel the unique/dep paths emit). All 7 families: conv == 0 + PD Hessian + `use_phylo_latent_slope == 1` + `n_lhs_cols_lat == 2`; mean slope-block variance within the family band inherited from the matching `test-matrix-slope-*.R` sibling (local measurement 2026-05-31: 56/56 expectations pass, 0 fail). Two pre-existing test bugs were fixed this cycle: the engine-liveness guard `slope_latent_path_is_live()` was mis-keyed on `use_phylo_slope` / `n_lhs_cols` (the unique/dep flags, always 0 / 1 on a latent fit) -> corrected to `use_phylo_latent_slope` / `n_lhs_cols_lat`; the recovery harness read the absent `sd_b` / `cor_b` channel -> repointed to the `Sigma_phy_slope_*` channel the engine actually populates. Families OFF the allowlist (e.g. tweedie) stay reserved fail-loud. |
| PHY-18 | `phylo_dep(1 + x \| sp)` augmented full-unstructured slope under **non-Gaussian** families | `partial` (Gaussian `covered`; non-Gaussian reserved) | `test-matrix-slope-phylo-dep.R`, `test-phylo-dep-slope-gaussian.R` | Design 56 §9.5c. The `dep` engine is implemented and Gaussian-validated (`Sigma_b_dep` full `C x C`, `C = 2*n_traits`; recovery + wide/long byte-identity green). The `R/fit-multi.R` guard was converted to an allowlist but holds **gaussian only** (`family_id == 0`): unlike the diagonal `phylo_indep` (PHY-12..16) and block-diagonal `phylo_latent` (PHY-17) paths, the full unstructured covariance is not yet identifiable for the non-Gaussian families at the validation fixtures -- every non-Gaussian dep fit returns conv != 0 / non-PD Hessian (verified empirically across `n_sp` up to 100, `n_rep` up to 10). Per the #388 discipline, non-Gaussian dep stays reserved fail-loud until a recovery cell passes; the `test-matrix-slope-phylo-dep.R` cells honest-skip at the converge/PD guard (7/7 skip, 0 fail). NOTE: the matrix-dep recovery harness also reads the 2-vector `sd_b` channel, which is incompatible with the `dep` engine's `C`-wide `Sigma_b_dep` -- this would need repointing too before the non-Gaussian dep cells can pass. |

### Section 5 — Spatial GLLVM

Row-owner: **Boole + Gauss** (SPDE inheritance from sdmTMB).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| SPA-01 | SPDE mesh construction via `make_mesh()` | `covered` | `test-mesh.R` | inherited from sdmTMB |
| SPA-02 | `spatial_latent` + `spatial_unique` paired | `covered` | `test-spatial-latent-recovery.R`, `test-spatial-pair-binary.R` | Phase B-INF Lane 2 / B3 (Design 58): binary probit paired fit on n_sites = 120, n_traits = 3, K = 1 fixture with SPDE Matern (range = 0.3) — `pd_hessian == TRUE`, both engine slots (`use$spde`, `use$spatial_latent`) toggled, and `confint(parm = "rho:spatial:i,j", method = "profile")` returns a finite bound on at least one upper-tri pair. |
| SPA-03 | `spatial_scalar` | `covered` | `test-stage4-spde.R`, `test-spatial-scalar-binary.R` | Phase B-INF Lane 2 / B4 (Design 58): binary probit recovery + CI smoke (`confint(parm = "tau_spde", method = "profile")`) + tied-tau contract verified (`log_tau_spde` entries collapse to a single value via TMB `map`). |
| SPA-04 | `spatial_indep / spatial_dep` | `covered` | `test-stage4-spde.R`, `test-spatial-depindep-binary.R` | Phase B-INF Lane 2 / B5 (Design 58): binary probit recovery + CI smoke on 80-site × 3-trait SPDE fixture (range = 0.4, sigma2_spa = 1.0, cutoff = 0.12) -- `spatial_indep` fits with `pd_hessian == TRUE` and finite-positive `kappa` + per-trait `log_tau_spde`; `spatial_dep` fits with `pd_hessian == TRUE`, routes through `spatial_latent(d = n_traits)`, returns a finite `confint(parm = "rho:spatial:i,j", method = "profile")` bound on at least one upper-tri pair, and `extract_correlations(tier = "spatial")` is non-degenerate. |
| SPA-05 | Spatial mode dispatch | `covered` | `test-spatial-mode-dispatch.R` | |
| SPA-06 | Spatial orientation handling (X/Y) | `covered` | `test-spatial-orientation.R`, `test-utm-conversions.R` | |
| SPA-07 | Spatial deprecation (legacy aliases) | `covered` | `test-spatial-deprecation.R` | |
| SPA-08 | `extract_Sigma(level = "spatial")` on the base SPDE-slope path (`spatial_unique` / `spatial_indep (1 + x \| coords)`, the `use_spde_slope` engine) | `covered` (Gaussian) | `test-extract-sigma-spde-base-slope.R` | Issue #354 part (a), shipped PR #367. `R/fit-multi.R` stores `fit$use$spde_slope`; `R/extract-sigma.R` adds an `extract_Sigma` branch (placed before, and guarded `!isTRUE(fit$use$spde_dep_slope)` so the `spatial_dep` path still routes to its own 4x4 branch) returning the 2x2 cross-field `Sigma_field` with `intercept`/`slope` dimnames, `R[1,2] == cor_spde_b`, finite-positive `kappa_s`, and a `note` documenting the marginal conversion `sigma_marg = sd_spde_b / (sqrt(4*pi) * kappa_s)`, on the SPDE parameterisation scale (tau absorbed, consistent with the `spde_dep` branch). `test-extract-sigma-spde-base-slope.R` (34 checks) verifies the 2x2 read-out for `spatial_unique` / `spatial_indep` and that `spatial_dep` still returns the interleaved 4x4. Gaussian-only; `extract_correlations` is intentionally NOT extended (its tier detection keys on intercept-only RR flags, matching the `spde_dep` / `phylo_dep` precedent). |
| SPA-09 | `spatial_latent(1 + x \| site, d = K)` augmented block-diagonal reduced-rank slope under **non-Gaussian** families | `covered` (Gaussian + binomial-probit / poisson / Gamma / Beta at the matrix fixture; `partial` for binomial-logit / ordinal_probit / nbinom2 at the default fixture seed) | `test-matrix-slope-spatial-latent.R`, `test-spatial-latent-slope-gaussian.R` | Design 64 §3. The `use_spde_latent_slope` engine (each LHS column gets its own `Lambda_k Lambda_k^T`, no intercept-slope correlation) was already Gaussian-validated; the `R/fit-multi.R` family guard was converted to an allowlist `c(0L,1L,2L,4L,5L,7L,14L)` (gaussian, binomial probit/logit, poisson, nbinom2, Gamma, Beta, ordinal_probit) per the #388/#392 discipline, ZERO new C++. Empirically all seven non-Gaussian families CONSTRUCT + CONVERGE; at the matrix fixture (n=100, seed 20260529, cutoff 0.1) four are PD (binomial-probit, poisson, Gamma, Beta — covered, 24 assertions pass) and three (binomial-logit, ordinal_probit, nbinom2) are non-PD at that specific seed but PD at alternate seeds (202/303) and at n=150 — a power/seed artifact, not non-identifiability, so they stay allowlisted and honest-skip at the default fixture (the documented remedy is wider n / different seed). Harness fixes mirrored from the #392 phylo_latent PR: the path-live guard keys on `use_spde_latent_slope` / `n_lhs_cols_spde_lat == 2` (NOT the intercept-only `fit$use$spatial_latent` flag, which an augmented slope fit does not set); recovery reads `report$Sigma_spde_slope_{intercept,slope}`; the CI smoke is a finite sdreport SE on `theta_rr_spde_slope` (the block-diagonal latent exposes no `rho:spatial` token and `extract_correlations(tier="spatial")` keys on the intercept-only flag); the nbinom2 expected `family_id` was corrected 3 -> 5. test-matrix-slope-spatial-latent.R: 24 pass / 3 honest-skip / 0 fail. |
| SPA-10 | `spatial_dep(1 + x \| site)` augmented full-unstructured 2T×2T field-covariance slope under **non-Gaussian** families | `partial` (Gaussian `covered`; non-Gaussian reserved) | `test-matrix-slope-spatial-dep.R`, `test-spatial-dep-slope-gaussian.R` | Design 64 §2. The `use_spde_dep_slope` engine (full unstructured `Sigma_field`, `C x C`, `C = 2*n_traits`, built from `theta_spde_dep_chol`; nests under `use_spde_slope`) is implemented and Gaussian-validated (recovery + analytic `Sigma_field (x) Q^{-1}` prior nll to 1e-9 + wide/long byte-identity). The `R/fit-multi.R` guard was split off from the shared base/dep gaussian-only abort and converted to an allowlist holding **gaussian only** (`c(0L)`): like `phylo_dep` (PHY-18), the full unstructured cross-field covariance is not identifiable for the non-Gaussian families at the validation fixtures — every non-Gaussian dep fit returns conv != 0 / non-PD (verified empirically across all 7 families at n=100). Non-Gaussian dep stays reserved fail-loud until a recovery cell passes; `test-matrix-slope-spatial-dep.R` honest-skips at construction (7/7 skip, 0 fail). The dep test's engine-routing flags were corrected to the augmented-slope flags `fit$use$spde_dep_slope` / `spde_slope` (the augmented covstruct carries `.spatial_dep_augmented` and does NOT set the intercept-only `spatial_dep` / `spatial_latent` flags), and the nbinom2 / Beta expected `family_id` values were corrected (3 -> 5, 5 -> 7); these assertions are currently unreached because the cells skip at construction, but are now correct for the day dep becomes identifiable. |

### Section 6 — Meta-analysis (meta_V)

Row-owner: **Fisher + Boole** (meta-analysis with known V).

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| MET-01 | Single-V `meta_V(V = V)` (additive `type = "exact"` default) | `partial` | `test-formula-grammar-smoke.R`, `test-traits-keyword.R`, `test-gllvmTMB-args.R` | V-only named and positional parser forms verified; wide `traits(...)` marker preservation verified; single-V smoke only; direct `glmmTMB::equalto()` LL comparator still needed |
| MET-02 | Block-V within-study correlation | `covered` | `test-block-V.R` | |
| MET-03 | `meta_V(V = V, type = "proportional")` (Nakagawa 2022) | `blocked` | n/a | post-CRAN; parser errors explicitly rather than silently treating it as exact |
| MET-04 | `corvidae-two-stage` two-stage workflow | `partial` | n/a | article pulled to `dev/workshop-articles/` in PR-0C.PULL (Gaussian meta-analytical example; deferred per maintainer 2026-05-16 — restore once a live cross-check fixture exists) |

### Section 6.5 — Known-relatedness keyword family (animal models)

Row-owner: **Boole + Gauss + Rose** (formula grammar + engine +
A-vs-V boundary). Added M2.8 (2026-05-17) per
[`14-known-relatedness-keywords.md`](14-known-relatedness-keywords.md).
The animal_* keyword family is pure sugar over the existing
`phylo_*` engine path; byte-equivalence with `phylo_*(vcv = A)` is
the test contract.

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| ANI-01 | `animal_scalar(id, pedigree=/A=/Ainv=)` | `covered` | `test-animal-keyword.R` | byte-equiv with `phylo_scalar(species, vcv = pedigree_to_A(ped))` to 1e-6 |
| ANI-02 | `animal_unique(id, ...)` | `covered` | `test-animal-keyword.R` | byte-equiv with `phylo_unique(vcv = A)` |
| ANI-03 | `animal_indep(0 + trait \| id, ...)` | `covered` | `test-animal-keyword.R` | byte-equiv with `phylo_indep(vcv = A)` |
| ANI-04 | `animal_dep(0 + trait \| id, ...)` | `covered` | `test-animal-keyword.R` | byte-equiv with `phylo_dep(vcv = A)` |
| ANI-05 | `animal_latent(id, d = K, ...)` | `covered` | `test-animal-keyword.R` | byte-equiv with `phylo_latent(vcv = A)` |
| ANI-06 | `animal_slope(x \| id)` | `covered` | `test-animal-slope-recovery.R` (PR #313) | Recovery validated: byte-equivalent to `phylo_slope(vcv = A)` to 1e-5; 32 assertions, full suite 3302/0. (Note: the augmented `animal_unique(1+x\|id)` correlated reaction-norm form now routes/fits rather than aborting -- see ANI-11; PR #367.) |
| ANI-07 | `pedigree_to_A()` Henderson formula | `covered` | `test-animal-keyword.R` | `nadiv::makeAinv()` cross-check available when nadiv installed |
| ANI-08 | Sparse `Ainv = ` direct engine path | `covered` (helper shipped PR #179 2026-05-18; engine auto-routing shipped 2026-05-18) | `tests/testthat/test-pedigree-sparse-ainv.R`, `tests/testthat/test-pedigree-sparse-ainv-engine.R` | Design 47 §10. `animal_*(pedigree = ped)` now auto-routes through `pedigree_to_Ainv_sparse()` and the sparse-Ainv engine path in `R/fit-multi.R` (mirrors the `phylo_tree → MCMCglmm::inverseA` route). Engine path identified via `inherits(fit$phylo_vcv, 'sparseMatrix')`. 8 byte-equivalence tests (scalar + unique, sparse vs dense) at `1e-6`. **Pre-CRAN per maintainer 2026-05-18.** |
| ANI-09 | Multi-matrix animal models (G + permanent-environment + maternal) | `partial` | n/a | Achievable today by combining `animal_*` with sibling `(1 \| id)`; idiomatic article example v0.3.0 |
| ANI-10 | Cross-package agreement against MCMCglmm / WOMBAT | `partial` | n/a | Phase 5.5 grid work |
| ANI-11 | `animal_unique(1 + x \| id)` augmented correlated intercept+slope routing **and 2x2 read-out** | `covered` (fits / routes / 2x2 read-out) | `test-animal-unique-routing.R`, `test-extract-sigma-augmented-unique.R` | Issue #354 part (b), shipped PR #367; read-out gap closed by PR #373. The correlated reaction-norm LHS `vec(B) ~ N(0, Sigma_b (x) A)` (Sigma_b a 2x2 with FREE intercept-slope correlation) now routes through the `phylo_unique` augmented engine instead of the old fail-loud abort that misdirected users to `animal_slope`. `R/brms-sugar.R` `animal_unique` handler emits `.phylo_unique_augmented = TRUE` with `atanh_cor_b` free (no `.indep`). `test-animal-unique-routing.R` (13 checks) confirms it fits (`use_phylo_slope_correlated == 1L`, not the dep path, `n_lhs_cols == 2L`) and is byte-identical to `phylo_unique(1+x\|id, vcv = pedigree_to_Ainv_sparse(ped))` (logLik + report-reconstructed Sigma_b diff = 0) and matches the dense `pedigree_to_A(ped)` call to ~1e-4; bare `animal_unique(id)` and intercept-only `animal_unique(0+trait\|id)` forms unchanged; a genuinely unsupported bar LHS still fails loud. **Read-out (PR #373):** the correlated 2x2 (intercept, slope) covariance READ-OUT is now surfaced by `extract_Sigma(fit, level = "phy")` for both `phylo_unique(1 + x \| sp)` and the same-engine `animal_unique(1 + x \| id)`. `R/extract-sigma.R` adds an `extract_Sigma` branch (placed before the generic `phy` handler, guarded `!isTRUE(fit$use$phylo_dep_slope)` and keyed on the scalar `report$cor_b` that ONLY the closed-form unique/indep path emits) returning the 2x2 `Sigma = D R D` (`D = diag(report$sd_b)`, `R = [[1, cor_b], [cor_b, 1]]`) with `intercept`/`slope` dimnames, `level = "phy_unique_slope"`, `part = "slope"`. This mirrors the spatial analogue SPA-08 and surfaces the FREE-correlation `unique` 2x2 honestly (#373). `test-extract-sigma-augmented-unique.R` (27 checks) asserts the read-out equals the engine's own `D R D` reconstruction to < 1e-6 with correct dimnames (Gaussian), an `animal_unique` smoke cell on the long surface, and that `phylo_dep(1 + x \| sp)` still routes to its own interleaved 4x4 branch (guard regression). `extract_correlations` is intentionally NOT extended (matching the `phylo_dep` / `spde_dep` / SPA-08 precedent, whose tier detection keys on intercept-only RR flags). |

### Section 6.6 — Generic kernels and cross-lineage coevolution

Row-owner: **Boole + Fisher + Curie** (generic kernel grammar,
identifiability, and simulation recovery). Added Design 65
(2026-05-31). C0 validates the biological kernel and the existing
dense `phylo_latent(vcv=K)` route before any new engine work. C1 adds
the generic dense `kernel_*()` formula surface by reusing that
phylo-equivalent path; C2 is still required before advertising
cross-lineage coevolution as a fitted biological model.

| ID | Capability | Status | Test evidence | Notes |
|----|------------|--------|---------------|-------|
| KER-01 | `make_cross_kernel(A_H, A_P, W, rho)` builds a PSD cross-lineage block kernel | `covered` | `test-coevolution-prototype.R` | C0 helper only. Validates symmetry, supplied diagonal blocks, unit diagonal, PSD, and fail-loud guards for invalid bridge strength / matrix scale. No parser or TMB engine change. |
| COE-01 | Cross-lineage coevolution prototype via existing `phylo_latent(..., vcv = K_star) + phylo_unique(..., vcv = K_star)` | `covered` | `test-coevolution-prototype.R` (heavy); superseded by `test-coevolution-recovery.R` (heavy) | C0 prototype checks planted host-partner `Gamma` recovery through the existing dense phylo path on block-missing `traits(...)` data. C2 supersedes the prototype with the generic `kernel_*()` path and the `extract_Gamma()` recovery gate. |
| KER-02 | Generic dense `kernel_latent()` / `kernel_unique()` / `kernel_indep()` / `kernel_dep()` formula family | `covered` | `test-kernel-equivalence.R` | Design 65 C1. Single named dense kernel tier reuses the phylo-equivalent dense `vcv` path. Equivalence tests cover bare latent, latent + unique, unique, indep, and dep against dense `phylo_*()` `vcv = A` paths to less than `1e-6` for log likelihood and extracted Sigma. No `kernel_scalar()` surface in C1. |
| COE-02 | Validated cross-lineage coevolution engine with `extract_Gamma()` | `covered` | `test-coevolution-recovery.R` (fast extractor tests; heavy recovery/sensitivity gate) | Design 65 C2. `extract_Gamma()` slices the named kernel tier's shared Sigma block. Heavy evidence covers known-`Gamma` recovery on block-missing host/partner data, a block-diagonal zero-`Gamma` null with lower logLik, rotation-invariant Gamma extraction, loading-orientation checks on the fitted dense-kernel recovery fixture, and a sparse-versus-dense single-`W` sensitivity case. Uncertainty intervals and `rho` profiling remain workflow/documentation layers, not new engine claims. |

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
| EXT-13 | `bootstrap_Sigma()` | `covered` (Gaussian) / `partial` (non-Gaussian) | `test-bootstrap-Sigma.R` | M3.3b surface admission (Design 50) controls the next non-Gaussian evidence movement. Known-phi point diagnostics are not bootstrap coverage. |
| EXT-14 | `getLoadings()` raw $\Lambda$ | `covered` | `test-rotate-compare-loadings.R` | rotation-variant; warn |
| EXT-15 | `rotate_loadings()` varimax / promax | `covered` | `test-rotate-compare-loadings.R`, `test-rotation-advisory.R` | Rotation is for interpretation of loading columns; covariance, correlation, communality, and uniqueness remain the primary rotation-invariant summaries. `plot(type = "ordination")` exposes the same order/sign-anchor convention for biplots. |
| EXT-16 | `getLV()` legacy ordination alias | `covered` | `test-extractors.R` | slated for `deprecate_soft()` 0.3.0 |
| EXT-17 | `getResidualCor / Cov()` glmmTMB-style | `covered` | `test-extractors.R` | |
| EXT-18 | `extract_Sigma_table()` report-ready Sigma/Psi/R table | `covered` | `test-extract-sigma-table.R`, `test-plot-gllvmTMB.R` | point-estimate table view over `extract_Sigma()`; interval columns intentionally `none` / `NA` |
| EXT-19 | `plot_correlations()` / `plot_Sigma_table()` tidy covariance/correlation forest and confidence-eye plots | `covered` | `test-plot-covariance-tables.R` | Report-ready ggplot helpers over `extract_correlations()` and `extract_Sigma_table()` rows; intervals are displayed when input bounds are finite but not computed by the plotting helpers. Confidence eyes are soft filled frequentist compatibility displays with hollow estimate markers, not posterior densities; `style = "raindrop"` remains a compatibility alias. |
| EXT-20 | `extract_Sigma_table()` bootstrap interval rows | `covered` | `test-extract-sigma-table.R`, `test-plot-covariance-tables.R` | Converts `bootstrap_Sigma()` Sigma/R point estimates and percentile bounds to the same report-ready row schema; does not compute new bootstrap intervals or itself cover communality / repeatability rows. |
| EXT-21 | `extract_communality()` bootstrap object rows and communality plot intervals | `covered` | `test-extract-communality-bootstrap.R`, `test-plot-gllvmTMB.R` | Reuses `bootstrap_Sigma(..., what = "communality")` point estimates and percentile bounds without rerunning refits; `plot(type = "communality", boot = boot)` overlays supplied `c^2` intervals. |
| EXT-22 | `extract_repeatability()` bootstrap object rows and integration plot intervals | `covered` | `test-extract-repeatability-bootstrap.R`, `test-plot-gllvmTMB.R` | Reuses `bootstrap_Sigma(..., what = "ICC")` point estimates and percentile bounds without rerunning refits; `plot(type = "integration", boot = boot)` accepts raw `bootstrap_Sigma()` objects for repeatability and communality intervals. |
| EXT-23 | `plot(type = "correlation")` / `plot(type = "correlation_ellipse")` bootstrap correlation intervals | `covered` | `test-plot-gllvmTMB.R` | Merges `bootstrap_Sigma(..., what = "R")` percentile bounds into correlation heatmap and ellipse data; ellipse borders/stars mark supplied intervals that do not cross zero. |
| EXT-24 | `plot_correlations()` bootstrap object input | `covered` | `test-plot-covariance-tables.R` | Converts `bootstrap_Sigma(..., what = "R")` summaries to row-first correlation forest/confidence-eye plots without requiring hand-built pairwise rows. |
| EXT-25 | `compare_Sigma_table()` estimate-vs-truth table helper | `covered` | `test-extract-sigma-table.R` | Joins fitted/report-ready Sigma or R rows to a supplied truth matrix for simulation and teaching figures; table helper only, no plotting or calibration claim. |
| EXT-26 | `plot_Sigma_comparison()` estimate-vs-truth plot helper | `covered` | `test-plot-covariance-tables.R` | Plots `compare_Sigma_table()` rows as row-labelled error plots or estimate-vs-truth scatter plots, including optional `facet = "comparison"` panels for precomputed model/specification labels; visual comparison helper only, no simulation or calibration claim. |
| EXT-27 | `plot_Sigma_heatmap()` matrix-style Sigma/R heatmap helper | `covered` | `test-plot-covariance-tables.R` | Plots `extract_Sigma_table()` rows as trait-by-trait heatmaps for covariance or correlation matrices; point-estimate visual helper only, intervals are preserved in plot data but not displayed. |
| EXT-28 | `extract_rotated_loadings_table()` report-ready rotated loading rows | `covered` | `test-rotate-compare-loadings.R` | Row-first table over `rotate_loadings()` for ordination reports and figures; includes rotation, axis-ordering, sign-anchor, anchor-trait, raw axis-variance/share, and raw/standardized loading scale metadata. Point-estimate helper only; no loading uncertainty intervals. |
| EXT-29 | `plot_rotated_loadings()` rotated loading matrix helper | `covered` | `test-rotate-compare-loadings.R` | Plots fitted-model or `extract_rotated_loadings_table()` rows as a report-ready loading matrix with rotation/sign/loading-scale metadata preserved in `gllvmTMB_meta` / `gllvmTMB_data`; point-estimate visual helper only, no loading uncertainty intervals. |
| EXT-30 | `plot_correlations()` heatmap / ellipse matrix styles | `covered` | `test-plot-covariance-tables.R`, `test-plot-visual-snapshots.R` | Adds matrix-style correlation heatmap and ellipse/oval views over fitted-model, `bootstrap_Sigma()`, or `extract_correlations()` rows, with full/lower/upper triangle controls, diagonal control, optional estimate/CI labels, `matrix_layout = "estimate_ci"` for upper estimates plus lower interval bounds, `matrix_layout = "levels"` for two-level upper/lower matrices such as `unit` over `unit_obs`, and significance outlines/stars for supplied intervals that exclude zero. Snapshot guards cover the estimate-CI heatmap and two-level ellipse matrix layouts. Plotting helper only; it does not compute intervals or calibrate uncertainty. |

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
| DIA-08 | `check_gllvmTMB(fit)` machine-readable fit-health table | `covered` | `test-sanity-multi.R` | Design 49 + #248. Returns stable rows for optimizer convergence, gradient, `sdreport()` availability, `pdHess`, Hessian rank, fixed-effect SEs, restart provenance, selected restart, simple boundary flags, loading-rotation convention, weak latent-axis share, near-zero `psi`, `sigma_eps` boundary, and broad cross-loading structure. Treats `pdHess = FALSE` and weak latent-axis rows as inference / identifiability warnings rather than automatic point-estimate failure. |
| DIA-09 | `sdreport()` failure degradation path | `partial` | `test-sanity-multi.R` | Design 49. Fit construction wraps `TMB::sdreport()` and records `fit$sdreport_error`; diagnostics are covered on a forced degraded object. A deterministic in-fit TMB `sdreport()` failure fixture is still needed before this row can move to `covered`. |
| DIA-10 | `gllvmTMBcontrol(se = FALSE)` hard-fit point-estimate path | `covered` | `test-sanity-multi.R`, `test-gllvmTMBcontrol.R` | Design 49. Lets hard models skip `TMB::sdreport()` intentionally, return point estimates, and route uncertainty to bootstrap/profile workflows. Diagnostics report `sdreport` as `WARN` with a skipped-SE message. |
| DIA-11 | `predictive_check()` fitted-model diagnostic plots | `covered` (Gaussian / Poisson / NB2 scoped plots) / `partial` (other families and formal tests) | `test-predictive-diagnostics.R` | Design 51 + #228. Exports package-specific fitted-model predictive plots rather than a Bayesian `pp_check()` claim. Q-Q, rootogram, grouped-statistic, and density-overlay plots return `ggplot` objects with plotted data, `check_gllvmTMB()` rows, and `fit$fit_health` metadata in `attr(plot, "gllvmTMB_diagnostic")`. Diagnostic display only; no interval calibration, latent-rank proof, or DHARMa-equivalent formal test. |
| DIA-12 | `residuals.gllvmTMB_multi()` randomized-quantile and simulation-rank residuals | `covered` (Gaussian / Poisson / NB2 exact residuals plus simulation fallback) / `partial` (other families) | `test-predictive-diagnostics.R` | Design 51 + #228. Exact family-CDF randomized-quantile residuals are implemented for Gaussian, Poisson, and NB2 rows; `type = "simulation_rank"` remains the fitted-model simulation fallback. Unsupported or non-finite rows are retained with explicit `status`, and residual objects carry `check_gllvmTMB()` / `fit_health` metadata. |
| DIA-13 | `diagnostic_table()` metadata table extraction | `covered` | `test-predictive-diagnostics.R` | Design 51 + #228 follow-up. Extracts plotted/residual data, row-status counts, fit-health status counts, and the attached `check_gllvmTMB()` rows from `predictive_check()` plots or diagnostic residual data frames without requiring article code to inspect `attr(x, "gllvmTMB_diagnostic")` directly. Table extraction only; no new diagnostics, formal tests, refits, or uncertainty calibration. |

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
| CI-08 | `coverage_study()` ≥ 94 % empirical coverage gate (PR #120) | `partial` (M3.3 production gate failed) | `test-coverage-study.R`; `dev/precomputed/coverage-gaussian-d2.rds` (R = 200, PR-0C.COVERAGE); `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md` (R = 200 Actions run 26100827665) | M3.3 profile-psi production run completed 2026-05-19: workflow passed 15/15 jobs, but only Gaussian d=1 and Gaussian d=3 cleared the 94 % gate; 13/15 cells remain below gate and 236/3000 replicate fits failed. No production RDS promoted to `inst/extdata/`; Design 50 now requires surface admission, target-explicit total `Sigma_unit[tt]`, and a diagnostic report before coverage claims move. |
| CI-09 | Fisher-z CI on correlations | `covered` | `test-fisher-z-correlations.R` | |
| CI-10 | profile / Wald / bootstrap on mixed-family fits | `partial` | `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md` | M3.3 mixed-family production cells did not clear the profile-psi coverage gate: d=1 0.820, d=2 0.685, d=3 0.550, with 105/600 failed replicate fits. Design 50 keeps this as triage evidence until target-explicit mixed-family surfaces pass admission and promotion gates. |

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
| MIS-03 | `gllvmTMB_wide(Y, ...)` legacy constructor | `partial` | `test-gllvmTMB-wide.R`, `test-wide-weights-matrix.R` | soft-deprecated in 0.2.0; retained for migration and matrix-first workflows |
| MIS-04 | Weight column unified handling | `covered` | `test-weights-unified.R`, `test-lme4-style-weights.R` | |
| MIS-05 | `simulate.gllvmTMB_multi()` family-aware draws (per-row family dispatch) | `covered` | `test-m1-8-bootstrap-mixed-family.R`, `test-simulate-site-trait.R` | M1.8 (PR #157) — `.draw_y_per_family()` dispatches by `family_id_vec`; 6 families (gaussian / binomial / poisson / lognormal / Gamma / nbinom2) covered; others fall back with one-time warning |
| MIS-06 | `tidy.gllvmTMB_multi()` broom-style output | `covered` | `test-tidy-predict.R` | |
| MIS-07 | `predict.gllvmTMB_multi()` link / response | `partial` | `test-tidy-predict.R` | family-aware predict typed outputs is M2 |
| MIS-08 | `print.gllvmTMB_multi()` summary label discipline | `covered` | `test-print-labels.R` | |
| MIS-09 | `plot.gllvmTMB_multi()` dispatcher | `partial` | `test-plot-gllvmTMB.R`, `test-plot-visual-snapshots.R` | Seven dispatcher types are object-shape tested (`correlation`, `correlation_ellipse`, `loadings`, `integration`, `communality`, `variance`, `ordination`), including bootstrap interval overlays and rotated ordination metadata. Visual snapshots now cover Confidence Eye correlation plots, Sigma-table Confidence Eye plots, and anchored rotated ordination; still partial until broader rendered-figure QA covers the full dispatcher surface. |
| MIS-10 | brms-style sugar | `covered` | `test-brms-sugar.R` | |
| MIS-11 | `traits(...)` LHS expansion | `covered` | `test-traits-keyword.R` | |
| MIS-12 | `gllvmTMBcontrol()` control object | `covered` | `test-gllvmTMBcontrol.R` | |
| MIS-13 | Integration tour (end-to-end) | `covered` | `test-integration-tour.R` | M0 baseline |
| MIS-14 | `gllvmTMB-args.R` argument validation | `covered` | `test-gllvmTMB-args.R` | |
| MIS-15 | `profile_targets()` controlled vocabulary (PR #109) | `covered` | `test-profile-targets.R` | drmTMB-style |
| MIS-16 | `init_strategy = "single_trait_warmup"` (M3.4 Mitigation A) | `covered` | `test-m3-4-warmstart-phi-clamp.R` | Design 48 §2-A. Opt-in via `gllvmTMBcontrol(init_strategy = "single_trait_warmup")`. Fits an intercept-only univariate GLM per trait (with that trait's family) and seeds `log_phi_*` entries before MakeADFun. Phi-bearing families covered: nbinom1, nbinom2, beta, betabinomial, truncated_nbinom2, gamma_delta (intercept-only seed only; per-trait `b_fix` warmup deferred). |
| MIS-17 | Phi starting-value clamp `[0.01, 100]` (M3.4 Mitigation B) | `covered` | `test-m3-4-warmstart-phi-clamp.R` | Design 48 §2-B. Applied to all `log_phi_*` entries at init regardless of `init_strategy`. Defensive — clamps both default zero inits (no-op) and warm-started values (pulls pathological theta from glm.nb iteration-limit cases back into a safe range). |
| MIS-18 | `start_method = list(method = "res")` residual reduced-rank starts | `covered` | `test-start-method-residual.R`, `test-gllvmTMBcontrol.R` | Design 48 §2-A2. Opt-in via `gllvmTMBcontrol(start_method = list(method = "res", jitter.sd = 0.2))`. Seeds `theta_rr_*` and latent scores from grouped fixed-effect residual matrices, rotates loadings to the engine's lower-triangular convention, and seeds paired `unique()` residual terms when present. Contract-tested; convergence-rate claims remain M3 production-grid evidence, not unit-test evidence. |
| MIS-19 | `start_method = list(method = "indep")` and manual `start_from` simpler-fit starts | `covered` | `test-start-method-residual.R`, `test-gllvmTMBcontrol.R` | Design 48 §2-A3. Opt-in GLMM/GLLVM warm start for Gaussian two-level latent+unique fits: fit the matching independent `unique()`-only model or a user-supplied simpler fit, then copy same-shaped estimated TMB parameters into the full model's starting list. Contract-tested; default-policy and convergence-rate claims require M3 target-explicit evidence. |
| MIS-20 | `restart_history` and `start_provenance` on fitted objects | `covered` | `test-stage39-multi-start.R`, `test-sanity-multi.R` | Design 49. Every fit records one row per attempted optimizer start, the selected restart, optimizer/start method, jitter scale, objective, convergence code, message, elapsed time, and start provenance. This is provenance only; it does not itself validate a start strategy's convergence-rate benefit. |
| MIS-21 | Missing response cells in long and wide data | `covered` | `test-missing-response.R`, `test-traits-keyword.R`, `test-wide-weights-matrix.R` | Response-missing rows/cells are dropped before fitting; other observed traits for the same unit remain in the likelihood. Predictor/design missingness still errors. |
| MIS-22 | Morphometrics cached bootstrap correlation fixture | `covered` | `test-example-morphometrics.R` | Ships `inst/extdata/examples/morphometrics-bootstrap-r.rds` for article rendering and visual QA of the confidence-eye correlation display and `plot(type = "correlation_ellipse", boot = boot)`; the fixture is not interval-calibration evidence. |

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
