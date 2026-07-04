# After-task report -- unique deprecation diagnostic cleanup

Date: 2026-06-18 18:20 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

Continued the post-coevolution `unique()` deprecation lane by cleaning up stale
ordinary-user diagnostics. This slice did not remove any keyword and did not
rename extractor parts.

## Implementation

- `R/extract-sigma.R`
  - Changed ordinary augmented `part = "unique"` guidance from explicit
    `unique(1 + x | unit)` wording to diagonal-Psi / default-`latent()` wording.
  - Updated the total-covariance note to say no diagonal Psi is present rather
    than no `unique()` term is present.
- `R/communality-ci.R`
  - Changed the missing-Psi diagnostic to name the diagonal Psi component and
    point to default `latent()`; `latent(..., residual = FALSE)` is now named as
    the deliberate no-Psi subset.
- `tests/testthat/test-ordinary-latent-random-regression.R`
  - Quieted lifecycle warnings in compatibility-only fixtures that deliberately
    parse explicit `unique()` syntax.
- `R/fit-multi.R`
  - Updated ordinary augmented reaction-norm guard suggestions so new code
    points to default `latent(1 + x | unit, d = K)`, while explicit
    `unique(1 + x | unit)` is described as compatibility syntax.
- `R/extract-sigma-table.R` and `R/extract-correlations.R`
  - Updated generic no-covariance diagnostics to list `latent()` / `indep()`
    first and describe explicit `unique()` as compatibility syntax.
- `NEWS.md`
  - Recorded the diagnostic cleanup under the `unique()` family soft-deprecation
    entry.

## Checks

- Coordination check:
  - `gh pr list --state open`
    -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"`
    -> recent commits were the current coevolution stack.
  - In the continuation that added the final generic extractor wording cleanup,
    this check was rerun after state refresh and before further shared-file
    edits; no collision was detected.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma|communality|ordinary-latent|unique-family", reporter = "summary")'`
  -> passed with 23 expected heavy skips and no warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent|unique-family", reporter = "summary")'`
  -> passed after the fit-time guard wording cleanup.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table|extract-correlations|unique-family", reporter = "summary")'`
  -> passed after the generic extractor diagnostic cleanup.

## Definition of Done status

- Implementation: local wording/test cleanup only, not pushed.
- Simulation/recovery evidence: not applicable; no model behavior changed.
- Documentation: NEWS and check log updated.
- Runnable example: not applicable.
- Check-log entry: present.
- Review pass: lifecycle/test hygiene only; no formula grammar or likelihood
  changed.

## Still not claimed

- No `unique()` / `*_unique()` removal.
- No `part = "unique"` rename.
- No `common = TRUE` re-homing.
- No source-specific or `kernel_*()` latent-Psi fold.
- No bridge completion, release readiness, or scientific coverage completion.
