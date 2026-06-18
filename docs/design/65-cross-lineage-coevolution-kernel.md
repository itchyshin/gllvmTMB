# Design 65 -- Cross-lineage co-evolution PG(eps)LLVM via a generic `kernel_*()` engine

**Status:** Active design contract + Codex implementation plan. gllvmTMB LEADS + implements;
drmTMB MIRRORS the shared `kernel_*()` API + `relmat -> kernel` deprecation on its own
schedule (NOT urgent).
**Scope:** a generic `kernel_*()` random-effect engine (a tier with an arbitrary
user-supplied between-unit covariance `K`) and its use to fit trait co-evolution between
two interacting lineages -- a stacked-trait PGLLVM with a cross-clade kernel `K*` whose
off-diagonal block carries the coevolution, yielding `Gamma = Lambda_H Lambda_P^T`.
**Parent designs:** Design 59 (missing-data shared contract / cross-repo ledger pattern),
Design 56 sec.5.3 (per-keyword Sigma variants), Design 35 (validation-debt register),
Design 00 (vision).
**Promoted from:** the approved implementation plan (brainstorm + writing-plans,
2026-05-31). This memo is the canonical in-repo contract; Codex executes from it. The
math below preserves the approved plan's notation (Greek + `(x)` Kronecker); see the
formula blocks for the ASCII gloss.

---

> **Handoff:** gllvmTMB **leads + implements** this; drmTMB **mirrors** the shared `kernel_*()` API + `relmat->kernel` deprecation on its own schedule (**not urgent**). Work TDD (test first), narrow-slice (one PR per task), `main` = single integration point. The engine lane (`fit-multi.R`/`brms-sugar.R`/`parse-multi-formula.R`/`src/gllvmTMB.cpp`) is **serialized** -- one engine PR in flight; rebase before the next. Do NOT widen tolerances silently; do NOT fake-pass; update the Design 35 register row + an after-task note per slice.

**Goal:** add a generic `kernel_*()` random-effect engine (a tier with an arbitrary user-supplied between-unit covariance `K`) and use it to fit **trait co-evolution between two interacting lineages** -- a stacked-trait PGLLVM with a cross-clade kernel `K*` whose off-diagonal block carries the coevolution, yielding `Gamma = Lambda_H Lambda_P^T` (host-trait x partner-trait coevolution).

**Architecture:** `kernel_*()` is the honest generic engine; `phylo/spatial/animal` are sugar that *build* `K`; `relmat` is near-redundant and gets soft-deprecated to `kernel`. The TMB contribution is already family-agnostic (`eta += G.Lambda^T` before family dispatch), so most of this reuses the existing augmented/latent path -- `kernel_*(K = A_phylo)` must reproduce `phylo_*()` byte-for-byte (the unification safety gate).

**Tech stack:** R (roxygen2, testthat 3e, lifecycle), TMB (`src/gllvmTMB.cpp`), `Matrix` (sparse Cholesky / GMRF). Reuses `phylo_latent`/`phylo_unique` machinery.

---

## The model (contract -- what the math must produce)

Stack hosts `H` (N_H species, T_H traits) and partners `P` (N_P, T_P) into one block-missing matrix; off-diagonal blocks are structural `NA` (existing per-cell response drop handles them):
```
Y* = [Y_H  NA ;  NA  Y_P]   (rows = all species, cols = all traits)
K* = [A_H  K_HP ; K_HP^T  A_P]   (between-species covariance; K_HP = cross-clade bridge)
```
Per kernel tier `r` (rank `d_r`): `G_r ~ N(0, K_r)`, loadings `Lambda_r` (T x d_r), per-trait uniqueness `psi_r`.
```
Var{vec(eta* - M*)} = (Lambda_phy Lambda_phy^T + Psi_phy) (x) K*_phy + (Lambda_non Lambda_non^T + Psi_non) (x) K*_non
Cov(eta_{H,ia}, eta_{P,jb}) = Gamma_ab . K_HP,ij ,   Gamma = Lambda_H Lambda_P^T   (host rows x partner cols of the loadings)
```
`K_HP^phy = rho . L_H . W~ . L_P^T` (`L_H L_H^T = A_H`; `W~` = association `W` spectrally scaled so the full `K*` is PSD). Within-lineage **null**: `K* = blockdiag(A_H, A_P)` (Gamma = 0; baseline).

