# After Task: LA-MSPL private uncertainty-candidate pilot

**Branch**: `codex/lane-b-mspl-interval-feasibility`  
**Date**: `2026-08-13`  
**Roles (engaged)**: Ada, Fisher, Curie, Rose

## 1. Goal

Measure availability and repeated-sampling behaviour of private active-objective
Hessian and profile candidates before any public MSPL uncertainty promotion.

## 2. Implemented

A seeded, failure-retaining four-cell pilot ran to completion with private
penalised-Hessian and nuisance-reoptimised profile candidates only.

## 3a. Decisions and Rejected Alternatives

Low-prevalence cloglog failures remain retained procedure outcomes. Wald
substitution, grid expansion, bootstrap, and public-method promotion were
rejected.

## 4. Files Touched

- `inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R`: seeded runner with
  atomic per-replicate receipts.
- `docs/dev-log/check-log.md` and Arc actuals: campaign receipt.
- This report.

No README, NEWS, roadmap, NAMESPACE, exported API, generated Rd, vignette, or
pkgdown surface changed.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'
Rscript --vanilla inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R prepare ...
Rscript --vanilla inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R run ...
Rscript --vanilla inst/sim/lane-b-uncertainty/run-mspl-uncertainty.R summarise ...
git diff --check
```

The Totoro campaign completed four fixed 100-replicate cells and wrote exactly
400 atomic receipts / 1,200 target rows. The private summary retains every
attempt. Focused MSPL tests were passed before campaign launch.

## 6. Tests of the Tests

The runner uses deterministic seed keys, planted fixed-effect truth, and a
poisoned penalty-off objective test in `test-mspl-api.R`. Atomic receipts were
exercised when local foreground runs were interrupted; completed attempts were
retained instead of discarded.

## 7a. Issue Ledger

Inspected open PRs #955--#960 before shared-log edits; none owns this private
MSPL uncertainty pilot. No issue was created or changed.

## 8. Consistency Audit

`rg -n "gllvmTMB_mspl_penalized_hessian_diagnostic|gllvmTMB_mspl_profile_threshold_diagnostic" NAMESPACE R tests/testthat` confirmed both helpers remain unexported.
`rg -n "confint.*mspl|profile_targets.*mspl|tmbprofile_wrapper.*mspl" R` confirmed public refusals remain present.

## 9. What Did Not Go Smoothly

The isolated Totoro source initially carried macOS build artefacts, then hit a
staged-install lazy-load failure. A non-staged exact-source Linux install
resolved it. These setup faults produced no campaign evidence.

## 10. Known Residuals

The 100-replicate pilot has wide Monte Carlo uncertainty and is not a
calibrated-coverage study. The low-prevalence cloglog profile candidate has
substantial nonavailability and poor unconditional coverage; no public profile
or confidence interval can be promoted.

## 11. Team Learning

**Fisher:** availability must be reported jointly with coverage; conditional
coverage cannot erase failed profile attempts.

**Curie:** atomic receipts make an interrupted campaign auditable.

**Rose:** the penalty-off provenance tape remains excluded and public MSPL
inference stays fail-closed.

## 12. Cross-Product Coverage

This work covers private ordinary complete-Bernoulli q = 1 fixed effects under
four named DGPs. It does NOT cover q = 2, spatial/phylogenetic effects,
missingness, aggregation, bootstrap, calibrated inference, or any public
provider.

## 13. Next Actions

Treat the low-prevalence cloglog profile result as a typed blocker. A larger
coverage campaign may assess the Hessian candidate only if separately designed;
this pilot does not authorize public SE/CI methods.
