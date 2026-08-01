# After-task report: compact spatial-guide output

## 1. Goal

Repair the reader-facing `spatial-models` article after visual inspection
showed that printing the complete `gllvmTMBmesh` object produced a very long
coordinate dump and buried the later `spde` components. Also demonstrate the
already-supported `spatial_latent()` and `spatial_dep()` modes without adding
another long output block.

## 2. Implemented

- Replaced bare `mesh` printing with a six-row component/size table covering
  `loc_xy`, mesh vertices, `A_st`, and all three SPDE matrices (`c0`, `g1`,
  `g2`).
- Hid the table-construction machinery so the public page shows the short
  `make_mesh()` call, the summary, and `plot(mesh)`.
- Added runnable Gaussian `spatial_latent(d = 2, unique = TRUE)` and
  `spatial_dep()` fits beside the existing `spatial_indep()` fit.
- Added a compact convergence/log-likelihood/AIC comparison; all three fits
  converged with code 0 in the rendered teaching fixture.
- Suppressed the duplicated eleven-row diagnostic return while retaining the
  runnable `check_gllvmTMB()` call and link to the diagnostics guide.

## 3a. Decisions and Rejected Alternatives

This is an article-only display and teaching repair. It does not add a print
method, change the mesh object contract, promote broader spatial validation,
or alter any likelihood. The full mesh remains inspectable through its named
components. The correlated-mode comparison is explicitly labelled as one
teaching dataset, not a recovery or model-selection study.

## 4. Files Touched

- `vignettes/articles/spatial-models.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-01-spatial-guide-output-compaction.md`

No R source, TMB source, tests, generated Rd, NAMESPACE, README, NEWS, or
pkgdown navigation file changed.

## 5. Checks Run

```sh
Rscript --vanilla -e 'pkgdown::build_article("articles/spatial-models", lazy = FALSE, new_process = TRUE, quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE, quiet = TRUE)'
Rscript --vanilla -e 'devtools::test(filter = "article-prescribed-calls|mesh|utm-conversions")'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
rg -n "try multiple starts|no loading rotation" pkgdown-site/articles/spatial-models.html
git diff --check
```

Results: focused and complete article renders PASS; focused tests PASS (60
expectations, no failures, warnings, or skips); pkgdown consistency PASS; stale
verbose diagnostic output absent; diff hygiene PASS.

Full package check: PASS in 15m01.1s with 0 errors, 0 warnings, and 2
environment notes (remote clock verification and `xcrun_db` detritus).

The rendered mesh and spatial-mode sections were inspected at 1500 x 1200 and
1500 x 2400 viewports. The mesh section fits in a normal viewport and the
latent/dep comparison table is readable without horizontal scrolling.

## 6. Tests of the Tests

The article was rendered in a fresh R process with execution enabled through
the installed `fmesher` dependency. This exercised all four fitted objects
(`fit_long`, `fit_wide`, `fit_latent`, and `fit_dep`) rather than checking only
source text. The prescribed-call test also parsed the article's public calls.

## 7a. Issue Ledger

No capability issue is closed or advanced. SPA-01 remains covered for the
helper/ingestion contract; FG-13 and SPA-02 remain partial for the broader
spatial keyword-by-family and correlated-field evidence. No new issue is
needed for this presentation defect.

## 8. Consistency Audit

Rose pre-publish verdict: PASS. Long-format calls retain explicit
`trait = "trait"`; function and argument names match the live API; the
SPA-01/FG-13/SPA-02 evidence boundary remains visible; no deprecated syntax or
new capability claim was introduced. The page still distinguishes independent
code authorship from the sdmTMB courtesy acknowledgement.

## 9. What Did Not Go Smoothly

The first compact table used dollar signs inside plain table-cell strings.
Pandoc interpreted them as math delimiters and broke the SPDE rows. The labels
were changed to plain `c0`, `g1`, and `g2`, while exact accessors such as
`mesh$spde$c0` remain in code-formatted prose. A second eye pass then found and
removed the neighbouring verbose diagnostics return.

## 10. Known Residuals

The article still shows full runnable calls for the latent and dependent
spatial modes; this is intentional teaching content. It does **not** cover
directional anisotropy, barriers, spatiotemporal fields, non-Gaussian recovery,
or calibrated spatial-correlation inference. A package-wide concise
`print.gllvmTMBmesh()` method is not part of this repair.

## 11. Team Learning

Reader-visible rendering is the acceptance surface for tutorials. A valid R
object can still be a poor article output, and markdown table cells need an eye
check when they contain R's dollar accessor. Compact summaries should expose
the contract a reader needs—component presence and dimensions—rather than raw
sparse contents.

## 12. Cross-Product Coverage

This repair covers only the public gllvmTMB spatial article. It changes no
drmTMB implementation and creates no new dependency or provenance relationship
with sdmTMB. It **does NOT cover** a package-wide mesh print method, new spatial
engine behaviour, or any cross-package code reuse.
