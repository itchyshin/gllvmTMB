# S4 GH-hard / hybrid n-ladders — admission + results

**Date:** 2026-08-07  
**Authority:** Shinichi — “also run tweedie, student, truncated, ordinal, and delta n-ladders on Totoro — why not.” Standing Totoro permission. Parallel OK with beta/betabinomial; did not kill.  
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families`  
**Estimator rev:** confirmation `022b4eab` (Totoro checkout).  
**D-50:** raw CSVs on Totoro + `/private/tmp` only — not git-staged.  
**Claim level:** **ladder evidence only** — do **not** claim package PASS/FAIL or flip fence/`auto`.

## Admission (Design 110 / Gate E / ultraplan)

| Ask | Registry cell | VA route | Verdict | Arms |
| --- | --- | ---: | --- | --- |
| **tweedie** | fid 6 / log | GH | **STARTED → DONE** | gtmb VA+LA; gllvm LA; gllvm VA @ n=120 |
| **student** | fid 9 / identity | GH | **STARTED → DONE** | gtmb VA+LA (no gllvm Student-t) |
| **truncated** | fid **10** `truncated_poisson` | GH | **STARTED → DONE** | gtmb VA+LA only |
| **ordinal** | fid 14 `ordinal_probit` | GH | **STARTED → DONE** | gtmb VA+LA; gllvm VA all n |
| **delta** | fid **13** `delta_gamma` | HYBRID | **STARTED → DONE** | gtmb VA+LA only |
| multinomial | — | not implemented | **SKIPPED** | ultraplan OUT |
| truncated_nbinom2 | fid 11 | GH | **DONE in sibling wave** | see `2026-08-07-va-truncnb2-delta-ln-nladder.md` |
| delta_lognormal | fid 12 | HYBRID | **DONE in sibling wave** | see `2026-08-07-va-truncnb2-delta-ln-nladder.md` |

### “truncated” clarification

Design 110 / `truncated_poisson()` = **zero-truncated Poisson** (positive counts; no zeros) — **not** Tobit / truncated-Gaussian. gllvm ZIP is a different model → no gllvm arm.

## Design (shared)

- Loadings-only (`Σ=ΛΛ'`, `unique=FALSE`), `p=8`, `q=2`
- **n ∈ {120, 400, 1000}**; seeds `11401:11412` (12); `n_starts=1`; `se=FALSE`; warm DLL
- Abs caps (reported only): β ≤ 0.35 ; Σ rf ≤ 0.50
- Totoro 10 cores × 5 jobs; ordinal VA metadata fix mid-flight (NULL cut inference)

## Roots + MD5 (`ladder-summary.csv`)

| Family | Totoro | Local | MD5 |
| --- | --- | --- | --- |
| tweedie | `…/va-s4-tweedie-nladder-20260807/` | `/private/tmp/va-s4-tweedie-nladder-20260807/` | `eadef84804aa58e186b837457195efbb` |
| student | `…/va-s4-student-nladder-20260807/` | `/private/tmp/va-s4-student-nladder-20260807/` | `d6c5c52f3e17404a52055c18c278db5d` |
| truncated_poisson | `…/va-s4-truncated-poisson-nladder-20260807/` | `/private/tmp/va-s4-truncated-poisson-nladder-20260807/` | `b3f6427af0dc15a965f76ad19c31b007` |
| ordinal_probit | `…/va-s4-ordinal-probit-nladder-20260807/` | `/private/tmp/va-s4-ordinal-probit-nladder-20260807/` | `6df52b752a5ef22c4385bace07e1812f` |
| delta_gamma | `…/va-s4-delta-gamma-nladder-20260807/` | `/private/tmp/va-s4-delta-gamma-nladder-20260807/` | `005c72d927ebde5ebca3f72b914c8426` |

Script: `lanes/va-s4-gh-hard/scripts/probe-s4-family-nladder.R`  
Launcher: `lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh`

## Summary tables (mean over finite β+Σ; 12 seeds)

### tweedie

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.099 | 0.506 | 0.50 | 4.06 | 13.6× |
| 120 | gtmb_LA | 0.098 | 0.522 | 0.42 | 0.30 | 1.0× |
| 120 | gllvm_LA | 0.243 | 1.454 | 0.00 | 2.71 | 9.0× |
| 120 | gllvm_VA | 0.234 | 1.335 | 0.00 | 3.15 | 10.5× |
| 400 | gtmb_VA | 0.046 | 0.244 | **1.00** | 18.3 | 23.5× |
| 400 | gtmb_LA | 0.046 | 0.247 | **1.00** | 0.78 | 1.0× |
| 400 | gllvm_LA | 0.175 | 1.135 | 0.00 | 4.66 | 6.0× |
| 1000 | gtmb_VA | 0.030 | 0.155 | **1.00** | 74.0 | 45.7× |
| 1000 | gtmb_LA | 0.030 | 0.158 | **1.00** | 1.62 | 1.0× |
| 1000 | gllvm_LA | 0.177 | 1.124 | 0.08 | 9.50 | 5.9× |

