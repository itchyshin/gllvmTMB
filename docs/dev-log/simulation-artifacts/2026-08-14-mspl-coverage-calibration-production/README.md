# LA-MSPL fixed-effect coverage calibration production

This directory preserves the compact adjudication from the claim-bearing
ordinary `q = 1` LA-MSPL interval campaign. Raw shards and row-level outputs
remain outside Git and on DRAC project storage; the files here are sufficient
to reconstruct the frozen 108-cell promotion verdict.

## Immutable campaign identity

- Source: `8b23cfd2078bbac409f229a4d9f87df8b35ab147`.
- Campaign: `lane-b-mspl-coverage-20260814-8b23cfd2-r1`.
- Production receipt SHA-256:
  `8232f1a847e6bfeb4626e6b55d033496743aa0e373284ad30a6432aeac277ea1`.
- Full summary SHA-256:
  `64b2776010b0f5af4b41d0f764d412853bd43a918fd758c4727ea854af991564`.
- Canonical 1,200-shard ledger SHA-256:
  `1cb6c667f9018784545646dcdda2183766758272e265848e80d1e27691f15fd1`.

The strict aggregate contains 1,200 unique shards, 12,000 outer fits,
6,000,000 bootstrap attempts, 108,000 method-target endpoints, 1,159,993
profile-trace rows, and 108 summary cells. Every outer fit succeeded. Five
bootstrap attempts had the retained status `refit_optimizer_failed`, but all
36,000 bootstrap endpoints met the 475-of-500 usable-refit floor.

## Frozen verdict

The predeclared gate required profile and bootstrap availability of at least
0.95, counted unavailable intervals as noncoverage, and required the 90%
Wilson coverage interval to lie wholly inside `[0.92, 0.98]`. Wald required at
least 500 available intervals per cell and applied the same equivalence gate
to coverage conditional on an available positive-definite likelihood Hessian.

| Method | Availability gates | Coverage gates | Joint gates | Public result |
|---|---:|---:|---:|---|
| Penalised profile | 34/36 | 25/36 | 24/36 | blocked |
| Parametric bootstrap | 36/36 | 20/36 | 20/36 | blocked |
| Paper-style Wald | 36/36 | 9/36 | 9/36 | blocked |

No method passed all 36 predeclared cells. Public MSPL `vcov()`, `confint()`,
`profile_targets()`, `tmbprofile_wrapper()`, `bootstrap_Sigma()`, and standard-
error routes therefore remain fail-closed. The 53 passing cells are not an
approved public subset, and this campaign must not be used to tune a method on
the same seeds.

## Files

- `gate-map-108.tsv`: all method-case-target gates and Wilson bounds.
- `joint-gate-failures-55.tsv`: the 55 cells that failed the joint gate.
- `method-summary.tsv`: method-level availability and coverage ranges.
- `case-summary.tsv`: joint pass/fail counts by case.
- `production-receipt.txt`: immutable aggregate receipt.
- `resource-runtime-stop-resume-summary.txt`: cluster routing, monitored
  pending-age stops, exact-key continuations, and aggregation resources.
- `SHA256SUMS`: hashes for the compact retained evidence.

Independent statistical reconstruction and provenance review both passed.
They confirmed that the non-promotion result is a genuine regime-dependent
availability/calibration blocker rather than a missing-key, aggregation, or
objective-identity defect.
