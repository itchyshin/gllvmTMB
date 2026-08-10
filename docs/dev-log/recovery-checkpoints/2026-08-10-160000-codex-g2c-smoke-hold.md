# G2c local-smoke checkpoint — HOLD

## State

- Worktree: `/private/tmp/gllvmtmb-isdm-g2c-replicated-pa`
- Branch: `codex/isdm-g2c-replicated-pa`
- Frozen runner commit: `2041684f044303c0fe26d5dde2b83f38d882f05d`
- Protected result: `dev/isdm-package-recovery/results/g2c-smoke-20260810-retry1/`
- Status: `SMOKE_HOLD`; do not overwrite or delete either the original empty
  root `g2c-smoke-20260810` or the retained retry root.

## What ran

1. No-write fixture validation: PASS.
2. `devtools::test(filter = "g2c-replicated-pa-harness")`: PASS, 3 assertions.
3. One synthetic paired smoke: ordinary seed 81101, one-visit and three-visit
   package-native fits, each with the three fixed native `theta_diag_B`
   log-SD profile ledgers. No Totoro, empirical data, public API, count,
   comparator, or spatial work ran.

## Exact smoke evidence

The receipt is `SMOKE_HOLD`. The three-visit fit had finite gradient
`1.972975e-04`, but its profile endpoint deltas did not satisfy the frozen
two-sided `>= 2` rule for all three coordinates. The three-visit fit is
therefore ineligible; this is neither a G2c recovery verdict nor a claim about
the general model.

## Changed files

- `dev/isdm-package-recovery/2026-08-10-g2c-replicated-pa-protocol.md`
- `dev/isdm-package-recovery/2026-08-10-g2c-replicated-pa-decision.md`
- `dev/isdm-package-recovery/run-g2c-replicated-pa-recovery.R`
- `dev/isdm-package-recovery/run-g2c-replicated-pa-totoro.sh`
- `tests/testthat/test-g2c-replicated-pa-harness.R`
- `docs/dev-log/check-log.md`
- this checkpoint

## Safe next action

Do **not** request or launch S5. First decide whether the profile admission
criterion should remain the exact gate for a repeated-visit recovery design,
or whether a separately approved G2d design should change only the support or
latent-variance parameterisation while retaining the same estimand. Any such
decision needs a new protocol and fresh root; it may not reuse this smoke root.
