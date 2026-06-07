# 2026-06-06 19:10:53 Codex recovery checkpoint

Context: resumed after context compaction while preparing the Power-pilot
zero-exclusion scoring correction branch.

Current branch and status:

- Worktree: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/power-pilot-scoring-ledger-2026-06-06`
- `git status --short --branch`:
  - `## codex/power-pilot-scoring-ledger-2026-06-06`
  - ` M .github/workflows/power-pilot-sweep.yaml`
  - ` M dev/m3-pilot-report.R`
  - ` M docs/dev-log/check-log.md`
  - `?? docs/dev-log/after-task/2026-06-06-power-pilot-zero-exclusion.md`
  - `?? docs/dev-log/recovery-checkpoints/2026-06-06-191053-codex-checkpoint.md`

Changed files / diff stat:

- `.github/workflows/power-pilot-sweep.yaml`: coverage+power board wording
  changed to coverage+diagnostics; board text now names the
  zero-exclusion panel as diagnostic rather than Type-I / power.
- `dev/m3-pilot-report.R`: adds `zero_exclusion_rate`, keeps `power` as a
  compatibility alias, renames the second plot output to
  `zero_exclusion`, writes `pilot-zero-exclusion-diagnostic.png`, and keeps
  `pilot_plot_power()` as a wrapper.
- `docs/dev-log/check-log.md`: adds the 2026-06-06 Power-pilot
  zero-exclusion scoring correction entry with exact commands and
  interpretation.
- `docs/dev-log/after-task/2026-06-06-power-pilot-zero-exclusion.md`:
  new after-task report for the correction.
- `git diff --stat` before this checkpoint:
  - `.github/workflows/power-pilot-sweep.yaml | 4 +-`
  - `dev/m3-pilot-report.R | 97 ++++++++++++++++++++------------`
  - `docs/dev-log/check-log.md | 59 +++++++++++++++++++`
  - `3 files changed, 123 insertions(+), 37 deletions(-)`

Commands already run and recorded in the latest check-log entry:

- Pre-edit lane check:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> no open PRs at that time.
- `git log --all --oneline --since="6 hours ago"` -> only merged RE-03 scout
  and result-store commits, no competing shared-file implementation collision.
- Power-pilot scoring audit over the remote and local stores -> 48 cells,
  74,092 accumulated reps, 0 cells complete at cap; representative rows showed
  the CI-excludes-zero metric was not a Type-I / power estimand for
  `Sigma_unit_diag`.
- Posted issue comments:
  - #340: <https://github.com/itchyshin/gllvmTMB/issues/340#issuecomment-4640838745>
  - #349: <https://github.com/itchyshin/gllvmTMB/issues/349#issuecomment-4640839299>
- `air format dev/m3-pilot-report.R` -> succeeded.
- `Rscript --vanilla -e 'invisible(parse(file = "dev/m3-pilot-report.R")); cat("r-parse-ok\n")'`
  -> `r-parse-ok`.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/power-pilot-sweep.yaml"); puts "yaml-ok"'`
  -> `yaml-ok`.
- API smoke sourcing `dev/m3-grid.R` and `dev/m3-pilot-report.R` confirmed
  `zero_exclusion_rate` exists, equals the compatibility `power` column, and
  `pilot_plot(save = FALSE)` returns `coverage` and `zero_exclusion`.

Commands still needing to run:

- Re-run focused checks after this recovery checkpoint is added:
  - `git diff --check`
  - parse `dev/m3-pilot-report.R`
  - parse `.github/workflows/power-pilot-sweep.yaml`
  - API smoke for `pilot_collect()` / `pilot_plot()`
- Commit and push the branch if the checkpoint is accepted.
- Open a focused PR for the Power-pilot scoring/ledger correction and monitor
  CI.
- Continue monitoring targeted RE-03 diagnostic workflow run `27077350201`;
  summarize artifact results on #341 once complete.

Next safest action:

- Run the focused checks, commit and push this Power-pilot scoring branch, open
  a small PR, then wait for the active PR checks before starting the separate
  article/docs slice.

Blocking question:

- None after maintainer approval to continue.
