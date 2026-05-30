# 63 — C++ random-slope campaign (sequenced engine work)

**Status date:** 2026-05-30
**Scope:** Planning + landing record for the structured random-slope
(`0 + trait + (0 + trait):x | group`, a.k.a. random-regression /
reaction-norm) keywords that require **new C++ likelihood blocks** in
`src/gllvmTMB.cpp`. Companion to Design 55 (covstruct grammar), Design 56
(augmented-LHS engine, Stage 3), and Design 61 (capability status).

This document tracks the *sequenced* delivery of the phylo/spatial slope
modes. The central planning finding (Design 61 §2) stands: **none of the
structured slope modes can be delivered by parser-guard lifts alone** — each
needs a new parameter block + prior + `eta` loop in the engine. They are
therefore landed one engine-slice at a time, not by agent fan-out.

---

## 1. Why a campaign (not a fan-out)

Design 61 §2 reconciled the engine audit (what the code can fit) against the
register audit (what has test evidence) and found every richer-LHS slope
keyword in the phylo/spatial family at `not-implemented` at the engine level.
Lifting a parser guard in isolation would accept syntax the engine cannot
fit — a silent-collapse hazard the Design 56 §7 fail-loud boundary exists to
prevent. So the work is sequenced: derive + implement + validate the engine
core for one mode, then wire its public R surface, then move to the next.

The dependency order below is driven by how much new derivation each mode
needs, cheapest first.

## 2. Sequenced work-list

| # | Mode | Engine core | Status |
|---|---|---|---|
| 1 | `phylo_dep(1 + x \| sp)` | full unstructured `2T × 2T` `Σ_b = L Lᵀ` over trait-stacked `(intercept, slope)` columns, prior `vec(B) ~ N(0, Σ_b ⊗ A_phy)`; Kronecker quadratic-form trick | **DONE (this slice)** — engine validated 1.46e-11; public surface wired (Gaussian only). |
| 2 | `phylo_latent(1 + x \| sp, d = K)` | 3D loadings `g_phy_slope (n_aug × d_phy × n_lhs_cols)` + factor-analytic `Σ_b` per LHS column; identifiability via the `rr()` convention | **NEEDS DERIVATION** — the per-LHS-column factor structure and its rotation/identification constraints are not yet worked out. |
| 3 | `spatial_latent(1 + x \| coords, d = K_S)` + `spatial_dep` | SPDE precision composed with the slope covariance: `theta_rr_spde_lv_slope (T × K_S × n_lhs_cols)` (latent) / full-rank Cholesky (`dep`); must verify the GMRF precision composes with `Σ_b` without double-counting `τ` | **NEEDS DERIVATION** — SPDE × slope-covariance composition unproven; `spatial_dep` is the heaviest (full `T × T × n_lhs_cols` Cholesky). |
| 4 | `spatial_indep` / `phylo_indep` slope (diagonal `Σ_b`) | the diagonal special-cases of #2/#3 (`ρ`-pinned); cheap *once* the latent cores above exist | Gated behind #2/#3. (`phylo_indep` slope already has a Gaussian-only parser+map path via the augmented `b_phy_aug` engine and the `.indep` marker; the *full* latent/dep cores are the remaining work.) |

`animal_*` slope modes inherit the phylo engine automatically (Design 14 §5
sparse-A byte-equivalence); they are mostly tests once the phylo cores land.
Non-Gaussian extension of every slope mode is a separate axis, deferred until
the Gaussian core of each mode is validated.

## 3. Landed slice — `phylo_dep` slope (2026-05-30)

### 3.1 Engine core (pre-existing on this branch; NOT modified by this slice)

`src/gllvmTMB.cpp:591-653`, nested under `use_phylo_slope_correlated == 1`
and gated by `DATA_INTEGER(use_phylo_dep_slope)`:

- `n_lhs_cols = C = 2T` (lifts the closed-form `{1, 2}` cap; Design 56 §3.1
  / §5.2 exemption).
- `PARAMETER_VECTOR(theta_dep_chol)` (length `C(C+1)/2`) packs a free
  lower-triangular Cholesky factor `L`: the first `C` entries are the
  log-diagonal (`exp`-transformed for positivity / identifiability), then the
  strictly-lower entries column-major. `Σ_b = L Lᵀ` is SPD by construction
  (Pinheiro & Bates 1996, the standard unstructured-covariance
  parameterisation).
