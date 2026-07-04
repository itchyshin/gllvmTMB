# Cross-Package Validation Internal Gate

Date: 2026-06-19 01:45 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice aligned `vignettes/articles/cross-package-validation.Rmd` with the
article-council ledger. It treated the page as an internal comparator ledger,
not a public proof of the full cross-package validation surface.

## What Changed

- Added Tier 3 YAML and an internal article gate.
- Reframed the opening from a universal comparator claim to an
  evidence-specific ledger claim.
- Added an explicit scope boundary for live, partial, and planned comparator
  evidence.
- Replaced broad status wording in the validation matrix with row-specific
  statuses.
- Renamed the differentiator section to keep engine and inference claims tied
  to validation rows.
- Removed broad `gllvmTMB is correct` and `inference-complete` wording while
  preserving the concrete `glmmTMB` / `gllvm` comparison examples.
- Updated the article-council ledger row.

## Checks

- `gh pr list --state open`
  - only draft PR #489 on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/cross-package-validation", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - rendered `pkgdown-site/articles/cross-package-validation.html`.
- Rendered HTML scope review:
  - `cross_package_rendered_scope_review=PASS`.
- Figure asset check:
  - `pkgdown-site/articles/cross-package-validation_files/figure-html/gllvm-plot-1.png`
    exists at `1344 x 672`.

## Definition Of Done Status

- Implementation: not applicable; article/status slice only.
- Simulation or comparator recovery: not added here; this slice narrows claims
  until Phase 5.5 comparator evidence exists.
- Documentation: article and article-council ledger updated.
- Runnable example: existing live glmmTMB chunks rendered; optional gllvm
  section rendered in this environment and produced the comparison plot.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Rose/Fisher scope-boundary pass applied; broad comparator and
  interval claims remain blocked.

## Not Claimed

- No public promotion of `cross-package-validation`.
- No complete Phase 5.5 comparator ledger.
- No broad mixed-family, spatial, phylogenetic, missing-data, or interval
  comparator completion.
- No CI-08 / CI-10 promotion.
- No release readiness or scientific coverage completion.
