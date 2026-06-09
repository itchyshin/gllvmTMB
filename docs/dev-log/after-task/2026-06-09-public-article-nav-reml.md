# Public article navigation and Gaussian REML note

Date: 2026-06-09  
Branch: `codex/public-article-nav-reml-2026-06-09`  
Maintainer request: merge the Gaussian REML PR, rebuild the site, clean the
article navigation, hide premature articles from the public path, and add a
focused REML note where it helps readers.

## What Changed

- Merged PR #469 (`feat: add Gaussian REML pilot`) into `main` before starting
  the docs slice.
- Narrowed the Articles dropdown to reader-ready pages:
  `morphometrics`, `model-selection-latent-rank`,
  `covariance-correlation`, `api-keyword-grid`, `response-families`,
  `fit-diagnostics`, `convergence-start-values`, `pitfalls`, and
  `missing-data`.
- Kept draft / technical / validation-dependent articles buildable but moved
  them under an explicit `Internal drafts and technical notes` article-index
  section rather than the public dropdown.
- Added a Gaussian-only `REML = TRUE` refit section to
  `vignettes/articles/model-selection-latent-rank.Rmd`, with the boundary tied
  to MIS-33.
- Marked `vignettes/articles/joint-sdm.Rmd` as Tier 3 / internal direct-link and
  changed its build policy to `eval = FALSE` so the full pkgdown site no longer
  stalls on a hidden public-style JSDM fit.

## Definition-Of-Done Check

1. **Implementation.** No engine implementation in this slice. The preceding
   Gaussian REML implementation is merged to `main` via PR #469
   (`a29c4a4`).
2. **Simulation recovery test.** Not applicable to the navigation/article slice.
   REML evidence remains `tests/testthat/test-gaussian-reml.R` / MIS-33 from
   PR #469.
3. **Documentation.** Updated `_pkgdown.yml`,
   `vignettes/articles/model-selection-latent-rank.Rmd`, and
   `vignettes/articles/joint-sdm.Rmd`.
4. **Runnable user-facing example.** The latent-rank article remains runnable and
   now includes long and wide Gaussian `REML = TRUE` refits. JSDM is explicitly
   internal/direct-link and light-build until it has a smaller reader-first
   public fixture.
5. **Check-log.** Added the paired entry in `docs/dev-log/check-log.md`.
6. **Review pass.** Rose / Pat / article-tier checks were applied locally:
   hidden articles are absent from the dropdown, public articles do not link to
   hidden slugs, and REML claims cite MIS-33 and name guarded regimes.

## Verification

- `pkgdown::build_article("articles/model-selection-latent-rank", lazy = FALSE,
  new_process = FALSE)` after `devtools::load_all()` wrote the touched article.
- `pkgdown::build_site(preview = FALSE, lazy = FALSE, install = TRUE,
  new_process = TRUE)` completed successfully with the current checkout
  temp-installed.
- `pkgdown::check_pkgdown()` returned `No problems found`.
- `git diff --check` returned clean.
- Rendered HTML scans confirmed that `joint-sdm.html`,
  `profile-likelihood-ci.html`, `troubleshooting-profile.html`,
  `cross-lineage-coevolution.html`, and
  `random-regression-reaction-norms.html` are absent from the dropdown on
  public and direct-link pages.
- Local server checks at `http://127.0.0.1:8123/` saw the new REML heading in
  `articles/model-selection-latent-rank.html` and the internal article-index
  section in `articles/index.html`.

## Not Run

- `devtools::test()` and `devtools::check()` were not rerun. This branch changes
  article navigation, article prose, and one internal article chunk policy; the
  full pkgdown build executed the public REML article path with the current
  package installed.

## Remaining Follow-Up

- If JSDM is promoted later, it needs a small public fixture, paired long/wide
  runnable calls, and a Pat/Darwin read before it returns to the dropdown.
- Cross-lineage and structured random-slope articles should stay internal until
  their reader path is simpler and the capability boundary is no longer doing
  most of the explanatory work.