- Prior `−log p(vec(B)) = ½[ n C log 2π + n logdet Σ_b + C logdet A
  + tr(Σ_b⁻¹ Bᵀ A⁻¹ B) ]` via the Kronecker trick (cost linear in `n_sp`).
- REPORTs `Sigma_b_dep` (`C × C`), `sd_b` (length `C`), `cor_b_mat`
  (`C × C`) for extractors / tests.

Validation: the analytic matrix-normal density check
(`docs/dev-log/spikes/2026-05-30-phylo-dep-slope-density-check.R`) matches the
TMB nll to **1.46e-11**; the recovery harness
(`docs/dev-log/spikes/2026-05-30-phylo-dep-slope-recovery-harness.R`) recovers
the known `Σ_b` (consistent-not-unbiased at fixed `n`).

### 3.2 Public R surface (this slice)

The **interleaved** column ordering `(α_{t0}, β_{t0}, α_{t1}, β_{t1}, …)` —
intercept then slope, per trait — is the load-bearing contract; Z, the
extractor dimnames, and every test follow it.

- **Parser** (`R/brms-sugar.R`, the `fn == "phylo_dep"` handler):
  classifies the bar LHS via `.gllvmTMB_lhs_form()`. `intercept_only`
  (`0 + trait | sp`) keeps the unchanged `phylo_rr(..., .dep = TRUE)` RR
  route; `wide_intercept_slope` / `long_intercept_slope` rewrite to
  `phylo_slope(bar, .phylo_dep_augmented = TRUE, lhs_form = …,
  slope_col = …)`; richer forms abort fail-loud.
- **Engine wiring** (`R/fit-multi.R`):
  `use_phylo_dep_slope <- isTRUE(extra$.phylo_dep_augmented)` forces
  `use_phylo_slope_correlated` on (the dep C++ branch is nested under it);
  `n_lhs_cols = 2T`; the interleaved `Z_phy_aug` activates each row's own
  trait `(intercept, slope)` pair; `theta_dep_chol` initialised with
  `log(0.5)` on the diagonal and left **free**, while `log_sd_b` and
  `atanh_cor_b` are **NA-mapped** (the unstructured `Σ_b` replaces them);
  a distinct `use$phylo_dep_slope` flag (NOT the intercept-only
  `use$phylo_dep` RR flag); and a Gaussian-only fail-loud guard
  (non-Gaussian dep slope deferred).
- **Extractor C2** (`R/extract-sigma.R`): `extract_Sigma()` keys on
  `fit$use$phylo_dep_slope` and returns the `2T × 2T` `Sigma_b_dep` with
  interleaved dimnames (`intercept.<t>`, `slope.<t>`, …), `level = "phy_dep"`,
  `part = "dep"`; the `level` / `part` / `link_residual` arguments do not
  apply to this single unstructured block.

### 3.3 Tests (`tests/testthat/test-phylo-dep-slope-gaussian.R`)

Wide↔long byte-identity (identical `Z_phy_aug`, `logLik` to 1e-6,
`Sigma_b_dep` to 1e-8); interleaved-Z structure; Gaussian recovery
(`n_sp = 80`, documented consistent-not-unbiased bands: diagonal variance
ratio ∈ [½, 2] with intercept variances tighter, off-diagonals abs < 0.25);
density smoke (TMB nll == analytic matrix-normal density < 1e-9); negative
tests (closed-form-cap re-engagement + dimension-mismatch both abort
fail-loud); and the C2 extractor (finite `2T × 2T`, interleaved dimnames).
`tests/testthat/test-phase56-1-phylo-augmented-stub.R` additionally asserts
`theta_dep_chol` length-0 and `use_phylo_dep_slope = 0` on the dormant path.

### 3.4 Scope boundary

Gaussian only. Non-Gaussian dep slope aborts fail-loud at fit time
(family unknown at parse time). The non-Gaussian matrix sibling
`tests/testthat/test-matrix-slope-phylo-dep.R` therefore continues to
honest-skip (register rows stay `partial`) — no fake-pass.

## 4. Cross-references

- Design 55 — covstruct grammar (`dep` keyword, §5/§7.3).
- Design 56 — augmented-LHS engine Stage 3 (§3.1 / §5.2 dep exemption;
  §9.5c landing; §7 fail-loud boundary).
- Design 61 — capability status (§1b / §2 slope reality tables).
- Spikes: `docs/dev-log/spikes/2026-05-30-phylo-dep-slope-recovery-harness.R`,
  `docs/dev-log/spikes/2026-05-30-phylo-dep-slope-density-check.R`.
