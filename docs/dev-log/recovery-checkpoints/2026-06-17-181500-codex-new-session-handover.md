# Codex new-session handover -- 2026-06-17 18:15 MDT

## Purpose

Prepare the next Codex session to continue the active goal:

> finish all the phases in the plan

This handover is intentionally explicit because the current thread is long and
the next session should rehydrate from repository and GitHub evidence, not from
chat memory.

## Branch

`codex/r-bridge-grouped-dispersion`

```sh
git status --short --branch
# ## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion
#  M docs/dev-log/check-log.md
#  M docs/dev-log/dashboard/status.json
#  M docs/dev-log/dashboard/sweep.json
#  M docs/dev-log/dashboard/version.txt
# ?? docs/dev-log/recovery-checkpoints/2026-06-17-050000-codex-handover-checkpoint.md
# ?? docs/dev-log/recovery-checkpoints/2026-06-17-151509-codex-stop-checkpoint.md
# ?? docs/dev-log/recovery-checkpoints/2026-06-17-160541-codex-progress-checkpoint.md
# ?? docs/dev-log/recovery-checkpoints/2026-06-17-180500-codex-restart-checkpoint.md
```

This checkpoint file is also untracked after writing.

## Local Diff

```sh
git diff --stat
#  docs/dev-log/check-log.md          | 47 ++++++++++++++++++++++++++++++++
#  docs/dev-log/dashboard/status.json | 55 +++++++++++++++++++++-----------------
#  docs/dev-log/dashboard/sweep.json  | 36 ++++++++++++++++++++++---
#  docs/dev-log/dashboard/version.txt |  2 +-
#  4 files changed, 112 insertions(+), 28 deletions(-)
```

The local edits record the latest evidence after commit `03fdda1` was pushed
and after the GLLVM.jl #101 local merge-ref test passed. They are not committed
or pushed yet.

## What Was Completed In This Sitting

1. Rehydrated the repo after restart from `git status`, `git diff --stat`,
   `git diff`, and the previous checkpoint
   `2026-06-17-180500-codex-restart-checkpoint.md`.
2. Refreshed live GitHub state for gllvmTMB #489, GLLVM.jl #101, and the
   scheduled power-pilot run.
3. Validated the earlier dashboard JSON refresh:
   `python3 -m json.tool docs/dev-log/dashboard/status.json`,
   `python3 -m json.tool docs/dev-log/dashboard/sweep.json`, stale-string
   `rg`, and `git diff --check`.
4. Committed and pushed:
   `03fdda1 docs: refresh mission-control Julia gate evidence`.
5. Observed that pushing `03fdda1` restarted #489 checks.
6. Fetched GLLVM.jl #101's current PR merge ref into
   `/tmp/gllvm-jl-pr101-merge`:
   synthetic merge commit `2cd8563` merges `f7be594` into main merge commit
   `70a5c83`.
7. Ran a focused #101 local merge-ref test slice with Julia 1.10:

```sh
$HOME/.juliaup/bin/julia --project=. -e 'using Pkg; Pkg.instantiate(); using Test, GLLVM; @testset "PR101 bridge focused merge-ref" begin include("test/test_bridge_capabilities.jl"); include("test/test_bridge_grouped_dispersion.jl"); include("test/test_bridge_ci.jl"); include("test/test_bridge_x.jl"); include("test/test_bridge_missing_mask.jl"); include("test/test_grouped_dispersion.jl"); include("test/test_grouped_dispersion_beta_gamma.jl"); include("test/test_grouped_dispersion_tweedie_nb1.jl"); include("test/test_ordinal_pertrait.jl") end'
# Test Summary:                  | Pass  Total     Time
# PR101 bridge focused merge-ref |  641    641  1m56.1s
```

This is useful partial evidence only. It is not a substitute for fresh
GLLVM.jl PR CI or live JuliaCall bridge evidence.

## Live State At Handover

- gllvmTMB #489:
  - draft/open
  - head `03fdda1`
  - merge state `UNSTABLE`
  - coevolution recovery run `27727834498` succeeded
  - R-CMD-check run `27727834488` still in progress
  - do not call #489 green until R-CMD completes successfully at `03fdda1`
- GLLVM.jl #95:
  - merged to main at `70a5c83`
  - main CI run `27724193515` succeeded
  - main Documenter run `27724193513` succeeded
- GLLVM.jl #101:
  - draft/open
  - base `main`
  - head `f7be594`
  - merge state `CLEAN`
  - displayed PR checks are still only the older Documenter preview from
    2026-06-16
  - local merge-ref focused bridge slice passed 641/641 at `2cd8563`
  - still needs fresh PR CI or explicit maintainer-approved equivalent
- GLLVM.jl #94:
  - dirty salvage; keep separate from #101/#95 ordering and do not use it to
    widen gllvmTMB claims
- gllvmTMB scheduled power-pilot run `27722546237`:
  - still in progress on main `0567cd7`
  - compact snapshot: 45 completed-success jobs, 4 in-progress shards
  - process evidence only, not coverage proof

## Claim Guard

Keep this exact guard active:

`PR green != bridge complete != release ready != scientific coverage passed`

