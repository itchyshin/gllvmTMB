# After-task — Poisson MSPL W_* REPLACE

**Date:** 2026-08-17  
**Branch:** `cursor/mspl-poisson-W-REPLACE-impl`  
**Worktree:** `~/local-scratch/lanes/gllvmTMB-mspl-poisson-W-REPLACE`  
**Authority:** G0 SIGNED REPLACE (#1102); Shinichi preapprove-all for ship.

## Outcome

Live Poisson MSPL GLM-outer weight (`family_id == 2`) is now working
logistic \(W_*\) via `return gll_mspl_log_weight(eta, 0)` (Tweedie
precedent). Twin R Jeffreys, #1064 W2/W7/W8, admit A6/A7, registry notes,
and `docs/design/03-likelihoods.md` rematched. Local multi-seed recovery
PASS. Experimental `admitted` kept (rematch green). **No** public SE /
NEWS covered / undraft #1077.

## Checks

- Smoke `se=FALSE`: class `gllvmTMB_mspl`, `convergence=0`, status admitted
- `devtools::test(filter="mspl-W-onesided|mspl-poisson-admit|mspl-poisson-phase4|mspl-poisson-W-REPLACE")` → **243 pass / 0 fail**
- `devtools::test(filter="mspl-api")` → **293 pass / 0 fail**
- `--as-cran` + vignettes: **deferred** (cut order if late)

## Hard OUT audit (untouched)

- public se/vcov/confint; undraft #1077; Totoro / Design 118 / Lane B / #1090
- KF2021 beyond binomial; NEWS covered; git add -A; isdm-package-recovery

## Soft-gate defaults applied

- Admit: keep experimental admitted (rematch green)
- #1077 stays draft; Design 125 fork smoke not invented; SE doors PREP notes only

## Follow-up

- CI green → merge (preapproved)
- Morning optional: which SE-series *prep* packet next (still no public se)
