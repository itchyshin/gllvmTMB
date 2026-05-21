# After-task: covariance edge-case example object

**Date:** 2026-05-21
**Branch:** `codex/article-audit-2026-05-20`
**Issue ledger:** #230; #228 inspected and left parked
**Slice:** 9
**Active reviewers:** Ada, Pat, Boole, Curie, Fisher, Grace, Rose.
**No spawned subagents were running in this slice.**

## Goal

Move the covariance/correlation demonstration from inline simulation code to a
tested prepared object, then render the affected public HTML for maintainer
review.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
or parser contract changed.

The teaching fixture uses the existing Gaussian `latent() + unique()`
decomposition:

\[
\Sigma = \Lambda\Lambda^\top + \Psi,
\]

where \(\Psi = \mathrm{diag}(\psi)\). The edge case compares this recommended
fit with a latent-only fit where \(\Psi\) is absent. The fitted quantity used
for the public claim is the rotation-invariant covariance/correlation matrix,
not raw loadings.

## Implemented

- Added `data-raw/examples/make-covariance-edge-cases-example.R`.
- Generated `inst/extdata/examples/covariance-edge-cases-example.rds`.
- Added `tests/testthat/test-example-covariance-edge-cases.R`.
- Updated `vignettes/articles/covariance-correlation.Rmd` to load the object,
  show long and wide formulas, fit latent-only and `latent() + unique()`
  models, and compare the correlation edge case against known truth.
- Updated `vignettes/articles/pitfalls.Rmd` to use the same object for the
  trait-factor-order pitfall.
- Updated `docs/design/52-example-object-contract.md`, `ROADMAP.md`, and
  `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`.
- Updated `_pkgdown.yml` after rendered HTML showed hidden pages still exposed
  through the generated Articles dropdown.
- Hid local source-tree fallback code from rendered article HTML while keeping
  source-tree renders functional.

## Files Changed

- `_pkgdown.yml`
- `ROADMAP.md`
- `docs/design/52-example-object-contract.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-covariance-edge-case-example.md`
- `data-raw/examples/make-covariance-edge-cases-example.R`
- `inst/extdata/examples/covariance-edge-cases-example.rds`
- `tests/testthat/test-example-covariance-edge-cases.R`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/morphometrics.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/pitfalls.Rmd`

No exported function documentation or generated `man/*.Rd` files changed.

## Tests And Checks

- `Rscript --vanilla data-raw/examples/make-covariance-edge-cases-example.R`
  - Saved `inst/extdata/examples/covariance-edge-cases-example.rds`.
- `Rscript --vanilla -e 'devtools::test(filter = "example-covariance-edge-cases")'`
  - Passed: 32 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'devtools::test(filter = "example-(morphometrics|covariance-edge-cases)")'`
  - Passed: 58 tests, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed: `No problems found.`
- `git diff --check`
  - Clean.
- Source-loaded visible render:
  `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); arts <- c("gllvmTMB", "articles/morphometrics", "articles/covariance-correlation", "articles/pitfalls"); for (a in arts) { message("Building ", a); pkgdown::build_article(a, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = TRUE) }; pkgdown::build_articles_index(pkg = ".")'`
  - Passed; emitted only pre-existing `../logo.png` warnings.
- Local HTTP server:
  `python3 -m http.server 8765 --bind 127.0.0.1 --directory pkgdown-site`
  - Served updated review pages with HTTP 200.

## Tests Of The Tests

The new test file is a boundary/feature-combination test:

- It checks the object schema and stable `system.file()` path.
- It checks long and wide data shapes agree.
- It fits the recommended long and wide formulas and requires identical
  log-likelihoods.
- It checks optimizer convergence and gradient health.
- It compares fitted \(\Sigma\) with known truth.
- It fits the latent-only edge case and verifies that correlation error is
  substantially larger than for `latent() + unique()`.

This test would catch stale formulas, broken extdata paths, long/wide grammar
drift, trait-order mistakes, and a demonstration where the advertised
`unique()` effect disappears.

## Consistency Audit

Exact scans are recorded in `docs/dev-log/check-log.md`. Key verdicts:

- Hidden article links: no hidden-page hrefs in the rendered public pages or
  article index after the `_pkgdown.yml` fix.
- Hidden dropdown: no generated hidden-article navbar remained; only intentional
  "Under audit" explanatory prose remains.
- Fallback code: no source-tree fallback plumbing appears in rendered HTML.
- Notation: no stale `S`, `S_B`, `S_W`, `s_unit`, or `diag(s_)` hits in touched
  source files.
- DGP location: the covariance article no longer has inline simulation code;
  simulation lives in the generator.
- Fit calls: covariance article and tests show explicit long `trait =` calls
  and wide `traits(...)` calls; Pitfalls still has long-form diagnostics and
  remains under HTML review.

## Reviewer Notes

Ada: The slice stayed infrastructure-first: object, test, article wiring, then
rendered HTML.

Pat: Covariance/correlation is easier to read. The article now starts from a
named behavioural example instead of asking readers to parse a simulation block.

Boole: Long and wide formulas are stored in the object and shown in the
article; the wide form uses `traits(...)`.

Curie: The fixture has deterministic truth and an explicit edge-case test for
correlation inflation.

Fisher: The claim is modest: one Gaussian edge-case fixture demonstrates why
`unique()` matters for correlations. It is not a broad coverage claim.

Grace: `pkgdown::check_pkgdown()` passes, targeted renders pass, and the
navbar fix removes hidden article exposure from generated HTML.

Rose: Rendered HTML caught two process failures that source review alone missed:
hidden pages exposed through pkgdown navigation and local fallback code printed
to users.

## Roadmap Tick

`ROADMAP.md` now lists slice 9, "Covariance edge-case example object", with the
done condition tied to the shipped object, article wiring, and long/wide plus
`unique()`-effect tests.

## GitHub Issue Ledger

- #230 inspected: still open and remains the owner issue for article reset.
- #228 inspected: still open; intentionally left parked until diagnostic
  terminology, tables, and plot semantics are stable.
- #230 commented with slice update:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4507500076>.

## Known Limitations

- Pitfalls is still not a polished Tier-1 article. It uses the new object for
  one pitfall, but several diagnostic examples remain long-form and need a
  later systematic HTML/prose review. Maintainer visual review on 2026-05-21
  agreed that Pitfalls' current topic mix feels random and should be returned
  to later as a more coherent diagnostic guide.
- The covariance heatmap is functional but not Florence-reviewed to final
  visual standard.
- Full `devtools::test()` and `devtools::check()` were not run for this
  docs/data-fixture slice.
- The clean new-process render can load an older installed `gllvmTMB` on this
  machine; source-loaded rendering was used for local HTML review.

## Next Safe Slice

Keep Get Started, Morphometrics, and Covariance/correlation in the current
public-review set. Return to Pitfalls later as a focused rewrite rather than
blocking the example-object infrastructure work.
