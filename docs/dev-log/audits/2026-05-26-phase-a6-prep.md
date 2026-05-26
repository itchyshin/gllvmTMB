# Phase A6 prep — articles inventory + NEWS pre-draft + validation-debt row pre-draft

**Date:** 2026-05-26
**Author:** Shannon (for the maintainer)
**Status:** docs/dev-log audit memo. **No live edits to the validation-debt register or to articles**; A6 itself lands after Phase 56.5 closes (per Active Plan 2026-05-26). This memo pre-stages the three error-prone bookkeeping pieces so the slice isn't bottlenecked when it unblocks.

## Scope

A6 deliverables per Active Plan 2026-05-26:

1. Soft-deprecate `phylo_slope()` and `animal_slope()` via `lifecycle::deprecate_soft()`.
2. Update articles that reference these keywords.
3. `NEWS.md` entry.
4. Walk validation-debt register rows RE-02, FG-15, PHY-06, ANI-06 to `covered` for Gaussian, and add a new `SPA-slope` row.

This memo covers (2)–(4) ahead of time:

- **(a) Articles inventory** — exact files and line numbers A6 must edit.
- **(b) NEWS.md pre-draft** — language ready to paste under the next-release header.
- **(c) Validation-debt register pre-draft** — wording for the row walks plus the new `SPA-slope` row.

It does **not** stage the deprecation messages themselves; those touch `R/brms-sugar.R` which is Codex-owned per Active Plan 2026-05-26 (Phase 56.3 file scope).

## (a) Articles inventory

`grep -rn "phylo_slope\|animal_slope" vignettes/articles/` against `main` tip `f6d6cc6` (2026-05-26) returns **9 locations across 6 articles**. The A6 slice must migrate each location to the new canonical syntax — `phylo_unique(1 + x | sp)` / `animal_unique(1 + x | id)` for the wide surface, or the long form `(0 + trait + (0 + trait):x | id)` per Design 55 §3.

| File | Line | Current usage | Migration target |
|---|---:|---|---|
| `vignettes/articles/animal-model.Rmd` | 438 | `animal_slope(x \| id)` (per-individual slope example) | `animal_unique(1 + x \| id)` |
| `vignettes/articles/api-keyword-grid.Rmd` | 50 | `phylo_slope(x \| species)` and `animal_slope(x \| id)` (top-of-page keyword tour) | Same keywords with new LHS form; this is a structural rewrite of the keyword grid table |
| `vignettes/articles/api-keyword-grid.Rmd` | 58 | `ANI-06` validation-status row text (currently "partial") | Reflect A6's "covered" walk |
| `vignettes/articles/api-keyword-grid.Rmd` | 278 | `phylo_slope(x \| species)` definition | `phylo_unique(1 + x \| species)` |
| `vignettes/articles/api-keyword-grid.Rmd` | 282 | `animal_slope(x \| id)` definition | `animal_unique(1 + x \| id)` |
| `vignettes/articles/choose-your-model.Rmd` | 205 | `animal_slope(x \| individual)` mention | `animal_unique(1 + x \| individual)` |
| `vignettes/articles/data-shape-flowchart.Rmd` | 168 | `animal_slope` flowchart entry | Update to `animal_unique(1 + x \| id)` or the canonical augmented-LHS keyword |
| `vignettes/articles/gllvm-vocabulary.Rmd` | 250 | `animal_slope(x \| individual, pedigree = ped)` example | `animal_unique(1 + x \| individual, pedigree = ped)` — preserve the pedigree path semantics |
| `vignettes/articles/phylogenetic-gllvm.Rmd` | 418 | `[animal_slope](../reference/animal_slope.html)` link | Redirect to the new keyword reference page |

**Concentration**: `api-keyword-grid.Rmd` carries 4 of the 9 locations. A6 should treat that article as a single coherent rewrite, not as four independent point-edits.

