# Audit: PoisG cloglog Σ vs scale (n / p)

**Date:** 2026-08-07  
**Question:** At n=120 PoisG Σ̂ collapsed (trace ~1e−10). Does that die with
larger **n** or a wider response matrix (**p**)?  
**Script:** `lanes/va-s1-binomials/scripts/probe-cloglog-poisg-nladder.R`  
**Results:** `lanes/va-s1-binomials/results/poisg-nladder-20260807/`,
`…/poisg-wide-500x20-20260807/`  
**No fence / `auto` flip.**

## Design

| knob | value |
|---|---|
| link / family | cloglog binary, trials=1, `unique=FALSE`, q=2 |
| n ladder | {120, 400, 1000} × p=8, **10 seeds** |
| wide smoke | n=500 × **p=20**, **8 seeds** |
| arms | `gtmb_poisg`, `gllvm_va` (default starts); ref `gtmb_gh`, `gtmb_la` |
| cores | 8 local |
| pass_abs | β RMSE ≤ 0.35 and Σ rel-Frob ≤ 0.50 |

## Verdict

**NO — Σ does not get OK at large n or large p.**  
Collapse is **100%** for both **our PoisG** and **gllvm VA** at every cell
tested. This looks like an **objective-level Λ→0 mode** (asymptotic / structural
under-scale of PoisG), not a small-n artefact. Contrast: **GH / LA** improve Σ
with n (pass_abs → 0.8–0.9 at n=1000, p=8).

β under PoisG **does** improve with n and matches gllvm to ~1e−6 abs on β RMSE.

## Chat table (medians; collapse = ‖Σ̂‖ < 1e−8 ‖Σ_true‖)

### n ladder (p=8, 10 seeds)

| n | arm | β RMSE | Σ rf | tr(Σ̂) | ‖Σ̂‖ | collapse | runaway | pass_abs |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 120 | **gtmb_poisg** | 0.123 | **1.00** | 8.7e−11 | 7.7e−11 | **1.0** | 0 | 0 |
| 120 | **gllvm_va** | 0.123 | **1.00** | 3.0e−11 | 2.8e−11 | **1.0** | 0 | 0 |
| 120 | gtmb_gh | 0.138 | 1.60 | 3.18 | 2.31 | 0 | 0.5 | 0 |
| 120 | gtmb_la | 0.134 | 1.42 | 2.71 | 2.03 | 0 | 0.2 | 0 |
| 400 | **gtmb_poisg** | 0.064 | **1.00** | 2.3e−11 | 2.0e−11 | **1.0** | 0 | 0 |
| 400 | **gllvm_va** | 0.064 | **1.00** | 1.2e−10 | 1.1e−10 | **1.0** | 0 | 0 |
| 400 | gtmb_gh | 0.069 | 0.82 | 2.11 | 1.59 | 0 | 0 | 0 |
| 400 | gtmb_la | 0.067 | 0.63 | 1.90 | 1.39 | 0 | 0 | 0.2 |
| 1000 | **gtmb_poisg** | 0.038 | **1.00** | 7.5e−11 | 7.2e−11 | **1.0** | 0 | 0 |
| 1000 | **gllvm_va** | 0.038 | **1.00** | 9.8e−11 | 9.7e−11 | **1.0** | 0 | 0 |
| 1000 | gtmb_gh | 0.037 | **0.37** | 1.60 | 1.23 | 0 | 0 | **0.8** |
| 1000 | gtmb_la | 0.037 | **0.39** | 1.62 | 1.22 | 0 | 0 | **0.9** |

max |Δβ RMSE| (poisg vs gllvm) ≤ 1.5e−6 at every n.

### Wider matrix (n=500, p=20, 8 seeds)

| arm | β RMSE | Σ rf | tr(Σ̂) | collapse | pass_abs |
|---|---:|---:|---:|---:|---:|
| **gtmb_poisg** | 0.063 | **1.00** | 7.8e−10 | **1.0** | 0 |
| **gllvm_va** | 0.063 | **1.00** | 7.2e−10 | **1.0** | 0 |
| gtmb_gh | 0.065 | 0.52 | 3.84 | 0 | 0.375 |
| gtmb_la | 0.065 | 0.51 | 3.73 | 0 | 0.25 |

## Yes / no / partial

| claim | answer |
|---|---|
| Σ OK at large **n** (≤1000)? | **NO** (poisg + gllvm: collapse 10/10) |
| Σ OK at large **p** (500×20)? | **NO** (collapse 8/8 both) |
| β OK / improves with n? | **YES** (partial win; matches gllvm) |
| Is this package-specific? | **NO** — gllvm VA identical pathology |

**Implication:** keep Design-110 `auto` = **GH** for cloglog; PoisG stays
opt-in / β-only curiosity. Do not advertise PoisG Σ recovery.
