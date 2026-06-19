# After Task: Unique / Ordinary Latent Psi Split Full Validation

**Branch**: `codex/unique-latent-psi-split-20260619`
**Date**: `2026-06-19`
**Roles (engaged)**: `Ada / Boole / Rose / Grace`

## 1. Goal

Repair the remaining full-suite failures in the `unique()` /
ordinary-`latent()` Psi migration split and verify that the lane is locally
green before bridge admission, coevolution, article-placement, or release gates
depend on it.

## 2. Implemented

- The row-weight tests now opt into `latent(..., residual = FALSE)` because
  they test observation-weight dispatch, not the new ordinary `latent()` Psi
  decomposition.
- The mixed-family extractor test now expects ordinary `latent()` to expose a
  positive default Psi diagonal through `extract_Sigma(part = "unique")`
  instead of expecting the old no-Psi subset.

## 3. Files Changed

Test files touched in this closeout slice:

- `tests/testthat/test-lme4-style-weights.R`
- `tests/testthat/test-mixed-family-extractor.R`

Inherited files in this split lane remain part of the broader API/convention
cascade and are not re-enumerated here.

## 3a. Decisions and Rejected Alternatives

Decision: use `latent(..., residual = FALSE)` in the weight fixture.

Rationale: the test file is about lme4/glmmTMB-style row weights. Ordinary
`latent()` now carries a default diagonal Psi companion, which can absorb the
signal the old fixture used to detect weight effects on fixed-effect SEs and
Gaussian residual scale.

Rejected alternative: relax the SE and sigma expectations. That would keep the
test passing but weaken the row-weight contract.

Decision: update the mixed-family extractor expectation to positive finite Psi.

Rationale: ordinary `latent()` now owns the diagonal Psi term by default. A
zero-Psi expectation would test the old no-residual subset while fitting the new
ordinary model.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> before edits reproduced four failures: two SE-shrink failures, one
  heteroscedastic sigma-recovery failure, and one stale zero-Psi mixed-family
  extractor expectation.
- `Rscript --vanilla -e 'devtools::test(filter = "lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> after edits completed with `DONE`, exit code 0.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|ordinary-latent-random-regression|brms-sugar|gllvmTMB-wide|keyword-grid|stage2-rr-diag|stage3-propto-equalto|stage33-non-gaussian|phase56-3-phylo-unique-parser|sigma-rename|extract-sigma|example-covariance-edge-cases|family-gamma|gllvmTMB-diagnose|joint-sdm-binary-long-wide|julia-bridge|lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> completed with `DONE`, exit code 0; expected INLA, heavy, and live-Julia
  skips remained.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> completed with `DONE`, exit code 0. The prior full-suite failures were
  gone; remaining warning output was from existing compatibility/deprecation and
  diagnostic paths.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `DONE`, exit code 0; JuliaCall activated the integration
  project and exited cleanly.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|Status:|fixed-enum|R_ext/Boolean|unknown warning group" /private/tmp/gllvmTMB-rcmdcheck/gllvmTMB.Rcheck/00check.log /private/tmp/gllvmTMB-rcmdcheck/gllvmTMB.Rcheck/00install.out`
  -> the lone warning was the known Apple clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.
- `git diff --check`
  -> clean after edits.

## 5. Tests of the Tests

The failure-before-fix evidence showed that the two repaired files were the
remaining full-suite blockers. The repaired focused run and the full
`devtools::test()` run both completed with exit code 0, so the changed
expectations are exercised in isolation and in the macro suite.

## 6. Consistency Audit

- `rg -n "zero-Psi|no-unique\\(\\) fit|structurally zero|latent\\(0 \\+ trait \\| site, d = 1\\)(,|\\))" tests/testthat/test-lme4-style-weights.R tests/testthat/test-mixed-family-extractor.R`
  -> no matches. The repaired files no longer contain the stale zero-Psi/no
  residual-implicit wording or unqualified weight-test latent formula.

## 7. Roadmap Tick

N/A. This was a split-lane validation repair, not a roadmap row movement.

## 7a. GitHub Issue Ledger

No issue was closed or created. The relevant public issue/PR state remains
unchanged: draft PR #489 is still the broader bridge PR, and this split worktree
has not been pushed.

## 8. What Did Not Go Smoothly

The original full-suite failure was not a new engine break. It was stale test
intent after the ordinary `latent()` Psi default changed. The row-weight fixture
needed an explicit no-residual model to keep the row-weight signal identifiable.

## 9. Team Learning

Ada: keep this as the first split lane because downstream bridge/article work
should teach the stable covariance grammar.

Boole: tests that need the old reduced-rank subset must now say
`residual = FALSE` explicitly.

Rose: stale “no `unique()` means zero Psi” language is an overclaim after the
ordinary latent-Psi fold.

Grace: the local R, pkgdown, R CMD check, and live Julia-via-R evidence now pass
for this split lane; the R CMD check warning is external compiler-header noise.

## 10. Known Limitations And Next Actions

This does not remove `unique()` or escalate lifecycle policy. Source-specific
and kernel latent-Psi folds remain future slices unless separately tested.

Next action: keep the split discipline. Use this Psi/API lane evidence before
moving on to bridge admission, fixed-rho coevolution engine review, or public
article placement.
