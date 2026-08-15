# Plan-actual — MSPL SE feasibility pin (Melissa)

```text
🎯 GOAL
Solo: Cursor
Deliverable: binary SE teacher + local se=TRUE feasibility pin for Bernoulli-logit and Poisson
HEADLINE: learn SE from the Codex binary lane; pin whether a named curvature construction can be formed; do not absorb; do not call it covered
DEFER: admit · NEWS covered · public vcov/confint · NB1/NB2/beta/Tweedie · gaussian SE · profile/bootstrap/sandwich
```

**Branch:** `cursor/mspl-se-feasibility-pin`
**Base:** tapes tip `0df6ab30` (#978 CI-fix) because #978 was not
merged when the lane cut. G0 allowed that fallback.
**Finish line:** teacher + availability pin + still planned, **not**
admission and **not** calibrated SE.

## G0 lock

| Q | Plan default | Actual |
|---|---|---|
| Q1 | (a) internal pin | (a) |
| Q2 | (a) Poisson + Bernoulli logit | (a) |
| Q3 | (c) both Hessians | (c) |

Shinichi: *"everything in this plan is pre-approved OK? - keep going"*
plus later merge authority for #978 and this PR when CI green.

## Slice ledger

| Slice | Plan | Actual | Status |
|---|---|---|---|
| A0 LOOP kit | lane folder, never root `LOOP/` | `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/` | **DONE** |
| A1 Shannon + branch | from main after #978, else tapes | cut from tapes @ `0df6ab30`; #972–#976 untouched | **DONE** |
| A2 teacher | `git -C` only | `2026-08-15-mspl-binary-se-teacher.md` | **DONE** |
| A3 estimand | smallest working binary route | both Hessians; sandwich/profile deferred | **DONE** |
| A4 failing tests | RED before `R/` | pin tests RED (`object not found`); public fence already green | **DONE** |
| A5 implement | new `R/` file; no `src/`; no Codex paste | `R/mspl-curvature-pin.R` | **DONE** |
| A6 tests | GREEN or exact RED | Bernoulli 24 / Poisson 29 GREEN | **DONE** |
| A7 closeout | Rose PASS; no admit | this file + after-task + check-log + handover | **DONE** |
| A8 SE PR | open, do not merge #972–#976 | opened when pushed | **IN FLIGHT** |
| A9 merge #978 | when CI green | authorised; wait on re-run `31905438557` | **IN FLIGHT** |
| A10 merge SE PR | when CI green | authorised after A8+A9 | **PENDING** |
| A11 morning brief | `2026-08-16-cursor-handover-se-pin.md` | written | **DONE** |

## Drift

- Overnight prompt said “se=TRUE pin”. Ultra-plan (pre-approved)
  forbade flipping the withholding branch. Resolved as: fit with
  `se=TRUE` to prove withhold, form SEs on the private pin.
- Ultra-plan preferred a post-#978 `main` cut. #978 was open and
  CI-red, then CI-fix-pushed. Lane cut from the fix tip so the
  Poisson door exists.
- No all-zero / large-μ Poisson cell in this overnight pin. Named
  as leftover, not silently dropped from the teacher.

## HARD STOP hits

None. No admit. No NEWS covered. No #972–#976 merge. No Codex
absorb. No repo-root `LOOP/`. No `src/` edit. No public `vcov()`.