### student

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.094 | 0.632 | 0.33 | 0.35 | 2.2× |
| 120 | gtmb_LA | 0.094 | 0.549 | 0.50 | 0.16 | 1.0× |
| 400 | gtmb_VA | 0.054 | 0.335 | 0.92 | 3.55 | 10.1× |
| 400 | gtmb_LA | 0.054 | 0.336 | **1.00** | 0.35 | 1.0× |
| 1000 | gtmb_VA | 0.032 | 0.196 | **1.00** | 37.9 | 52.3× |
| 1000 | gtmb_LA | 0.032 | 0.231 | **1.00** | 0.72 | 1.0× |

### truncated_poisson (zero-truncated Poisson)

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.144 | 0.701 | 0.08 | 0.38 | 1.7× |
| 120 | gtmb_LA | 0.156 | 0.767 | 0.00 | 0.23 | 1.0× |
| 400 | gtmb_VA | 0.076 | 0.344 | **1.00** | 3.58 | 5.9× |
| 400 | gtmb_LA | 0.080 | 0.394 | 0.83 | 0.61 | 1.0× |
| 1000 | gtmb_VA | 0.042 | 0.209 | **1.00** | 31.1 | 21.9× |
| 1000 | gtmb_LA | 0.044 | 0.250 | **1.00** | 1.42 | 1.0× |

### ordinal_probit

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.125 | 1.211 | 0.00 | 2.47 | 2.7× |
| 120 | gtmb_LA | 0.124 | 1.080 | 0.00 | 0.92 | 1.0× |
| 120 | gllvm_VA | 0.108 | 0.796 | 0.00 | 0.15 | 0.17× |
| 400 | gtmb_VA | 0.066 | 0.668 | 0.00 | 12.5 | 4.3× |
| 400 | gtmb_LA | 0.065 | 0.549 | 0.50 | 2.94 | 1.0× |
| 400 | gllvm_VA | 0.061 | 0.816 | 0.00 | 0.69 | 0.23× |
| 1000 | gtmb_VA | 0.042 | 0.393 | 0.92 | 60.2 | 8.0× |
| 1000 | gtmb_LA | 0.042 | 0.361 | **1.00** | 7.49 | 1.0× |
| 1000 | gllvm_VA | 0.039 | 0.814 | 0.00 | 8.30 | 1.1× |

### delta_gamma

| n | arm | β RMSE | Σ rf | pass_abs | secs | vs LA |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 120 | gtmb_VA | 0.119 | 0.551 | 0.42 | 0.92 | 3.4× |
| 120 | gtmb_LA | 0.117 | 0.548 | 0.33 | 0.27 | 1.0× |
| 400 | gtmb_VA | 0.055 | 0.260 | **1.00** | 5.72 | 12.1× |
| 400 | gtmb_LA | 0.054 | 0.260 | **1.00** | 0.47 | 1.0× |
| 1000 | gtmb_VA | 0.037 | 0.186 | **1.00** | 43.1 | 36.7× |
| 1000 | gtmb_LA | 0.036 | 0.185 | **1.00** | 1.17 | 1.0× |

## Verdict for Shinichi (ladder evidence only)

1. **All five Design-110 cells ran.** Multinomial correctly skipped; truncated = ztpois; delta = delta_gamma.
2. **Σ recovers with n** for gtmb VA and LA on tweedie / student / truncated_poisson / delta_gamma — pass_abs → 1 by n=400 or 1000.
3. **Ordinal is hardest:** abs Σ only clears at n=1000 (VA 0.92 / LA 1.00); gllvm VA stays ~0.8 Σ rf and never passes abs.
4. **Tweedie gllvm LA/VA look poorly calibrated on this DGP** (Σ rf ≳ 1.1 even at n=1000) vs gtmb arms at ~0.16 — comparator caveat, not a gtmb fence flip.
5. **VA is much slower than LA** at large n (often 20–50×) for similar abs recovery when both clear — prefer LA for speed on these cells unless VA wins abs (as on NB2).
6. **No fence / `auto` flip.**

## Checks

```sh
for fam in tweedie student truncated_poisson ordinal_probit delta_gamma; do
  FAMILY=$fam ACTION=sync ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
  FAMILY=$fam ACTION=full PILOT_CORES=10 PROBE_N_SEED=12 PROBE_N_GRID=120,400,1000 \
    ./lanes/va-s4-gh-hard/scripts/launch-totoro-s4-nladder.sh
done
# ordinal: mid-run kill+relaunch after NULL cut-metadata fix (other jobs untouched)
```

Deliberately not run (this wave): fence edits, multinomial, package PASS claim.
Sibling wave (truncnb2 + delta_ln) landed same day — see
`docs/dev-log/audits/2026-08-07-va-truncnb2-delta-ln-nladder.md`.
