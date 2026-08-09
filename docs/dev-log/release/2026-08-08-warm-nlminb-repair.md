# Narrow warm-`nlminb` repair receipt

Date: 2026-08-08  
Owner: Gauss (TMB/numerical lane)  
Scope: native-Laplace default `nlminb` point estimation only  
Bounded result: **IMPLEMENTED; FOCUSED AND RELEVANT REGRESSIONS PASS**  
Release result: **HOLD pending stable-source full-suite review and v4 evidence**

## Change

`R/fit-multi.R` now performs at most one warm PORT pass when, and only when,
the first native-Laplace `nlminb` result has code zero, a finite objective and
AD gradient, a positive-definite Hessian, a present empty character boundary
vector, and raw maximum gradient at or above the unchanged `0.01` gate. AGHQ
must be exactly unused (`identical(aghq_used, FALSE)`), and the Laplace ridge
must be absent.

The warm pass uses the same objective, AD gradient, parameter order, bounds,
scale, and control list. It is accepted only when its diagnostics are fully
present and well typed, it retains code zero, finite objective and gradient,
positive-definite Hessian and no boundary, it strictly improves raw maximum
gradient, and its objective is no worse than

```text
objective_before + 64 * .Machine$double.eps *
  max(1, abs(objective_before)).
```

Otherwise the original optimizer result, report, `sdreport`, fit health,
restart history, and TMB `last.par`/`last.par.best`/`value.best` checkpoint are restored.
No likelihood, estimand, parameter transformation, optimizer default, or
`0.01` health threshold changed.

Every fit records the exact 13-field v4 provenance contract under
`fit$warm_restart_provenance`:

- `warm_restart_attempted`;
- `warm_restart_accepted`;
- `objective_before_restart`;
- `objective_after_restart`;
- `max_gradient_before_restart`;
- `max_gradient_after_restart`;
- `convergence_code_before_restart`;
- `convergence_code_after_restart`;
- `pd_hessian_before_restart`;
- `pd_hessian_after_restart`;
- `boundary_before_restart`;
- `boundary_after_restart`;
- `warm_restart_trigger_reason`.

Unattempted fits retain typed `NA` values in every after-field. An attempted
candidate error also retains typed after-field `NA`s: the original fit is
restored, while the v4 adapter deliberately rejects the incomplete attempt
rather than receiving invented diagnostics.

## Review correction

The first implementation received an independent Gauss **HOLD**. The corrected
implementation closes every stated blocker:

1. AGHQ and boundary diagnostics now fail closed on `NULL`, `NA`, missing, or
   malformed values in both eligibility and acceptance.
2. A narrow internal checkpoint seam proves that forced rejected and errored
   candidates restore `opt`, report, `sdreport`, restart history, and TMB
   `last.par`, `last.par.best`, and `value.best` state.
3. NB2 seed `371700001` is frozen as a non-positive-definite-Hessian case; a
   healthy no-restart outcome can no longer satisfy that assertion.
4. Tests cover missing/malformed before and after diagnostics, an already
   stationary `nlminb` fit, and an `optimizer = "optim"` no-effect fit.
5. The accepted deterministic case checks restart-history objective,
   convergence, message, elapsed time, iterations, and evaluations; the forced
   rejection checks exact history invariance.
6. Package tests freeze all 13 field names, types, trigger-reason precedence,
   unattempted/accepted/rejected/error semantics, and mirror the build-excluded
   v4 adapter against actual package fits.

A fresh independent review is still required before v4 is frozen or run.

## Verification

All commands ran in `/private/tmp/gllvmtmb-cran-0.7-20260807`.

| Command | Result |
|---|---|
| `Rscript --vanilla -e 'devtools::test(filter = "warm-nlminb-restart", reporter = "summary")'` | PASS; exact 13-field and pure contract tests green; six expected heavy skips |
| `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "warm-nlminb-restart", reporter = "summary")'` | PASS; actual v4-compatible fit records, deterministic acceptance, rejected/error restoration, no-effect paths, Gaussian boundary and NB2 non-PD cases green |
| `Rscript --vanilla -e 'devtools::test(filter = "stage39-multi-start\|multi-start-sdreport-consistency\|fit-health-converged\|matrix-binomial-logit-unit\|matrix-nbinom2-unit\|release-core-sentinels\|warm-nlminb-restart", reporter = "summary")'` | PASS; 16 expected heavy skips |
| Same relevant command with `GLLVMTMB_HEAVY_TESTS=1` | PASS; four pre-existing honest profile-CI skips, no failure |
| External probe loading `inst/sim/cran07-core/schema.R` and `inst/sim/cran07-v4/schema-v4.R`, then calling `cran07_v4_restart_record_from_fit()` on actual accepted (`n = 300`) and stationary (`n = 100`) package fits | PASS; both exact 13-field records accepted with correct attempted/accepted states |
| `Rscript --vanilla -e 'parse("R/fit-multi.R"); parse("tests/testthat/test-warm-nlminb-restart.R")'` | PASS |
| `git diff --check -- R/fit-multi.R tests/testthat/test-warm-nlminb-restart.R` | PASS |

The first full ordinary suite was stopped intentionally after independent
review superseded that implementation. The corrected full ordinary suite was
also stopped intentionally: concurrent, uncommitted comparator-harness edits
produced seven failures in `test-cran07-core-comparators.R`, making the source
state non-frozen and the run invalid for this repair. No warm-restart failure
had appeared. The release orchestrator owns one clean full-suite rerun after
the comparator producer finalizes stable source.

## Deterministic mechanisms retained

- Binomial-logit seed `372000004`, `n = 300`: warm restart attempted and
  accepted; maximum gradient falls below `0.01`; objective, report, `sdreport`,
  TMB state, and restart history are mutually consistent.
- Gaussian seed `371300010`, `n = 60`: no restart; the near-zero Psi boundary
  remains visible.
- NB2 seed `371700001`, `n = 100`: no restart; the frozen non-PD Hessian remains
  visible.
- Binomial-logit seed `372000004`, `n = 100`: already stationary and no restart.
- `optimizer = "optim"`: no restart.

## Explicit non-coverage

This receipt does not authorize v4 smoke, pilot, production, Totoro/DRAC use,
comparator adjudication, a version bump, source freeze, commit, push, or CRAN
submission. Gaussian latent `n = 60` and NB2 latent `n = 100` remain fenced.
