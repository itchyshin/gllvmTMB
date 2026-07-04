# After-task report: ancillary reference examples latent cleanup

Date: 2026-06-18 21:42 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Update ancillary validation/profile/rotation examples so ordinary Gaussian
covariance fits use default `latent()` rather than old ordinary
`latent() + unique()` compatibility spelling.

## Files touched

- `R/check-consistency.R`
- `R/coverage-study.R`
- `R/profile-targets.R`
- `R/rotate-loadings.R`
- `man/gllvmTMB_check_consistency.Rd`
- `man/coverage_study.Rd`
- `man/profile_targets.Rd`
- `man/rotate_loadings.Rd`
- `man/extract_rotated_loadings_table.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- `gllvmTMB_check_consistency()`, `coverage_study()`, and
  `profile_targets()` examples now use default ordinary `latent()` alone.
- `rotate_loadings()` and `extract_rotated_loadings_table()` examples now use
  default ordinary `latent()` alone.

## Definition-of-done accounting

1. Implementation: documentation example cleanup only; no parser or model
   behavior changed and nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: roxygen sources and generated Rd files updated.
4. Runnable example: reference examples now use the preferred ordinary
   `latent()` spelling.
5. Check-log: `docs/dev-log/check-log.md` has the 21:42 MDT entry with exact
   commands and outcomes.
6. Review pass: lifecycle wording consistency only; no likelihood, parser, or
   formula semantics changed.

## Validation

- Touched R files parsed.
- `devtools::document(quiet = TRUE)` regenerated the five Rd files.
- Focused check-consistency / coverage / profile-targets / rotate-loadings /
  deprecation tests passed with expected heavy skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no old ordinary `latent() + unique()` examples in
  the touched source/help files.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` cleanup remains ongoing.
