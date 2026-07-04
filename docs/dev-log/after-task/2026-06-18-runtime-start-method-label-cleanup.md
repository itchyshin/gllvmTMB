# Runtime Start-Method Label Cleanup

Date: 2026-06-18 23:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Finish the adjacent start-method vocabulary cleanup by removing the last
runtime/design `unique-only` labels from the independent warm-start path and
RE-12 testing contract.

## Files Touched

- `R/fit-multi.R`
- `docs/design/05-testing-strategy.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What Changed

- The verbose `start_method = "indep"` message now says it fitted an
  independent diagonal warm-start model, not a `unique`-only warm-start model.
- The RE-12 focused testing contract now says explicit compatibility diagonal
  extraction instead of `unique`-only diagonal extraction.

## Checks

- `Rscript --vanilla -e 'devtools::test(filter = "start-method|gllvmTMBcontrol|ordinary-latent|unique-family-deprecation", reporter = "summary")'`
  completed successfully.
- Exact scans over the touched runtime/design/status surface returned no hits
  for `unique-only` and the old verbose start-method string.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.

## Still Not Claimed

- No behavior change to `start_method`.
- No keyword removal.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.
