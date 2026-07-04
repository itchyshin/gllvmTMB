# Codex new-session handover -- 2026-06-18 05:23 MDT

## Active Goal

Finish all phases in the GLLVM mission-control plan from
`docs/dev-log/recovery-checkpoints/2026-06-17-181500-codex-new-session-handover.md`,
using current repo and GitHub state as authoritative.

Keep this guard active:

```text
PR green != bridge complete != release ready != scientific coverage passed
```

Do not widen any claim beyond row-level evidence in the dashboard, check-log,
validation debt register, PR state, run logs, or local command output.

## Current Branch And Worktree

- Repo: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/r-bridge-grouped-dispersion`
- Current HEAD: `173d623 docs: refresh local power pilot iter 24 evidence`
- Local branch is ahead of origin by 24 commits.
- Tracked tree is clean after `173d623`.
- Untracked files are recovery checkpoints only, including this handover after
  writing.

## Widget / Dashboard State

- Dashboard version: `r35`
- Files:
  - `docs/dev-log/dashboard/version.txt`
  - `docs/dev-log/dashboard/status.json`
  - `docs/dev-log/dashboard/sweep.json`
  - `docs/dev-log/check-log.md`
- Validation already run:
  - `python3 -m json.tool docs/dev-log/dashboard/status.json`
  - `python3 -m json.tool docs/dev-log/dashboard/sweep.json`
  - `git diff --check`
- Latest committed dashboard entry:
  - `## 2026-06-18 -- Local power-pilot iter 24 and live workflow heartbeat`

## Current Evidence Snapshot At 05:19 MDT

- gllvmTMB #489:
  - draft/open/clean
  - head `03fdda1`
  - visible R-CMD-check and coevolution recovery checks succeeded
  - still partial and not release-ready
- GLLVM.jl #101:
  - draft/open/clean
  - head `f7be594`
  - displayed checks remain only old 2026-06-16 Documenter/deploy evidence
  - local merge-ref and live bridge evidence are partial only
  - no mutation is approved; do not push, close/reopen, or create empty commits
- gllvmTMB #486:
  - release gate remains open
- Main full-check run `27752749643`:
  - head `0567cd7`
  - status `in_progress`
  - job rollup at 05:19 MDT: 1 success, 2 in progress
  - no run conclusion yet
- Power-pilot run `27752884846`:
  - head `0567cd7`
  - GitHub run-level status `queued`
  - job rollup at 05:19 MDT: 19 completed-success, 20 in progress, 10 queued
  - `power-pilot-results` remained at
    `5969f6f280fd084f60b6dcf18ca1c5739d531025`
  - no new persisted-store or scoring evidence yet
- Local power pilot:
  - latest stable iteration: iter 24 at 2026-06-18 05:14 MDT
  - 383,510 / 480,000 reps
  - 0/48 cells at cap
  - 0 errored cells
  - signal mean coverage 0.753
  - pass94 3/24
  - pass95 2/24
  - null mean coverage-under-null 0.425
  - parent loop and all ten workers alive; nine workers active; STOP absent

## Current Phase Status

### Phase A -- Dashboard/check-log evidence

Current state: stabilized through `r35` and committed at `173d623`.

Next action: refresh only when live evidence changes. Do not churn the widget
for no-op polls.

### Phase B -- GLLVM.jl #101 CI trigger path

Current decision: defer without maintainer-approved mutation.

Evidence:

- `GLLVM.jl/AGENTS.md` says no push without explicit maintainer instruction.
- `GLLVM.jl/.github/workflows/CI.yml` has `push` to `main` and
  `pull_request` to `main`, but no useful `workflow_dispatch`.
- Branch run list for `codex/julia-per-trait-dispersion` still shows only
  old Documenter run `27652799083`.

Allowed next paths:

- Ask/receive explicit maintainer approval for an empty no-file commit to
  `codex/julia-per-trait-dispersion`.
- Ask/receive explicit maintainer approval to close/reopen #101.
- Continue deferring and keep #101 evidence partial.

Do not mutate #101 without explicit approval.

### Phase C -- R bridge live evidence

