# Simulation Recovery Internal Gate

Date: 2026-06-19 01:48 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice aligned `vignettes/articles/simulation-recovery-validated.Rmd` with
the current CI-08 / CI-10 validation-debt status. It did not add new simulation
evidence or promote interval coverage.

## What Changed

- Retitled the page from `Simulation recovery: validated DGP grid` to
  `Simulation recovery: M3 smoke grid`.
- Added Tier 3 YAML and an internal coverage-triage gate.
- Named CI-08 and CI-10 as partial.
- Added the current M3.3 production-gate outcome: only Gaussian `d = 1` and
  `d = 3` passed, 13 of 15 cells stayed below gate, and 236 of 3000 replicate
  fits failed.
- Reframed the smoke grid as failure-analysis evidence rather than validation
  evidence.
- Removed validated/release-readiness implications from the prose and See also
  links.
- Updated the article-council ledger row.

## Checks

- `gh pr list --state open`
  - only draft PR #489 on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/simulation-recovery-validated", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - rendered `pkgdown-site/articles/simulation-recovery-validated.html`.
- Rendered HTML scope review:
  - `simulation_recovery_rendered_scope_review=PASS`.
- Figure asset check:
  - no article-specific figure assets were produced; expected for this page.

## Definition Of Done Status

- Implementation: not applicable; article/status slice only.
- Simulation recovery: no new simulation evidence added; the slice narrows
  claims around existing failed/partial evidence.
- Documentation: article and article-council ledger updated.
- Runnable example: existing smoke-grid chunks rendered.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Curie/Fisher/Rose boundary applied by keeping coverage partial.

## Not Claimed

- No CI-08 or CI-10 promotion.
- No new production-grid success.
- No broad interval calibration.
- No release readiness or scientific coverage completion.
