# After Task: Sparse propto precision marginalization

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: Ada / Noether / Fisher / Curie / Grace / Rose / Shannon

## 1. Goal

Fix issue #636 locally: the sparse `propto()` adapter must not treat a submatrix
of a precision matrix as the marginal precision when the sparse `Ainv` contains
extra nodes beyond the fitted species levels.

## 2. Implemented

- Added `.resolve_sparse_propto_precision()` in `R/fit-multi.R`.
- Kept the exact tip-only sparse `Ainv` route unchanged: reorder to fitted
  levels, use the sparse precision directly, and compute `log_det_Cphy` as
  `-logdet(Ainv)`.
- For sparse precision matrices with extra nodes, invert the full precision to
  covariance, subset the marginal covariance to fitted levels, add the same
  small jitter as the dense adapter, then invert that submatrix for `Cphy_inv`.
- Added pure matrix tests proving the extra-node route differs from the old
  precision-subset result and matches the inverse marginal covariance.

## 3. Files Changed

- `R/fit-multi.R`
- `tests/testthat/test-stage3-propto-equalto.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-sparse-propto-precision-marginalization.md`

## 3a. Decisions and Rejected Alternatives

Decision: implement the correct extra-node marginalization rather than fail
loud. Rationale: `propto()` already uses a dense adapter downstream, and the
correct operation is cheap for the small matrices this route admits. Rejected
alternative: keep using `Ainv[levs, levs]`; that is mathematically wrong for
augmented precision matrices. Confidence: high for the matrix identity; broader
large-p performance remains a separate design issue.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("tests/testthat/test-stage3-propto-equalto.R")); cat("parse-ok\n")'
```
Outcome: `parse-ok`.

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage3-propto-equalto.R", reporter = "summary")'
```
Outcome: passed; one pre-existing glmmTMB non-PD-Hessian skip in the combined
smoke cell.

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-pedigree-sparse-ainv-engine.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-phylo-vcv-A-aliases.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load-all-ok\n")'
git diff --check
```
Outcome: sparse Ainv tests passed; phylo A/Ainv alias tests passed; `load_all`
passed; diff whitespace check passed.

## 5. Tests of the Tests

The first new test constructs a positive-definite full covariance, converts it
to sparse precision, fits only a subset of levels, and checks that the resolver
matches `solve(C_full[levs, levs] + jitter)` while differing from the old
precision submatrix. The second test checks the exact tip-only path with
reordered levels so the compatibility route remains covered.

## 6. Consistency Audit

```sh
rg -n "Ainv_sub|Subsetting a precision|precision.*submatrix|sparse.*propto" R/fit-multi.R tests/testthat/test-stage3-propto-equalto.R docs/design/35-validation-debt-register.md
```
Verdict: found only the new resolver, tests, and validation-register wording.

```sh
rg -n "partial support|ready to expose|bootstrap rescue|source-specific.*support|mixed-family CI" docs/dev-log/dashboard docs/design docs/dev-log/check-log.md
```
Verdict: hits are historical guard/dashboard language; this slice adds no
support, interval, source-specific `lv`, mixed-family CI, or compute claim.

## 7. Roadmap Tick

N/A. This is a robustness repair inside an existing covered sparse `Ainv` /
`propto()` route, not a roadmap status promotion.

## 7a. GitHub Issue Ledger

- Inspected issue #636:
  https://github.com/itchyshin/gllvmTMB/issues/636
- Issue #636 remains open upstream because this local fix has not been pushed or
  included in a PR.

## 8. What Did Not Go Smoothly

The issue is subtle because the old path is correct when the sparse precision
row set is exactly the fitted tip set. The fix therefore had to keep that path
intact while changing only the extra-node case.

## 9. Team Learning

Ada kept the slice local and focused: one adapter helper, one branch swap, and
one pure math regression.

Noether checked the matrix identity: subsetting a precision matrix is not the
same as marginalizing a covariance matrix unless the precision is already the
complete fitted block.

Fisher kept the claim boundary narrow. This is not a new interval claim or
calibration result.

Curie kept the regression pure and fast, then widened to the existing sparse
Ainv and A/Ainv alias tests.

Grace verified parse, package load, focused tests, and whitespace hygiene.

Rose checked that no stale source-specific `lv`, mixed-family CI, bootstrap
rescue, or public-support wording changed.

Shannon confirmed no open PR lane was returned before shared ledger edits.

## 10. Known Limitations And Next Actions

This does not make sparse `propto()` a large-scale sparse runtime engine; it
corrects the dense adapter math. The next cleanup slices remain the current
issue-burn-down queue: finish local issue fixes, then refresh the completion
matrix and decide which surface deserves the next small PR.
