# Shannon Phase 0.2 — MSPL next (read-only scout)

**Date:** 2026-08-15  
**Platform:** Cursor Models bar  
**Workspace:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**Verdict:** **WARN**

One-line: **#978 GOAL is landed and CI is still in flight; do not start new MSPL `src/`; do not merge #972–#976 from this lane; Codex interval stays PROTECTED and was not checked out.**

## Preflight

`~/shinichi-brain/tools/lane_preflight.sh` ran on this repo.

```text
PLATFORM: cursor
ON BRANCH: cursor/mspl-phase4-tapes-planned
LANE: LA-MSPL Phase-4 tapes (#978)
OTHER LANES: Codex interval + Claude interval-calibration + 5 Cursor Phase-4 prep PRs + other foreign work
PREFLIGHT: FOREIGN LANE ACTIVE (codex claude); 16 other Cursor lanes live in 12h
```

This checkout is **clean** and tracks `origin/cursor/mspl-phase4-tapes-planned` at `f658fb96` (Wave 5 closeout). Shared-copy warning: 16 branch switches in 12h on this worktree. Confirm HEAD before any later commit.

Codex `codex/lane-b-mspl-interval-feasibility` lives at `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB` (`e91c7b7c`). This scout did **not** check it out.

## Working tree

| Item | Evidence |
| --- | --- |
| Branch | `cursor/mspl-phase4-tapes-planned` → `origin/cursor/mspl-phase4-tapes-planned` |
| Dirty? | No. `git status -sb` is branch-only. |
| HEAD | `f658fb96` `docs(mspl): Wave 5 closeout for tapes-planned #978` |
| Science tip | `57ae6983` `feat(mspl): add five GLM-outer tapes and open the Poisson public door` |
| Lane map | `docs/dev-log/handover/2026-07-25-active-lane-split.md` refresh #5: GOAL LANDED, not admitted |
| Named handover | `docs/dev-log/handover/2026-08-15-cursor-handover-phase4-tapes.md` |

Closed kits stay historical: catch-up, gaussian, point-continue (`#971` merged `cb126576`), phase4-prep-goal (`#977` merged). Do not reopen.

## Open PR census (`gh pr list --state open --limit 15`)

| PR | Head | Base | State | After-task |
| --- | --- | --- | --- | --- |
| **#978** | `cursor/mspl-phase4-tapes-planned` | `main` | OPEN, MERGEABLE, **UNSTABLE**, ubuntu-latest **IN_PROGRESS** | yes — `2026-08-15-mspl-phase4-tapes-planned.md` |
| #976 | `cursor/mspl-phase4-nbinom1` | `cursor/mspl-point-programme-continue` | OPEN, CLEAN, no checks | yes — nbinom1 prep |
| #975 | `cursor/mspl-phase4-beta` | same stale #971 branch | OPEN, CLEAN, no checks | yes — beta prep |
| #974 | `cursor/mspl-phase4-nbinom2` | same | OPEN, CLEAN, no checks | yes — nbinom2 prep |
| #973 | `cursor/mspl-phase4-tweedie` | same | OPEN, CLEAN, no checks | yes — Tweedie prep |
| #972 | `cursor/mspl-phase4-poisson` | same | OPEN, CLEAN, no checks | yes — Poisson prep |
| #960 | `codex/872-mapped-point-prevalence` | `main` | DRAFT, DIRTY | docs fence |
| #958 | `codex/scale-equivariance-gate0` | `main` | DRAFT, DIRTY | docs fence |
| #957 | `codex/aa03-gaussian-latent-admission` | `codex/mainline-06-issue-closeout` | DRAFT, DIRTY | docs |
| #955 | `claude/drmtmb-mspl-findings-clean` | `main` | OPEN, CLEAN, CI SUCCESS | cross-repo note |

Cursor MSPL WIP is **6 open PRs** (#972–#978). Soft cap is 3. That is the WARN, not a merge-now instruction.

Suggested merge order (human, not this scout):

1. Wait for #978 CI. Review/merge #978 to `main` if green. Do **not** admit Poisson.
2. Leave #972–#976 for their own human merge. They still target the already-merged #971 branch, not `main`. After #978 lands they will need retarget/rebase; do not merge them from the tapes lane.
3. Do not absorb Codex drafts #960/#958/#957 or Claude #955 into this lane.
4. Never merge or rebase the PROTECTED interval branch into point/tapes work.

## File overlap

| Collision | Files | Risk |
| --- | --- | --- |
| #978 ∩ #972 | `tests/testthat/test-mspl-poisson-phase4-oracles.R` | Real. #978 already pin-notes that file. Merging #972 after #978 without retarget will fight. |
| #978 ∩ #974 | `docs/dev-log/check-log.md` | Coordination-file append collision. Already named in the Wave 5 Shannon WARN. |
| #978 alone among MSPL PRs | `src/gllvmTMB.cpp`, `R/mspl.R`, `R/mspl-registry.R`, lane-split, tapes handover | One cpp owner. Do not open a second `src/` editor. |
| #972–#976 vs each other | mostly disjoint LOOP/research/oracle files | Safe as sibling docs **until** retarget onto post-#978 `main`. |

#955 is a single cross-repo markdown file. No MSPL implementation overlap.

## After-task and message bus

- #978 after-task, Melissa plan-actual, LOOP checkpoint, and lane-split row all say GOAL LANDED / not admitted / do not merge #972–#976 / Codex interval PROTECTED.
- Check-log 2026-08-15 Wave 5 entry records the same Shannon WARN and the targeted test receipt (prepare-fence, public-door, fenced tapes, NB1/NB2 fence, API, registry, Poisson oracles: PASS). Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro, admit, merge.
- Sibling prep PRs each carry their own after-task. Coverage is present; the gap is **merge sequencing**, not missing reports.

## Rule-drift notes

- Pre-edit lane check: open-PR list and 6-hour `git log` were live before this scout. Shared rule files (`check-log.md`, lane-split, after-task) are already owned by #978. Do not append a new lane claim on them until #978 CI finishes.
- Merge authority: #978 is high-risk (`src/` + family door). Human review, not agent self-merge.
- CI pacing: one ubuntu-latest run is in progress on #978. Do not push a follow-up commit on this branch while that run is live.
- Design-number ledger (preflight): 15 duplicate slots across refs; next free **117**. Do not mint a new design number from this checkout.
- Foreign interval lanes (do not touch):
  - Codex `codex/lane-b-mspl-interval-feasibility` (binary SE) — PROTECTED
  - Claude `claude/mspl-interval-calibration` at `/private/tmp/gllvmtmb-mspl-interval-calibration`

## What “next” is allowed

Allowed without a new G0:

- Watch #978 CI. If green, human review/merge. If red, fix only on `cursor/mspl-phase4-tapes-planned` after the active run ends.
- Keep #972–#976 parked for their own human merge after retarget.

Needs a **new G0** (handover OWED list):

- Poisson `planned` → `admitted`
- Public `estimator="mspl"` on NB1 / NB2 / beta / Tweedie
- Gaussian or Poisson SE
- Totoro campaign
- NEWS `covered`

HARD STOP (unchanged): Codex interval checkout/absorb · admit without Shinichi · NEWS covered · public `mspl` on the four fenced families · Totoro >30 min · repo-root `LOOP/`.

## Next action

Stay on this clean tapes checkout. Do not edit `src/`. Do not check out the Codex interval worktree. The next MSPL act is **human merge of #978 after CI**, then a new GOAL if any science continues.
