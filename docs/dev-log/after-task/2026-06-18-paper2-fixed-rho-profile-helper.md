# After Task: Paper 2 Fixed-Rho Profile Helper

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-18`
**Roles (engaged)**: `Ada / Boole / Fisher / Curie / Grace / Rose / Pat`

## 1. Goal

Move the Paper 2 fixed-`rho` workflow from an internal test-only pattern to a
documented helper, while preserving the claim boundary. The new surface should
help users compare defended fixed `rho` values, not pretend that `rho` is
estimated inside TMB or that profile intervals exist.

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## 2. Implemented

- Added exported `profile_cross_rho()`.
- The helper rebuilds `K_star` via `make_cross_kernel()` for each fixed grid
  value, calls a user-supplied `refit(K, rho, ...)`, and returns a tidy
  likelihood/profile table.
- The table includes `rho`, `logLik`, `relative_logLik`, `delta_deviance`,
  `is_best`, `convergence`, `pd_hessian`, `status`, `error`, and optional
  metric columns.
- The heavy COE-04 fixed-rho sensitivity gate now uses the exported helper.
- `extract_Gamma()` documentation points to the helper for fixed-grid
  profiling.
- The internal coevolution article now teaches `profile_cross_rho()` in the
  `rho` grid section.
- Dashboard, validation register, Design 65, NEWS, pkgdown, and check-log
  evidence were updated.

## 3. Files Changed

Code and docs:

- `R/kernel-helpers.R`
- `R/extract-sigma.R`
- `NAMESPACE`
- `man/profile_cross_rho.Rd`
- `man/extract_Gamma.Rd`
- `_pkgdown.yml`
- `NEWS.md`

Tests and article:

- `tests/testthat/test-coevolution-two-kernel.R`
- `vignettes/articles/cross-lineage-coevolution.Rmd`

Evidence:

- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-18-paper2-fixed-rho-profile-helper.md`

## 3a. Decisions and Rejected Alternatives

Decision: use a callback-based `refit(K, rho, ...)` contract.

Rationale: arbitrary user formulas can contain `K` in many environments and
names; trying to rewrite formula calls automatically would be fragile and
could silently profile the wrong model.

Rejected alternative: automatic formula surgery.

Decision: return a fixed-grid likelihood table, not a confidence interval.

Rationale: `rho` is not a TMB parameter in the current engine, and finite-grid
best values can sit on the high edge because fixed kernel strength and loading
magnitudes trade off.

Rejected alternative: labeling the helper as `rho` estimation or interval
support.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file = "R/kernel-helpers.R")); invisible(parse(file = "tests/testthat/test-coevolution-two-kernel.R")); cat("parse ok\n")'`
  -> pass.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `NAMESPACE`, `man/profile_cross_rho.Rd`, and after roxygen text
  changes `man/extract_Gamma.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 9 | PASS 67`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-helpers|coevolution-prototype|coevolution-recovery")'`
  -> `FAIL 0 | WARN 0 | SKIP 3 | PASS 33`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 225`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 12 | PASS 171`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> exit 0; rendered the coevolution article and full article set.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 354`.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> pass.

## 5. Tests of the Tests

The first focused run failed because the helper was not yet exported. That
proved the test exercised the public package surface rather than only a local
definition.

The second focused run failed because `best_rho` was attached before a
data-frame reorder and was dropped. That proved the fast contract test protects
the returned object metadata.

The heavy COE-04 gate now runs the real fixed-rho grid through the exported
helper and still verifies that positive `rho` fits beat the block-null
`rho = 0` fit.

## 6. Consistency Audit

Patterns used:

- `rg -n 'profile_cross_rho|fixed-kernel sensitivity grid|fixed-grid profile|in-engine rho|formal rho profile|profile/estimation|rho profile intervals|PR green' pkgdown-site/articles/cross-lineage-coevolution.html docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json NEWS.md docs/design/35-validation-debt-register.md docs/design/65-cross-lineage-coevolution-kernel.md R/kernel-helpers.R R/extract-sigma.R vignettes/articles/cross-lineage-coevolution.Rmd man/profile_cross_rho.Rd man/extract_Gamma.Rd`

Verdict: `profile_cross_rho()` is present in source, generated Rd, pkgdown
reference index, rendered coevolution article, tests, NEWS, Design 65,
validation row `COE-04`, dashboard, and check-log. Remaining `rho`/interval
phrases are claim-boundary language.

## 7. Roadmap Tick

Design 65 C3.3 and validation row `COE-04` were updated. `COE-04` remains
partial.

## 7a. GitHub Issue Ledger

No GitHub issue or PR was mutated. This respects the current boundaries: do
not push and do not mutate GLLVM.jl #101.

## 8. What Did Not Go Smoothly

The fast test caught two useful issues before commit: missing export before
documentation, and a dropped `best_rho` attribute after data-frame column
reordering. A stale scan was also initially run with a double-quoted pattern
containing backticks, which zsh treated as command substitution; the scan was
rerun safely with single quotes.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: this moves the coevolution model surface forward without redefining the
finish line. The helper removes one "planned support" gap, but the model is
not done.

Boole: callback-based refitting is the right grammar boundary for now. It
keeps the formula API stable and avoids implicit formula rewriting.

Fisher: the profile table is fixed-grid evidence only. It supports
sensitivity analysis, not `rho` estimation or interval calibration.

Curie: the heavy gate now validates the exported helper, not a private test
utility. The broad null/overlap/non-Gaussian gates still need separate
simulation evidence.

Grace: documentation, pkgdown registration, full article rendering,
focused tests, and full heavy kernel/coevolution aggregation passed.

Rose: dashboard and validation rows keep `COE-04` partial and preserve the
guard sentence.

Pat: the coevolution article now points readers to a named helper rather than
making them copy a hand-rolled `lapply()` profile.

## 10. Known Limitations And Next Actions

- No public Paper 2 promotion.
- No in-engine `rho` estimation.
- No `rho` profile intervals or interval coverage.
- No formal null-threshold / Type-I calibration beyond the diagnostic grid.
- No broader/harder moderate-overlap grid.
- No broad high-overlap truth-recovery/failure calibration beyond the current
  collapse-equivalence and warning gates.
- No non-Gaussian recovery or mixed-family Paper 2 coverage; the Poisson gate
  remains construction-only.
- No explicit Paper 2 multi-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation yet.
- No bridge completion, release readiness, or scientific coverage completion.
