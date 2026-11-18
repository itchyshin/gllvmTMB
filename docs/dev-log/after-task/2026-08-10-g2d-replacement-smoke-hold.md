# After Task: G2d replacement local-smoke profile-map HOLD

**Branch**: `codex/isdm-g2d-six-species`  
**Date**: `2026-08-10`  
**Roles (engaged)**: Ada, Gauss, Rose

## 1. Goal

Run one authorised replacement G2d ordinary seed-86101 local smoke after P1
root preflight, then admit or hold the separate Totoro decision from retained
evidence.

## 2. Implemented

The smoke wrote all required root, fit, paired-map, restart, profile, metric,
and manifest receipts, then returned `G2D_SMOKE_HOLD`. Both arms stopped at a
false profile map guard before eligibility/metrics could be assessed. Exact
TMB-map indexing repaired that guard and a method reviewer confirmed the
diagnosis; no second smoke was run.

Mathematical contract: no DGP, estimand, target, likelihood, public API,
family, formula grammar, or public documentation changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: hold Totoro and do not reinterpret the retained fit. **Rationale**:
  profiles did not execute, so no numerical admission evidence exists.
  **Rejected alternative**: treating convergence or retained fit objects as a
  smoke PASS. **Confidence**: high.
- **Decision**: repair exact map lookup but do not rerun. **Rationale**: the
  smoke allowance was one attempt. **Rejected alternative**: silently consume a
  second seed after a harness repair. **Confidence**: high.

## 4. Files Touched

- Private runner/test: `dev/isdm-package-recovery/run-g2d-six-species-recovery.R` and `tests/testthat/test-g2d-six-species-harness.R`.
- Private decision: `dev/isdm-package-recovery/2026-08-10-g2d-smoke-decision.md`.
- Closure: this report, P3 checkpoint, plan-vs-actual reconciliation, and
  `docs/dev-log/check-log.md`.
- Untouched: public R/src, README, NEWS, ROADMAP, vignettes, Rd, pkgdown,
  Totoro, campaign fixtures, empirical data, and Issue #953.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=smoke --scenario=ordinary --replicate=1 --output=dev/isdm-package-recovery/results/g2d-smoke-20260810-210000 --pkg="$PWD" --campaign-sha=621eb94c8a2a3dc631a620926736af1be9eb3f72
# HOLD: G2D_SMOKE_HOLD.

Rscript --vanilla -e '<read retained result; inspect status/detail/map/manifest>'
# PASS: every required retained artifact has a non-empty hash; both arms detail
# the same partial-match profile error.

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: 17 expectations; no fit.
```

No Totoro, panel, comparator, spatial, count, empirical, or public command ran.

## 6. Tests of the Tests

The exact-indexing assertion is a failure-before-fix regression: it prevents
R from partially matching `theta_diag_B_slope` when the exact free
`theta_diag_B` map is absent.

## 7a. Issue Ledger

No issue was inspected, commented, created, or updated. Issue #953 remains out
of scope.

## 8. Consistency Audit

```sh
rg -n 'theta_diag_B.*exact|G2D_SMOKE_(PASS|HOLD)' dev/isdm-package-recovery tests/testthat
```

Verdict: the runner, protocol, dormant Totoro launcher, and test use the same
G2D smoke labels; the exact map lookup is explicit.

## 9. What Did Not Go Smoothly

P1 checked root serialisation but did not exercise the profiler's map lookup.
The replacement smoke therefore spent its allowance discovering the remaining
partial-match defect. The error was retained with its fit objects and is not
relabelled as an estimator result.

## 10. Known Residuals

No valid G2d smoke, recovery panel, Totoro admission, or Paper-2 numerical
evidence exists. A future smoke must have new explicit authority.

## 11. Team Learning

**Gauss** identified the R partial-match mechanism and verified that exact
`NULL` means a free coordinate. **Rose** required the HOLD to remain separate
from a numerical recovery claim and barred an automatic retry.

## 12. Cross-Product Coverage

This phase does NOT cover a successful profile, eligibility, recovery,
campaign, remote compute, empirical data, count/comparator/spatial/source
admission work, detection, absolute intensity, public API/docs, or Issue #953.
