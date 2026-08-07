# VA(GH) H=7 Arc 2 — Totoro confirmation launch checkpoint

## Scope and immutable roots

- Branch: `codex/va-gh-all-families`
- Clean campaign revision: `022b4eabf36bb442ed7b76aacadffeeebdc3cff2`
- New Totoro campaign root:
  `/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806`
- Completed H-ladder evidence remains separate and unchanged at:
  `/home/snakagaw/gllvm_work/va-gh-h7-campaign-ac45e50f`
- The pre-existing Narval replacement root and its monitor remain separate. No
  Narval task, result, receipt, or denominator was reused here.

## Local repository state at checkpoint

`git status --short --branch`:

```text
## codex/va-gh-all-families
```

`git diff --stat` was empty. The campaign input commit contains only:

```text
dev/va-gh-h7-campaign/launch-totoro-confirmation.sh
dev/va-gh-h7-campaign/run-cell.R
tests/testthat/test-va-gh-h7-campaign.R
```

The TMB likelihood template, public VA family fence, JJ path, multinomial path,
and non-scalar model scope were not changed.

## Arc 0 verification

- `Rscript --vanilla -e 'parse("dev/va-gh-h7-campaign/run-cell.R")'`: PASS.
- `bash -n dev/va-gh-h7-campaign/launch-totoro-confirmation.sh`: PASS.
- `git diff --check`: PASS.
- `NOT_CRAN=true Rscript --vanilla -e
  'devtools::test(filter="va-gh-h7-campaign", reporter="summary",
  stop_on_failure=TRUE)'`: PASS.
- Independent contract review found and closed one launch-gate defect: smoke
  verification now requires both `status == "completed"` and `healthy == TRUE`.
  A second independent pass reported PASS.
- The final adjudicator uses role names (`h_ladder`, `confirmation`) and accepts
  explicit platforms. This campaign will use `h_ladder_platform=Totoro` and
  `confirmation_platform=Totoro`, yielding `platform=Totoro` and
  `cross_platform=FALSE`.

## Totoro provenance and sequential gates

Only the existing ControlMaster socket was used:

```text
/Users/z3437171/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22
```

The clean git bundle was
`/private/tmp/gllvmTMB-va-gh-h7-arc2-022b4eab.bundle`, SHA-256
`aeab218e16cb3ef2a1af8d46df208e3b795796d6bd60054b38d1a2dfbc59f77b`.
It was cloned into the campaign root as a detached, clean checkout at the
revision above.

The fail-closed sequential gate command was:

```sh
bash /home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/incoming/va-gh-h7-totoro-gates-022b4eab.sh
```

Outcome: `SEQUENTIAL_GATES_PASS`. The gate order and receipts were:

1. native Totoro runtime and clean-checkout fingerprints: PASS;
2. checksum-bound Gate E: PASS;
3. native package build and runtime manifest: PASS;
4. timed VA/Laplace preflight: PASS;
5. separate one-row VA smoke: completed, healthy, PASS;
6. separate 100-row sentinel: 100 published bundles, 0 infrastructure
   failures, failure rate 0, threshold 0.10, PASS;
7. exact confirmation plan: 36,000 rows, PASS.

Key immutable checksums:

```text
native_runtime_sha256=b78376b5195afab5a3de817c9fbf11e9c45c086cf727024aaa49ce7652bfcdf4
gate_receipt_md5=5fc7fccf70c4ad99f92e80d713488360
runtime_manifest_md5=1b07b5b7c21347d7e40a0c690cf41d05
preflight_receipt_md5=cea3ae3cfe68cf9f877d85d0a89ebb33
smoke_plan_md5=b6990e54d01553fb8f6d7eab4bc744b2
sentinel_plan_md5=8584326b52b54f032fbc39b35c5a7d25
sentinel_receipt_md5=49b1b2d5b78acf9706d26ef480c2647b
confirmation_plan_md5=9d1812ea659da9ae77f06b386832f224
```

The smoke and sentinel live outside `confirmation/`; neither can enter the
36,000-row scientific denominator. Statistical failed/unhealthy sentinel fits
were retained as immutable model outcomes but did not count as infrastructure
failures because every bundle and provenance chain verified.

## Healthy full launch

Launch command recorded in the remote receipt:

```sh
ACTION=run CORES=150 bash dev/va-gh-h7-campaign/launch-totoro-confirmation.sh
```

- Started UTC: `2026-08-07T02:22:22Z`
- Launcher PID: `1667101`
- `seq` PID at the checkpoint snapshot: `1667247`
- `xargs -P 150` PID at the checkpoint snapshot: `1667248`
- Sample R worker PIDs at the snapshot:
  `1720601,1720701,1720810,1720902,1720998,1721102,1721184,1721266`
- Worker ceiling: 150.
- `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`,
  `MKL_NUM_THREADS=1` for every worker.
- Full log:
  `/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/logs/full-confirmation.log`
- Launch receipt:
  `/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/receipts/full-confirmation-launch.dcf`
- Exit receipt when finished:
  `/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806/receipts/full-confirmation-exit.dcf`
- Published confirmation bundles at the `02:24 UTC` snapshot: 2,963 / 36,000.
- The exit receipt was absent at that snapshot, correctly indicating RUNNING.

## Next monitoring action

Use only the existing ControlMaster. First verify the launcher or exit receipt,
then count immutable bundles; do not infer completion from a missing PID alone:

```sh
ssh -o ControlPath=/Users/z3437171/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22 \
  -o ControlMaster=no -o BatchMode=yes -o ConnectTimeout=20 totoro \
  'root=/home/snakagaw/gllvm_work/va-gh-h7-totoro-confirmation-022b4eab-20260806;
   test -f "$root/receipts/full-confirmation-exit.dcf" &&
     sed -n "1,80p" "$root/receipts/full-confirmation-exit.dcf" || true;
   find "$root/confirmation/replicates" -mindepth 1 -maxdepth 1
     -type d -name "*.bundle" | wc -l;
   tail -n 20 "$root/logs/full-confirmation.log"'
```

If and only if the exit receipt says `COMPLETE`, the bundle count is exactly
36,000, and a clean host-local export verifies every immutable bundle, proceed
to the checksum-bound two-campaign adjudication. Re-export the unchanged
H-ladder raw root with this committed role-neutral driver, pass both platform
arguments explicitly as `Totoro`, and retain all failures. Do not pool cells or
ranks, weaken thresholds, import sentinel rows, or alter the frozen estimator,
fixture, or decision rules.
