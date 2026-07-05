# After Task: Coevolution Focused Checks

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Curie / Rose / Ada`

## 1. Goal

Run the coevolution/kernel focused checks named in the completion branch review
package map.

## 2. Implemented

No code changed. This is evidence-only.

## 3. Files Changed

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-coevolution-focused-checks.md`

## 3a. Decisions and Rejected Alternatives

Decision: run `test-coevolution-prototype.R` and
`test-coevolution-recovery.R` with `GLLVMTMB_HEAVY_TESTS=1`.

Reason: the non-heavy pass skipped the actual recovery cells.

Rejected alternative: run `test-coevolution-two-kernel.R` immediately.

Reason: the review map marks that file as larger and time-budget dependent.

## 4. Checks Run

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-prototype.R", reporter = "summary")'
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-recovery.R", reporter = "summary")'
```

Outcome: both passed their non-heavy checks but skipped heavy recovery cells.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-prototype.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-coevolution-recovery.R", reporter = "summary")'
```

Outcome: both passed.

## 5. Tests of the Tests

The heavy rerun matters because the planted-Gamma and C2 kernel recovery cells
are skipped otherwise.

## 6. Consistency Audit

These checks support the local review package only. They do not turn exploratory
coevolution surfaces into broad public claims.

## 7. Roadmap Tick

Coevolution/kernel focused checks now have fresh local evidence.

## 7a. GitHub Issue Ledger

No issue was closed or commented.

## 8. What Did Not Go Smoothly

No blocker.

## 9. Team Learning

For coevolution surfaces, the heavy flag separates syntax/shape tests from
actual planted-signal recovery.

## 10. Known Limitations And Next Actions

- `test-coevolution-two-kernel.R` was not run.
- Release-level checks remain pending.
