# After Task: Function Map and Cheatsheet

## Goal

Add one public Tier-2 gllvmTMB navigation article with an accessible task-based
HTML map, a runnable ordinary Gaussian route, and deterministic printable PDF
companions. Keep the Formula keyword grid as the grammar authority.

## Implemented

Added `function-map-cheatsheet.Rmd` and placed it in a dedicated pkgdown
Get started navigation menu. The page gives a task-first route from
preparation through fitting, fit health, rotation-invariant covariance
interpretation, target-specific uncertainty, and reporting. It includes an
original function-labelled loop illustration, links to two generated PDFs, and
adds reciprocal links from the vocabulary and Formula keyword-grid articles.

`dev/function-map-inventory.R` is the reviewed source for the primary task map.
`tools/build-function-cheatsheets.R` generates the one-page landscape map and
the one-page landscape A4 cheatsheet, rejecting unexported primary entries, compatibility
aliases on the first-use route, and any unclassified export.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, or generated
Rd file changed. The article teaches the existing ordinary decomposition
`Sigma = Lambda Lambda^T + Psi`: ordinary `latent()` includes Psi by default;
source-specific `*_latent()` requires `unique = TRUE` for its diagonal
companion; `indep()` is the new standalone diagonal spelling.

## Files Changed

- `_pkgdown.yml`
- `vignettes/articles/function-map-cheatsheet.Rmd`
- `vignettes/articles/gllvm-vocabulary.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `dev/function-map-inventory.R`
- `tools/build-function-cheatsheets.R`
- `pkgdown/assets/cheatsheets/gllvmTMB-function-map.pdf`
- `pkgdown/assets/cheatsheets/gllvmTMB-function-cheatsheet.pdf`
- `vignettes/articles/figures/gllvmTMB-function-map-illustration.png`
- `docs/dev-log/check-log.md`
- this report

No README, NEWS, ROADMAP, design document, roxygen, or generated Rd update was
required because package behaviour and syntax did not change.

## Checks Run

- `Rscript --vanilla tools/build-function-cheatsheets.R` — PASS; both PDFs
  generated without warnings.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/function-map-cheatsheet", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` — PASS; the simulated fit, `check_gllvmTMB()`, and `extract_Sigma()` executed.
- Focused builds of `articles/gllvm-vocabulary` and `articles/api-keyword-grid`
  — PASS; reciprocal links rendered.
- Rendered-site grep for the new article, its Get started navbar entry,
  entry, function-map image, reciprocal links, and both downloads — PASS; both
  built PDF assets were non-empty.
- `pdfinfo`, `pdftotext`, and 150-dpi page render inspection — PASS; map is one
  landscape page and cheatsheet is one landscape A4 page with all six task
  routes visible and no clipped text.
- `git diff --check` — PASS.
- `pkgdown::check_pkgdown()` — pre-existing FAIL: `_pkgdown.yml` already omits
  `kernel_scalar`, `reml_bridge`, and `scalar` from the reference index. This
  task does not touch those topics; the failure is recorded rather than repaired
  out of scope.

## Tests Of The Tests

The generator is an executable documentation guard: it fails if a primary-map
entry is no longer exported, if the documented `predict()`/`simulate()` S3
methods disappear, or if a compatibility alias enters the primary path. The
article render executes the small simulation-fit-extract route and would fail on
invalid current syntax. The rendered-HTML grep would catch a lost navbar route,
reciprocal link, or missing download.

## Consistency Audit

Rose verdict: PASS with one repository baseline WARN. The new article keeps
`traits(...)` on the wide-data path, passes `trait = "trait"` in the executed
long call, routes family selection to the family article, labels `meta_V()` as
a separate workflow, and avoids a generic profile-CI promise. Its scope boundary
maps IN claims to FG-01--FG-04, FAM-01, EXT-01, and EXT-05; source/family/
interval extensions remain explicitly partial. The pre-existing reference-index
omissions prevent a green global `pkgdown::check_pkgdown()` but do not involve
this article or its new navigation entry.

## What Did Not Go Smoothly

The first A4 cheatsheet layout tried to fit all six cards on one page and
overlapped text. A first repair used sparse two-panel pages; it was then
replaced by a compact single-page landscape 2 x 3 quick-reference grid. The
160-dpi render was re-inspected. `pkgdown::check_pkgdown()` also exposed three
unrelated missing reference topics already absent from the index.

## Team Learning

Pat required one navigation surface rather than three competing beginner
artefacts; the HTML page is therefore primary and the PDFs are supplements.
Boole required the Formula keyword grid to remain the sole grammar authority.
Rose required exact scope fencing, long/wide syntax accuracy, and the baseline
pkgdown failure to be reported rather than silently repaired. Jason required
the primary map to distinguish current reader routes from compatibility and
unsupported exports.

## Known Limitations

The inventory is hand-reviewed, not a claim that every export is first-use
appropriate. The visual does not certify family, structured-source, or interval
coverage beyond the linked article boundaries. `pkgdown::check_pkgdown()` stays
red until the existing `kernel_scalar`, `reml_bridge`, and `scalar` reference
index omissions are addressed in a separate slice.

## Next Actions

Run the normal PR review and deploy cycle; verify the final public URL and both
PDF downloads after pkgdown publishes. Treat reference-index repair as a
separate documentation-maintenance task.

**Roadmap tick**: N/A; this adds a navigation aid and does not alter a roadmap
capability/status row.

**GitHub issue ledger**: inspected #230 (article surface reset and user-first
tooling gate) and #347 (article completion/public learning path). Both remain
open; this slice advances their documentation surface without closing either.
