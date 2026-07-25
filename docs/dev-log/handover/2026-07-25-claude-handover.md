# Session Handoff — Claude lane split after private Design-103 closure

**Meta:** 2026-07-25 · author = Claude · target = next Claude · fresh context
recommended.

You are Claude, picking up a shared `gllvmTMB` repository after a private
Codex direct-GH diagnostic.  First read the active-lane split.  The one rule
that prevents loss of work is simple: **the eta simulation lane remains in
Codex; do not touch it from Claude.**

## Goals / mission

Keep `gllvmTMB` a stacked-trait multivariate GLLVM package and preserve the
release/evidence claim boundary.  Continue only the explicitly selected Claude
lane after rehydration.  The completed private Design-103 experiment is not a
package capability, recovery, or EVA result.

## Plans / roadmap

1. Re-derive the intended Claude lane from the split note and its named
   handover before editing.
2. If the human selects the 0.6 release/M5 lane, follow the rc.2 claim-reword
   handover exactly; CRAN submission and a final tag are Shinichi-only acts.
3. If the human selects the dirty profile/Tier-2a lane, attach to the existing
   Dropbox checkout and preserve its uncommitted state; do not silently recreate
   it in a clean worktree.
4. Do not run the Codex eta simulation, direct-2D, VA/JJ/EVA, or Design-103
   work from Claude.

## What was accomplished

- Design-103 is privately closed in its own Codex worktree as
  `TECHNICAL_PARTIAL`.  Direct GH101 global refits exceeded the resource/time
  envelope; bounded GH61 refits were pathological; fixed-coordinate GH101
  start gaps were numerical near-ties in the two N=240 regimes.  Its durable
  local adjudication is named in the lane split.
- This handover records the lane ownership boundary and replaces the stale
  single-lane snapshot pointer with a lane split.

## Current working state

- **Working:** none in this clean handover branch; it contains documentation
  only.
- **In progress:** two independent Claude possibilities (release/M5 and the
  dirty profile/Tier-2a checkout), each needing a human lane choice.
- **Codex-only:** eta simulation at
  `/private/tmp/gllvmtmb-design100-progress-oracle`.  It is explicitly left
  for Codex.
- **Closed:** Design-103, without a public or package claim.

## Key decisions and rationale

- A finite objective or optimiser code is not enough to call a direct-GH
  refit healthy.  The Design-103 bounded refits had extreme parameter/covariance
  blow-up, so no approximation, information, or chart/scale mechanism label
  was issued.
- Selection was only weakly tested at two N=240 coordinates and was not
  materially supported there.  Do not generalise it.
- The eta simulation remains a separate Codex lane to avoid concurrent,
  conflicting computation and repository mutation.

## Landing state

`~/shinichi-brain/tools/handoff_gate.sh` was run before this handover and
reported unlanded state.  Nothing is silently treated as visible to a fresh
checkout.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | ---: | ---: | --- | --- |
| `handover/2026-07-25-claude` (this doc, lane split, `CLAUDE.md`) | yes | yes | #786 open | LANDED on docs-only branch; awaiting human merge |
| `claude/profile-coverage-remeasure-20260718` primary checkout | no | no | none | CARRIED-OVER — 12 user/Claude changes are local and must be resumed only in `/Users/z3437171/Dropbox/Github Local/gllvmTMB`; do not reset, clean, or overwrite |
| `codex/design100-progress-oracle-20260724` | no | no | none | CARRIED-OVER, Codex-owned eta-simulation lane; Claude has no resume authority |
| `codex/design103-covariance-mechanism-20260724` | no | no | none | CARRIED-OVER local-only private diagnosis; closed, do not promote |
| legacy parked branches | mixed | mixed | unrelated | CARRIED-OVER and quarantined; see the gate output and do not clean or push them |

Carried-over resume boundaries:

- **Profile/Tier-2a (Claude only):** `cd '/Users/z3437171/Dropbox/Github Local/gllvmTMB' && git status --short --branch`.
  Attach only after confirming this exact dirty checkout is the intended lane;
  do not switch, reset, clean, or copy files into it.
- **Eta simulation (Codex only):** `cd /private/tmp/gllvmtmb-design100-progress-oracle && git status --short --branch`.
  This is an inspection boundary for Claude, not permission to resume it.
- **Design-103 (closed, local-only):** `sed -n '1,240p' /private/tmp/gllvmtmb-design103-covariance-mechanism/dev/design103-covariance-mechanism/ADJUDICATION.md`.
  Do not edit or promote it.
- **Legacy parked branches:** no resume command is authorised; keep them
  quarantined.

## Files created / modified

- `CLAUDE.md` — snapshot now points to the multi-lane split.
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` — durable ownership map.
- `docs/dev-log/handover/2026-07-25-claude-handover.md` — this handover.

## Next immediate steps

1. Read `AGENTS.md`, `CLAUDE.md`, and
   `docs/dev-log/handover/2026-07-25-active-lane-split.md`.
2. Ask the human which Claude lane to resume if it is not already specified.
3. For release/M5, read `docs/dev-log/handover/2026-07-23-codex-handover.md`
   and work only in its named isolated release worktree.
4. For profile/Tier-2a, read the local dirty checkpoint files already listed by
   `git status`, preserve all changes, and first write a recovery checkpoint
   before any edit.
5. Before any claim, spawn/consult the required Rose-style review lens and
   verify the precise lane state from repository evidence.

## Blockers / open questions

- The next Claude action is a human lane-choice: release/M5 or profile/Tier-2a.
- Network/PR visibility was not assumed from stale local branches; re-check it
  live before outward actions.
- Eta simulation is not a Claude blocker; it is fenced Codex work.

## Gotchas / failed approaches

- Do not interpret Design-103's direct-GH terminal failures as evidence for a
  package defect or any causal mechanism.
- Do not run simulations or recovery campaigns on GitHub Actions.
- Do not use a clean worktree to overwrite the dirty profile/Tier-2a checkout.
- Do not collapse the lane split back to a single `START HERE` pointer.

## How to resume

From an authenticated terminal at the repository root:

```sh
claude "Read AGENTS.md, CLAUDE.md, and docs/dev-log/handover/2026-07-25-active-lane-split.md; rehydrate only the human-selected Claude lane. Leave the eta simulation lane in Codex untouched."
```

## Mission control

| Item | State | Owner / next leverage |
| --- | --- | --- |
| Release 0.6/M5 | separate release lane | Claude follows the 2026-07-23 rc.2 handover; no CRAN submission |
| Profile/Tier-2a | dirty primary checkout | Claude preserves and checkpoints it before any work |
| Eta simulation | Codex worktree, uncommitted | Codex only; no Claude mutation or compute |
| Design-103 | private `TECHNICAL_PARTIAL` | closed; no public/package promotion |
| This handover | PR #786 open | human review/merge only; do not auto-merge |
