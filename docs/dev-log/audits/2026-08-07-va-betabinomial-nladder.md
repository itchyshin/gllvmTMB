# Audit — betabinomial n-ladder (Totoro, 2026-08-07)

**Lane:** `va-s3-betabinomial`  
**Checkout:** Totoro confirmation `022b4eab`  
**D-50 dirs:** Totoro `/home/snakagaw/gllvm_work/va-s3-betabinomial-nladder-20260807/`;
local `/private/tmp/va-s3-betabinomial-nladder-20260807/`  
**Scripts:** `lanes/va-s3-betabinomial/scripts/probe-betabinomial-nladder.R`,
`launch-totoro-betabinomial-nladder.sh`

## Design

| axis | value |
|---|---|
| DGP | Design-110 loadings-only (`Σ = ΛΛ'`, `unique=FALSE`) |
| p, q | 8, 2 |
| n | {120, 400, 1000} |
| seeds | 12 (SEED0=11301) |
| **trials** | **10** (Design-59 / recovery default; multi-trial for identifiable φ) |
| φ | 3 |
| arms | gtmb VA-GH H=7, gtmb LA, gllvm VA, gllvm LA (attempted) |
| timing | `n_starts=1`, `se=FALSE`, warm DLL outside timers |

## Comparator feasibility (gllvm 2.0.13)

| arm | verdict |
|---|---|
| gllvm VA `beta.binomial` | **N/A** — not implemented with method VA |
| gllvm LA `beta.binomial` | **N/A** — errors (`condition has length > 1`) on every `Ntrials` shape tried |

2×2 panel reserves both cells; raw CSV records the refusal. No silent drop.

## Summary table (mean over 12 seeds; abs caps β≤0.35 / Σ≤0.50)

| n | arm | n_ok | β RMSE | Σ rf | pass_abs | frac_runaway | secs |
|---:|---|---:|---:|---:|---:|---:|---:|
| 120 | gtmb_va | 12 | 0.117 | 1.409 | 0.00 | 0.50 | 2.3 |
| 120 | gtmb_la | 12 | 0.114 | 0.831 | 0.00 | 0.00 | 0.66 |
| 400 | gtmb_va | 12 | 0.064 | 0.707 | 0.17 | 0.00 | 11.5 |
| 400 | gtmb_la | 12 | 0.063 | 0.495 | 0.58 | 0.00 | 1.80 |
| 1000 | gtmb_va | 12 | 0.036 | 0.409 | 0.75 | 0.00 | 53.7 |
| 1000 | gtmb_la | 12 | 0.036 | 0.354 | 0.92 | 0.00 | 3.77 |

gllvm arms: 0/12 ok at every n (API N/A).

## Verdict (scientific only — **not** a package PASS)

1. **Σ recovers with n** for both gllvmTMB arms: VA rf 1.41 → 0.41; LA 0.83 → 0.35;
   pass_abs 0 → 0.75 (VA) / 0.92 (LA) at n=1000.
2. **Prefer LA** on this cell for default cost+accuracy: matched β, better Σ, ~14× faster
   than VA at n=1000 under `n_starts=1`.
3. VA `healthy=0` at all n under `n_starts=1` (three-start health gate cannot fire) —
   same timing design as NB2; abs metrics still scored on completed fits.
4. No fence / `auto` flip. No PASS claim from this ladder alone.
