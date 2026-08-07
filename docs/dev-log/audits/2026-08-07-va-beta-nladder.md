# Audit — beta n-ladder (Totoro, 2026-08-07)

**Lane:** `va-s4-beta`  
**Checkout:** Totoro confirmation `022b4eab`  
**D-50 dirs:** Totoro `/home/snakagaw/gllvm_work/va-s4-beta-nladder-20260807/`;
local `/private/tmp/va-s4-beta-nladder-20260807/`  
**Scripts:** `lanes/va-s4-beta/scripts/probe-beta-nladder.R`,
`launch-totoro-beta-nladder.sh`

## Design

| axis | value |
|---|---|
| DGP | Design-110 loadings-only (`Σ = ΛΛ'`, `unique=FALSE`) |
| p, q | 8, 2 |
| n | {120, 400, 1000} |
| seeds | 12 (SEED0=11401) |
| φ | 5 (recovery-test moderate concentration) |
| y support | clamped to `(1e-4, 1-1e-4)` |
| arms | gtmb VA-GH H=7, gtmb LA, gllvm LA, gllvm VA (attempted) |
| timing | `n_starts=1`, `se=FALSE`, warm DLL outside timers |

## Comparator feasibility (gllvm 2.0.13)

| arm | verdict |
|---|---|
| gllvm VA `beta` | **N/A** — not implemented with method VA |
| gllvm LA `beta` | live (attempted and scored) |

## Summary table (mean over 12 seeds; abs caps β≤0.35 / Σ≤0.50)

| n | arm | n_ok | β RMSE | Σ rf | pass_abs | frac_runaway | secs |
|---:|---|---:|---:|---:|---:|---:|---:|
| 120 | gtmb_va | 12 | 0.091 | 0.707 | 0.25 | 0.08 | 6.4 |
| 120 | gtmb_la | 12 | 0.090 | 0.516 | 0.58 | 0.00 | 0.39 |
| 120 | gllvm_la | 12 | 0.080 | 0.726 | 0.00 | 0.00 | 3.7 |
| 400 | gtmb_va | 12 | 0.049 | 0.276 | **1.00** | 0.00 | 10.5 |
| 400 | gtmb_la | 12 | 0.048 | 0.296 | **1.00** | 0.00 | 1.21 |
| 400 | gllvm_la | 12 | 0.069 | 0.699 | 0.00 | 0.00 | 10.5 |
| 1000 | gtmb_va | 12 | 0.030 | **0.175** | **1.00** | 0.00 | 52.7 |
| 1000 | gtmb_la | 12 | 0.031 | 0.212 | **1.00** | 0.00 | 2.22 |
| 1000 | gllvm_la | 12 | 0.067 | 0.706 | 0.00 | 0.00 | 31.2 |

gllvm VA: 0/12 ok at every n (API N/A).

## Verdict (scientific only — **not** a package PASS)

1. **Σ recovers with n for gllvmTMB** (both VA and LA): pass_abs reaches 1.0 by n=400
   and holds at n=1000; Σ rf falls to ~0.17–0.21.
2. **gllvm LA does not recover Σ with n** on this DGP: Σ rf stuck ~0.70–0.73 across
   120→1000; pass_abs stays 0. β RMSE also flat/worse vs gtmb (~0.067 at n=1000 vs ~0.030).
3. At large n, **gtmb VA slightly beats gtmb LA on Σ** (0.175 vs 0.212) but is ~24× slower
   under matched `n_starts=1`. Prefer LA for cost unless Σ edge is decisive.
4. VA `healthy=0` under `n_starts=1` (health gate needs ≥3 starts) — abs still scored.
5. No fence / `auto` flip. No PASS claim from this ladder alone.
