# 61 — Capability Status and Dependency-Ordered Work-List (gllvmTMB)

**Status date:** 2026-05-30
**Sources:** 4 read-only domain audits (ARTICLES, ENGINE-slopes, REGISTER, VALIDATION).
**Scope:** Synthesis only. Line/PR references below are quoted from the input audits against the `gllvmTMB` source tree (`R/brms-sugar.R`, `src/gllvmTMB.cpp`); they were **not** re-verified in this pass.

This document is a status snapshot plus a two-track work-list. The central, load-bearing finding is in §2 and §4: **every richer-LHS random-slope keyword in the phylo/spatial family is `not-implemented` at the engine level, and only `phylo_indep`'s parser guard — not its math — is cheap. None of the structured slope modes can be delivered by mass agent fan-out.**

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

| Slope keyword | Parser accepts richer LHS? | Engine support? | Validated? | Effort to deliver |
|---|---|---|---|---|
| `phylo_slope` (existing scalar-slope path) | yes | yes | **P** — Gaussian only (RE-02) | — (exists) |
| `animal_slope(x \| id)` | yes (parser-accepted) | scalar path only | **P** — recovery deferred (ANI-06) | L (recovery study) |
| `phylo_indep` slope | N | N | N | guard **S** → engine **C++** |
| `phylo_dep` slope | N | N | N | guard **S** → engine **C++** |
| `phylo_latent` slope | N | N | N | guard **S** → engine **C++** |
| `spatial_indep` slope | N | N | N | guard **S** → engine **C++** |
| `spatial_dep` slope | N | N | N | guard **S** → engine **C++ (L)** |
| `spatial_latent` slope | N | N | N | guard **S** → engine **C++** |

### 1c. Family × validation tier

| Family | Recovery | Cross-package | Register / Validation IDs |
|---|---|---|---|
| gaussian | C | C (vs glmmTMB `rr()`) | FG-04 (C) |
| binomial / probit | C | C (vs mirt 2PL) | (M2.3 mirt cross-check) |
| poisson | C | **N** (no glmmTMB sister fixture) | FAM-06 (recovery C; cross-pkg N) |
| nbinom2 | C | **N** (no glmmTMB cross-check) | FAM-08 (recovery C; cross-pkg N) |
| nbinom1 | **P — smoke only** | N | FAM-07 (P) |
| gamma (log) | P→ (recovery exists; see §3) | P (no cross-pkg) | FAM-09 (P) |
| beta (logit) | C (recovery) | P (no clean comparator) | FAM-10 (P) |
| ordinal_probit | P→ (recovery exists; see §3) | P (no mirt `graded` cross-check) | FAM-14 (P) |
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

This is the table that matters most for planning. It reconciles the ENGINE audit (what the code can do) against the REGISTER audit (what has test evidence). **"Parser-only doable" is a property of lifting the guard; it does NOT mean the fit works** — in every structured case the linear predictor and prior likelihood need new C++ parameter blocks.

