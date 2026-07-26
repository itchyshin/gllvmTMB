# `test-getlv-se.R` CI fragility fix — diagnosis and verification

Branch: `claude/getlv-score-se-20260725`. Worktree:
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-getlv-se`. PR #792.

## Diagnosis

PR #792's CI run
(https://github.com/itchyshin/gllvmTMB/actions/runs/30181760156) failed on
`ubuntu-latest` with:

```
── Error ('test-getlv-se.R:60:3'): (code run outside of `test_that()`) ──
Error in eval(...): isTRUE(fit$sd_report$pdHess) is not TRUE
[ FAIL 1 | WARN 3 | SKIP 787 | PASS 7361 ]
```

Line 60 was `stopifnot(isTRUE(fit$sd_report$pdHess))` inside the module-scope
`.getlv_se_fit_BW <- local({ ... })` block — the two-tier
`latent(0 + trait | site, d = 2) + latent(0 + trait | site_species, d = 1)`
fixture (n_sites = 80, n_species = 12, n_traits = 4). This `stopifnot()` runs
*outside* any `test_that()`, at file-sourcing time, so when it fails it
aborts the entire test file (halting all 10 tests below it, not just the two
that actually need the two-tier structure).

The failure is BLAS/platform-sensitive fixture fragility, not a feature bug:
locally on macOS/ARM the same fixture (same seed, same config) converges
with `pdHess = TRUE` every time; on `ubuntu-latest`'s BLAS/LAPACK it does
not. `getLV(se = TRUE)`'s handling of a non-PD Hessian is itself correct and
already tested — it warns and returns `NA` standard errors
(`R/output-methods.R`, `.getLV_se()`, the `if (!isTRUE(sd_rep$pdHess))`
branch) rather than erroring.

The single-tier `.getlv_se_fit_B` fixture (used by 8 of the 10 tests) was
NOT implicated in the CI failure — its own module-scope `stopifnot()` at
line 38 did not fire on ubuntu-latest per the CI log (the file aborted at
line 60, inside the *second* fixture block, so the first fixture's
`stopifnot()` had already passed). It is left unchanged.

## Fixture change

1. **Single-tier `.getlv_se_fit_B`**: unchanged, still built once at module
   scope with its own `stopifnot(isTRUE(pdHess))`. It is already the
   fixture used by every test that doesn't specifically need the z_W /
   `level = "unit_obs"` block (shape/dimnames, the joint-precision
   cross-check, the reshape ordering-hazard guard, rotate/lv/no-sdreport/
   no-rr-term gating) — no simplification was needed there; it already
   matched option 1 in the brief ("a single-tier fixture may be entirely
   sufficient").

2. **Two-tier `.getlv_se_fit_BW` → `.build_getlv_se_fit_BW()`**: converted
   from a module-scope `local({...})` block with `stopifnot()` into a
   plain builder *function* (identical simulate + fit code, `stopifnot()`
   removed). It is called inside each of the two `test_that()` blocks that
   actually need the two-tier structure:
   - `"getLV(level = 'unit_obs', se = TRUE) uses the z_W block with
     matching shape"` — this test needs real (non-NA) SE values (it
     asserts `is.finite`, `> 0`, and numeric agreement with an
     independently-recomputed SE), so it now checks
     `fit$sd_report$pdHess` right after building the fixture and calls
     `testthat::skip("two-tier (B+W) getlv-se fixture did not converge to
     a PD Hessian on this platform")` if it is not `TRUE`, instead of
     erroring the file.
   - `"getLV(level = 'unit', se = TRUE) on the B+W fit still reads z_B,
     not z_W"` — this test's assertions are shape-only
     (`nrow`/`ncol` equal to `fit$n_sites`/`fit$d_B`), and `.getLV_se()`
     resolves the `z_B`/`z_W` block by *name and length* before it ever
     inspects `pdHess` (the NA-filled non-PD fallback has the identical
     dims as the real one). So this test does **not** skip on a non-PD
     Hessian — it deliberately keeps running unconditionally, because
     (see next section) it is the load-bearing regression guard for the
     historical level-name mix-up bug, and skipping it under exactly the
     platform condition that triggered this fix would defeat the point.

   Each test now builds its own fixture instance (`set.seed(2025)` inside
   the builder makes both instances byte-identical), so this trades one
   extra ~small multivariate TMB fit for full per-test isolation — the
   same idiom already used in `tests/testthat/test-matrix-poisson-unit.R`
   (`.fit_pois_unit()` + `.unhealthy_reason()` + `skip(reason)`, built
   fresh inside each consuming `test_that()`).

