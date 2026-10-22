# Preparation checkpoint

Date: 2026-08-28  
Branch: `codex/isdm-evidence-map-closure`  
Worktree: `/private/tmp/gllvmtmb-isdm-evidence-map-closure`  
Baseline: `origin/main` at `1a3b0d161781468a3e647cb9b717eb1635e20730`

## Completed

- reconciled shipped behavior, stale wording, negative evidence, and protected
  paths;
- froze public nonspatial and rank-one SPDE equations and rotation-invariant
  estimands;
- generated exact immutable plans for 1,600 promotion attempts, 200 stress
  attempts, 800 spatial attempts, and 4,800 interval attempts;
- retained distinct attempt seeds and paired structural seeds for full/weak
  comparisons;
- implemented public-route fixtures, source/mesh truth, whole-coordinate
  holdout, all-NA refusal, atomic started/terminal records, exact source and
  loaded-binary identity, denominator reconciliation, and frozen adjudicators;
- hardened the retained-record path with exclusive no-replace locks, immediate
  started receipts, phase-aware terminal validation, one exact v2 source
  contract per adjudication, and explicit eligible denominators;
- made source qualification consume independently verified exact-head
  three-OS CI plus an install receipt binding the source SHA/tree, every
  installed package-file hash, and the loaded DLL hash;
- made the 38-fit pre-run manifest directly executable while preserving its
  ordinary, attack, spatial, and interval routes outside production seeds;
- added deterministic tests for source laws/masks, covariance packing,
  effort-free links, interruption/unavailability, warning retention, invalid
  terminals, target availability, stress separation, species-wise Wilson
  intervals, type-1 transforms, and typed out-of-hull warnings.
- preregistered coefficient applicability (1,600 common targets and 800
  three-source-only targets), exact receipt-vs-plan identity, separate neutral
  map and source-dispatch grids, and stress degradation summaries.
- passed independent specification and code-quality reviews after adversarial
  repair; the final quality review reported no P0--P3 findings.

## Fresh verification

```text
Rscript --vanilla -e 'devtools::test(filter = "isdm-requalification",
  reporter = "summary", stop_on_failure = TRUE)'
=> DONE, 0 failures

Rscript --vanilla dev/isdm-requalification/verify-preparation.R all
=> ISDM_INVENTORY_VERIFIED
=> ISDM_ALIGNMENT_VERIFIED
=> ISDM_MANIFEST_VERIFIED

git diff --check
=> clean
```

Non-claim-bearing timings on the baseline:

- nonspatial public fit: convergence 0, finite total Sigma, 180/180 finite
  scoring predictions, 1.974 seconds;
- 64-cell SPDE public fit: convergence 0, finite 72/72 held-out predictions,
  2.028 seconds.

## Blocking gates

1. **Maintainer amendment approval.** Sol requires five corrections to the
   originally approved adjudication: per-target availability at least 0.85,
   stress-only disconnected support, whole-coordinate holdout, species-wise
   Wilson gates, and type-1 interval quantiles.
2. **Coefficient lease.** `codex:structured-column-coef-family` still owns the
   shared R/API, NEWS, register, pkgdown, and closeout paths.
3. **G5 source-observation prediction defect.** The SPDE field reconstructs to
   `1.11e-16`, but the newdata fixed design omits three source-observation
   columns and fails training identity by `1.101235`. See the terminal receipt.
4. **G6 source qualification.** After the coefficient series and the focused
   prediction repair land with green three-OS CI, install exact main and run
   `qualify-source.R`; any later identity drift invalidates the packet.

No 14-fit pre-run, 2,600-attempt point campaign, interval implementation, or
4,800-attempt calibration has started. Production denominators remain zero.

## Next safest action

After maintainer approval and shared-path release, rebase on exact green main,
acquire the narrow prediction/shared-document lease, write a failing
source-observation `newdata = training` regression test, repair the fixed-design
reconstruction, rerun package tests and three-OS CI, then qualify the immutable
source before any retained pre-run.
