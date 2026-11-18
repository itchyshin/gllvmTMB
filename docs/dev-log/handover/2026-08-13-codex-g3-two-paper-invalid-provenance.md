# Session Handoff: G3 two-paper smoke provenance closure

**Meta:** 2026-08-13 · Codex · private two-paper iSDM lane

## Critical Context

Both fresh G3 smoke roots are invalid-provenance records, not numerical model
results. Do not describe either as failed fitting, G3 rejection, recovery,
Psi, spatial-separation, or article evidence. Paper 2's root is
`G3_P2_S6_C360_R3_V1`; it stopped before optimizer entry because the runner
compared an ephemeral `devtools::load_all()` DLL path despite matching content
hashes.

## What Was Accomplished

- Committed the sealed P2 runner and its no-fit fence test.
- Corrected ledger-finalization, source-hash, timer, and same-objective checks
  after independent review.
- Materialised one immutable P2 receipt and ran exactly one approved smoke.
- Retained and independently adjudicated its terminal `INVALID_PROVENANCE`
  root; wrote the after-task report and recovery checkpoint.

## Current Working State

- **Working:** no active fit, campaign, profile, simulation, or public work.
- **Complete:** P2 preflight and smoke protocol execution; closure record.
- **Blocked by design gate:** no replacement P2 smoke or recovery campaign is
  authorised. The next proposal must be no-fit provenance design only.

## Key Decisions And Rationale

The G3 P2 packet explicitly treats receipt mismatch as terminal and forbids a
new start. The current root is therefore retained unchanged. Its path mismatch
is an implementation/provenance fault, not evidence about the likelihood. The
historical `PAPER2_PRIVATE_STOP_HOLD`, `G2N_LOCAL_PRERUN_HOLD`,
`G2K_CALIBRATION_HOLD`, and `G2C_SMOKE_ADMISSION_HOLD` remain protected.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/two-paper-global-analysis` at `1ab0d9c6` | yes | no | none | CARRIED-OVER |

The branch is intentionally unpushed because it is private evidence and needs
maintainer direction on the next no-fit design gate. Resume with:

```sh
cd /private/tmp/gllvmtmb-two-paper-global-analysis
git status --short --branch
git log --oneline -4
```

## Next Immediate Steps

1. Read the recovery checkpoint and after-task report below.
2. Request explicit approval for a new **no-fit** provenance-design amendment.
3. If approved, specify a new packet/root that uses source/DLL content hashes,
   records field-by-field receipt comparison, and leaves the two invalid roots
   untouched. That approval does not include a fit.

## Blockers / Open Questions

Only the maintainer can approve a fresh provenance-design amendment and decide
whether its later independently reviewed packet may request a new smoke. There
is no approved recovery, Totoro/DRAC, article-evidence, or public-reader step.

## Gotchas And Failed Approaches

Do not compare the path of a DLL loaded by `devtools::load_all()` across R
processes: it is temporary. Do compare immutable source and DLL content hashes.
Do not modify the existing P1/P2 result roots to repair their labels or receipt
detail; each remains an all-attempt historical record.

## How To Resume

Read, in order:

1. `docs/dev-log/recovery-checkpoints/2026-08-13-codex-g3-paper2-invalid-provenance.md`
2. `docs/dev-log/after-task/2026-08-13-g3-paper2-smoke-invalid-provenance.md`
3. `docs/dev-log/plan-actual/2026-08-13-g3-two-paper-final-reconciliation.md`
4. `dev/isdm-package-recovery/2026-08-13-g3-paper2-smallest-smoke-packet.md`
5. `dev/isdm-package-recovery/run-g3-paper2-smoke.R`

Then run the lane preflight and inspect current Git state before proposing any
mutation.
