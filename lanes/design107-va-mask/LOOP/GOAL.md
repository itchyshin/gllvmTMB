# GOAL — Design 107 Gate A Stage 1 (VA response-include)

**IMMUTABLE FOR THIS RUN. Re-read at the top of EVERY arc.**

## Mission

Wire dense `DATA_IVECTOR(is_y_observed)` into `gllvmTMB_va_r3`, gate density/`ell`,
lift R response-mask aborts for `miss_control(response = "include")`, keep VA
`mi()` refused, prove sentinel-invariance + thin recovery. No public claim.

## Headline

Ayumi-shaped incomplete grids can enter `integration = "va"` under the existing
VA admission fence.

## Invariants

- Worktree: `/private/tmp/gllvmtmb-design107-va-mask-20260801`
- Branch: `cursor/design107-va-response-mask-20260801`
- Do **not** edit root `LOOP/` (0.6 release lane).
- Do **not** reuse `/private/tmp/gllvmtmb-missing-data-336-20260801`.
- No VA `mi()`; no Design 108 Stage 2+; no Totoro Stage 8; no coverage (D-112).
- Local compute only.

## Definition of done

1. VA accepts response-include under existing VA fence.
2. Sentinel-invariance + thin recovery tests green.
3. After-task + check-log + register VA-10 `partial` + Melissa plan-actual + PR.
4. No public “VA missing-data certified” claim.
