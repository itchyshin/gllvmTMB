# After Task: Capability-First Ultraplan Audit

**Branch**: `codex/capability-first-audit-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Run the agreed two-hour autonomous planning block after PR #552: refresh live
gates, audit current pilot semantics, prepare the next DRAC CPU smoke commands
without submitting them, and triage speed notes into benchmark-first slices.

## 2. Implemented

- Added `docs/dev-log/audits/2026-06-24-capability-first-two-hour-packet.md`.
- Recorded the current live gate state: no open `gllvmTMB` PRs, post-merge
  R-CMD-check and pkgdown green for `7c675dd`, scheduled Power pilot sweep
  still in progress, and GLLVM.jl #113 still draft/clean.
- Wrote an ADEMP-style skeleton for the core CPU study and a Williams 2024
  self-audit table.
- Mapped the next package slices without moving validation rows.
- Prepared fir SLURM commands for `SLURM_STAGE=all N_SIM_STEP=1 N_BOOT=0` and
  `N_BOOT=2`, explicitly not run here.
- Reduced `/Users/z3437171/Desktop/speed.txt` into benchmark-first speed
  spikes.

## 3. Files Changed

- `docs/dev-log/audits/2026-06-24-capability-first-two-hour-packet.md`
- `docs/dev-log/after-task/2026-06-24-capability-first-ultraplan-audit.md`
- `docs/dev-log/check-log.md`

No R source, TMB source, formula grammar, likelihood, family, roxygen, Rd,
vignette, pkgdown navigation, NEWS, README, ROADMAP, or validation-debt row
changed.

## 3a. Decisions and Rejected Alternatives

Decision: make the next implementation slice a tiny scheduled fir fit-smoke
readout, not the `n_sim = 2000` campaign. Rationale: the manifest-only SLURM
path is proven, but the scheduled fit path still needs artifact inspection at
`N_SIM_STEP=1`. Rejected alternative: launch the core grid now. Confidence:
high.

Decision: treat `/Users/z3437171/Desktop/speed.txt` as triage input only.
Rationale: the NotebookLM URL redirected to a Google login in this session, so
the notebook citations were not rechecked. Rejected alternative: cite speed
leads as validated literature. Confidence: high.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared dev-log edits; no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared dev-log edits; recent history was `7c675dd` only in
  the clean worktree.
- `git status --short --branch`
  -> PASS before edits; clean `main...origin/main`.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 8 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> post-merge R-CMD-check `28111548411` success, post-merge pkgdown
  `28111605400` success, scheduled Power pilot sweep `28106026686` still
  in progress.
- `sed -n '1,260p' docs/design/66-capstone-power-study.md`
  -> inspected Design 66 pilot/core-grid contract.
- `sed -n '1,260p' docs/design/50-m3-3b-surface-admission.md`
  -> inspected surface-admission contract.
- `rg -n "^CI-08|^CI-10|^EXT-13|^EXT-04|JUL-01|JUL-01A|FAM-15|FAM-16|COE-03|COE-04|RE-12|RE-03|FG-13|FG-14|MET-01|MET-04|ANI-09|ANI-10|MIS-07|MIS-09|LAM-02|EXT-10|DIA-11|DIA-12|DIA-14|FG-17|FAM-18|FAM-19|MET-03|MIX-10|EXT-11|MIS-32" docs/design/35-validation-debt-register.md`
  -> inspected the capability backlog rows named by the plan.
- `sed -n '90,240p' dev/m3-pilot-launch.R`
  -> inspected pilot family/link/signal/grid definitions.
- `sed -n '490,940p' dev/m3-pilot-launch.R`
  -> inspected manifest, chunk, and artifact guards.
- `sed -n '260,620p' dev/m3-pilot-report.R`
  -> inspected denominators, MCSE, and zero-exclusion semantics.
- `sed -n '1,260p' dev/power-pilot-slurm-smoke.sh`
  -> inspected SLURM wrapper boundaries and variables.
- `sed -n '1,220p' dev/power-pilot-drac-setup.sh`
  -> inspected DRAC setup helper and fir library convention.
- `sed -n '1,260p' /Users/z3437171/Desktop/speed.txt`
  -> inspected speed-note synthesis.
- NotebookLM URL open attempt:
  `https://notebooklm.google.com/notebook/3b3d2ec5-7779-41ee-b968-22623c80278b`
  -> blocked by Google login redirect in this session.

## 5. Tests of the Tests

No tests were added or changed. This is a planning/audit artifact. Existing
manifest/report tests were inspected through their after-task evidence and
remain the relevant tests for the next implementation slice.

## 6. Consistency Audit

Exact searches and verdicts:

- `rg -n "Type-I proxy|coverage-under-null|null/Type-I|power/Type-I|signal-zero Type-I|Type-I error for Sigma_unit_diag" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml`
  -> PASS; current source/report wording keeps signal-zero output diagnostic.
- `rg -n "binomial_probit|binomial_logit_harness|zero-exclusion|coverage_mcse|coverage_eligible" dev/m3-pilot-launch.R dev/m3-pilot-report.R dev/power-pilot-run.R docs/design/66-capstone-power-study.md .github/workflows/power-pilot-sweep.yaml tests/testthat/test-m3-pilot-report.R tests/testthat/test-m3-pilot-manifest.R`
  -> PASS; current source labels the binomial logit harness while preserving
  old `binomial_probit-*` cell IDs.
- `rg -n "GPU.*(enabled|tested)|production launch|n_sim = 2000.*started|validated binomial-probit|probit support|CI-08.*covered|CI-10.*covered" docs/dev-log/audits/2026-06-24-capability-first-two-hour-packet.md`
  -> PASS after edits; no hard-stop overclaim in the new audit packet.

## 7. Roadmap Tick

N/A. This audit changes no roadmap status and moves no validation-debt row.

## 7a. GitHub Issue Ledger

No GitHub issue was commented, closed, or created. Issue #340 remains the
Power pilot board; the running scheduled sweep was not harvested for
validation evidence.

## 8. What Did Not Go Smoothly

The NotebookLM link could not be opened from this session because it redirected
to Google login, so the speed-note citations remain unverified. The scheduled
Power pilot sweep was still in progress, so no new sweep output was inspected
or promoted.

## 9. Team Learning

Ada: the most valuable next step is a tiny scheduled fir fit-smoke readout,
not another high-level plan or a broad campaign.

Curie: the manifest/chunk machinery already carries good seed and artifact
provenance; the next risk is whether tiny scheduled fit artifacts aggregate
cleanly.

Fisher: `signal = 0` remains a positive-variance coverage diagnostic for the
current target; Type-I/null calibration needs a separate target-aligned
decision rule.

Grace: fir setup is ready for CPU scheduled smoke jobs, but the first fit run
must remain small and scheduled through SLURM.

Rose: documentation should update as gates, but the immediate public-story
risk is overclaiming pilot or speed evidence.

Shannon: the work stayed in `/private/tmp`; the Dropbox checkout was read only
for the project-local after-task skill and was not staged, reset, cleaned, or
modified.

## 10. Known Limitations And Next Actions

- Do not promote `CI-08` or `CI-10`.
- Do not launch GPU work or the production `n_sim = 2000` campaign.
- Next action, if Shinichi widens the stop line: run fir
  `SLURM_STAGE=all N_SIM_STEP=1 N_BOOT=0` as a scheduled CPU job, inspect
  artifacts, then decide whether to repeat with `N_BOOT=2`.
- True binomial-probit and ordinal-probit coverage remain separate repair
  slices.
- Speed spikes remain benchmark proposals until objective/gradient, accuracy,
  CI/status, and runtime gates pass.
