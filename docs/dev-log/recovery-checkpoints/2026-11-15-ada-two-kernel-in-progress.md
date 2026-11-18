# Two-kernel Gaussian work in progress

Branch: `codex/two-kernel-gaussian-20261115`, based on `abf3e905`.
The user owns both this lane and PR #1763 and authorized the overlapping work.
The PR remains untouched. A separate scratch reconciliation passed its focused
tests; its NEWS conflict remains unresolved.

The working tree contains changes to the fitting and refit R files, generated
help, two existing test files, and new files under `dev/two-kernel-gaussian/`
and `tests/testthat/test-coevolution-known-fixed-error.R`. Run `git status
--short --branch` and `git diff --stat` for the current exact state. The ignored
acceptance ledger is `.unlazy/two-kernel/GATES.md`.

The focused two-kernel test passed. The broader compatibility regression passed
with 21 heavy tests skipped. `devtools::document()` and
`pkgdown::check_pkgdown()` passed; pkgdown emitted Pandoc deprecation warnings.
An independent five-point fixed-coordinate oracle passed against the staged
Mac library. A fitted-object check passed named extraction and the tested
prediction and simulation guards, but uniqueness estimates were near zero.
The initial extraction assertion used the wrong return field; the failure and
correction remain under `dev/two-kernel-gaussian/fitcheck/`.

Totoro's exploratory pilot finished 36 scheduled cases, with 36 extractions
and 34 convergence codes of zero. Independent review reproduced all 468
summary rows; `dev/two-kernel-gaussian/pilot/RESULTS.md` records the results. Its
source, build and outputs are under
`/home/snakagaw/hsq_work/two-kernel-build-20261115.u4bM1P/`. The initial
AppleDouble build failure, retry, failed nested-timeout probe and replacement
supervisor probe are preserved. The first case's initial launch failed before
generation because its output directory was absent. No result has yet been
accepted as recovery or interval-calibration evidence.

The full local `devtools::test()` run exited with failures; its output is
`/tmp/gllvmtmb-two-kernel-full-tests.log`. Change-related bare-abort and
capability-ledger failures were repaired and focused tests passed. Some
interval-claim, help and visual failures were reproduced on clean main; the
reporter suppressed additional failures. Local `devtools::check()` exited 1:
one ERROR from two visual-snapshot tests, zero WARNINGs and one NOTE about
`TMB:::EvalADFunObject`. Both named visual tests also fail on clean main;
their rendered differences were not retained. The triple-colon call is present
on clean main. The check log is `/tmp/gllvmtmb-two-kernel-check.log`.
The untruncated full-suite rerun exited 1 with 11 named failures, each also
reproduced on clean main; visual pixel differences were not retained. Its log
is `/tmp/gllvmtmb-two-kernel-full-tests-untruncated.log`. After help and
article edits, the final local package check exited 1 with the same two named
baseline snapshot failures and one note; its log is
`/tmp/gllvmtmb-two-kernel-final-check.log`. This check began before the article
generator's ridge correction. The corrected article was rendered separately,
and `pkgdown::build_articles(lazy=FALSE)` then exited zero with 43 pages; its
log is `/tmp/gllvmtmb-two-kernel-all-articles.log`.
The next actions are to finish the package checks,
reconcile the PR overlap, complete the acceptance ledger and after-task report,
and report the final source-bound findings to the coevolution chat. No push,
merge or public capability claim is authorized by the plan.

The user authorized scratch reconciliation of PRs #1790 and #1794. Their
overlapping prediction and check-log changes were preserved and reconciled in
`/Users/z3437171/.codex/worktrees/two-kernel-pr1763-reconcile/gllvmTMB`.
The combined #1790 prediction tests passed; the #1794 check-log copy retains
its PR content and has an in-progress entry. Neither PR was changed. The held
prediction and simulation documentation has since been updated and rendered.

The user also authorized preserving and reconciling PR #1800 in scratch. Its
named shared-only fixed-rho target passed 36 assertions on combined scratch
source on Totoro. An independent reviewer checked same-run source and live
DLL hashes and process cleanup. This is not a full-PR or two-Psi recovery pass.
The original PR and both sets of tests remain intact.
