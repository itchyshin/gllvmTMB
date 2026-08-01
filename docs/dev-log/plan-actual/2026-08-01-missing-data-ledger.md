# Plan vs actual — missing-data ledger closure (2026-08-01)

**Plan:** `docs/dev-log/plans/2026-08-01-ultra-plan-missing-data-ledger-closure.md`  
**Lane LOOP:** `lanes/missing-data-ledger-336/LOOP/`

## Axes

| Axis | Planned | Actual | Tag |
| --- | --- | --- | --- |
| Scope | Ledger close #336/#337/#338; optional independence pin | Pin added + issues closed; no greenfield 2b | adaptive (S0 found gate unmet → S2 required) |
| Evidence | Cite MIS-27/28 + tests; narrow heavy if pin | testthat desc pin 0 fail; probe abs_err 0.044 | match |
| Model routing | Cursor Composer scout + Auto Cost close | Same chat executed S0–S5 after `/goal` | adaptive (user pasted `/goal` into planning chat) |
| Safety gates | No coverage; no D-112 tree; no root LOOP overwrite | Held; used named lane LOOP | match |
| Public claims | No new capability claim | Register MIS-27 note only; Design 107 named as next | match |
| Handoff | MC/CLAUDE/handover → Design 107 | Updated | match |

## Material deviations

1. **Root LOOP collision** — main already has 0.6 `LOOP/`. Adaptive: wrote
   `lanes/missing-data-ledger-336/LOOP/` instead of overwriting.
2. **Worktree branch drift** — path briefly pointed at
   `docs/cursor-handover-20260801`; corrected back to
   `cursor/missing-data-ledger-336-20260801` @ `origin/main` before edits.
3. **`/goal` in planning chat** — user invoked `/goal` here; executed rather
   than forcing a second fresh chat (checkpoint still durable on disk).

## Drift to Rose

None unjustified. No deferred slice vanished.
