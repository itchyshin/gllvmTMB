# Arc 2 Narval replacement launch checkpoint

## Repository state

- Worktree: `/private/tmp/gllvmtmb-va-gh-all-families`
- Branch: `codex/va-gh-all-families`
- HEAD before this checkpoint: `91ef0e85`
- The worktree was clean before this checkpoint.
- Automation ownership check: PASS.

## Authorised host switch

The maintainer explicitly selected Narval after Nibi's load-shed maintenance
held the complete gate chain. Before switching, all five Nibi jobs were still
pending, the Nibi runtime manifest was absent, and the Nibi campaign had zero
`COMPLETE.dcf` bundles. Exactly these jobs were cancelled:

- `19211941` dependencies
- `19211952` runtime
- `19211953` preflight
- `19211954` smoke
- `19211956` launcher

All five recorded `CANCELLED` without an allocation or result. No Nibi or Fir
bundle was copied into the Narval denominator.

## Sealed Narval state

- Existing socket:
  `/Users/z3437171/.ssh/cm-snakagaw@narval.alliancecan.ca:22`
- Root:
  `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-narval-replacement-e46d7977`
- Clean detached checkout:
  `e46d7977aa63c61cf3f4a2dd4d7cf26e5612d917`
- Plan: exactly 36,000 rows; MD5
  `9d1812ea659da9ae77f06b386832f224`
- Gate E receipt MD5: `0e711dc062f04660725103fa66670ecf`
- Git bundle MD5: `bdfa40a0548193d6f61b4cb74651b346`
- Dependency archive MD5: `82a20d52462852535c4934471aaf16dc`
- Source archive MD5 values:
  - `units_1.0-1.tar.gz`: `6aeee90a7f0b2f63a37f69407bbcca63`
  - `sf_1.1-2.tar.gz`: `565438ff8c7c034f792351e1d7274d93`
  - `fmesher_0.8.0.tar.gz`: `bb1ef5f5fb76ea9b9912fffc91a639b4`
- Narval project quota before staging: `67K / 500K` files and
  `229 GB / 10 TB`.

Narval exposes the required `StdEnv/2023`, `r/4.5.0`, `gdal/3.9.1`, and
`udunits/2.2.28` module stack.

## Accepted afterok chain

1. Dependencies: `336858`
2. Runtime preparation: `336859`, afterok `336858`
3. Timed preflight: `336860`, afterok `336859`
4. One-row smoke: `336861`, afterok `336860`
5. Full launcher: `336862`, afterok the smoke array

All downstream jobs use `--kill-on-invalid-dep=yes`. At
`2026-08-06T22:26:21Z`, the dependency job was pending for ordinary scheduler
priority and the remaining jobs were pending on their expected dependencies.
The launcher first verifies the smoke bundle, then submits the unchanged plan
as 36 batches of at most 1,000 tasks with array concurrency 100.

## Monitoring

Automation id `va-gh-h7-arc-2-fir-monitor` was updated in place and is now
displayed as `VA GH H7 Arc 2 Narval monitor`. It is ACTIVE every 30 minutes and
uses only the existing Narval socket. It monitors the five gate jobs, validates
the later 36-job submission ledger and 1--36,000 task coverage, tracks immutable
bundles, and performs export/adjudication only at full scheduler completion.
Its prompt forbids bypasses, resubmission, denominator mixing, threshold
changes, new campaigns, and public-fence changes.

## Checks run

- Verified Nibi had zero bundles and no runtime receipt before cancellation.
- Verified Narval capacity, module availability, and unused destination root.
- Verified every transferred checksum on Narval.
- Verified the 36,000-row plan and clean frozen checkout.
- Ran `bash -n` on the four Narval staging scripts.
- Confirmed Slurm accepted all five Narval jobs and their exact dependencies.

No Narval compilation, preflight fit, smoke fit, full campaign task, export,
or final adjudication had completed at this checkpoint.

## Single next action

Wait for the active Narval monitor. Intervene only if it reports a failed
gate/task or when all 36,000 immutable bundles and the 36 independent
cell-by-rank verdicts are ready.

