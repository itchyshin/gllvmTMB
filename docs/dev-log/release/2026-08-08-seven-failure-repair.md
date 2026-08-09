# Seven-failure heavy-suite repair — 2026-08-08

## 1. Goal

Reproduce, diagnose, and repair the seven failures reported by the exact-tag
`v0.6.1-rc.1` full-check run at commit `6a58683c`: six SPDE mesh-validation
errors and one loading-bootstrap comparison failure. The repair is deliberately
limited to test fixtures. It does **NOT cover** package-wide release readiness,
simulation evidence, or a replacement for the final exact-artifact three-OS
check.

Historical CI receipt:
<https://github.com/itchyshin/gllvmTMB/actions/runs/31218105940>.

## 2. Implemented

- Changed the two seed-7 SPDE scaffold fixtures from `cutoff = 0.15` to
  `cutoff = 0.12`. With fmesher 0.8.0, the old cutoff consolidated away the
  fixture's most extreme unique location, leaving two observation rows with
  projection-matrix row sums of zero. The smaller cutoff retains mesh support
  for every simulated location.
- Increased only the quantitative loading-bootstrap/Wald comparator from 40 to
  60 bootstrap draws. The fixed-seed 40-draw run had 30 accepted refits and a
  maximum closer-bound discrepancy of 0.3299275; the 60-draw run had 46
  accepted refits and a discrepancy of 0.2758533.
- Kept the bootstrap acceptance threshold at 0.30. The other three structural
  bootstrap tests remain at 40 draws.
- Did not change public API code, the mesh validator, bootstrap implementation,
  TMB likelihood code, or user-facing documentation.

## 3a. Decisions and Rejected Alternatives

The mesh validator was not weakened. Direct inspection of the seed-7 fixture
showed 60 observation rows, 30 unique coordinates, a 37-node mesh at cutoff
0.15, and two zero-sum projection rows for the duplicated extreme coordinate
`(0.7707718, 0.08026144)`. A cutoff sweep showed that 0.12 produced a 45-node
mesh with no unsupported rows and maximum row-sum error of approximately
`2.22e-16`. This is fixture drift under the current fmesher triangulation, not
evidence that accepting unsupported data locations is safe.

The 0.30 loading-bootstrap tolerance was not relaxed. Increasing the simulated
site count was rejected because it did not stabilise the deterministic fixture:
at 100 sites a fitted loading ran to approximately 18.97 and the maximum
discrepancy was approximately 8.08; at 120 sites the discrepancy was
approximately 0.638. Increasing only the Monte Carlo resolution of the test's
comparator passed the existing scientific bound without changing package
behaviour.

An 80-draw exploratory comparator was stopped after the 60-draw result had
already established the smallest tested passing adjustment. Its interrupted
status is not a package-test failure.

## 4. Files Touched

- `tests/testthat/test-spde-slope-base-engine.R`: SPDE scaffold fixture cutoff
  and rationale comment.
- `tests/testthat/test-spatial-dep-slope-gaussian.R`: dependent-slope SPDE
  scaffold fixture cutoff and rationale comment.
- `tests/testthat/test-loading-ci-bootstrap.R`: quantitative comparator draw
  count and fixed-seed evidence comment.
- `docs/dev-log/release/2026-08-08-seven-failure-repair.md`: this receipt.

No source, generated documentation, public vignette, package metadata,
campaign sentinel, API, or TMB file was changed by this repair.

## 5. Checks Run

Environment: R 4.6.0 on `aarch64-apple-darwin23`, fmesher 0.8.0, Matrix 1.7.5,
and testthat 3.3.2.

Pre-repair reproduction:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e '
  devtools::load_all(".", compile = TRUE, quiet = TRUE)
  testthat::test_file("tests/testthat/test-spde-slope-base-engine.R", reporter = "summary")
  testthat::test_file("tests/testthat/test-spatial-dep-slope-gaussian.R", reporter = "summary")
  testthat::test_file("tests/testthat/test-loading-ci-bootstrap.R", reporter = "summary")'
```

Result: reproduced five mesh errors in the base-engine file, one mesh error in
the dependent-slope file, and the loading-bootstrap failure at 0.3299275 versus
the required `< 0.30`.

Post-repair SPDE verification:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e '
  testthat::test_local(
    ".",
    filter = "spde-slope-base-engine|spatial-dep-slope-gaussian",
    reporter = "summary",
    stop_on_failure = TRUE
  )'
```

Result: PASS, exit status 0, with no failures or errors.

