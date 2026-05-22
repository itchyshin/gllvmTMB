# After-task report: Remaining Sigma heatmap labels

**Date:** 2026-05-22  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Florence, Pat, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Use the new `plot_Sigma_heatmap()` label API at the remaining public article
heatmap call sites so the figures name the biological or modeling comparison
they show.

## Mathematical Contract

No model, extractor, covariance matrix, interval, or plotting geometry changed.
The edited calls only provide `title` and `subtitle` strings to existing
`plot_Sigma_heatmap()` outputs. The heatmaps remain point-estimate displays and
their captions still state that heatmaps do not display uncertainty intervals.

## Scope

- Added custom titles/subtitles to the Get Started correlation heatmap.
- Added custom titles/subtitles to the between- and within-individual
  behavioural-syndromes heatmaps.
- Added custom titles/subtitles to the between- and within-site
  functional-biogeography heatmaps.
- Added a custom title/subtitle to the joint-SDM shared-vs-total Sigma heatmap.

## Files Touched

- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/joint-sdm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-remaining-sigma-heatmap-labels.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is article-label polish only.
3. **Documentation:** four public pages were updated and rendered locally.
   Roxygen/Rd, NEWS, pkgdown navigation, and design docs were not touched.
4. **Runnable user-facing example:** all edited heatmap chunks rendered locally.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Florence checked visual fit; Pat checked reader-specific
   wording; Grace checked render/pkgdown/package gates; Rose checked stale
   wording and ledger completeness.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/gllvmTMB.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/joint-sdm.Rmd`
  -> completed without output.
- `for article in gllvmTMB articles/behavioural-syndromes articles/functional-biogeography articles/joint-sdm; do Rscript --vanilla -e "devtools::load_all(quiet = TRUE); pkgdown::build_article('$article', quiet = TRUE, new_process = FALSE)" || exit 1; done`
  -> all four pages rendered locally.
- Visual QA images inspected:
  - `pkgdown-site/articles/cor-matrix-1.png`
  - `pkgdown-site/articles/behavioural-syndromes_files/figure-html/inspect-1.png`
  - `pkgdown-site/articles/behavioural-syndromes_files/figure-html/inspect-w-1.png`
  - `pkgdown-site/articles/functional-biogeography_files/figure-html/heatmap-rb-1.png`
  - `pkgdown-site/articles/functional-biogeography_files/figure-html/heatmap-rw-1.png`
  - `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-sigma-1.png`
- Florence verdict:
  `PASS`. Titles and subtitles fit without clipping; captions still carry the
  no-interval caveat. The joint-SDM matrix remains dense, but the label now
  clarifies the shared-versus-total comparison without changing the geometry.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'First-model trait correlations|Between-individual syndrome correlations|Within-individual lability correlations|Between-site trait correlations|Within-site trait correlations|Shared and total latent-liability Sigma|title = ' vignettes/gllvmTMB.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/behavioural-syndromes.html pkgdown-site/articles/functional-biogeography.html pkgdown-site/articles/joint-sdm.html`
  -> edited labels are present in source and rendered HTML.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/gllvmTMB.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/joint-sdm.Rmd`
  -> one hit only: the existing article link slug
  `two-U-phylogeny` in `functional-biogeography.Rmd`; no stale notation was
  introduced by this slice.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains' vignettes/gllvmTMB.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/joint-sdm.Rmd`
- The exact label-presence scan was:
  `rg -n 'First-model trait correlations|Between-individual syndrome correlations|Within-individual lability correlations|Between-site trait correlations|Within-site trait correlations|Shared and total latent-liability Sigma|title = ' vignettes/gllvmTMB.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/behavioural-syndromes.html pkgdown-site/articles/functional-biogeography.html pkgdown-site/articles/joint-sdm.html`

## Tests Of The Tests

No new tests were added. This slice changes article calls only; the helper API
and label validation were already tested in
`tests/testthat/test-plot-covariance-tables.R`.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves figure specificity but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-27 remains the relevant Sigma heatmap helper row. This slice changes
  article labels only; no validation status moved.

## What Did Not Go Smoothly

No blocker. The stale-wording scan still sees the historical
`two-U-phylogeny` article slug in a link; that is not new notation or prose.

## Known Limitations And Next Actions

- Heatmaps remain point-estimate displays. Use `plot_correlations()` or
  `plot_Sigma_table()` when interval geometry matters.
- The short package check still reports the existing install warning and notes.
