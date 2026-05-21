# After-task report: report-ready Sigma table and wide-first landing page

**Date:** 2026-05-21  
**Agent:** Ada / Codex  
**Branch:** `codex/symbol-syntax-alignment-2026-05-21`

## Implemented claim

`gllvmTMB` now has a report-ready `extract_Sigma_table()` helper for
Sigma / Psi / R point-estimate tables, and the landing page now presents
wide `traits(...)` data as the first user-facing path while preserving the
long stacked-trait equivalent beside it.

## Roles engaged

- **Ada:** kept the slice bounded and stopped the stale long-running check
  when the maintainer redirected the lane.
- **Emmy:** checked the extractor return-value shape and pkgdown export
  parity.
- **Florence:** kept the table contract plot-ready for correlation heatmaps
  and ellipse plots.
- **Pat:** pushed the landing page toward the data shape most applied users
  already have on disk.
- **Rose:** checked stale wording, scope-boundary row IDs, long/wide example
  consistency, and generated documentation parity.

No spawned subagents were running.

## Files touched

- `R/extract-sigma-table.R`
- `R/plot-gllvmTMB.R`
- `tests/testthat/test-extract-sigma-table.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `README.md`
- `vignettes/articles/morphometrics.Rmd`
- `NEWS.md`
- `_pkgdown.yml`
- `NAMESPACE`
- `man/extract_Sigma_table.Rd`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`

Example files touched and verified: `README.md`,
`vignettes/articles/morphometrics.Rmd`,
`R/extract-sigma-table.R`, and `man/extract_Sigma_table.Rd`.

## Mathematical / API contract

The helper is a table view over `extract_Sigma()`, not a second covariance
implementation. For a requested level and component it returns entries from:

```text
Sigma = Lambda Lambda^T + Psi
```

For `part = "unique"`, the table reports `Psi` diagonal entries. For
`measure = "correlation"`, it reports `R = cov2cor(Sigma)` and only permits
`part = "total"`. Interval columns are placeholders (`NA`, `none`) because
interval estimation remains the job of `extract_correlations()` and
`bootstrap_Sigma()`.

Validation row: `EXT-18`, with the underlying Sigma evidence inherited from
`EXT-01` and mixed-family row `MIX-03`.

## Tests and checks

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`  
  Result: wrote `NAMESPACE` and `man/extract_Sigma_table.Rd`.
- `tail -8 man/extract_Sigma_table.Rd && grep -c '^\\keyword' man/extract_Sigma_table.Rd`  
  Result: expected `\seealso{...}` ending; keyword count `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table|plot-gllvmTMB")'`  
  Result: 164 passes, 0 failures, 0 warnings, 0 skips.
- README wide-first smoke test with `traits(bill_length, body_mass, wing_length)`  
  Result: optimizer convergence `0`, communality and Fisher-z correlations printed.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics", new_process = FALSE)'`  
  Result: rebuilt `articles/morphometrics.html`.
- `Rscript --vanilla -e 'pkgdown::build_home()'`  
  Result: rebuilt the pkgdown landing page.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`  
  Result: `No problems found.`
- `git diff --check`  
  Result: clean.

`devtools::check(args = "--no-manual")` was started before the maintainer
redirected the work to the landing-page pivot. It was still silent after a
long run and was killed. It did not finish and is not counted as evidence.

## Stale wording and Rose gate

Exact scans run:

```sh
rg -n "Long data are canonical|long data are canonical|Data shapes: long or wide|gllvmTMB_wide\\(Y, \\.\\.\\.\\) was removed|removed in 0\\.2\\.0|diag\\(S\\)|diag\\(s\\)|diag\\(U\\)|\\\\bf S|S_B|S_W|profile-likelihood default|profile default" README.md NEWS.md R/extract-sigma-table.R man/extract_Sigma_table.Rd vignettes/articles/morphometrics.Rmd docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md pkgdown-site/index.html
rg -n "gllvmTMB\\(" README.md R/extract-sigma-table.R man/extract_Sigma_table.Rd vignettes/articles/morphometrics.Rmd NEWS.md docs/design/06-extractors-contract.md
rg -n 'Most readers|Data shapes: wide or long|traits\\(bill_length|One `gllvmTMB\\(\\)`' pkgdown-site/index.html README.md
```

Results: no stale long-first, removed-wrapper, legacy notation, or
profile-default wording remained in touched public surfaces. Touched
long-format calls include `trait = "..."`; wide-format calls use
`traits(...)` without a `trait =` argument.

## Convention-change cascade

No formula grammar, argument name, keyword default, or function signature was
changed. The PR does add a new exported helper, so the export cascade was:

- roxygen block added in `R/extract-sigma-table.R`;
- `man/extract_Sigma_table.Rd` regenerated;
- `NAMESPACE` regenerated;
- `_pkgdown.yml` reference entry added;
- `NEWS.md` entry added with IN / PARTIAL / PLANNED scope wording;
- `docs/design/06-extractors-contract.md` and
  `docs/design/35-validation-debt-register.md` updated.

## Remaining risk

`extract_Sigma_table()` is point-estimate only. Florence-grade significance
annotations for ellipses or heatmaps still need a future interval-aware table
join. Full `devtools::check()` remains not rerun after this slice.

## Next safest action

Keep the next slice narrow: either add an interval-aware join from
`extract_correlations()` into `extract_Sigma_table()` output, or use the new
table to replace remaining hand-indexed Sigma/correlation code in
Morphometrics and the covariance article.
