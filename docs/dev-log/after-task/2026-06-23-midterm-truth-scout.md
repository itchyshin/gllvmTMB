# After Task: Mid-Term Truth Sync And Scout Packet

**Branch**: `codex/midterm-truth-scout-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Jason / Curie / Fisher / Pat / Darwin / Rose / Shannon / Grace`

## 1. Goal

Implement the safe first slice of the mid-term plan: merge the approved
JSDM docs lane, fix the stale capability count, record the sibling-team
scout packet, and mark the power/compute gates without refreshing mission
control or launching simulations.

## 2. Implemented

- Corrected the validation-register headline from `172/22/0/7 over
  201 rows` to `173/22/0/7 over 202 rows`.
- Added a 2026-06-23 truth-sync note to the capability-status synthesis.
- Added a scaling gate to the capstone power-study design.
- Added a sibling-team update to the ASReml speed-techniques note.
- Added the mid-term capability/compute scout packet under
  `docs/dev-log/audits/`.
- Added this after-task report and a check-log entry.
- Merged PR #538 after Shinichi approved the merge, then rebased this
  branch onto the new `origin/main` merge commit `475cd7a`.

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation changed.

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a source-truth and scout slice instead of a
dashboard refresh.

Rationale: the local mission-control checkout is dirty and issue #340 is
stale relative to the register. Refreshing the widget before the source
truth lands would recreate the status-drift problem.

Decision: merge PR #538 before publishing this follow-up, after Shinichi
approved the recommended first packet.

Rationale: the truth-scout branch depends on #537 and should follow the
already-green JSDM article-polish lane, not compete with it.

Rejected alternative: edit `dev/m3-pilot-launch.R` immediately. The
pilot code has real stale wording around `signal = 0`, but the current
slice records the blocker and leaves the metric repair for the pilot
audit lane.

## 4. Files Touched

- `docs/design/35-validation-debt-register.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/61-capability-status.md`
- `docs/design/66-capstone-power-study.md`
- `docs/dev-log/audits/2026-06-23-midterm-capability-compute-scout.md`
- `docs/dev-log/after-task/2026-06-23-midterm-truth-scout.md`
- `docs/dev-log/check-log.md`

## 5. Checks Run

- `git status --short --branch`
  - PASS in the clean `/private/tmp` worktree before edits.
- `gh pr view 538 --repo itchyshin/gllvmTMB --json number,title,state,isDraft,mergeStateStatus,headRefName,baseRefName,statusCheckRollup,url`
  - PASS before merge; PR #538 was open, non-draft, clean, and had
    Ubuntu R-CMD-check success.
- `gh pr merge 538 --repo itchyshin/gllvmTMB --merge --delete-branch --match-head-commit 3a15adf2a6170b49d4a2e456909cf3dd6ed9a0c3`
  - PASS; PR #538 merged at `475cd7a`.
- `git fetch origin --prune`
  - PASS; `origin/main` advanced to `475cd7a`.
- `git rebase origin/main`
  - PASS after resolving the append-only `docs/dev-log/check-log.md`
    conflict by keeping both the #538 entry and this truth-scout entry.