---

## File structure (what changes; reuse over new)

| File | Responsibility | Reuse anchor |
|---|---|---|
| `R/brms-sugar.R` | new `kernel_latent/kernel_unique/kernel_indep/kernel_dep()` parser terms; `relmat` `deprecate_soft` | `phylo_latent`:509, `phylo_unique`:734 |
| `R/parse-multi-formula.R` | register the `kernel_*` markers (mirror the `phylo_rr`/`.phylo_*_augmented` kinds) | the phylo kind-tagging |
| `R/fit-multi.R` | kernel-tier data/parameter wiring (accept dense `K` or sparse precision; build `Ainv`/`L_K`; add scores to `random`) | `vcv`/`Ainv_phy_rr` prep ~:1048; `MakeADFun(random=)` ~:1926 |
| `src/gllvmTMB.cpp` | kernel-tier prior + eta (reuse family-agnostic augmented path; no new family code) | the augmented `eta +=` block |
| `R/extract-sigma.R` | `level = "<kernel name>"` dispatch (already designed, :476) + new `extract_Gamma()` | `extract_Sigma` `part=` :485 |
| `R/kernel-helpers.R` (new) | `make_cross_kernel(A_H, A_P, W, rho)` (+ PSD check) | -- |
| `tests/testthat/test-kernel-equivalence.R` (new) | `kernel_*(K=A) ≡ phylo_*(vcv=A)` byte-equivalence | -- |
| `tests/testthat/test-coevolution-recovery.R` (new) | recover known `Gamma` from `K*`-structured sim | -- |

---

## Phase C0 -- prototype now (zero new engine code; validate the biology)

**Files:** `R/kernel-helpers.R` (new, `make_cross_kernel` only), `tests/testthat/test-coevolution-prototype.R` (new), a worked example under `dev/`.

- [ ] **C0.1 -- failing test for `make_cross_kernel()`.** Test: for toy `A_H` (3x3), `A_P` (2x2), `W` (3x2), `K <- make_cross_kernel(A_H, A_P, W, rho=0.4)` returns a 5x5 matrix that is (a) symmetric, (b) PSD (`min(eigen(K)$values) > -1e-8`), (c) has the supplied `A_H`/`A_P` on the diagonal blocks, (d) `diag(K) == 1`. Assert these.
- [ ] **C0.2 -- implement `make_cross_kernel(A_H, A_P, W, rho=0.5, eps=1e-8)`** per the spec math: symmetric sqrt of each `A` (eigen, floor eigenvalues at `eps`), spectral scaling `W~ = W0 / max(svd(W0)$d[1], eps)`, `C_HP = rho.L_H.W~.L_P^T`, assemble, symmetrise, PSD-check (`stop()` if `min eig < -1e-6` with a `cli::cli_abort` telling the user to lower `rho`/rescale `W`), set `diag<-1`. ASCII-only.
- [ ] **C0.3 -- run C0.1; PASS. Commit** (`feat(kernel): make_cross_kernel helper`).
- [ ] **C0.4 -- prototype recovery test (the real win):** simulate a 2-lineage coevolution DGP (host + partner trees, a known `Gamma`, an association `W`), stack into `Y*` with block-`NA`, fit with the EXISTING `phylo_latent(species, d=2, vcv=K_cross) + phylo_unique(species, vcv=K_cross)`; assert (a) `conv==0` + PD Hessian, (b) the host x partner block of `extract_Sigma(level="phy", part="shared")$Sigma` correlates with the true `Gamma` (Procrustes/sign-tolerant) above a threshold. Gate behind `skip_if_not_heavy()`.
- [ ] **C0.5 -- partner-weighted regression vignette/example** (`dev/coevolution-prototype.R`): `Xbar_{P|H} = D_H^-1 W X_P`; fit partner-weighted partner traits as predictors of host traits (`trait:host_trait` slopes = entries of `Gamma_HP`), reciprocal `Xbar_{H|P}`. This is the immediately-usable empirical analysis. Commit.

