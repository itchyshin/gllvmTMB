# Design 77 — Augmented `*_latent(unique = TRUE)` fold consistency

**Status:** 2026-07-07 — **COMPLETE for every source.** `phylo`/`animal` fold via the
`phylo_slope` companion; `kernel`/ordinary `latent` already folded; **`spatial` now folds
too** — parser-only, both SPDE slope engines co-active, identifiable, byte-identical to the
explicit pair (see the RESOLVED section below). 10/10 augmented cells. The footgun fix
(fail-loud) was the interim that restored the design's intended guard.
**Owner:** Claude (finding + phylo/animal wiring), Codex (heavy fold-fit verification; spatial C++).
**Relates to:** Design 56 (augmented-LHS engine) §5.3; the `*_unique` deprecation
(the augmented migration target depends on this fold being wired).

## Why this exists

The `*_unique` deprecation (maintainer, 2026-07-07) retires `phylo_unique`. The
intended augmented-slope migration is
`phylo_unique(1 + x | sp)` → `phylo_latent(1 + x | sp, unique = TRUE)`. A parser
probe found that this migration target **does not fold** — and, worse, that the
five `*_latent` keywords are **inconsistent** at the augmented `(1 + x | grp)`
form. All five honour `unique =` correctly at the intercept-only ordination form;
the divergence is entirely in the augmented random-regression branch.

### Verified behaviour matrix (`rewrite_canonical_aliases`, 2026-07-07)

| `*_latent` keyword | ordination `unique = TRUE` | augmented `unique = TRUE` |
|---|---|---|
| `latent` (ordinary) | folds (`.auto_unique`) | **wired** — `.latent_augmented_unique` engine marker |
| `kernel_latent` | folds (+companion) | **wired** — desugars to latent + augmented unique companion |
| `spatial_latent` | folds (`.spatial_unique_diag`) | **fails loud** — "not implemented … yet" (honest) |
| `phylo_latent` | folds (+companion) | **silently dropped** ❌ (was) |
| `animal_latent` | folds (+companion) | **silently dropped** ❌ (was) |

The augmented `phylo_latent`/`animal_latent` branches return the loadings-only
`.latent_slope` `phylo_rr` call *before* reading `unique`, so `unique = TRUE`
was consumed with no effect and no warning — the Sokal silent-drop anti-pattern
the surrounding comments already warn about for the slope column.

## Footgun fix (landed 2026-07-07)

`phylo_latent`/`animal_latent` augmented `unique = TRUE` now **fail loud**,
mirroring the existing `spatial_latent` guard (`R/brms-sugar.R`), pointing users
to the intercept-only fold or the explicit augmented pair
(`phylo_latent(1 + x | sp) + phylo_unique(1 + x | sp)`) as the interim companion
route. `unique = FALSE`/absent stay loadings-only; the ordination fold is
untouched. Parser-level regression tests added to
`tests/testthat/test-phylo-latent-unique-fold.R` and
`test-animal-latent-unique-fold.R`. No existing test used the silent-accept path.

## Wiring slice (queued — the honest migration prerequisite)

To make the maintainer's migration real, wire the augmented fold for
`phylo_latent`/`animal_latent` so that

```
phylo_latent(1 + x | sp, unique = TRUE)  ≡  phylo_latent(1 + x | sp) + phylo_unique(1 + x | sp)
```

exactly (logLik + `extract_Sigma` byte-identity), then replace the fail-loud
guard with the fold and add the duplicate-`+ *_unique()` guard the ordination
form already has.

**Two in-repo precedents to copy** (no new C++ expected — both engines already
run the two terms separately):
- `kernel_latent` augmented (`R/kernel-keywords.R` / brms-sugar): desugars
  `unique = TRUE` to `latent + augmented unique companion`.
- ordinary `latent` augmented: carries `.latent_augmented_unique = TRUE` through
  to the engine.

**Verification (Codex, heavy):** augmented byte-identity fits for `phylo_latent`
and `animal_latent` mirroring the ordination-form gate in
`test-phylo-latent-unique-fold.R` (Gaussian; then the non-Gaussian slope
families already covered for `phylo_unique`). Gate `GLLVMTMB_HEAVY_TESTS=1`.

## Deprecation implication

