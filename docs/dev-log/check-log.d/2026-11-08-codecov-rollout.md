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
