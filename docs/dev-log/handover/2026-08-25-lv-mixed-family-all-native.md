# Codex Handover: Family-Wide Mixed-Family Predictor-Informed LV

Status: **PANEL-PASSED CHECKPOINT — review repairs and exact-source checks are
green at local checkpoint `312598984...`; the final 2-Terra/1-Sol panel passes.
Ordered PR #1214 integration, final reverify/validators, and lease release
remain.**

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
- Verified base:
  `499cc3f901f5b5d02962a3c5fb665bf69f2fc796`.
- Rebased candidate before closeout-only edits:
  `4a93d008da1006809e4a840b846886915c298702`.
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
- Authoritative final namespace-source local package check: 22m56.90s wall,
  0 errors, 0 warnings, 4 explicit notes. The earlier 82.56-second interrupted
  attempt, 20m54.71s logical-source pass, and 20m31.59s structural-source pass
  are retained separately.
- Final evaluated article and pkgdown checks: pass.
- Post-panel exact-shape and pre-drop missing-response repairs pass the live
  mixed-LV, complete LV, traits, and neighbouring missing-response suites.
- The retained Gaussian--multinomial cell now counts its complete $K-1$
  contrast expansion as one logical response; a live public canary and the
  neighbouring cross-family multinomial suite pass, while unexpanded duplicate
  family-16 traits remain rejected.
- Pre-expanded multinomial groups must also be contiguous and contain each
  contrast exactly once in a common order; planted duplicate-contrast and
  noncontiguous-group inputs now fail before fitting.
- Incidental columns named like multinomial metadata are ignored when no
  family-16 response is present; a planted Gaussian + Poisson control protects
  that namespace boundary.
- Two narrow mixed-LV local commits exist; no mixed-LV push, PR, merge, or
  release has occurred.

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

1. Wait for the ordered PR #1214 merge lane to return the exact merged-main SHA
   and shared-file lease receipt; do not edit or rebase before it arrives.
2. Rebase once, preserve both append-only check-log histories, and append the
   frozen 22m56.90s final-check receipt.
3. Run final Unlazy `--reverify`, after-task validator, Melissa reconciliation,
   and `handoff_gate.sh`; prove a clean tree and release the exact-path lease.
   Do not push this local-only lane.

## Protected boundaries

- GLLVM.jl is read-only and outside this lane.
- Do not admit arbitrary family combinations.
- Do not widen rank, default `Psi`, masks, missing/factor LV predictors, fixed
  `X + X_lv`, REML, source tiers, Julia, VA/AGHQ/MSPL, profile, or bootstrap.
- Raw `alpha`, raw `Lambda`, and signed raw scores are never cross-fit targets.
- Failed attempts and all-attempt denominators are immutable evidence.

## Landing classification

FINDINGS-OF-RECORD: none — the durable scientific and operational findings are
source-pinned in this repository's Design 73, source contract, retained
artifacts, after-task report, and check-log rather than a separate vault note.

- **DONE**: source contract, exact allow-list implementation, mixed/sentinel
  r200, pure r200, mixed r500 calibration, long/wide reader repair,
  focused/full tests, article, pkgdown, local check, current status cascade,
  and the final 2-Terra/1-Sol panel.
- **CARRIED-OVER**: ordered PR #1214 integration, final reverify, validators,
  check-log receipt, clean-tree proof, and lease release.
- **REJECTED**: duplicate campaigns, evidence-by-canary, arbitrary mixtures,
  remote compute above the approved envelope, GitHub Actions science compute,
  GLLVM.jl mutation, or umbrella Design 73 promotion.