Current state: local no-Julia and live JuliaCall bridge suites had passed
earlier against GLLVM.jl `f7be594`, but this remains partial until #101 has
fresh PR CI or an explicit maintainer-approved equivalent.

Next action after #101 evidence is current:

- refresh no-Julia bridge tests;
- refresh live JuliaCall grouped-dispersion bridge tests;
- update JUL-01/JUL-01A rows only with command/SHA/date evidence.

### Phase D -- Power/simulation evidence

Current state:

- remote run `27752884846` is live; no scoring until it completes and persists
  a new store;
- local iter 24 is process/diagnostic evidence only;
- existing scoring still blocks coverage/power promotion.

Next action:

- watch run `27752884846`;
- if completed and `power-pilot-results` moves, fetch/archive/score the store;
- do not call coverage or power passed until Fisher/Curie-style scoring says so.

### Phase E -- Docs/pkgdown/release

Current state:

- main R-CMD/pkgdown completed green at `0567cd7` before the live scheduled
  full-check;
- scheduled full-check `27752749643` is still live;
- issue #486 remains open; no release-ready claim.

Next action:

- wait for full-check conclusion;
- only after #489/#101/bridge/power gates are current, run Rose/Shannon/Grace
  audits and any required pkgdown/pre-publish checks;
- keep release blocked until `--as-cran` evidence exists.

## Suggested New Sessions

### Session 1 -- Mission Control And Widget Owner

Repo: `gllvmTMB`

Goal: own the dashboard/check-log/recovery evidence lane. Poll live runs only
when useful, update widget/check-log only for stable evidence, and keep the
guard active.

Immediate first steps:

1. Read `AGENTS.md`, this handover, git status/diff, latest check-log entry,
   and dashboard `r35`.
2. Poll `27752749643`, `27752884846`, #489, #101, #486, and
   `power-pilot-results`.
3. If a run concludes or the results branch moves, update dashboard/check-log
   with exact evidence and commit. Otherwise report no-op status.

### Session 2 -- Power Store And Scoring Lane

Repo: `gllvmTMB`

Goal: watch `27752884846` and perform the remote-store fetch/archive/scoring
only if the run completes and `power-pilot-results` moves.

Immediate first steps:

1. Read `AGENTS.md`, this handover, and the r35 check-log entry.
2. Poll `27752884846` and `git ls-remote origin refs/heads/power-pilot-results`.
3. If branch is still `5969f6f`, do not score; report live process state.
4. If branch moved, fetch/archive/score with Fisher/Curie framing and update
   evidence without claiming scientific coverage passed prematurely.

### Session 3 -- GLLVM.jl #101 CI Gate Lane

Repo: `GLLVM.jl`

Goal: keep the #101 trigger decision evidence-led without mutation unless the
maintainer explicitly approves it.

Immediate first steps:

1. Read `GLLVM.jl/AGENTS.md` and this handover.
2. Check #101 PR state, branch status, workflow triggers, and latest runs.
3. Confirm whether any non-mutating trigger exists.
4. If not, prepare the exact options and do not push or close/reopen.

### Session 4 -- Release/Docs Gate Audit

Repo: `gllvmTMB`

Goal: remain read-only until bridge/power gates are current, then run the
Rose/Shannon/Grace audit path for pkgdown/docs/release readiness.

Immediate first steps:

1. Read `AGENTS.md`, this handover, #486, dashboard `r35`, and latest
   check-log entries.
2. Verify that no public-facing text implies bridge complete, release ready, or
   scientific coverage passed.
3. Do not edit public docs until the preceding gates are current and the
   pre-publish/pkgdown commands are appropriate.

## Coordination Rules For All New Sessions

- Current repo/GitHub state is authoritative; re-poll before acting.
- Run the pre-edit lane check before touching shared files:
  `/opt/homebrew/bin/gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,isDraft,headRefName,updatedAt,url`
  and
  `git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/dashboard docs/dev-log/recovery-checkpoints`
- Never use `git add -A`.
- Do not push gllvmTMB evidence commits unless the maintainer asks.
- Do not mutate GLLVM.jl #101 without explicit approval.
- Keep this guard active in every report:
  `PR green != bridge complete != release ready != scientific coverage passed`.
