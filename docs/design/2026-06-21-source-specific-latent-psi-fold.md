# Design: source-specific latent-Ψ fold (Stage A of the `latent_*`-only migration)

**Status:** design / maintainer checkpoint (grammar change — needs per-item merge approval).
**Author:** Claude (Ada). **Baseline:** `origin/main` 482d569.
**Progress note 2026-06-21:** the implemented spelling is `unique =` /
`.auto_unique`, not the earlier draft's `residual =` / `.auto_residual`.
`phylo_latent()` and `animal_latent()` have landed; `kernel_latent()` is this
follow-up slice; `spatial_latent()` remains blocked on the missing SPDE
diagonal engine slot.

**Superseding note 2026-07-03:** the default-fold part of this design was
revised. Ordinary `latent()` still carries diagonal Psi by default, but
source-specific and kernel latent terms are loadings-only by default. Use
`phylo_latent(..., unique = TRUE)`, `animal_latent(..., unique = TRUE)`,
`spatial_latent(..., unique = TRUE)`, or
`kernel_latent(..., unique = TRUE)` for
`Lambda Lambda^T + Psi_source`; keep
`*_latent(..., unique = FALSE) + *_unique()` as compatibility syntax.

## Historical Goal Superseded 2026-07-03

This note originally proposed making each `*_latent()` auto-carry its
source-specific diagonal Ψ companion by default. That default change was
superseded on 2026-07-03. The current contract is explicit:
`*_latent(..., unique = TRUE)` gives
`Lambda Lambda^T + Psi_source`, while bare `*_latent()` remains
loadings-only. The compatibility spelling
`*_latent(..., unique = FALSE) + *_unique()` stays live until a later
lifecycle PR retires `*_unique()`.

## Current state (verified)

- **Ordinary `latent(unique=TRUE)`** → `rr(...) + diag(..., .auto_unique=TRUE)`
  (R/brms-sugar.R, `if (identical(fn,"latent"))` block ~2804-2852). Done + correct.
- **Source-specific `*_unique` companions** route through `phylo_rr`/`spde`;
  fold slices reuse those same engine slots. The companion routes are:
  - `phylo_unique(0+trait|sp)` → `phylo_rr(sp, .phylo_unique=TRUE, [tree/vcv])` (R/brms-sugar.R:3052)
  - `animal_unique(id)` → `phylo_rr(id, .phylo_unique=TRUE, vcv=A)` (R/brms-sugar.R:2445)
  - `spatial_unique`/`kernel_unique` → analogous (spde / `phylo_rr(.kernel_*)`).
  After the kernel slice, only `spatial_latent()` remains pending because its
  SPDE diagonal companion slot still needs engine confirmation.
- **Dedup** (R/fit-multi.R:340-366) keys `is_auto_psi` on `kind=="diag" && .auto_unique`,
  and drops the auto-Ψ when an explicit `diag` sits at the same grouping (byte-identity).
  **It does NOT yet recognise source companions** (`kind=="phylo_rr"`/`spde`), so without an
  extension `phylo_latent(unique=TRUE) + phylo_unique()` would **double-count Ψ**.

## Mechanism (per source)

