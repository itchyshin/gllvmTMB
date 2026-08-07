# truncnb2 + delta_lognormal n-ladders — sibling wave after S4

**Date:** 2026-08-07  
**Authority:** Shinichi — “do **B here** — Totoro n-ladders for **truncnb2** and **delta_lognormal**.” Standing Totoro permission. **Only B** — no Arc-1 merge / fence / PR.  
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families` · `codex/va-gh-all-families`  
**Estimator rev:** confirmation `022b4eab` (Totoro checkout).  
**D-50:** raw CSVs on Totoro + `/private/tmp` only — not git-staged.  
**Claim level:** **ladder evidence only** — do **not** claim package PASS/FAIL or flip fence/`auto`.

## Registry names (clarified)

| Ask | Registry name | fid | VA route | Sibling already done |
| --- | --- | ---: | --- | --- |
| **truncnb2** | `truncated_nbinom2()` | **11** | GH | `truncated_poisson` fid 10 (zero-truncated Poisson, **not** Tobit) |
| **delta_ln** | `delta_lognormal()` | **12** | HYBRID | `delta_gamma` fid 13 |

Both are Design-110 VA-admitted cells. gllvm has no matching zero-truncated NB2 / hurdle-lognormal arm → **gtmb LA + VA only** (same as the siblings).

## Design (match S4 / betabin)

- Loadings-only (`Σ=ΛΛ'`, `unique=FALSE`), `p=8`, `q=2`
- **n ∈ {120, 400, 1000}**; seeds `11401:11412` (12); `n_starts=1`; `se=FALSE`; warm DLL outside timers
- Abs caps (reported only): β ≤ 0.35 ; Σ rf ≤ 0.50
- truncnb2 DGP: φ = 2; β elevated (`seq(0.55, 1.35, length.out = p)`) so mean counts stay away from the Poisson limit under zero-truncation
- delta_lognormal DGP: occupancy ~ Bernoulli(logit η); positives ~ Lognormal(meanlog = η, sdlog = 0.60) — shared-η hybrid, sibling of delta_gamma
- Totoro 12 cores × 2 jobs in parallel; did not kill unrelated work

## Roots + MD5 (`ladder-summary.csv`)

| Family | Totoro | Local | MD5 |
| --- | --- | --- | --- |
| truncated_nbinom2 | `…/va-s4-truncated-nbinom2-nladder-20260807/` | `/private/tmp/va-s4-truncated-nbinom2-nladder-20260807/` | `e25f7b482ee5add6c8071e96778cd0c7` |
| delta_lognormal | `…/va-s4-delta-lognormal-nladder-20260807/` | `/private/tmp/va-s4-delta-lognormal-nladder-20260807/` | `aec4b3b7c36ff37186097e61bfdeab87` |

Script: `lanes/va-s4-gh-hard/scripts/probe-s4-family-nladder.R` (extended)  
Launcher: `lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh`

Full jobs: truncnb2 done ~13:29:50; delta_ln done ~13:29:27. Raw: 72 arm-rows + header each (12×3×2).

## Summary tables (mean over finite β+Σ; 12 seeds)

### truncated_nbinom2 (zero-truncated NB2)

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.115 | 0.656 | 0.17 | 1.31 | 0.86× |
| 120 | gtmb_LA | 0.116 | 0.682 | 0.08 | 1.53 | 1.0× |
| 400 | gtmb_VA | 0.069 | 0.389 | **0.92** | 6.61 | 1.49× |
| 400 | gtmb_LA | 0.073 | 0.423 | 0.75 | 4.45 | 1.0× |
| 1000 | gtmb_VA | 0.043 | 0.220 | **1.00** | 42.3 | 4.15× |
| 1000 | gtmb_LA | 0.045 | 0.272 | **1.00** | 10.2 | 1.0× |

### delta_lognormal

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.099 | 0.588 | 0.58 | 2.50 | 8.0× |
| 120 | gtmb_LA | 0.102 | 0.553 | 0.67 | 0.31 | 1.0× |
| 400 | gtmb_VA | 0.055 | 0.269 | **1.00** | 4.46 | 7.1× |
| 400 | gtmb_LA | 0.054 | 0.260 | **1.00** | 0.63 | 1.0× |
| 1000 | gtmb_VA | 0.036 | 0.196 | **1.00** | 41.8 | 30.5× |
| 1000 | gtmb_LA | 0.037 | 0.197 | **1.00** | 1.37 | 1.0× |

No collapse / runaway on either cell (frac = 0). VA rows often report `status=failed_health_gate` (`n_healthy` = 0) while still returning finite β/Σ — same stricter gate pattern as other S4 VA cells; abs recovery uses the finite scores.

## Sibling cross-check (prior S4 wave)

| Cell | n=1000 VA Σ rf | n=1000 LA Σ rf | pass_abs @400 |
| --- | ---: | ---: | --- |
| truncated_poisson | 0.209 | 0.250 | VA 1.00 / LA 0.83 |
| **truncated_nbinom2** | **0.220** | **0.272** | **VA 0.92 / LA 0.75** |
| delta_gamma | 0.186 | 0.185 | both 1.00 |
| **delta_lognormal** | **0.196** | **0.197** | **both 1.00** |

## Verdict for Shinichi (ladder evidence only)

1. **Both sibling cells ran on Totoro** — registry `truncated_nbinom2` (fid 11) and `delta_lognormal` (fid 12); gllvm N/A.
2. **Σ recovers with n** for gtmb VA and LA on both — pass_abs → 1 by n=1000 (delta_ln already 1.00 at n=400).
3. **truncnb2:** VA has a mild abs/Σ edge (like ztpois / NB2); wall gap is small (≤4.2×). Prefer **VA** when abs Σ matters at mid-n; **LA** acceptable at n=1000 when both clear and speed matters.
4. **delta_lognormal:** VA ≈ LA on abs recovery; VA is **~30× slower** at n=1000. Prefer **LA**.
5. **No fence / `auto` flip.** Arc-1 merge not started (explicit B-only).

## Checks

```sh
FAMILY=truncated_nbinom2 ACTION=sync ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=delta_lognormal ACTION=sync ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=truncated_nbinom2 ACTION=smoke ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=delta_lognormal ACTION=smoke ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=truncated_nbinom2 PILOT_CORES=12 PROBE_N_SEED=12 ACTION=full \
  ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=delta_lognormal PILOT_CORES=12 PROBE_N_SEED=12 ACTION=full \
  ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=truncated_nbinom2 ACTION=pull ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
FAMILY=delta_lognormal ACTION=pull ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
```

Local 1-seed smokes also OK before Totoro. Deliberately not run: fence edits, Arc-1 merge/PR, package PASS claim.
