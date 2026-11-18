# After-task — Poisson MSPL W_* REPLACE

**Date:** 2026-08-17  
**Branch:** `cursor/mspl-poisson-W-REPLACE-impl`  
**Worktree:** `~/local-scratch/lanes/gllvmTMB-mspl-poisson-W-REPLACE`  
**Authority:** G0 SIGNED REPLACE (#1102); Shinichi preapprove-all for ship.  
**Merged:** PR [#1111](https://github.com/itchyshin/gllvmTMB/pull/1111) into
`main` at merge commit **`3053fce3`**, 2026-08-18 00:36 UTC, with
`R-CMD-check` ubuntu-latest (release) **SUCCESS**.

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
- Private `/tmp` install re-verify: `filter="mspl-api"` → **293/0**; `filter="mspl"` → **2079/0/19skip**; A4 recovery → **22/0**
- Local multi-seed point smoke (not Totoro): **32/32** MSPL conv0+finite; TSV+note `docs/dev-log/research/2026-08-17-mspl-poisson-W-REPLACE-point-smoke.*` (script `OPERATIONAL_SMOKE` still requires `planned`; REPLACE keeps experimental `admitted`)
- `--as-cran` + vignettes (local): **Status: 2 NOTEs** (0E/0W); vignettes rebuilt OK; also PR #1111 CI

## Hard OUT audit (untouched)

- public se/vcov/confint; undraft #1077; Totoro / Design 118 / Lane B / #1090
- KF2021 beyond binomial; NEWS covered; git add -A; isdm-package-recovery

## Soft-gate defaults applied

- Admit: keep experimental admitted (rematch green)
- #1077 stays draft; Design 125 fork smoke not invented; SE doors PREP notes only

## Closeout (2026-08-18)

CI came back green and the PR merged under preapprove-all. Each arc was then
re-verified against the merged tree rather than against the earlier claim:
`src/gllvmTMB.cpp:293-299` returns `gll_mspl_log_weight(eta, 0)` for
`family_id == 2`; W2/W7/W8 are present in
`tests/testthat/test-mspl-W-onesided-oracles.R`; the twin in
`R/mspl-poisson-atoms.R` computes `W_* = mu_*(1-mu_*)` from `eta`;
`R/mspl-registry.R` names the REPLACE in its notes;
`tests/testthat/test-mspl-poisson-W-REPLACE-recovery.R` exists;
`docs/design/03-likelihoods.md:675` carries the working-logistic row; and the
family-door PREP note is in `docs/dev-log/research/`. A0–A8 are DONE and the
LOOP state is **GOAL_MET**.

One coordination note for whoever picks up MSPL next: `LOOP/` is shared, and
the foreign lane `claude/lane-mspl-profile-led-ci` still carries a
*"Poisson W UNSIGNED"* version of `LOOP/GOAL.md` / `arcs.md` / `checkpoint.md`
from before #1102 was signed. That lane's LOOP text is stale against `main`,
but it is not this lane's to rewrite — it needs the owner, or Shinichi.

## Follow-up

- Merged; nothing outstanding in this LOOP
- Morning optional: which SE-series *prep* packet next (still no public se)
