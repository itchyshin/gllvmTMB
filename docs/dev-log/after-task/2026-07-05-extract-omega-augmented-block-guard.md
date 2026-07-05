# After Task: extract_Omega augmented block guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: 2026-07-05
**Roles (engaged)**: Ada / Emmy / Curie / Fisher / Rose / Shannon

## 1. Goal

Make `extract_Omega()` fail loud when a requested tier returns an augmented
structural covariance block that is not summable into the trait-level `T x T`
Omega matrix. This closes the local repair for issue #632 without changing any
likelihood, formula grammar, family support, or interval claim.

## 2. Implemented

- Added a summability guard before `Omega <- Omega + Sigma` in
  `extract_Omega()`.
- The guard rejects non-matrix payloads, wrong-dimension payloads, and
  same-dimension payloads with row or column names that do not match the fitted
  trait order.
- The error directs users to `extract_Sigma(level = ..., part = "total")` for
  augmented tier-specific blocks such as `phylo_dep(1 + x | species)`.

## 3. Mathematical Contract

No public API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change.

`extract_Omega()` remains the trait-level additive covariance helper:

```text
Omega = Sigma_tier1 + Sigma_tier2 + ...
```

That addition is valid only when every requested tier returns the same `T x T`
trait covariance with matching trait labels. Augmented intercept/slope tiers
return coefficient-block covariances, for example `2 x 2` or `(1+s)T x (1+s)T`,
so they remain inspectable through `extract_Sigma()` but are not silently coerced
into Omega.

## 4. Files Changed

- `R/extract-omega.R`
- `tests/testthat/test-extract-omega.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-extract-omega-augmented-block-guard.md`

## 3a. Decisions and Rejected Alternatives

Decision: fail loud instead of slicing an augmented block down to its intercept
sub-block.

Rationale: `extract_Omega()` is a trait-level sum. Pulling out a sub-block would
make an unadvertised estimand and risk hiding the fact that the requested tier
contains a richer structural random-slope covariance.

Rejected alternative: coerce by position or drop slope rows/columns. Confidence:
high for this guard slice.

## 4. Checks Run

```sh
gh pr list --state open --limit 20
git log --all --oneline --since='6 hours ago' --decorate
gh issue view 625 --repo itchyshin/gllvmTMB --json number,title,body,url
gh issue view 626 --repo itchyshin/gllvmTMB --json number,title,body,url
gh issue view 627 --repo itchyshin/gllvmTMB --json number,title,body,url
gh issue view 632 --repo itchyshin/gllvmTMB --json number,title,body,url
Rscript --vanilla -e 'parse("R/extract-omega.R"); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extract-omega.R")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-keyword-grid.R")'
git diff --check
```

Outcomes: open-PR lane check returned no open PRs; recent-log lane check showed
only local completion-arc commits. `test-extract-omega.R` passed 21 assertions.
`test-keyword-grid.R` produced one expected CRAN skip. `git diff --check`
passed.

## 5. Tests Of The Tests

The two new tests are boundary tests. They mock `extract_Sigma()` so the failure
is isolated to `extract_Omega()`'s summation contract:

- a `2 x 2` augmented phylo slope block cannot be added to a `3 x 3`
  trait-level Omega;
- a `3 x 3` block with the wrong trait labels cannot be added by position.

The first direct test run without `pkgload::load_all()` failed because the
standalone file does not attach the package namespace. The package-loaded rerun
passed.

## 6. Consistency Audit

```sh
rg -n "non-conformable arrays|non-conformable|extract_Omega\\(\\).*augmented|extract_Omega.*phylo_dep|trait-level Omega" R tests/testthat docs/design docs/dev-log/after-task docs/dev-log/check-log.md
```

Verdict: after the guard and report, the only current references describe the
new fail-loud trait-level Omega boundary or historical issue context.

## 7. Roadmap Tick

N/A. No roadmap status chip or public capability row changed.

## 7a. GitHub Issue Ledger

- Inspected #625: duplicate slope covariates. Already locally covered by
  earlier branch work (`c22f4c97`) and validation row `RE-03`; no edit in this
  slice.
- Inspected #626: parenthesized intercept LHS. Already locally covered by
  earlier branch work (`594f16df`) and `test-augmented-lhs-guard.R`; no edit in
  this slice.
- Inspected #627: malformed spatial `name | name` orientation. Still a good
  follow-up structural parser guard; not edited here.
- Inspected #632: `extract_Omega()` augmented / dep phy tier crash. This slice
  implements the local fail-loud repair. No GitHub comment or close was posted
  from this local-only branch.

## 8. What Did Not Go Smoothly

The first standalone `test_file()` run failed because package functions were not
attached. The correct focused command is the package-loaded form:

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-extract-omega.R")'
```

One mocked matrix initially used `diag(..., dimnames = ...)`, which base R does
not support; the test now assigns `dimnames()` after constructing the matrix.

## 9. Team Learning

Ada kept the slice to a truth-lock guard: no attempt to solve augmented Omega
semantics beyond preventing a misleading crash.

Emmy confirmed the extractor contract boundary: `extract_Omega()` is a
trait-level summation helper, while augmented structural coefficient blocks
belong in `extract_Sigma()`.

Curie kept the tests pure and mocked, avoiding a slow phylo slope fit for a
shape guard.

Fisher kept the estimand honest: no intercept-block extraction was promoted as a
new Omega definition.

Rose checked the wording boundary: this is a guarded redirect, not new support
for augmented structural Omega summaries.

Shannon's lane check found no open PR collision before shared dev-log and design
files were edited.

## 10. Known Limitations And Next Actions

- Issue #627 remains the next small structural parser guard.
- This slice does not add an augmented-Omega estimand. If that is wanted later,
  it needs a symbolic definition and tests, not a matrix-shape fallback.
- No broad `devtools::check()`, pkgdown rebuild, Totoro, or DRAC compute was run
  for this local extractor guard.
