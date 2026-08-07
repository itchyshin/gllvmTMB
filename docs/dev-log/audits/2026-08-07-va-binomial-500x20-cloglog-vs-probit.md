# Audit — 500×20 cloglog vs probit GH H2H (abs Σ)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Ask:** Does cloglog GH bring better abs Σ news than probit GH at n=500 p=20?  
**Verdict:** **No — stick with probit GH for the user story.**  
**Fence / `auto`:** unchanged. No public claim.

---

## Spec

| Field | Value |
| --- | --- |
| size | n=500, p=20, q=2, trials=1, `unique=FALSE`, H=7 |
| DGP | Design-110-shaped (same Λ / β / seed recipe as prior 500×20 probit) |
| seeds | 12 (`11001`…`11012`), same seeds both links |
| primary arms | **gtmb cloglog GH**, **gtmb probit GH** |
| optional | gtmb LA both links (cheap); PoisG / gllvm off on this H2H |
| pass_abs | β RMSE ≤ 0.35 **and** Σ rel Frob ≤ 0.50 |
| host | Totoro (`PILOT_CORES=12`); probit-only Totoro job left untouched |
| scripts | `lanes/va-s1-binomials/scripts/probe-binomial-500x20-cloglog-probit-h2h.R` |
| | `lanes/va-s1-binomials/scripts/launch-totoro-s1-500x20-cloglog-probit-h2h.sh` |
| raw (D-50) | `/home/snakagaw/gllvm_work/va-s1-binomial-500x20-cloglog-probit-h2h-20260807/results/` |
| local mirror | `/private/tmp/va-s1-binomial-500x20-cloglog-probit-h2h-20260807/totoro-results/` |

Also extended `probe-binomial-500x20-probit-smoke.R` so `PROBE_LINK=cloglog` works (family + inv-link).

---

## Chat-ready table (Totoro, 12 seeds)

| link | arm | β RMSE | Σ rf (mean) | Σ rf (med) | pass_abs | collapse | runaway | secs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **probit** | **gtmb_va_gh** | **0.065** | **0.468** | **0.485** | **8/12 (0.67)** | 0 | 0 | 139 |
| cloglog | gtmb_va_gh | 0.069 | 0.518 | 0.527 | **5/12 (0.42)** | 0 | 0 | 37 |
| probit | gtmb_la | 0.065 | 0.444 | 0.454 | 9/12 (0.75) | 0 | 0 | 1.4 |
| cloglog | gtmb_la | 0.069 | 0.492 | 0.501 | 6/12 (0.50) | 0 | 0 | 1.5 |

Paired GH (cloglog − probit), n=12: **dβ = +0.0038**, **dΣ = +0.050**, pass 0.42 vs 0.67.

Sibling Totoro probit-only smoke (GH+AC+LA+gllvm VA, same seeds) agrees: GH pass_abs **0.67**, mean Σ rf **0.468**; AC/gllvm VA stay soft/collapsed on Σ (pass_abs 0).

Prior local probit 10-seed (same recipe): GH pass_abs 0.60, Σ rf 0.469 — consistent.

---

## PoisG / gllvm cloglog (reuse; not the 500×20 H2H)

PoisG n-ladder finished locally (`/private/tmp/va-s1-poisg-nladder-20260807/`, p=8, 10 seeds): **gtmb_poisg and gllvm_va collapse Σ at every n** (frac_collapse=1, pass_abs=0). GH recovers with n (pass_abs 0 → 0 → **0.8** at n=1000). PoisG is not a 500×20 abs-Σ candidate.

Cheap n=120 PoisG H2H earlier: same collapse story.

---

## Recommendation (one sentence)

**Prefer probit + our GH for users; cloglog GH at 500×20 is softer on abs Σ (pass 5/12 vs 8/12, mean Σ rf 0.52 vs 0.47) and does not improve the user story — keep cloglog as a supported link, not the default pitch.**
