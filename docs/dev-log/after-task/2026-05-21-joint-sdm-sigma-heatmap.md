# After-task report: Joint-SDM Sigma heatmap

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Florence, Fisher, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Replace the joint-SDM article's printed shared/total Sigma matrices with a
helper-backed heatmap and align its long-format fit call with the explicit
`trait = "trait"` convention.

## Mathematical Contract

No likelihood, formula grammar, family, export, or extractor contract changed.
The article still contrasts the shared GLLVM covariance with the total
latent-liability covariance:

```r
Sigma_shared = Lambda Lambda^T
Sigma_total = Sigma_shared + (pi^2 / 3) I
```

The heatmap displays point estimates from `extract_Sigma_table()`. It does not
display uncertainty intervals.

## Scope

- Added `trait = "trait"` to the long-format JSDM fit.
- Replaced printed `Sigma_shared` / `Sigma_total` matrices with
  `extract_Sigma_table()` rows and `plot_Sigma_heatmap()`.
- Kept the explanatory prose that the total matrix differs on the diagonal by
  the fixed logistic link residual.

## Files Touched

- `vignettes/articles/joint-sdm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-joint-sdm-sigma-heatmap.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article display cleanup.
3. **Documentation:** the joint-SDM article source was updated and rendered
   locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the rendered article runs the fit, table
   extraction, and heatmap.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked article flow, Florence checked the rendered
   heatmap, Fisher checked that covariance-scale interpretation remains
   explained in prose, Grace checked local commands, and Rose checked stale
   printed-matrix scaffolding plus explicit `trait = "trait"`.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/joint-sdm.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/joint-sdm", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Visual QA image inspected:
  `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-sigma-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n 'Sigma_shared <-|Sigma_total\\s*<-|round\\(Sigma_shared|round\\(Sigma_total|list\\(Sigma_shared|plot_Sigma_heatmap\\(|Sigma_shared_rows|Sigma_total_rows|trait\\s*=\\s*"trait"' vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/joint-sdm.html`
  -> printed matrices are gone; helper-backed source/rendered HTML and explicit
  `trait = "trait"` are present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|estimate-vs-truth article figures remain future|plotting geometry remains" vignettes/articles/joint-sdm.Rmd`
  -> no hits.

## Tests Of The Tests

No new test file was added. The slice relies on the already-tested EXT-27
helper plus local article rendering and visual QA of the generated covariance
heatmap.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves one article but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice reuses the existing EXT-27 helper.

## What Did Not Go Smoothly

The covariance heatmap is naturally dominated by large diagonal/liability-scale
entries. This is acceptable here because the visible labels and adjacent prose
make the diagonal link-residual addition the explicit teaching point.

## Known Limitations And Next Actions

- The heatmap is point-estimate only; interval-bearing correlation summaries
  remain in the preceding `extract_correlations()` output.
- Continue scanning remaining articles for printed covariance/correlation
  matrices and long-format calls missing `trait = "trait"`.
