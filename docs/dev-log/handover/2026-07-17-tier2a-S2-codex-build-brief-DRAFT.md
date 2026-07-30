# Codex build brief — Tier-2a phylo-multinomial, slice S2 (live TMB) — DRAFT

**From:** Claude (Fable 5), 2026-07-17. **For:** Codex (owns the live TMB build + fits + compute).
**Status:** DRAFT — hand over once the fresh arc branch exists and S1 (grammar) has landed.
**Plan of record:** `docs/dev-log/2026-07-17-tier2a-ultra-plan-DRAFT.md`.
**Design:** `docs/design/84-phylogenetic-multinomial-tier2.md` (PR #752).
**Reference (must match):** `dev/phylo-multinomial-spike.R` (validated MCMCglmm recovery).
**Acceptance harness (ready):** `dev/phylo-multinomial-harness-DRAFT.R` (consistency ladder).

## Sequencing / ownership
- **S1 grammar wiring (Claude, pure-R):** admit `latent()`/`phylo_latent()` on a multinomial trait →
  K−1 category-contrast pseudo-traits with category-specific loadings λⱼ on shared factors zᵢ. Must land
  on the arc branch BEFORE S2. (Blocked today only by the classifier outage gating branch creation.)
- **S2a TMB core (Codex):** this brief.
- **S2b optimizer robustness (Codex):** starting values, convergence checks, Laplace-failure fallback,
  loud non-convergence (never silently return NA).
- **S3 reporting (Claude/Codex, pure-R):** `extract_Sigma()`/`extract_correlations()` return
  `V ≈ ΛΛᵀ + diag(ψ)` on the pinned scale + `print`/`summary`.
- **S4b campaign (Codex, Totoro):** run the harness ladder + references; the gate below.

## What S2a must implement (the math is fixed; map the template, then wire)
Model (Design 84 §2, §4): `eta_ij = X_i β_j + z_i' λ_j`, softmax with baseline category pinned at 0;
`z_i` a low-dim (fixed small `d`) phylogenetically-structured latent factor (phylo precision via the
EXISTING sparse `A⁻¹` engine); `λ_j` category-specific loadings. Reduced-rank
`V ≈ Λ Λᵀ + diag(ψ)` on the K−1 contrasts — i.e. `phylo_latent()`'s decomposition applied to the
category contrasts of one multinomial trait.

**Map first (you run the live toolchain — I could not grep during the outage):** locate in the TMB
template (`src/*.cpp`) (a) the softmax/multinomial (fid-16) likelihood, (b) where latent factors `z`
and loadings `Λ` enter the linear predictor for existing `phylo_latent`, (c) where the sparse `A⁻¹`
GMRF density is applied to the factors, and (d) the R-side assembler that passes `A⁻¹` + factor dims to
TMB. Confirm the softmax linear predictor can receive the `z_i' λ_j` contribution for the K−1 contrasts.

## LOAD-BEARING — identification (do NOT estimate this)
Fix the latent-scale residual **by convention** to **`R = (1/K)·(I + J)`** on the (K−1) contrasts
(`I` identity, `J` all-ones). This is exactly what the validated spike uses
(`dev/phylo-multinomial-spike.R:60-63`, `R = list(V = (1/K)*(I+J), fix = 1)`) and it is the MCMCglmm
categorical convention. It supersedes Design 84 §7's "identity vs 0.5/0.25" hedge. The reported `V`/ρ
must live on THIS scale so it matches the MCMCglmm reference (scale reconciliation: ultra-plan §S0(b)).
If the softmax likelihood in TMB has no explicit residual term, the equivalent is to hold the
category-contrast latent scale to `(1/K)(I+J)` rather than free it — confirm the parameterization.

## Acceptance gate (the consistency ladder is load-bearing)
Run `dev/phylo-multinomial-harness-DRAFT.R` (move it onto the arc branch first) on Totoro:
1. **Smoke:** `Rscript dev/phylo-multinomial-harness-DRAFT.R` (N=800, 1 seed) → non-NA, in-range ρ̂.
2. **Ladder:** `... 800,1600,3200 20 60000` → does ρ̂ climb toward 0.6 (under-power → OK, add a
   sample-size fence in docs) or plateau below (asymptotic bias → STOP, revisit S0 scale before any
   `covered` claim)? The harness prints the verdict.
3. **gllvmTMB match:** once S2a fits, compare its `extract_Sigma()` `V` to `V_true` AND to the MCMCglmm
   posterior on the SAME `(1/K)(I+J)` scale. brms `gr(cov=A)` is a scale-checked secondary only.

## Guards
- Standalone per-trait `V` first; **fence cross-trait** (a multinomial trait correlating with 1-dim
  traits — needs a K−1↔1-dim mixing convention). Julia parity is a later arc.
- Preserve backward-compat: no RE term on a multinomial trait ⇒ the shipped fixed-effects
  `multinomial()` behaviour is unchanged.
- Compute local→Totoro/DRAC, **never GitHub Actions (D-50)**. Reader surfaces carry no `fid-16`/`FAM-20`.
- New arc = Discussion Checkpoint: maintainer sign-off gates the grammar/likelihood change (given).
