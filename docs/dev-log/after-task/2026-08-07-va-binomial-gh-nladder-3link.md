# After-task — binomial GH n-ladder (logit × probit × cloglog)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Lane:** `lanes/va-s1-binomials`  
**Scope:** Measurement-only large-N ladder for three binomial links. No fence change. Logit GH fix remains parked.

## Outcome

- Reused `/private/tmp/va-s1-binomial-gh-nladder-20260807/` (logit+probit already complete).
- Extended `probe-binomial-gh-nladder.R` for **cloglog** (GH+LA+gllvm; `PROBE_APPEND=1`).
- Grid: n∈{120,400,1000}, p=8, q=2, trials=1, unique=FALSE, H=7, seeds `10901:10912`, 8 cores.
- Audit: `docs/dev-log/audits/2026-08-07-va-binomial-gh-nladder.md`.

## Headline numbers (GH)

| link | n=120 β/Σ/pass | n=1000 β/Σ/pass |
| --- | --- | --- |
| logit | 0.225 / 5.58 / 0 | 0.058 / 1.13 / **0** |
| probit | 0.129 / 2.03 / 0 | 0.038 / 0.44 / **0.58** |
| cloglog | 0.158 / 1.86 / 0 | 0.046 / 0.47 / **0.67** |

Large N clears abs Σ for **probit and cloglog** GH; **logit GH still fails** abs — park stands (use JJ).

## Checks

- Local cloglog append: 144 new rows → 504 total in `seed-rows-long.csv`.
- Summary regenerated; paired Δ vs gllvm includes cloglog.
- No `R/` / `src/` / fence edits.
- Print crash on unicode `β` in summary cat fixed to ASCII (data already written before crash).

## Follow-up

- G0: nbinom dig vs Totoro S1 — not logit-GH rescue.
- Optional: copy combined CSVs into lane `results/` if Shinichi wants them in-repo (currently D-50 local `/private/tmp/...` only).
