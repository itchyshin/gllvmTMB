# After-task — isdm lands on main; the SDM article collection opens

Date: 2026-08-16 · Platform: Claude · Lanes:
`codex/isdm-range-amplitude-orthogonal` (merge, PR #1031) then
`claude/sdm-collection-20260816` (this PR).

## Scope

Two user-directed deliverables, executed under one approved ultra-plan:

1. **Land the integrated-SDM programme on `main`** — PRs #1016 (public
   `gllvmTMB()` door + two articles), #1027 (branch passes `R CMD check`),
   #1030 (multi-source `isdm_sources()` + third article), already merged
   within the branch, brought to `main` via PR #1031.
2. **Open the pkgdown "Species Distribution Models" collection** — a new
   navbar menu ordering SDM → JSDM → i-JSDM as a curriculum, plus the
   missing presence-only opener: a new fully-evaluated article,
   `vignettes/articles/gbif-joint-intensity.Rmd`.

## Outcome

### The merge (PR #1031, merged; `main` @ `2b87aa98`)

- Merged current `main` INTO the branch first, so CI ran on exactly the tree
  that landed. Three conflicts, all resolved to keep both programmes:
  - `src/gllvmTMB.cpp` DATA block: isdm `report_obs_nll` AND main's full
    MSPL block.
  - `src/gllvmTMB.cpp` binomial dispatch, composed: MSPL takes precedence
    when `estimator_id != 0`; otherwise cloglog rows route through the iSDM
    tail-safe `gll_dbinom_cloglog` kernel (a strict improvement over the
    naive clamped ML form); logit/probit unchanged.
  - check-log union merge; lane-split map keeps both sides' rows.
- Validation on the final tree: isdm/offset/family block **305 pass /
  0 fail**; MSPL block **1630 pass / 2 fail**, both failures being the
  source-pin test that is red on `origin/main` itself (`R/mspl.R` widened to
  `c(0L, 1L, 2L, 5L, 15L)` without updating the pin — flagged in the PR
  body, deliberately not fixed here; the MSPL lanes own that file).
- CI (first ever run on this work): `ubuntu-latest (release)` **pass**,
  39m48s.
- Post-merge verification: `main` carries `R/isdm-sources.R`, all three
  integrated articles, and the composed template (`report_obs_nll` and
  `estimator_id` both present).

### The SDM collection (this lane)

- **New article** `gbif-joint-intensity.Rmd` — the "Article 1" that existed
  only as an unevaluated, fenced staging draft
  (`dev/isdm-package-recovery/article-staging/gbif-joint-intensity.Rmd`,
  untouched). Written fresh, fully evaluated: 6 wetland species × 300 cells,
  59% zeros, plain `gllvmTMB()` with `poisson()` + effort offset +
  accessibility bias covariate + `latent(d = 1)`. Health PASS/PASS. Slope
  recovery tight (max abs err ~0.12); bias-association recovery honestly
  noisier (max abs err ~0.31) and the prose teaches that asymmetry. The
  estimand fence is the staging draft's: relative ecological intensity only;
  bias identification stated as a design assumption in three places.
- **Rose-lens audit (read-only Sonnet child)**: 1 blocker + 2 lesser
  findings, all fixed before commit — an interval fence around the
  `extract_correlations()` table (`heuristic_unvalidated` now contextualised
  in prose), the single-draw generalisation softened, and the correlations
  paragraph rewritten to describe only the printed rows.
- **`_pkgdown.yml`**: new navbar component `sdm` ("Species Distribution
  Models") between Model Guides and Concepts — joint-sdm (moved from Model
  Guides), the new opener, the three integrated articles, and cross-links to
  the LA-MSPL binary JSDM and spatial articles (whose index homes stay in
  Model Guides). Index section "Data integration (experimental)" renamed to
  "Species distribution models" and now opens with joint-sdm and the new
  article.
- **NEWS**: one entry under 0.7.0 New.

## Checks

- Article renders end-to-end with every chunk evaluated, in the lane
  worktree against the post-merge tree.
- `pkgdown::check_pkgdown()` clean in the lane worktree.
- No internal register codes on the reader surface (audited).
- No `R/`, `src/`, or test changes in this lane — docs/articles class.

## Follow-ups

- The MSPL source-pin test (`test-mspl-poisson-phase4-oracles.R`, "prepare
  public door … (source pin)") is red on `main`; owned by the MSPL phase-4
  lanes; flagged in PR #1031's body.
- The staged repeated-survey draft
  (`article-staging/integrated-jsdm-repeated-survey.Rmd`) remains the next
  candidate article if the collection grows.
- Deferred items from the isdm programme carry over unchanged (all-PA
  declarations, #944 weights, per-source bias covariates, calibrated
  intervals, spatial evidence at n > 2).
