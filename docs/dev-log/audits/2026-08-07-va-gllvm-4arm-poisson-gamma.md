# gllvm vs gllvmTMB 4-arm known-truth probe (poisson + gamma)

**Date:** 2026-08-07  
**Authority:** Standing gllvm comparator rule (Shinichi).  
**Estimator rev:** confirmation `022b4eab` (Totoro checkout + runtime).  
**D-50:** raw CSVs on Totoro + `/private/tmp` only — not git-staged.

## Roots

| Host | Path |
| --- | --- |
| Totoro | `/home/snakagaw/gllvm_work/va-gllvm-h2h-4arm-022b4eab-20260807/` |
| Local copy | `/private/tmp/va-gllvm-h2h-4arm-20260807/totoro-results/` |
| Script | `lanes/va-s0b-exact/scripts/probe-gllvm-4arm.R` |

MD5 (`summary.csv`): `41bbe9f13ada77bb018a9d1152bfd954`

## Design

- DGP: Design-110 exact cell (`n=120`, `p=8`, `Σ=ΛΛ'`, `unique=FALSE`)
- Cells: poisson, gamma (log link); `q ∈ {2,5}`
- Seeds: 91001:91008 (8 — small but decisive)
- Arms: **gllvmTMB VA** (GH H=7 private engine), **gllvmTMB LA**, **gllvm VA**, **gllvm LA**
- Caps (abs): β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50
- Totoro: 24 cores; local smoke used 1 core / 1 seed

## Model-match caveats

1. **Ψ / unique:** both packages fitted loadings-only (`latent(..., unique=FALSE)` / gllvm `num.lv`) — matched on Ψ absence.
2. **Family API:** gllvm requires string `family="gamma"`; `Gamma(link="log")` is rejected.
3. **Shape / φ:** not a matched estimand. gllvm `phi` and gllvmTMB `exp(log_phi_gamma)` can diverge wildly while β/Σ still score. Primary ledger estimands remain β and Σ.
4. **gllvmTMB LA Σ:** scored via `extract_Sigma(..., part="shared")` (link-implicit residual messages appear; shared LL' is the scored matrix).
5. **Health vs finite score:** gllvmTMB VA `status=failed_health_gate` on 6/8 gamma `q=5` seeds; finite β/Σ still reported. Do not equate health-gate FAIL with “hopeless recovery.”

## Summary (8 seeds; mean over finite β+Σ)

| cell | q | arm | n_ok | β RMSE | Σ rel Frob | pass_abs | secs mean |
| --- | --- | --- | --- | --- | --- | --- | --- |
| poisson | 2 | gtmb_VA | 8 | 0.111 | 0.608 | 0.12 | 0.53 |
| poisson | 2 | gtmb_LA | 8 | 0.114 | 0.648 | 0.12 | 0.10 |
| poisson | 2 | gllvm_VA | 8 | 0.116 | 0.667 | 0.12 | 0.21 |
| poisson | 2 | gllvm_LA | 8 | 0.110 | 0.687 | 0.12 | 1.29 |
| poisson | 5 | gtmb_VA | 8 | 0.123 | 0.460 | 0.75 | 10.9 |
| poisson | 5 | gtmb_LA | 8 | 0.130 | 0.483 | 0.62 | 0.18 |
| poisson | 5 | gllvm_VA | 8 | 0.121 | 0.536 | 0.12 | 3.81 |
| poisson | 5 | gllvm_LA | 8 | 0.130 | 0.507 | 0.50 | 3.47 |
| gamma | 2 | gtmb_VA | 8 | 0.070 | 0.418 | 0.62 | 0.89 |
| gamma | 2 | gtmb_LA | 8 | 0.070 | 0.419 | 0.75 | 0.17 |
| gamma | 2 | gllvm_VA | 8 | 0.078 | 0.488 | 0.25 | 0.28 |
| gamma | 2 | gllvm_LA | 8 | 0.077 | 0.498 | 0.50 | 1.81 |
| gamma | 5 | gtmb_VA | 8 | 0.128 | 0.440 | 0.88 | 90.5 |
| gamma | 5 | gtmb_LA | 8 | 0.109 | 0.367 | 1.00 | 0.45 |
| gamma | 5 | gllvm_VA | 8 | 0.150 | 0.505 | 0.50 | 26.1 |
| gamma | 5 | gllvm_LA | 8 | 0.121 | 0.424 | 1.00 | 3.94 |

## Verdicts for Shinichi

1. **Poisson q=2:** all four arms fail the abs Σ cap together (Σ ~0.61–0.69). β is fine. This is a shared DGP/regime problem, not a gllvmTMB-only defect. Matches S0b (A) SCIENTIFIC_FAIL on Σ.
2. **Poisson q=5:** gllvmTMB VA clears abs most often (pass 0.75, Σ 0.46). gllvm VA is weaker on Σ (0.54, pass 0.12). gllvm LA sits in between.
3. **Gamma — is gllvm / gllvmTMB LA “hopeless”?** **No, not on β/Σ.** gllvm LA finishes 8/8 and at `q=5` passes abs on **all** seeds (Σ 0.42). gllvmTMB LA does the same. S0b recorded gamma LA “healthy 0/300” is a **RETRACTED** `laplace_health` FE+RE gradient artefact (FE-proxy ≈282/300 & ≈214/300) — not evidence that Laplace cannot recover planted Σ. Gamma `(A) SCIENTIFIC_FAIL` remains a **VA reliability** statement under the recorded gate (re-read; no PASS without FE-|g| recompute).
4. **Shape caveat:** gllvm `phi` at gamma `q=5` often explodes (10⁶–10⁷) even when Σ recovers; gllvmTMB VA shape also blows on several `q=5` seeds. Do **not** use shape agreement as the comparator verdict.
5. **gllvm performance (always report):** gllvm VA is fast at `q=2` (~0.2–0.3 s) and slower at gamma `q=5` (~26 s mean, max ~70 s). gllvm LA is consistently ~1–5 s on this grid — faster than gllvmTMB VA at `q=5`, slower than gllvmTMB LA wall on Totoro for these small cells.

## Sibling coordination

Local VA×VA 20-seed probe under
`/private/tmp/va-poisson-gllvm-probe-20260807/` (`paired-summary.csv`):
**gllvmTMB VA often better Σ** than gllvm VA on poisson/gamma q∈{2,5}
(keep artefact; supports locked VA ≲ gllvm bar). Aborted sibling
`/private/tmp/va-s0b-gllvm-h2h-20260807/` was **not** reused.
This 4-arm Totoro run is the consolidated **2×2** comparator table.