| Slope mode | Current parser behaviour | Parser-guard lift | Engine math needed | Parser-only sufficient? | Test evidence today |
|---|---|---|---|---|---|
| `phylo_slope` (scalar slope, existing) | accepted, fits | done | done | — | **Gaussian recovery** (test-phylo-slope.R; per-species slope cor > 0.85) — RE-02 **P** |
| `animal_slope(x \| id)` | accepted, fits scalar path | done | scalar done; richer slopes not | partial | **none** — skeletons gated `skip_until_stage3()`, bodies are `expect_true(TRUE)` — ANI-06 **P** |
| `phylo_indep` slope | guard rejects (brms-sugar.R:2506) | **S** (extend `.is_zero_plus_trait` / add `.is_long_intercept_slope`) | **C++**: new `b_phy_indep_slopes` block + MVN prior `Σ_b ⊗ A_phy_indep` + eta loop expand | **NO** | none |
| `phylo_dep` slope | guard rejects (:2582) | **S** (same predicate fix) | **C++**: `b_phy_dep_slopes`, 2×2 Cholesky per species block, T×2 LHS matrix | **NO** | none |
| `phylo_latent` slope | no guard; rewrites to `phylo_rr` (:2210) | **S** (add bar inspection before rewrite) | **C++**: 3D `g_phy_slope (n_aug × d_phy × n_lhs_cols)` + `Z_phy_aug` reindex | **NO** | none |
| `spatial_indep` slope | no slope guard; via `normalise_spatial_orientation` (:2526) | **S** (post-normalise bar inspection) | **C++**: `omega_spde_slope (n_mesh × n_traits × n_lhs_cols)` + per-trait eta sum | **NO** | none |
| `spatial_dep` slope | `.assert_no_augmented_lhs` blocks (:2608) | **S** (relax assert w/ `.allow_intercept_slope`) | **C++ (L)**: `theta_rr_spde_lv` → T×T×n_lhs_cols Cholesky; `omega_spde_lv_slope` | **NO** | none |
| `spatial_latent` slope | no slope guard; rewrites to `spde(...)` (:2450) | **S** (bar inspection before rewrite) | **C++**: `theta_rr_spde_lv_slope (T × K_S × n_lhs_cols)` + Z slope indicators | **NO** | none |

**Key correction to a tempting assumption.** The ENGINE audit explicitly checked whether `phylo_indep` slopes are "doable WITHOUT C++" and answered **NO**. `phylo_indep` *intercepts* reuse the `phylo_unique` engine path (rank-T diagonal Λ), which is fully implemented — but slopes route to separate `phylo_slope` machinery (`b_phy_indep_slopes`, likelihood at gllvmTMB.cpp:543-621 / 780-785) that does not exist. The only cheap, fan-out-safe slice anywhere in this family is the **`phylo_indep` parser-guard lift in isolation** (S), and even that is only useful once paired with the C++ work — shipping the guard alone would accept syntax the engine cannot fit.

---

## 3. The three overclaims

These are places where current documentation or status posture asserts more capability than the evidence supports. (The inverse — register entries that *under*-claim relative to existing tests — are handled as consolidation items in Track A, §4, and are listed separately below so they are not confused with overclaims.)

**Overclaim 1 — Random slopes are advertised as a usable keyword family; only Gaussian `phylo_slope` is real.**
Articles (`animal-model.Rmd`, `phylogenetic-gllvm.Rmd`, vocabulary/grid/flowchart pages) reference `animal_slope` and `phylo_slope` as available keywords, and a new `random-regression-reaction-norms.Rmd` is proposed as a worked tutorial. But the only random-slope mode with recovery evidence is **`phylo_slope` on a Gaussian DGP** (RE-02). `animal_slope` is parser-accepted with **no** recovery study (ANI-06); its Gaussian skeleton tests are `skip_until_stage3()` placeholders with `expect_true(TRUE)` bodies. Every structured slope (`phylo/spatial × indep/dep/latent`) is `not-implemented` at the engine. **Honest posture:** "one random-slope mode validated (phylo, Gaussian); animal-slope parser-accepted but recovery deferred; structured slopes not yet implemented."

**Overclaim 2 — Profile/Wald/bootstrap CIs are presented as validated, but the Gaussian coverage gate is failing.**
`profile-likelihood-ci.Rmd` and the covariance/CI articles showcase the three-method API as complete for Gaussian, and CI-02..CI-07 are genuinely covered for *point* behaviour. But the **coverage** study (CI-08) is `needs-update`: the M3.3 production run cleared the ≥94% gate on **only Gaussian d=1 and d=3 — 13/15 cells remain below**, with 236/3000 replicate fits failing. Calibrated coverage is not established for most cells; Design 50 now gates promotion on surface admission + target clarity + a diagnostic report. **Honest posture:** "point estimation and CI machinery validated; calibrated interval coverage is established only for Gaussian d=1/d=3 and is an open gate elsewhere."

