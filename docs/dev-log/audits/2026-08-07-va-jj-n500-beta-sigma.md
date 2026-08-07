# Audit — logit JJ at n=500 (β + Σ vs GH / gllvm / LA)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-gh-nladder.R`  
**Results (D-50 local):** `/private/tmp/va-s1-binomial-jj-n500-20260807/`  
**Wall:** 101 s on 8 cores. **No fence / auto / H change. Logit GH fix stays PARKED.**

---

## Cell card

| Field | Value |
| --- | --- |
| family / link | binomial Bernoulli, **logit** |
| n, p, q | **500**, 8, 2 |
| unique | FALSE (Σ=ΛΛ′) |
| seeds | `10901:10912` (12) |
| H | 7 (GH only; JJ explicit `eval_method="jj"`) |
| engine | private `.va_r3_fit` |
| arms | gtmb JJ, gtmb GH, gtmb LA, gllvm VA, gllvm LA |
| gllvm starts | **default** (`PROBE_GLLVM_START=default`) — fair same-family package compare |
| abs caps | β RMSE ≤ 0.35; Σ rel Frob ≤ 0.50 |

---

## Numbers first (means over 12 seeds)

| arm | β RMSE | Σ rf | trace | runaway | collapse | pass_abs | healthy | secs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **gtmb_va_jj** | **0.090** | **0.953** | **1.19** | **0** | **0** | **0** | **1.00** | 5.5 |
| gtmb_va_gh | 0.094 | 1.950 | 2.41 | **0.83** | 0 | 0 | 1.00 | 35 |
| gtmb_la | 0.092 | 1.016 | 1.29 | 0 | 0 | 0 | 0.75 | 7.5 |
| gllvm_va | 0.092 | 1.000 | ~0 | 0 | **1.00** | 0 | 1.00 | 0.82 |
| gllvm_la | **0.089** | **0.802** | 0.68 | 0 | 0 | 0 | 1.00 | 2.5 |

Paired mean Δ (ours − comparator; negative = we better):

| contrast | dβ | dΣ |
| --- | ---: | ---: |
| **JJ − GH** | **−0.003** | **−0.997** (JJ better Σ on **12/12**) |
| JJ − gllvm_va | −0.002 | −0.047 (gllvm Σ̂≈0 → rf≈1; JJ has real scale) |
| JJ − gllvm_la | +0.001 | +0.150 (gllvm LA slightly better Σ) |
| JJ − gtmb_la | −0.002 | −0.064 |

JJ seed Σ rf range: 0.55–1.48 (median 0.94). GH: 1.28–2.87 (median ~1.8).

---

## Ladder context (same seeds / DGP; prior zero-start gllvm)

| n | JJ β | JJ Σ rf | JJ trace | JJ pass_abs |
| ---: | ---: | ---: | ---: | ---: |
| 400 | 0.122 | 1.05 | 1.28 | 0 |
| **500** | **0.090** | **0.953** | **1.19** | **0** |
| 1000 | 0.056 | 0.694 | 0.84 | 0.08 |

n=500 sits cleanly between 400 and 1000 — not a surprise spike.

---

## Verdict

### Is JJ good at n=500?

| Claim | Verdict |
| --- | --- |
| β good? | **YES** — RMSE 0.090 ≪ 0.35; healthy 12/12 |
| Σ good (abs bar)? | **NO / PARTIAL** — no runaway, trace≈1.2, but mean Σ rf **0.95 > 0.50**; pass_abs **0/12** |
| JJ vs GH (ours)? | **JJ wins** — Σ d≈−1.0, runaway 0 vs 0.83; β tied/slightly better |
| JJ vs gllvm VA? | **JJ is the usable VA** — same β ballpark; gllvm VA **collapses Σ̂→0** even with **default** starts on this cell |
| JJ vs LA? | **Competitive on β**; **gllvm LA edges Σ** (0.80 vs 0.95); gtmb LA similar β, slightly worse Σ than JJ |

**One-liner:** At n=500 logit, **JJ is good on β and clearly better than our GH on Σ**, but **does not yet clear the abs Σ bar** (needs larger n, cf. n=1000 rf≈0.69 / pass≈0.08). Prefer JJ over GH for logit VA; do not treat collapsed gllvm VA as a recovery competitor.

---

## Process

- Reused n-ladder script; added `PROBE_GLLVM_START=zero|default` (default used here).
- Local only; fence untouched; logit GH fix **PARKED**.
