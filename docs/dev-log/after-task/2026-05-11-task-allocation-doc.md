# After-Task: Task allocation design doc (Claude × Codex × Maintainer)

## Goal

Address the maintainer's stated gap: "I have no idea what you guys
are doing... I want you guys to work parallel... So far it's not
going in a way I imagined."

Produce a single shareable document that shows, for each of the six
ROADMAP.md phases, **who owns which kind of task**, **what runs in
parallel**, and **what must be sequential**. The document is a
standing reference for the maintainer and for both agents
(Claude Code, Codex) so neither has to guess.

This is a **Claude propose step** in the `CLAUDE.md` Collaboration
Rhythm. After maintainer review, this becomes the canonical task
allocation doc.

## Implemented

A new design document at
`docs/design/11-task-allocation.md` containing:

- a lane-discipline table (file-domain ownership: Claude lane,
  Codex lane, shared-but-never-both-at-once);
- six per-phase tables (Phase 1 reader path through Phase 6
  methods paper) showing Claude tasks, Codex tasks, and a
  "parallel?" column per row;
- a "today's parallel work successes and failures" section using
  2026-05-11 examples (the Shannon-shipped-twice issue is named
  directly);
- a maintainer-dispatch pattern;
- a recommended near-term rhythm (next 5 PRs);
- an explicit note that this doc is NOT a phase plan, NOT a
  status board, and NOT a rules document -- it complements the
  existing ones.

No package code, NAMESPACE, generated Rd, vignette source, or
pkgdown navigation changed.

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, generated Rd, or pkgdown navigation changed. Project
documentation only.

## Files Changed

- `docs/design/11-task-allocation.md` (new, ~200 lines)
- `docs/dev-log/after-task/2026-05-11-task-allocation-doc.md`
  (new, this file)

## Checks Run

- Confirmed the file fits the existing `docs/design/`
  numbering convention (`00-vision.md`, `10-after-task-protocol.md`,
  now `11-task-allocation.md`).
- Cross-referenced with `AGENTS.md`, `CLAUDE.md`, `ROADMAP.md`,
  and `CONTRIBUTING.md` -- the new doc explicitly says it does
  not duplicate those.
- Verified the lane-discipline rows in the new doc match the
  existing rules in `AGENTS.md` "Multi-Agent Collaboration" and
  `CLAUDE.md` "Collaboration Rhythm".

## Tests Of The Tests

- The "today's parallelism failure" section names a real event
  (the Shannon double-ship from 2026-05-11) rather than a
  hypothetical; a future reader can cross-check by reading
  `docs/dev-log/shannon-audits/2026-05-11-first-audit.md` and PR
  #15's description.
- The per-phase tables align row-by-row with the work descriptions
  in `ROADMAP.md` phases 1-6.

## Consistency Audit

- Lane discipline rows reference the same shared files that
  Shannon's `SKILL.md` flags as cross-team coordination targets
  (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `ROADMAP.md`,
  `decisions.md`, `check-log.md`, `after-task/`).
- The "How the maintainer dispatches" section matches the explicit
  one-liner pattern the maintainer asked for during the
  2026-05-11 session ("Codex, please pick up morphometrics.Rmd
  per PR #14 row 1 once #11 + #12 merge").
- The "Shannon coordination audit before each dispatch" section
  is consistent with `.agents/skills/shannon-coordination-audit/SKILL.md`
  use cases.

## What Did Not Go Smoothly

Nothing for this doc itself. The doc is a response to a real
parallelism failure today (Shannon double-ship); writing it down
is the corrective.

## Team Learning

- Lane discipline is the simplest answer to "parallel without
  collision". Two agents in disjoint file lanes don't conflict.
  Two agents in the same lane MUST be sequential.
- The shared-rule-files row is the dangerous one. Both teams
  edited `AGENTS.md` / Shannon `SKILL.md` today; only one survives
  per cycle. Future shared-rule edits should be dispatched
  explicitly: "Codex, edit AGENTS.md to add Shannon" OR "Claude,
  draft AGENTS.md Shannon paragraph". Not both.
- Per-phase tables answer the maintainer's "I have no idea what
  you guys are doing" because the table makes the next task
  visible at a glance.

## Known Limitations

- This document captures the current six-phase plan. If a new
  phase is added or the lane discipline is refined, this file
  must be updated. It is intended to be stable -- not
  continuously edited -- so future updates should land via their
  own bounded PR with a clear after-task report.
- The "Recommended near-term rhythm" table at the bottom is
  illustrative of what the next 3-5 PRs should look like. It is
  not a binding schedule; the maintainer dispatches per-task.

## Next Actions

- Maintainer reviews `docs/design/11-task-allocation.md` and the
  per-phase tables. Adjust ownership rows if the proposed
  split is not what is wanted.
- After approval, this doc becomes the canonical task-allocation
  reference. Both agents read it (it is in the `docs/design/`
  read path).
- Codex can then proceed with the morphometrics.Rmd rewrite per
  PR #14 row 1 knowing the doc is the standing answer to "what
  am I expected to do".