**Overclaim 3 — Mixed-family CIs are framed as near-ready M3 polish; coverage actually collapses.**
`joint-sdm.Rmd` and `mixed-family-extractors.Rmd` frame mixed-family communality/repeatability/correlation CIs as imminent M3 milestone work (CI-10 "partial"). The M3.3 production run **failed the gate badly** on mixed-family cells: d=1 coverage **0.820**, d=2 **0.685**, d=3 **0.550** against a ≥0.94 target. This is an `engine-C++` problem (target-explicit `Sigma_unit[tt]` rather than `psi`, plus a diagnostic report), not a documentation gap. **Honest posture:** "mixed-family CI coverage is a known engine deficiency (0.55–0.82 observed), not a near-complete feature."

**Not overclaims — register under-claims to fix in consolidation (Track A):**
- **FAM-09 (gamma, log):** register says "smoke only" but `test-family-gamma.R` performs recovery (trait-intercept + CV). Status is too conservative; candidate `partial → covered` after a tolerance-depth review.
- **FAM-14 (ordinal_probit):** register says "smoke only; full M2 work" but `test-ordinal-probit.R` recovers cutpoints + intercepts across K=2/3/4 and shows binomial-probit byte-identity at K=2. Status text is inaccurate; recovery exists. (Cross-package mirt `graded` check still missing, so it stays `partial` overall — but for the cross-package reason, not "smoke only".)

---

## 4. Two-track work-list

### Track A — Safe parallel work (agent-dispatchable today)

These items are documentation, register hygiene, a single cheap parser change, and cross-package test fixtures. They touch no engine math and have no shared mutable state beyond the register file (§A-reg, which should be serialized). Ordered by dependency: register truth and the capability matrix must settle before articles that cite them; the parser-guard lift and the new article depend on the slope-reality table being agreed.

| # | Item | What it delivers | Effort | Parallel-agent today? | Depends on |
|---|---|---|---|---|---|
| A1 | **Register consolidation** (FAM-09, FAM-14 status text; confirm ANI-06/PHY-06/RE-02/FG-15 all read "partial"; CI-08 "needs-update", CI-10 "partial") | Single source of truth for status; fixes two under-claims | S | **Yes** (one owner; serialize writes to register) | — |
| A2 | **Capability matrix freeze** (this doc §1–§2 ratified as the status reference) | Shared status table every article links to | S | **Yes** | A1 |
| A3 | **`api-keyword-grid.Rmd`** — confirm "partial" mapping for animal/phylo rows (audit: already current) | No-op verification; guards against drift | S | **Yes** (read-mostly) | A1 |
| A4 | **`choose-your-model.Rmd`** decision-tree rewrite: extend ladder past spatial to `animal_slope`/`phylo_slope`; add non-Gaussian-slope and CI-method (Wald vs profile vs bootstrap) guidance; cite PHY-06, ANI-06, CI-10 as partial | Honest complexity ladder | L | **Yes** | A1, A2 |
| A5 | **`animal-model.Rmd`** — showcase `animal_slope(x\|id)` usage *with explicit "recovery deferred (ANI-06)" caveat*; add phylo_unique/animal_unique non-Gaussian note | Documents keyword without overclaiming | M | **Yes** | A1, A2 |
| A6 | **`phylogenetic-gllvm.Rmd`** — add `phylo_slope` reaction-norm tutorial section (Gaussian, the one validated mode); add `unit_obs` + cluster trait-covariance decomposition | Fills the one slope path that is real | M | **Yes** | A1, A2 |
| A7 | **`joint-sdm.Rmd`** — add profile/Wald/bootstrap CI examples for ICC/correlations on the binary latent scale; flag mixed-family CI coverage as failing (CI-10), do **not** imply readiness | Binary-scale CI worked examples, honestly bounded | M | **Yes** | A1, A2 |
| A8 | **NEW `random-regression-reaction-norms.Rmd`** — anchor slope-family keywords; scope **to the validated case** (Gaussian `phylo_slope`), with `animal_slope` shown as parser-accepted/recovery-deferred and structured slopes marked not-yet-implemented | The advertised "how do I fit reaction norms?" entry point, scoped to reality | L | **Yes** (but must respect §2/§3 caveats) | A1, A2, A6 |
| A9 | **Poisson (FAM-06) cross-package glmmTMB fixture** | Closes the obvious cross-check gap; binomial/nbinom2/gaussian already have one | S | **Yes** (independent test file) | — |
| A10 | **nbinom2 (FAM-08) cross-package glmmTMB fixture** | Validates M3.3 production-grid family vs sister package | S–M | **Yes** (independent test file) | — |
| A11 | **`phylo_indep` parser-guard lift, IN ISOLATION** (extend `.is_zero_plus_trait` / add `.is_long_intercept_slope` at brms-sugar.R:2506; reuse `.gllvmTMB_lhs_form()` from phylo_unique :2407-2408) | The single cheap parser slice in the slope family | S | **Caution** — yes as a code task, but **must not ship user-facing** until B1 lands, or it accepts syntax the engine cannot fit | §2 ratified; gated behind B1 for release |

