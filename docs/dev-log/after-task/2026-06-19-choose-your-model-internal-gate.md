# Choose Your Model Internal Gate

Date: 2026-06-19 01:56 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice aligned `vignettes/articles/choose-your-model.Rmd` with the current
article-council ledger. It kept the page as an internal navigation draft until
the linked article surface is public-safe.

## What Changed

- Added Tier 3 YAML.
- Replaced the opening status block with an internal navigation-draft gate.
- Stated that linked worked examples are intentionally internal until their
  rendered/browser and evidence gates close.
- Removed `validated rungs are runnable` wording.
- Replaced `publication-grade CIs` with coverage-row-scoped interval wording.
- Marked the linked biological/capstone articles in the See also list as
  internal drafts.
- Updated the article-council ledger row.

## Checks

- `gh pr list --state open`
  - only draft PR #489 on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/choose-your-model", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - rendered `pkgdown-site/articles/choose-your-model.html`.
- Rendered HTML scope review:
  - `choose_your_model_rendered_scope_review=PASS`.
- Figure asset check:
  - `ladder-fig-1.png`: `1459 x 806`.

## Definition Of Done Status

- Implementation: not applicable; article/status slice only.
- Simulation recovery: no new evidence added.
- Documentation: article and article-council ledger updated.
- Runnable example: existing live chunks rendered.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose navigation-boundary pass applied; page remains
  internal.

## Not Claimed

- No public promotion of `choose-your-model`.
- No final navigation-guide decision.
- No release readiness or scientific coverage completion.
