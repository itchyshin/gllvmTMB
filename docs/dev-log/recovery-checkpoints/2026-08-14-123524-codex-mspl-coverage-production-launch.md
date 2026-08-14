# Recovery checkpoint — MSPL coverage production launch

Date: 2026-08-14 12:35 MDT
Platform: Codex
Branch: `codex/lane-b-mspl-interval-feasibility`
Current committed HEAD: `9a5e131f64cb5d77eefc2719bde412ffe7d7ed5c`

## Current state

The maintainer approved continuation through the full calibration/public-method
goal. Local production-launch hardening is complete and independently reviewed
GO. No new remote campaign root, source archive, runtime, job, shard, or unlock
has been created since that approval. Public MSPL inference is still
fail-closed.

The current working tree contains the source/launcher/test hardening plus the
plan actual, check-log, this checkpoint, and a phase after-task report. A new
immutable commit is the next action.

## Evidence completed

- Schema-v2 shards bind campaign, source, manifest, cluster, case/shard,
  runtime fingerprint, source archive/bundle, launcher bundle/helper, and
  cluster-native runtime hashes.
- Gate 3, Gate 4, and production aggregators require an external expected
  source SHA and immutable canonical shard ledgers.
- Production accepts only the exact 1,188 remaining keys; Gate 4 shard 001
  keys cannot be reused.
- Closed Gate 3/Gate 4 ready receipts bind live aggregate, ledger, manifest,
  source, launcher, and runtime hashes.
- The monitor validates schema-v2 RDS contents before counting and enforces all
  declared age/failure stop rules.
- Focused runner: 192 expectations passed.
- Focused MSPL suite: 1,431 passed, zero failures/warnings, one intentional
  skip, 175.5 seconds.
- Launcher contract self-test, all shell syntax checks, and `git diff --check`
  passed.
- Independent final production-launch audit: strict GO, no P0/P1/P2.

## Historical evidence retained

- Old Gate 4 retrieval: `/tmp/mspl-coverage-retrieval-112931db/gate4`
- Old execution bundle:
  `/tmp/mspl-coverage-retrieval-112931db/gates1-4-execution-bundle.tar.gz`
- The old shards are schema v1 and intentionally cannot unlock or aggregate
  with the repaired schema-v2 source.

## Next safest actions

1. Commit the exact scoped local files and record the new immutable SHA.
2. Materialise a fresh source archive, manifest, launcher ledger, and campaign
   root under that SHA.
3. Repeat scheduler dry runs and cluster-native builds on Nibi, Narval, and
   Rorqual; do not reuse compiled libraries across clusters.
4. Run and aggregate fresh Gate 3 and exact 12-shard Gate 4 evidence.
5. Audit and materialise the new ready receipt, then submit only the 1,188
   remaining keys.
6. Monitor completed valid shard counts and stop/reroute at the frozen limits.
7. Aggregate all 1,200 shards and adjudicate 108 method-target cells before any
   public API change.

## Stop conditions

Stop on identity/hash mismatch, malformed or duplicate keys, invalid shard,
terminal task failure, task above 14:31, task at 30 minutes, no valid shard 60
minutes after first recorded start, no start within 45 minutes, pending work
older than two hours, or a projected campaign above 12 hours. Retain every
failure and original statistical key.
