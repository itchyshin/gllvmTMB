# After-task report: capability-status default augmented latent cleanup

Date: 2026-06-18 21:56 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice updated `docs/design/61-capability-status.md`, the readable planning
layer over the validation-debt register, so the ordinary Gaussian
reaction-norm row names default augmented `latent(1 + x | unit, d = K)` with
`Psi_B,aug`.

Explicit augmented `unique(1 + x | unit)` remains Gaussian-only compatibility
syntax. Non-Gaussian augmented `unique()` remains guarded.

## Files touched

- `docs/design/61-capability-status.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Validation

- `rg -n 'latent\\(1 \\+ x \\| unit, d = K\\) \\+ unique\\(1 \\+ x \\| unit\\)|Gaussian `latent \\+ unique`|ordinary unit-tier\\s+`latent\\(1 \\+ x \\| unit' docs/design/61-capability-status.md`
  returned no hits.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  `No problems found.`
- `git diff --check` passed.

## Definition-of-done notes

1. Implementation: design-doc wording only; local on the active #489 branch.
2. Simulation recovery: not applicable; no new likelihood, family, keyword, or
   estimator was added.
3. Documentation: source design document updated directly.
4. Runnable example: no executable example changed; the planning row now
   matches the implemented augmented latent-Psi default.
5. Check-log: appended in `docs/dev-log/check-log.md`.
6. Review pass: Rose/Boole-style status wording check is the relevant lens; no
   likelihood or parser implementation changed.

## Still guarded

- `unique()` remains compatibility syntax.
- Source-specific and kernel latent-Psi folds remain future work.
- Coevolution remains `COE-04 partial`.
- Bridge completion, release readiness, and scientific coverage are not
  claimed.
