# Binomial GH large-N ladder — logit × probit × cloglog

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-gh-nladder.R`  
**Local results (D-50):** `/private/tmp/va-s1-binomial-gh-nladder-20260807/`  
(combined 3-link summary; pre-cloglog backups `*.pre-cloglog.csv`; cloglog wall ~7 min @ 8 cores)  
**Prior n=120 dig:** `docs/dev-log/audits/2026-08-07-va-binomial-logit-probit-systematic.md`  
**No public fence change. No default-H change. No GH-logit fix programme.**

---

## Park (Shinichi 2026-08-07) — read first

**Logit GH recovery / “make GH win on logit” is PARKED.**  
Use **JJ for logit when VA**. This ladder is **measurement only** (impact of
large N on β / Σ / runaway / pass_abs across three links). Do **not** expand into
a logit-GH fix arc.

---

## A. Glossary

| Term | Meaning |
| --- | --- |
| **β RMSE** | vs planted Design-110 FE truth |
| **Σ rel Frob** | ‖Σ̂−Σ_true‖_F / ‖Σ_true‖_F ; Σ=ΛΛ′ loadings-only; **>1 allowed** |
| **trace_ratio** | tr(Σ̂)/tr(Σ_true) — loading scale (~1 = matched) |
| **eta_var** | var(Λ̂ m̂) / var(Λ z_true) when scores available |
| **runaway** | ‖Σ̂‖_F > 2 ‖Σ_true‖_F |
| **collapse** | ‖Σ̂‖_F ≈ 0 (zero estimator; rel≈1) |
| **pass_abs** | β≤0.35 AND Σ rf≤0.50 |
| **Our VA ≠ gllvm VA** | private R3 GH/JJ/AC vs `gllvm::gllvm(method="VA")` |

---

## B. Cell card

| Field | Value |
| --- | --- |
| family | binomial Bernoulli (trials=1) |
| links | **logit**, **probit**, **cloglog** |
| n ladder | **120, 400, 1000** (2000 skipped — not cheap) |
| p, q | 8, 2 |
| unique | FALSE (Σ=ΛΛ′) |
| seeds | `10901:10912` (12; same seeds per n) |
| H | 7 (GH) |
| engine | private `.va_r3_fit` |
| arms logit | GH, JJ, gtmb LA, gllvm VA, gllvm LA |
| arms probit | GH, AC, gtmb LA, gllvm VA, gllvm LA |
| arms cloglog | GH, gtmb LA, gllvm VA, gllvm LA |
| cores | 8 (cap 10) |

---

## C. Chat-ready — GH only (3 links × n)

Mean over 12 seeds. **pass_abs** = β≤0.35 & Σ rf≤0.50.

| link | n | β RMSE | Σ rf | trace | runaway | collapse | pass_abs | secs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **logit** | 120 | 0.225 | 5.582 | 5.94 | 1.00 | 0 | 0 | 2.8 |
| **logit** | 400 | 0.130 | 2.224 | 2.62 | 0.92 | 0 | 0 | 21 |
| **logit** | 1000 | 0.058 | 1.131 | 1.58 | 0.17 | 0 | **0** | 134 |
| **probit** | 120 | 0.129 | 2.034 | 2.39 | 0.83 | 0 | 0 | 6.0 |
| **probit** | 400 | 0.091 | 0.854 | 1.36 | **0** | 0 | 0 | 36 |
| **probit** | 1000 | **0.038** | **0.443** | **1.03** | **0** | 0 | **0.58** | 190 |
| **cloglog** | 120 | 0.158 | 1.863 | 2.28 | 0.58 | 0 | 0 | 2.0 |
| **cloglog** | 400 | 0.076 | 0.783 | 1.29 | **0** | 0 | 0.17 | 18 |
| **cloglog** | 1000 | **0.046** | **0.472** | **1.05** | **0** | 0 | **0.67** | 142 |

**n=120 → n=1000 GH improvement**

| link | β fold↓ | Σ rf | runaway | pass_abs |
| --- | ---: | ---: | ---: | ---: |
| logit | 3.9× | 5.58 → 1.13 | 1.00 → 0.17 | 0 → 0 |
| probit | 3.4× | 2.03 → 0.44 | 0.83 → 0 | 0 → **0.58** |
| cloglog | 3.4× | 1.86 → 0.47 | 0.58 → 0 | 0 → **0.67** |

**Read:** Large N helps β on all three links (~3.4–3.9×). **Probit and cloglog** clear Σ runaway by n=400 and clear abs Σ at n=1000 (pass_abs 0.58 / 0.67). **Logit GH** improves but never clears pass_abs (Σ still >0.50); fix remains **PARKED** — use JJ.

---

## D. Key comparators at n=1000

| link | arm | β RMSE | Σ rf | trace | runaway | pass_abs | secs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| logit | **gtmb_va_gh** | 0.058 | 1.131 | 1.58 | 0.17 | 0 | 134 |
| logit | **gtmb_va_jj** | 0.056 | **0.694** | 0.84 | 0 | 0.08 | 13 |
| logit | gtmb_la | 0.057 | 0.706 | 0.87 | 0 | 0 | 15 |
| logit | gllvm_va | 0.074 | 1.000† | ~0 | 0 | 0 | 4.4 |
| probit | **gtmb_va_gh** | **0.038** | **0.443** | **1.03** | 0 | **0.58** | 190 |
| probit | **gtmb_va_ac** | 0.039 | 1.000† | ~0 | 0 | 0 | 115 |
| probit | gtmb_la | 0.038 | **0.416** | 0.92 | 0 | **0.75** | 14 |
| probit | gllvm_va | 0.039 | 1.000† | ~0 | 0 | 0 | 5.1 |
| cloglog | **gtmb_va_gh** | **0.046** | **0.472** | **1.05** | 0 | **0.67** | 142 |
| cloglog | gtmb_la | 0.048 | **0.407** | 1.06 | 0 | **0.92** | 15 |
| cloglog | gllvm_va | 0.044 | 1.000† | ~0 | 0 | 0 | 4.2 |
| cloglog | gllvm_la | 0.048 | 0.530 | 0.96 | 0 | 0.58 | 10 |

† **gllvm VA / AC collapse** (Σ̂≈0 → rel≈1). Not a successful loadings recovery.

Paired mean Δ (ours − gllvm_va) at n=1000: logit GH dβ=−0.016 dΣ=+0.13; probit GH dβ≈0 dΣ=−0.56; cloglog GH dβ=+0.003 dΣ=−0.53. ΔΣ vs collapsed gllvm is not “we beat recovery by 0.5” — it is “we keep real scale while they zero.”

---

## E. Probit panel (full)

| n | arm | β RMSE | Σ rf | trace | runaway | collapse | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | **gtmb_va_gh** | 0.129 | 2.034 | 2.39 | 0.83 | 0 | 0 | 6.0 |
| 120 | **gtmb_va_ac** | 0.110 | 0.925 | 0.082 | 0 | 0.50 | 0 | 1.4 |
| 120 | gtmb_la | 0.127 | 1.726 | 2.06 | 0.58 | 0 | 0 | 1.6 |
| 120 | gllvm_va | 0.110 | 0.942 | 0.067 | 0 | 0.42 | 0 | 0.07 |
| 400 | **gtmb_va_gh** | 0.091 | 0.854 | 1.36 | **0** | 0 | 0 | 36 |
| 400 | **gtmb_va_ac** | 0.082 | 1.000 | ~0 | 0 | **0.92** | 0 | 13 |
| 1000 | **gtmb_va_gh** | **0.038** | **0.443** | **1.03** | **0** | 0 | **0.58** | 190 |
| 1000 | **gtmb_va_ac** | 0.039 | 1.000 | ~0 | 0 | **0.92** | 0 | 115 |
| 1000 | gtmb_la | 0.038 | **0.416** | 0.92 | 0 | 0 | **0.75** | 14 |

**Probit:** large N clears GH β + Σ runaway; AC/gllvm VA stay collapsed.

---

## F. Logit panel (measurement — fix PARKED)

| n | arm | β RMSE | Σ rf | trace | runaway | collapse | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | **gtmb_va_gh** | 0.225 | 5.582 | 5.94 | **1.00** | 0 | 0 | 2.8 |
| 120 | **gtmb_va_jj** | 0.191 | 2.205 | 2.46 | 0.67 | 0 | 0 | 0.65 |
| 400 | **gtmb_va_gh** | 0.130 | 2.224 | 2.62 | 0.92 | 0 | 0 | 21 |
| 400 | **gtmb_va_jj** | 0.122 | 1.050 | 1.28 | **0** | 0 | 0 | 3.1 |
| 1000 | **gtmb_va_gh** | 0.058 | 1.131 | 1.58 | 0.17 | 0 | **0** | 134 |
| 1000 | **gtmb_va_jj** | 0.056 | **0.694** | 0.84 | 0 | 0 | 0.08 | 13 |
| 1000 | gtmb_la | 0.057 | 0.706 | 0.87 | 0 | 0 | 0 | 15 |
| 1000 | gllvm_va | 0.074 | 1.000 | ~0 | 0 | **1.00** | 0 | 4.4 |

**Logit:** n helps β and shrinks runaway; abs Σ still FAIL for GH. Prefer **JJ**. No fix programme.

---

## G. Cloglog panel (new this session)

| n | arm | β RMSE | Σ rf | trace | runaway | collapse | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | **gtmb_va_gh** | 0.158 | 1.863 | 2.28 | 0.58 | 0 | 0 | 2.0 |
| 120 | gtmb_la | 0.154 | 1.462 | 1.88 | 0.33 | 0 | 0 | 1.7 |
| 120 | gllvm_va | 0.135 | 1.000 | ~0 | 0 | **1.00** | 0 | 0.05 |
| 120 | gllvm_la | 0.221 | 23.4‡ | 18.8 | 0.33 | 0 | 0 | 0.95 |
| 400 | **gtmb_va_gh** | 0.076 | 0.783 | 1.29 | **0** | 0 | 0.17 | 18 |
| 400 | gtmb_la | 0.077 | 0.693 | 1.22 | 0 | 0 | 0.25 | 5.7 |
| 1000 | **gtmb_va_gh** | **0.046** | **0.472** | **1.05** | **0** | 0 | **0.67** | 142 |
| 1000 | gtmb_la | 0.048 | **0.407** | 1.06 | 0 | 0 | **0.92** | 15 |
| 1000 | gllvm_va | 0.044 | 1.000 | ~0 | 0 | **1.00** | 0 | 4.2 |
| 1000 | gllvm_la | 0.048 | 0.530 | 0.96 | 0 | 0 | 0.58 | 10 |

‡ n=120 gllvm LA mean inflated by runaway seeds; ignore as “typical.”

**Cloglog:** same large-N story as probit — GH β↓, runaway dies by n=400, pass_abs **0.67** at n=1000 (best of the three GH arms). Only GH VA tier exists for cloglog (no JJ/AC).

---

## H. Process / fence

- Local only (8 cores). Totoro not required.
- Public fence **unchanged**; private R3 path only.
- n=2000 not run (GH already ~2–3 min/seed at n=1000).
- Logit GH fix programme explicitly **not** opened.

---

## I. STOP — what this does / does not license

1. **Large N helps all three links on β** (~3.4–3.9× from 120→1000).
2. **Probit + cloglog GH** clear Σ runaway and pass abs Σ at n=1000; **logit GH does not** (pass_abs still 0) — park stands; use JJ for logit VA.
3. **gllvm VA / probit AC** remain **collapse** paths at large N — do not cite them as Σ recovery winners.
4. Still **no** fence/`auto` flip; still **no** public claim.
5. Next G0: nbinom dig vs Totoro S1 — not “fix logit GH.”
