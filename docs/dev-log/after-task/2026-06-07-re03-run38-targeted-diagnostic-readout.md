# After-Task: RE-03 run 38 targeted diagnostic readout

## Task Goal

Harvest the manual run-38 `s = 2` dep-slope diagnostic, post the result to
issue #341, and decide whether the new evidence changes RE-03 admission
status for non-Gaussian `phylo_dep(..., s >= 2)`.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, README, NEWS, or pkgdown navigation change.

The model target is still the existing RE-03 validation row: Gaussian
`phylo_dep(1 + x1 + x2 | sp)` is covered, while non-Gaussian `s >= 2` remains
reserved behind the runtime guard until a separate sweep clears. This readout
does not change the guard or the validation-debt register.

## Files Created Or Changed

- `docs/dev-log/check-log.md`
  - Adds the run-38 artifact/result-store readout and the issue-comment link.
- `docs/dev-log/after-task/2026-06-07-re03-run38-targeted-diagnostic-readout.md`
  - This report.

No implementation, test, roxygen, Rd, vignette, README, NEWS, roadmap, or
pkgdown file changed.

## Evidence

- Workflow run:
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27106800868>
- Result-store commit:
  `a067f04 dep-slope campaign: accumulate seeds (run 38)`
- Downloaded artifact:
  `/tmp/gllvmtmb-depslope-run27106800868/dep-slope-campaign-run-38/`
- GitHub issue readout:
  <https://github.com/itchyshin/gllvmTMB/issues/341#issuecomment-4644432504>

Run 38 used `families = nbinom2,ordinal_probit`, `s_grid = 2`,
`n_grid = 600,1200`, `seeds_per_run = 1`, `n_rep = 20`,
`x_sd_grid = 1,1.5`, and `slope_scale_grid = 1,1.25`.

The accumulated `dep-slope-sweep-s2-accumulated.csv` store grew from 99 to
115 rows. The fresh seed was `3801`.

## Results

All valid `slope_scale = 1.0` cells passed strict and loose recovery:

| family | n_sp | x_sd | PD | strict | loose | max_sigma_diff |
|---|---:|---:|---:|---:|---:|---:|
| nbinom2 | 600 | 1.0 | 1/1 | 1/1 | 1/1 | 0.1730 |
| ordinal_probit | 600 | 1.0 | 1/1 | 1/1 | 1/1 | 0.3071 |
| nbinom2 | 1200 | 1.0 | 1/1 | 1/1 | 1/1 | 0.1537 |
| ordinal_probit | 1200 | 1.0 | 1/1 | 1/1 | 1/1 | 0.1868 |
| nbinom2 | 600 | 1.5 | 1/1 | 1/1 | 1/1 | 0.2307 |
| ordinal_probit | 600 | 1.5 | 1/1 | 1/1 | 1/1 | 0.3594 |
| nbinom2 | 1200 | 1.5 | 1/1 | 1/1 | 1/1 | 0.1346 |
| ordinal_probit | 1200 | 1.5 | 1/1 | 1/1 | 1/1 | 0.1598 |

All requested `slope_scale = 1.25` cells returned `failure_reason = not_fit`
with `note = fixture: the leading minor of order 3 is not positive`. These
rows are not model-fit failures; they show that the stronger-slope fixture was
not a valid positive-definite covariance design.

## Checks Run

- `gh run view 27106800868 --repo itchyshin/gllvmTMB --json databaseId,status,conclusion,workflowName,headBranch,headSha,event,url,jobs`
  -> run completed successfully on `main`.
- `gh run download 27106800868 --repo itchyshin/gllvmTMB --dir /tmp/gllvmtmb-depslope-run27106800868`
  -> downloaded the run-38 log and `dep-slope-sweep-s2-accumulated.csv`.
- `git fetch origin dep-slope-sweep-results:refs/remotes/origin/dep-slope-sweep-results`
  -> result-store ref updated to `a067f04`.
