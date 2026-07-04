# After-Task Report: animal-model Reader Scope and Diagnostics

Date: 2026-06-19 01:07 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Continue article-council slice 5 after `behavioural-syndromes` and
`phylogenetic-gllvm` by removing the "untriaged" blocker from the
`animal-model` draft without promoting it publicly.

## Files Touched

- `vignettes/articles/animal-model.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-animal-model-reader-scope-diagnostics.md`

## What Changed

- Added explicit Tier 3/internal YAML and an internal article gate.
- Added a reader/scope bridge mapping four quantitative-genetic questions to
  model objects, code sections, known simulation truth, and readouts.
- Added explicit scope boundary language for `ANI-01`--`ANI-12`, `ANI-09`,
  `ANI-10`, and `DIA-08`.
- Added a rendered `diagnostic_table()` block covering the heritability,
  bivariate G, rank-1 G, and reaction-norm examples.
- Recorded that `animal_unique()` remains source-specific explicit genetic
  `Psi` compatibility syntax in paired decompositions; standalone diagonal
  teaching remains `animal_indep()`.

## Verification

- Pre-edit lane check:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> no recent commits.
- Article render:
  - `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/animal-model", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Result: rendered `pkgdown-site/articles/animal-model.html`.
- Rendered diagnostic review:
  - `animal_rendered_diagnostic_review=PASS`.
  - Rendered HTML contains `PASS` rows for `optimizer_convergence`,
    `max_gradient`, `sdreport`, and `pd_hessian` across the heritability,
    bivariate_G, rank1_G, and reaction_norm examples.
- Figure asset review:
  - `animal_png_asset=PASS`.
  - `pkgdown-site/articles/animal-model_files/figure-html/G3-correlation-1.png`
    exists with dimensions `1113x921`.
  - Florence verdict: pass as a point-estimate genetic-correlation heatmap
    with readable labels, an appropriate correlation scale, and an explicit
    no-interval caption.

## Still Not Claimed

- No public promotion of `animal-model`.
- No cross-package agreement with MCMCglmm, WOMBAT, or ASReml.
- No broader non-Gaussian calibration claim.
- No `unique()` API removal.
- No `kernel_unique()` expansion for Paper 2 multi-kernel coevolution.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Safest Action

Run rendered/browser review for the three biological candidate articles, or
continue the serial article-council plan with the advanced methods block if
browser tooling remains unavailable.