Notes for Track A dispatch:
- **A1 is the chokepoint.** Run it first and single-owner; all article work (A4–A8) reads the register it produces.
- **A9/A10 are fully independent** of everything else and can launch immediately in parallel.
- **A3** is verification-only (audit says `api-keyword-grid.Rmd` is already current).
- Articles already marked `done`/`current` in the audit (lambda-constraint, profile-likelihood-ci, behavioural-syndromes, covariance-correlation, morphometrics, functional-biogeography, stacked-trait-gllvm, psychometrics-irt, response-families, convergence-start-values, cross-package-validation, gllvm-vocabulary, pitfalls, data-shape-flowchart, troubleshooting-profile, simulation-recovery-validated, simulation-verification, roadmap, ordinal-probit) need **no change this cycle** and are out of scope for Track A.

### Track B — Engine / C++ work (maintainer or expert; **NOT mass-agent fan-out**)

Every item below requires new TMB parameter blocks, prior-likelihood derivation, linear-predictor restructuring, and a recovery/coverage study to validate. These are **not** decomposable into independent agent tasks: the slope keywords share the `b_phy_*` / `g_phy` / `theta_rr_spde_lv` data contracts and the eta-construction loops, so changes interact. **Do not attempt to deliver these by fan-out.** Sequencing reflects shared machinery (correlated phylo blocks before reduced-rank latent; phylo before spatial; spatial_dep last as the heaviest).

