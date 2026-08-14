# Recovery checkpoint — MSPL coverage calibration Gate 4

Date: 2026-08-14
Platform: Codex
Branch: `codex/lane-b-mspl-interval-feasibility`
Gate 0 source: `112931db32088b5ff8c460ff9e89a7ef81d10c96`

## Current state

Gates 1--4 are complete and the full campaign is hard-stopped. The public MSPL inference fence is unchanged. A new immutable commit is pending for permanent launcher repairs and explicit Gate 4 aggregation.

Changed files before this checkpoint:

- `inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R`
- `tests/testthat/test-mspl-coverage-runner.R`
- six files under `inst/sim/lane-b-uncertainty/mspl-coverage/`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md`
- `docs/dev-log/check-log.md`
- this checkpoint

## Evidence completed

- Gate 1: setup/smoke/array `sbatch --test-only` accepted on Nibi, Narval, and Rorqual; staged hashes matched.
- Gate 2: cluster-native runtimes passed finite-objective receipts; no cross-cluster compiled binary reuse.
- Gate 3: 9/9 exact link-by-cluster smokes; 9 outer, 18 bootstrap, 81 endpoints, 885 traces.
- Gate 4: 12/12 shards; 120 outer; 60,000 bootstrap; 1,080 endpoints; 11,576 traces; zero missing/duplicate keys.
- Operational availability: bootstrap 360/360, profile 358/360, Wald 279/360.
- Resource receipt: 4:48--9:45 wall; median 7:15.5; maximum RSS 276,084--712,604 KB; 2,254,447 compressed bytes.
- Exact `aggregate-prerun` rerun passed with self-identifying receipt SHA-256 `25da8a0b5fb76e93bd8cc13c33c920573637e48c4cf290425dbdd86e521a0d1e`.
- Focused runner test passed 143 expectations; launcher self-test, all `bash -n`, and `git diff --check` passed.
- Final focused `mspl` suite passed 1,382 expectations with zero failures/warnings and one pre-existing skip in 162.1 seconds.

Preserved external evidence:

- retrieval: `/tmp/mspl-coverage-retrieval-112931db/gate4`
- execution bundle: `/tmp/mspl-coverage-retrieval-112931db/gates1-4-execution-bundle.tar.gz`
- bundle SHA-256: `7869083e6c705cebb3eadba167fc3dd5a2a08eb749a0c09c8a4a9e37ecacfc05`

## Still required

1. Receive the maintainer's explicit post-Gate-4 approval for full production.
2. Review and commit the permanent launcher/aggregator repairs as a new immutable source identity.
3. Restage the new source and repeat the required identity, scheduler dry-run, and cluster-runtime binding gates before production; never reuse a mismatched source-SHA receipt.
4. Run the remaining exact production keys only after the new unlocking receipt is materialized.
5. Aggregate/adjudicate coverage and availability before any public method change.

## Next safest action / blocker

Stop and present the Gate 4 receipt to the maintainer. Do not create `gate4-prerun-ready.receipt` or submit the 1,200-task campaign without explicit approval. If approved, recheck Rorqual's exact file quota immediately before submission; its current exact 2x-margin verdict passes only under the compact-output contract.
