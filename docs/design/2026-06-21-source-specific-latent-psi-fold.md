# Design: source-specific latent-Ψ fold (Stage A of the `latent_*`-only migration)

**Status:** design / maintainer checkpoint (grammar change — needs per-item merge approval).
**Author:** Claude (Ada). **Baseline:** `origin/main` 482d569.

## Goal

Make each `*_latent()` auto-carry its source-specific diagonal Ψ companion by default
(`residual = TRUE`), so the paired `*_latent + *_unique` collapses to a single
`*_latent()` — mirroring the ordinary `latent()` fold already shipped. This is the
prerequisite for `latent_*`-only and the eventual removal of `*_unique()`
(verification sweep finding: source-specific latents do **not** yet fold Ψ —
roxygen "latent-Psi folds remain future slices", R/brms-sugar.R:744,851).

## Current state (verified)

- **Ordinary `latent(residual=TRUE)`** → `rr(...) + diag(..., .auto_residual=TRUE)`
  (R/brms-sugar.R, `if (identical(fn,"latent"))` block ~2804-2852). Done + correct.
- **`*_latent`** (phylo/spatial/animal/kernel) → `phylo_rr`/`spde` with **no companion**.
  Still require explicit `*_unique()`. `*_unique` companions today:
  - `phylo_unique(0+trait|sp)` → `phylo_rr(sp, .phylo_unique=TRUE, [tree/vcv])` (R/brms-sugar.R:3052)
  - `animal_unique(id)` → `phylo_rr(id, .phylo_unique=TRUE, vcv=A)` (R/brms-sugar.R:2445)
  - `spatial_unique`/`kernel_unique` → analogous (spde / `phylo_rr(.kernel_*)`).
- **Dedup** (R/fit-multi.R:340-366) keys `is_auto_psi` on `kind=="diag" && .auto_residual`,
  and drops the auto-Ψ when an explicit `diag` sits at the same grouping (byte-identity).
  **It does NOT yet recognise source companions** (`kind=="phylo_rr"`/`spde`), so without an
  extension `phylo_latent(residual=TRUE) + phylo_unique()` would **double-count Ψ**.

## Mechanism (per source)

**1. Rewriter (R/brms-sugar.R).** Add `residual`/`common` args to each `*_latent()` (mirror
`latent()`'s arg handling + the bare-default fire-on-use notice). When `residual=TRUE`, emit the
rewritten `*_latent → *_rr/spde` **plus** the source `*_unique` companion carrying
`.auto_residual=TRUE`:

| source | `*_latent(residual=TRUE)` desugars to |
|---|---|
| phylo | `phylo_rr(sp, d=K, [tree/vcv]) + phylo_rr(sp, .phylo_unique=TRUE, .auto_residual=TRUE, [tree/vcv])` |
| animal | `phylo_rr(id, d=K, vcv=A) + phylo_rr(id, .phylo_unique=TRUE, .auto_residual=TRUE, vcv=A)` |
| spatial | `spde(coords, d=K) + spde(coords, .spatial_unique=TRUE, .auto_residual=TRUE)` (confirm spde-unique marker) |
| kernel | `phylo_rr(unit, d=q, .kernel_name, .kernel_mode, vcv) + phylo_rr(unit, .phylo_unique=TRUE, .auto_residual=TRUE, .kernel_name, .kernel_mode, vcv)` |

`residual=FALSE` → loadings-only (`*_rr`/`spde` alone, no companion). The companion reuses
`.pass_through_extras(e, c("tree","vcv"))` so the SAME phylo/spatial/kernel structure A is shared.

**2. Dedup extension (R/fit-multi.R).** Generalise `is_auto_psi` + the dedup so the source
auto-companions are recognised (e.g. `kind=="phylo_rr" && .phylo_unique && .auto_residual`;
`spde && .auto_residual`) and an explicit `*_unique()` at the same grouping supersedes the
auto-companion (drop the auto one) → **byte-identical** to the explicit paired spec.

**3. Per-family gate.** The existing `auto_residual_off_family` (ordinal/delta) gate + the binary
unit-level skip (#509) must extend to the source companions (a phylo/cluster fit with ordinal
traits drops the source auto-Ψ just as the plain-diag case does).

## Per-source slices (one PR each; **phylo → spatial → animal → kernel**)

Each slice = rewriter + dedup + per-family gate, with these **gates**:
- **G1 byte-identity:** `*_latent(residual=TRUE)` ≡ `*_latent(residual=FALSE) + *_unique()`
  (logLik + `extract_Sigma` Δ < 1e-6) across the wired families.
- **G2 per-family + per-level recovery:** known-DGP recovery of the source Σ = ΛΛᵀ + Ψ at
  `unit` / `cluster` (+ `cluster2` where applicable) for the wired families.
- **G3 `residual=FALSE`** returns the loadings-only submodel.
- **G4 deprecation:** an explicit `*_unique()` still fits + warns (compat preserved) until Stage E.

## Risks / open decisions (maintainer)

1. **Augmented `*_latent(1 + x | g)` slope variants** desugar through `phylo_slope` /
   `.latent_slope`, not the simple companion. **Proposal: slice 1 GUARDS the augmented case**
   (keep requiring explicit `*_unique()` for augmented slopes), and the augmented fold is a
   later follow-up. Confirm.
2. **Source ordering:** phylo first (most common + most valuable), then spatial, animal, kernel.
   Confirm.
3. **Dedup `kind` extension** must be careful — the source companions are different `kind`s than
   the ordinary `diag`. This is the main correctness hazard; G1 byte-identity is the guard.
4. This **changes the default meaning of `*_latent()`** (grammar change) → each slice is a per-item
   maintainer merge.

## Removal (Stage E — later)

Only after all four source folds + G1-G3 are green, flip `*_unique()` soft-deprecation to removal,
source-by-source, each gated by its byte-identity + recovery evidence.
