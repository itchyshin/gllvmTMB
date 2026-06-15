# Julia Bridge Confint CI Status

Date: 2026-06-15

## Goal

Tighten the R-side Julia bridge inference contract by making successful
`confint.gllvmTMB_julia()` matrices carry row-level `ci_status` metadata, like
the native derived-quantity interval routes.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-confint-ci-status.md`

## What Changed

`confint.gllvmTMB_julia()` now calls `.gtmb_attach_ci_status()` before returning
successful interval matrices. The attribute is row-named after any `parm`
subsetting, so `attr(ci, "ci_status")` lines up with `rownames(ci)`.

The test suite now checks:

- cached no-Julia CI payloads carry `ci_status == "ok"`;
- `parm` subsetting subsets the status names with the matrix rows;
- live Gaussian Wald/profile/bootstrap CIs carry status attributes;
- live NB1 Wald CIs carry status attributes;
- masked and mixed-family unsupported CI cells still fail before any fake
  interval promotion.

## Tests And Checks

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 18 | PASS 228` in `2.7s`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

First run exposed an attribute-sensitive numeric comparison in the bootstrap
reproducibility assertion. After making that equality ignore attributes while
keeping explicit `ci_status` assertions, the gate passed:

`FAIL 0 | WARN 0 | SKIP 0 | PASS 552` in `65.0s` on the final source state.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/confint.gllvmTMB_julia.Rd`. Pre-existing unresolved-link
roxygen warnings remain; unrelated generated Rd churn was reverted.

```sh
Rscript -e 'devtools::test()'
```

Result: `FAIL 0 | WARN 3 | SKIP 724 | PASS 2998`. Warnings were the existing
`nadiv::makeAinv()` selfing warning and the existing `glmmTMB`/`TMB` version
mismatch.

```sh
Rscript -e 'pkgdown::check_pkgdown()'
git diff --check
```

Result: pkgdown reported no problems; whitespace check clean.

## Claim Boundary

This is status metadata only. It does not change interval estimates, add
masked-response intervals, add mixed-family intervals, add non-Gaussian-X
intervals, route covariance matrices, change REML behavior, or make a speed
claim.

REML remains Gaussian-only. Non-Gaussian Julia-engine fits remain ML/Laplace
with Wald/profile/bootstrap terminology where routed.

## Rose Verdict

PASS WITH NOTES. The slice aligns successful Julia bridge interval matrices
with the native CI-status vocabulary without promoting unsupported cells.

Open audit follow-up from Rose: `GLLVM.jl-integration` public wording and
bridge metadata still need a separate cleanup so "full parity" and blanket
`status = "supported"` wording do not conflict with the R-first roadmap.

## Next Command

```sh
git status --short --branch
```
