# `unique`-family removal — code review (the fix surface)

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread), 3 parallel deep
code-review passes (parser / engine+C++ / extractors+exports+tests) ·
**Read-only — nothing changed.** Decision (maintainer, 2026-06-12): **remove the
whole `unique` family** — `unique`, `phylo_unique`, `animal_unique`,
`spatial_unique`, `kernel_unique` — because it is redundant and, for non-Gaussian,
almost always unnecessary/confusing; the Gaussian residual Ψ folds into `latent`
by default. **This supersedes the "no-prefix only" default in
`2026-06-12-unique-migration-spec.md` §B.1 and the kernel-out note in §B.2.**

## Your rationale, confirmed by the code

The engine puts Ψ (the `diag`/`unique` random effect) in the linear predictor η
*additively, before the family density* (`src/gllvmTMB.cpp:1609-1630`). The family
then adds its **own** noise/dispersion. So Ψ and the family's dispersion are two
variance sources on the same atoms — which is exactly why `unique` is
Gaussian-meaningful and non-Gaussian-redundant:

| Family | Ψ status (from the code) | engine behaviour |
|---|---|---|
| **Gaussian / lognormal / Gamma** | the meaningful residual | σ_eps **auto-suppressed** so Ψ *becomes* the residual (`fit-multi.R:3290-3327`) — **the fold-into-`latent` case** |
| **Poisson** | legitimate OLRE / overdispersion | fit normally — the one clean non-Gaussian use |
| Binary single-trial, ordinal_probit | **unidentifiable** | auto-skipped (`fit-multi.R:3362-3409, 3374-3379`) |
| nbinom1/2, Beta, Tweedie, betabinom | **redundant with the family's own φ** (double dispersion) | fit proceeds — the "confusing" case you flagged |

So the family is genuinely Gaussian-only-meaningful. Removing it + folding Ψ into
`latent` is the right cleanup.

## Headline: removal is **R-side only**

`src/gllvmTMB.cpp` has **no `unique` concept** — the Ψ / diagonal-RE contributions
are gated entirely by integer flags (`use_diag_B/W/species/cluster2`,
`use_phylo_diag`, `use_diag_B_slope`) assembled at `fit-multi.R:2528-2551`. If the
R side stops setting those flags from a `*_unique` keyword, the `dnorm` blocks
simply never fire. **No TMB/C++ change needed.**

## The fix surface, by layer

### 1. Parser (`R/brms-sugar.R` + keyword files) — DELETE
- 4 exported stubs: `animal_unique` (`animal-keyword.R:91`), `phylo_unique`
  (`brms-sugar.R:734`), `spatial_unique` (`brms-sugar.R:794`), `kernel_unique`
  (`kernel-keywords.R:56`). **`unique` is NOT exported** — it's a doc-only parser
  symbol (`brms-sugar.R:436` / `unique-keyword.R`), so "remove from NAMESPACE" is a
  no-op for it.
- 5 desugar branches: `unique` (`:2633-2665`), `phylo_unique` (`:2807-2861`),
  `spatial_unique` arm (`:2505`, `:2595-2630`), `animal_unique` (`:2246-2299`),
  `kernel_unique` (`:2482-2488`).
- **MUST NOT break:** the engine kinds (`diag`, `phylo_rr`, `spde`) and the markers
  `.indep` / `.phylo_unique` — all shared with the **surviving `indep` family**
  (`indep`, `phylo_indep`, `animal_indep`, `spatial_indep`, `kernel_indep`). E.g.
  `unique→diag` and `indep→diag(.indep=TRUE)` are the same slot; `.phylo_unique` is
  set by `phylo_indep` too. Keep all of it.

### 2. Engine (`R/fit-multi.R`) — mostly survives; targeted edits
- **Survives (and is reused by the fold):** the generic `diag`/`phylo_rr`/`spde`
  consumption (`:324, 363, 368, 793`), the **σ_eps auto-suppression** (`:3290-3327`)
  and the **per-family OLRE selection** (`:3329-3445`) — both keyword-agnostic
  (key off `per_row_diag_*` + `family_id`), so they already do the right thing for
  a `diag` term that `latent` auto-emits.
- **Edit:** the over-param guard *messages* that name `unique`
  (`:617-628, 654-661, 744-790, 866-915`) — reword (the keyword can't be typed
  anymore). The `.phylo_unique` routing (`:687-724`) and `lambda_constraint`
  injection (`:3052-3068`) stay (still serve `phylo_indep`).
- **⚠️ THE collision watch-item:** the guard at `fit-multi.R:639-661` **aborts on
  `indep`/`unique` + `latent` on the same grouping** ("over-parameterised"). When
  `latent` auto-emits its Ψ `diag`, that auto-Ψ **must be exempted** from this
  guard, or the fold trips the very error designed to forbid the manual pairing.
  This is the single place the fold most directly collides with the old plumbing.

