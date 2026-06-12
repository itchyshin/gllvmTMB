# Design proposal: fold Ψ into `latent`, deprecate standalone `unique()`

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:**
**PROPOSAL — for Boole / Gauss / Noether / Fisher review.** No code changed.
Direction confirmed by maintainer (2026-06-12): *`latent` carries both Λ and Ψ;
non-Gaussian is more involved.*

**Updated 2026-06-12 (post-discussion)** — three refinements folded in:
(1) separate **between-unit Ψ** from **OLRE**, which dissolves the dispersion
"confound" (§3–§4); (2) the bare-`latent` transition leans **clean-break + loud
warning** (§7); (3) `unique` retires in **two slices** — residual now, augmented
slope next (§6, §10).

## 1. Motivation

`latent + unique` is the canonical decomposition Σ = ΛΛᵀ + Ψ, and the docs
already say *"you almost always want `unique()`"*. Folding Ψ into `latent`:
- removes a footgun (bare `latent` inflates correlations — `unique-keyword.R:32`);
- aligns with the GLLVM.jl twin, whose Gaussian marginal covariance is
  intrinsically Σ = ΛΛᵀ + diag(d_total) (`GLLVM.jl model.md:67`);
- lets one keyword carry the full per-tier covariance.

## 2. New `latent()` semantics

`latent(0 + trait | g, d = K)` fits **ΛΛᵀ + Ψ where the family identifies Ψ**
(§3). Opt-out for the rotation-invariant / confirmatory Λ-only fit:

```r
latent(0 + trait | g, d = K, residual = FALSE)   # ΛΛᵀ only  [answers Q-a]
```

This reuses the existing identifiability guards — it invents **no new**
identifiability logic, only changes the *default* and where the guard is read.

## 3. Per-family Ψ default — between-unit vs OLRE

The key refinement (maintainer, 2026-06-12): there are **two different Ψ's**, and
the default is about the **between-unit** one, not OLRE.

- **Between-unit Ψ** — `latent` at the *unit* tier. The trait-specific residual
  in the standard decomposition. Identified for the main families given
  replication, and **separable from the family's dispersion φ** (different
  levels). **This is what folds into `latent` by default.**
- **OLRE Ψ** — `latent` at the *per-row* tier. An overdispersion device — the
  **Poisson-flavoured** case. Where a family already carries φ (nbinom/Beta/Gamma)
  it is redundant; for Bernoulli/ordinal it is unidentified. **Not part of the
  default fold;** it stays an explicit, opt-in term under the existing per-family
  OLRE guards (`fit-multi.R:3329`).

**Default rule:** add the between-unit Ψ **wherever the engine already deems it
identified** — i.e. reuse the current "When you do not need `unique()`" rules.
No new per-family table is invented:

| Case | between-unit Ψ default |
|---|---|
| Gaussian, lognormal, Gamma, Poisson, nbinom1/2, Beta, Tweedie, Student-t | **on** (separable from φ given replication) |
| Binary probit/logit/cloglog | the engine's single-obs guard auto-skips when unidentified (implicit link variance is the residual) |
| ordinal_probit, delta_* | **off** (scale-absorbed / OLRE-suspect — existing guards) |

## 4. The dispersion "confound" — RESOLVED by §3

This was flagged open in the first draft; the between-unit/OLRE split resolves it.
For `nbinom/Beta/Gamma/Tweedie`, the per-trait φ is **observation-level**
overdispersion; the default Ψ is a **between-unit** RE. With replication they are
separable, so **between-unit Ψ defaults on and coexists with φ**. The only place
they collide is the **per-row/OLRE** tier — which is exactly where the existing
guards already special-case (defer to φ / skip / warn). So no new maintainer
decision is needed here; Gauss to confirm the reuse is sound.

## 5. `unique()` soft-deprecation mapping (Slice 1)

`lifecycle::deprecate_warn`, context-dependent:

- **Paired** `latent(...) + unique(...)` → `latent(...)`. The `unique()` term
  becomes a **no-op** (Ψ already default-on) → warn, **byte-identical fit**.
