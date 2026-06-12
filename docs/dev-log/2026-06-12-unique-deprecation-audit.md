# `unique` → `indep` deprecation — audit & migration tracker

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:** read-only
audit + tracker (no code changed). Cross-repo notice already dropped in
`GLLVM.jl/docs/dev-log/2026-06-12-inbox-from-gllvmTMB-unique-deprecation.md`.

## Decision (maintainer, 2026-06-12)

Deprecate the `unique` covstruct keyword family; **merge semantics into `indep`**;
**soft-deprecation with a working alias** (`lifecycle::deprecate_warn`) — *not*
hard removal. `unique()` keeps fitting, warns, routes to the `indep` path. Docs
migrate **gradually** (no AGENTS.md rule-10 lockstep this cycle).

**Survives the rename (do NOT touch):** `psi`/`Psi`; the canonical decomposition
`latent + unique` → Σ = ΛΛᵀ + diag(ψ) (concept); and the **"uniqueness" /
communality** factor-analysis vocabulary (1 − communality) — that is a different
concept from the keyword and must not be renamed.

## ⚠️ Correlated-slope wrinkle (must resolve in PR1)

Standalone `unique`≡`indep`. But the **augmented** forms differ *today*:
`*_indep(1+x|g)` desugars with `.indep = TRUE` (intercept–slope correlation
**pinned to 0**); `*_unique(1+x|g)` omits it (correlation **free**;
`atanh_cor_b` free) — see `R/brms-sugar.R` 2253/2295 vs 2346/2386/2942/3001.
**Plan:** the alias preserves *old `unique` behavior* (warn + keep the existing
engine path), so deprecation is cosmetic this cycle; unify markers later.

## Surface 1 — code + contract (engine PR1, the shim)

| Item | Location |
|---|---|
| 5 keyword defs | `unique` (R/unique-keyword.R), `animal_unique` (R/animal-keyword.R), `phylo_unique`+`spatial_unique` (R/brms-sugar.R 734/794), `kernel_unique` (R/kernel-keywords.R 56) |
| parser branches | R/brms-sugar.R — `unique` 2633, `phylo_unique` 2807, `animal_unique` 2246, `spatial_unique` 2504/2588, `kernel_unique` 2482 |
| engine markers | R/fit-multi.R — `.phylo_unique`, `.unique_augmented`, `.spatial_unique_augmented` |
| exports | NAMESPACE — `animal_unique`, `phylo_unique`, `spatial_unique`, `kernel_unique` |
| Rd | `man/{unique_keyword,animal_unique,phylo_unique,spatial_unique}.Rd` (+ cross-refs) — regenerate |
| grid | `AGENTS.md`/`CLAUDE.md` 4×5 grid; `docs/design/01-formula-grammar.md` |
| register | `docs/design/35-validation-debt-register.md` — FG-05/06/07, PHY-02/11/17/18, SPA-02/08, ANI-02/11, RE-09/12, KER-02 |
| extractor | `extract_Sigma(part = "unique")` — decide separately (names Ψ regardless of keyword; may stay) |
| tests | ~30 `tests/testthat/test-*unique*.R` (keep running under the alias) |

**PR1 =** `deprecate_warn("0.2.0", "unique()", "indep()")` on the 5 defs (+ standalone
parser branch), each routing to its **current** engine path (behavior-preserving)
+ grid/register/NEWS/decisions updates + one `expect_warning` test that `unique()`
warns and still fits identically. Engine-sensitive (R/brms-sugar.R, R/fit-multi.R)
→ Codex's lane per the collaboration rhythm; this doc is the drafted shape.

## Surface 2 — pages (gradual migration; verified keyword-only counts)

Counts are raw keyword *signal* (not de-duplicated): **var** = `*_unique`
variants; **call** = bare `unique(` in chunks; **decomp** = `latent + unique` /
`part="unique"` prose. The English **"uniqueness"** count is shown only to mark
where editors must be careful NOT to rename the surviving concept.

### PUBLIC (navbar / homepage — migrate first, one PR each)

| Page | var | call | decomp | "uniqueness" (survives) | note |
|---|--:|--:|--:|--:|---|
| `README.md` | 0 | 12 | 3 | — | Tiny example + grid row |
| `articles/api-keyword-grid.Rmd` | 12 | 18 | 6 | — | **the grid reference — must update** |
| `articles/covariance-correlation.Rmd` | 1 | 24 | 17 | 10 | heaviest; CAUTION: 10 "uniqueness" stay |
| `articles/morphometrics.Rmd` | 0 | 8 | 8 | 4 | Tier-1 exemplar |
| `articles/pitfalls.Rmd` | 3 | 8 | 4 | — | |
| `articles/model-selection-latent-rank.Rmd` | 0 | 5 | 2 | — | |
| `articles/joint-sdm.Rmd` | 0 | 4 | 3 | 5 | |
| `articles/response-families.Rmd` | 0 | 4 | 1 | — | |
| `articles/convergence-start-values.Rmd` | 0 | 3 | 2 | — | |
| `articles/fit-diagnostics.Rmd` | 0 | 1 | 1 | — | |
| `articles/lambda-constraint.Rmd` | 2 | 2 | 0 | 17 | mostly the surviving concept |
| `vignettes/gllvmTMB.Rmd` (main) | 0 | 4 | 1 | 4 | Get-started |

### INTERNAL drafts (not in navbar — batch later; alias keeps them running)

`choose-your-model` (18/16/8), `phylogenetic-gllvm` (9/16/9),
`functional-biogeography` (11/14/1), `animal-model` (14/3/0),
`random-regression-reaction-norms` (0/12/3), `stacked-trait-gllvm` (4/8/2),
`cross-lineage-coevolution` (7/0/0), `behavioural-syndromes` (0/7/3 — 14 surviving
"uniqueness"), `profile-likelihood-ci` (1/6/3), plus small hits in
`mixed-family-extractors`, `cross-package-validation`, `ordinal-probit`,
`simulation-*`, `random-slopes-nongaussian`, `data-shape-flowchart`,
`gllvm-vocabulary`, `psychometrics-irt`.

### NEWS.md

16 variant + 9 call + 8 decomp — update the grid table + add the deprecation entry.

## Sequencing

1. **PR1** — engine shim + grid + register + NEWS + `decisions.md` + warn-test (Codex).
2. **Public pages**, one PR each: `README` → `api-keyword-grid` → `morphometrics`
   → `covariance-correlation` → `model-selection-latent-rank` / `joint-sdm` / `pitfalls`.
3. **Internal drafts** — batch sweep later.
4. **GLLVM.jl twin** — mirror docs (`covariance-correlation.md` "When you need `unique`");
   notice already delivered to that thread.

Per-line edits happen inside each page's own PR (the alias keeps unmigrated pages
working, so this is safe to do incrementally).