### 3. C++ — **NO CHANGE.**

### 4. Extractors — **REWIRE `part = "unique"`** (it does NOT survive as-is)
`extract_Sigma(part = "unique")` reads keyword-gated report slots
(`fit$use$diag_*` / `phylo_diag`, set only when a `unique`/`diag` keyword was
parsed). With the keyword gone, **it returns zeros** unless repointed to the
`latent`-folded Ψ. The `part = "unique"` argument value and the `"Psi"` table label
can stay; their **data source** must move to the new default path. Affects
`extract-sigma.R` (950-1169, 1255-1262, the augmented `B_slope`/`phy_unique_slope`/
`spatial` blocks 607-889), `extract-sigma-table.R`, `extract-omega.R`,
`extract-repeatability.R`. The "missing-`unique()`" advisory copy
(`extract-sigma.R:1134-1169, :990`) is **stale → remove/invert**.
`extract-two-psi-cross-check.R` → likely **REMOVE**.

### 5. Exports / man — 4 removals + 5 man pages + re-document
- NAMESPACE: drop `animal_unique` (`:34`), `phylo_unique` (`:126`),
  `spatial_unique` (`:157`), `kernel_unique` (`:99`).
- Delete `man/{animal_unique,phylo_unique,spatial_unique,unique_keyword,diag_re}.Rd`;
  trim the `kernel_unique` alias from `man/kernel_latent.Rd`.
- A dense `@seealso` web (`R/gllvmTMB.R:15-18` the 4×5 grid; `animal-keyword.R`,
  `spde-keyword.R`, `brms-sugar.R` ×~22, `unique-keyword.R`) dangles → ~31 `man`
  pages re-`document()`.

### 6. Tests — REMOVE / REWIRE / KEEP
- **REMOVE (~16 dedicated files):** the augmented-slope `phylo/animal/spatial_unique`
  recovery tests, `test-animal-unique-routing.R`, the `phase56` `phylo_unique`
  parser/stub tests, the `*_unique` redundancy-error cases in
  `test-canonical-keywords.R` / `test-keyword-grid.R`, `extract-two-psi-cross-check`,
  and the "missing-`unique`" advisory test (`test-extract-sigma.R:78`).
- **REWIRE (~19 tier/extractor files, ~50 `part="unique"` sites):** drop the
  `unique()` term, recover Ψ from the new `latent` default — `test-tiers-*.R`,
  `test-cluster2-*.R`, `test-re09-latent-unique-unit.R`,
  `test-cross-sectional-unique.R`, `test-mixed-response-unique-nongaussian.R`,
  `test-sigma-eps-autosuppress.R`, etc.
- **KEEP:** the `part="unique"` return-shape contract (`test-extract-sigma.R:69-75`)
  and the `"Psi"` table label — once their data source is rewired.

## Residual decisions for you (these shape the fix)

1. **Free-correlation reaction norms.** The augmented `*_unique(1 + x | g)` path is
   the *only* one giving a **free** intercept–slope correlation (the `*_indep`
   augmented path pins it to 0). Removing the family **loses** that capability
   unless it's re-homed into `latent(1 + x | g)`. **Preserve (re-home) or drop?**
2. **`common =` knob.** `unique(common = TRUE)` ties per-trait Ψ SDs to one shared
   scalar (`fit-multi.R:338-341`). Does the folded Ψ keep a `common` option on
   `latent`?
3. **Extractor part name.** Keep `part = "unique"` (repointed to the folded Ψ), or
   rename to `part = "psi"` / `"residual"`?
4. **Bare-`latent` transition** (still open): clean-break + warning is the leaning.

## Smallest-safe sequence

1. Engine: make `latent` auto-emit the `diag` (Ψ) by default (reuse the existing
   `diag` path + the family guards), with the `residual = FALSE` opt-out, and
   **exempt the auto-Ψ from the `indep/unique + latent` guard** (the watch-item).
2. Rewire `extract_*` `part="unique"` data source to the folded Ψ.
3. Delete the 5 parser branches + 4 exports + 5 man pages; reword the
   `unique`-naming guards; keep `.indep`/`.phylo_unique` + the `diag`/`phylo_rr`/
   `spde` slots for the surviving `indep` family.
4. Decide #1 (free-corr reaction norms) → either re-home into `latent(1+x|g)` or
   drop those augmented branches + their tests.
5. Tests: REMOVE/REWIRE per the inventory; NEWS + `decisions.md` entry; grid/
   register/article cascade (`unique-migration-spec.md`, scope now = whole family).