- `gh issue view 340 --repo itchyshin/gllvmTMB --json number,title,state,body,updatedAt,url`
  - PASS; issue body still reports old 2026-06-03 tally, so it is stale
    relative to the register.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url,files --limit 20`
  - PASS before merge; only PR #538 was open. Overlap was limited to
    append-only `check-log` / after-task files; this branch avoids article
    files.
- `git log --all --oneline --since='6 hours ago' --decorate --date=short`
  - WARN; recent remote activity includes the #537 merge, #538 branch,
    and power-pilot result commits. No competing local edit was made in
    this clean worktree; #538 overlap is limited to append-only
    `check-log` / after-task files.
- `git diff --check`
  - PASS.
- `Rscript --vanilla -e 'tools::md5sum(c("docs/design/35-validation-debt-register.md", "docs/design/61-capability-status.md", "docs/design/66-capstone-power-study.md", "docs/design/43-asreml-speed-techniques.md"))'`
  - PASS; files are readable by R.
- `Rscript --vanilla -e 'source("/Users/z3437171/shinichi-brain/tools/check-after-task.R"); main_check_after_task("docs/dev-log/after-task/2026-06-23-midterm-truth-scout.md")'`
  - PASS; after-task structure check passed.

## 6. Tests of the Tests

No package tests were added because this slice is documentation and
coordination only. The meaningful failure mode is status drift; the
stale-wording scans in the consistency audit are the guard. The after-task
structure was checked with the hub validator after the report was aligned
to the required section headings.

## 7a. Issue Ledger

- PR #538 was inspected, approved by Shinichi, and merged.
- Issue #340 was inspected and judged stale relative to the validation
  register; no issue edit was made in this slice.
- No new issue was created. The follow-up work is already recorded in the
  scout packet: dashboard/issue refresh and pilot metric audit.

## 8. Consistency Audit

Exact scans run:

- `rg -n "172/22/0/7|201 rows|166 C|193 rows|Register tally now" docs/design docs/dev-log README.md NEWS.md _pkgdown.yml`
- `rg -n "automatic removal|automatic deletion|guarantees convergence|proves identifiability" docs/design docs/dev-log README.md NEWS.md vignettes R man`
- `rg -n "AI-REML|REML" docs/design/43-asreml-speed-techniques.md docs/design/61-capability-status.md docs/design/66-capstone-power-study.md docs/dev-log/audits/2026-06-23-midterm-capability-compute-scout.md`
- `rg -n "Type-I proxy|coverage-under-null|signal = 0|binomial_probit|coverage_primary" docs/design/66-capstone-power-study.md dev/m3-pilot-launch.R dev/m3-pilot-report.R`

Results:

- The stale current headline was corrected in the validation register.
- Historical `193 rows` references remain in older snapshot sections where
  they are provenance, not current status. Old `172/22/0/7` text remains
  only inside dev-log records that describe the change or old checks.
- The overclaim scan hits only old dev-log scan records and this report's
  scan pattern. It found no live user-facing overclaim in touched prose.
- `AI-REML` hits are now bounded to Gaussian-only / do-not-borrow wording.
- `Type-I proxy` and `coverage-under-null` still occur in
  `dev/m3-pilot-launch.R`; this slice documents the blocker but does not
  change pilot code.

## 9. What Did Not Go Smoothly

The global skill cache paths listed in the runtime prompt were partly
stale on disk. I used the project-local `.agents/skills/` copies and the
hub after-task protocol instead.

The repo-local and hub after-task templates differ slightly. I aligned
this report to the hub validator's required headings while preserving the
repo-specific mathematical-contract and consistency-audit content.

## 10. Known Residuals

- PR #538 was merged after Shinichi approved the first packet.
- Mission control was not refreshed.
- Issue #340 was not edited.
- No Totoro or DRAC login/submission was attempted.
- No pilot code or simulation metrics were changed.
- `dev/m3-pilot-launch.R` still contains `coverage-under-null` /
  `Type-I proxy` wording that belongs in the next pilot audit slice.

## 11. Team Learning

Ada: keep the first slice small when the dashboard, validation ledger, and
power pilot are all drifting at once.

Jason: sibling-team lessons transfer best as process first: measure-first,
scale-aware convergence, sparse trace discipline, and comparator runbooks.

Curie and Fisher: no big simulation should launch until the estimand,
metric names, MCSE, and denominators are target-aligned.

Pat and Darwin: the collaborator-facing status should start with "safe
now" and "use cautiously", not the full method inventory.

Rose and Shannon: a stale widget is safer when it is explicitly labelled
as an operating surface rather than evidence. Keep dirty mission-control
work and clean package PRs separate.

Grace: the compute plan must stay manifest-first with immutable chunks and
no fitting on DRAC login nodes.
