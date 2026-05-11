# Task allocation: Claude × Codex × Maintainer

This document shows how Claude Code, Codex, and the maintainer (Ada)
divide work within and across the six phases of `ROADMAP.md`. It
exists so the maintainer can see at a glance who is supposed to do
what, and so both agents read the same rules before picking up a
task.

It is paired with:

- `AGENTS.md` "Multi-Agent Collaboration" (the standing rule set)
- `CLAUDE.md` "Collaboration Rhythm" (the propose / dispatch /
  implement pattern)
- `ROADMAP.md` "Collaboration Stops" (the four discussion
  checkpoints)
- `.agents/skills/shannon-coordination-audit/SKILL.md` (the
  coordination audit before dispatches)

The 2026-05-11 lesson behind this doc: Codex and Claude both shipped
the Shannon coordination role in parallel without coordinating
because no document said "this kind of task belongs to that team."
Writing the lanes down should prevent the repeat.

## Lane discipline (file-domain ownership)

| Lane | Default owner | Examples |
|---|---|---|
| **Implementation** | Codex | `R/`, `src/`, `tests/`, `vignettes/`, `NAMESPACE`, `_pkgdown.yml`, `.github/workflows/`, generated `man/*.Rd`, family code, parser, TMB engine |
| **Audit / design / prose** | Claude | `docs/dev-log/` (audits, proposals, plan files), PR descriptions / comments, design drafts in `docs/design/`, READMEs as drafts (before Codex applies them) |
| **Shared rule files** | **Either, but never both at once** | `AGENTS.md`, `CLAUDE.md`, `ROADMAP.md`, `CONTRIBUTING.md`, `docs/dev-log/decisions.md`, `docs/dev-log/check-log.md`, `docs/dev-log/after-task/`, `docs/design/`, `inst/COPYRIGHTS`, `DESCRIPTION` |

Rule: whichever agent the maintainer dispatches first owns the
shared-row edit for that cycle; the other agent reads after and
adds in a follow-up PR if needed. Shannon's first check is
"is this file being edited by another agent right now?"

Append-only logs (`decisions.md`, `check-log.md`, `NEWS.md`,
`after-task/`) are append-safe: both teams can extend them in
non-overlapping ranges, but Shannon flags chronological merge
order when more than one PR appends in the same cycle.

## Per-phase task allocation

The six phases come from `ROADMAP.md`. Each table column says who
owns that kind of task within the phase. "Parallel?" notes whether
the Claude row and the Codex row can run at the same time without
collision.

### Phase 1 -- Stabilise the reader path

Goal: long + wide example pairs in every Tier-1 article; legacy
helpers retired.

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Audit articles for legacy helpers + long+wide pairing | Article rewrites, one PR per article, in the order suggested by Claude's audit | Sequential within an article; Claude audits N+1 while Codex rewrites N |
| Draft the canonical long+wide example snippet | Apply the snippet to each article; replace legacy helpers per the audit's mapping | Same -- audit ahead, implementation behind |
| Provide line anchors + replacement-function table | Each PR includes after-task report; Rose pre-publish gate runs | Same |
| Review each Codex article PR (a Claude review pass, not Rose) | -- | Sequential per PR |

Codex implementation can be **parallel across two articles** if the
maintainer dispatches both explicitly, since each article is its
own file. Default: serial, to keep WIP=1.

### Phase 2 -- Finalise the public surface

Goal: drop legacy ghosts from `NAMESPACE`; the v0.2.0 export
surface matches `ROADMAP.md`.

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Priority 2 audit (drop / keep / internal classification) | Delete the drop list: edit `NAMESPACE`, delete `R/<func>.R`, delete `man/<func>.Rd`, delete tests | Sequential: Claude audit → maintainer decides → Codex implements |
| Cross-reference legacy helpers with article usage | Update `_pkgdown.yml` (remove deprecated section, no internal graveyard) | Same |
| Single `NEWS.md` sentence draft | Apply the `NEWS.md` sentence; run `devtools::document()` + `devtools::test()` | Codex does both NAMESPACE + NEWS in the same PR |

Phase 2 deletions depend on Phase 1 article rewrites completing
first (so no live article still uses the helpers being deleted).
Sequential between phases.

### Phase 3 -- Unify data shapes and weights

Goal: one shared weights helper across `gllvmTMB()` /
`gllvmTMB_wide()` / `traits()`; long-vs-wide produces the same
fitted target.

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Design doc for the weights contract (accepted shapes, errors, trait order, identifiers) | Implement `R/weights-shape.R` per Claude's contract | Sequential: design → maintainer approves → Codex implements |
| Specify paired-test contract (long vs wide byte-identical objective) | Refactor `gllvmTMB()` / `gllvmTMB_wide()` / `traits()` to call the helper | Codex changes alongside the helper |
| Rose pre-publish gate on the unified Rd wording | Write `tests/testthat/test-weights-unified.R` with the paired tests | Codex implements tests alongside Rd regeneration |
| Audit `man/*.Rd` consistency post-Codex | Run `devtools::document()` to regenerate Rd | Sequential per file |

Phase 3 can start as soon as Phase 1 lands. Phase 2 (surface
cleanup) and Phase 3 (weights contract) **could run in parallel**
because they touch different files -- but the maintainer should
dispatch carefully because both touch `NAMESPACE` if Phase 3
exports new helpers. Default: serial.

