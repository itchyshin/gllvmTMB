# Frozen approved ultra-plan — missing-data ledger closure

**G0 approved:** 2026-08-01 (Shinichi: "approve"; Design 107 locked as next pointer).

Source of truth also at:
`docs/dev-log/plans/2026-08-01-ultra-plan-missing-data-ledger-closure.md`

## GOAL

```text
PLATFORM: Cursor
DELIVERABLE: Close (or honestly hold) GitHub issues #336/#337/#338 against already-shipped MIS rows + Phase 2b/2c tests; leave next-capability pointer = Design 107 VA missing-data.
HEADLINE: Retire stale "implement #336 Phase 2b" programme debt — MIS-27 is already covered on origin/main @ 6a5bc352.
DEFER / FENCED: greenfield Phase 2b; MIS-32; coverage (D-112); Design 107 implementation; tweedie; protected Dropbox coverage checkout; deleted slope lane.
DISCIPLINE: cite register + named tests + narrow test; local only; after-task + issue closes + check-log.
```

## Arcs / slices

| ID | Outcome |
| --- | --- |
| S0 | Evidence map + shared-group pin present/absent |
| S1 | After-task + issue disposition |
| S2 | Thin shared-group independence pin **only if S0 unmet** |
| S3 | Narrow test if code changed |
| S4 | MC/handover/CLAUDE pointer → Design 107 |
| S5 | Melissa plan-actual |

## Locked decisions

1. Ledger closure, not greenfield 2b.
2. Next capability pointer = Design 107.
3. Root `LOOP/` is foreign (0.6); this lane uses `lanes/missing-data-ledger-336/LOOP/`.
