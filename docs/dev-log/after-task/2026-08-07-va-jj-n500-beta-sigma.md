# After-task — logit JJ quality at n=500 (β + Σ)

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Branch:** `codex/va-gh-all-families`

## Scope

Measurement-only: how good is **JJ** on β and Σ at **n=500** (binomial logit,
p=8, q=2, unique=FALSE, H=7, 12 seeds), vs GH (ours), gllvm VA, and LA arms.
No fence flip. Logit GH fix stays parked.

## Outcome

- Script tweak: `PROBE_GLLVM_START=zero|default` on
  `lanes/va-s1-binomials/scripts/probe-binomial-gh-nladder.R`
- Results: `/private/tmp/va-s1-binomial-jj-n500-20260807/` (wall 101 s, 8 cores)
- Audit: `docs/dev-log/audits/2026-08-07-va-jj-n500-beta-sigma.md`

### Verdict (short)

| Question | Answer |
| --- | --- |
| JJ good on β @ n=500? | **YES** (RMSE 0.090) |
| JJ good on Σ (abs ≤0.50)? | **NO** (rf 0.95; pass_abs 0) — improving vs n=400 |
| vs GH? | **JJ wins Σ** (dΣ≈−1.0; runaway 0 vs 0.83) |
| vs gllvm VA? | **JJ usable; gllvm VA collapses Σ̂** (even default starts) |
| vs LA? | β tied; gllvm LA slightly better Σ |

## Checks

- Local probe only; no `R/` / `src/` / fence edits in this slice.
- Prior ladder n∈{400,1000} consistent with n=500 interpolation.

## Follow-up

- None required for JJ-at-500. Logit GH fix remains PARKED.
- Optional: larger n if abs Σ pass rate is the next bar (n=1000 JJ pass≈0.08).
