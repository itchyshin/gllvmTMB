# Paper 2 iJSDM A0–A2 reconciliation receipt

**Lane:** `codex/isdm-paper2-evidence-reader-a0`
**Exact base:** `0f668c469228f1799a989e112176fd931f2f88a8`
**Status:** documentation/specification closed; A3 approval required.

## Reconciled predecessor

G2o's `G2O_NO_FIT_DESIGN_ONLY_GO` permits only a fresh, pre-registered
estimator/Psi calibration design.  This A0–A2 packet takes exactly that
permission.  It reads the retained G2d protocol, G2n local-pre-run HOLD, G2k
150/150 diagnostic, and G2o postmortem; it does not open their result roots as
new experiments or change their receipt classifications.

The following evidence remains protected and unchanged:

- `G2N_LOCAL_PRERUN_HOLD`: Case C, unique `b_fix` raw-gradient maximum
  0.002726537 and diagonal-Psi variance miss 0.2156398 > 0.20.
- `G2K_CALIBRATION_HOLD`: a completed 150-attempt FIR evidence bundle whose
  numerical/recovery distribution does not define a promotion cutoff.
- `G2C_SMOKE_ADMISSION_HOLD`: retained separately; it is not reopened,
  pooled, or reinterpreted.

## Actual A0–A2 work

- A0 created a lane-local loop and durable stop checkpoint.
- A1 maps package scopes from official documentation without a comparator fit,
  performance ranking, or public claim.
- A2 locks the existing likelihood/DGP/map/transform/threshold contract and
  preregisters recovery dimensions S = 6, 20, 60 plus measured S = 250 and
  S = 1,000 implementation gates.

No R, C++, tests, public docs, pkgdown, articles, package metadata, estimator,
fixture, seed, threshold, result root, profile, or compute state changed.

## Forward authority

No fit is authorized.  The next action is explicit maintainer approval for a
named A3 slice after the Gate-A review, with an estimate and pre-run test before
any run expected to exceed 30 minutes.  S = 10,000 stays architecture HOLD.
