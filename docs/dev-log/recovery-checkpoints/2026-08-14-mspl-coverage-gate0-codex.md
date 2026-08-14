# Recovery checkpoint — LA-MSPL coverage calibration Gate 0

- Branch: `codex/lane-b-mspl-interval-feasibility`
- Starting HEAD: `ee206bfd`
- Starting status: clean; branch ten commits ahead of its remote tracker.
- Goal: implement and locally verify Gate 0 of the approved coverage campaign,
  then advance through DRAC Gates 1--4 and stop for production approval.
- Active owners:
  - Codex parent: integration, local verification, remote gates, durable logs.
  - coverage-runner worker: new coverage runner and its focused test.
  - DRAC-launcher worker: new scripts under the MSPL coverage subdirectory.
- Completed read-only checks: Ultra Plan instructions; repository route
  manifest; lane preflight; current/all-ref history; Arc 3 source, tests, and
  closeout; public fence scan; brain DRAC lessons; current DRAC readiness.
- GitHub limitation: `gh pr list --state open` could not reach
  `api.github.com`; the committed coordination board and local all-ref log
  are the fallback.
- Commands still required: focused runner tests, focused MSPL tests,
  local miniature shard round-trip, `bash -n`, static fence audit,
  `git diff --check`, then DRAC Gates 1--4.
- Next safe action: integrate the two disjoint Gate 0 implementation slices,
  review their exact-key and objective-role contracts, and run pure tests
  before any fit.
- Hard stop: do not submit the full 1,200-task campaign without the
  maintainer's approval of the Gate 4 receipt.