Post-repair loading-bootstrap verification:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e '
  testthat::test_local(
    ".",
    filter = "loading-ci-bootstrap",
    reporter = "summary",
    stop_on_failure = TRUE
  )'
```

Result: PASS, exit status 0. The first three 40-draw structural tests each
reported their expected warning that 10 refits were rejected and 30 survived.
The 60-draw quantitative comparator reported its expected warning that 14
refits were rejected and 46 survived. No test failure occurred.

The after-task close-out compiler also passed this report, including its
required structural and evidence gates.

`devtools::document()`, package-wide `devtools::test()`, `R CMD check`, pkgdown,
and GitHub Actions were not run: this slice changed no roxygen or package code,
and its assigned verification scope was the seven historical heavy-suite
failures. The final frozen tarball still requires the release ladder's exact-
artifact checks.

## 6. Tests of the Tests

The historical exact-tag run failed with the same seven signatures on Ubuntu,
macOS, and Windows. The local pre-repair run reproduced all seven. The focused
post-repair runs then exercised the same test files with `stop_on_failure = TRUE`
and exited successfully. This red-to-green sequence shows that the fixture
changes, rather than unrelated concurrent package edits, address the named
failures.

The SPDE diagnosis also directly inspected the projection matrix and swept the
fixture cutoff. The bootstrap diagnosis retained the same seed, fitted object,
raw-Wald comparator, and numerical threshold while changing only the Monte
Carlo draw count.

## 7a. Issue Ledger

| Finding | Severity | Disposition |
| --- | --- | --- |
| Six SPDE tests used a cutoff that no longer retained every seed-7 location in mesh support | Release blocker | Repaired in the two shared scaffold fixtures; focused tests green |
| Loading comparator used only 30 accepted replicates from 40 draws and missed its unchanged bound by 0.0299275 | Release blocker | Comparator raised to 60 draws; 46 accepted and bound passes |
| Bootstrap refit-rejection warnings remain | Expected diagnostic | Retained; warnings identify the accepted replicate count |
| No post-repair three-OS exact-tarball receipt exists yet | Release blocker outside this slice | Run only after the release artifact is frozen |

## 8. Consistency Audit

Both SPDE files use the same scaffold rationale and cutoff. Only the bootstrap
test that makes a quantitative finite-Monte-Carlo comparison was increased to
60 draws; structural tests were left unchanged. The original 0.30 bound remains
literal and no package defaults were changed.

Concurrent edits elsewhere in the working tree were not modified, staged, or
reverted. Prohibited reader-facing, package-metadata, current-limits, and
campaign-sentinel surfaces were left untouched.

## 9. What Did Not Go Smoothly

The original combined reproduction used `testthat::test_file()`, whose returned
failures did not by themselves force a non-zero shell exit. The failures were
still printed and matched the CI signatures. Post-repair verification therefore
used `testthat::test_local(..., stop_on_failure = TRUE)` to make the process
status authoritative.

Changing the bootstrap fixture's site count was not a monotone route to a more
stable comparison, so that alternative was abandoned rather than encoded.

## 10. Known Residuals

- The repair has local macOS evidence only until the same frozen candidate is
  checked on Ubuntu, macOS, and Windows.
- Expected bootstrap warnings remain because failed or rejected refits are
  explicitly excluded from percentile intervals.
- This repair does **NOT cover** package-regression checks outside the three
  named files and is not simulation-based recovery, coverage, or power evidence.
- The uncommitted working tree contains concurrent work owned by other lanes;
  artifact identity must be established only after those lanes converge.

## 11. Team Learning

Mesh tests should assert support on their deterministic coordinates rather than
implicitly rely on a historically stable triangulation at an aggressive cutoff.
Finite-bootstrap comparison tests should record both requested and accepted
replicate counts; an accuracy threshold is interpretable only with that Monte
Carlo context.

Memory receipt: loaded the repository rules, the R-package engineer skill, and
the after-task protocol; applied their test-first, narrow-diff, honest-residual,
and cross-product-boundary requirements.

Golden Set: not in scope; no repository Golden Set exercise targets these two
test fixtures, and the named historical failures were checked directly.

## 12. Cross-Product Coverage

This repair covers the two SPDE scaffold families that generated all six mesh
errors and the one loading-bootstrap/raw-Wald comparator that generated the
seventh failure. It does NOT cover or expand statistical claims or feature
coverage.
Routine package CI remains package-regression evidence; simulation campaigns,
when separately authorised, remain distinct statistical evidence and do not
substitute for the final CRAN check ladder.