**C0 stop:** no new engine/parser code beyond the helper. Confirms the science + that the stacked-`Y*` + dense-`vcv` path works end to end.

## Phase C1 -- `kernel_*()` engine, single dense `K` (THE new functionality, gated by equivalence)

**Files:** `R/brms-sugar.R`, `R/parse-multi-formula.R`, `R/fit-multi.R`, `src/gllvmTMB.cpp`, `R/extract-sigma.R`, `tests/testthat/test-kernel-equivalence.R`.

API (lock these signatures):
```r
kernel_latent(unit, K, d, name = "kernel")   # (Lambda Lambda^T) (x) K   ; Lambda is T x d
kernel_unique(unit, K, name = "kernel")       # diag(psi) (x) K
kernel_indep(unit, K, name = "kernel"); kernel_dep(unit, K, name = "kernel")  # parallel to phylo modes
```
- [ ] **C1.1 -- parser:** add the four `kernel_*()` functions in `R/brms-sugar.R` mirroring `phylo_latent`/`phylo_unique`, but taking a user matrix `K` (dense PSD or a sparse precision/`Ainv`) instead of `tree`/`vcv`; register markers in `R/parse-multi-formula.R` analogous to the phylo kinds, carrying `K` and `name`. Test: `parse_multi_formula(traits(y1,y2) ~ 1 + kernel_latent(g, K=K0, d=2, name="k"))` yields a kernel tier with `K`, `d=2`, `name="k"`. Run -> PASS. Commit.
- [ ] **C1.2 -- engine wiring (`fit-multi.R`):** for a kernel tier, build the same data the phylo path builds from a `vcv` (dense `K` -> its `Ainv`/Cholesky `L_K`; or pass a supplied sparse precision straight to `GMRF`); declare the tier's latent scores in the TMB `random` vector; pass `Lambda`/`log_psi` parameters. Reuse the `phylo_latent`/`phylo_unique` data+parameter construction verbatim where possible (it already accepts a user dense `vcv`).
- [ ] **C1.3 -- C++ (`src/gllvmTMB.cpp`):** add the kernel-tier contribution: `PARAMETER` standard-normal scores `z` (n_unit x d), `G = L_K z` (or reuse the `GMRF(Q)` prior on `z` for the sparse path), `eta += G.Lambda^T + psi.xi`; standard-normal prior on `z`. This is structurally identical to the augmented/phylo latent block -- prefer routing through the existing code with `K` supplied, adding NO new family branches.
- [ ] **C1.4 -- extractor:** `extract_Sigma(level = "<name>", part=...)` dispatches to the kernel tier (the `:476` mechanism is already designed for `level="<colname>"`). Returns `(Lambda Lambda^T + diag psi)` as usual.
- [ ] **C1.5 -- THE EQUIVALENCE GATE (test-kernel-equivalence.R):** fit a model with `phylo_latent(sp, d=2, vcv=A) + phylo_unique(sp, vcv=A)` and the same model with `kernel_latent(sp, K=A, d=2) + kernel_unique(sp, K=A)`; assert `abs(logLik difference) < 1e-6`, `extract_Sigma` matrices equal to `< 1e-6`, identical random-effect dims. If not equal, the kernel tier is not reproducing the phylo path -- fix before proceeding. Run -> PASS. Commit (`feat(kernel): generic kernel_*() engine, phylo-equivalent`).

**C1 stop:** single dense `K`; no cross-clade, no two-kernel, no unification yet.

## Phase C2 -- cross-clade co-evolution + `extract_Gamma()` (the actual goal)

