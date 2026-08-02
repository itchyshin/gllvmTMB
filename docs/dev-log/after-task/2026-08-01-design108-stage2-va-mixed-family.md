# After Task: Design 108 Gate A Stage 2 — VA mixed-family + per-trait Gaussian SD

**Branch**: `cursor/design108-va-mixed-family-20260801`
**Date**: `2026-08-01`
**Roles (engaged)**: Ada / Gauss / Boole / Curie / Fisher / Rose

## 1. Goal

Unblock Ayumi-shaped mixed-family expression on `integration = "va"` by
wiring per-row family dispatch and estimated per-trait Gaussian residual SD
into the VA-R3 template, lifting the R mixed-family abort for fence-admitted
families only, while keeping single-family bit-compat, VA `mi()` refused, and
no public mixed-family claim.

## 2. Implemented

- `inst/tmb/gllvmTMB_va_r3.cpp`: `DATA_IVECTOR(family)` (dense `N*T`);
  `PARAMETER_VECTOR(log_sigma)` length `T`; row loop uses `family(r)`;
  Gaussian `ell` uses `exp(log_sigma(t))`; JJ requires all rows binomial.
- R: `.va_r3_validate_data` / make / fit / engine accept `family_codes`;
  Laplace→VA id map; per-trait maps for `log_phi` / `log_sigma`;
  `estimate_gaussian_sd` pin for known-SD oracle tests.
- Fence admits `gaussian` identity; route lifts mixed abort for admitted set;
  pure binomial → `jj`, mixed/non-binomial → `gh`.
- Tests: packing/eval policy; thin mixed gaussian+binomial prototype smoke;
  thin mixed binomial+poisson public smoke under fence; single-family
  prototype regression green.

## 3. Files Changed

- `inst/tmb/gllvmTMB_va_r3.cpp`
- `R/va-r3-proto.R`
- `R/va-routing.R`
- `R/approximation-engine.R`
- `R/integration-fence.R`
- `tests/testthat/test-va-mixed-family.R` (new)
- `tests/testthat/test-integration-fence.R`
- `tests/testthat/test-va-r3-prototype.R`
- `docs/design/35-validation-debt-register.md` (VA-02/03 notes; VA-11 `partial`)
- `docs/dev-log/after-task/2026-08-01-design108-stage2-va-mixed-family.md`
- `docs/dev-log/plan-actual/2026-08-01-design108-stage2-va-mixed-family.md`
- `docs/dev-log/check-log.md`
- `lanes/design108-stage2/LOOP/` (GOAL / ultra-plan pointer; root `LOOP/` untouched)

## 3a. Decisions and Rejected Alternatives

- **Decision:** dense per-row `DATA_IVECTOR(family)` (not length-`T` trait lookup).
  **Rationale:** mirrors Laplace `family_id_vec` and Stage 1 `is_y_observed`.
  **Rejected:** Stage 3 lognormal-as-core; Stage 4 probit/ordinal; Totoro Stage 8.
  **Confidence:** high (Design 108 locked decisions).

- **Decision:** per-trait free `log_sigma` with map-off for non-Gaussian traits;
  oracle fixtures may set `estimate_gaussian_sd = FALSE`.
  **Rationale:** Stage 2 deliverable is estimated residual SD; known-SD algebra
  tests need the pre-Stage-2 pin.
  **Rejected:** keeping `DATA_SCALAR(gaussian_sd)` as the only path.

- **Decision:** pure binomial keeps JJ; mixed → GH (no per-row JJ).
  **Rationale:** JJ bound is binomial-only; Gate 3 evidence is Bernoulli.

## 4. Checks Run

```sh
git diff --check   # clean
NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-mixed-family.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 23

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-missing-response.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 10

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-integration-fence.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 39

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-routing-oracle.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 31

NOT_CRAN=true Rscript --vanilla -e \
  'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-r3-prototype.R")'
# FAIL 0 | WARN 0 | SKIP 0 | PASS 352
```

Deliberately not run: full `devtools::test()`, Totoro Stage 8, coverage,
Design 108 Stages 3–14, public NEWS advertise.

## 5. Tests of the Tests

- Scalar family still expands to a dense code vector (bit-compat packing).
- Mixed JJ request fails closed; pure binomial still resolves to JJ.
- Prototype mixed smoke exercises free `log_sigma` + GH.
- Public mixed smoke uses Stage-37 `family = list(...)` + `family_var`.
- Design 107 mask suite remains green (Stage 1 not regressed).

## 6. Consistency Audit

```sh
rg -n 'DATA_IVECTOR\(family\)|PARAMETER_VECTOR\(log_sigma\)' inst/tmb/gllvmTMB_va_r3.cpp
# present
rg -n 'length\\(unique\\(family' R/va-routing.R
# mixed abort removed; fence/pair path remains
```

## 7. Follow-up

- Design 108 Stage 3 lognormal only as optional early Rung 1 after this merges
  green — do not auto-start Stage 4.
- No public mixed-family VA advertise until register moves past `partial`.

## 8. Definition of Done (six-item)

1. Implementation — this PR (CI pending).
2. Simulation recovery — thin admission smoke only; not a recovery certificate
   (after-task names why: Stage 2 is plumbing).
3. Documentation — register VA-11; no user-facing advertise.
4. Runnable example — tests exercise the public route; no article claim.
5. check-log — appended.
6. Review — Gauss (template), Boole (fence/route), Curie (tests), Rose (register).
