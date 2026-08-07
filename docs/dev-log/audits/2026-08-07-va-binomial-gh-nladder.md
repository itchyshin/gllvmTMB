# Binomial GH large-N ladder — probit β-vs-n (decision) + logit measurement

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-gh-nladder.R`  
**Local results (D-50):**
- probit: `/private/tmp/va-s1-binomial-gh-nladder-probit-20260807/` (wall 733 s)
- logit: `/private/tmp/va-s1-binomial-gh-nladder-logit-20260807/` (wall 460 s)  
**Prior n=120 dig:** `docs/dev-log/audits/2026-08-07-va-binomial-logit-probit-systematic.md`  
**No public fence change. No default-H change. No GH-logit fix programme.**

---

## Park (Shinichi 2026-08-07) — read first

**Logit GH recovery / “make GH win on logit” is PARKED.**  
Use **JJ for logit when VA**. This ladder is **measurement only** (does n help
β / scale / runaway?). Do **not** expand into a logit-GH fix arc. Decision-relevant
piece = **probit β-vs-n** (and whether AC stays collapsed while GH settles).

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
| links | **probit** (primary) + **logit** (measurement only) |
| n ladder | **120, 400, 1000** (2000 skipped — not cheap) |
| p, q | 8, 2 |
| unique | FALSE (Σ=ΛΛ′) |
| seeds | `10901:10912` (12; same seeds per n) |
| H | 7 (GH) |
| engine | private `.va_r3_fit` |
| arms probit | GH, AC, gtmb LA, gllvm VA, gllvm LA |
| arms logit | GH, JJ, gtmb LA, gllvm VA, gllvm LA |
| cores | 8 (cap 10) |

---

## C. Probit panel (decision-relevant)

| n | arm | β RMSE | Σ rf | trace | eta_var | runaway | collapse | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | **gtmb_va_gh** | 0.129 | 2.034 | 2.39 | 1.05 | 0.83 | 0 | 0 | 7.6 |
| 120 | **gtmb_va_ac** | 0.110 | 0.925 | 0.082 | 0.020 | 0 | 0.50 | 0 | 1.9 |
| 120 | gtmb_la | 0.127 | 1.726 | 2.06 | — | 0.58 | 0 | 0 | 1.9 |
| 120 | gllvm_va | 0.110 | 0.942 | 0.067 | 0.016 | 0 | 0.42 | 0 | 0.08 |
| 120 | gllvm_la | 0.127 | 1.724 | 2.06 | 0.76 | 0.58 | 0 | 0 | 0.55 |
| 400 | **gtmb_va_gh** | 0.091 | 0.854 | 1.36 | 0.44 | **0** | 0 | 0 | 44 |
| 400 | **gtmb_va_ac** | 0.082 | 1.000 | ~0 | ~0 | 0 | **0.92** | 0 | 17 |
| 400 | gtmb_la | 0.086 | 0.670 | 1.13 | — | 0 | 0 | 0.08 | 6.6 |
| 400 | gllvm_va | 0.082 | 1.000 | ~0 | ~0 | 0 | **1.00** | 0 | 0.71 |
| 400 | gllvm_la | 0.086 | 0.667 | 1.05 | 0.29 | 0 | 0 | 0.08 | 2.3 |
| 1000 | **gtmb_va_gh** | **0.038** | **0.443** | **1.03** | 0.29 | **0** | 0 | **0.58** | 190 |
| 1000 | **gtmb_va_ac** | 0.039 | 1.000 | ~0 | ~0 | 0 | **0.92** | 0 | 100 |
| 1000 | gtmb_la | 0.038 | **0.416** | 0.92 | — | 0 | 0 | **0.75** | 13 |
| 1000 | gllvm_va | 0.039 | 1.000 | ~0 | ~0 | 0 | **1.00** | 0 | 4.6 |
| 1000 | gllvm_la | 0.039 | 0.695 | 0.58 | 0.14 | 0 | 0.25 | 0.17 | 5.2 |

Paired Δ (GH − gllvm_va): n=120 dβ=+0.020 dΣ=+1.09; n=400 dβ=+0.008 dΣ=−0.15; **n=1000 dβ=−0.001 dΣ=−0.56**.

### Probit claims (yes/no)

| Claim | Verdict |
| --- | --- |
| GH β → match AC/gllvm as n↑? | **YES** — at n=1000 GH β 0.038 ≈ AC/gllvm 0.039 (dβ≈0) |
| GH scale (trace) → 1? | **YES** — 2.39 → 1.36 → **1.03** |
| GH Σ runaway die with n? | **YES** — runaway 0.83 → 0 → 0; Σ rf 2.03 → 0.85 → **0.44**; pass_abs **0.58** at n=1000 |
| AC stay attenuated while GH settles? | **YES** — AC/gllvm VA **collapse** (Σ̂≈0, rel≈1) at n≥400; GH keeps real scale and wins abs Σ |

**Read:** On this Design-110 probit cell, large N clears the GH β gap and kills Σ runaway. Closed-form **AC ≈ gllvm VA** remains a **collapse / zero-Σ** path that does not recover loadings even at n=1000. GH (and gtmb LA) are the arms that actually recover Σ here.

---

## D. Logit panel (measurement only — fix PARKED)

| n | arm | β RMSE | Σ rf | trace | eta_var | runaway | collapse | pass_abs | secs |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | **gtmb_va_gh** | 0.225 | 5.582 | 5.94 | 2.44 | **1.00** | 0 | 0 | 2.9 |
| 120 | **gtmb_va_jj** | 0.191 | 2.205 | 2.46 | 0.72 | 0.67 | 0 | 0 | 0.68 |
| 120 | gtmb_la | 0.212 | 3.129 | 3.40 | — | 1.00 | 0 | 0 | 1.6 |
| 120 | gllvm_va | 0.136 | 0.999 | ~0 | ~0 | 0 | **0.92** | 0 | 0.06 |
| 400 | **gtmb_va_gh** | 0.130 | 2.224 | 2.62 | 0.69 | 0.92 | 0 | 0 | 22 |
| 400 | **gtmb_va_jj** | 0.122 | 1.050 | 1.28 | 0.22 | **0** | 0 | 0 | 3.2 |
| 1000 | **gtmb_va_gh** | 0.058 | 1.131 | 1.58 | 0.31 | **0.17** | 0 | 0 | 139 |
| 1000 | **gtmb_va_jj** | 0.056 | 0.694 | 0.84 | 0.11 | 0 | 0 | 0.08 | 14 |
| 1000 | gtmb_la | 0.057 | 0.706 | 0.87 | — | 0 | 0 | 0 | 15 |
| 1000 | gllvm_va | 0.074 | 1.000 | ~0 | ~0 | 0 | **1.00** | 0 | 4.4 |

### Logit claims (yes/no) — measurement, not a fix ticket

| Claim | Verdict |
| --- | --- |
| GH β → match JJ/gllvm as n↑? | **YES on β vs JJ** at n=1000 (0.058 ≈ 0.056); vs gllvm VA β looks “better” only because gllvm collapses |
| GH scale → 1? | **PARTIAL** — trace 5.94 → 2.62 → **1.58** (improving, not settled) |
| Logit GH Σ runaway die with n? | **MOSTLY YES** — runaway 1.00 → 0.92 → **0.17**; Σ rf 5.58 → 2.22 → **1.13** (noise shrinks; abs Σ still FAIL) |
| Expand into “make GH win on logit”? | **NO — PARKED** (Shinichi). Prefer JJ for logit VA. |

---

## E. Process / fence

- Local only (8 cores). Totoro not required for this dig.
- Public fence **unchanged**; private R3 path only.
- n=2000 not run (probit GH already ~190 s/seed at n=1000).
- Logit GH fix programme explicitly **not** opened.

---

## F. STOP — what this does / does not license

1. **Probit:** large-N **does** clear GH β noise and Σ runaway on this cell; AC stays collapsed. GH is competitive with (or better than) AC/gllvm on abs recovery at n=1000.
2. **Logit:** n helps (β and runaway improve) but does **not** reopen a GH-logit rescue programme — **parked**; use JJ.
3. Still **no** fence/`auto` flip; still **no** public claim.
4. Next G0: nbinom dig vs Totoro S1 — not “fix logit GH.”
