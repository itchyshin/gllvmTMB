# After Task: LA-MSPL private uncertainty-method admission

**Branch**: `codex/lane-b-mspl-interval-feasibility`  
**Date**: `2026-08-13`  
**Roles (engaged)**: Ada, Fisher, Rose

## 1. Goal

Admit or block two private fixed-effect uncertainty candidates for an ordinary
complete-Bernoulli q = 1 LA-MSPL fit: numerical curvature of the active
penalised outer objective and finite nuisance-reoptimised profile-threshold
brackets.

## 2. Implemented

`.gllvmTMB_mspl_penalized_hessian_diagnostic()` obtains a numerical outer
Hessian with `stats::optimHess()` from `fit$tmb_obj` after verifying
`estimator_id = 1`. `.gllvmTMB_mspl_profile_threshold_diagnostic()` extracts
only finite, converged linear threshold brackets from the existing penalised
profile trace. Both return typed diagnostics and are unexported.

## 4. Files Touched

- `R/mspl.R`: private numerical-Hessian and threshold-bracket helpers.
- `tests/testthat/test-mspl-api.R`: deterministic accepted and truncated-path
  tests, including a poisoned penalty-off objective.
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`:
  actuals.
- `docs/dev-log/check-log.md`: verification receipt.
- This report.

Status-inventory cascade: `README.md`, `NEWS.md`, `ROADMAP.md`, vignettes,
NAMESPACE, generated Rd, and pkgdown were intentionally unchanged: this is not
a public capability.

## 3a. Decisions and Rejected Alternatives

TMB's analytic Hessian is unavailable with random effects; the observed error
is retained as a seam fact. A numerical outer Hessian of the active penalised
objective was admitted as a private candidate. `sdreport()`, a sandwich
covariance, public `vcov()`/profile/`confint()`, and a calibration claim remain
rejected pending repeated-sampling evidence.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl-api", stop_on_failure = TRUE)'
git diff --check
rg -n "gllvmTMB_mspl_penalized_hessian_diagnostic|gllvmTMB_mspl_profile_threshold_diagnostic" NAMESPACE R tests/testthat
rg -n "gllvmTMB_mspl_(confint|profile|tmbprofile|vcov)|confint\\.gllvmTMB_mspl|profile_targets\\.gllvmTMB_mspl|tmbprofile_wrapper" R
```

The focused deterministic suite passed 268 expectations with no failures,
warnings, or skips in under one minute. `git diff --check` passed. The static
audit found the new helpers only in `R/mspl.R` and its test; no NAMESPACE entry
or public-fence change was present.

## 6. Tests of the Tests

The test is a deterministic feature-combination test: MSPL with random effects,
active-objective numerical curvature, nuisance reoptimisation, and a poisoned
penalty-off provenance objective. It also covers the boundary path where a
finite profile has no crossing in its fixed budget and therefore returns typed
`truncated` endpoints rather than an interval.

## 8. Consistency Audit

The exact static searches in Section 4 confirmed that the candidate helper
names are unexported and that public MSPL inference guards remain present.
No reader-facing wording changed, so package-wide stale-prose scans and pkgdown
builds were deliberately not run.

## 7. Roadmap Tick

N/A: no roadmap row changed; `MSPL-04` remains blocked pending calibration.

## 7a. Issue Ledger

Inspected open PRs #955--#960 before shared dev-log edits. None concerns this
private MSPL uncertainty seam; no issue was created or changed.

## 9. What Did Not Go Smoothly

The first implementation attempted `fit$tmb_obj$he()`. TMB reports that an
analytic Hessian is not implemented for models with random effects. A local
probe confirmed that `stats::optimHess()` on the same active outer objective is
finite and positive-definite for the deterministic fixture; the code and claim
were adjusted accordingly.

## 10. Known Residuals

The numerical outer Hessian is a curvature diagnostic only. It is not a
sampling covariance, and the profile threshold is not yet a likelihood-ratio
confidence rule. The TMB analytic-Hessian seam remains unavailable for random
effects. `MSPL-04` is therefore still blocked.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** separated method admission from calibration, avoiding premature
activation of a public uncertainty API.

**Fisher:** treats inverse penalised curvature and the chi-square profile
threshold as separate candidate procedures, neither of which is calibrated by
a finite deterministic trace.

**Rose:** required a poisoned provenance-objective test and an explicit public
fence audit so the retained penalty-off tape cannot silently enter a candidate.

## 12. Cross-Product Coverage

No public product surface changed. The new contract covers the ordinary
complete-Bernoulli q = 1, logit fixture only; it does NOT cover link/regime
transfer, repeated-sampling behaviour, calibrated uncertainty, other engines,
missingness, aggregation, or any public inference provider.

## 13. Known Limitations And Next Actions

This stage does not establish calibrated SEs, confidence intervals, coverage,
or generality beyond the deterministic ordinary q = 1 fixture. The next stage
is a seeded, failure-retaining operational pilot over prespecified DGP cells;
only its cost and availability outcomes determine whether a larger coverage
campaign is justified. Public MSPL inference remains fail-closed.
