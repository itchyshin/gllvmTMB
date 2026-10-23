# After Task: `--as-cran` ERROR fixed — lane-b test needed the git-checkout guard

**Branch**: `claude/mspl-theorem-gated-inference`
**Date**: `2026-08-17`
**Roles (engaged)**: Curie (test fidelity) / Rose (defect-class sweep) / Grace (check conditions)
**Workspace**: worktree `/private/tmp/gllvmtmb-theorem-gated-inference`

## 1. Goal

Reproduce and fix the `--as-cran` test ERROR that the multinomial structured
arc recorded as pre-existing and out of its scope
(`docs/dev-log/after-task/2026-08-16-multinomial-structured-arc.md`). Scope was
reproduce-then-fix only: no estimator change, no SE/CI surface change.

## 2. Implemented

One guard, 8 lines, in `tests/testthat/test-mspl-simulation-contract.R` before
the `lane_b_prepare()` call at former line 132:

```r
source_root <- normalizePath(
  file.path(testthat::test_path(), "..", ".."), mustWork = FALSE
)
skip_if_not(
  file.exists(file.path(source_root, ".git")),
  "requires a source checkout for git-bound campaign receipts"
)
```

Placed **after** the pure queue-cardinality and seed-registry assertions, not at
the top of the test, so that coverage keeps executing under CRAN conditions. The
idiom is copied verbatim from the same file's already-guarded second call site
(line 968), so no new pattern enters the suite.

## 3. Files Changed

- `tests/testthat/test-mspl-simulation-contract.R` (one guard)
- `docs/dev-log/check-log.md` (prepend)
- `docs/dev-log/after-task/2026-08-17-ascran-lane-b-git-guard.md` (this file)

No `R/`, `src/`, `NAMESPACE`, NEWS, vignette, or validation-register change.

## 4. Root cause

`lane_b_checkout_head()` (`inst/sim/lane-b/lane-b-b2-runner.R:60`) shells out to
`git -C <lane_b_repo_root()> rev-parse HEAD` and `stop()`s on non-zero status.
Under `R CMD check` the tests run from a copied temp directory with no `.git`,
and `lane_b_repo_root()` (`:55`, `harness_dir/../../..`) resolves to the R
library directory rather than a checkout. So the call cannot succeed there. The
test file invoked `lane_b_prepare()` twice and carried the `.git` guard on only
one of them.

This is why the failure was invisible in isolation: every local run executes from
a source checkout where `../../.git` resolves, so the guard never mattered. The
earlier working hypothesis — single-session cross-file interference under
`test_check()` — was **wrong** and is recorded here so it is not re-tried.

## 4a. Decisions and Rejected Alternatives

- **Decision:** guard the test. **Rationale:** the campaign harness legitimately
  requires git; the *test* is what must degrade. **Rejected:** make
  `lane_b_checkout_head()` return `NA` when git is unavailable — it feeds
  `frozen$checkout_head`, a campaign-provenance pin, so that would weaken a
  receipt to paper over a harness gap. **Confidence:** high.
- **Decision:** guard mid-test, not at the top. **Rationale:** the first half of
  the test needs no git and currently passes under CRAN; a top-level skip would
  discard that coverage. **Confidence:** high.
- **Decision:** treat as a singleton after sweeping, not as a class fix.
  **Rationale:** evidence below. **Confidence:** high.

## 5. Defect-class sweep (Rose)

Five test files reach `git`. Four were already safe:

| File | Guard | Verdict |
|---|---|---|
| `test-mspl-simulation-contract.R:132` | none | **the defect** |
| `test-mspl-simulation-contract.R:968` | `.git` `skip_if_not` | safe |
| `helper-aghq-o3.R:486` | returns `NA_character_` on failure | safe |
| `test-g2d-six-species-harness.R:4` | `skip_if_not(file.exists(script))` | safe |
| `test-bfgs-smoke-contract.R:555` | `isdm_dev_path()` | safe |

`^dev$` is in `.Rbuildignore` and the built tarball contains 0 `dev/` entries,
which is why the two `dev/`-dependent files skip. Singleton status is consistent
with the observed `FAIL 1` rather than `FAIL 5`.

## 6. Checks Run

```sh
R CMD build --no-build-vignettes .
R CMD check --as-cran --no-manual --no-build-vignettes gllvmTMB_0.7.0.tar.gz
```

| | before | after |
|---|---|---|
| Status | `1 ERROR, 2 WARNINGs, 1 NOTE` | `2 WARNINGs, 1 NOTE` |
| `checking tests` | `[6m/13m] ERROR` | `[6m/10m] OK` |
| tally | `FAIL 1 \| SKIP 1565 \| PASS 8887` | `FAIL 0 \| WARN 0 \| SKIP 1566 \| PASS 8887` |

`PASS` identical (no coverage lost), `SKIP` +1, and the skip reason
`requires a source checkout for git-bound campaign receipts` goes from 1 to 2
instances — the guard fires on exactly one site and nowhere else.

Also: `testthat::test_file("test-mspl-simulation-contract.R")` from a source
checkout, before and after and again after rebase onto `b3fa0a7f` — unchanged at
35 tests / 206 expectations / 0 failed / 1 skipped, confirming the guard does not
fire where `.git` exists.

Not run: full `devtools::test()`, pkgdown, 3-OS. The two residual WARNINGs are
artifacts of `--no-build-vignettes` (absent `inst/doc`, unrendered
`gllvmTMB.Rmd`), not of this change; the NOTE is the benign
`New submission` / no-vignette-index pair.

## 7. Tests of the Tests

- The guard fails to protect if `lane_b_repo_root()` is ever changed to resolve
  inside the installed package — then `rev-parse` would fail while `.git` still
  exists at `source_root`, and the test would error again rather than skip.
- The `SKIP 1565 -> 1566` delta is the load-bearing evidence: a larger jump would
  mean the guard is over-firing and silently dropping coverage.
- If the queue-cardinality assertions before the guard ever regress, the test
  still reports a failure rather than a skip, because those expectations execute
  before the skip condition is evaluated.

## 8. Process failure worth recording

Two separate false-green signals occurred while verifying, both pointing toward a
result not yet obtained:

1. A watcher polled for the check process during the `R CMD build` phase, found
   nothing running, and reported completion. **Process absence is not evidence of
   completion.**
2. A relaunch used the same fixed scratch directory and `rm -rf`-ed it while the
   previous run was still alive, destroying that run's tarball mid-flight
   (`CHECK START ... on ` with an empty filename, `rc=1` one second later). **A
   fixed scratch dir plus `rm -rf` is unsafe for concurrent runs.**

The reported verdict comes from the tracked run's own log, not from a wrapper
exit code.

## 9. Standing fences untouched

`Q_0` remains the paper-aligned SE reporting target and `Q_P` availability-only
(D-149, #1061); MSPL-04 stays `blocked`; no public `se=TRUE`, `vcov()`, or
`confint()`; the interval programme remains a separate lane. Two maintainer
decisions remain open and unactioned: per-coordinate blanking of negative
inverse-diagonals per 2023 Table 3, and the G0 keep-or-replace call on Poisson
`W = diag(mu)` (#1064).

## 10. Follow-up

- The multinomial arc's attribution was **correct**; its stated reason ("the
  failure reproduces identically on `origin/main`") holds only under `--as-cran`,
  never under `test_local`/`test_file`. Worth phrasing as condition-specific in
  future notes so the next lane does not waste a cycle failing to reproduce it.
