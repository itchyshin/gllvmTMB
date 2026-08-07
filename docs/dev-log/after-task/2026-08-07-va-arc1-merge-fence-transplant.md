# After-task: VA Arc-1 merge/fence (C) path transplant — 2026-08-07

## Scope

Execute G0-approved Arc-1 ship path on a new lane from `origin/main`:
scaffold → inventory → path transplant → focused tests → Rose claim-fence →
open code PR (**no merge**).

## Outcome

- Worktree `/private/tmp/gllvmtmb-va-arc1-merge-fence` · branch
  `cursor/va-arc1-merge-fence-20260807` @ base `5bf18ab3`.
- Inventory frozen at
  `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-inventory.md`.
- Path transplant pins: closeout `537e6da4`; pre-PoisG `4435cd1e` for
  `R/va-r3-proto.R`, `test-va-r3-prototype.R`, and
  **`inst/tmb/gllvmTMB_va_r3.cpp`** (required — main still had legacy
  `log_phi`); NEWS honesty `98839853`.
- PoisG (`b53be434`), campaign harness, and `lanes/*/results` left behind.
- Focused tests green: integration-fence, va-routing-oracle,
  va-control-exposure, va-all-family-oracles/compiled/light-fits
  (18/18 healthy).
- Rose: `calibrated=FALSE`, Laplace default, Arc-2 mixed honesty, no soft-PASS.

## Checks

See `docs/dev-log/check-log.md` entry `2026-08-07 -- VA Arc-1 merge/fence (C)`.

## Follow-up

- Open code PR against `main`; **STOP for merge G0**.
- DEFER: docs-evidence PR; `calibrated=TRUE`; PoisG; multinomial VA; #947/#948.
