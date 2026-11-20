# Checkpoint: Psi SD prior PR #1841

Branch: `codex/psi-sd-prior-integration-20261119`
PR: https://github.com/itchyshin/gllvmTMB/pull/1841
Initial PR head: `e2f468f260b9b0af368f88ca12cfe5ad643b1019`

## Local follow-up

- `R/kernel-psi-sd-priors.R` now gives actionable next steps for two internal errors. The bare-abort count returned to 770.
- `dev/gapclose/build-capability-status.R` maps `KER-03B` as an R-only, scope-limited MAP sensitivity. `docs/design/capability-status.md` was regenerated: 82 rows, 255 mapped rows, 37 unmapped by design, zero unexpected unmapped rows.
- `Rscript dev/gapclose/build-capability-status.R --check` passed.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|gapclose-parity-ledger|gapclose-next-steps", reporter = "summary")'` passed with zero failures. The expected penalised-MAP `logLik()` warning appeared.
- `rg -n 'KER-03B|Named-kernel Psi SD priors|Julia parity, broad recovery' dev/gapclose/build-capability-status.R docs/design/capability-status.md docs/design/35-validation-debt-register.md` found consistent mapping and scope text. `git diff --check` passed.

## Pre-fix CI

- PR run `44585940971` at the initial head completed with Ubuntu shards 1 and 2 passing; shard 3 failed the 770 abort-count assertion; shard 4 failed the three assertions caused by unmapped KER-03B.
- Manual three-platform run `44586781505` at the initial head failed on Windows, macOS, and Ubuntu with the same two causes. These runs do not validate the follow-up changes.

## Remaining work

The local changes, task reports, check log, and checkpoint are uncommitted. Run `git diff --check`, commit and push the follow-up, wait for exact-head package CI and full three-platform checks, then merge through the guarded procedure only after every required check is green. Update the check log and after-task report with the new CI outcome.

`check-after-task.R` confirms report structure but reports three unrelated unmet acceptance ledgers: `./.unlazy/ijsdm-response-information-forensics/GATES.md`, `./.unlazy/ijsdm-response-information-GATES.md`, and `./.unlazy/temporal-ar1/GATES.md`. Do not change those other work lanes.
