# After-task report -- kernel_unique lifecycle badge alignment

Date: 2026-06-18 23:58 MDT  
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Make the `kernel_unique()` deprecation stage visible on the shared dense-kernel
reference topic while preserving the current compatibility contract.

The scope is deliberately narrow: `kernel_unique()` remains compatibility
syntax, and the Paper 2 multi-kernel path remains latent-only.

## Files touched

- `R/kernel-keywords.R`
- `man/kernel_latent.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-kernel-unique-lifecycle-badge.md`

## Evidence

- `devtools::document(quiet = TRUE)` regenerated `man/kernel_latent.Rd`.
- Focused `unique-family-deprecation|kernel-equivalence|coevolution-two-kernel`
  tests passed with expected heavy COE-04 skips.
- `pkgdown::check_pkgdown()` reported no problems.
- Source/Rd scan confirmed the `kernel_unique()`-only deprecated badge line.
- `grep -c '^\\keyword' man/kernel_latent.Rd` returned `0`.
- `git diff --check` was clean.

## Definition-of-done notes

- Implementation: roxygen/Rd lifecycle text only; no parser, engine, or
  extractor behavior changed.
- Simulation recovery: not applicable for this documentation/lifecycle polish.
- Documentation: roxygen and Rd updated.
- Runnable example: unchanged; existing `kernel_latent()` example remains
  latent-only.
- Check-log: updated in `docs/dev-log/check-log.md`.
- Review/scope pass: kept the guard explicit and did not expand
  `kernel_unique()` into Paper 2 explicit-Psi support.

## Still not claimed

- No `unique()` keyword removal.
- No source-specific/kernel latent-Psi fold.
- No Paper 2 multi-kernel explicit-Psi implementation.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
