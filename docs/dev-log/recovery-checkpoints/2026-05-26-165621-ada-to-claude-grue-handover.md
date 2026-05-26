# Handover Checkpoint: Ada/Codex to Claude Grue

**Date:** 2026-05-26 16:56 MDT  
**Repository:** `/Users/z3437171/Dropbox/Github Local/gllvmTMB`  
**Current branch:** `main`  
**Local status at handover:** clean; `main` equals `origin/main` at
`58b6b56` (`Phase 56.4 merge close-out: #298 cross-reference +
coord-board sync (#299)`).  
**Spawned subagents:** none.

This is a clean handover for Claude Grue to carry the GLM / GLLVM /
TMB-facing `gllvmTMB` work for the next couple of days. The goal is
not merely to keep moving, but to keep the project easy to resume:
small PRs, exact evidence, no overclaiming, and repo-visible handoff
notes.

## First Commands For Claude Grue

Run these before editing:

```sh
git status --short --branch
git fetch --prune
git pull --ff-only
gh pr list --repo itchyshin/gllvmTMB --state open \
  --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url
gh run list --repo itchyshin/gllvmTMB --limit 12 \
  --json databaseId,workflowName,status,conclusion,event,headBranch,headSha,url
sed -n '1,180p' docs/dev-log/coordination-board.md
tail -n 220 docs/dev-log/check-log.md
```

For any edit to shared coordination/design files, also run the
pre-edit lane check from `AGENTS.md`:

```sh
gh pr list --repo itchyshin/gllvmTMB --state open
git log --all --oneline --since="6 hours ago"
```

## Current Git / PR / CI State

Open PR census at handover:

```text
[]
```

Recent merged sequence:

```text
58b6b56 Phase 56.4 merge close-out: #298 cross-reference + coord-board sync (#299)
dd3b2be Phase 56.4: activate phylo_unique recovery (#298)
a16dbec Phase 56.3 merge close-out: #295 cross-reference + coord-board sync (#297)
6026710 Phase 56.3: wire phylo_unique augmented parser (#295)
e443b6a #287 audit-only tidy: pre-spec defaults note + Codex sequencing cross-refs (#296)
1108d3b Phase 56.2 merge close-out: #293 cross-reference + coord-board sync (#294)
72f67de Phase 56.2: classify n_traits audit sites (#293)
e4d67aa Phase 56.1 merge close-out: #289 cross-reference + coord-board sync (#292)
3133863 Phase 56.1: add dormant phylo augmented TMB stubs (#289)
6f413cf A6 prep memo: articles inventory + NEWS pre-draft + register row pre-draft (#291)
```

Live validation evidence at handover:

- PR #298 (`Phase 56.4: activate phylo_unique recovery`) merged at
  `dd3b2be` on 2026-05-26 22:34 UTC after 3-OS PR
  `R-CMD-check` passed. Run: `26477429036`.
- PR #299 (`Phase 56.4 merge close-out`) merged at `58b6b56` on
  2026-05-26 22:45 UTC.
- Post-#299 main `R-CMD-check` passed on `58b6b56`. Run:
  `26479492838`.
- Post-#299 pkgdown passed on `58b6b56`. Run: `26479513474`.

One earlier post-#298 main run on `dd3b2be` was cancelled after #299
advanced `main`; do not treat that cancellation as a failing signal.

## What Just Landed

Phase 56.4 activated the first real augmented-LHS recovery test for
the `phylo_unique` Gaussian anchor:

```r
traits(t1, t2, t3) ~ 1 + phylo_unique(1 + x | species)
value ~ 0 + trait + phylo_unique(0 + trait + (0 + trait):x | species)
```

The activated test lives in:

- `tests/testthat/test-phylo-unique-slope-gaussian.R`

It checks:

- wide versus long byte identity;
- Gaussian recovery for the block-local 2 x 2 `Sigma_b`;
- the forced `n_lhs_cols = 1L` negative test that exercises the TMB
  shape guard.

Internal wording was deliberately conservative:

- `docs/design/01-formula-grammar.md` says Phase 56.4 evidence exists
  but keeps the public status at `claimed`;
- `CLAUDE.md` keeps validation-debt movement, NEWS, articles,
  user-facing advertising, and deprecation wording parked until
  Phase 56.6.

## Next Best Lane

The coordination board currently queues **Phase 56.5: anchor-adjacent
fan-out by backend/risk**, starting with the smallest delta from the
green anchor:

```text
phylo_unique(..., vcv = A_user)
```

Recommended first PR:

- Branch: `agent/phase56-5-relmat-unique-slope-2026-05-26` or a
  similarly explicit Claude branch.
- Primary file: `tests/testthat/test-relmat-unique-slope-gaussian.R`.
- Goal: remove the `skip_until_stage3()` gate for the relmat /
  user-supplied-A analogue and attach:
  - wide-long byte-identity checks;
  - Gaussian recovery checks;
  - a forced mismatch / shape-guard negative test;
  - honest check-log and after-task evidence.

