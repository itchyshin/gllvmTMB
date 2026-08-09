# Lane B MSPL recovery checkpoint — 2026-08-09 01:00 MDT

## Branch and worktree

- Worktree: `/private/tmp/gllvmtmb-lane-b-mspl`
- Branch: `codex/lane-b-mspl-20260808`, based on `origin/main`.
- The main checkout remains untouched.
- `git diff --check`: PASS after the targeted-quasi lock-cleanup repair.
- The dirty tree is the intended B0/B1/B2 implementation, tests, documentation,
  and simulation harness. Do not use `git add -A`; stage the Lane B paths
  explicitly at handoff.

## Locally complete

- B0 opt-in fixed-design screening is implemented for complete single-trial
  Bernoulli logit, probit, and cloglog responses.
- B1 `estimator = "mspl"` is implemented as an opt-in LA-MSPL point estimator;
  the default `estimator = "ml"` route remains unchanged.
- The admitted surface is fenced to the documented complete-Bernoulli ordinary
  and spatial regimes. Unsupported likelihood, integration, missing-data, and
  inference routes fail closed.
- The weighted-information determinant uses the numerically guarded max-volume
  backend and reports typed failure/status diagnostics. Public text does not
  claim formal interval certification of the returned value or derivatives.
- The Tier-1 MSPL article, pre-fit screening article, function documentation,
  NEWS entry, design note, citations, and draft after-task report are present.
- Pat, Curie, the inference-surface audit, and the final mathematical/claim audit
  returned PASS on their bounded reviews.

## Local verification evidence

- Full `devtools::test(reporter = "summary", stop_on_failure = TRUE)`: PASS;
  two pre-existing comparator warnings only.
- `pkgdown::check_pkgdown()`: PASS.
- Both affected articles rendered successfully with
  `pkgdown::build_article()`.
- Fresh `devtools::check(args = "--no-manual")`: 0 errors, 0 warnings, 1
  environment NOTE (`xcrun_db`).
- Focused `mspl-api`, profile-CI, separation-screening, and simulation-contract
  tests: PASS.
- The post-launch targeted-quasi lock cleanup is explicit and idempotent; its
  focused regression test passes. Frozen Fir workers are not modified mid-run.
- `git diff --check`: PASS.

## Remote evidence state

### Totoro main B2

- Root: `/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1`
- Frozen manifest: 8,472 shards, 130,800 datasets, 561,600 primary fits plus
  retained alternate starts.
- Snapshot at this checkpoint: 640 complete, 120 running, 0 failed.
- Workers are active on the later high-dimensional cells. Do not add workers;
  total observed Totoro use is already near the 150-core project ceiling.

### Exact B0 supplement

- Complete: 2,880 / 2,880 shards and 72,000 unique ordinary datasets.
- Exact labels: 39,493 overlap; 11,173 complete; 21,329 constant; five
  quasi-complete; zero `NOT_CHECKED`.

### Fir targeted quasi-complete supplement

- Array: `53828776`; aggregate: `53828777`; keeper: `53828788`.
- Frozen manifest: 600 shards, 6,000 datasets, 24,000 primary fits.
- Snapshot at this checkpoint: 211 complete, 30 running, 0 failed; remaining
  array indices pending under the `%30` throttle.
- Frozen worker scripts leave a stale lock after successful completion because
  top-level `on.exit()` is ineffective. This is a state-hygiene defect only:
  attempt files, completion receipts, aggregation, and promotion logic do not
  consume the lock count. The shipping harness fixes this explicitly and has a
  regression test.

## Still required for completion

1. Let Totoro and Fir finish without altering their frozen estimator or fixture
   surfaces.
2. Run and independently inspect the immutable aggregators and strict promotion
   gates, retaining every failed attempt in denominators.
3. Promote ordinary and spatial cells independently; update the validation-debt
   register, article/NEWS scope, check log, and after-task report with exact
   evidence paths and hashes.
4. Re-run final full tests, pkgdown, article renders, and package check after the
   evidence-driven documentation updates.
5. Complete final Rose/Grace/Shannon audits, make a scoped commit, push the
   branch, open the PR, and require green 3-OS CI before claiming the 0.7 Lane B
   deliverable complete.

## Next safest action

Monitor both immutable campaigns. When Fir finishes, inspect its automatically
chained aggregate and keeper before touching public claims. Continue only local
closure work that cannot pre-empt the B2 verdict.
