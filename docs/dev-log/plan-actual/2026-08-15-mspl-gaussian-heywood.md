# Melissa plan-actual — Gaussian LA-MSPL Heywood (#967)

**Date:** 2026-08-15  
**Lane:** `cursor/mspl-gaussian-heywood-atom`  
**Plan:** `docs/dev-log/plans/2026-08-15-cursor-mspl-gaussian-heywood-ultra-plan.md`  
**LOOP:** `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/`

## G0 answers (locked)

| Q | Answer |
|---|---|
| Q1 merge #967 | YES when CI green + Rose PASS |
| Q2 registry | keep `admitted` / `oracle_local` |
| Q3 LOOP | new `cursor-mspl-gaussian/LOOP/` (catch-up GOAL untouched) |

## Plan vs actual

| Slice | Plan | Actual |
|---|---|---|
| S0 recon | map #967 vs main | **PASS** — MSPL-only; 0 behind at merge |
| S1 LOOP | new Gaussian kit | **PASS** — catch-up GOAL untouched |
| S2 Hirose tape | verify; Sol only if FAIL | **PASS** — no rebuild |
| S3 smoke | healthy + near-Heywood `se=FALSE` | **PASS** — `LOCAL_MSPL_SUMMARY failed=0` |
| S4 Rose | claim boundary | **PASS** — NEWS untouched; no SE bleed |
| S4b CI fence | — | **PASS** — `aaac7701` oracle planned→admitted/oracle_local; CI 31893473934 SUCCESS |
| S5 merge | if Q1 + CI + Rose | **DONE** — MERGED once |

## Deviations

- First CI FAIL was stale heywood oracle expecting `planned` (not C++). Fixed; no atom rebuild.
- Prior fail also listed VA `delta_lognormal` health-gate; **no VA files in #967**. Green re-run after MSPL fence fix cleared full R-CMD-check — treat prior VA hit as non-blocking / not MSPL-caused.
- Sol/Opus atom review **not** invoked.

## claim_guard (honoured)

- IN: experimental Gaussian ordinary point estimates (`admitted` / `oracle_local`).
- OUT: campaign, SE/intervals, Poisson, NEWS covered, free-ε, #856, binary SE lane, EVA.

## Closure artefacts

- After-task: `docs/dev-log/after-task/2026-08-15-mspl-gaussian-hirose-implement.md`
- PR: https://github.com/itchyshin/gllvmTMB/pull/967
- Fix commit: `aaac7701e225637a3ed876e5cae4b2b050be7f07`
- Merge SHA: `834c4cb684820f64f6c710e897bae97dbf5481c5`