| # | Item | Why it is engine-C++ / not-agent | Effort | Gate to validate |
|---|---|---|---|---|
| B1 | **`phylo_indep` slope engine** — `b_phy_indep_slopes` block, MVN prior `Σ_b ⊗ A_phy_indep`, eta loop expansion (gllvmTMB.cpp:193/279/543/780) | New parameter struct + prior; pairs with A11 guard. Audit verdict: explicitly **not** parser-only doable | engine-C++ | RE-02-style Gaussian slope recovery, then non-Gaussian |
| B2 | **`phylo_dep` slope engine** — `b_phy_dep_slopes`, 2×2 intercept-slope Cholesky per species block, T×2 LHS matrix | Block-wise quadratic forms; shares `b_phy_*` contract with B1 | engine-C++ | slope-variance + cross-(intercept,slope) cor recovery |
| B3 | **`phylo_latent` slope engine** — 3D `g_phy_slope (n_aug × d_phy × n_lhs_cols)`, `Z_phy_aug` reindex (gllvmTMB.cpp:200/269/557-621) | Reduced-rank Λ_phy extended by a new dimension; depends on intercept latent path | engine-C++ | recovery on reduced-rank slope loadings |
| B4 | **`spatial_indep` slope engine** — `omega_spde_slope (n_mesh × n_traits × n_lhs_cols)`, per-trait eta sum (gllvmTMB.cpp:90-97/643-650/760-768) | SPDE per-trait field gains a slope dimension; new design-matrix contract | engine-C++ | SPA-style spatial slope recovery |
| B5 | **`spatial_latent` slope engine** — `theta_rr_spde_lv_slope (T × K_S × n_lhs_cols)`, Z slope indicators (gllvmTMB.cpp:260-265/764-768) | Reduced-rank spatial loadings extended; shares packing with B6 | engine-C++ | recovery on shared-field slope loadings |
| B6 | **`spatial_dep` slope engine** — `theta_rr_spde_lv` → T×T×n_lhs_cols full Cholesky, `omega_spde_lv_slope` (gllvmTMB.cpp:260-269/664-670) | Full-rank (d=T) block expansion; **heaviest** item | engine-C++ (L) | full-unstructured (intercept,slope) recovery |
| B7 | **`animal_slope(x\|id)` recovery study** (ANI-06) — activate the `skip_until_stage3()` skeletons with real DGPs | Not new engine code, but a **validation** study that gates promotion; expert-run, not fan-out | L | Gaussian slope recovery + per-id slope cor, then non-Gaussian |
| B8 | **nbinom1 recovery + cross-package** (FAM-07) — currently smoke-only; `test-nb2-recovery.R:115` notes "nbinom1 smoke only" | Family-specific recovery + glmmTMB cross-check; estimand/DGP care needed | M | recovery + glmmTMB agreement |
| B9 | **Gaussian coverage gate** (CI-08) — drive 13/15 failing cells to ≥94%; resolve 236/3000 fit failures | Engine + estimand work behind Design 50 surface-admission gate | engine-C++ | ≥94% across the cell grid + diagnostic report |
| B10 | **Mixed-family CI coverage** (CI-10) — target-explicit `Sigma_unit[tt]` not `psi`; lift d=1/2/3 from 0.55–0.82 | Estimand redefinition + engine; precedes any mixed-family CI article promotion | engine-C++ | ≥0.94 mixed-family coverage + diagnostic report |
| B11 | **Delta/hurdle latent-scale correlation formula** (FAM-17, MIX-10) | **Blocked** — two scales (occurrence + continuous); single latent-residual formula undefined. Needs mathematical derivation **before** any code | engine-C++ (blocked) | derivation first, then mixed-family delta/hurdle fits |
| B12 | **Cross-package empirical-agreement grids** (ANI-10 vs MCMCglmm/Hmsc; SPA-01..07 vs sdmTMB/gllvm; ordinal vs mirt `graded`; Phase 5.5 ~810-cell sweep) | Large empirical sweeps, expert-designed DGPs; explicitly Phase 5.5 / not M2 | engine-C++ / Phase 5.5 | per-grid agreement bands |

**Why Track B cannot fan out:** the six structured-slope items (B1–B6) all mutate the same three engine data contracts (`b_phy_*` for correlated phylo blocks, `g_phy`/`Z_phy_aug` for latent phylo, `theta_rr_spde_lv`/`omega_spde_lv` for spatial) and the shared linear-predictor loops. Parallel edits would collide in the `.cpp` and in the TMB parameter map. They must be sequenced by a maintainer (suggested order B1→B2→B3 then B4→B5→B6, with B11's derivation unblocking any delta-family extension). The validation items (B7–B12) are gated by Design 50 / Phase 5.5 evidence protocols and require expert DGP design, not template tests.

---

## 5. One-line bottom line

The intercept-level phylo/spatial/animal stack is broadly **covered** (often on the binary scale too); the random-**slope** stack is almost entirely aspirational — **one Gaussian mode (`phylo_slope`) is validated, `animal_slope` is parser-accepted but unproven, and all six structured slope modes need maintainer-led C++**; meanwhile the **CI coverage gates (Gaussian CI-08 and mixed-family CI-10) are failing** and must not be documented as done. Track A (docs, register hygiene, two cross-package fixtures, one isolated parser guard) is safe to parallelize today; Track B is not.
