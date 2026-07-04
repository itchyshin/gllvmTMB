# After-task report: canonical vision default latent cleanup

Date: 2026-06-18 21:54 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice updated `docs/design/00-vision.md`, the canonical vision document, so
ordinary no-prefix covariance examples teach default `latent()` as the
`Sigma = Lambda Lambda^T + Psi` decomposition.

The explicit ordinary `latent() + unique()` spelling remains named only as
compatibility syntax. The source-specific `phylo_unique()` example remains
because source-specific latent-Psi folding is not part of this cleanup slice.

## Files touched

- `docs/design/00-vision.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Validation

- `rg -n 'latent\\(\\) \\+ unique\\(\\)|\\+ unique\\(0 \\+ trait \\| site\\)|\\+ unique\\(1 \\| site\\)|\\+ unique\\(0 \\+ trait \\| site_species\\)|\\+ unique\\(1 \\| site_species\\)' docs/design/00-vision.md`
  returned only the intended compatibility sentence.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  `No problems found.`
- `git diff --check` passed.

## Definition-of-done notes

1. Implementation: design-doc wording only; local on the active #489 branch.
2. Simulation recovery: not applicable; no new likelihood, family, keyword, or
   estimator was added.
3. Documentation: source design document updated directly.
4. Runnable example: no executable package example changed; the design example
   now matches the implemented ordinary latent-Psi default.
5. Check-log: appended in `docs/dev-log/check-log.md`.
6. Review pass: Boole/Rose-style formula wording check is the relevant lens;
   no likelihood or parser implementation changed.

## Still guarded

- `unique()` remains compatibility syntax.
- Source-specific and kernel latent-Psi folds remain future work.
- Coevolution remains `COE-04 partial`.
- Bridge completion, release readiness, and scientific coverage are not
  claimed.
