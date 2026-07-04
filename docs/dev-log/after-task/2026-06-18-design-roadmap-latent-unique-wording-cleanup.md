# Design Roadmap Latent/Unique Wording Cleanup

Date: 2026-06-18 23:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Remove a few remaining design-roadmap labels that described ordinary
validation targets as `latent+unique` or `unique`-only after the ordinary
`latent()` Psi fold.

## Files Touched

- `docs/design/01-formula-grammar.md`
- `docs/design/49-robust-modeling-roadmap.md`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- The augmented random-regression formula-grammar row now says explicit
  compatibility diagonal fit rather than `unique`-only fit.
- M3.3a pilot cells now say ordinary latent covariance instead of
  `latent+unique`.
- The capstone replication note now says diagonal `Psi` tier and explicit-Psi
  compatibility configuration instead of unique-`psi` tier and
  unit_obs / `latent+unique`.

## Checks

- Exact scans for the replaced phrases returned no hits in the touched files.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.

## Still Not Claimed

- No behavior change.
- No keyword removal.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.
