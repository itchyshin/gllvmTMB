# After-task report: plot dispatcher validation-row refresh

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice refreshed one stale validation-debt row for the
`plot.gllvmTMB_multi()` dispatcher. It did not change code, examples, or
reference help.

## What changed

- MIS-09 now records seven dispatcher plot types:
  `correlation`, `correlation_ellipse`, `loadings`, `integration`,
  `communality`, `variance`, and `ordination`.
- MIS-09 now names the remaining limitation: visual snapshots / broader
  rendered-figure QA and 3-OS CI still need to cover the figure surface.

## Validation

- `git diff --check` was clean before adding this report.
- Register wording scan:
  `rg -n 'MIS-09|5 plot types|Phase 1c-viz|Seven dispatcher types|visual snapshots' docs/design/35-validation-debt-register.md R/plot-gllvmTMB.R tests/testthat/test-plot-gllvmTMB.R`
  returned the updated MIS-09 row and no stale `5 plot types` or
  `Phase 1c-viz` wording in the scanned files.

## Review lenses

- Ada kept the update to a single ledger row.
- Florence kept the residual-risk language honest: plot object tests are not
  the same as final rendered-figure QA.
- Rose checked the stale wording.
- Grace noted that 3-OS CI remains outstanding.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: validation-debt register updated.
4. Runnable example: not applicable; no code or examples changed.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Rose, and Grace lenses applied as above.

## Residual risk

- MIS-09 remains `partial` until visual snapshots / broader rendered-figure QA
  and 3-OS CI cover the current figure surface.