**1. Rewriter (R/brms-sugar.R).** Add `unique` args to each `*_latent()` (mirror
`latent()`'s arg handling where relevant). When `unique=TRUE`, emit the
rewritten `*_latent → *_rr/spde` **plus** the source `*_unique` companion carrying
`.auto_unique=TRUE`:

| source | `*_latent(unique=TRUE)` desugars to |
|---|---|
| phylo | `phylo_rr(sp, d=K, [tree/vcv]) + phylo_rr(sp, .phylo_unique=TRUE, .auto_unique=TRUE, [tree/vcv])` |
| animal | `phylo_rr(id, d=K, vcv=A) + phylo_rr(id, .phylo_unique=TRUE, .auto_unique=TRUE, vcv=A)` |
| spatial | `spde(coords, d=K) + spde(coords, .spatial_unique=TRUE, .auto_unique=TRUE)` (confirm spde-unique marker / engine slot first) |
| kernel | `phylo_rr(unit, d=q, .kernel_name, .kernel_mode, vcv) + phylo_rr(unit, .phylo_unique=TRUE, .auto_unique=TRUE, .kernel_name, .kernel_mode, vcv)` |

`unique=FALSE` → loadings-only (`*_rr`/`spde` alone, no companion). The companion reuses
`.pass_through_extras(e, c("tree","vcv"))` so the SAME phylo/spatial/kernel structure A is shared.

**2. Dedup extension (R/fit-multi.R).** Generalise `is_auto_psi` + the dedup so the source
auto-companions are recognised (e.g. `kind=="phylo_rr" && .phylo_unique && .auto_unique`;
`spde && .auto_unique`) and an explicit `*_unique()` at the same grouping supersedes the
auto-companion (drop the auto one) → **byte-identical** to the explicit paired spec.

**3. Per-family gate.** The existing `auto_unique_off_family` (ordinal/delta) gate + the binary
unit-level skip (#509) must extend to the source companions (a phylo/cluster fit with ordinal
traits drops the source auto-Ψ just as the plain-diag case does).

## Per-source slices (one PR each; **phylo → spatial → animal → kernel**)

Each slice = rewriter + dedup + per-family gate, with these **gates**:
- **G1 byte-identity:** `*_latent(unique=TRUE)` ≡ `*_latent(unique=FALSE) + *_unique()`
  (logLik + `extract_Sigma` Δ < 1e-6) across the wired families.
- **G2 per-family + per-level recovery:** known-DGP recovery of the source Σ = ΛΛᵀ + Ψ at
  `unit` / `cluster` (+ `cluster2` where applicable) for the wired families.
- **G3 `unique=FALSE`** returns the loadings-only submodel.
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

Only after all source folds + G1-G3 are green, flip `*_unique()` soft-deprecation to removal,
source-by-source, each gated by its byte-identity + recovery evidence.

## Phylo slice — implementation-grade detail (from the deep phylo research)

The phylo feature is heavily developed (validation-debt **PHY-01..18**; ~30 test files; sparse
`A⁻¹` Hadfield-Nakagawa engine; augmented slopes; `animal_*`/`kernel_*` parallels). The fold must
preserve all of it. Verified specifics:

**Companion form + routing.** `phylo_unique` paired with `phylo_latent` routes to the engine's
`phylo_diag` slot (`use_phylo_diag=1`, parameter `log_sd_phy_diag`, sharing `Ainv_phy_rr` /
`g_phy_diag`), giving `Σ_phy = Λ_phy Λ_phyᵀ ⊗ A + Ψ_phy ⊗ A`. So the fold emits, when
`phylo_latent(species, d=K, unique=TRUE)`:
`phylo_rr(species, d=K, [tree/vcv]) + phylo_rr(species, .phylo_unique=TRUE, .auto_unique=TRUE, [tree/vcv])`.
The companion reuses `.pass_through_extras(e, c("tree","vcv"))` (+ A/Ainv) so the SAME phylo `A` is
shared. `unique=FALSE` → `phylo_rr(d=K)` alone. Add `unique` to
`phylo_latent` mirroring `latent()`'s relevant arg handling (R/brms-sugar.R ~2804-2852).

**Dedup extension (R/fit-multi.R ~340-366 + ~804-960).** `is_auto_psi` currently keys on
`kind=="diag" && .auto_unique`. Extend it to recognize the phylo auto-companion
(`kind=="phylo_rr" && .phylo_unique && .auto_unique`) and drop it when an explicit `phylo_unique`
sits at the same grouping → byte-identity with the explicit pair. The lone-`phylo_unique` legacy
gate (`is_phylo_unique`, ~951: d=T, diagonal Lambda constraint) must be left UNCHANGED.

**Guards.** (a) Augmented `phylo_latent(1+x|sp)` carries `.latent_slope` (separate engine block) —
the fold must EXCLUDE it (keep explicit `phylo_unique` for augmented in slice 1). (b) Mutual
exclusion: if `phylo_indep`/`phylo_dep` is present on the same grouping, do NOT fold. (c) Per-family
gate: the existing `auto_unique_off_family` (ordinal/delta) + binary-#509 skips apply to the phylo
companion too.

**Invariants the fold must keep byte-identical (the safety net):**
`extract_Sigma(level="phy", part="total"/"shared"/"unique")`; `extract_phylo_signal` (`H²+C²_non+ψ²=1`);
the two-Ψ cross-checks (`compare_dep_vs_two_psi`, `compare_indep_vs_two_psi`); all wide/long
byte-identity gates; the lone-`phylo_unique` three-piece path; and PHY-01..18.

**New tests (TDD):** `test-phylo-latent-unique-fold.R` — G1 byte-identity
(`phylo_latent(unique=TRUE)` ≡ `phylo_latent(unique=FALSE) + phylo_unique()`): `logLik`,
`extract_Sigma(level="phy", part=*)`, `extract_phylo_signal` identical (< 1e-6) across the wired
families; G2 per-family recovery of `Σ_phy`; G3 `unique=FALSE` = loadings-only; plus a guard test
that explicit-pair and augmented stay unchanged.
