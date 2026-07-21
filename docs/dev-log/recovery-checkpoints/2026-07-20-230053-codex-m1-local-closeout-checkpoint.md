# Recovery Checkpoint: M1 Local Closeout

**Timestamp opened**: 2026-07-20 23:00:53 MDT

**Refreshed**: 2026-07-20 after D-50/report review

**Owner**: root Codex, sole writer

## Branch and literal working-tree status

Command: `git status --short --branch`

```text
## codex/gllvmtmb-060-m1-baseline-20260720...origin/main [ahead 6]
 M .github/workflows/R-CMD-check.yaml
 D .github/workflows/coevolution-two-kernel-recovery.yaml
 D .github/workflows/dep-slope-identifiability-sweep.yaml
 D .github/workflows/dep-slope-poisson-recovery.yaml
 M .github/workflows/full-check.yaml
 D .github/workflows/gamma-ordinal-recovery-depth.yaml
 D .github/workflows/m3-production-grid.yaml
 D .github/workflows/nightly-stale-test-fixups-gate.yaml
 D .github/workflows/phylo-q-decomposition-recovery.yaml
 D .github/workflows/power-pilot-sweep.yaml
 D .github/workflows/simulate-unit-trait-recovery.yaml
 D .github/workflows/slope-grid-residuals-recovery.yaml
 D .github/workflows/spatial-dep-slope-nongaussian-recovery.yaml
 D .github/workflows/spatial-indep-slope-nongaussian-recovery.yaml
 D .github/workflows/spatial-latent-slope-nongaussian-recovery.yaml
 D .github/workflows/spde-slope-base-engine-check.yaml
 M dev/m3-pilot-launch.R
 M dev/m3-pilot-local-loop.R
 M dev/m3-pilot-report.R
 M dev/power-pilot-run.R
 M dev/precompute-m3-grid.R
 M docs/design/05-testing-strategy.md
 M docs/design/35-validation-debt-register.md
 M docs/design/42-m3-dgp-grid.md
 M docs/design/44-m3-3-inference-replacement.md
 M docs/design/49-robust-modeling-roadmap.md
 M docs/design/50-m3-3b-surface-admission.md
 M docs/design/66-capstone-power-study.md
 M docs/design/70-missing-data-simulation-design.md
 M docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md
 M docs/dev-log/check-log.md
 M tests/testthat/setup.R
?? docs/dev-log/recovery-checkpoints/2026-07-20-230053-codex-m1-local-closeout-checkpoint.md
?? tools/check-actions-boundary.sh
```

The two untracked paths are intentional closeout files. The guard is executable
and has SHA-256
`b94d91e7cca9996de6c28ca41f94c304e757f411c193b22422e9610d7d25717e`.

Builder: `/private/tmp/gllvmtmb-060-m1-builder`. HEAD before the closeout commit
is `d05db5627fd7ec631d4725cf0efa917767507bd5`; the frozen upstream base is
`de211f762812c574646938adaca22cbf41c6175e`. Open PRs: 0. Active, queued,
waiting, requested, and pending runs: 0.

## Literal uncommitted diff stat

Command: `git diff --stat`

