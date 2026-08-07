# Inventory — was gllvm in Codex/Totoro Arc-2? (binomial gap)

**Date:** 2026-08-07  
**Question:** Did last night’s Totoro/Codex Arc-2 runs include **gllvm** comparisons?  
**Answer:** **No.** New work needed for **binomial** 2×2 (gllvm arms).

## Arc-2 / H-ladder / confirmation — gllvm?

| Surface | Path | Estimators | gllvm? |
| --- | --- | --- | --- |
| H-ladder export | `/private/tmp/va-gh-h7-final-evidence/totoro/h-ladder/final-export-role-neutral-022b4eab.csv` | `va`, `laplace` only | **N** |
| Confirmation export | `…/totoro/confirmation/final-export-role-neutral-022b4eab.csv` | same lineage | **N** |
| Adjudication | `…/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv` MD5 `e57f8460…` | gllvmTMB VA vs LA ratios | **N** |
| Campaign contract | `dev/va-gh-h7-campaign/README.md` | *"`gllvm` is deliberately absent"* | **N** by design |

H-ladder MD5 `895bea568af0e582e8b104f9bf991d72` · **5520** rows · H∈{0,5,7,9,15,61}.  
Confirmation: **36000** rows. No `gllvm` column in any frozen export.

## Codex last night — any gllvm 2×2?

**N** for Arc-2. Codex Totoro work = H-ladder + confirmation + adjudication (gllvmTMB-only).

## What this Cursor session already has (gllvm)

| Probe | Families | Arms | Path / audit |
| --- | --- | --- | --- |
| Totoro 4-arm | poisson, gamma | gtmb VA/LA × gllvm VA/LA | `/private/tmp/va-gllvm-h2h-4arm-20260807/` · `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md` |
| Local gamma LA H2H | gamma | gtmb LA × gllvm LA | `/private/tmp/va-gamma-la-h2h-20260807/` · `…-va-gamma-la-h2h.md` |
| Local VA×VA (poisson/gamma) | poisson, gamma | gtmb VA × gllvm VA | `/private/tmp/va-poisson-gllvm-probe-20260807/` |
| Binomial 2×2 smoke | binomial logit | all four (2 seeds) | `/private/tmp/va-s1-binomial-2x2-smoke-20260807/` — **plumbing only**, not scientific |

## Binomial gllvm status

**Missing** as a real comparison. No Arc-2/Codex binomial×gllvm. Only a 2-seed local smoke.  
**Action:** start new local ≤10-core binomial 2×2 (H=7 reuse from Totoro H-ladder for the H question; new work = gllvm arms). Do **not** re-run H-ladder.

## H question (reuse — separate)

Totoro H-ladder already has binomial H∈{5,7,9,15,61}; H7≈H61 (adjudication `h7_stability_verdict=PASS` all six binomial cells). Gaps H=6,8 only — **not** worth a re-run given 5≈7≈9≈61. Keep public H=7 pending G0.