**Files:** `R/extract-sigma.R` (`extract_Gamma`), `R/kernel-helpers.R`, `tests/testthat/test-coevolution-recovery.R`.

- [x] **C2.1 -- `extract_Gamma(fit, level, row_traits, col_traits)`:** slice the `row_traits x col_traits` block of `extract_Sigma(level, part="shared")$Sigma` (= `Lambda_row Lambda_col^T`). For coevolution: `row=host_traits, col=partner_traits` -> `Gamma`. Test on a fitted prototype: returns a `T_H x T_P` matrix with correct dimnames. Run -> PASS. Commit.
- [x] **C2.2 -- coevolution recovery test (the headline gate):** DGP with known `Gamma_true`, host/partner trees, association `W`; build `K* = make_cross_kernel(...)`; simulate `eta*` from `(Lambda Lambda^T)(x)K*`; fit `kernel_latent(species, K=K_star, d=2, name="phy") + kernel_unique(species, K=K_star, name="phy")` on the block-`NA` `Y*`; assert (a) conv==0 + PD, (b) `extract_Gamma(...)` recovers `Gamma_true` (Procrustes-aligned correlation > 0.9 or entrywise within band), (c) the **null** `K*=blockdiag(A_H,A_P)` gives `Gamma_hat ~ 0` and strictly worse logLik on `K*`-structured data (the cross-kernel is doing real work). Gate `skip_if_not_heavy()`. Run -> PASS. Commit (`feat(kernel): cross-clade coevolution + extract_Gamma`).
- [x] **C2.3 -- fixed-`rho` sensitivity + shape/effect extraction:** since
  `rho` lives inside `K_HP` (not estimated yet), document the sensitivity-grid
  pattern (`lapply(rho_grid, refit); which.max(logLik)`) and keep it in the
  example. The doc/example side is covered in
  `vignettes/articles/cross-lineage-coevolution.Rmd`. The extractor side now
  separates `Gamma_shape = Lambda_H %*% t(Lambda_P)` from the fixed-kernel
  effect scale: `make_cross_kernel()` records the supplied `rho` as metadata
  on `K_star`, fitted kernel tiers carry that value in `fit$kernel_levels`,
  and `extract_Gamma(scale = "effect")` returns
  `Gamma_effect = rho * Gamma_shape` for tiers built from
  `make_cross_kernel()`. Generic kernels without cross-kernel metadata fail
  loudly for `scale = "effect"` and should use the default
  `scale = "shape"`. This is not in-engine `rho` estimation, profiling, or
  interval evidence.
