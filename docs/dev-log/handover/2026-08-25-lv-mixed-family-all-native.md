# Codex Handover: Family-Wide Mixed-Family Predictor-Informed LV

Status: **REVIEW REPAIRS IN PROGRESS — retained campaigns are adjudicated;
the first frozen panel found bounded guard, provenance-test, and receipt
defects that must pass re-review before landing.**

## Goal

Finish the exact native ordinary rank-1, loadings-only, complete-response
family-wide predictor-informed LV programme. Do not widen it to arbitrary
mixtures or any deferred Design 73 surface.

## First reads

1. `AGENTS.md`
2. `docs/dev-log/plans/2026-08-25-lv-mixed-family-all-native-ultra-plan.md`
3. `.unlazy/lv-mixed-family-all-native/checkpoint.md`
4. `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-source-contract.md`
5. `docs/dev-log/after-task/2026-08-25-lv-mixed-family-all-native.md`
6. `docs/dev-log/plan-actual/2026-08-25-lv-mixed-family-all-native.md`

## Current state

- Branch: `codex/lv-mixed-family-all-native`.
- Campaign source HEAD:
  `7dd5eec733c42c722fe94be4c0e5a2efe1f4a3c3`.
- Final transfer bundle:
  `.unlazy/lv-mixed-family-all-native/source-snapshot-v4-shallow-20260825-01.tar.gz`.
- Bundle SHA-256:
  `d295bf14cae6e26036107f181bd2b3ff407303f783122c5127c7eb2da61dcd02`.
- Mixed/sentinel r200: complete, 3,800/3,800 retained, all 19 point gates pass.
- Pure r200: complete, 3,800/3,800 retained, 17 PASS and two honest HOLDs.
- Mixed r500 calibration: complete, 4,000/4,000 retained, 3,999 interval
  eligible, all eight target-wise Wald gates pass.
- Final-candidate full tests: exit 0, testthat `DONE`.
- Local package check: 0 errors, 0 warnings, 4 explicit notes.
- Evaluated article and pkgdown checks: pass.
- No mixed-LV commit, push, PR, merge, or release yet.

## Resolved remote blocker

The existing socket is present at
`/Users/z3437171/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22`, but the managed
sandbox returns:

```text
Control socket connect(...): Operation not permitted
ssh: Could not resolve hostname totoro.biology.ualberta.ca
```

This occurred before any remote command. The fail-closed overnight operator
completed 285/285 exact-socket probes from
`2026-08-26T06:20:22Z` through `2026-08-26T11:06:52Z`; every probe returned
`Operation not permitted`. It exited 72, issued zero remote commands, started
zero fits, and created no result bundle. Later explicitly approved escalated
access attached through that exact existing socket and completed both campaigns.
The first two remote launch failures (missing `artifacts/` for redirection, then
AppleDouble `._gllvmTMB.cpp` compilation) remain preserved as zero-attempt
failures. The successful Linux extraction removed only AppleDouble metadata and
passed the exact source manifest.

## Approved compute

The maintainer approved both exact campaigns:

- `APPROVE TOTORO PURE-LV R200 RECOVERY: 40 WORKERS, 3,800 ATTEMPTS`
- `APPROVE TOTORO MIXED-LV R500 CALIBRATION: 40 WORKERS, 4,000 ATTEMPTS`

Both use 40 one-thread workers, remain below the 150-core cap, preserve every
attempt, and stop the complete process group at 1,800 seconds. Do not change
the grids, seeds, thresholds, or source identity. Do not use GitHub Actions,
DRAC, or a duplicate local campaign.

## Final landing sequence

1. Run lane preflight and confirm no exact-path collision. The lease registry
   may still be unwritable from a managed sandbox; record that honestly.
2. Reconcile `origin/main` without changing the historical campaign source
   receipt. Re-run affected focused tests, docs, pkgdown, local package check,
   stale scans, and exact-head CI as required.
3. Run final Unlazy `--reverify`, the exact 2-Terra/1-Sol panel, Rose/Grace
   review, after-task validator, Melissa reconciliation, `handoff_gate.sh`, a
   narrow local commit, clean-tree proof, and lease release.

## Protected boundaries

- GLLVM.jl is read-only and outside this lane.
- Do not admit arbitrary family combinations.
- Do not widen rank, default `Psi`, masks, missing/factor LV predictors, fixed
  `X + X_lv`, REML, source tiers, Julia, VA/AGHQ/MSPL, profile, or bootstrap.
- Raw `alpha`, raw `Lambda`, and signed raw scores are never cross-fit targets.
- Failed attempts and all-attempt denominators are immutable evidence.

## Landing classification

- **DONE**: source contract, exact allow-list implementation, mixed/sentinel
  r200, pure r200, mixed r500 calibration, long/wide reader repair,
  focused/full tests, article, pkgdown, local check, current status cascade,
  and preparatory reviews.
- **CARRIED-OVER**: origin/main integration, exact-head verification,
  completion panel, reverify, validators, commit, and lease release.
- **REJECTED**: duplicate campaigns, evidence-by-canary, arbitrary mixtures,
  remote compute above the approved envelope, GitHub Actions science compute,
  GLLVM.jl mutation, or umbrella Design 73 promotion.
