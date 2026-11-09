# Check-log: Codecov producer/OIDC uploader (gllvmTMB only)

**Goal:** Measure real R test coverage with covr and prepare a main-only
Codecov OIDC upload path, without merging and without changing tests or
scientific code.

**Commands:**

```
git fetch origin main
git rev-parse HEAD origin/main
# both 9e35c5d84caeabe02bf2655431046785c651346d before this branch's commit

bash tools/check-actions-boundary.sh
python3 -m unittest tools/tests/test_codecov_workflow.py -v
curl -sS -X POST --data-binary @codecov.yml https://codecov.io/validate
python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/test-coverage.yaml")); yaml.safe_load(open(".github/workflows/codecov-upload.yaml")); yaml.safe_load(open("codecov.yml")); print("yaml ok")'
rg -n 'CODECOV_TOKEN|pull_request_target' AGENTS.md CONTRIBUTING.md codecov.yml .github/workflows/test-coverage.yaml .github/workflows/codecov-upload.yaml .github/workflows/R-CMD-check.yaml
rg -n 'GLLVMTMB_TEST_SHARD|covr::package_coverage|id-token: write|use_oidc' .github/workflows
command -v Rscript
curl -sS -L 'https://codecov.io/api/v2/github/itchyshin/repos/gllvmTMB'
curl -sS -L 'https://codecov.io/api/v2/github/itchyshin/repos/gllvmTMB/commits'
curl -sS -L 'https://codecov.io/api/v2/github/itchyshin/repos?active=true'
```

**Results:**

- `check-actions-boundary.sh`: PASS (five allowed workflows; 7-day coberturas).
- `test_codecov_workflow.py`: 8 tests, 0.002s, OK.
- Codecov `/validate`: starts `Valid!`; informational project/patch; `comment: false`.
- PyYAML: `yaml ok` (GitHub `on:` still `on:` on disk).
- `CODECOV_TOKEN` / `pull_request_target`: only in comments that say they are absent.
- `command -v Rscript`: empty. No local `covr::package_coverage()`.
- Codecov repo API: `itchyshin/gllvmTMB` exists with `active=false`,
  `activated=false`, `totals=null`. Commits `count=0`. Active org repos:
  pigauto only (84.98%). This is inactive-repo data, not a failed uploader
  and not proof that the Codecov GitHub App lacks a grant.

**Not run:** `devtools::test()`, `devtools::check()`, `covr::package_coverage()`
(no R on this image). Live Codecov upload (main-only after merge). Full
GitHub Actions on this branch (left running; not polled).

First producer run on `0ab5309f` (Actions 42525479166): R-CMD-check 4/4 green;
coverage shard 1 wrote `shard_percent_coverage=53.0183` and a PR coberturas
artifact; shards 2–4 failed because covr's install tree has no `00_pkg_src` /
`man` (help/source scanners) and shard 3's runaway-warning cell emitted an
AGHQ stall under tracing. Tests were not changed. Follow-up plants that
layout in `tools/run-covr-coverage.R` and stops uploading the 63 MB
instrumented tree.

**Claim boundary:** local guards and yaml validity do not show an accepted
Codecov commit report, dashboard coverage on main, C++ line coverage, or
CI completion of the instrumented shards. Shard 1's 53.0183% is one
partition only, not merged package coverage.

## 2026-11-09 follow-up: honest coverage runner (head `67cbe920` -> this commit)

**Problem on `67cbe920` (Actions 42532198109):** all four coverage shards
stopped with `test_dir(): No test files found` before any test ran. covr runs
its `code =` commands from the install directory, and the runner called
`test_check("gllvmTMB")` there, so `./testthat` did not exist. The same runner
passed `stop_on_failure = FALSE` and never read the result back, and both
upload steps used `if: always()`, so a failing shard could still write and
publish `cobertura.xml`.

**Fix:** `tools/run-covr-coverage.R` now builds the tarball as
`check-r-package@v2` does (`R CMD build --no-manual`, vignettes not built),
instruments a copy with covr, and inside covr's command step runs
`R CMD check --install=skip --library=<covr lib> --no-manual --as-cran` on the
tarball from `<workspace>/check`, with only examples/vignettes switched off.
Tests therefore run from `check/gllvmTMB.Rcheck/tests` through the unchanged
`tests/testthat.R` (same shard filter, helpers, `setup.R`, `00_pkg_src`
layout, `dev/` walk-up and `--as-cran` environment as `R-CMD-check.yaml`). A
test failure is a check ERROR, which fails covr's command step. The runner
then requires `Status:` without ERROR in `00check.log`, a
`[ FAIL 0 | ... | PASS n>0 ]` summary in `testthat.Rout`, and traced lines in
`R/gllvmTMB.R` before writing `cobertura.xml`. Upload steps use `success()`.

**Second defect found while testing the fix:** `--as-cran` runs tests against a
private library holding only declared dependencies (`tools:::setRlibs`). covr's
load and exit hooks run inside `try()`, so with covr unreachable the tests
still passed but their R coverage was dropped: the 1/200 trial reported
0.98% (R files ~0%, `src/gllvmTMB.cpp` 22% from gcov) with exit 0. The runner
now copies covr's missing closure (`covr`, `rex`) into `.Library`, proves covr
loads from a process with the test library settings, and the `R/gllvmTMB.R`
guard refuses a run without traced test coverage. A script over
`available.packages()` showed `covr` and `rex` are the only packages this
makes newly visible to tests, and no test probes for either.

**Local commands (R 4.6.2, covr 3.6.5, scratch copies of the checkout):**

```
GITHUB_WORKSPACE=<copy> RUNNER_TEMP=<tmp> NOT_CRAN=true GLLVMTMB_TEST_SHARD=1/200 Rscript tools/run-covr-coverage.R
# same, with expect_true(FALSE) appended to tests/testthat/test-sanity-multi.R
bash tools/check-actions-boundary.sh
python3 -m unittest tools/tests/test_codecov_workflow.py -v
```

**Local results:** clean 1/200 shard: `Status: 3 WARNINGs, 1 NOTE` (all three
from instrumentation: covr `:::` hooks, off-library-path load, `--coverage`
symbols; ordinary CI fails only on ERROR), `[ FAIL 0 | WARN 1 | SKIP 9 |
PASS 91 ]`, 487 traced lines in `R/gllvmTMB.R`, `shard_percent_coverage=9.5185`.
Injected failure: `Status: 1 ERROR`, `[ FAIL 1 | ... ]`, runner exit 1, no
`cobertura.xml` / `coverage-*.txt` written. Boundary PASS; Python guard 11/11.

**Shard-3 AGHQ warning from run 42525479166:** `test-runaway-warning.R:63-65`
saw `AGHQ did not converge ... stalled (no honest descent at cap 1 after
backtracking); max |grad| = 0.00188`. Locally the same fit converges with
max |grad| 0.000321 under both an ordinary `-O2` install and a `-O0 --coverage`
install, and the whole file passes 6/6 under full covr instrumentation when
run alone. In that run the earlier shard-3 files ran under the broken layout,
so the stall is session-order dependent and is re-tested by this commit's CI
run with the faithful layout. No test, tolerance or warning expectation was
changed.

**Known differences from `R-CMD-check.yaml`, all inherent to covr:**
`-O0 --coverage` compiled code, `--with-keep.source` trace-wrapped R code,
`R_COVR=true` (three `skip_on_covr()` blocks in
`test-multi-trial-binomial.R` skip), vignette outputs not built (no test reads
them), and `covr`/`rex` visible in `.Library`.