Do not imply:

- draft PR #489 is release-ready;
- #101 has fresh PR CI;
- local merge-ref tests equal GitHub PR CI;
- power-pilot job health equals power/coverage proof;
- GLLVM.jl #94 salvage supports current bridge claims;
- Julia-side selectable fitting algorithms are available unless current code
  evidence proves them.

## Detailed Plan For The Next Session

Start the next Codex session with this user goal:

> Please inherit the handover in
> `docs/dev-log/recovery-checkpoints/2026-06-17-181500-codex-new-session-handover.md`
> and continue the objective: finish all phases in the GLLVM mission-control
> plan. Use current repo/GitHub evidence as authoritative. Do not widen claims
> beyond evidence.

Then execute:

### Phase A -- Rehydrate And Stabilise Current Dashboard Evidence

1. Read `AGENTS.md`, this checkpoint, and the newest `docs/dev-log/check-log.md`
   entry.
2. Run:
   - `git status --short --branch`
   - `git diff --stat`
   - `git diff`
   - `/opt/homebrew/bin/gh pr view 489 --repo itchyshin/gllvmTMB --json number,isDraft,state,mergeStateStatus,headRefOid,statusCheckRollup,updatedAt,url`
   - `/opt/homebrew/bin/gh pr view 101 --repo itchyshin/GLLVM.jl --json number,isDraft,state,baseRefName,headRefName,headRefOid,mergeStateStatus,statusCheckRollup,updatedAt,url`
   - `/opt/homebrew/bin/gh run view 27722546237 --repo itchyshin/gllvmTMB --json status,conclusion,headSha,updatedAt,jobs --jq ...`
3. If #489 R-CMD-check `27727834488` has completed, update
   `status.json`, `sweep.json`, and `check-log.md` with the true result.
4. Validate:
   - `python3 -m json.tool docs/dev-log/dashboard/status.json`
   - `python3 -m json.tool docs/dev-log/dashboard/sweep.json`
   - `git diff --check`
5. Commit the local dashboard/check-log/version changes only after the current
   #489 status is reflected honestly.

### Phase B -- Decide The #101 PR CI Trigger

1. Respect `GLLVM.jl/AGENTS.md`: it says no push without explicit maintainer
   instruction.
2. Present the clean options:
   - maintainer approves an empty no-file commit on
     `codex/julia-per-trait-dispersion` to trigger `pull_request synchronize`;
   - maintainer approves close/reopen of #101 to trigger `pull_request reopened`;
   - accept local merge-ref evidence temporarily and defer PR CI trigger.
3. Preferred technical route, if maintainer explicitly approves a push:
   - use the existing clean worktree
     `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`;
   - create an empty commit such as
     `ci: refresh pr101 checks after main retarget`;
   - push only `codex/julia-per-trait-dispersion`;
   - watch the resulting GLLVM.jl PR CI and Documenter checks.
4. Do not call #101 green unless fresh PR CI or maintainer-approved equivalent
   succeeds on the current head/merge ref.

### Phase C -- R Bridge Live Evidence

After #101 evidence is current:

1. Refresh no-Julia and live JuliaCall bridge evidence in gllvmTMB.
2. Prioritise tests that exercise grouped dispersion bridge admission,
   point-only Sigma-table routes, and interval gates.
3. Keep failures scoped:
   - if no-Julia tests fail, fix R-side gate/admission rows first;
   - if live JuliaCall fails, identify whether the mismatch belongs to
     GLLVM.jl payloads, gllvmTMB bridge wrappers, or local environment.
4. Update dashboard rows `JUL-01` and `JUL-01A` only with command/path/SHA/date
   evidence.

### Phase D -- Power And Simulation Evidence

1. Watch scheduled power-pilot run `27722546237` until completion.
2. If it succeeds, inspect/pull the results branch and compare against run 107
   (`2709930`).
3. Fisher/Curie must score estimands before any promotion:
   - coverage by estimand;
   - pass94/pass95 or replacement thresholds;
   - cap/completion diagnostics;
   - failed/weak cells and why.
4. Keep wording as process/diagnostic evidence until scoring supports a
   scientific claim.

### Phase E -- Public Docs And Release Gate

Only after #489, #101, live bridge, and simulation gates are current:

1. Run Rose/Shannon/Grace-style audits:
   - claim rows match validation debt register;
   - dashboard and check-log match GitHub state;
   - pkgdown/public text does not imply bridge complete/release ready;
   - no issue is closed from chat memory.
2. If user-facing docs change, run the project-local pre-publish and pkgdown
   checks required by `AGENTS.md`.
3. Keep #486 release gate blocked until `--as-cran` evidence exists.
4. Only move #489 toward review when Rose, Shannon, and Grace close the
   coordination/evidence loop.

## Stop/Start Advice

Start a fresh Codex session now. The current thread is long, and the next
session will be more reliable if it begins from this checkpoint plus live
GitHub state.

## Blocking Question For Maintainer

For GLLVM.jl #101, do you explicitly approve a no-file empty commit push to
`codex/julia-per-trait-dispersion` to trigger fresh PR CI after the retarget to
`main`?
