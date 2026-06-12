# Design proposal: fold Ψ into `latent`, deprecate standalone `unique()`

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:**
**PROPOSAL — for Boole / Gauss / Noether / Fisher review.** No code changed.
Direction confirmed by maintainer (2026-06-12): *`latent` carries both Λ and Ψ;
non-Gaussian is more involved.* Open questions are flagged **[OPEN]** inline.

## 1. Motivation

`latent + unique` is the canonical decomposition Σ = ΛΛᵀ + Ψ, and the docs
already say *"you almost always want `unique()`"*. Folding Ψ into `latent`:
- removes a footgun (bare `latent` inflates correlations — `unique-keyword.R:32`);
- aligns with the GLLVM.jl twin, whose Gaussian marginal covariance is
  intrinsically Σ = ΛΛᵀ + diag(d_total) (`GLLVM.jl model.md:67`);
- lets one keyword carry the full per-tier covariance.

## 2. New `latent()` semantics

`latent(0 + trait | g, d = K)` fits **ΛΛᵀ + Ψ where the family identifies Ψ**
(per-family policy, §3). Opt-out for the rotation-invariant / confirmatory
Λ-only fit:

```r
latent(0 + trait | g, d = K, residual = FALSE)   # ΛΛᵀ only  [answers Q-a]
```

This reuses the existing identifiability guards — it invents **no new**
identifiability logic, only changes the *default* and where the guard is read.

## 3. Per-family Ψ-default policy

| Family | Ψ status | Source rule |
|---|---|---|
| Gaussian, lognormal, Gamma | **on** | the wanted residual |
| Poisson | **on** | Ψ *is* the overdispersion (OLRE) |
| Binary probit/logit/cloglog | **off** | implicit link variance (1, π²/3, π²/6); explicit Ψ unidentified (`unique-keyword.R:48`) |
| ordinal_probit, delta_lognormal, delta_gamma | **off / warn** | OLRE unidentifiable — engine already warns (`fit-multi.R:3343,3368`) |
| nbinom1/2, Beta, Tweedie, Student-t | **tier-aware — see §4** | family carries its own dispersion φ |

The point: "`latent` = ΛΛᵀ + Ψ" is shorthand for "**Ψ where identified**," and the
identifiability table above is *already implemented* (the "When you do not need
`unique()`" rules + the per-family OLRE selection block at `fit-multi.R:3329`).

## 4. The dispersion confound — **[OPEN: maintainer/Gauss/Fisher call]**

`nbinom1/2`, `Beta`, `Gamma`, `Tweedie`, `Student-t` each have a per-trait
dispersion φ (`fit-multi.R:2742`, `03-likelihoods.md:60`) that captures
**observation-level** overdispersion. Ψ is a per-trait **random effect at a
grouping tier**. Whether they confound depends on the tier:

- **Between-unit tier** (`latent` at `unit`, with replication): Ψ (between-unit
  RE) and φ (observation dispersion) live at different levels → separable →
  **Ψ on**.
- **OLRE / per-row tier** (`latent` at `unit_obs`, no replication): Ψ ≈ φ →
  confounded → **defer to φ, Ψ off** (matches the existing OLRE-suspect handling).

**Recommendation:** tier-aware default (Ψ on between-unit, off at OLRE for
dispersion families). **Alternative:** always defer to φ (Ψ off for all
dispersion families) — simpler, but loses the legitimate between-unit RE.
Needs Gauss/Fisher confirmation.

## 5. `unique()` soft-deprecation mapping

`lifecycle::deprecate_warn`, context-dependent:

- **Paired** `latent(...) + unique(...)` → `latent(...)`. The `unique()` term
  becomes a **no-op** (Ψ already default-on) → warn, **byte-identical fit**.
- **Standalone** `unique(0 + trait | g)` *alone* (no `latent`) → the Ψ-only
  marginal diagonal = `indep()` numerically. Warn → route to **`indep()`**.
  *(This is the only context where "→ indep" was ever correct — the
  standalone-alone case, not the decomposition.)*
- **`*_unique` variants** (`animal_/phylo_/spatial_`) fold into the matching
  `*_latent` where Ψ is identifiable, following the existing phylo
  three-piece / four-component rules (`unique-keyword.R:53–72`).
- **Augmented** `unique(1 + x | g)` — **not** folded (§6).

## 6. Augmented slopes + extractor — **[OPEN: Q-b]**

- Augmented `*_unique(1 + x | g)` is a **free-correlation random regression**, a
  distinct structure from the residual Ψ. **Proposal: leave it unchanged in this
  slice** (do not deprecate it with the Ψ-fold); decide its spelling separately
  so two features don't entangle.
- `extract_Sigma(part = "unique")` **keeps its name** — it names the Ψ diagonal
  regardless of how Ψ was specified. (Optional: add a `part = "psi"` alias.)

## 7. Backward compatibility — the key hazard

- `latent + unique` → **unchanged fit** (unique now redundant). Gate with a
  byte-identity test.
- **Bare `latent`-alone changes meaning** (was Λ-only; becomes Λ + Ψ). This
  *silently alters existing bare-`latent` fits.* **[OPEN]** Transition:
  deprecation-warn on bare `latent` for one cycle — *"the default now includes a
  per-trait residual Ψ; pass `residual = FALSE` for the old Λ-only fit."* Without
  this it is a silent breaking change.
- Per-family identifiability recovery tests (binary Ψ-off, ordinal/delta warn,
  the confound families) land **with** the engine change (Curie).

## 8. Cascade (pages) — gradual, after the grammar lands

`latent + unique` → `latent` across the ~28 bucket-A pages, one PR each; the
soft-deprecation keeps unmigrated pages warning-but-working. Buckets B
(augmented) and C (`part = "unique"`) unchanged. Update the grid
(`AGENTS.md`/`CLAUDE.md`/`01-formula-grammar.md`), the register, NEWS, and
`decisions.md`. Full map: `docs/dev-log/2026-06-12-unique-deprecation-audit.md`.

## 9. Open questions for the maintainer

1. **Dispersion confound (§4):** tier-aware (recommended) vs always-defer-to-φ?
2. **Bare-`latent` transition (§7):** warn-one-cycle (recommended) vs hard switch?
3. **Augmented-slope spelling (§6):** keep `unique(1 + x)` vs move under
   `latent(1 + x)`?

## 10. Reviewers & sequencing

Boole (grammar), Gauss (likelihood/identifiability), Noether (symbolic↔engine
match), Fisher (confound/identifiability), Curie (recovery tests). After the
maintainer answers §9: Codex implements the engine (parser default + per-family
policy reusing existing guards), Claude does docs + the page cascade.
Identifiability + byte-identity tests ship with the implementation.
