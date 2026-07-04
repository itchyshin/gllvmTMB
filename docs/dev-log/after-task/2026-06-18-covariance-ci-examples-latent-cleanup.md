# After-task report: covariance CI examples latent cleanup

Date: 2026-06-18 21:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Update covariance/correlation interval examples so ordinary Gaussian covariance
fits use default `latent()` rather than the old ordinary `latent() + unique()`
compatibility spelling.

## Files touched

- `R/extract-correlations.R`
- `R/bootstrap-sigma.R`
- `R/z-confint-gllvmTMB.R`
- `man/extract_correlations.Rd`
- `man/bootstrap_Sigma.Rd`
- `man/confint.gllvmTMB_multi.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- `extract_correlations()` examples now fit the ordinary covariance model with
  `latent(0 + trait | site, d = 1)` alone.
- `bootstrap_Sigma()` examples now fit the ordinary covariance model with
  `latent()` alone.
- `confint.gllvmTMB_multi()` examples now fit the ordinary covariance model
  with `latent()` alone.

## Definition-of-done accounting

1. Implementation: documentation example cleanup only; no parser or model
   behavior changed and nothing was merged to `main`.
2. Simulation recovery: not applicable.
3. Documentation: roxygen sources and generated Rd files updated.
4. Runnable example: the reference examples now use the preferred ordinary
   `latent()` spelling.
5. Check-log: `docs/dev-log/check-log.md` has the 21:40 MDT entry with exact
   commands and outcomes.
6. Review pass: lifecycle wording consistency only; no likelihood, parser, or
   formula semantics changed.

## Validation

- Touched R files parsed.
- `devtools::document(quiet = TRUE)` regenerated the three Rd files.
- Focused extractor / bootstrap / confint / deprecation tests passed with
  expected heavy skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no old ordinary `latent() + unique()` examples in
  the touched source/help files.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` cleanup remains ongoing.
