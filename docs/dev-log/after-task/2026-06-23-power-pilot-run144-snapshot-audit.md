# After Task: Power Pilot Run 144 Snapshot Audit

**Branch**: `codex/power-pilot-audit-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose`

## 1. Goal

Freeze the current power-pilot snapshot after run 144 and record why it remains
diagnostic-only before any Totoro, DRAC, or larger power-study scaling.

## 2. Implemented

- Added `docs/dev-log/audits/2026-06-23-power-pilot-run144-snapshot-audit.md`.
- Recorded run #144 metadata: workflow ID, source SHA, result-branch SHA, result
  commit time, job count, result store path, and run window.
- Recomputed the current result-store summaries from `origin/power-pilot-results`.
- Recorded the remaining blockers: binary label mismatch, missing ordinal
  coverage rows, zero-exclusion not being Type-I/power, missing broad MCSE and
  denominator accounting, and missing durable session manifest.

## 3. Mathematical Contract

No likelihood, estimator, formula grammar, response family, API, or simulation
DGP changed in this slice. The mathematical contract is therefore unchanged:
`CI-08` and `CI-10` remain partial, and run 144 remains diagnostic-only until
the pilot target, metric names, MCSE, denominators, and fit-health accounting
are repaired.

## 3a. Decisions and Rejected Alternatives

- Decision: make this an audit note only. Rationale: the pilot semantics need
  repair before code, workflow, or compute changes.
- Rejected alternative: launch a new pilot or DRAC smoke immediately. The run
  144 readout already shows unresolved target and reporting problems.

## 4. Files Touched

- `docs/dev-log/audits/2026-06-23-power-pilot-run144-snapshot-audit.md`
- `docs/dev-log/after-task/2026-06-23-power-pilot-run144-snapshot-audit.md`
- `docs/dev-log/check-log.md`

## 5. Checks Run

- `git worktree add -b codex/power-pilot-audit-20260623 /private/tmp/gllvmtmb-power-pilot-audit-20260623 origin/main`
  -> clean worktree at `88b8fa85`.
- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,url,mergeStateStatus,statusCheckRollup`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> showed #537, #538, #539 and `power-pilot-results` run 144.
- `git ls-tree -r --name-only origin/power-pilot-results`
  -> listed 48 per-cell RDS files plus `pilot-index.rds`.
- `git show --stat --oneline --decorate --no-renames origin/power-pilot-results -1`
  -> `6f0be960 power-pilot: accumulate reps (run 144)`.
- `gh run list --repo itchyshin/gllvmTMB --workflow 'Power pilot sweep' --limit 20 --json ...`
  -> run 144 success, run 145 already in progress.
- `gh run view 28022283502 --repo itchyshin/gllvmTMB --json jobs`
  -> 51 jobs, all success, first start `2026-06-23T11:17:06Z`, last completion
  `2026-06-23T14:25:18Z`.
- `Rscript --vanilla -e 'idx <- readRDS("/tmp/pilot-index-run144.rds"); ...'`
  -> `48 x 9` index, `sum_n_sim = 273576`; all index rows marked `done`.
- `Rscript --vanilla -e '... pilot_accum_status(results_dir=rd, n_sim_cap=10000); ... pilot_collect(results_dirs=rd) ...'`
  -> 1 / 48 cells complete, 273,576 / 480,000 reps, 48 collected cells, 28
  flagged cells.
- `Rscript --vanilla -e '... aggregate(is.na(coverage_primary) ~ family, df, sum) ...'`
  -> ordinal-probit accounts for all 12 missing coverage rows.
- `Rscript --vanilla -e '... print(out[, keep]); ...'`
  -> full per-cell compact table printed; signal coverage mean 0.752, 3 / 24
  pass 94%, 2 / 24 pass 95%, null mean coverage 0.424, 28 flagged cells.
- `git show origin/power-pilot-results:dev/m3-pilot-results/binomial_probit-d1-n50-sig0p2.rds >/tmp/binom-cell.rds`
  plus `Rscript --vanilla -e 'x <- readRDS("/tmp/binom-cell.rds"); ...'`
  -> result rows contain `rep_seed`, `seed_base`, fit-health, and bootstrap
  fields but no durable session manifest.
- `Rscript --vanilla -e 'source("/Users/z3437171/shinichi-brain/tools/check-after-task.R"); main_check_after_task("docs/dev-log/after-task/2026-06-23-power-pilot-run144-snapshot-audit.md")'`
  -> PASS; after-task structure check passed.
- `git diff --check`
  -> PASS; no whitespace errors.

## 6. Tests of the Tests

No package tests were added. This was a read-only simulation audit note. The
key verification was recomputing summaries from the result store rather than
copying issue text.

## 7a. Issue Ledger

- Inspected issue #340 indirectly through the run-144 workflow summary path and
  prior status refresh. No new issue comment was posted in this slice because
  the audit note is not yet on `main`.

## 8. Consistency Audit

- `rg -n "pending at report creation|CI-08|CI-10|binomial_probit|coverage_primary|zero-exclusion|Type-I|DRAC|MCSE|session" docs/dev-log/audits/2026-06-23-power-pilot-run144-snapshot-audit.md docs/dev-log/after-task/2026-06-23-power-pilot-run144-snapshot-audit.md`
  -> found the intended row IDs, target-mismatch terms, coverage fields, and
  next-gate wording in the audit note and after-task report. The only
  `pending at report creation` hit is the recorded scan command itself, not a
  stale status claim.

## 8a. Roadmap Tick

N/A. No `ROADMAP.md` or validation row status changed. `CI-08` and `CI-10`
remain partial.

## 9. What Did Not Go Smoothly

- One broad `rg` search across all docs and dev files was too noisy and was
  narrowed to the pilot files and result branch.
- One R compact-table print asked for an `n_boot` column that is not returned by
  `pilot_collect()`; the command was rerun without that field.

## 10. Known Residuals

- No code or workflow repair was made.
- No new simulation was launched.
- Next implementation slice should add a durable run manifest, repair/rename
  the binary link target, explain ordinal coverage, and add MCSE plus explicit
  denominators before compute scaling.

## 11. Team Learning

- Ada: froze the snapshot rather than chasing the in-progress run 145.
- Curie: identified the binary label mismatch and the missing ordinal coverage
  as DGP/reporting blockers.
- Fisher: kept zero-exclusion separate from Type-I and power.
- Grace: verified workflow metadata, result-branch state, and result-store
  provenance fields.
- Rose: kept the audit from moving `CI-08` or `CI-10`.