### Phase 4 -- Improve feedback time

Goal: 3-OS R-CMD-check stays the main gate, but Windows wall time
fits inside the 30-minute budget via slow-test gating.

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Audit `tests/testthat/` -- which files are smoke vs recovery vs identifiability? | Implement `RUN_SLOW_TESTS` env gating in selected test files | Sequential: Claude classifies → maintainer approves → Codex implements |
| Propose the CI strategy doc (lanes, schedule, dispatch triggers) | Update `.github/workflows/R-CMD-check.yaml` to set the env conditionally | Same |
| -- | Verify Windows post-gate wall time <= 30 min over two main pushes | Codex monitors |

### Phase 5 -- CRAN readiness

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Final `@examples` audit (which Rd files still need them) | Add the remaining `@examples` blocks | Sequential: audit → implement |
| Draft `cran-comments.md` | Update `DESCRIPTION` title / authors / DOIs as needed | **Parallel** -- different files |
| Prose / NEWS / README polish (drafts in dev-log/) | `inst/COPYRIGHTS` final pass; provenance check | **Parallel** -- different files |
| Run `pkgdown::check_pkgdown()` locally; report | Run `rcmdcheck::rcmdcheck(args = "--as-cran")` locally; report | **Parallel** -- different commands |

Phase 5 is where genuine parallelism happens most: many small
non-overlapping cleanups.

### Phase 6 -- Methods paper and extensions

| Claude tasks | Codex tasks | Parallel? |
|---|---|---|
| Functional-biogeography reproducibility article draft | New family additions (ZIP / ZINB / SPDE barrier) per `add-family` skill | **Parallel** -- different files |
| Two-U identifiability article draft | Two-U single-call API implementation per maintainer's design | Sequential within feature; parallel across features |
| Manuscript polish (prose) | New `add_barrier_mesh()` per the SPDE barrier path | **Parallel** |

## What runs in parallel today (real examples from 2026-05-11)

Today's session showed both successful parallelism and one
parallelism failure:

**Successful parallelism**: Claude opened PR #10 (Priority 2
audit), PR #11 (long+wide rule), PR #14 (Priority 1a proposal)
while Codex authored PR #8 (CI / site / team repair), PR #12
(roadmap rewrite), PR #15 (Shannon coordination). Different files,
different concerns, no collision. The maintainer dispatched and
reviewed at the natural boundaries.

**Parallelism failure**: Claude and Codex both started writing the
Shannon coordination role at the same time. The Edit tool
surfaced "File has been modified since read" because Codex landed
first. The duplicate effort was small (Claude's draft was thrown
away), but the lesson is that **shared rule files** (`AGENTS.md`,
`SKILL.md` definitions) **must not** be edited by both at once
without explicit dispatch.

## How the maintainer dispatches

Per-task one-liners at handoff points:

- *"Claude, audit Phase 2 export surface"* -- Claude alone owns it
- *"Codex, implement weights helper per Claude's design"* -- Codex
  alone owns it
- *"Both: Claude reviews PR #X while Codex starts PR #Y"* --
  parallel, but the maintainer named two different lanes

The maintainer is the dispatcher. Agents stand by between
dispatches. Each completed task ends with an after-task report in
the same commit. The next agent reads it before starting.

If an agent finds work in the Claude lane while a Codex task is
running, they may do the Claude work in parallel without an
explicit dispatch -- because the lanes are disjoint. The reverse
holds. This is what makes parallel work cheap.

## Recommended near-term rhythm

After the 2026-05-11 doc-PR sprint clears, the next 3-5 PRs should
look like:

| # | Lead | Phase | Task |
|---|---|---|---|
| next | Codex | 1 | Rewrite `vignettes/articles/morphometrics.Rmd` per PR #14 |
| +1 | Codex | 1 | Rewrite `vignettes/articles/covariance-correlation.Rmd` |
| +2 | Claude | 3 | Design doc for the weights contract (start while Codex is still on Phase 1) |
| +3 | Codex | 1 | Rewrite `vignettes/articles/joint-sdm.Rmd` |
| +4 | Codex | 2 | First surface-cleanup PR (legacy aliases bucket) once Phase 1 articles using the helpers are done |

This pattern shows genuine parallelism: Codex implements Phase 1
articles in sequence, Claude designs Phase 3 contract in parallel,
Phase 2 deletions wait until the article-rewrite phase clears.

## Shannon coordination audit before each dispatch

Before the maintainer dispatches the next task, a Shannon audit
(see `.agents/skills/shannon-coordination-audit/SKILL.md`) takes
~30 seconds and confirms:

- no agent has uncommitted work that conflicts with the new task;
- the file lane is clear (no other open PR is editing the same
  files);
- the previous task closed with an after-task report.

Skipping Shannon is what caused the 2026-05-11 duplicate Shannon
ship. Don't skip it.

## What this document is NOT

- Not a phase plan. `ROADMAP.md` owns that.
- Not a process rules document. `AGENTS.md` and `CLAUDE.md` own
  those.
- Not a status board. The active Claude plan
  (`~/.claude/plans/please-have-a-robust-elephant.md`) and the
  most-recent Shannon audit
  (`docs/dev-log/shannon-audits/`) cover current state.

This document is the **standing answer** to "who does what within
a phase". It updates only when a new phase is added or the lane
discipline changes (rare).
