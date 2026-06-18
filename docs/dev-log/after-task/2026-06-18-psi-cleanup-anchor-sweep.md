# After-Task Report: Psi Cleanup Anchor Sweep

**Date:** 2026-06-18 09:55 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Scope:** first implementation slice of the master finish plan: public
`unique()` / Psi language, coevolution Option B guard wording, dashboard, and
evidence trail.

Guard:

```text
PR green != bridge complete != release ready != scientific coverage passed
```

## What Changed

- Added
  `docs/dev-log/audits/2026-06-18-master-finish-plan-psi-coevolution-ledger.md`
  with the full Psi/coev/article/bridge/release roadmap for this slice.
- Updated `vignettes/articles/api-keyword-grid.Rmd` so `indep()` is the public
  standalone diagonal recommendation and `unique()` is framed as explicit
  `Psi`.
- Updated `vignettes/articles/covariance-correlation.Rmd` title and opening
  boundary from broad "when you need unique" to explicit Psi in
  `latent() + unique()`.
- Updated `vignettes/articles/model-selection-latent-rank.Rmd` so the `d = 0`
  diagonal baseline uses `indep()`, while `d >= 1` candidates keep `unique()`
  as the explicit Psi component.
- Updated `vignettes/articles/cross-lineage-coevolution.Rmd` so the current
  coevolution workflow centers `kernel_latent()` and `extract_Gamma()`, while
  `kernel_unique()` is described as the Gaussian fixture's optional Psi
  component, not Paper 2 Option B.
- Updated `docs/dev-log/dashboard/status.json` and
  `docs/dev-log/dashboard/sweep.json` with a separate Psi cleanup card/evidence
  entry.

## Definition Of Done

1. **Implementation.** Completed as documentation/source edits only. No R, TMB,
   parser, likelihood, extractor, or validation-row status code changed.
2. **Simulation recovery.** Not applicable to this slice because no likelihood,
   family, keyword implementation, or estimator changed. No row was promoted.
3. **Documentation.** Four article sources plus the master ledger, dashboard,
   check-log, and this after-task report were updated. No roxygen or Rd files
   were touched.
4. **Runnable user-facing example.** The rank-selection article's runnable
   `d = 0` baseline now uses `indep()` and rendered successfully through
   `pkgdown::build_articles(lazy = FALSE)`.
5. **Check-log.** `docs/dev-log/check-log.md` records commands, stale scans,
   render evidence, and skipped commands.
6. **Review pass.** Boole reviewed the formula-language boundary; Rose guarded
   stale claims and validation-row separation; Fisher guarded rho/interval and
   scientific-coverage claims; Pat guarded first-reader article language;
   Grace owned pkgdown/check evidence. Gauss and Noether were not invoked for
   an active likelihood review because no TMB/math implementation changed.

## Commands And Evidence

- Pre-edit lane check:
  - `PATH="/opt/homebrew/bin:$PATH" gh pr list --state open --json number,title,headRefName,isDraft,updatedAt,url`
    -> only draft PR #489 open.
  - `git log --all --oneline --since="6 hours ago"`
    -> recent overlaps were the current mission-control/article lane.
  - `git diff --check`
    -> clean before edits.
- Memory grounding:
  - `rg -n "gllvmTMB|coevolution|unique|kernel" /Users/z3437171/.codex/memories/MEMORY.md`
    -> confirmed the one-kernel coevolution point-estimate boundary and
    validation-led public-story rule.
- Stale scan:
  - `rg -n 'standalone \`unique\\(\\)\`|standalone unique|unique\\(\\).*preferred diagonal|when you need \`unique\\(\\)\`|model = .*unique only|rank_label.*unique|kernel_unique\\(\\).*source of \`Gamma\`|kernel_unique\\(\\).*central' vignettes vignettes/articles docs/dev-log/audits`
    -> hits were only the new guard/ledger text and intentional
    covariance-correlation boundary.
- Render/check:
  - `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
    -> completed successfully and rendered the touched articles.
  - `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
    -> `No problems found.`
  - `rg -n 'explicit Psi|standalone marginal-only|diagonal indep|True Paper 2 Option B|kernel_unique\\(\\).*explicit \`Psi\`|Gamma_shape' pkgdown-site/articles/api-keyword-grid.html pkgdown-site/articles/covariance-correlation.html pkgdown-site/articles/model-selection-latent-rank.html pkgdown-site/articles/cross-lineage-coevolution.html`
    -> rendered HTML contains the intended wording.
- Cleanup:
  - Removed build-generated untracked files
    `vignettes/cor-matrix-1.png`, `vignettes/cor-plot-1.png`,
    `vignettes/ord-1.png`, and `vignettes/residual-qq-1.png`.

## Deliberately Not Run

- No `devtools::document()`, full `devtools::test()`,
  `devtools::check(args = "--no-manual")`, release `--as-cran`, issue mutation,
  GLLVM.jl mutation, push, validation-row promotion, parser change, or TMB
  change.

## Next Safest Action

Continue the article cleanup one decision at a time. The next slice should
audit `response-families.Rmd`, `joint-sdm.Rmd`, and binary/ordinal wording for
implicit link residuals versus explicit Psi before moving to phylogenetic,
animal, and advanced-method articles.