- **Standalone** `unique(0 + trait | g)` *alone* (no `latent`) → the Ψ-only
  marginal diagonal = `indep()` numerically. Warn → route to **`indep()`**.
  *(The only context where "→ indep" was ever correct — standalone-alone.)*
- **`*_unique` variants** (`animal_/phylo_/spatial_`) fold into the matching
  `*_latent` where Ψ is identifiable (existing phylo three-piece /
  four-component rules, `unique-keyword.R:53–72`).

## 6. Augmented slopes + extractor (Slice 2)

Corrected from the first draft (it can't "stay unchanged" if `unique` retires):

- Augmented `*_unique(1 + x | g)` is a **free-correlation random regression**. The
  consistent end-state is that it **folds into `latent(1 + x | g, d = K)`**, which
  carries the 2×2 intercept–slope structure — same logic as the residual fold.
  Bigger lift (currently Gaussian-only for ordinary `unique(1+x)`, family-general
  only via `phylo_unique`), so it is a **fast-follow (Slice 2)**, kept out of
  Slice 1 so the slope design is not rushed and the clean residual fold is not
  blocked. `unique` fully retires across the two slices.
- `extract_Sigma(part = "unique")` **keeps its name** — names the Ψ diagonal
  regardless of how Ψ was specified. (Optional `part = "psi"` alias.)

## 7. Backward compatibility — the key hazard, and the call

- `latent + unique` → **unchanged fit** (unique now redundant). Gate with a
  byte-identity test.
- **Bare `latent`-alone changes meaning** (was Λ-only; becomes Λ + Ψ) — a *silent*
  result change for existing analyses. **Decision (maintainer leaning):
  clean-break + loud fire-on-use warning** — flip the default now, and when bare
  `latent` is used without an explicit `residual=`, warn *"the default now
  includes a per-trait residual Ψ; pass `residual = FALSE` for the old
  rotation-invariant fit."* Rationale: bare-`latent` Λ-only is mostly a footgun
  already (inflated correlations), so a clean correct default + warning beats
  prolonging the wrong default. Conservative alternative (warn one cycle, keep old
  behaviour, then flip) noted; **lock at implementation.**
- Per-family identifiability recovery tests (single-obs binary skip, ordinal/delta
  warn, the φ-coexistence families) land **with** the engine change (Curie).

## 8. Cascade (pages) — gradual, after the grammar lands

`latent + unique` → `latent` across the ~28 bucket-A pages, one PR each; the
soft-deprecation keeps unmigrated pages warning-but-working. Buckets B (augmented)
and C (`part = "unique"`) unchanged in Slice 1. Update the grid
(`AGENTS.md`/`CLAUDE.md`/`01-formula-grammar.md`), the register, NEWS, and
`decisions.md`. Full map: `docs/dev-log/2026-06-12-unique-deprecation-audit.md`.

## 9. Decision status

1. **Dispersion confound** — **resolved** (§3–§4): between-unit Ψ default-on and
   coexists with φ; OLRE stays opt-in under existing guards. Gauss to confirm.
2. **Bare-`latent` transition** — **leaning clean-break + warning** (§7); lock at
   implementation.
3. **Augmented-slope spelling** — **resolved**: folds into `latent(1 + x | g)` as
   Slice 2 (§6).

## 10. Sequencing

- **Slice 1 (now):** residual `unique()` retires. Parser default fold (between-unit
  Ψ via existing guards) + `residual = FALSE` opt-out + bare-`latent` warning +
  `unique()`/`*_unique` deprecation mapping + grid/register/NEWS/decisions +
  identifiability & byte-identity tests. Engine: the **parallel Claude thread
  (run from GLLVM.jl)**, with Boole/Gauss/Noether review. Docs + page cascade: Claude.
- **Slice 2 (fast-follow):** augmented `*_unique(1 + x | g)` folds into
  `latent(1 + x | g)` (2×2 free-correlation structure; family coverage per current
  augmented-slope support).
