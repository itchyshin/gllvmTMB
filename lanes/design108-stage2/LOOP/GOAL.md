# GOAL — Design 108 Gate A Stage 2 (VA mixed-family)

> **🔴 STALE / GOAL_MET — do not execute this LOOP.**  
> Stage 2 landed on `main` via [#893](https://github.com/itchyshin/gllvmTMB/pull/893)
> (2026-08-02). Mixed-family VA under the existing admission fence is **`partial`**
> (register VA-11), not a public claim. This kit is a **historical pointer** only.
> For current VA work see `docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md`
> and the lane map. **Resume pointer:** `lanes/design108-stage2/LOOP/checkpoint.md`.

**IMMUTABLE FOR THIS RUN (historical). Re-read at the top of EVERY arc.**

## Mission

Wire dense `DATA_IVECTOR(family)` and per-trait `log_sigma` into
`gllvmTMB_va_r3`, lift R mixed-family abort for fence-admitted families,
keep pure-binomial JJ / mixed→GH, prove single-family regression + thin
mixed smoke. No public claim.

## Headline

Ayumi-shaped mixed-family fits can enter `integration = "va"` under the
existing VA admission fence (gaussian/binomial/poisson).

## Invariants (historical)

- Worktree: `/private/tmp/gllvmtmb-design108-stage2-mixed-20260801` — **removed**
- Branch: `cursor/design108-va-mixed-family-20260801` — **merged #893**
- Do **not** edit root `LOOP/` (0.6 release lane).
- Do **not** reuse Design 107 WT for implementation after merge.
- No Stage 3–14 as core; no Totoro Stage 8; no coverage (D-112); no VA `mi()`.
- Local compute only.

## Definition of done (all satisfied on main)

1. Mixed-family VA admitted under fence; single-family tests green. ✅
2. Thin mixed smoke green. ✅
3. After-task + check-log + register VA-11 `partial` + PR. ✅ [#893](https://github.com/itchyshin/gllvmTMB/pull/893)
4. No public mixed-family VA claim. ✅ (fenced)
