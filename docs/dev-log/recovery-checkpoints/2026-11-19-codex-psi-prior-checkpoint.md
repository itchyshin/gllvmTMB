# Recovery checkpoint: named-kernel Psi prior

Branch: `codex/psi-sd-prior-20261119` at base `0d065c398510dcdd0df3079eff0de36d78402202` (`origin/main`).
Owner: Codex PSI-prior lane. This worktree is isolated, and no commit, push, PR, merge, or release has been made.

## Current tree

`git status --short --branch`:

```text
## codex/psi-sd-prior-20261119...origin/main
 M R/aghq-report.R
 M R/fit-multi.R
 M R/fixed-effect-priors.R
 M R/gllvmTMB.R
 M R/methods-gllvmTMB.R
 M R/standard-errors.R
 M R/vcov-coef.R
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/known-limitations.md
 M man/gllvmTMB_multi-vcov.Rd
 M man/gllvmTMBcontrol.Rd
 M man/standard_errors.Rd
 M man/tidy.gllvmTMB_multi.Rd
 M tests/testthat/test-loading-ridge-disclosure.R
?? R/kernel-psi-sd-priors.R
?? docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md
?? docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md
?? docs/dev-log/recovery-checkpoints/2026-11-19-codex-psi-prior-checkpoint.md
?? tests/testthat/test-psi-sd-priors.R
```

`git diff --stat`: 14 tracked files changed, 312 insertions, 54 deletions; this excludes five untracked implementation, test, and report files. `git diff --check` passed.

## Implemented and validated

