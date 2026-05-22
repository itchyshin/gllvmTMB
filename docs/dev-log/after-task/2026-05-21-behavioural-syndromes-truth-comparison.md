# After-task report: Behavioural-syndromes truth comparison

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose, Emmy  
**Spawned subagents:** none

## Task Goal

Replace the behavioural-syndromes article's hand-indexed between-individual
correlation recovery plot with the report-ready Sigma comparison helper.

## Mathematical Contract

No likelihood, formula grammar, family, NAMESPACE, or generated Rd changed. The
article still compares the fitted between-individual correlation matrix to the
known DGP:

```r
Sigma_B = Lambda_B Lambda_B^T + diag(psi_B)
error = estimate - truth
```

`plot_Sigma_comparison(style = "scatter")` displays those errors. The vertical
segments are comparison residuals, not confidence intervals.

## Scope

- Replaced manual `extract_Sigma()` / `cov2cor()` / lower-triangle indexing in
  `vignettes/articles/behavioural-syndromes.Rmd`.
- Used `compare_Sigma_table()` to build lower-triangle correlation rows.
- Used `plot_Sigma_comparison(style = "scatter")` for the recovery figure.
- Shortened scatter comparison labels in `plot_Sigma_comparison()` so default
  article-sized renders do not clip the title, subtitle, or caption.
- Added regression expectations for the scatter label contract.

## Files Touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-behavioural-syndromes-truth-comparison.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice changes an article
   recovery display and plot labels; it does not add an estimator, likelihood,
   family, or simulation layer.
3. **Documentation:** the behavioural-syndromes article source was updated. No
   roxygen, Rd, or pkgdown navigation changed.
4. **Runnable user-facing example:** the rendered article runs the DGP, fit,
   comparison table, and comparison figure.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked that the article now uses the same helper as
   the other recovery articles, Florence checked the rendered figure for
   clipping and row/legend spacing, Fisher checked error-versus-interval
   wording, Grace checked local commands, Rose checked stale manual scaffolding,
   and Emmy checked that the plot helper contract stayed narrow.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R vignettes/articles/behavioural-syndromes.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  -> 130 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/behavioural-syndromes_files/figure-html/recovery-sigma-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'Sigma_B_hat|true_corr|hat_corr|df_sigma|Optional: compare Sigma_B|Off-diagonal indices|True.*Sigma|Recovery of between-individual trait correlations' vignettes/articles/behavioural-syndromes.Rmd`
  -> no hits.
- `rg -n 'compare_Sigma_table\\(|plot_Sigma_comparison\\(|Correlation estimates vs truth|Segments are errors, not CIs|fig.width = 7.2' vignettes/articles/behavioural-syndromes.Rmd R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> helper calls and label expectations are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|estimate-vs-truth article figures remain future|plotting geometry remains" vignettes/articles/behavioural-syndromes.Rmd R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  -> no hits.

## Tests Of The Tests

The new label expectations catch the exact visual-QA failure from this slice:
scatter comparison labels must stay short enough for article renders. The
article render exercises the real DGP, fit, comparison table, and comparison
plot.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  advances the hidden/technical article cleanup but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new advertised capability was added. The article now reuses the existing
Sigma truth-comparison helper surface recorded under EXT-25 / EXT-26 in
`docs/design/35-validation-debt-register.md`.

## What Did Not Go Smoothly

The first rendered scatter figure clipped the title and subtitle at the default
6 x 4 inch article size. Shortening the helper labels alone was not enough; the
article chunk also needed a slightly wider device for a square correlation
panel plus legend and caption.

## Known Limitations And Next Actions

- Several hidden/technical articles still build covariance, correlation, or
  loading displays manually.
- The next narrow cleanup target is likely `functional-biogeography.Rmd`, which
  still has hand-built cross-trait correlation heatmaps.
