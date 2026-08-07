# NB2 (nbinom2) n-ladder — does Σ recover with n?

**Date:** 2026-08-07  
**Authority:** Shinichi — “NB2 Σ looks hopeless at n=120 — do we need larger sample sizes?”  
**Prior smoke:** Totoro 2×2 `dcaf37d7` — all arms `pass_abs=0`, Σ rf ~1.0–1.2 at n=120.  
**Estimator rev:** confirmation `022b4eab` (Totoro checkout).  
**D-50:** raw CSVs on Totoro + `/private/tmp` only — not git-staged.  
**Claim level:** **ladder evidence only** — do **not** claim package PASS/FAIL or flip fence/`auto`.

## Roots

| Host | Path |
| --- | --- |
| Totoro | `/home/snakagaw/gllvm_work/va-s2-nbinom2-nladder-20260807/` |
| Local copy | `/private/tmp/va-s2-nbinom2-nladder-20260807/` |
| Script | `lanes/va-s2-nbinom2/scripts/probe-nbinom2-nladder.R` |
| Launcher | `lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-nladder.sh` |

MD5 (`ladder-summary.csv`): `f1e9a03f3c7f262ae3c85b901ea29134`  
MD5 (`ladder-raw.csv`): `71789abca17a32644ff37e217e9ad705`

## Design

- Same DGP as 2×2 smoke: Design-110 loadings-only (`Σ=ΛΛ'`, `unique=FALSE`), `p=8`, `q=2`, planted size `φ=1.5`
- **n ∈ {120, 250, 400, 1000}**; seeds `11201:11212` (12)
- Arms: **gtmb VA-GH H=7** (`.va_r3_fit`, `n_starts=1`) · **gtmb LA** (`se=FALSE`) · **gllvm LA**; **gllvm VA only at n=120** (collapse reconfirm)
- Warm DLL outside timers; Totoro 24 cores; wall ~2 min after compile (`done 10:04:14`)
- Abs caps (reported, not package adjudication): β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50

## Summary (mean over finite β+Σ; 12 seeds)

| n | arm | β RMSE | Σ rf (mean) | Σ rf (med) | pass_abs | collapse | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.145 | 0.991 | 0.973 | **0.00** | 0.00 | 1.71 | 2.51× |
| 120 | gtmb_LA | 0.184 | 1.143 | 1.110 | **0.00** | 0.00 | 0.68 | 1.00× |
| 120 | gllvm_LA | 0.184 | 1.120 | 1.060 | **0.00** | 0.00 | 0.57 | 0.83× |
| 120 | gllvm_VA | 0.183 | 0.997 | 1.000 | **0.00** | **0.83** | 0.07 | 0.10× |
| 250 | gtmb_VA | 0.104 | 0.841 | 0.813 | 0.08 | 0.00 | 2.72 | 1.99× |
| 250 | gtmb_LA | 0.157 | 1.023 | 1.050 | 0.08 | 0.00 | 1.37 | 1.00× |
| 250 | gllvm_LA | 0.149 | 1.022 | 0.965 | 0.08 | 0.08 | 3.16 | 2.31× |
| 400 | gtmb_VA | 0.088 | 0.643 | 0.666 | 0.17 | 0.00 | 5.20 | 2.15× |
| 400 | gtmb_LA | 0.146 | 0.887 | 0.936 | 0.00 | 0.00 | 2.42 | 1.00× |
| 400 | gllvm_LA | 0.154 | 0.928 | 0.918 | 0.00 | 0.00 | 3.90 | 1.61× |
| **1000** | **gtmb_VA** | **0.058** | **0.373** | **0.373** | **0.92** | 0.00 | 19.2 | 3.17× |
| 1000 | gtmb_LA | 0.099 | 0.548 | 0.559 | 0.42 | 0.00 | 6.05 | 1.00× |
| 1000 | gllvm_LA | 0.118 | 0.721 | 0.776 | 0.25 | 0.00 | 13.5 | 2.24× |

## Verdict for Shinichi

**Yes — larger n is needed for abs Σ on this DGP**, and it is **not** hopeless forever.

1. **Shared hardness at n=120:** all scored arms fail abs together (Σ rf ≈ 1.0–1.1). Matches the 2×2 smoke. Not a VA-only defect.
2. **Σ recovers monotonically with n for gtmb VA and (slower) for gtmb LA.** At n=1000: VA mean Σ rf **0.37**, `pass_abs` **0.92**; LA mean Σ rf **0.55**, `pass_abs` **0.42**.
3. **Nuance vs smoke takeaway:** at **small n**, prefer **LA** (cheaper; same abs fail). At **large n (≈1000)**, **VA-GH can win abs Σ** on NB2 vs LA and vs gllvm LA — still ~3× wall vs gtmb LA.
4. **gllvm VA collapse reconfirmed** at n=120 (10/12 seeds); skipped at larger n by design.
5. **gtmb LA `healthy` FE-gate rate falls with n** (12→7→1→0) while `ok` stays 12/12 — gate tightness under `se=FALSE`, not a collapse of scorable β/Σ. Do not equate gate FAIL with hopeless recovery (same caveat as VA `n_starts=1`).

**No fence / `auto` flip.** No package PASS claim beyond this ladder.

## Checks

```sh
ACTION=sync ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-nladder.sh
ACTION=full PROBE_N_SEED=12 PILOT_CORES=24 PROBE_N_GRID=120,250,400,1000 \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-nladder.sh
# EXIT 0; done 10:04:14; summary MD5 f1e9a03f3c7f262ae3c85b901ea29134
LOCAL_PULL=/private/tmp/va-s2-nbinom2-nladder-20260807 ACTION=pull \
  ./lanes/va-s2-nbinom2/scripts/launch-totoro-nbinom2-nladder.sh
```

Deliberately not run: fence edits, H-ladder, φ as abs estimand, gllvm VA at n>120, package tests.
