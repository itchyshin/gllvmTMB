# `unique` deprecation — audit & context map

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:** read-only
map, no code changed. **Direction NOT yet decided — see Correction below.**

## ⚠️ Correction (supersedes the first version of this doc, PR #475)

The first version framed this as **"merge `unique` → `indep`."** **That is wrong**
and is withdrawn. Evidence:

- The engine **forbids `latent + indep`** (and `latent + dep`):
  `R/fit-multi.R:646` aborts *"over-parameterised … use `latent + unique`
  (paired) for the decomposition. They cannot coexist."*
- `latent + unique` is the **canonical decomposition** Σ = ΛΛᵀ + diag(ψ);
  `unique` is the **dedicated Ψ-residual keyword** (`R/unique-keyword.R`),
  Boole-locked and actively extended (`decisions.md:733`).
- `unique` ≡ `indep` **only** in the rare *standalone-alone* case (no `latent`
  on the same grouping). In its primary (paired) role, `indep` cannot replace it.

Empirical proof: `latent(1|id, d=1) + unique(1|id)` fits (logLik −258.67);
swapping to `indep` aborts. So `indep` is not the target.

## Current grammar — the clean quartet (`R/fit-multi.R:565`)

| Form | Meaning | Pairing |
|---|---|---|
| `latent + unique` | decomposition Σ = ΛΛᵀ + Ψ | **paired** |
| `indep` | marginal-only | always alone |
| `dep` | full unstructured | always alone |

`latent + indep` and `latent + dep` are hard-aborted (over-parameterised).

## Leading direction — UNDER DISCUSSION, not decided

Fold Ψ into `latent` by **default** (so `latent(...)` alone = today's
`latent + unique`), and deprecate the *separate* `unique()` keyword (now
implicit). Rationale: it matches the GLLVM.jl twin, whose Gaussian marginal
covariance is intrinsically Σ = Λ_BΛ_Bᵀ + diag(d_total) with the diagonal
**always present** (`GLLVM.jl/docs/src/model.md:67`). Migration would be
`latent + unique` → `latent`, **not** `unique` → `indep`.

**Two open design questions gate everything downstream:**
- **(a)** After the fold, how is the **no-residual / rotation-invariant**
  `latent`-alone fit requested? (e.g. `latent(..., residual = FALSE)`)
- **(b)** How are **augmented free-correlation slopes** spelled once `unique()`
  is gone (bucket B below), and does **`extract_Sigma(part = "unique")`** keep
  its name (bucket C)?

## Context map — where `unique` lives across the pkgdown pages

Almost every modelling page pairs `latent(` + `unique(` (28 of ~30 articles).
But `unique` appears in **four distinct contexts**, and only **A** is a
mechanical fold-into-`latent`:

**A. `latent + unique` decomposition — the dominant case (~28 pages).**
Every modelling article + README + NEWS. Under fold-into-`latent`:
`latent(...) + unique(...)` → `latent(...)`.

**B. Augmented `*_unique(1 + x | …)` — free-correlation random slope (~7 pages).**
`README:256`, `NEWS:53`, `random-regression-reaction-norms` (167/197),
`random-slopes-nongaussian:39`, `choose-your-model` (292/296/541/543),
`phylogenetic-gllvm` (476/491), `animal-model` (564/572/625/631).
**Does not fold into `latent`.** `NEWS:305` confirms `*_indep(1+x)` pins the
intercept–slope correlation to 0 while `*_unique(1+x)` is the family-general
**free-correlation** path. This is the genuine `unique`≠`indep` wrinkle.

**C. Extractor `part = "unique"` (~4 pages).**
`covariance-correlation` (92/289/303/479), `morphometrics` (242/282),
`phylogenetic-gllvm` (182/198/589), `random-regression-reaction-norms:283`.
Names the Ψ diagonal regardless of how it was specified — **likely keeps its name.**

**D. "uniqueness" / communality prose — factor-analysis concept (never changes).**
Heaviest in `lambda-constraint` (17), `behavioural-syndromes` (14),
`covariance-correlation` (10). Distinct from the keyword; must not be renamed.

## Code + contract surface (touched by any deprecation; direction-independent)

| Item | Location |
|---|---|
| 5 keyword defs | `unique` (R/unique-keyword.R), `animal_unique` (R/animal-keyword.R), `phylo_unique`+`spatial_unique` (R/brms-sugar.R 734/794), `kernel_unique` (R/kernel-keywords.R 56) |
| parser branches | R/brms-sugar.R — `unique` 2633, `phylo_unique` 2807, `animal_unique` 2246, `spatial_unique` 2504/2588, `kernel_unique` 2482 |
| engine markers + guard | R/fit-multi.R — `.phylo_unique`, `.unique_augmented`, `.spatial_unique_augmented`; over-param guard 565–650 |
| exports | NAMESPACE — `animal_unique`, `phylo_unique`, `spatial_unique`, `kernel_unique` |
| Rd | `man/{unique_keyword,animal_unique,phylo_unique,spatial_unique}.Rd` |
| grid | `AGENTS.md`/`CLAUDE.md` 4×5 grid; `docs/design/01-formula-grammar.md` |
| register | `docs/design/35-validation-debt-register.md` — FG-05/06/07, PHY-02/11/17/18, SPA-02/08, ANI-02/11, RE-09/12, KER-02 |
| tests | ~30 `tests/testthat/test-*unique*.R` |

## Status

Read-only map. **No direction decided; no code, grammar, or page changes** until
(a) and (b) above are settled. The "merge → indep" sequencing from the first
version is withdrawn.
