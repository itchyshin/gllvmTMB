# Codex Recovery Checkpoint - 2026-06-17 00:11 MDT

## Branch And Status

- Branch: `codex/r-bridge-grouped-dispersion`
- `git status --short --branch`: `## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion`
- Tracked source tree before this checkpoint: clean.
- Ignored local widget files under `pkgdown-site/` were updated after compaction and refreshed in the existing Chrome tab.

## Changed Files And Diff Stat

- Before this checkpoint, `git diff --stat` was empty.
- This checkpoint adds only `docs/dev-log/recovery-checkpoints/2026-06-17-001114-codex-checkpoint.md`.

## Commands Already Run Since Rehydration

- `date '+%Y-%m-%d %H:%M:%S %Z'` -> `2026-06-17 00:05:16 MDT` on first rehydration check.
- `git status --short --branch` in `gllvmTMB` -> clean tracked tree on `codex/r-bridge-grouped-dispersion`.
- `git log -1 --oneline` in `gllvmTMB` -> `dad6c78 docs: narrow masked CI bridge wording`.
- `jq empty pkgdown-site/status.json` -> valid JSON.
- `curl -s http://127.0.0.1:8770/` -> local widget server responded.
- Existing Chrome tab refresh via AppleScript -> `REFRESHED_EXISTING_WIDGET_TAB_COUNT=1; window 1 tab 2`.
- `gh pr view 489` -> draft PR, merge state `CLEAN`, checks passed at `dad6c78`.
- `gh pr view 101 --repo itchyshin/GLLVM.jl` -> draft PR, merge state `CLEAN`, Documenter passed at `f7be594`.
- `gh pr view 95 --repo itchyshin/GLLVM.jl` -> draft PR, merge state `CLEAN`, older full Julia CI green.
- `gh pr view 94 --repo itchyshin/GLLVM.jl` -> draft PR, merge state `DIRTY`, salvage only.
- `gh run list --workflow power-pilot-sweep.yaml` -> latest scheduled run `27665164559` still `in_progress`.
- `gh run view 27665164559 --json jobs` -> 43 jobs completed successfully, 6 shard jobs still in progress.
- `launchctl print gui/$(id -u)/com.gllvmtmb.power-pilot-local` -> local LaunchAgent running with `LOCAL_CORES=10`, one recorded segmentation-fault restart.
- Targeted cross-twin `rg` scans over GLLVM and DRM bridge surfaces -> confirmed GLLVM uses fit-time `ci_method` / `ci_nboot` / `ci_seed` plus capability/gate registry surfaces, while DRM uses `confint(..., method=, level=, B=, seed=, threads=)` for its first bridge inference slice.
- `gh issue list` for `gllvmTMB`, `GLLVM.jl`, `drmTMB`, and `DRM.jl` -> open issue ledgers refreshed read-only.

## Commands Still To Run

- Recheck `gh run view 27665164559` later to see whether the remaining six power-pilot shards finish and whether the result branch advances.
- Recheck PR #489 and PR #101 near the 5am MDT stop.
- Refresh the widget in the same Chrome tab after any new evidence, without opening another tab or browser window.

## Next Safest Action

- Continue read-only audits and low-risk widget updates until the 5am MDT stop point.
- Avoid further package-source edits unless required by the recovery protocol or a clear safety issue.
- Keep PR #489 draft/partial; do not merge or close issues from chat memory.

## Blocking Questions

- None for the overnight continuation.
- Maintainer decision still needed later: whether draft PR #489 lands as the next-release Julia bridge branch or stays separate while CRAN-main remains lean.
