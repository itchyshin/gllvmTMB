# Repair PR #1936: Newton-SE gate and deterministic non-PD tests

Reader: a package contributor checking the converged rule before review.

## Goal

`fit_health$converged` on PR #1936 already required a positive-definite Hessian and finite fixed-effect standard errors. The 26 Nov rule also requires the Newton step in standard-error units,

`max_i |(H^{-1} g)_i| / SE_i <= 1e-3`,

with `SE_i = sqrt((H^{-1})_{ii})` from `sd_report$cov.fixed`. That check was missing. The non-PD tests skipped whenever a fitted Hessian read as positive definite, which had happened on Ubuntu CI.

## Mathematical contract

No likelihood, family, formula grammar, or estimand change. The convergence label gains one gate. `H^{-1}` is the fixed-effect covariance already stored by `sdreport()`. `g` is the same penalised gradient `fit_health$max_gradient` uses. The absolute value makes the minimiser sign irrelevant. The gate runs only after optimiser success, a finite objective, the existing raw-gradient bound (`1e-2`), no boundary flag, `pdHess = TRUE`, and finite fixed-effect standard errors. A non-positive-definite Hessian stays `degenerate`. A boundary component stays `boundary`. A ratio above `1e-3`, or a ratio that cannot be formed on that path, is `not_converged`.

## Files

- `R/diagnose.R` — `.gllvmTMB_newton_se_ratio()`, the status argument, and `fit_health$newton_se_ratio`.
- `tests/testthat/test-convergence-pd-hessian-1926.R` — threshold, formula, passing and failing fixtures, indefinite mocked Hessian.
- `tests/testthat/test-fit-health-converged.R` — the rotation-ridge case is now that same indefinite fixture and still expects `degenerate`. The clean Gaussian draw now includes a shared factor so the unchanged `converged == TRUE` assertion is an interior fit; noise-only data had put one `sd_B` at `9e-5`, under the existing `1e-4` boundary threshold.
- `NEWS.md` — the rule, in plain language.
- `docs/dev-log/check-log.d/2026-11-26-1926-newton-se.md`
- this report.

No README, vignette, Rd, design-register, or roadmap edit. `man/*.Rd` was not regenerated because no exported signature changed.

## Checks

`pkgload::load_all()` then `testthat::test_file()`:

- `test-convergence-pd-hessian-1926.R`: FAIL 0 / WARN 0 / SKIP 0 / PASS 36
- `test-fit-health-converged.R`: FAIL 0 / WARN 0 / SKIP 0 / PASS 17
- `test-unique-indep-slope-semantics.R`: FAIL 0 / WARN 0 / SKIP 0 / PASS 31

Not run: full package check, pkgdown. No C++ change, so the installed DLL was left in place and the R sources were loaded with `pkgload`.

## Consistency

The rotation-ridge expectation stays `degenerate`. No other test expectation was retargeted. `test-sanity-multi.R` still expects `converged == TRUE` on two fixtures that this branch already classifies as boundary or degenerate (`near_zero_sd_B`, and a fit whose warning is the non-PD class). The small Gaussian's Newton ratio was `9.8e-5`, so those failures are not the new gate. They were left as they stand.

## Tests of the tests

The failing fixture uses gradient `5e-3` and variance 1, so the raw gradient gate (`1e-2`) passes and the Newton gate (`5e-3`) fails. Removing the Newton branch would label it `converged` and the test fails. The passing fixtures use `1e-6` and the inclusive bound `1e-3`. The non-PD fixture is the indefinite matrix `[[1, 2], [2, 1]]` with `pdHess = FALSE`, a tiny gradient, and a finite fixed-effect SE, so the only route to `degenerate` is the Hessian flag. There is no `skip_if` on that path.

## What did not go smoothly

The noise-only "clean fit" in `test-fit-health-converged.R` is on a variance boundary under seed 1. The assertion stayed `converged == TRUE`; the data gained a shared factor. `tidyr` is absent here, so the traits()-based penalised-gradient and Ayumi tests could not be executed.

## Review

Fisher: the new gate is a scale-free stationarity check. A diagonal shortcut `|g_i| * SE_i` is not the tested quantity; the off-diagonal case expects `5e-4` rather than `1e-3`. Curie: both the reject and the accept cases are constructed, and the non-PD case no longer depends on BLAS. Rose: parallel PR #1932 edits `R/diagnose.R` with a different `convergence_status` signature (no `pd_hessian`). This repair stays on #1936 and does not edit #1932. Merge will conflict and needs a human ordering.

## Design, pkgdown, roadmap, issues

No design-doc or pkgdown change. Roadmap tick: N/A. Issue #1926 was read. Its only comment assigns the case to the degenerate-classification lane and does not claim it for Claude, Codex, or Antigravity. No issue comment was added. The PR body is appended, not replaced.

## Limitations

`newton_se_ratio` is `NA` when `sdreport()` did not run or the Hessian is not positive definite. Duplicate TMB parameter names are not used to reorder `cov.fixed`; the gradient passed from `build_fit_health` is unnamed, so the product is positional, which matches `obj$gr()` and `cov.fixed`.
