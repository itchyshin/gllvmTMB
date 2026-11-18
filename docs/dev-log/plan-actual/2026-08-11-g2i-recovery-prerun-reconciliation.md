# G2i recovery pre-run: plan versus actual

| Approved item | Actual evidence | Status |
| --- | --- | --- |
| One private SHA-bound local pre-run | Seed `86122L`, commit `0d0d5772`, one retained root | completed |
| Frozen G2h fixture and G2i estimator | Bound receipt hashes; no model/DGP change | completed |
| No-fit validation first | Focused test and `--mode=validate` passed | completed |
| Retain recovery/timing/provenance | Truth, fit, profiles, ledgers, manifest and closure retained | completed |
| No retry, Totoro, DRAC, public work, or excluded scope | None performed | completed |
| Recovery admission | Four of five recovery measures passed; Psi variance error `0.2156398 > 0.20` | HOLD |
| Measured campaign proposal | 30 seeds/cores: ~3.57 core-hours, 15-minute wall estimate; not authorized | completed, no launch |

The sole result is `PRE_RUN_RECOVERY_HOLD`.  It does not supersede G2c
`G2C_SMOKE_ADMISSION_HOLD` or G2h `G2H_SMOKE_HOLD`.

## Next safe action

Create a bounded diagnostic-design goal for the diagonal-Psi recovery hold.
It should inspect information and estimand alignment before changing the DGP,
criterion, or sample size; it must not fit, retry, or launch a campaign until
that diagnosis is approved.
