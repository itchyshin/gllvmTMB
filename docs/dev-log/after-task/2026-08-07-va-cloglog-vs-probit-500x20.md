# After-task: 500×20 cloglog vs probit GH (abs Σ)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Outcome:** cloglog GH does **not** beat probit GH at n=500 p=20; prefer probit + our GH for users.

## Scope

- Head-to-head Totoro probe, 12 shared seeds, Design-110 DGP, H=7, unique=FALSE
- Arms: gtmb cloglog GH, gtmb probit GH (+ LA both links)
- PoisG ladder reused (collapse at all n; not a candidate)
- Fence / `auto` untouched

## Artefacts

- Audit: `docs/dev-log/audits/2026-08-07-va-binomial-500x20-cloglog-vs-probit.md`
- Scripts: `lanes/va-s1-binomials/scripts/probe-binomial-500x20-cloglog-probit-h2h.R`,
  `launch-totoro-s1-500x20-cloglog-probit-h2h.sh`; cloglog support in
  `probe-binomial-500x20-probit-smoke.R`
- Check-log one-liner under 2026-08-07

## Checks

- Totoro H2H completed (pid 2754426); probit-only job (2753035) left alone and also finished
- No package tests required (docs/scripts measurement only)

## Follow-up

None blocking. User story remains: probit + GH; cloglog supported but not the pitch.
