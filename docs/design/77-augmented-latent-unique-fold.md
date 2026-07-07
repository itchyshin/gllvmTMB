# Design 77 — Augmented `*_latent(unique = TRUE)` fold consistency

**Status:** 2026-07-07 — `phylo`/`animal` augmented fold **WIRED** (loadings + the
existing `phylo_slope(.phylo_unique_augmented)` companion == the explicit pair);
`kernel`/ordinary `latent` already fold; **`spatial` is the next arc — C++**
(starting kit below). Footgun fix (fail-loud) was the interim that restored the
design's intended guard.
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
- **The additive slot may already be in C++** — `src/gllvmTMB.cpp` (~L156-168)
  documents `spde_lv_k` (0 = per-trait fields / `spatial_unique`; ≥1 = low-rank
  `spatial_latent`) **and** a `spde_lv_unique` flag: *"If `spde_lv_unique == 1`,
  an additional per-trait `omega_spde` block is [added on top of the low-rank
  fields]."* That is exactly the additive `Lambda Lambda^T + Psi` fold slot.
  **First step: confirm whether `spde_lv_unique` is wired + tested or dormant** —
  the 2026-06-21 blocker said "engine confirmation needed," but this flag suggests
  the mechanism may already be present.
- **Design target** (`2026-06-21-source-specific-latent-psi-fold.md:58`):
  `spatial_latent(coords, d = K, unique = TRUE)` →
  `spde(coords, d = K) + spde(coords, .spatial_unique = TRUE, .auto_unique = TRUE)`.
- **Related branches to diff before starting:** `agent/spatial-slope-base`,
  `agent/spatial-dep-latent-slope(s)`, `agent/ci-spde-density-fix`, and the
  `codex/spatial-latent-psi-fold-20260621` arc (PR #525) that recorded the blocker.

**Gap to close:** confirm/activate `spde_lv_unique` (low-rank + per-trait additive
in one fit), set `use_spde_slope` / companion routing, wire the parser
(`spatial_latent(1 + x | coords, unique = TRUE)` and the ordination form → set the
flag), add recovery + byte-identity tests. Replace the spatial fail-loud with the
fold only once a fit recovers to truth.