Per the brief's option 3, nothing was reduced to "delete the assertion and
let downstream tests run against a non-PD fit": both consumers explicitly
check `pdHess` and either skip honestly (numeric-SE test) or rely on an
assertion that is provably PD-independent (shape test) — never silently
asserting on NA values.

## Proof the block-ordering / level-dispatch guard is still live

The brief's CRITICAL section names "the BLOCK-ORDERING regression guard...
it caught a real bug during development where `.canonical_level_name(level)`
was passed instead of `level`, making every request silently read the `z_W`
block" — this identifies the **level-dispatch** guard, i.e. test #10,
`"getLV(level = 'unit', se = TRUE) on the B+W fit still reads z_B, not
z_W"` (matching the file's own header comment about "the level-name
mix-up... every test below failed until it was fixed").

Verification performed on `R/output-methods.R`:

1. Changed line 187 from
   `se_mat <- .getLV_se(fit, level = level, scores = ord$scores)` to
   `se_mat <- .getLV_se(fit, level = .canonical_level_name(level), scores = ord$scores)`
   — reproducing the exact historical bug (passing the user-facing
   `"unit"`/`"unit_obs"` name instead of the internal `"B"`/`"W"` slot name
   that `.getLV_se()`'s `if (level == "B") "z_B" else "z_W"` requires).
2. Re-ran `test-getlv-se.R`. Result: **4 tests now error** (tests #1, #3,
   #4, #6, all built on `.getlv_se_fit_B`, which has no `z_W` block at all
   — `.getLV_se()` now always resolves to the nonexistent `z_W` name and
   hits the `gllvmTMB_getLV_se_block_mismatch` path / a length-0 index),
   and **test #10 itself errors**: `.getLV_se()` now always reads the
   `z_W` block (`d_W = 1`, `n_site_species` ≫ 80) but its output gets
   `dimnames(se_mat) <- dimnames(scores)` assigned from the *correct*
   `ord$scores` (shape `80 × 2`, since `extract_ordination()` on line 177
   was untouched) — an R-level dims mismatch error
   (`'dimnames' applied to non-array`-class error from the shape clash).
   Confirmed via `testthat::test_file()`: `error = TRUE` for test #10
   (and #1/#3/#4/#6), `failed = 0` for the rest — i.e. the guard fires as
   an uncaught error, which `testthat` reports as a failing test, exactly
   as required ("that test must still be able to fail if the ordering is
   wrong").
3. Reverted line 187 to the original
   `se_mat <- .getLV_se(fit, level = level, scores = ord$scores)`.
   Confirmed via `git diff R/output-methods.R` that the file is byte-for-
   byte identical to the committed version (empty diff) — the deliberate
   breakage left no residue.
4. Re-ran `test-getlv-se.R`: back to 10/10 passed, 27/27 expectations,
   0 failed/skipped/error/warning.

**Residual finding, not fixed (out of the requested scope, mentioned per
the "surgical changes" rule):** the *other* ordering guard in this file —
`"getLV(level = 'unit_obs', se = TRUE) uses the z_W block with matching
shape"`'s internal reshape check (comment: "Same ordering-hazard guard as
the unit-level test, at the W tier") — is not actually able to detect an
nrow/ncol-swapped reshape at the z_W tier, because `d_W = 1` in this
fixture: `t(matrix(v, nrow = 1, ncol = n))` and `matrix(v, nrow = n, ncol
= 1)` are the identical `n × 1` matrix whenever `d = 1` (there is no
column permutation to get wrong with only one column). I verified this
directly: deliberately swapping the z_W-tier reshape in `.getLV_se()`
(`matrix(se_vec, nrow = n, ncol = d)` instead of
`t(matrix(se_vec, nrow = d, ncol = n))`) did **not** fail test #9's
`expect_equal(out$se, se_correct, ...)` at line 238, precisely because
`d_W = 1` makes the two reshapes numerically identical. This is a
pre-existing property of the original fixture/test (not introduced by this
change) and does not affect the guard the brief asked me to verify (the
`d_B = 2` B-tier reshape test, and the level-dispatch test, both of which
I confirmed above are live). Flagged for a maintainer decision (e.g. bump
`d_W` to 2 in a future revision) rather than silently changed here.

## Rebase / merge

`main` had moved 2 commits ahead of this branch's fork point (#790, #791:
docs handover + the "typed droplevels error, lv/axis_effect docs"
usability fix). I **merged** `origin/main` into
`claude/getlv-score-se-20260725` (`git merge origin/main --no-edit`,
commit `109d2080`) rather than rebasing, to avoid rewriting already-pushed
branch history. The merge was clean (no conflicts); `NAMESPACE` was
untouched by either side (see below).

## Test counts

`devtools::test(filter = "getlv")` (via
`testthat::test_file("tests/testthat/test-getlv-se.R")`), after the fix,
on macOS/ARM:

```
10 test_that() blocks, 27 expectations
passed: 27   failed: 0   skipped: 0   error: 0   warning: 0
```

Per-test breakdown (`nb` = expectations in that test):

| # | test | nb | failed | skipped | error |
|---|------|----|----|----|----|
| 1 | returns a list with scores + se of matching shape | 5 | 0 | 0 | 0 |
| 2 | se = FALSE unaffected | 2 | 0 | 0 | 0 |
| 3 | agrees with joint-precision-inversion route | 1 | 0 | 0 | 0 |
| 4 | correct (unit-major) reshape, not swapped | 5 | 0 | 0 | 0 |
| 5 | errors when rotate != 'none' | 1 | 0 | 0 | 0 |
| 6 | errors for predictor-informed lv fit | 1 | 0 | 0 | 0 |
| 7 | errors cleanly when fit has no sdreport | 2 | 0 | 0 | 0 |
| 8 | returns NULL when no rr term at level | 1 | 0 | 0 | 0 |
| 9 | unit_obs / z_W block matching shape | 7 | 0 | 0 | 0 |
| 10 | still reads z_B, not z_W (B+W fit) | 2 | 0 | 0 | 0 |

Both two-tier fixture builds converged with `pdHess = TRUE` locally (the
`skip()` branch in test #9 was not exercised on this platform — expected,
since the CI failure was ubuntu-specific and unreproduced here).

`devtools::test_dir("tests/testthat", filter = "getlv|extractors")`: all
green (`extractors`, `extractors-extra`, `getlv-se`), plus the pre-existing,
unrelated `m2-2b-binary-cis-extractors` heavy-test skips
(`GLLVMTMB_HEAVY_TESTS` gate, unaffected by this change).

Full `devtools::test_dir("tests/testthat")` (whole suite):
[FILLED IN AFTER THE BACKGROUND RUN COMPLETES]

No warnings were suppressed or grepped away; the only warnings observed
anywhere in these runs were the package's own one-shot deprecation /
identifiability-gate `cli::cli_inform`/`cli_warn` messages already present
on `main` (e.g. `phylo()`/`gr()`/`diag()` alias deprecations), unrelated to
this fix.

## NAMESPACE check

`git diff origin/main -- NAMESPACE` (after the merge): **empty** —
byte-identical. `devtools::document(quiet = TRUE)` was also run after the
edit and produced no changes to `NAMESPACE` or `man/` (only
`tests/testthat/test-getlv-se.R` shows as modified in `git status`).

## Files changed

- `tests/testthat/test-getlv-se.R` — the fixture-robustness fix described
  above (30 insertions, 12 deletions).
- `dev/getlv-se-ci-fix-RESULTS.md` — this file.
- Merge commit `109d2080` bringing in `origin/main` (#790, #791); no
  source files touched by the merge itself beyond the usual merge diff
  (see `git log` for the full file list).
