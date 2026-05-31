# 61 — Capability Status and Dependency-Ordered Work-List (gllvmTMB)

**Status date:** 2026-05-31 (§1b/§1c/§2/§3/§B reconciled against origin/main HEAD 3ef12df, post PR #313/#367/#373/#381; original audits 2026-05-30)
**Sources:** 4 read-only domain audits (ARTICLES, ENGINE-slopes, REGISTER, VALIDATION), since superseded for the slope/family rows by direct verification against the merged code. Line/PR references below are re-verified via Bash against `origin/main` tree 2026-05-31; the up-to-date source of truth is the validation-debt register (Design 35).
**Scope:** Synthesis only. The slope-family and nbinom1 rows were reconciled 2026-05-31 against `origin/main` HEAD 3ef12df (post PR #313/#367/#373/#381): several rows previously described a pre-campaign state and were corrected to match the merged engine (`R/brms-sugar.R`, `R/fit-multi.R`, `src/gllvmTMB.cpp`).

This document is a status snapshot plus a two-track work-list. The central, load-bearing finding is in §2 and §4: **the augmented random-slope engine is family-general and now carries Gaussian (and, for `phylo_indep`, binomial) reaction-norm fits with ZERO new C++; the structured spatial slope engines (`use_spde_slope` / `use_spde_latent_slope`) are built and Gaussian-validated, with non-Gaussian RESERVED behind a family guard rather than absent. The remaining structured-slope work is non-Gaussian coverage and recovery studies, not "build the engine" — but it is still maintainer-sequenced, not mass agent fan-out, because the slope keywords share engine data contracts.**

---

## 1. Capability matrix (family × structure × slope × tier)

Legend: **C** = covered (recovery/cross-check evidence), **P** = partial (smoke or single-scale/single-DGP only), **N** = not-implemented, **B** = blocked (needs derivation), **—** = not applicable.

The `slope` column refers specifically to the richer **`(0 + trait + trait:x | group)`** intercept+slope LHS (random-regression / reaction-norm). The intercept-only forms are captured by the structure columns.

### 1a. Structure × scale (intercept-only LHS)

| Structure keyword | Gaussian | Binary / probit | Other non-Gaussian | Register IDs |
|---|---|---|---|---|
| `scalar (0+trait \| unit)` | P (Gaussian only) | — | — | FG-09 (P) |
| `indep (0+trait \| unit)` | P (Gaussian only) | — | — | FG-07 (P) |
| `dep (0+trait \| unit)` | P (Gaussian only) | — | — | FG-08 (P) |
| `unit_obs` / nested unit | C | C | C | RE-04 (C) |
| `cluster` (rename of `species`) | C | — | — | RE-08 (C) |
| `phylo_scalar` | C | C | — | PHY-04 (C) |
| `phylo_indep / phylo_dep` | C | C | — | PHY-05 (C) |
| `phylo_latent (+ phylo_unique)` | C | C | — | (PHY family, intercept path) |
| `spatial_latent (+ spatial_unique)` | C | C | — | SPA-02 (C) |
| `spatial_scalar` | C | C | — | SPA-03 (C) |
| `spatial_indep / spatial_dep` | C | C | — | SPA-04 (C) |
| animal-model (sparse-A) scalar/unique/indep/dep/latent | C | C | — | ANI-01..ANI-05 (C, 1e-6 byte-eq) |

### 1b. Structure × **slope** (`0 + trait + trait:x | group`)

Legend reminder: **C** = covered, **P** = partial, **N** = not-implemented, **R** = reserved (engine exists; this family/cell is fail-loud by contract pending validation), **—** = n/a.

> Provenance: §1b/§1c/§2/§3/§4/§B rows reconciled 2026-05-31 against origin/main HEAD 3ef12df (post PR #313/#367/#373/#381). The validation-debt register (Design 35) is the source of truth.

| Slope keyword | Parser accepts richer LHS? | Engine support? | Validated? | Remaining work |
|---|---|---|---|---|
| `phylo_slope` (existing scalar-slope path) | yes | yes | **C** — cross-family augmented recovery (RE-02, FG-15) | — (exists) |
| `animal_slope(x \| id)` | yes | yes (desugars to `phylo_slope(vcv = A)`) | **C** — recovery + 1e-5 byte-eq (ANI-06, PR #313) | — (exists) |
| `phylo_indep` slope | yes (augmented `1 + x` rewritten to `phylo_slope`, `.indep=TRUE`) | yes (family-general augmented `b_phy_aug`, ZERO new C++) | **C** Gaussian + binomial (probit+logit, PHY-06/PHY-11, #381); **R** poisson/nbinom2/gamma/beta/ordinal | non-Gaussian B-slice validation (RESERVED by `c(0L,1L)` allowlist, not absent) |
| `phylo_dep` slope | yes (augmented `1 + x` rewritten to `phylo_slope`) | yes (full unstructured 2T×2T) | **C** Gaussian; **R** non-Gaussian | non-Gaussian dep-slope slice |
| `phylo_latent` slope | yes (augmented `1 + x` routes to `use_phylo_latent_slope`) | yes (block-diagonal reduced-rank) | **C** Gaussian; **R** non-Gaussian | non-Gaussian latent-slope slice |
| `spatial_indep` slope | yes (augmented `1 + x`; diagonal special case of base SPDE slope) | yes (`use_spde_slope`) | **C** Gaussian (test-spatial-indep-slope-gaussian.R); **R** non-Gaussian | non-Gaussian path + recovery |
| `spatial_dep` slope | yes (augmented `1 + x`; base SPDE slope, full 4×4) | yes (`use_spde_slope` / `use_spde_dep_slope`) | **C** Gaussian (test-spatial-dep-slope-gaussian.R); **R** non-Gaussian | non-Gaussian path + recovery |
| `spatial_latent` slope | yes (augmented `1 + x`, `d = K`) | yes (`use_spde_latent_slope`, separate block) | **C** Gaussian (test-spatial-latent-slope-gaussian.R); **R** non-Gaussian | non-Gaussian path + recovery |

Also Gaussian-validated: `spatial_unique(1 + x | coords)` recovery (test-spatial-unique-slope-gaussian.R), the diagonal-cross-field base of the SPDE slope engine.

### 1c. Family × validation tier

| Family | Recovery | Cross-package | Register / Validation IDs |
|---|---|---|---|
| gaussian | C | C (vs glmmTMB `rr()`) | FG-04 (C) |
| binomial / probit | C | C (vs mirt 2PL) | (M2.3 mirt cross-check) |
| poisson | C | **N** (no glmmTMB sister fixture) | FAM-06 (recovery C; cross-pkg N) |
| nbinom2 | C | **N** (no glmmTMB cross-check) | FAM-08 (recovery C; cross-pkg N) |
| nbinom1 | C (wired on main: fid 15L, `log_phi_nbinom1` init + TMB map; unit-cell recovery) | N (no glmmTMB NB1 LL-agreement fixture) | FAM-07 (un-skipped 2026-05-31; recovery `covered`; cross-pkg N) |
| gamma (log) | C (recovery: intercepts + CV; `test-family-gamma.R`) | P (no cross-pkg comparator) | FAM-09 (C recovery; cross-pkg remains P) |
| beta (logit) | C (recovery) | P (no clean comparator) | FAM-10 (P) |
| ordinal_probit | C (recovery: cutpoints + intercepts K=2/3/4; `test-ordinal-probit.R`) | P (no mirt `graded` cross-check) | FAM-14 (C recovery; cross-pkg remains P) |
| delta / hurdle | **B** | B | FAM-17, MIX-10 (blocked) |

### 1d. CI-method tier (profile / Wald / bootstrap)

| Estimand scale | Profile/Wald/bootstrap | Coverage gate (≥94%) | IDs |
|---|---|---|---|
| Gaussian ICC / communality / correlations | C (three-method API) | **FAILING** — 13/15 cells < gate; only Gaussian d=1, d=3 clear | CI-02..CI-07 (C); CI-08 (needs-update) |
| Binary latent-scale ICC / correlations | C (Gaussian-validated path) | not separately gated this cycle | CI-02..CI-07 |
| Mixed-family (Gaussian+Binomial) | P | **FAILING** — d=1 0.820, d=2 0.685, d=3 0.550 | CI-10 (P) |
| Ordinal cutpoints / variance components | **N** (CI not extended to ordinal) | — | EXT-10 (P) |

---

## 2. Random-slope-mode reality table

This is the table that matters most for planning. **Reconciled 2026-05-31 against origin/main HEAD 3ef12df (post PR #313/#367/#373/#381).** The pre-campaign version of this table asserted that the structured slope engines did not exist and that the augmented engine needed new C++ per keyword; the merged code shows otherwise. The augmented-slope engine is family-general (`eta += b_phy_aug . Z_phy_aug` is accumulated BEFORE the C++ family dispatch), and the SPDE slope engines are built. What is reserved is non-Gaussian *coverage*, enforced by family guards — not the engine.

| Slope mode | Current parser behaviour | Engine status | Gaussian validated? | Non-Gaussian | Test evidence today |
|---|---|---|---|---|---|
| `phylo_slope` (scalar slope, existing) | accepted, fits | done | yes | family-general | **cross-family augmented recovery** (test-phylo-slope.R, test-matrix-slope-*.R) — RE-02/FG-15 **C** |
| `animal_slope(x \| id)` | accepted, desugars to `phylo_slope(vcv = A)` | done | yes | family-general | **recovery + 1e-5 byte-eq** (test-animal-slope-recovery.R, PR #313; real `expect_equal(sigma_slope_hat, ...)`) — ANI-06 **C** |
| `phylo_indep` slope | augmented `1+x \| sp` parsed (R/brms-sugar.R ~2786), rewritten to `phylo_slope(.indep=TRUE)` | done (ZERO new C++; family-general `b_phy_aug`) | yes | **binomial covered** (probit+logit, #381); poisson/nbinom2/gamma/beta/ordinal **RESERVED** via `c(0L,1L)` allowlist (R/fit-multi.R:760) | test-phylo-indep-slope-spike.R (Gaussian), test-binomial-slope-recovery.R (binomial), test-matrix-slope-phylo-indep.R (reserved-family fail-loud) — PHY-06/PHY-11 |
| `phylo_dep` slope | augmented `1+x` parsed, rewritten to `phylo_slope` | done (full unstructured 2T×2T) | yes | **RESERVED** (family guard at R/fit-multi.R, `family_id != 0L` fail-loud) | Gaussian recovery (Design 56 §9.5c) |
| `phylo_latent` slope | augmented `1+x` routes to `use_phylo_latent_slope` | done (block-diagonal reduced-rank) | yes | **RESERVED** | Gaussian recovery (Design 56 §9.5a) |
| `spatial_indep` slope | augmented `1+x` parsed; diagonal special case of base SPDE slope | done (`use_spde_slope`) | yes | **RESERVED** (R/fit-multi.R:308, "validated for gaussian() only") | test-spatial-indep-slope-gaussian.R (real recovery) |
| `spatial_dep` slope | augmented `1+x` parsed; base SPDE slope, full 4×4 | done (`use_spde_slope` / `use_spde_dep_slope`) | yes | **RESERVED** (R/fit-multi.R:308) | test-spatial-dep-slope-gaussian.R (recovery + analytic prior nll, 1e-9) |
| `spatial_latent` slope | augmented `1+x`, `d = K`, own engine block | done (`use_spde_latent_slope`) | yes | **RESERVED** (R/fit-multi.R:335, "validated for gaussian() only") | test-spatial-latent-slope-gaussian.R (real recovery) |

**Key correction (reconciled 2026-05-31).** The pre-campaign claim that `phylo_indep` slopes are "not doable without C++" is false against the merged code: the augmented `phylo_indep(1 + x | sp)` desugars to the family-general `phylo_slope` augmented engine (`.indep=TRUE` only pins `atanh_cor_b` to 0 via the TMB map) and was activated for binomial in PR #381 with ZERO new C++ by relaxing the Gaussian-only family guard to `family_id in {gaussian, binomial}` (R/fit-multi.R:760). Likewise the structured spatial slope engines (`use_spde_slope`, `use_spde_latent_slope`; Design 64) are built and Gaussian-validated. The remaining work is non-Gaussian *coverage* (new validation cells behind the reserved family guards), not new engine construction. This is still maintainer-sequenced rather than mass agent fan-out, because the slope keywords share the `b_phy_*` / `g_phy` / SPDE-field data contracts and the eta-construction loops.

---

## 3. The three overclaims

These are places where current documentation or status posture asserts more capability than the evidence supports. (The inverse — register entries that *under*-claim relative to existing tests — are handled as consolidation items in Track A, §4, and are listed separately below so they are not confused with overclaims.)

**Overclaim 1 — RESOLVED by the merged code (reconciled 2026-05-31; no longer an overclaim).**
The pre-campaign posture held that only Gaussian `phylo_slope` was real, that `animal_slope`'s recovery was deferred with `skip_until_stage3()` / `expect_true(TRUE)` placeholder bodies, and that every structured slope (`phylo/spatial × indep/dep/latent`) was not-implemented at the engine. Against origin/main HEAD 3ef12df this is now false on all three counts: (i) `animal_slope(x | id)` has a real recovery + 1e-5 byte-equivalence study (ANI-06, `test-animal-slope-recovery.R`, PR #313 — `expect_equal(sigma_slope_hat, sqrt(fx$sigma2_slope))`, no placeholders); (ii) the augmented `phylo_indep(1 + x | sp)` slope is **covered for Gaussian and binomial** (probit + logit, PHY-06/PHY-11, PR #381) with ZERO new C++; (iii) all six structured slope engines (`phylo/spatial × indep/dep/latent`) are **built and Gaussian-validated** (Design 56 / Design 64), with non-Gaussian RESERVED behind family guards. **Honest posture now:** "Gaussian augmented random regression is validated across the keyword family; `phylo_indep` is additionally binomial-covered; non-Gaussian for the other structured modes is RESERVED (engine exists, family-guard fail-loud) pending validation cells."

**Overclaim 2 — Profile/Wald/bootstrap CIs are presented as validated, but the Gaussian coverage gate is failing.**
`profile-likelihood-ci.Rmd` and the covariance/CI articles showcase the three-method API as complete for Gaussian, and CI-02..CI-07 are genuinely covered for *point* behaviour. But the **coverage** study (CI-08) is `needs-update`: the M3.3 production run cleared the ≥94% gate on **only Gaussian d=1 and d=3 — 13/15 cells remain below**, with 236/3000 replicate fits failing. Calibrated coverage is not established for most cells; Design 50 now gates promotion on surface admission + target clarity + a diagnostic report. **Honest posture:** "point estimation and CI machinery validated; calibrated interval coverage is established only for Gaussian d=1/d=3 and is an open gate elsewhere."

**Overclaim 3 — Mixed-family CIs are framed as near-ready M3 polish; coverage actually collapses.**
`joint-sdm.Rmd` and `mixed-family-extractors.Rmd` frame mixed-family communality/repeatability/correlation CIs as imminent M3 milestone work (CI-10 "partial"). The M3.3 production run **failed the gate badly** on mixed-family cells: d=1 coverage **0.820**, d=2 **0.685**, d=3 **0.550** against a ≥0.94 target. This is an `engine-C++` problem (target-explicit `Sigma_unit[tt]` rather than `psi`, plus a diagnostic report), not a documentation gap. **Honest posture:** "mixed-family CI coverage is a known engine deficiency (0.55–0.82 observed), not a near-complete feature."

**Not overclaims — register under-claims resolved in this pass (2026-05-31):**
- **FAM-09 (gamma, log):** Register (Design 35) already reads `covered` (`test-family-gamma.R` + `test-matrix-gamma-unit.R` + `test-matrix-slope-gamma.R` + `test-tiers-gamma.R`; 15 + 32 assertions, 0 fail). §1c updated to `C` for recovery / `P` for cross-package. Cross-package comparator (gllvm Procrustes or glmmTMB LL) still outstanding.
- **FAM-14 (ordinal_probit):** Register (Design 35) already reads `covered` (`test-ordinal-probit.R` + `test-matrix-ordinal-unit.R` + `test-matrix-slope-ordinal.R` + `test-tiers-ordinal.R`; 21 + 30 assertions, 0 fail). §1c updated to `C` for recovery / `P` for cross-package. Cross-package mirt `graded` fixture still outstanding.

---

## 4. Two-track work-list

### Track A — Safe parallel work (agent-dispatchable today)

These items are documentation, register hygiene, a single cheap parser change, and cross-package test fixtures. They touch no engine math and have no shared mutable state beyond the register file (§A-reg, which should be serialized). Ordered by dependency: register truth and the capability matrix must settle before articles that cite them; the parser-guard lift and the new article depend on the slope-reality table being agreed.

| # | Item | What it delivers | Effort | Parallel-agent today? | Depends on |
|---|---|---|---|---|---|
| A1 | **Register consolidation** (FAM-09, FAM-14 §1c done in this pass 2026-05-31; FAM-07 §1c + §B8 reconciled to "wired on main / recovery covered"; ANI-06/PHY-06/RE-02/FG-15 now read `covered` per Design 35; CI-08 "needs-update", CI-10 "partial") | Single source of truth for status; §1c under-claims resolved; FAM-07/slope rows reconciled to merged code | S | **Yes** (one owner; serialize writes to register) | — |
| A2 | **Capability matrix freeze** (this doc §1–§2 ratified as the status reference) | Shared status table every article links to | S | **Yes** | A1 |
| A3 | **`api-keyword-grid.Rmd`** — confirm "partial" mapping for animal/phylo rows (audit: already current) | No-op verification; guards against drift | S | **Yes** (read-mostly) | A1 |
| A4 | **`choose-your-model.Rmd`** decision-tree rewrite: extend ladder past spatial to `animal_slope`/`phylo_slope`; add non-Gaussian-slope and CI-method (Wald vs profile vs bootstrap) guidance; cite PHY-06, ANI-06, CI-10 as partial | Honest complexity ladder | L | **Yes** | A1, A2 |
| A5 | **`animal-model.Rmd`** — showcase `animal_slope(x\|id)` usage; recovery is now **validated** (ANI-06, 1e-5 byte-eq, PR #313), so present it as a covered Gaussian mode; add phylo_unique/animal_unique non-Gaussian note | Documents a validated keyword | M | **Yes** | A1, A2 |
| A6 | **`phylogenetic-gllvm.Rmd`** — add `phylo_slope` reaction-norm tutorial section (Gaussian + `phylo_indep` binomial, both validated); add `unit_obs` + cluster trait-covariance decomposition | Fills the validated slope paths | M | **Yes** | A1, A2 |
| A7 | **`joint-sdm.Rmd`** — add profile/Wald/bootstrap CI examples for ICC/correlations on the binary latent scale; flag mixed-family CI coverage as failing (CI-10), do **not** imply readiness | Binary-scale CI worked examples, honestly bounded | M | **Yes** | A1, A2 |
| A8 | **NEW `random-regression-reaction-norms.Rmd`** — anchor slope-family keywords; scope to the validated cases: Gaussian augmented `phylo_slope`/`animal_slope` (both recovery-validated) and Gaussian structured slopes (`phylo/spatial × indep/dep/latent`, all built + Gaussian-validated), plus `phylo_indep` binomial; mark the other structured non-Gaussian cells as RESERVED (fail-loud, validation pending), not absent | The advertised "how do I fit reaction norms?" entry point, scoped to reality | L | **Yes** (but must respect §2/§3 caveats) | A1, A2, A6 |
| A9 | **Poisson (FAM-06) cross-package glmmTMB fixture** | Closes the obvious cross-check gap; binomial/nbinom2/gaussian already have one | S | **Yes** (independent test file) | — |
| A10 | **nbinom2 (FAM-08) cross-package glmmTMB fixture** | Validates M3.3 production-grid family vs sister package | S–M | **Yes** (independent test file) | — |
| A11 | **DONE on main** — the `phylo_indep(1 + x \| sp)` augmented-slope parser route is shipped (R/brms-sugar.R ~2786; desugars to `phylo_slope(.indep=TRUE)`), engine is family-general (ZERO new C++), and the cell is **covered** for Gaussian + binomial (PR #381). No longer pending. | (delivered) | — | — | — |

Notes for Track A dispatch:
- **A1 is the chokepoint.** Run it first and single-owner; all article work (A4–A8) reads the register it produces.
- **A9/A10 are fully independent** of everything else and can launch immediately in parallel.
- **A3** is verification-only (audit says `api-keyword-grid.Rmd` is already current).
- Articles already marked `done`/`current` in the audit (lambda-constraint, profile-likelihood-ci, behavioural-syndromes, covariance-correlation, morphometrics, functional-biogeography, stacked-trait-gllvm, psychometrics-irt, response-families, convergence-start-values, cross-package-validation, gllvm-vocabulary, pitfalls, data-shape-flowchart, troubleshooting-profile, simulation-recovery-validated, simulation-verification, roadmap, ordinal-probit) need **no change this cycle** and are out of scope for Track A.

### Track B — Engine / C++ work (maintainer or expert; **NOT mass-agent fan-out**)

**Reconciled 2026-05-31:** the structured-slope engines that the pre-campaign version of this table listed as unbuilt (B1, B4–B6) are in fact **built and Gaussian-validated** on origin/main HEAD 3ef12df. For those items the remaining work is the **non-Gaussian path + recovery study** behind the existing family guards, not new TMB parameter blocks. The items below still require expert/maintainer work — coverage studies, cross-package fixtures, and the genuinely unbuilt pieces (B2/B3 non-Gaussian, the delta/hurdle derivation B11) — and they remain **not decomposable into independent agent tasks**: the slope keywords share the `b_phy_*` / `g_phy` / SPDE-field data contracts and the eta-construction loops, so changes interact. **Do not attempt to deliver these by fan-out.**

| # | Item | Why it is engine-C++ / not-agent | Effort | Gate to validate |
|---|---|---|---|---|
| B1 | **DONE for Gaussian + binomial; non-Gaussian RESERVED.** `phylo_indep(1 + x \| sp)` uses the family-general augmented `b_phy_aug` engine (ZERO new C++; `.indep=TRUE` pins `atanh_cor_b` to 0 via the TMB map). Gaussian + binomial (probit+logit) covered (PHY-06/PHY-11, PR #381). Remaining: validate poisson/nbinom2/gamma/beta/ordinal cells, then relax the `c(0L,1L)` family allowlist (R/fit-multi.R:760). | Non-Gaussian *validation*, not engine build | validation | non-Gaussian recovery on the reserved cells |
| B2 | **`phylo_dep` slope engine** — `b_phy_dep_slopes`, 2×2 intercept-slope Cholesky per species block, T×2 LHS matrix | Block-wise quadratic forms; shares `b_phy_*` contract with B1 | engine-C++ | slope-variance + cross-(intercept,slope) cor recovery |
| B3 | **`phylo_latent` slope engine** — 3D `g_phy_slope (n_aug × d_phy × n_lhs_cols)`, `Z_phy_aug` reindex (gllvmTMB.cpp:200/269/557-621) | Reduced-rank Λ_phy extended by a new dimension; depends on intercept latent path | engine-C++ | recovery on reduced-rank slope loadings |
| B4 | **`spatial_indep` slope engine — BUILT (`use_spde_slope`), Gaussian-validated.** Non-Gaussian RESERVED behind the family guard (R/fit-multi.R:308, "validated for gaussian() only"). | Non-Gaussian *path + recovery*, not engine build | validation | non-Gaussian spatial slope recovery |
| B5 | **`spatial_latent` slope engine — BUILT (`use_spde_latent_slope`, separate block), Gaussian-validated.** Non-Gaussian RESERVED (R/fit-multi.R:335). | Non-Gaussian *path + recovery*, not engine build | validation | non-Gaussian shared-field slope recovery |
| B6 | **`spatial_dep` slope engine — BUILT (`use_spde_slope`/`use_spde_dep_slope`, full 4×4), Gaussian-validated** (recovery + analytic prior nll to 1e-9). Non-Gaussian RESERVED (R/fit-multi.R:308). | Non-Gaussian *path + recovery*, not engine build | validation | non-Gaussian full-unstructured slope recovery |
| B7 | **DONE — `animal_slope(x\|id)` recovery study shipped** (ANI-06, PR #313). `test-animal-slope-recovery.R` has real `expect_equal(sigma_slope_hat, sqrt(fx$sigma2_slope))` + 1e-5 byte-equivalence to `phylo_slope(vcv = A)` (32 assertions); the `skip_until_stage3()`/`expect_true(TRUE)` skeletons are gone. Open: non-Gaussian animal-slope cells. | (delivered for Gaussian) | validation | non-Gaussian animal-slope recovery |
| B8 | **nbinom1 wired on main; unit-cell recovery covered** (FAM-07). Engine on origin/main: fid 15L, `log_phi_nbinom1` init (R/fit-multi.R:1898) + TMB map (R/fit-multi.R:2288) + C++ `fid==15` branch (src/gllvmTMB.cpp:1601); `test-matrix-nbinom1.R` recovery green, un-skipped 2026-05-31. Open: tier/phylo/spatial coverage + a glmmTMB `rr()` NB1 LL-agreement cross-check fixture. | Cross-package fixture + extended coverage | M | tier/phylo/spatial coverage; glmmTMB NB1 agreement |
| B9 | **Gaussian coverage gate** (CI-08) — drive 13/15 failing cells to ≥94%; resolve 236/3000 fit failures | Engine + estimand work behind Design 50 surface-admission gate | engine-C++ | ≥94% across the cell grid + diagnostic report |
| B10 | **Mixed-family CI coverage** (CI-10) — target-explicit `Sigma_unit[tt]` not `psi`; lift d=1/2/3 from 0.55–0.82 | Estimand redefinition + engine; precedes any mixed-family CI article promotion | engine-C++ | ≥0.94 mixed-family coverage + diagnostic report |
| B11 | **Delta/hurdle latent-scale correlation formula** (FAM-17, MIX-10) | **Blocked** — two scales (occurrence + continuous); single latent-residual formula undefined. Needs mathematical derivation **before** any code | engine-C++ (blocked) | derivation first, then mixed-family delta/hurdle fits |
| B12 | **Cross-package empirical-agreement grids** (ANI-10 vs MCMCglmm/Hmsc; SPA-01..07 vs sdmTMB/gllvm; ordinal vs mirt `graded`; Phase 5.5 ~810-cell sweep) | Large empirical sweeps, expert-designed DGPs; explicitly Phase 5.5 / not M2 | engine-C++ / Phase 5.5 | per-grid agreement bands |

**Why Track B cannot fan out (reconciled 2026-05-31):** the structured-slope engines (B1, B4–B6) are now built and Gaussian-validated, but their remaining non-Gaussian work — plus any genuinely unbuilt pieces (B2/B3 non-Gaussian, B11's delta/hurdle derivation) — still mutate the same shared engine data contracts (`b_phy_*` for correlated phylo blocks, `g_phy`/`Z_phy_aug` for latent phylo, the SPDE field arrays for spatial) and the shared linear-predictor loops. Parallel edits and the family-guard relaxations would collide in the `.cpp` and in the TMB parameter map, so they must be sequenced by a maintainer. The validation items (B7–B12) are gated by Design 50 / Phase 5.5 evidence protocols and require expert DGP design, not template tests.

---

## 5. One-line bottom line

The intercept-level phylo/spatial/animal stack is broadly **covered** (often on the binary scale too). The random-**slope** stack is, as of origin/main HEAD 3ef12df, **Gaussian-validated across the keyword family**: augmented `phylo_slope` and `animal_slope` recover (with 1e-5 byte-equivalence), all six structured modes (`phylo/spatial × indep/dep/latent`) have built engines with Gaussian recovery, and `phylo_indep` is additionally **binomial-covered** (probit+logit, ZERO new C++). Non-Gaussian for the other structured modes is **RESERVED** — fail-loud behind family guards, validation pending, *not* unbuilt; `nbinom1` is wired with unit-cell recovery covered. Meanwhile the **CI coverage gates (Gaussian CI-08 and mixed-family CI-10) are failing** and must not be documented as done. Track A (docs, register hygiene, two cross-package fixtures) is safe to parallelize today; Track B (non-Gaussian slope coverage + the remaining derivations) is maintainer-sequenced, not fan-out.
