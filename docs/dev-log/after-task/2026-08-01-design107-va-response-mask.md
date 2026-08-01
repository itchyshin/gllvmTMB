# After Task: Design 107 Gate A Stage 1 — VA response-include

**Branch**: `cursor/design107-va-response-mask-20260801`
**Date**: `2026-08-01`
**Roles (engaged)**: Ada / Gauss / Boole / Curie / Fisher / Rose

## 1. Goal

Unblock Ayumi-shaped incomplete response grids on `integration = "va"` by
wiring a dense `DATA_IVECTOR(is_y_observed)` term-skip into the VA-R3 template
and lifting the R abort that refused masked responses, while keeping VA `mi()`
refused and making no public missing-data claim.

## 2. Implemented

- `inst/tmb/gllvmTMB_va_r3.cpp` declares `is_y_observed`, validates `{0,1}`,
  conditions family range checks on observed cells, and skips density/`ell`
  accumulation on masked rows (sentinel-invariant).
- R DATA assembly (`.va_r3_validate_data` / `.va_r3_make_objective` /
  `.va_r3_fit` / `.approximation_engine_va_r3_fit`) carries the mask; default
  is all-ones.
- `.gllvmTMB_va_route()` no longer aborts on response masks; still aborts on
  `mi()`, offsets, weights, REML, etc.; still requires dense `N*T` layout.
- Tests: sentinel-invariance, thin binomial JJ+include recovery, mi refuse,
  validate_data mask acceptance.

## 3. Files Changed

- `inst/tmb/gllvmTMB_va_r3.cpp`
- `R/va-r3-proto.R`
- `R/va-routing.R`
- `R/approximation-engine.R`
- `tests/testthat/test-va-missing-response.R` (new)
- `tests/testthat/test-va-r3-prototype.R` (message expectation)
- `docs/design/35-validation-debt-register.md` (VA-03 note; VA-10 `partial`)
- `docs/dev-log/after-task/2026-08-01-design107-va-response-mask.md`
- `docs/dev-log/plan-actual/2026-08-01-design107-va-response-mask.md`
- `docs/dev-log/check-log.md`
- `lanes/design107-va-mask/LOOP/` (GOAL / ultra-plan pointer; root `LOOP/` untouched)

## 3a. Decisions and Rejected Alternatives

- **Decision:** mechanism (b) dense term-skip (`is_y_observed`), not remove-error-only.
  **Rationale:** Gauss — lifting the abort without gating `ell` lets sentinel `y`
  corrupt the ELBO (Design 107 §2).
  **Rejected:** ragged dropped-row layout; VA `mi()`; Stage 2 mixed-family.
  **Confidence:** high (mirrors Laplace Design 59 convention).

## 4. Checks Run

```sh
git diff --check   # clean
NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-missing-response.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 10

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-r3-prototype.R")'
# FAIL 0 (prior session with load_all)
```

Deliberately not run: full `devtools::test()`, Totoro Stage 8, coverage, Design
108 Stage 2+.

## 5. Tests of the Tests

- Sentinel 0 vs `1e6` must move `fn`/`gr` if the density gate regresses
  (failure-before-fix).
- Public include path uses JJ (binomial route default) — exercises JJ×mask.
- Zero-observed unit included in the sentinel fixture (Design 107 §3.2 pin).
- `mi()` refuse is a positive control that Stage 1 did not widen predictor scope.

## 6. Consistency Audit

```sh
rg -n 'no response-mask channel|masked \(missing\) responses' R/ tests/
# no hits in R/va-routing.R (abort lifted)

rg -n 'DATA_IVECTOR\(is_y_observed\)' inst/tmb/gllvmTMB_va_r3.cpp
# present

rg -n 'VA-10' docs/design/35-validation-debt-register.md
# present; status partial
```

## 7. Roadmap Tick

N/A — Design 108 Stage 1 is register/admission plumbing, not a ROADMAP chip move.

## 7a. GitHub Issue Ledger

No dedicated open issue for Design 107 Stage 1; no issue closed or created.
Umbrella missing-data #332 remains open and is Laplace/`mi`-scoped; this PR
does not claim it.

## 8. What Did Not Go Smoothly

Worktree briefly risked colliding with the ledger lane; corrected to a fresh
`/private/tmp/gllvmtmb-design107-va-mask-20260801` from `origin/main` before
implementation.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss** — Required full term-skip, not abort-only; family range checks must
be observed-only or sentinels trip validation before the density gate.

**Fisher** — Named sentinel-invariance as the acceptance check; zero-observed
unit pin kept cheap inside the same fixture.

**Boole** — Kept dense `N*T` complete-design check; reinterpreted as dense
layout under include, not a ragged missing-data model.

**Curie** — Narrow `test-va-missing-response.R` under `skip_on_cran()`; avoids
CRAN compile of the parked VA DLL while still running under `NOT_CRAN=true`.

**Rose** — Register row VA-10 is `partial` with explicit non-advertise language;
VA-03 updated so “masked responses refused” is no longer stale.

**Ada** — Stage 1 only; Stage 2 mixed-family is the next Design 108 arc after
this lands.

## 10. Known Limitations And Next Actions

- No public “VA missing-data certified” claim; VA remains opt-in research fence.
- VA `mi()` still hard-errors (by design).
- Next: Design 108 Stage 2 (mixed-family) only after maintainer dispatch — do
  not auto-start. Totoro Stage 8 / coverage deferred.