**Render-time risk**: once `lifecycle::deprecate_soft()` lands in `R/brms-sugar.R`, any vignette that still calls the deprecated keywords without `lifecycle::expect_deprecated()` wrap will emit a deprecation message during `devtools::build_vignettes()` / pkgdown. A6 must rewrite the *examples themselves*, not just add deprecation notices alongside.

## (b) NEWS.md pre-draft

Paste under the next-release header in `NEWS.md` when A6 opens. Three short bullets:

```markdown
# gllvmTMB (next release)

## New canonical syntax for structural random slopes

* `phylo_*()`, `animal_*()`, and `spatial_*()` keywords now accept the
  augmented LHS form `(1 + x | id)` (intercept + slope) across all five
  canonical structural-dependence keywords (`*_latent`, `*_unique`,
  `*_indep`, `*_dep`, `*_scalar`). The same model can be expressed in long
  form as `(0 + trait + (0 + trait):x | id)`; the two surfaces are
  byte-identical per the wide↔long contract. See `?phylo_unique`,
  `?animal_unique`, `?spatial_unique`, and `vignette("api-keyword-grid")`.

* The standalone `phylo_slope()` and `animal_slope()` keywords are
  **soft-deprecated** via `lifecycle::deprecate_soft()`. Existing calls
  continue to work and emit a one-time message redirecting users to the new
  syntax. The deprecated keywords remain exported for at least one minor
  version. Use `phylo_unique(1 + x | sp)` /
  `animal_unique(1 + x | id)` going forward.

* The augmented LHS form composes with the SPDE precision in `spatial_*()`
  keywords; `spatial_unique(1 + x | site)` and the long-form equivalent are
  validated for Gaussian responses against simulated truth in
  `test-spatial-{latent,unique,indep,dep}-slope-gaussian.R`. Non-Gaussian
  families remain a Phase B deliverable.
```

The phrasing assumes A6 lands after Phase 56.4 closes the (4 × 5 × Gaussian) APPLICABLE matrix per Design 55 §5. If 56.5 closure shrinks the cell list, the third bullet may need a "*_dep` excluded" or similar caveat.

## (c) Validation-debt register pre-draft

Target file: `docs/design/35-validation-debt-register.md`. All updates land after the (4 × 5 × Gaussian) recovery matrix passes per Active Plan A7 close-gate.

### Updates to existing rows

| Row | Current | A6 target wording |
|---|---|---|
| **RE-02** "One random slope (`s = 1`)" | `partial` — `test-phylo-slope.R` | `covered` — evidence: `test-phylo-unique-slope-gaussian.R` (recovery, byte-identity at 1e-6) plus the 16-cell APPLICABLE matrix per Design 55 §5. Recovery target: ≥ 4-decimal on σ²_α, σ²_β, ρ. |
| **RE-03** "Two or more random slopes (`s ≥ 2`)" | `blocked` — n/a | **stays `blocked`**. Active Plan §"What this plan does NOT include" reserves this for later; Design 56 parameter shapes generalize trivially (the `log_sd_b` / `atanh_cor_b` vectors scale to any s), but no recovery work or test surface in scope. |
| **FG-15** "`phylo_slope()` random-slope keyword" | `partial` — smoke only | `covered` — evidence: `lifecycle::deprecate_soft()` redirects to `phylo_unique(1 + x | sp)` plus recovery in `test-phylo-unique-slope-gaussian.R`. Row name should be **reframed** to point at the canonical syntax — recommended new wording: "Augmented-LHS phylogenetic random regression (wide and long surfaces)". |
| **PHY-06** "Phylo-slope keyword `phylo_slope()`" | `partial` — `test-phylo-slope.R` | `covered` — evidence: `test-phylo-{latent,unique,indep,dep}-slope-gaussian.R` (4 cells) post-Phase 56.4 activation. Same reframing note as FG-15. |
| **ANI-06** "`animal_slope(x \| id)`" | `partial` — `test-animal-keyword.R` smoke | `covered` — evidence: `test-animal-{latent,unique,indep,dep}-slope-gaussian.R` (4 cells) post-Phase 56.4. Reframing target: `animal_unique(1 + x | id)` etc. |

