# After Task: Totoro reaction-norm gradient repair

Branch: `codex/totoro-gradient-fixture-20261018`. Base: main `2020ef25a`. Date: 18 October 2026. Status: local verification complete; publication pending.

## 1. Goal

Repair the existing Totoro gradient-test failure while retaining the effective `loading_ridge = Inf` default and the raw-gradient threshold of 0.01.

## 2. Implemented

The long and wide BFGS test helpers now request `reltol = 1e-10` and explicitly set `loading_ridge = Inf`. The original stopping rule returned code zero with a raw gradient of 0.0181667. The tighter rule reaches 0.000236255 and lowers the objective from 24.94217347 to 24.61862488. Both formats return identical parameters. The new assertions check the wide diagnostic as well as finite, unpenalised TMB gradients below 0.01 in both formats. Every existing recovery and likelihood-agreement assertion remains.

Mathematical contract: no public API, estimator, likelihood, formula grammar, family, diagnostic cutoff or package-default change. This repair changes only how accurately an existing test fixture is optimised. It supplies no new Hessian or interval-coverage claim.

## 3a. Decisions and Rejected Alternatives

Tighten the fixture's objective stopping tolerance because the original BFGS settings stop before the existing gradient criterion is met. R's installed `?optim` documentation confirms that `reltol` controls relative objective reduction. At `1e-12`, the objective agrees with the selected `1e-10` run within 4.03e-10. The tighter fit changes the unit-slope covariance by about 0.573% relative to the early-stopped fit and passes the existing truth-recovery assertions.

Adding ridge, increasing the gradient threshold, accepting WARN, dropping recovery assertions and changing global optimiser defaults were rejected as unnecessary. Confidence is high for this deterministic fixture on the checked Totoro toolchain; cross-platform execution remains separate evidence.

## 4. Files Touched

The implementation change is `tests/testthat/test-example-behavioural-reaction-norm.R`. This report and `docs/dev-log/research/2026-10-18-totoro-gradient/` retain the commands, individual fit receipts, red/green results, source hash and check logs. A final file inventory accompanies the receipts.

`R/`, `src/`, `NAMESPACE`, `DESCRIPTION`, `man/`, README, NEWS, ROADMAP, vignettes and pkgdown navigation are unchanged. The shared check log is carried by active PR 1561, so the dated command record is isolated in this research directory. The primary Dropbox checkout and the CRAN-only `skip_on_cran()` changes on the separate release branch are preserved.

## 5. Checks Run

The retained `totoro-gradient-investigate.R` fits the original settings, `reltol = 1e-10`, `reltol = 1e-12` and the wide `1e-10` form using the unchanged checked package binary. All use `loading_ridge = Inf`. The baseline uses 152 objective and 47 gradient evaluations; the selected fit uses 295 and 87, below the unchanged 2,000-iteration cap.

The retained `totoro-gradient-test-file.R` runs the full reaction-norm test file with `NOT_CRAN=true`. Before the control change: 4 failed, 69 passed, zero errors, warnings or skips. After: 73 passed, zero failures, errors, warnings or skips. `git diff --check` passes. `pkgdown::check_pkgdown()` reports no problems, with existing Pandoc `--mathml` deprecation notices.

The neighbouring article's default `nlminb`, `se = TRUE` fit was exercised on the same frozen data. Its optimiser and raw-gradient checks pass, with gradient about 0.0007743, available standard-error calculations and a positive-definite Hessian. `neighbour-default.json` and its script retain this bounded check. This supports leaving the article's fitting calls unchanged.

`pkgbuild::build(binary = FALSE, vignettes = FALSE, manual = FALSE)` produced source SHA256 `ba34f02436646225b88d990d817525a5e8862702ce26ef09e0b8728f7f978ce8`. The complete `devtools::check(document = FALSE, args = "--no-manual")` passed on Totoro in 1,701.08 seconds under single-thread numerical libraries, `MAKEFLAGS=-j2` and a 30-minute timeout: zero errors, zero warnings and two existing notes. The full suite reported FAIL 0, WARN 60, SKIP 1259, PASS 26641. The notes concern `TMB:::EvalADFunObject` and server compiler flags; both were present in the previous failed check. The complete check and test logs are retained. Roxygen regeneration and article rendering were not repeated because no public code, help, grammar or example changed.

## 6. Tests of the Tests

The strengthened assertions failed before changing the controls: the long and wide diagnostic rows returned WARN, and both independent raw-gradient comparisons exceeded 0.01. The same assertions pass with the tighter stopping tolerance. No assertion was removed or weakened. Agreement of the long/wide parameter vectors and the independent `1e-12` stopping check guards against claiming success from a diagnostic label alone.

## 7. Roadmap Tick

N/A. This repairs numerical stopping in an existing test fixture.

## 7a. Issue Ledger

The baseline failure is recorded in merged PR 1596's publication receipts. No new issue is needed for this bounded repair. No issue or PR comment was sent; no new PR or merge was performed.

## 8. Consistency Audit

`rg -n 'reltol|max_gradient|0\.01|loading_ridge' tests/testthat/test-example-behavioural-reaction-norm.R` confirms that both helpers use the same stopping controls and that the direct gradient cutoff remains 0.01.

`rg -n 'max_gradient|0\.01' vignettes/articles/random-regression-reaction-norms.Rmd` confirms that the article still teaches the existing raw-gradient cutoff. Its calls use the default nlminb optimiser, so the BFGS-only fixture repair requires no article change.

`git diff --name-only -- R src NAMESPACE DESCRIPTION man README.md NEWS.md ROADMAP.md vignettes _pkgdown.yml` returns no changed path. There is no convention-change cascade or new advertised capability; validation-debt status is unchanged.

## 9. What Did Not Go Smoothly

The first investigative script used the wrong fitted-object slot and an unavailable fixed-effect generic. Correcting the throwaway harness produced the retained numerical comparison. The first test runner recorded the real failures but also triggered a global cleanup error; a corrected runner reproduced the same four failures without a harness error. The original log is retained. An intermediate runner used an unavailable edition helper and stopped before tests; it was corrected before reporting green results.

Source-package construction took several minutes. The first full-check build stopped before tests because the reused Pandoc path omitted its final `bin` directory. The corrected path passed a version probe before restart; the failed build log is retained. The private tools, source archive and original failed check were preserved. Neither runtime code nor test thresholds were changed to compensate for a toolchain issue.

## 10. Known Residuals

Local repair and the full Totoro package check passed. The two existing package-check notes and 60 test diagnostic warnings remain visible in the receipts. No claim about all platforms or interval calibration follows from this fixture. Publication, exact-head CI and post-merge CI remain the next gates; this report records the local verification checkpoint before push or merge.

## 11. Team Learning

Ada's primary-agent review separated the relative objective stopping rule from the raw-gradient diagnostic, reproduced the failing test before editing its controls, and retained exact source provenance. The neighbouring article uses a different optimiser and needs no matching control edit.

The independent test reviewer inspected the diff and receipts without running fits. The reviewer found no blocker: both shapes use the same unpenalised controls, direct gradient checks reinforce the diagnostic labels, and the existing recovery assertions remain. The reviewer explicitly limited this evidence to point recovery and stationarity because these fixture fits use `se = FALSE`.

## 12. Cross-Product Coverage

Covers the saved Gaussian reaction-norm fixture in both long and wide forms, BFGS point fitting, its raw-gradient diagnostics and existing covariance-recovery checks. It does NOT cover Hessian quality, interval coverage, other families, structured covariance providers or a change in package optimiser behaviour. No cross-cutting engine or penalty flag was changed.
