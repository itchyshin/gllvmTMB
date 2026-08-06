# Arc 2 Nibi gated campaign launch checkpoint

## Repository state

- Worktree: `/private/tmp/gllvmtmb-va-gh-all-families`
- Branch: `codex/va-gh-all-families`
- HEAD before this checkpoint: `54a94006`
- `git status --short --branch` was clean before this checkpoint.

## Outcome

The complete Nibi launch chain was accepted by Slurm. The full 36,000-row
campaign is deliberately behind dependency, runtime, preflight, and one-row
smoke gates. It will be submitted automatically only if every gate exits
successfully. No threshold, plan row, family fence, estimator, or frozen
Totoro/Fir evidence was changed.

The Nibi load-shed maintenance reservation delayed the first job at the stop
boundary. This is healthy scheduler waiting, not a failed gate or statistical
result.

## Immutable inputs

- Campaign root:
  `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-nibi-replacement-e46d7977`
- Runtime checkout: clean detached
  `e46d7977aa63c61cf3f4a2dd4d7cf26e5612d917`
- Plan: 36,000 rows; MD5 `9d1812ea659da9ae77f06b386832f224`
- Gate E receipt MD5: `0e711dc062f04660725103fa66670ecf`
- Transferred dependency archive MD5:
  `82a20d52462852535c4934471aaf16dc`
- Fir dependency-packaging job `53449048`: `COMPLETED|0:0` in 23m39s.

## Accepted afterok chain

1. Dependencies: `19211941`
2. Runtime preparation: `19211952`, afterok `19211941`
3. Timed preflight: `19211953`, afterok `19211952`
4. One-row smoke: `19211954`, afterok `19211953`
5. Full launcher: `19211956`, afterok the smoke array

Each dependent job was submitted with `--kill-on-invalid-dep=yes`. A failed
gate therefore stops the chain instead of allowing the full array to launch.
The launcher runs the committed `submit-drac.sh` in an allocation; it first
verifies the immutable smoke bundle and then submits exactly 36 batches of at
most 1,000 tasks with an array concurrency limit of 100.

At `2026-08-06T21:02:01Z`, all five jobs were pending: the dependency job had
reason `ReqNodeNotAvail, Reserved for maintenance`, and the other four had
their expected unfulfilled dependency reasons. No Nibi result bundle existed
before submission.

## Staging scripts

The following non-repository scripts are retained under
`/private/tmp/va-gh-h7-nibi-staging/` and copied to the Nibi campaign's
`incoming/` directory:

- `nibi-deps.sbatch`: SHA-256
  `78cf6d05f46bb1d0924a8c2fa25b7e997d4814dabdd4231f602eecd5b7a03480`
- `nibi-runtime.sbatch`: SHA-256
  `5cefcbaad86e82c37ce2b7653d2bfc44d7b40ae6bf905662af9fa0f964edf5cf`
- `nibi-preflight.sbatch`: SHA-256
  `db410ec13d301fd58363f8a25e046e3af5f787e764abe76aa8138b2a09ee1f04`
- `nibi-launch-full.sbatch`: SHA-256
  `2bd765f9a5334fca6b1921b276c74a2b3e2e7ebd0622314c65a7172b14d94c3e`

## Monitoring

The existing automation id `va-gh-h7-arc-2-fir-monitor` was updated rather
than duplicated. Its displayed name is now `VA GH H7 Arc 2 Nibi monitor`, it
is ACTIVE every 30 minutes, and its prompt is Nibi-specific. It monitors the
five gate jobs above, discovers and validates the 36 full-array job IDs from
the immutable submission log, tracks exactly 36,000 `COMPLETE.dcf` bundles,
and performs export/adjudication only after scheduler completion. The prompt
forbids bypass, cancellation/resubmission, denominator mixing, threshold
changes, and public-fence changes.

## Checks actually run

- Verified the Fir archive job completed successfully and checked its MD5
  locally before relay to Nibi.
- Verified the clean Nibi checkout and zero starting result bundles.
- Ran `bash -n` on all four staging scripts.
- Recorded SHA-256 checksums for all four staging scripts.
- Confirmed Slurm accepted all five jobs and recorded their dependencies.

No package compilation, preflight fit, smoke fit, full campaign task, export,
or final adjudication had completed at this checkpoint.

## Single next action

Wait. Let the active Nibi monitor observe the strict chain. Intervene only if
it reports a failed gate/task or when all 36,000 immutable bundles and the
final 36 cell-by-rank verdicts are available.

