# After Task: devtools::test() triage for issue #1563

**Branch**: `fix/gtmb1563-snak`
**Date**: `2026-10-31`
**Roles (engaged)**: `Claude Code (triage only)`

## 1. Goal

Issue #1563 reports that a local `devtools::test()` on `main` fails in tests
that skip under `R CMD check`, so PR CI stays green. It names two source-scan
failures and lists eleven more for triage, asking for a maintainer-machine run
to show which are real. This report is that run.

## 2. Implemented

No code or test changes. The two failures named in the issue title were already
fixed on `main` by PR #1609 (`83372186`), which said "Part of #1563" and so
left the issue open. Every remaining failure needs a maintainer decision,
listed in section 10.

## 3. Files Changed

- `docs/dev-log/after-task/2026-10-31-issue-1563-devtools-test-triage.md` (this file)

## 3a. Decisions and Rejected Alternatives

Decisions: none. Each remaining failure is either a reader-facing claim
boundary, a provenance pin, a visual-review gate, or a numerical tolerance.
Making any of them pass would mean deciding the wording or the tolerance, so
none was changed.

## 4. Checks Run

Machine: macOS (Darwin 25.6.0), R 4.6.0, TMB 1.9.21, testthat 3.3.2, en_US.UTF-8.
`main` @ `80b0129f`.

```
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MAKEFLAGS=-j4 Rscript -e \
  'options(testthat.progress.max_fails = 100000); devtools::test(reporter = "summary", stop_on_failure = FALSE)'
```

Result: 755 files, **FAIL 18, ERROR 1**, SKIP 905, PASS 32552, in 12 files.
Each failing file was then rerun in small filtered groups with
`devtools::test(filter = ...)`. Eleven failed again the same way.
`test-va-r3-prototype.R` passed in one filtered rerun and failed in another,
so it is intermittent on this machine.