- [x] **C2.4 -- identifiability constraints + single-`W` sensitivity (literature-mandated; scout):** (a) ensure `Gamma` is uniquely identified, not rotation/reflection-ambiguous -- `Lambda_H` lower-triangular with positive diagonal (gllvmTMB's existing loadings constraint should provide this for the latent block; **verify it carries through to the cross-clade `Gamma` slice**, else add a constraint). (b) Add a sensitivity sim varying **association richness** (sparse vs dense `W`, number of realised host-partner links): show recovery degrades and uncertainty needs sensitivity assessment as `W` thins, because a single shared `W` is only one replicate of the coevolution signal (Boettiger et al. 2012). C2 engine tests verify the loading orientation and sparse-versus-dense single-`W` degradation; `?extract_Gamma` and `vignettes/articles/cross-lineage-coevolution.Rmd` carry the data-condition warning and internal workflow.

## Phase C3 -- two-kernel model (`K*_phy` + `K*_non`) + identifiability discipline

**Files:** `R/fit-multi.R`, `R/extract-sigma.R`,
`src/gllvmTMB.cpp`, `tests/testthat/test-coevolution-two-kernel.R`.

- [x] **C3.1 -- fit two kernel tiers** (`name="phy"` with `K*_phy`, `name="non"` with `K*_non = scale(W)` tip-level); confirm both tiers' `Sigma` + `Gamma` extract by `name`. **First fixed multi-kernel wave landed (2026-06-18):** two or more named dense `kernel_latent()` tiers now activate a generic TMB block with per-tier `K_r`, `Lambda_r`, and latent field. The one-name `kernel_*()` path remains on the C1 phylo-equivalent engine, preserving the `<1e-6` KER-02 equivalence gate. `test-coevolution-two-kernel.R` fits two named latent tiers and extracts component-specific shared `Sigma`, `Gamma_shape`, and, when the tier was built from `make_cross_kernel()`, fixed-`rho` `Gamma_effect = rho_r * Gamma_shape_r`. This Paper 2 path is deliberately latent-only in the first wave: explicit kernel-level Psi via `kernel_unique()` is deferred because it is a poor default for non-Gaussian and cross-family coevolution models, and the broader `*_unique()` surface should become compatibility/deprecation work after this arc. This is an engine and extractor gate, not scientific promotion: `COE-03` remains partial until component recovery, kernel-separation diagnostics, null/selective-absence tests, `rho` profiling/estimation, interval calibration, and Psi grammar decisions pass.
- [x] **C3.2 -- identifiability guardrail:** the two-Psi split (`Psi_phy` + `Psi_non`) is NOT separable from one obs/species/trait. Default to ONE uniqueness tier; require replication (repeated communities / species means+SE) before enabling both. **Done (2026-06-03):** `R/fit-multi.R` detects two `kernel_unique` tiers WITHOUT within-species replication, drops the extra uniqueness covstruct (defaulting to a single tier), and emits a `cli::cli_warn` (warn, not abort -- the model still fits). `test-coevolution-two-kernel.R`: the warning fires (non-replicated, two distinct names so the guardrail precedes the single-`name` validation); a single uniqueness tier does NOT warn; a heavy replicated DGP recovers a positive phylo uniqueness diagonal.
- [x] **C3.3 -- first COE-04 recovery/separation gates:** heavy Gaussian latent-only DGPs now cover the near-orthogonal two-component case, a conservative moderate-edge case, a high-overlap collapse-equivalence case, selective absence in both directions, a block-null smoke case, a small null/signal separation grid, fixed-`rho` sensitivity, and fixed-`rho` effect-scale extraction. The two-component fixture uses two named kernels with low off-diagonal Frobenius-style similarity, the fitted object stores the pairwise diagnostic in `fit$kernel_diagnostics`, fits `kernel_latent(..., name = "phy") + kernel_latent(..., name = "non")`, verifies that the full model beats either one-component model, and checks that component-specific `extract_Gamma()` estimates recover their own `Gamma_shape` truths while not matching the other component. For cross-kernel tiers with recorded `rho`, `extract_Gamma(scale = "effect")` returns `rho_r * Gamma_shape_r` for each component. The moderate-edge fixture blends the non association pattern 30% toward the phy pattern, lands in the moderate overlap class, and still recovers both component `Gamma_shape` matrices. The high-overlap fixture sets the two named kernels equal, verifies the separated two-tier fit is not materially better than one collapsed rank-2 kernel tier, and keeps component-specific `extract_Gamma()` warning while the collapsed extraction stays quiet and finite. The selective-absence fixture sets either component's loadings to zero; the two-kernel fit recovers the present `Gamma_shape`, collapses the absent component below `1e-3`, and does not materially improve over the present-only model. The block-null smoke fixture sets both loading blocks to zero and verifies both extracted component `Gamma_shape` norms collapse below `1e-3`; the small null/signal grid repeats that null collapse across three seeds and contrasts it with two medium-signal fixtures that recover both component `Gamma_shape` blocks and strongly beat one-component fits. A fixed-`rho` sensitivity grid rebuilds the phy component over `rho = c(0, 0.25, 0.55, 0.85)` while holding the non component fixed; positive-`rho` fits strongly beat `rho = 0`, but the best grid point can sit at the high edge, so this is sensitivity evidence only, not `rho` estimation. High-overlap fitted tier pairs now warn that component-specific `Gamma_shape` separation is weak evidence, and `extract_Gamma(level = ...)` repeats the warning when the requested component participates in a high-overlap pair. **Still partial:** broader moderate-overlap calibration, broader high-overlap recovery/failure calibration beyond the collapse and warning gates, broader null-threshold calibration, formal `rho` profile/estimation support, intervals, mixed/non-Gaussian gates, and the post-arc `*_unique()` lifecycle/deprecation plan remain future work.

## Phase C4 -- incremental unification + `relmat` soft-deprecation (cross-package contract)

**Files:** `R/brms-sugar.R`, `tests/testthat/test-*-slope-*.R` (existing, as gates), `NEWS.md`.

- [ ] **C4.1 -- re-point `phylo_*()` onto the kernel engine** (internally build `A` from `tree`/`vcv`, call the `kernel_*()` core). **Gate:** every existing `test-phylo-*` test passes UNCHANGED (byte-equivalence). If any regresses, revert that keyword's re-point. Commit per keyword.
- [ ] **C4.2 -- repeat for `spatial_*` then `animal_*`** (one keyword per PR, each gated by its existing tests). The sparse `Ainv`/`GMRF` path must be preserved for `animal`/`spatial`.
- [ ] **C4.3 -- soft-deprecate `relmat`:** `relmat(unit, A)` calls `lifecycle::deprecate_soft("x.y.z", "relmat()", "kernel_*()")` then delegates to `kernel_*(unit, K = A)`. Test: `relmat(...)` still fits + emits the deprecation warning (`expect_snapshot` / `lifecycle::expect_deprecated`). Update `NEWS.md`. Commit.
- [ ] **C4.4 -- docs:** document `phylo/spatial/animal` as sugar over `kernel_*()`; `_pkgdown.yml` reference grouping; an `?kernel` topic. (Coordinate pkgdown edits -- single shared file.)

## Phase C5 (LATER, separate spec) -- dyadic `phylo_kron()`

Interaction-strength-as-response model (`W_ij` as the response, both phylogenies in the covariance) -- the Rafferty & Ives / Hadfield lineage. Distinct from the one-matrix trait model; scope in its own design doc when C0-C4 land.

---

## Verification (per phase, before merge)

- **C0:** prototype recovers a planted host->partner association; `make_cross_kernel` PSD-checks.
- **C1:** the equivalence gate (`kernel ≡ phylo` to `<1e-6`) -- non-negotiable before C2.
- **C2:** known-`Gamma_shape` recovery (Procrustes corr > 0.9);
  fixed-`rho` `Gamma_effect = rho * Gamma_shape` extraction when
  `make_cross_kernel()` metadata is recorded; null-vs-cross logLik
  separation; PSD enforced.
- **C3:** fixed two-kernel fit + two-Psi guardrail; STOP if two uniqueness tiers are requested without replication. Near-orthogonal two-component recovery, conservative moderate-edge recovery, high-overlap collapse-equivalence, two-sided selective absence, block-null smoke plus a small null/signal grid, fixed-`rho` sensitivity, fixed-`rho` component `Gamma_effect` extraction, and high-overlap fit/extraction warning language have evidence, but scientific promotion still waits for the broader recovery/separation/null/interval grid (`COE-03` partial, `COE-04` partial).
- **C4:** each re-pointed keyword passes its existing suite UNCHANGED; `relmat` emits deprecation + still fits.
- Each slice: local `devtools::test(filter=...)`, `devtools::document()`, register row updated, after-task note. `R CMD check` clean before the engine PRs merge.

## Cross-package coordination

- **gllvmTMB leads + ships** (C0->C4 on the gllvmTMB engine lane). This memo is the gllvmTMB contract.
- **drmTMB mirrors the shared contract on its own schedule -- NOT urgent.** The shared-contract items are the **`kernel_*()` API** + the **`relmat -> kernel` soft-deprecation**; drmTMB adopts them when convenient so the sister APIs don't diverge. drmTMB has `relmat()`/`animal()` too -- do NOT let gllvmTMB ship a `relmat` deprecation that drmTMB hasn't agreed to in the ledger.
- **Ledger:** record the `kernel_*()` API signatures + the `relmat` deprecation decision on the cross-repo GitHub-Issues ledger (as with missing-data Design 59). Both teams sign off the API text there; gllvmTMB merges first.

## Evidence base (literature-grounded; scout-verified 2026-05-31)

**Novelty:** the one-matrix stacked-trait coevolution PGLLVM with an off-diagonal `K_HP` from an association matrix `W` and estimand `Gamma = Lambda_H Lambda_P^T` appears **novel** -- no published PGLLVM with bipartite stacked-`Y` + `Gamma` was found; HMSC (Ovaskainen 2017) is closest but does NOT enforce cross-clade latent coupling. Frame C2/C3 as a methods contribution (paper).

- **Process / coevolution:** Manceau, Lambert & Morlon (2017, *Syst Biol* 66:551) -- traits coevolving across interacting lineages; MVN tip limit; interaction matrix `P` ~ our `W`-derived `K_HP` (theoretical basis for the block kernel). Drury et al. (2016 *Syst Biol* 65:798; 2018 67:413) -- matching models; **classical methods fail to detect interaction effects -> the explicit `K_HP` structure is necessary**.
- **Dyadic (C5 ancestor):** Rafferty & Ives (2013, *Ecology* 94:2321) -- PLMM with both phylogenies as `Sigma_H (x) Sigma_P` (direct `K*` precedent). Adams & Nason (2018, *Evolution* 72:234); Hadfield & Nakagawa (2010, *JEB* 23:494, MCMCglmm).
- **Latent-factor phylo:** Tolkoff et al. (2018, *Syst Biol* 67:384, phylogenetic factor analysis -- the Lambda-on-tree precedent); Hassler et al. (2022, *MEE* 13:2181, selecting the factor count `d`); Goolsby Rphylopars (2017, *MEE* 8:740). **GLLVM/JSDM:** Warton et al. (2015, *TREE* 30:766); Niku et al. (2019, *MEE* 10:2173, the `gllvm` speed target); Ovaskainen et al. (2017, *Ecol Lett* 20:561, HMSC); Hui boral (2016, *MEE* 7:171).
- **Identifiability (load-bearing):** de Villemereuil et al. (2016, *Genetics* 204:1281) -- latent vs observation scale; **link-residual anchor required** (gllvmTMB's `link_residual_per_trait` already does this). Boettiger et al. (2012, *Evolution* 66:2240) -- phylo power needs tip replication; **a single shared `W` is only ONE replicate of the coevolution signal -> `Gamma` precision is limited**. Khabbazian et al. (2016, *MEE* 7:811) + bipartite-latent ambiguity -- **`Gamma` is identified only up to rotation/reflection without loading constraints (`Lambda_H` lower-triangular, `Lambda_P` positive-diagonal)**. Izenman (2008) -- `K*` PSD.

**Claims that need an EMPIRICAL recovery sim (not literature alone):** (i) `K_HP` recovers from `W` -- **not literature-backed -> the C2 power/bias sim is MANDATORY**; (ii) `Gamma` precision under a single `W` (sensitivity to association richness); (iii) recovery with vs without the loading constraints; (iv) the cross-phylo link-residual anchor. These gate the C2/C3 claims -- do NOT advertise coevolution recovery on literature alone. *(Scout flagged Nuismer & Harmon and a Weber & Agrawal dual-lineage paper as unverified.)*

## Handoff

Roadmap umbrella issue tracks C0-C5 as slices (label `roadmap` + `kernel`/`coevolution`); a cross-repo ledger entry carries the shared `kernel_*()`/`relmat` contract for drmTMB. Codex executes C0 first (zero-engine, validates the science), then the serialized engine lane C1->C4.
