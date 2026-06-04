# After-task: flagship non-Gaussian structured random-slope article

- **Date:** 2026-06-04
- **Author:** Claude Code
- **Branch:** `claude/article-random-slopes`
- **Closes (deliverable):** #341 "random-slope article"
- **Gate:** maintainer rendered-HTML review (#230 / #347); promotion into
  the visible `_pkgdown.yml` index is owned by #447 and is NOT done here.

## Scope

Draft a flagship pkgdown article showcasing the now-complete
**non-Gaussian structured random-slope grid** (reaction norms / random
regression): every core family crossed with the phylogenetic and spatial
sources across the `indep` / `latent` / `dep` correlation modes
(#388 / #392 / #422 / #424 / #427 / #429; `nbinom1` via #441).

## Extend vs new: NEW article

Read the existing `vignettes/articles/random-regression-reaction-norms.Rmd`
and `vignettes/articles/morphometrics.Rmd` (house style).

Decision: **create a complementary new article**
`vignettes/articles/random-slopes-nongaussian.Rmd` rather than edit the
existing one.

Rationale: the existing reaction-norms article is comprehensive for the
*Gaussian, single-variance* `phylo_slope` / `animal_slope` mode, but its
scope table and "what is forthcoming" section explicitly mark the
structured `phylo_dep` / `phylo_latent` and `spatial_dep` /
`spatial_latent` slopes and the non-Gaussian augmented forms as
**forthcoming / engine in progress**. That framing is now stale. Rewriting
those validated, approved sections in place would be a broad article
rewrite -- high-risk per CLAUDE.md / the ROADMAP discussion-checkpoint
list. A self-contained new article that documents the completed grid and
cross-links the existing one is the lower-risk shape and keeps the new
deliverable clean for the #230 HTML gate. The existing article is left
untouched (no Codex/human prose reverted).

## Content / families & modes demonstrated

- **Augmented-slope grammar table:** `(1 + x | group)`,
  `phylo_indep` / `phylo_latent` / `phylo_dep(1 + x | species)`,
  `spatial_indep` / `spatial_dep(1 + x | coords)`; long `0 + trait +
  (0 + trait):x` vs wide `traits(...)` shorthand equivalence noted.
- **Gaussian** small fit, `phylo_indep(1 + x | species)`, BOTH long and
  wide (`tidyr::pivot_wider`), logLik byte-equivalence shown.
- **Poisson** small fit, `phylo_indep(1 + x | species)`, slope-variance
  recovery from `report$sd_b`.
- **phylo_dep(1 + x | species)** correlated intercept+slope, Poisson,
  both shapes, `extract_Sigma(level = "phy")$Sigma` interleaved-block
  read (eval = FALSE; validation numbers quoted in prose).
- **spatial_indep(1 + x | coords)**, Poisson, both shapes,
  `extract_Sigma(level = "spatial")` field-SD read (eval = FALSE).
- Full-grid summary table (phylo/spatial x indep/latent/dep), family
  list `gaussian, poisson, nbinom1, nbinom2, Gamma, Beta, binomial,
  ordinal_probit`.

## Hard constraints honored

- **Dual format** on every structured cell (long + wide).
- **Light for pkgdown:** only small `phylo_indep` Gaussian + Poisson fits
  run at build time (a few seconds each, `n_sp` 25-30); the heavy
  `phylo_dep` / spatial cells at validation n are `eval = FALSE` with
  precomputed validation numbers in prose (mirrors `missing-data.Rmd`
  eval=FALSE + `joint-sdm.Rmd` small real fits).
- **Honest-uncertainty (#230):** `pdHess = FALSE` framed as an
  uncertainty warning not model death; `check_gllvmTMB()` shown; CI note
  distinguishing recovery bands from calibrated coverage; pointer to
  `simulate_unit_trait()` / `simulate_site_trait()` for the DGP scaffold.
- **`_pkgdown.yml` untouched** (owned by #447).

## Eval strategy per chunk

| Chunk | eval | why |
|---|---|---|
| `setup`, `sim-small`, `poisson-small` setup | TRUE | data gen, fast |
| `fit-small-long` | TRUE | small Gaussian `phylo_indep` fit, seconds |
| `fit-small-wide` | `requireNamespace("tidyr")` | wide reshape + fit |
| `recover-small`, `check-small` | TRUE | read fit_long |
| `poisson-small` fit | TRUE | small Poisson `phylo_indep` fit, seconds |
| `dep-poisson` | FALSE | heavy validation-n dep fit; syntax + extractor only |
| `spatial-poisson` | FALSE | needs mesh; heavy; syntax + extractor only |

Top-level `eval = requireNamespace("ape")`; the tree-building chunks need
`ape`.

## Checks

- Build-time chunk syntax cross-checked against the merged recovery tests
  (`test-phylo-indep-slope-gaussian.R`, `test-matrix-slope-phylo-dep.R`,
  `test-spatial-indep-slope-nongaussian.R`,
  `test-phylo-dep-slope-gaussian.R`): formula spelling, top-level
  `phylo_tree =`, `report$sd_b` (indep channel),
  `extract_Sigma(level = "phy")` / `level = "spatial"` all match tested
  usage.
- R is not available in this worktree environment, so chunks were not
  executed here. The build-time chunks reuse exactly the validated
  `phylo_indep` Gaussian/Poisson recipe from the tests at small n. The
  maintainer's pkgdown render is the execution gate (#230).

## Follow-up

- 🔴 **Needs you:** maintainer to render the article HTML and review
  (#230 / #347), then add the one-line `_pkgdown.yml` index entry below
  on approval (taxonomy PR #447 owns that file):

  ```yaml
  - text: "Structured random slopes for non-Gaussian traits"
    href: articles/random-slopes-nongaussian.html
  ```

- If the maintainer prefers, the stale "forthcoming" scope table /
  closing section in `random-regression-reaction-norms.Rmd` can be
  reconciled in a separate follow-up PR (it is a broad-rewrite touch, so
  it is deliberately not bundled here).