### New row to add

In the spatial section of `design/35` (insert after the last `SPA-` row):

| ID | Capability | Status | Test evidence | Notes |
|---|---|---|---|---|
| `SPA-slope` | Spatial augmented-LHS random regression (`spatial_*(1 + x \| site)`) | `covered` (Gaussian) | `test-spatial-{latent,unique,indep,dep}-slope-gaussian.R` (4 cells) | Composes with SPDE precision; Kronecker decomposition holds because the structural matrix is the GMRF precision (Q) rather than a covariance. Recovery only validated for Gaussian; non-Gaussian deferred to Phase B. |

### Relmat row — judgement call

There is no explicit register row for the user-supplied A path (`phylo_*(species, vcv = A_user, ...)`) random regression. A6 should consider adding a `REL-slope` row mirroring `SPA-slope`, with evidence `test-relmat-{latent,unique,indep,dep}-slope-gaussian.R`. Alternative interpretation: the relmat path is already implicitly covered by the `phylo_*(... vcv = A)` semantics (Design 14 byte-equivalence) and doesn't need its own row. **Maintainer decides** — leave as an open question for the A6 PR description.

## Open questions for A6 lead

1. **Row reframing vs. preserving keyword names.** FG-15, PHY-06, ANI-06 are named after the deprecated keywords. Reframing them to point at the new canonical keywords could break backward compatibility for anyone cross-referencing the register from a paper or external doc. Alternative: keep the row names, mark `covered (via deprecation + new canonical syntax)` and rely on the row body to describe the canonical path. Recommend the latter for stability; flag for maintainer.

2. **SPA-slope row position.** New row goes in the spatial section of `design/35` — quick visual confirm of section order needed before the A6 PR opens.

3. **NEWS.md release header.** A6 lands before a release tag; header should be `(next release)` or the actual version planned (depends on release schedule).

4. **Deprecation message wording.** `lifecycle::deprecate_soft()` takes a `with` argument naming the replacement. Suggested: `"Use `phylo_unique(1 + x | sp)` instead. See `?phylo_unique` and `vignette('api-keyword-grid')`."` for `phylo_slope`; analogous for `animal_slope`. The actual deprecation message string lives in `R/brms-sugar.R` (Codex-owned in Phase 56.3); leave the exact wording as a coordination item for the A6 PR.

## Estimated A6 effort

Per Active Plan: **~1 day**. This memo pre-stages roughly half that — the inventory and language work. Remaining day-of work for A6:
- The actual `lifecycle::deprecate_soft()` calls in `R/brms-sugar.R` (Codex / Emmy).
- The article rewrites at the 9 locations above (Shannon / Emmy).
- The NEWS.md paste (Shannon).
- The register edits (Shannon / Rose).
- Pre-publish + 3-OS CI verification + after-task report.

## Cross-references

- Active Plan 2026-05-26, slice A6 (`docs/superpowers/specs/` or wherever the plan is currently anchored).
- Design 55 §5 — APPLICABLE matrix.
- Design 56 §5.2 — engine shape (block-local `n_lhs_cols ∈ {1, 2}`).
- Design 56 §9.1 — Phase 56.1 validation contract + Shannon post-merge role.
- PR [#289](https://github.com/itchyshin/gllvmTMB/pull/289) — Phase 56.1 dormant TMB promotion (3-OS green at time of writing).
- PRs [#282](https://github.com/itchyshin/gllvmTMB/pull/282) / [#283](https://github.com/itchyshin/gllvmTMB/pull/283) / [#284](https://github.com/itchyshin/gllvmTMB/pull/284) — 16 skeleton tests (activation surface for Phase 56.4).
- `docs/dev-log/audits/2026-05-26-phase-56-5-per-cell-scoping.md` (#287) — per-cell sample-size scoping.
- `docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md` (#288) — Phase B0 non-Gaussian identifiability map.
- `docs/design/35-validation-debt-register.md` — target file for (c).

---

— Shannon, 2026-05-26
