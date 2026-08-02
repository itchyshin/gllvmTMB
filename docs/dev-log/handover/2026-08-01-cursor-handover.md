# Session Handoff: D-113 betabinomial slope admission closed

**Meta:** 2026-08-01 · from Cursor Agent · to Cursor · fresh context required

## Critical Context

**Should we move to a new lane? Yes.** The completed slope-per-family branch
`claude/slope-per-family-20260801` was squash-merged and deleted after PR
[#887](https://github.com/itchyshin/gllvmTMB/pull/887). Do not resume it.
Likewise, the primary Dropbox checkout remains deliberately parked and dirty on
`claude/profile-coverage-remeasure-20260718` for the D-112 coverage history; it
is not the next D-113 lane.

**SUPERSEDED for "implement #336" (2026-08-01 ledger closure):** Phase 2b/2c/3
are already on `main` (MIS-27/MIS-28). Issues #336/#337/#338 are ledger-closed
with the shared-group independence pin; see
`docs/dev-log/after-task/2026-08-01-missing-data-ledger-closure.md`.
**Default next D-113 lane:** Design 107 VA missing-data (Ayumi). Tweedie remains
the alternate gap-ledger pick. Do not restart a coverage re-measure: D-112 fixes
0.6 at recovery-only interval framing.

The repository remains multi-lane. Read
`docs/dev-log/handover/2026-07-25-active-lane-split.md` before mutations and
do not touch the active Codex spatial-guide lane, PR
[#888](https://github.com/itchyshin/gllvmTMB/pull/888).

## Goals / Mission

gllvmTMB is the stacked-trait, long-format multi-response GLLVM package. D-113
is a post-0.6 capability programme, not a reason to widen 0.6 claims. Its
remaining tracks are EVA, Ayumi/missing-data #332/#336, AGHQ claim-earning,
#750, SEPARABLE, and the remaining per-family slope gaps (tweedie remains
gated).

## What Was Accomplished

- D-113 track 6, Arc 0 + Rung 1 is **DONE**: `betabinomial` (runtime
  `family_id` 8) is admitted to `.augmented_slope_family_contract()` as
  `c1_partial`, logit / `link_0` only.
- The C1 recovery evidence is a multi-trial
  `phylo_indep(1 + x | species)` cell at `n_sp = 200`, `trials = 15`,
  satisfying the #388 large-N discipline. PR #887 reports 15 passing heavy
  recovery assertions.
- PR [#887](https://github.com/itchyshin/gllvmTMB/pull/887) was squash-merged
  to `main` at `2716f74b1cf1d99207044ee3378dd5d9c5003e59` on 2026-08-01.
- The merged after-task reports preserve the admission result and the
  per-family gap ledger:
  - `docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`
  - `docs/dev-log/after-task/2026-08-01-slope-per-family-gap-ledger.md`

## Current Working State

- **Working:** #887 is landed on `origin/main`; this handover is docs-only on
  `docs/cursor-handover-20260801`.
- **In progress:** separate Codex spatial pkgdown guide, PR #888. It does not
  overlap this handover's `CLAUDE.md` or handover path.
- **Protected:** the primary checkout's D-112 coverage-remeasure files and
  untracked local material. Do not stage, clean, or use that checkout for
  D-113.
- **Not working / blocked:** no D-113 implementation blocker. Tweedie stays
  explicitly gated until its own campaign; do not count the betabinomial C1
  result as a route-specific, coverage, or broad-family slope claim.

## Key Decisions & Rationale

- **D-112:** 0.6 retains recovery-only interval framing. No coverage
  re-measure is owed.
- **D-113:** the 0.7 programme is capability expansion: EVA, missing-data,
  AGHQ claims, #750, SEPARABLE, and per-family slopes. The current Mission
  Control receipt identifies missing-data #332 as the primary post-0.6 slice.
- **Betabinomial scope:** the landed result is C1 partial for logit only. It
  does not establish `phylo_dep`, `phylo_latent`, spatial routes, replicated
  seed robustness, Hessian/gradient health, or interval calibration.
- **Lane choice:** missing-data #336 is the recommended next Cursor lane
  because it directly unblocks the Ayumi destination; tweedie is the
  alternative gap-ledger choice.

## Landing State

`~/shinichi-brain/tools/handoff_gate.sh` was run against the primary checkout.
It correctly failed that checkout because it is a parked, dirty D-112 worktree
and also reported legacy unpushed local branches. Those are not artifacts of
this handover or #887. `tools/lane_preflight.sh` found foreign lane activity:
Codex PR #888.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `origin/main` `2716f74b` | yes | yes | [#887 merged](https://github.com/itchyshin/gllvmTMB/pull/887) | LANDED |
| `docs/cursor-handover-20260801` | yes | yes | handover PR | LANDED when this PR is merged |
| `/private/tmp/gllvmtmb-slope-per-family-20260801/dev/probe-betabinomial-slope.R` | no | no | none | CARRIED-OVER: local diagnostic probe only; never stage it. Resume only to inspect it: `git -C /private/tmp/gllvmtmb-slope-per-family-20260801 status --short` |
| primary `claude/profile-coverage-remeasure-20260718` | mixed / dirty | partly no | none | CARRIED-OVER / PROTECTED D-112 checkout; do not resume for D-113 |

## Files Created / Modified

### Landed by PR #887

- `R/fit-multi.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/79-covariance-mode-taxonomy.md`
- `docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`
- `docs/dev-log/after-task/2026-08-01-slope-per-family-gap-ledger.md`
- `docs/dev-log/capability-surface.html`
- `docs/dev-log/check-log.md`
- `tests/testthat/test-augmented-slope-family-policy.R`
- `tests/testthat/test-family-slope-recovery.R`

### This docs-only handover branch

- `docs/dev-log/handover/2026-08-01-cursor-handover.md`
- `CLAUDE.md` (multi-lane snapshot pointer refreshed without replacing the
  authoritative lane map)

## Mission Control

| Repository | Branch / canonical state | What shipped | Next by leverage |
| --- | --- | --- | --- |
| gllvmTMB | `origin/main` @ `2716f74b` | betabinomial C1 augmented-slope admission | fresh missing-data #336 lane; parallel D-112 0.6 honesty closeout |

Mission Control is
`~/shinichi-brain/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`.
It already says: “Next D-113 pick from gap ledger (tweedie campaign OR
missing-data #332/#336). Parallel: 0.6 honesty closeout under D-112. Do NOT
resume coverage re-measure,” and names #332 as primary. No status rewrite was
needed; this handover supplies the durable repository link.

## Next Immediate Steps

1. In a fresh Cursor session, run `tools/lane_preflight.sh` and inspect
   `git status -sb`, the current `origin/main` log, this handover, the active
   lane split, and Mission Control. Classify each instruction `OWED`, `DONE`,
   `RETRACTED`, or `PROTECTED`.
2. Claim **missing-data #336** only if it remains unowned. Create a new
   worktree from `origin/main`; do not reuse the slope or coverage worktrees.
   If the lane preflight identifies an overlap, stop and ask Shinichi rather
   than choosing between missing-data and tweedie unilaterally.
3. Read the missing-data design and existing contract before planning:
   `docs/design/59-missing-data-layer.md`,
   `docs/design/67-missing-predictor-design.md`, and the relevant #332/#336
   issue state. Keep the first slice bounded.
4. Keep D-112’s recovery-only 0.6 framing in all new prose. Do not run a
   coverage campaign unless Shinichi opens a new scope.

## Blockers / Open Questions

- **No blocker for a fresh lane.** Shinichi may instead choose tweedie over
  missing-data; missing-data #336 is the recommended default, not an
  irreversible reassignment.
- Ownership overlap is the only stop condition: PR #888 is foreign and the
  historical lane map contains several parked lanes.

## Gotchas & Failed Approaches

- The first betabinomial probe at `n_sp = 90` failed convergence; the admitted
  C1 fixture is deliberately `n_sp = 200`, not evidence for smaller samples.
- Do not interpret a C1 slope admission as coverage evidence.
- The deleted remote slope branch and its local probe are not a live
  implementation lane.
- The handoff gate failing in the primary checkout is expected evidence of its
  protected parked state, not a reason to clean or repair it.

## How to Resume

Work from a fresh checkout/worktree based on `origin/main`. Cursor has no
inherited terminal, credentials, extensions, or chat context. The live R
toolchain commands used by the landed slope slice were:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-family-slope-recovery.R")'
```

Run only the narrow test that the new missing-data slice changes. Do not stage
`.claude/`, `.uinit/`, the parked D-112 files, or
`dev/probe-betabinomial-slope.R`.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-01-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
