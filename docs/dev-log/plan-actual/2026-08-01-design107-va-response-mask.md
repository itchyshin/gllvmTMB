# Plan vs actual — Design 107 VA response-include Stage 1 (2026-08-01)

**Plan:** `~/.cursor/plans/design_107_va_response-mask_c98e6827.plan.md`  
**Lane LOOP:** `lanes/design107-va-mask/LOOP/`

## Axes

| Axis | Planned | Actual | Tag |
| --- | --- | --- | --- |
| Scope | Gate A Stage 1 only: `is_y_observed` term-skip; lift response-mask abort; keep mi abort; local tests | Delivered; no Stage 2 / mi / coverage / Totoro | match |
| Evidence | Sentinel-invariance + thin VA+include recovery | `test-va-missing-response.R` 10/10; prototype still loads | match |
| Model routing | Fresh WT + Cursor `/goal` | WT `/private/tmp/gllvmtmb-design107-va-mask-20260801`; branch `cursor/design107-va-response-mask-20260801` | match |
| Safety gates | No root LOOP overwrite; no ledger WT reuse; no public claim | Held; named lane LOOP; register VA-10 `partial` | match |
| Public claims | No “VA missing-data certified” | No NEWS/README/article advertise; register honesty only | match |
| Handoff | After-task + check-log + PR + Melissa | This file + after-task + PR | match |

## Material deviations

1. **Fixture q=1 Lambda bug in first mi-refuse draft** — fixed locally before closeout (`adaptive`).
2. **Root LOOP** — already owned by 0.6 lane; wrote `lanes/design107-va-mask/LOOP/` (`adaptive`, same pattern as ledger lane).

## Drift to Rose

None unjustified. Stage 2 not started.
