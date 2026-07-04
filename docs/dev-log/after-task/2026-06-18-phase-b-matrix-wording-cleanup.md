# Phase-B Matrix Wording Cleanup

Date: 2026-06-18 23:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Clean the Phase-B matrix-completion planning table so it no longer teaches
`latent+unique` as ordinary vocabulary after the ordinary `latent()` Psi fold.

## Files Touched

- `docs/design/59-phase-b-matrix-completion.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- Reworded unit, phylo, and spatial matrix-gap cells to distinguish ordinary
  `latent()` covariance from explicit-Psi compatibility cells.
- Reworded tail-family smoke coverage to ordinary latent / explicit
  compatibility diagonal smoke.

## Checks

- Exact scans for `latent+unique` and the old `latent` / `unique` smoke phrase
  returned no hits in the touched file.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.

## Still Not Claimed

- No behavior change.
- No keyword removal.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.
