# After-task: `engine = "julia"` kernel symmetry gate, review round 2 (refs #1348)

Date: 2026-10-16. PR: #1497 (draft). Lane G1b. Stacked PR #1532 sits on this
branch and was not rewritten (fast-forward commits only).

## Scope

The R reviewer blocked #1497 at `74487af` on three items: (1) the julia-path
kernel gate used `isSymmetric(tol = sqrt(eps))`, which tests a mean relative
difference, so it should be entry by entry; (2) add a ~200 x 200 test with one
1e-3 entry; (3) reword "exactly symmetric" to "symmetric to rounding". Commits
`544b3f9`/`5960e79` addressed all three in a container without R, so none of
it had been run.

## Outcome

- **The previous 200 x 200 test could not fail against the old gate.** Run in
  R 4.3.3, `isSymmetric(K, tol = sqrt(eps))` already rejected its fixture.
  Two mechanisms explain this. `all.equal.numeric()` (default
  `countEQ = FALSE`) averages only over the entries that differ, so one bad
  entry in an otherwise bit-symmetric K is never diluted. `isSymmetric()`
  also pre-checks rows 1, 2, n - 1 and n at `8 * tol`, and that fixture's bad
  entry sat at `[1, 2]`. Dilution needs rounding-level asymmetry across most
  entries (the #1348 situation) and a bad entry outside those rows.
- The forcing test now uses that case: a compound-symmetric 200 x 200 K
  (diagonal 10, off-diagonal 9) with `1e-14 * sin()` noise in every entry and
  one 1e-3 entry at `[100, 101]`. Its premise is asserted in the test
  (`isSymmetric(tol = sqrt(eps))` passes it, the entry-wise gate does not;
  mean relative difference ~6.1e-9 against 1.49e-8). A control test shows the
  same K without the bad entry passes the gate and reaches the bridge as the
  exact `(K + t(K)) / 2`.
- Gate code is unchanged in substance. The tolerance is named (`k_tol`), the
  comment now describes `isSymmetric()` correctly, and the message states the
  rule the code applies: `sqrt(.Machine$double.eps) * max(1, max|K|)`, with
  its value.
- `devtools::document()` (roxygen2 8.0.0) rewrote three `NAMESPACE` lines,
  `S3method(stats::sigma, ...)` to `S3method(sigma, ...)`. This is drift
  already on `main`: `273b777` (#1407) edited them by hand, and the roxygen
  tags (`@export` with `@importFrom stats sigma`) generate the unqualified
  form, the same as `residuals`. Registration is unchanged. It is in its own
  commit.

## Checks

- Red: the gate condition swapped back to `74487af`'s `isSymmetric()` form.
  Only the new forcing test fails: the bad kernel reaches the mocked
  `gllvm_julia_fit()`. The other three mocked tests pass.
- Green: `test-issue-1348-julia-kernel-symmetry.R` 16 expectations, 0 failures,
  1 skip (live Julia test; JuliaCall not installed).
- 14 julia-path and kernel test files: 941 expectations, 0 failures. One error
  in `test-integration-fence.R` comes from `tools::sha256sum()` (R >= 4.5)
  under the local R 4.3.3, in the EVA research route, which this change does
  not touch.
- The TMB route (`R/fit-multi.R`, absolute 1e-8 entry-wise) is untouched.

## Follow-up

- The live end-to-end test (1e-12 asymmetry through Julia) has still not run
  anywhere; it needs JuliaCall and `GLLVMODELS_JL_PATH`.
- The gate tolerance floors at `sqrt(eps)` absolute (`max(1, ...)`), so for a
  kernel scaled far below 1 it is loose in relative terms. This is the
  reviewer's chosen form; noted, not changed.