- `Rscript --vanilla - <<'RS' ... read dep-slope-sweep-s2-accumulated.csv; inspect appended rows 100:115 ... RS`
  -> confirmed 16 fresh rows, 8 strict-pass fits and 8 fixture failures.
- `grep -n "not_fit\|ERROR\|WARN\|Accumulated\|IDENTIFIABILITY_SWEEP_DONE" /tmp/gllvmtmb-depslope-run27106800868/dep-slope-campaign-run-38/dep-slope-campaign.log | tail -n 80`
  -> confirmed the eight positive-definiteness fixture failures and successful
  accumulation.
- `rg -n "^\| RE-03\||RE-03" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md ROADMAP.md`
  -> confirmed RE-03 still reads `partial`.
- `gh pr list --state open --json number,title,headRefName,baseRefName,author,url`
  -> no open PR collision before editing shared dev-log files.
- `git log --all --oneline --since="6 hours ago"`
  -> no competing shared-file branch appeared.
- `gh issue comment 341 --repo itchyshin/gllvmTMB --body-file /tmp/gllvmtmb-re03-run38-issue.*.md`
  -> posted the issue readout.

## Consistency Audit

The exact status-inventory scan was:

```sh
rg -n "^\| RE-03\||RE-03" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md ROADMAP.md
```

Verdict: the register still marks RE-03 `partial`; Design 61 still treats
non-Gaussian structured-slope coverage as reserved; no public wording was
changed or newly advertised.

## Tests Of The Tests

No new package test was added. This task consumed an existing remote simulation
diagnostic and classified the rows. The useful test-of-test finding is that the
`slope_scale = 1.25` axis must be fixture-validated for positive definiteness
before it can be treated as an admission diagnostic.

## What Did Not Go Smoothly

The `slope_scale = 1.25` design failed before fitting because the fixture
covariance was not positive definite. That is useful, but it means the run
answered only half of the intended diagnostic question.

The GitHub app connector could read issue #341 but received a 403 when trying
to comment. The authenticated `gh` CLI posted the issue update successfully.

## Team Learning

- Ada: keep the issue and dev-log boundary clear. Run 38 strengthens the
  evidence for the valid design but does not relax the guard.
- Curie: validate the DGP covariance before using stronger-slope settings as
  simulation evidence.
- Fisher: count only fitted rows as recovery evidence; the `not_fit` rows are
  fixture-design evidence.
- Rose: issue #341, the check-log, and this after-task report now say the same
  thing: RE-03 stays `partial`.
- Grace: the manual workflow finished cleanly after the schedule was stopped,
  and the result-store commit is traceable.

## Design-Doc Updates

None. `docs/design/35-validation-debt-register.md` remains unchanged because
RE-03 did not clear an admission threshold.

## Pkgdown And Documentation Updates

None. No user-facing documentation changed.

## Roadmap Tick

N/A. No `ROADMAP.md` row status chip or progress bar changed.

## GitHub Issue Ledger

- Inspected and commented #341:
  <https://github.com/itchyshin/gllvmTMB/issues/341#issuecomment-4644432504>
- No issue closed.
- No new issue created; the next RE-03 fixture-design step fits under #341.

## Definition Of Done Accounting

1. **Implementation.** No implementation change; this was a readout.
2. **Simulation recovery test.** Existing remote diagnostic consumed; no new
   test added.
3. **Documentation.** Check-log and after-task report updated. No public docs
   changed.
4. **Runnable user-facing example.** Not applicable.
5. **Check-log entry.** Added with exact commands, artifact paths, and issue
   link.
6. **Review pass.** Curie/Fisher/Rose/Grace lenses applied as above. No
   Boole/Gauss/Noether gate is triggered because grammar, likelihood, and TMB
   code are untouched.

## Known Limitations And Next Actions

RE-03 remains `partial`. The public non-Gaussian
`phylo_dep(..., s >= 2)` guard stays in place.

Next action: redesign the stronger-slope DGP so the covariance matrix is
positive definite, then rerun a small multi-seed `s = 2` diagnostic for
`nbinom2` and `ordinal_probit` before considering any family-specific
admission PR.