- Prototype API: `gllvmTMBcontrol(kernel_psi_sd_prior = data.frame(kernel, trait, scale))`, a normalized HalfNormal density on selected natural named-kernel Psi SDs. Target/offset, objective, gradient, Hessian, and finite-difference checks exist. It is limited to native TMB Gaussian identity-link ML Laplace fits.
- Simulated-fit checks distinguish an interior target from a zero-boundary target. The boundary fit converged with Psi variance `1.51e-15`, natural SD about `3.9e-8`, and the expected `near_zero_sd_phy_diag` flag. These seeded fits check integration; they do not estimate recovery rates. The HalfNormal mode at zero does not prevent near-zero estimates.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors|loading-ridge-disclosure", reporter = "summary")'` passed with zero failures. The expected MAP `logLik()` warning appeared.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with no problems.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'` completed in 42m 30.6s: 30,990 passed, 1,252 skipped, 70 test warnings, and two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`. Both snapshot failures reproduce on clean base `0d065c398510dcdd0df3079eff0de36d78402202`. Code, documentation, compilation, and examples passed; R CMD check reported one error from those snapshots, zero check warnings, and one existing NOTE for `TMB:::EvalADFunObject`.
- A follow-up full check after public `target_class = "unique_variance"` and `measure = "natural_sd"` metadata assertions completed in 42m 22.8s: 30,992 passes, 1,252 skips, 70 test warnings, and the same two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`. R CMD check reported one error from those failures, zero check warnings, and one NOTE for `TMB:::EvalADFunObject`. The focused prior, fixed-effect-prior, and loading-ridge disclosure suite passed after that change.
- `Rscript --vanilla '/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R' '/Users/z3437171/.codex/worktrees/psi-sd-prior-gllvmTMB/docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md'` passed report structure validation, then failed repository acceptance because three unrelated ledgers are unmet: `./.unlazy/ijsdm-response-information-forensics/GATES.md`, `./.unlazy/ijsdm-response-information-GATES.md`, and `./.unlazy/temporal-ar1/GATES.md`. Do not alter those ledgers.
- `python3 /Users/z3437171/shinichi-brain/tools/slop_check.py` was run on both updated reports with absolute paths; both returned zero findings. The initial relative-path calls resolved against the wrong project, so only the absolute-path results count.

## Cross-lane contract and ownership

The generalized-prior lane confirmed the shared target class as `unique_variance`, with the requested density measure explicitly set to `natural_sd`. The log-SD optimizer evaluates p_SD(exp(eta)) without a Jacobian. This local named-kernel implementation remains isolated; do not edit or integrate into the lane's active four-package branch. Julia parity and cross-package integration remain unverified. PR #1820 overlaps `R/gllvmTMB.R`; defer edits to overlapping source until ownership clears. `_pkgdown.yml` had 55 competing refs, so a separate article was not added. No NEWS change was made due concurrent PR ownership.

Live ownership refresh on 2026-11-19: `gh pr view 1820 --json number,state,isDraft,title,headRefName,baseRefName,updatedAt,files,url` confirms PR #1820 is still open and draft. A file-set comparison across all open PRs found additional overlaps with this branch: `R/fit-multi.R` in #1834 and #981; `R/methods-gllvmTMB.R` in #1828, #1826, and #1785; and `R/gllvmTMB.R` in #1824, #1823, #1822, and #1820. The lane preflight identified 19 active lanes and this branch as the Codex Psi-prior lane. Keep those three files unchanged until their owners clear or the maintainer explicitly coordinates the overlap.

## Next safest action

Keep the local API explicit: target class `unique_variance`, measure `natural_sd`, and density p_SD(sqrt(Psi[t,t])) with no log-SD Jacobian. The prior lane has confirmed the design; no cross-package integration is planned on its active branch. Keep KER-03B `partial` and the overall goal active. Resume edits to the three overlapping source files only after current ownership clears or explicit maintainer coordination; then refresh from current main and rerun the relevant focused and package gates. No three-OS CI, Julia parity, interval calibration, broad recovery, PR, merge, or release is established.

Current continuation receipt: the full-check rerun result is also appended to `docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md` and `docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md`. The check process is terminal; do not restart it to regenerate output.

## Continuation refresh: 2026-11-19

- `git fetch origin main` confirmed this branch and `origin/main` remain at `0d065c398510dcdd0df3079eff0de36d78402202` (0 ahead, 0 behind). The working tree remains dirty only with this Psi-prior implementation and its reports/tests.
- Live PR scan: #1785 has merged. Remaining source overlaps are #1834 and #981 (`R/fit-multi.R`); #1828 and #1826 (`R/methods-gllvmTMB.R`); and #1824, #1823, and #1822, plus #1820 (`R/gllvmTMB.R`). Keep those files untouched until their open owners clear the overlap.
- The prior/penalty lane received the explicit implementation plan on 2026-11-19. It remains active on its independent four-package acceptance run; no reply to the detailed plan was visible at the latest read.
- The check-log timing sentence now correctly says no implementation source, public documentation, NEWS, or shared navigation files changed after the full package check began. `git diff --check` and the absolute-path `slop_check.py` pass; the lease was released and the registry showed no active lease.
- Next safe action: refresh the live PR file map. Resume integration only after all three source-file overlaps clear; then refresh the branch and rerun affected focused and package checks. Keep KER-03B `partial`; no PR, merge, release, three-OS CI, Julia parity, or calibrated-uncertainty claim is established.

## Second ownership refresh: 2026-11-19

- A new `git fetch origin main` advanced `origin/main` from `0d065c398` to `902c069c8`; this branch is now 6 commits behind and 0 ahead. Those six commits include the merge of PR #1785 and change `R/methods-gllvmTMB.R`.
- The overlap scan still finds open PRs #1834 and #981 on `R/fit-multi.R`; #1828 and #1826 on `R/methods-gllvmTMB.R`; and #1824, #1823, #1822, and #1820 on `R/gllvmTMB.R`. Their continued file ownership means this lane must not rebase-and-edit the overlapping source yet. Preserve the dirty implementation as-is.
- Current safe next step requires external state change: the relevant PRs must close/merge or their owners must clear these files. Once that happens, refresh the main base, reconcile the source edits, and rerun focused/package checks. Do not merge or release without separate authorization.

## Approved ownership outreach: 2026-11-19

Shinichi authorized asking the open PR lanes when their overlapping files would clear. Comments were posted to #1834, #981, #1828, #1826, #1824, #1823, #1822, and #1820. The GitHub connector returned 403, so the authenticated GitHub CLI posted each comment. All eight comments were read back by comment ID and verified as exact matches. Links are recorded in `docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md`. No implementation source was changed; next step is to check responses and rederive the live overlap map.

## Follow-up ownership refresh: PR #1838

PR #1838 (`cursor/fix-1580-multinomial-psi-note-ae5d`) opened on `R/fit-multi.R` after the previous refresh. It adds wording and tests for the automatic-Psi skip message. Shinichi asked me to sort out ownership and keep going; I posted the ownership question at https://github.com/itchyshin/gllvmTMB/pull/1838#issuecomment-7011568117 and verified the exact text. No replies have arrived to any of the nine open-PR comments. Continue preserving the overlapping source files until the lanes clear them.

## Hunk-level ownership audit: 2026-11-19

Read-only comparison used `git diff --unified=0 HEAD -- R/fit-multi.R R/methods-gllvmTMB.R R/gllvmTMB.R` and `gh pr diff <number> --color never` for each overlapping PR. The local Psi-prior hunks did not directly intersect the PR hunk ranges: #1838 (R/fit-multi.R 113-122, 145-151); #1834 (5740-5745, 5881-5886); #981 (8016-8021, 8056-8062, 8066-8071); #1828/#1826 (R/methods-gllvmTMB.R, about 3165-3635); #1824/#1823 (R/gllvmTMB.R 161-166, 1185-1211); #1822 (1367-1389); #1820 (159-165). The nearest local hunk to #981 is at R/fit-multi.R line 8076, five lines after its last listed hunk. This is a line-range comparison against current PR diffs, not a merge-conflict proof or ownership release. The preflight still reports foreign lanes active on these paths; wait for the maintainer ownership decision before editing them.
