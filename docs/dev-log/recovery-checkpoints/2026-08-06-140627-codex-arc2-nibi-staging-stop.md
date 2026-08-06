# Arc 2 Nibi replacement staging stop

## Why this checkpoint exists

The Fir campaign stopped making valid progress after exhausting the shared
`/project` file quota. The maintainer authorised a separate Nibi replacement
campaign. This checkpoint freezes the first safe Nibi boundary before any
package compilation, fit, smoke task, or full-array submission. The task was
stopped here at the maintainer's request to preserve context.

## Repository state

- Worktree: `/private/tmp/gllvmtmb-va-gh-all-families`
- Branch: `codex/va-gh-all-families`
- HEAD before this checkpoint: `8905cd76c3e1ac209437dc3cb067b15992b570cf`
- `git status --short --branch` was clean before this checkpoint.
- The automation ownership guard passed for task
  `019fd6d7-de59-7c43-b09d-7cc25f57c59f` and repository `gllvmTMB`.

## Sealed Nibi state

- Existing ControlMaster socket used:
  `/Users/z3437171/.ssh/cm-snakagaw@nibi.alliancecan.ca:22`
- Campaign root:
  `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-nibi-replacement-e46d7977`
- Clean detached checkout:
  `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-nibi-replacement-e46d7977/checkout-e46d7977`
- Checkout revision:
  `e46d7977aa63c61cf3f4a2dd4d7cf26e5612d917`
- Checkout porcelain count: `0`
- Frozen plan: 36,000 rows; MD5
  `9d1812ea659da9ae77f06b386832f224`
- Gate E receipt MD5: `0e711dc062f04660725103fa66670ecf`
- Git bundle MD5: `bdfa40a0548193d6f61b4cb74651b346`
- Source archive MD5 values:
  - `units_1.0-1.tar.gz`: `6aeee90a7f0b2f63a37f69407bbcca63`
  - `sf_1.1-2.tar.gz`: `565438ff8c7c034f792351e1d7274d93`
  - `fmesher_0.8.0.tar.gz`: `bb1ef5f5fb76ea9b9912fffc91a639b4`
- Nibi `/project` at the stop boundary: `160K / 500K` files and
  `10021 MiB / 9313 GiB`; approximately 340,000 file slots remain.
- No runtime manifest, preflight receipt, result bundle, or Nibi SLURM campaign
  job exists yet.

The first project-filesystem clone was interrupted while updating files. It was
moved, not deleted, to a timestamped `checkout-incomplete-*` directory under
the Nibi campaign root. The second clone completed cleanly. The quarantined
copy is not an input to any gate or campaign job.

## Fir state retained unchanged

The failed Fir campaign and its immutable result bundles were not modified,
cancelled, resubmitted, or mixed into the proposed Nibi denominator. The prior
failure record remains
`docs/dev-log/recovery-checkpoints/2026-08-06-132810-codex-arc2-fir-quota-failure.md`.

One new dependency-packaging job was submitted on Fir to copy the already
installed shared R library into `/scratch` as a single archive:

- job: `53449048`
- state at `2026-08-06T20:06:27Z`: `PENDING (Priority)`
- requested resources: 4 CPUs, 8 GiB, 1 hour
- intended archive:
  `/scratch/snakagaw/va-gh-h7-nibi-staging/gtmb-xfam-lib-20260806.tar.zst`
- intended checksum:
  `/scratch/snakagaw/va-gh-h7-nibi-staging/gtmb-xfam-lib-20260806.tar.zst.md5`

No archive or checksum existed at the checkpoint. A direct local `rsync`
attempt did not start because macOS's bundled rsync does not recognise
`--info=progress2`; it exited immediately with status 1 and copied no files.
Use BSD-compatible `--progress` if that fallback is needed.

## Automation state

The obsolete Fir-only heartbeat `va-gh-h7-arc-2-fir-monitor` was paused. It
must not be reactivated with its old Fir-only prompt. After the Nibi smoke gate
passes and exact Nibi job identifiers exist, update or replace it with a
Nibi-specific monitor that preserves the frozen thresholds and denominator.

## Commands and checks completed

- Read the project instructions, the Fir quota-failure checkpoint, and the
  campaign runtime/preflight/submission scripts.
- Verified the ownership guard: PASS.
- Verified Nibi capacity and the existing ControlMaster socket.
- Created and verified a complete Git bundle from
  `codex/va-gh-all-families`.
- Copied the frozen plan, Gate E receipt, source archives, and bundle first to
  local staging and then to the separate Nibi campaign root.
- Verified all checksums on Nibi.
- Materialised and verified the clean detached `e46d7977` checkout.
- Confirmed the copied plan has exactly 36,000 rows.
- Submitted Fir dependency-packaging job `53449048`.
- Paused the stale Fir-only heartbeat.

No R package tests, compilation, model fits, preflight, smoke task, full
campaign task, export, or final adjudication were run in this slice.

## Single next action

Transfer the exact Fir `gtmb-xfam-lib` dependency library to the sealed Nibi
root and verify its checksum: first use job `53449048`'s single archive if it
has completed; otherwise use a resumable BSD-compatible `rsync --progress`
through the existing Fir socket. Do not begin runtime preparation until the
dependency library is present and loadable on an allocated Nibi compute node.

After that one action, the authorised order remains dependency install ->
runtime manifest -> timed preflight -> one-row smoke -> full independent Nibi
36,000-row submission. Do not alter the plan, thresholds, scalar-family scope,
JJ fence, multinomial/non-scalar fences, or the immutable Fir/Totoro evidence.

