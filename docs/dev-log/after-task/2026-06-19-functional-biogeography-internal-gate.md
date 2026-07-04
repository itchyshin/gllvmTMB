# Functional Biogeography Internal Gate

Date: 2026-06-19 01:51 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice aligned the final capstone `functional-biogeography` draft with
current M3 / CI evidence. It did not change model code or promote the article.

## What Changed

- Added Tier 3 YAML.
- Strengthened the internal capstone gate.
- Updated the opening validation wording to say ordinary default-`latent()`
  covariance is covered, while explicit `unique()` remains compatibility
  syntax where shown.
- Kept CI-08 / CI-10 partial in the article gate.
- Replaced the remaining `publication-grade` phrase with
  `most defensible point-estimate teaching fit`.
- Updated the article-council ledger row.

## Checks

- `gh pr list --state open`
  - only draft PR #489 on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/functional-biogeography", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - rendered `pkgdown-site/articles/functional-biogeography.html`.
- Rendered HTML scope review:
  - `functional_biogeography_rendered_scope_review=PASS`.
- Figure asset checks:
  - `heatmap-rb-1.png`: `1536 x 768`.
  - `heatmap-rw-1.png`: `1536 x 768`.

## Definition Of Done Status

- Implementation: not applicable; article/status slice only.
- Simulation recovery: no new M3 or CI evidence added.
- Documentation: article and article-council ledger updated.
- Runnable example: article rendered with its existing simulated fit workflow.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Fisher/Rose scope-boundary pass applied; Florence asset
  existence/dimension smoke checked.

## Not Claimed

- No public promotion of `functional-biogeography`.
- No M3 close.
- No CI-08 / CI-10 promotion.
- No publication-grade or release-ready claim.
- No scientific coverage completion.