Until the wiring slice lands, the augmented `phylo_unique(1 + x | sp)` /
`animal_unique(1 + x | id)` spellings **stay live** as the supported companion —
they must **not** be advertised as migrating to `*_latent(unique = TRUE)` yet.
The bare-diagonal (`*_unique(grp)` → `*_indep(grp)`) and ordination-fold cases
are clean and proceed now. See the `*_unique` deprecation after-task report.

## Next arc — `spatial_latent(..., unique = TRUE)` C++ fold (starting kit; do NOT start from scratch)

Per the source-specific fold design
(`docs/design/2026-06-21-source-specific-latent-psi-fold.md`, ordering
**phylo → spatial → animal → kernel**), spatial is the one source whose
`unique = TRUE` fold needs **engine (C++)** work, not just a parser desugar — the
SPDE path *switches representations* rather than composing an additive companion
(`docs/dev-log/after-task/2026-06-21-spatial-latent-psi-fold-blocker.md`).

**Existing scaffolding already on `main` — build on this, do not rewrite:**

- **Dormant SPDE augmented base term** — `fba7e691` (2026-05-30, on main):
  `vec(Omega) ~ N(0, Sigma_field ⊗ Q^-1)` prior in `src/gllvmTMB.cpp`, gated by
  `use_spde_slope <- FALSE` in `R/fit-multi.R`; a 404-line
  `tests/testthat/test-spde-slope-base-engine.R` already exists. Parser not
  activated yet.
### RESOLVED 2026-07-07 — the ordination spatial fold is DONE; the 2026-06-21 blocker is stale

The verify-first sweep found the additive slot is **wired end-to-end**, and the
**ordination** spatial fold already fits:

- **C++** — `src/gllvmTMB.cpp` `DATA_INTEGER(spde_lv_unique)` (L170) with **five live
  usage sites** in the likelihood (L1416, L1426, L1466, L1750, L1851) that keep the
  per-trait `omega_spde` block when `spde_lv_unique == 1` (the additive
  `Lambda Lambda^T + Psi`).
- **R** — `R/fit-multi.R:1304` sets `use_spde_latent_diag` from the
  `.spatial_unique_diag` marker, and L3183 passes `spde_lv_unique = as.integer(...)`.
- **Test** — `tests/testthat/test-spatial-latent-unique-fold.R` **fits, converges**
  (`convergence == 0`), asserts `diag(Sigma_shared) + Psi_spde_unique == diag(Sigma_total)`,
  and `fold logLik == explicit-pair logLik` (byte-identity). Passes clean (TMB installed,
  not skipped).

So `spatial_latent(0 + trait | coords, d = K, unique = TRUE)` is **done and on main**.
The 2026-06-21 blocker ("additive sum not wired") predates the `spde_lv_unique` work.

### RESOLVED 2026-07-07 (evening) — the augmented spatial fold is PARSER-ONLY, not C++

An identifiability recovery study corrected the earlier "genuine engine work" read (which
was drawn *before* running the study — a lesson in itself). The augmented fold is
`spatial_latent(1+x|coords, unique=TRUE)` =
`spatial_latent(1+x|coords) + spatial_unique(1+x|coords)` — the loadings-only latent slope
(`use_spde_latent_slope`) **+** the augmented `spatial_unique` companion (`use_spde_slope`,
`omega_spde_aug`). **Both engines already exist and co-activate:** the explicit pair fits
with `use_spde_latent_slope = 1` and `use_spde_slope = 1`. And the model is **identifiable** —
on data generated from the fold's own two random fields (Matern GP) it converges
(`conv = 0`) and the fold is **byte-identical in `logLik` to the explicit pair** (ΔLL = 0).
(An earlier probe with a *deterministic* signal gave `conv = 1`: a DGP-mismatch artifact,
not unidentifiability — hence the recovery study, not a convergence flag, arbitrated.)

So it is **parser-only**, the same story as phylo/animal. Wired in `R/brms-sugar.R`
(`spatial_latent` branch): `unique = TRUE` at the augmented LHS desugars to
`spde(.spatial_latent_augmented) + spde(.spatial_unique_augmented)`; the fail-loud is gone.
Parser test in `tests/testthat/test-spatial-latent-unique-fold.R`; the heavy multi-seed
recovery-to-truth gate goes to Codex.

**The augmented `unique =` fold is now complete for every source** — ordinary, `phylo`,
`animal`, `spatial`, `kernel` (the ordination fold was already complete). 10/10 cells.
