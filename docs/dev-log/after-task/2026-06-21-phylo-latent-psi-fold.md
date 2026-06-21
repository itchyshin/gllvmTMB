# After-task — phylo_latent Ψ-fold (Stage A, slice 1 of the latent-only migration)

**Date:** 2026-06-21 · **Author:** Claude (Ada) · **Branch:**
`claude/phylo-fold-20260621` (PR # to follow) · **Scope:** engine + grammar — make
`phylo_latent()` auto-carry its diagonal Ψ companion by default, mirroring the ordinary
`latent()` fold. **Per-item maintainer merge required** (grammar change).

## Why this work exists

The approved `latent_*`-only migration plan (`docs/design/2026-06-21-source-specific-latent-psi-fold.md`,
PR #515) needs each `*_latent()` to carry its source-specific Ψ by default so the paired
`*_latent + *_unique` collapses to a single `*_latent(residual=TRUE)` — the prerequisite for
removing `*_unique()`. The deep verification confirmed only ordinary `latent()` folds today
(roxygen: "latent-Psi folds remain future slices"). This is **slice 1 — phylo** (the maintainer's
"phylo first, succeed, then the augmented case"). Spatial / animal / kernel are later slices.

## The change (R-only; no C++)

**Rewriter** (`R/brms-sugar.R`, the `phylo_latent` branch after the `latent` fold): add a `residual`
argument to `phylo_latent()`. When `residual = TRUE` (the new default), emit the rewritten
`phylo_rr(species, d=K)` **plus** the phylo-structured diagonal companion
`phylo_rr(species, .phylo_unique=TRUE, .auto_residual=TRUE, [tree/vcv])` — NOT a plain `diag`
(Σ_phy = Λ_phy Λ_phyᵀ ⊗ A + Ψ_phy ⊗ A). `residual = FALSE` returns the loadings-only `phylo_rr`.
The companion reuses `.pass_through_extras(e, c("tree","vcv"))` so the same phylo `A` is shared.
Augmented `phylo_latent(1 + x | sp)` is handled and **returned earlier** (the `.latent_slope`
block), so the fold only ever sees the intercept-only form — augmented stays explicit (slice 1b).

**Dedup** (`R/fit-multi.R`, beside the existing `diag` auto-Ψ dedup): `is_auto_phylo_psi` tracks the
phylo companion (a `phylo_rr`, not a `diag`); an explicit `phylo_unique()` at the same grouping
supersedes it (dropped), so `phylo_latent(residual=TRUE) + phylo_unique()` is byte-identical to the
explicit pair and avoids the downstream ">1 phylo_unique" abort. The per-family off-family gate
(pure ordinal/delta) is extended to drop the phylo companion too.

## Verification (TDD; mac-local, compiled worktree, `NOT_CRAN=true`, `GLLVMTMB_HEAVY_TESTS=1`)

New gate `tests/testthat/test-phylo-latent-residual-fold.R` — written RED first, watched fail
(`use$phylo_diag` FALSE, byte-identity off), then GREEN:
- **G1 byte-identity:** `phylo_latent(residual=TRUE)` ≡ `phylo_latent(residual=FALSE) + phylo_unique()`
  (`logLik` + `extract_Sigma(level="phy", part="total")` to < 1e-6).
- **G3 `residual=FALSE`** = loadings-only (no phylo diagonal).
- **Dedup:** `phylo_latent(residual=TRUE) + phylo_unique()` byte-identical to the explicit pair (no double-Ψ).

| suite | result |
|---|---|
| **fold tests** (above) | 3/3 ✓ |
| **critical cascade** — stage35 (bare phylo_latent now folds), q-decomposition (lone phylo_unique legacy), mode-dispatch, phylo_indep/dep mutual-exclusion | 19/19 ✓ (0 fail) |
| **heavy recovery** (CI does NOT run these) — matrix-poisson/gamma/ordinal-phylo (paired recovery), phylo-latent-slope + phylo-unique-slope (augmented, guarded), extract-omega (H²+C²+ψ²=1) | 27/27 ✓ (0 fail) |

The dedup keeps every paired-recovery test byte-identical; the augmented slope tests are untouched;
`extract_phylo_signal` and the lone-`phylo_unique` legacy path are unchanged.

## Definition-of-Done / scope notes

- **Engine + grammar change → per-item maintainer merge** (not self-merged).
- **Behaviour change (flag for the maintainer):** bare `phylo_latent(species, d=K)` (no explicit
  `residual=`) now auto-folds Ψ_phy, exactly as bare `latent()` does. The ordinary `latent()` fold
  ships a one-shot fire-on-use notice (`.gllvmTMB_warn_latent_default_psi()`); **this slice does NOT
  yet add a phylo equivalent** — deferred so the maintainer can decide the wording/UX. The existing
  bare-`phylo_latent` tests pass with the fold (no warning needed for correctness).
- Per-family recovery for the fold is covered transitively: the fold is byte-identical to the paired
  form, and the paired form's per-family recovery (PHY-04/05, matrix-*-phylo) stays green.
- **Next:** slice 1b (augmented `phylo_latent(1+x|sp)` fold) per the maintainer's sequence, then
  spatial / animal / kernel slices.

## Open notes

1. Fire-on-use notice for the bare-`phylo_latent` default change (above) — maintainer decision.
2. The full ~30-file phylo suite + the cross-OS CI is the maintainer's pre-merge gate; the heavy
   recovery subset run here is the part CI omits.
