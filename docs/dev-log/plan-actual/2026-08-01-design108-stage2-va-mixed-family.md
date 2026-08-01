# Plan vs actual — Design 108 Stage 2 VA mixed-family (2026-08-01)

**Plan:** `~/.cursor/plans/va_mixed-family_stage_2_e09a9bf6.plan.md`  
**Lane LOOP:** `lanes/design108-stage2/LOOP/`

## Axes

| Axis | Planned | Actual | Tag |
| --- | --- | --- | --- |
| Scope | Gate A Stage 2: `DATA_IVECTOR(family)` + `log_sigma[T]`; lift mixed abort for fence set; pure-binomial jj / mixed→gh | Delivered; no Stage 3/4, Totoro, public claim, VA mi() | match |
| Evidence | Single-family regression + thin mixed smoke | mixed 23/23; missing 10/10; fence 39/39; routing 31/31; prototype 352/352 | match |
| Model routing | Fresh WT after #891 from `origin/main` | WT `/private/tmp/gllvmtmb-design108-stage2-mixed-20260801`; branch `cursor/design108-va-mixed-family-20260801` @ `3f66d553` | match |
| Safety gates | No root LOOP overwrite; no Design 107 WT reuse; no public claim | Held; named lane LOOP; register VA-11 `partial` | match |
| Public claims | No mixed-family VA advertise | No NEWS/README/article advertise; register honesty only | match |
| Handoff | After-task + check-log + PR + Melissa | This file + after-task + PR | match |

## Material deviations

1. **`estimate_gaussian_sd` pin** — added so known-SD gaussian oracle / variance-domain fixtures keep pre-Stage-2 algebra (`adaptive`). Public/default path still estimates `log_sigma`.
2. **Mixed public smoke fixture** — thinned to `n=100, p=4, q=1` with a milder DGP after larger `q=2` cells hovered just above the 1e-4 gradient gate (`adaptive`, still in-fence).
3. **Root LOOP** — already owned by 0.6 lane; wrote `lanes/design108-stage2/LOOP/` (`adaptive`).

## Drift to Rose

None unjustified. Stage 3/4 not started.
