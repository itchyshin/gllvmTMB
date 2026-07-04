# Codex handover checkpoint -- 2026-06-17 05:00 MDT

## Purpose

Prepare the `gllvmTMB` workspace for a new Codex session after the overnight
GLLVM.jl + gllvmTMB twin-finish monitoring run.

## Current branch and tree

- Repository: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/r-bridge-grouped-dispersion`
- Remote tracking: `origin/codex/r-bridge-grouped-dispersion`
- Last pushed commit: `e79ed27 docs: add overnight recovery checkpoint`
- PR: <https://github.com/itchyshin/gllvmTMB/pull/489>
- PR state at 2026-06-17 04:58 MDT:
  - draft: yes
  - merge state: `CLEAN`
  - head: `e79ed274378ab6ba03ca79d61afe12fcef683241`
  - checks: `R-CMD-check / ubuntu-latest (release)` success and
    `coevolution-two-kernel-recovery / recovery` success

The only intentional local source-tree addition for handover is this checkpoint
file. The ignored widget directory `pkgdown-site/` also has local status JSON
updates and should not be treated as package source.

## Commands run immediately before handover

- `date '+%Y-%m-%d %H:%M:%S %Z (%z)'`
  - `2026-06-17 04:58:07 MDT (-0600)`
- `git status --short --branch && git diff --stat && git log -1 --oneline`
  - `## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion`
  - `e79ed27 docs: add overnight recovery checkpoint`
- `gh pr view 489 --json number,title,isDraft,headRefName,headRefOid,mergeStateStatus,statusCheckRollup,url`
  - draft PR #489, merge-clean, green at `e79ed27`
- `gh run view 27665164559 --json status,conclusion,updatedAt,url,jobs`
  - scheduled power-pilot run completed successfully at
    `2026-06-17T07:10:44Z`
  - all 51 jobs were `completed:success`
- Widget validation:
  - `jq empty pkgdown-site/status.json`
  - `curl -s http://127.0.0.1:8770/status.json | jq -r '.updated'`
  - served timestamp: `2026-06-17 04:58 MDT`
- Chrome widget refresh:
  - same existing Google Chrome tab refreshed
  - output: `REFRESHED_EXISTING_WIDGET_TAB_COUNT=1; window 1 tab 2`

## Overnight work completed

- Preserved PR #489 as a draft/partial bridge PR rather than widening or landing
  it.
- Confirmed PR #489 stayed green and merge-clean at `e79ed27`.
- Kept the status widget at <http://127.0.0.1:8770/> updated and refreshed only
  the existing Chrome tab.
- Monitored scheduled power-pilot run
  <https://github.com/itchyshin/gllvmTMB/actions/runs/27665164559>.
  - The run completed successfully with all 51 jobs green.
  - `origin/power-pilot-results` still pointed at
    `ed7a88d power-pilot: accumulate reps (run 58)` after fetch.
- Summarised the archived results branch plus local store using
  `dev/m3-pilot-report.R::pilot_collect()`:
  - remote store: 48 cells, 10,188 accumulated reps, 0/48 cells at cap,
    mean signal-cell coverage 0.739, 4/32 signal rows at the 94% gate, and
    4/32 signal rows at the 95% gate;
  - remote + local LaunchAgent store: 48 cells, 303,888 accumulated reps,
    0/48 cells at cap, mean signal-cell coverage 0.753, 3/32 signal rows at
    the 94% gate, and 2/32 signal rows at the 95% gate.
- Posted bounded evidence updates, without closure:
  - #346: <https://github.com/itchyshin/gllvmTMB/issues/346#issuecomment-4727147377>
  - #349: <https://github.com/itchyshin/gllvmTMB/issues/349#issuecomment-4727147513>
- Continued monitoring the local LaunchAgent:
  - latest raw local log at 2026-06-17 04:45 MDT: iteration 99, 10 cells run
    on 10 cores, 0 errored cells;
  - local-only raw store: 336,000 / 480,000 reps (70.0%);
  - 0/48 cells at cap;
  - signal-cell coverage summary in the local log remains mean 0.753, 3/24 at
    or above 94%, 3/24 at or above 95%;
  - null/Type-I proxy mean coverage-under-null remains 0.425.

## Important boundaries

- Do not describe PR #489 as a complete bridge or release-ready bridge.
  It is a draft, partial Julia bridge admission PR.
- Do not close issues from chat memory.
  Live issue views and Rose/Shannon signoff are still required.
- Do not collapse the successful scheduled workflow into a scientific power or
  coverage claim. The helper summary still shows 0/48 cells at cap and weak
  coverage-gate attainment.
- Keep the local raw LaunchAgent progress separate from the
  `pilot_collect()` helper summary; they are different evidence surfaces.
- Keep using the same Chrome tab when refreshing the widget; do not open a new
  browser or tab.

## Next safest actions for the next Codex session

1. Read this checkpoint, then run:
   - `git status --short --branch`
   - `git diff --stat`
   - `git diff -- docs/dev-log/recovery-checkpoints/2026-06-17-050000-codex-handover-checkpoint.md`
2. Decide whether to keep this checkpoint uncommitted as local handover context
   or commit it in a separate doc-only handover commit. Avoid pushing a
   checkpoint commit before considering that PR #489 is currently green at
   `e79ed27`.
3. Recheck PR #489 live:
   - `gh pr view 489 --json isDraft,headRefOid,mergeStateStatus,statusCheckRollup,url`
4. Recheck the local power pilot:
   - `tail -n 40 /Users/z3437171/gllvmTMB-power-pilot/dev/m3-pilot-local.log`
   - `launchctl print gui/$(id -u)/com.gllvmtmb.power-pilot-local | sed -n '1,90p'`
5. Recheck the scheduled power-pilot / results branch state:
   - `gh run list --workflow power-pilot-sweep.yaml --limit 5`
   - `git fetch origin power-pilot-results:refs/remotes/origin/power-pilot-results`
   - `git log --oneline --max-count=5 origin/power-pilot-results`
6. Refresh the widget only in the existing Chrome tab if evidence changes.
7. Keep the branch quiet unless the maintainer explicitly chooses the next
   implementation lane. The recommended next decision is still the maintainer /
   Julia landing decision for draft PR #489, not another broad bridge feature
   slice.

