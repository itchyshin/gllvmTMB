# Audit — LA vs AGHQ(+ridge) timed binary (S1-shaped)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Question:** Is AGHQ+ridge still “best” for binary, and how fast vs LA?  
**Fence:** measurement only — no default / `auto` / public claim.

## API (today)

- AGHQ is **opt-in**: `gllvmTMBcontrol(aghq = k)` (or `"auto"`); **default `aghq = FALSE`** (Laplace).
- When AGHQ is on, **`aghq_ridge` defaults to `τ = 2`** on the AGHQ path (`R/fit-multi.R`).
- Laplace + ridge fires **only** if the caller **names** `aghq_ridge` (default never silently penalises Laplace).
- AGHQ Stage 1a needs `latent(..., unique = FALSE)` — same grammar as Design-110 / S1 probes.

## Brain priors (cited)

- [[AGHQ exposes a flat likelihood direction in GLLVMs — the runaway is bimodal, not biased]] — shipped-engine claim: AGHQ+ridge eliminates runaway and improves **ρ** at every n tested, **σ** at large n; small-n σ can favour Laplace.
- [[VA series standard comparator panel (LA default + LA+tricks)]] — AGHQ/`aghq_ridge` evidence is mostly binomial/runaway; not a multi-family S1 abs-Σ certificate.
- [[Totoro preferred for heavy VA/binary sims (2026-08-07)]] — heavy jobs → Totoro; local ≤10 cores for smokes.
- Repo `decisions.md` 2026-07-28 four-arm table: vs **shipped** Laplace, AGHQ+ridge wins σ and ρ on p=6 q=2 binomial (954-fit Totoro lineage). Later verification audit: AGHQ helps binomial mainly at **large n**; ridge (not quadrature) kills runaway.

## Banked wall times (warm engines; Totoro shipped-4)

Source: `dev/aghq-evidence/20-shipped4-inc.csv` (p=6 q=2 binomial, 15 seeds/cell, `elapsed_s`).

| n | LA med (s) | AGHQ+ridge med (s) | ratio |
| ---: | ---: | ---: | ---: |
| 100 | 1.01 | 4.81 | **4.7×** |
| 1600 | 2.97 | 67.06 | **22.6×** |

Recovery on that grid (median): at n=1600, AGHQ+ridge `sigma_rat` 0.981 vs LA 0.868; `rho_absd` 0.076 vs 0.103 — AGHQ+ridge still ahead on those estimands.

## Fresh timed smoke (this session)

Script: `lanes/va-s1-binomials/scripts/probe-la-vs-aghq-timed.R`  
D-50: `/private/tmp/va-s1-la-vs-aghq-timed-20260807/`  
Geometry: **probit**, n=400, p=8, q=2, `unique=FALSE`, seeds `11101:11104`.  
Warm-up at n=60 **untimed** (excluded from ratios). No cold TMB inside the clock.

| arm | β RMSE | Σ rf | pass_abs | secs (mean) | vs LA |
| --- | ---: | ---: | ---: | ---: | ---: |
| **gtmb_la** | 0.065 | **0.600** | **0.50** | **3.1** | 1× |
| gtmb_aghq_ridge (`aghq=9`, τ=2) | 0.067 | 0.947 | 0.00 | 206.5 | **~67×** |

S1 nladder context (same scorer family, n=1000 probit, 12 seeds): LA already strong — β≈0.038, Σ rf≈0.416, pass_abs≈0.75 at ~14 s; VA-GH ~190 s.

## Verdict

1. **Accuracy “best” depends on estimand.** AGHQ+ridge remains best on the **σ / ρ / runaway** binomial grid that justified it. On **S1 abs β / Σ rf / pass_abs** at n=400–1000, **LA is competitive or better** and already clears abs more often.
2. **Cost:** AGHQ is **not** cheap vs LA. Banked ~5–23×; this S1-shaped smoke ~**67×** at n=400 (adaptation + multi-start path). It only *feels* fast next to VA-GH.
3. **Recommendation:** keep **LA as large-N binary baseline** for S1; keep AGHQ(+ridge) as optional **LA+tricks** comparator (already in the VA panel). **No default flip.**

## Not done

- n=1000 / 500×20 AGHQ timed panel (Totoro busy on 500×20 probit + cloglog h2h — do not kill).
- AGHQ `aghq_ridge=Inf` split on S1 scorers.
- Coverage / SE claims.