```text
 .github/workflows/R-CMD-check.yaml                 |  13 +-
 .../workflows/coevolution-two-kernel-recovery.yaml | 123 ----
 .../workflows/dep-slope-identifiability-sweep.yaml | 220 ------
 .github/workflows/dep-slope-poisson-recovery.yaml  | 107 ---
 .github/workflows/full-check.yaml                  |  17 +-
 .../workflows/gamma-ordinal-recovery-depth.yaml    | 115 ----
 .github/workflows/m3-production-grid.yaml          | 173 -----
 .../workflows/nightly-stale-test-fixups-gate.yaml  | 118 ----
 .../workflows/phylo-q-decomposition-recovery.yaml  | 103 ---
 .github/workflows/power-pilot-sweep.yaml           | 550 ---------------
 .../workflows/simulate-unit-trait-recovery.yaml    | 106 ---
 .../workflows/slope-grid-residuals-recovery.yaml   | 119 ----
 .../spatial-dep-slope-nongaussian-recovery.yaml    | 110 ---
 .../spatial-indep-slope-nongaussian-recovery.yaml  | 108 ---
 .../spatial-latent-slope-nongaussian-recovery.yaml | 117 ----
 .../workflows/spde-slope-base-engine-check.yaml    | 104 ---
 dev/m3-pilot-launch.R                              |  43 +-
 dev/m3-pilot-local-loop.R                          |  76 +--
 dev/m3-pilot-report.R                              |  17 +-
 dev/power-pilot-run.R                              |  39 +-
 dev/precompute-m3-grid.R                           |  16 +-
 docs/design/05-testing-strategy.md                 |  16 +-
 docs/design/35-validation-debt-register.md         |   4 +-
 docs/design/42-m3-dgp-grid.md                      |  14 +-
 docs/design/44-m3-3-inference-replacement.md       |  35 +-
 docs/design/49-robust-modeling-roadmap.md          |   9 +-
 docs/design/50-m3-3b-surface-admission.md          |   9 +-
 docs/design/66-capstone-power-study.md             | 169 +++--
 docs/design/70-missing-data-simulation-design.md   |  26 +-
 .../after-task/2026-07-20-m1-heavy-baseline.md     | 751 +++++++++++++++++----
 docs/dev-log/check-log.md                          | 183 +++++
 tests/testthat/setup.R                             |   8 +-
 32 files changed, 1091 insertions(+), 2527 deletions(-)
```

This stat excludes the two untracked files listed above, as `git diff --stat`
does by design. Before durable receipts were added, Shannon fingerprinted the
30-path D-50 slice at SHA-256
`ee725a3387cb7ae26f5a76508ce8c5213d238bc29dfdc16f03c36a99ddba44b1`;
that pre-receipt fingerprint is retained as coordination provenance, not as a
fingerprint of the current 34-entry status estate.

## Quarantined state

- The dirty primary remains at
  `6fcf0998a87d00b791c299c94e7995f23c744199`; do not switch, clean, stash,
  reset, or edit it.
- The inactive worktree `agent-ae50a884b8bfbdef5` overlaps on
  `docs/design/35-validation-debt-register.md`; do not touch it.
- The primary-only 303-line check-log tail remains CARRIED-OVER with SHA-256
  `902d88919d88b43c89cec54fd4cd08b619529e2110ac79eca02e244597425ced`.

## Commands already run

- Untouched 48-failure baseline reproduction: PASS as a reproducer.
- Complete repaired heavy suite: 0 failures/errors; 13,641 passes.
- M1 no-skip audit: 523 passes, 0 skips/failures/errors/warnings.
- Explicit roxygen2 8 document and `pkgdown::check_pkgdown()`: PASS.
- Heavy and standard source-package checks: 0 R CMD errors/warnings/notes.
- D-50 guard syntax, positive case, and four negative fixtures: PASS.
- Retained workflow YAML parse and five modified dev-script R parses: PASS.
- `devtools::test(filter = "m3-pilot-manifest")`: 147 passes.
- After-task structure validator: PASS.
- Exhaustive touched-file inventory: 74 actual and 74 reported paths.
- Grace final D-50 review: PASS.
- Shannon final coordination review: WARN only for quarantined stale overlap;
  safe to continue.

Exact invocations, paths, hashes, and nonclaims are recorded in:

- `docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md`;
- the final `2026-07-20 — gllvmTMB 0.6 M1 release truth` entry in
  `docs/dev-log/check-log.md`.

## Commands still required

1. Obtain Rose's final post-receipt PASS.
2. Commit the D-50/receipt slice.
3. Run the final exact-head local standard package check and pkgdown gate.
4. Push the one M1 branch and create the one M1 PR.
5. Dispatch/observe exact-head three-platform package CI and Ubuntu heavy CI.
6. Update receipts, obtain final independent M1 synthesis, and request the
   maintainer's M1-to-M2 admission decision.

## Next safest action

Run the final read-only Rose/Boole gate. If it passes, commit the closeout slice
and run exact-head local package/pkgdown checks. Do not launch Totoro/DRAC, begin
Design 86 implementation, add a public EVA surface, tag, submit, or make a
release claim.

## Blocking question

None for local M1 closeout. Separate maintainer authority remains mandatory
before M2 remote compute and every later public/release boundary.