| File | Kind | Status on this Mac |
|---|---|---|
| `test-control-field-surface.R` | source scan | passes (fixed by #1609) |
| `test-loading-unpack-contract.R` | source scan | passes (fixed by #1609) |
| `test-interval-calibration-ci09.R:369` | source scan, git | **fails**: orphaned pinned commit |
| `test-interval-calibration-claims.R:30,35,166,181,196,203` | source scan | **fails**: wording drift |
| `test-reader-facing-no-register-codes.R:120` | source scan | **fails**: wording drift |
| `test-article-prescribed-calls.R:282` | source scan | **fails**: article drift |
| `test-plot-visual-snapshots.R:301,327,353` | vdiffr, `skip_on_ci()` | **fails**: sub-pixel drift |
| `test-aghq-multistart-convergence.R:197` | numeric, `skip_on_cran()` | **fails** |
| `test-restart-selection-1335.R:83` | numeric, `skip_on_cran()` | **fails** |
| `test-suggest-lambda-constraint.R:238` | numeric, `skip_on_cran()` | **fails** |
| `test-va-r3-prototype.R:116,121` | numeric, `skip_on_cran()` | **fails intermittently** |
| `test-g3-smallest-smoke-packets.R`, `test-gapclose-parity-ledger.R`, `test-m3-pilot-manifest.R`, `test-isdm-diagnostic-runner.R`, `test-mspl-simulation-contract.R`, `test-zz-mspl-fenced-family-tapes.R` | various | pass (container-specific in the issue) |

## 5. Tests of the Tests

Not applicable: no test was added or modified.

## 6. Consistency Audit

Sibling check for pinned commits that cannot be fetched:

```
grep -ohE '"[0-9a-f]{40}"' tests/testthat/*.R | sort -u   # 3 SHAs
git cat-file -e <sha>^{commit}                             # after git fetch origin
```

Two are missing from `origin`: `822024b1` (checked out by `test-interval-calibration-ci09.R`)
and `328d8abc` (compared only as a string in ci09/ci10, so harmless). The GitHub
compare API returns 404 for `822024b1`, and `git fetch origin 822024b1...`
answers "not our ref". It looks like a branch head lost when its branch was squash-merged.

Source-scan exposure: 63 test files reach the repository via
`test_path("..", "..")`, and 32 guard it with `skip_if_not(dir.exists/file.exists)`.
`R CMD check` runs none of those, so the PR CI cannot see their drift.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

#1563 inspected. PR #1609 (merged) fixed the two titled failures. This PR
refers to #1563 but does not close it.

## 8. What Did Not Go Smoothly

`main` tracks eleven `tests/testthat/_snaps/plot-visual-snapshots/*.new.svg`
files, added by `a6aecc0e` (#1487). testthat deletes or rewrites `.new.svg`
on every run, so any local `devtools::test()` leaves the working tree dirty.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

A guard test that only runs locally drifts as soon as reader-facing pages
are edited. The plain-language PRs #1288, #1290, #1294 and #1297 all changed
text that `test-interval-calibration-claims.R` and
`test-reader-facing-no-register-codes.R` pin. Their PR CI stayed green
because those tests skip under `R CMD check`.

## 10. Known Limitations And Next Actions

Questions for the maintainer, one per failure class:

1. **Interval claim wording** (`test-interval-calibration-claims.R`,
   `dev/interval-calibration/verify-claims.R`). README, DESCRIPTION,
   `R/zzz.R` and `man/gllvmTMB-package.Rd` no longer contain "one fixed
   simulated dataset with known true values" / "only for fits that converge
   cleanly". `_pkgdown.yml` lacks "frozen DGP" / "conditional on eligible
   fits". `current-limits.Rmd` lacks "withdrawn until the mechanism is
   repaired and recalibrated". Restore the boundary wording on those
   surfaces, or update the guard to the new plain-language phrasing (which
   phrases count as the boundary)?
2. **pkgdown navigation** (`test-reader-facing-no-register-codes.R:120`).
   The nav no longer contains "How gllvmTMB is checked — and what those
   checks miss". Restore the entry, or update the test to the current title?
3. **Orphaned frozen source** (`test-interval-calibration-ci09.R:369`).
   Commit `822024b1` cannot be fetched from GitHub. Should it be re-pinned
   to the merged commit that holds the same `R/` and `dev/interval-calibration/ci09/`
   tree, or should the test skip when the pinned commit is unavailable?
   Either choice changes what the CI-09 frozen-source guarantee means.
4. **Article sketch** (`test-article-prescribed-calls.R:282`).
   `vignettes/articles/api-keyword-grid.Rmd:393` runs `dat$species <- dat$trait`
   in an `eval = FALSE` sketch, and `dat` is defined nowhere in the article
   (added by `8abd9a00`, #1161). Define `dat` earlier in the article, or
   rewrite the sketch so it doesn't operate on `dat`?
5. **Visual snapshots** (`test-plot-visual-snapshots.R`). Three SVGs differ by
   0.01 px in one or a few coordinates (for example `187.70` vs `187.69`). The
   file says not to regenerate merely to make a local run green. Accept the
   new snapshots after visual review, or round the fitted coordinates?
   Separately, should the eleven tracked `*.new.svg` files from `a6aecc0e` be
   deleted, and `*.new.svg` added to `.gitignore`?
6. **Numeric tolerances** (`aghq-multistart-convergence`, `restart-selection-1335`,
   `suggest-lambda-constraint`, `va-r3-prototype`). These run in PR CI
   (`NOT_CRAN=true`, ubuntu) and fail on this Mac. Examples: restart
   objective 268.7 vs 267.6, `healthy_starts` 3 vs 4, "Tested 10 entries;
   1 skipped" vs 11/0. Unverified: whether they also fail on current Linux CI
   (the last completed `full-check.yaml` succeeded on 2026-09-30, and the
   2026-10-26 run was cancelled). If they pass on Linux, these are
   platform-sensitive optima. Should the tests be made platform-robust or
   pinned to Linux?
7. **Structural gap** (the issue's root cause). Should PR CI run the
   repository-only source-scan tests against the checkout? One option is a
   cheap extra step after `check-r-package` that runs
   `testthat::test_local(filter = <source-scan files>)`. This costs CI minutes
   and is a workflow decision.
