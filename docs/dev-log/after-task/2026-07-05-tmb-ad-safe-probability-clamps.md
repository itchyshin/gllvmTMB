# After Task: TMB AD-safe probability clamps

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Gauss / Noether / Curie / Rose / Shannon`

## 1. Goal

Close the local implementation side of issue #658 by replacing probability
clamps that used AD-value C++ ternary branches with CppAD conditional
expressions. The intended likelihood bounds stay the same; only the branch
mechanism changes so the clamp is evaluated correctly on the AD tape.

## 2. Implemented

- Added `gll_clamp()` in `src/gllvmTMB.cpp`.
- Replaced the binomial probability clamp with `gll_clamp(p, tiny, 1 - tiny)`.
- Replaced the Beta response clamp with `gll_clamp(y_safe, tiny_y, 1 - tiny_y)`.
- Replaced the ordinal category-probability lower clamp with
  `CppAD::CondExpLt`.
- Added `tests/testthat/test-tmb-ad-safe-clamps.R` as a regression guard.
- Updated validation-debt rows for the affected family surfaces.

## 3. Files Changed

- `src/gllvmTMB.cpp`
- `tests/testthat/test-tmb-ad-safe-clamps.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-tmb-ad-safe-probability-clamps.md`

## 3a. Decisions and Rejected Alternatives

Decision: use `CppAD::CondExpLt` / `CppAD::CondExpGt` directly, with a small
`gll_clamp()` helper for two-sided clamps.

Rationale: the file already uses this idiom in nearby numerical guards, and it
preserves the existing lower and upper numeric bounds.

Rejected alternative: change the link functions or likelihood formulas. That
would be a parameterisation change and would require a larger symbolic and
simulation review. This slice is only numerical safety.

Confidence: high that the reported AD-tape branch hazard is removed at the
named sites. Broader C++ ternary review remains a separate audit.

## 4. Checks Run

```sh
gh issue view 658 --repo itchyshin/gllvmTMB --json number,title,state,body,url
rg -n "\\?\\s*[^:]+:|CondExp|tiny|p_k|y_safe|p =" src/gllvmTMB.cpp
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R", reporter = "summary")'
Rscript --vanilla -e 'pkgbuild::compile_dll()'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-tmb-ad-safe-clamps.R", reporter = "summary")'
env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-multi-trial-binomial.R", reporter = "summary")'
env NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-beta-recovery.R", reporter = "summary")'
env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinal-probit.R", reporter = "summary")'
```

Outcomes:

- Source guard passed.
- `pkgbuild::compile_dll()` passed; only upstream Eigen unused-variable warnings
  were emitted.
- `test-multi-trial-binomial.R` passed under `NOT_CRAN=true`.
- `test-beta-recovery.R` passed under `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`.
- `test-ordinal-probit.R` passed under `NOT_CRAN=true`.

## 5. Tests of the Tests

The new test is a source-level regression guard that fails if the exact
AD-driven ternary clamp patterns return at the binomial, Beta, or ordinal
probability sites. It complements, but does not replace, the compiled family
tests.

## 6. Consistency Audit

```sh
rg -n "p = \\(p < tiny\\)|y_safe = \\(y_safe < tiny_y\\)|p_k = \\(p_k < tiny_p\\)|gll_clamp|CondExpLt\\(p_k" src/gllvmTMB.cpp tests/testthat/test-tmb-ad-safe-clamps.R
```

Verdict: the old AD-value ternary clamp patterns are absent from the C++ source;
the new helper and ordinal `CondExpLt` clamp are present.

## 7. Roadmap Tick

N/A. This is robustness hardening for existing covered family rows, not a new
family or public capability.

## 7a. GitHub Issue Ledger

- Inspected open issue #658:
  `https://github.com/itchyshin/gllvmTMB/issues/658`.
- Local fix implemented and tested. Issue not closed here because this branch
  has not been pushed or merged in this slice.

## 8. What Did Not Go Smoothly

Several nearby open GitHub issues were already fixed locally on this branch, so
issue triage took longer than the actual patch. The useful rule was to verify
current code before editing.

## 9. Team Learning

- Ada: kept the slice to numerical clamp mechanics and did not widen family
  claims.
- Gauss: confirmed the same clamp bounds are retained while the AD branch is
  made tape-safe.
- Noether: no symbolic likelihood formula or parameterisation changed.
- Curie: paired a source-level regression guard with compiled family smoke.
- Rose: validation rows were updated as evidence pointers only, with no status
  promotion.
- Shannon: pre-edit lane check found no open PR list output; recent commits are
  local branch work.

## 10. Known Limitations And Next Actions

- This does not audit every ternary expression in the C++ file; it closes the
  probability-clamp sites named in issue #658.
- No broad `devtools::check()` or pkgdown run was done in this slice.
- Continue the completion arc with either the sparse `propto()` precision
  boundary (#636) as a focused numerical slice or a reconciliation pass for
  open GitHub issues already fixed locally.
