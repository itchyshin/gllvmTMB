# After Task: Fix #1757 reviewer deparse regex and collinear z

**Branch**: `cursor/fix-1757-traits-implicit-intercept-0b8b` (PR #1774, stays draft)
**Date**: `2026-11-11`
**Roles (engaged)**: Curie (test of the test), Ada (mechanical review blockers only)

## 1. Goal

Apply only the two Code Reviewer blockers on draft PR #1774: the
`~ z + shared(x)` expectation must match the real expanded deparse, and
the fixture `z` must not be a scalar multiple of `x` so the design can
be asserted full rank with 7 columns. Leave `column_data` main-effect
`~ pathway` / `~ leaf_area` behaviour for Shinichi.

## 2. Implemented

`rewrite_traits_lhs()` injects the trait intercept with
`call("+", 0 + trait, rhs)`, so `~ z + shared(x)` deparses as
`0 + trait + ((0 + trait):z + x)`, not
`0 + trait + (0 + trait):z + x`. The test now uses `expect_identical()`
on that exact string. Fixture `z` is an 8-vector that is not affine in
`x`; the expanded model matrix is asserted to have 7 columns and
`qr()` rank 7 (3 trait intercepts, 3 `trait:z` slopes, 1 shared `x`).

## 3. Files Changed

- `tests/testthat/test-fix-1757-traits-implicit-intercept.R`
- `docs/dev-log/check-log.d/2026-11-11-fix-1757-traits-intercept-regex.md`
- `docs/dev-log/after-task/2026-11-11-fix-1757-traits-intercept-regex.md`

Not edited: `R/`, `NEWS.md`, design docs, PR body, Design 131 §4.

## 3a. Decisions and Rejected Alternatives

- **Decision:** `expect_identical()` on the exact deparse, not a looser
  `expect_match()` with extra `.*`.
- **Rejected:** changing intercept injection so the deparse loses the
  extra parentheses. That is behaviour, not a test fix.
- **Rejected:** exempt or document `0 + pathway` for `column_data`
  main effects. Awaits Shinichi (Design 131 §4).
- **Confidence:** high. CI at `75c0b0ea` printed the actual deparse;
  the rank claim was reproduced with a collinear control (`z = x/8`
  gives rank 6).

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-11-fix-1757-traits-intercept-regex.md`.
First `test_that()`: FAIL 0 / PASS 15. Fit/coef-count block not run
locally (no compiled `gllvmTMB` DLL); it already passed on CI at the
previous head.

## 5. Tests of the Tests

- **Failure-before-fix:** CI ubuntu-latest (release) shard 3/4 at
  `75c0b0ea` failed line 90 with actual text
  `0 + trait + ((0 + trait):z + x)`.
- **Boundary:** collinear `z = x/8` yields 7 columns and rank 6
  (standalone runner; not committed). Independent `z` yields rank 7.
- **Feature-combination:** `~ z + shared(x)` still expands to
  per-trait intercepts, per-trait `z` slopes, and one shared `x`.

## 6. Consistency Audit

```sh
rg -n "seq_len\\(8\\) / 8" tests/testthat/test-fix-1757-traits-implicit-intercept.R
rg -n "traits\\(.*\\) ~ pathway|~ leaf_area" tests
```

No leftover collinear fixture. No test file currently writes
`traits(...) ~ pathway` or `~ leaf_area`, so none depends on the
pending Design 131 §4 decision.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

Inspected #1757 and draft PR #1774. No comment posted. No issue
created or closed. `column_data` main-effect rank-deficiency remains
Shinichi's.

## 8. What Did Not Go Smoothly

This VM had no R. `r-base` plus a subset of Imports were installed to
run the rewrite assertions. Full `load_all()` / the second test's
`gllvmTMB()` fits were not run because `fmesher` / the package DLL
were not built.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Curie:** a start-anchored regex can still miss because `deparse()`
  adds grouping parentheses around the injected `+`. Prefer
  `expect_identical()` on the exact RHS when the AST shape is the
  claim. A scalar-multiple covariate makes a "7 columns" assertion
  pass while `qr()` rank is 6.
- **Ada:** these blockers are test-only; intercept behaviour and
  Design 131 §4 stay on the previous commits.

## 10. Known Limitations And Next Actions

`column_data` main-effect `traits(...) ~ pathway` / `~ leaf_area`
still error with `gllvmTMB_rank_deficient_design`. No current test
exercises that path. Keep PR #1774 draft.