This is the right first 56.5 cell because it should reuse the same
anchor `b_phy_aug` machinery rather than introducing animal, spatial,
latent, indep, or dep-specific semantics yet.

Do not batch all remaining cells. The current fan-out principle is
backend/risk grouping, not one enormous 16-cell PR:

1. `phylo_unique(..., vcv = A_user)` first.
2. `animal_unique` after its bar-form sugar routes to the same
   augmented path.
3. `spatial_*` only after SPDE augmented plumbing is explicit.
4. `*_latent`, `*_indep`, and `*_dep` only after their distinct
   `Sigma_b` / map semantics are designed and tested.

The coordination board says 15 skeleton tests remain
`skip_until_stage3()`-gated until their backend lands. Keep that
honest. Do not remove a skip just to show progress unless the test
has real evidence behind it.

## Phase 56.5 Acceptance Standard

For each activated cell, aim for the same discipline as #298:

- one small PR;
- one cell or one tightly related backend group;
- after-task report in the branch;
- `docs/dev-log/check-log.md` entry with exact commands;
- focused local tests first;
- no validation-debt promotion until the planned Phase 56.6 gate;
- Rose pre-publish if user-facing or cross-file wording changes;
- Shannon coordination pass before and after merge.

Minimum validation shape for the next relmat cell:

```sh
Rscript --vanilla -e 'devtools::test(filter = "relmat-unique-slope-gaussian")'
Rscript --vanilla -e 'devtools::test(filter = "relmat-unique-slope-gaussian|phylo-unique-slope-gaussian|phase56-3-phylo-unique-parser")'
git diff --check
```

Add broader tests only if the implementation touches shared parser,
TMB-data, or engine plumbing. If a recovery fit is seed-sensitive,
document the rejected seed and the accepted seed as #298 did; do not
silently widen tolerances to fit a convenient run.

## Boundaries / Do Not Do Yet

- Do not promote augmented structural-slope support in NEWS, README,
  articles, roxygen, or the validation-debt register before Phase
  56.6.
- Do not deprecate `phylo_slope()` / `animal_slope()` yet.
- Do not reopen the paused `codex/morphometrics-long-wide` branch as
  part of Phase 56.
- Do not launch A6 public-surface work from #291 until Phase 56.5
  closes and Ada explicitly allows the Phase 56.6 public claim gate.
- Do not dispatch r200 or broad validation-factory jobs without a
  refreshed maintainer gate.
- Do not touch `src/gllvmTMB.cpp` unless the next slice genuinely
  requires likelihood/engine changes; if it does, invoke the
  TMB-likelihood review path and update design docs.

## What Claude Grue Should Aim For

The best version of this handoff is not "Claude keeps Codex busy."
It is: Claude leaves the repo easier for the next agent than it was
found.

Aim for:

- **Evidence before optimism.** Every capability claim points to a
  test, CI run, after-task report, or design memo.
- **Implemented / partial / planned kept separate.** This matters
  more than speed in `gllvmTMB` because stale public claims have hurt
  the package before.
- **One active PR at a time.** The repo's CI history shows that WIP
  fan-out creates avoidable cancel cascades.
- **Long and wide examples paired when public docs are touched.**
  User-facing examples should show both the canonical long
  `gllvmTMB(value ~ ..., data = df_long)` shape and the wide
  `gllvmTMB(traits(...) ~ ..., data = df_wide)` shape unless the file
  explicitly says why wide form is unsupported.
- **Small, reviewable after-task trails.** A future agent should be
  able to answer "what changed, what was run, what is still planned?"
  from the repo, not from private chat.
- **Respect for both teams.** Codex has useful recovery and evidence
  discipline; Claude/Shannon has strong coordination and
  pre-publish hygiene. Use both.

## Suggested Claude Team Message

```text
Claude Grue / Shannon:

Codex has finished the Phase 56.4 lane. #298 merged, #299 close-out
merged, main R-CMD-check passed, and pkgdown passed on main at
58b6b56. The repo is clean, no open PRs.

Please pick up Phase 56.5 from the repo-visible handover:
docs/dev-log/recovery-checkpoints/2026-05-26-165621-ada-to-claude-grue-handover.md

First target: relmat/user-supplied-A analogue of the green anchor,
`phylo_unique(..., vcv = A_user)`, likely in
tests/testthat/test-relmat-unique-slope-gaussian.R. Keep it one
small PR, test-backed, with check-log + after-task, and do not move
validation-debt / NEWS / articles until Phase 56.6.

Please start with the first-command block in the handover and refresh
live PR/CI state before editing.
```

## Safest Next Action

Claude Grue should refresh the repo, open one Phase 56.5 relmat PR,
and keep all broader public-surface work parked until the relmat cell
is either merged cleanly or deliberately deferred with evidence.

## Blocking Question

None for handover. The next maintainer decision is only about pace:
whether Claude should take just the first relmat 56.5 cell or continue
through the rest of the backend/risk fan-out after each PR lands
green.
