# After-Task: Update handoff doc Read-First list

## Goal

Address Shannon's second-audit `WARN-LITE`: the
`docs/dev-log/claude-group-handoff-2026-05-11.md` "Read First"
list pre-dates several important new docs landed during the
2026-05-11 doc-PR sprint and does not reference them. A new
agent joining the work would miss them in their read path.

Files added to the Read-First list:

- `docs/design/11-task-allocation.md` (lane discipline; landed in
  PR #18)
- `.agents/skills/shannon-coordination-audit/SKILL.md` (Shannon
  role; landed in PR #15)
- The `docs/dev-log/shannon-audits/` subdirectory (audits landed
  in PR #17 and PR #20)

Also bumped `ROADMAP.md` higher in the list (third position) since
it is the canonical roadmap and should be read before the more
specific design docs.

## Implemented

A single edit to the "Read First" section of
`docs/dev-log/claude-group-handoff-2026-05-11.md`. The list grew
from 8 to 11 entries, in a slightly reordered sequence:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `ROADMAP.md`
4. `docs/design/11-task-allocation.md`
5. `.agents/skills/rose-pre-publish-audit/SKILL.md`
6. `.agents/skills/shannon-coordination-audit/SKILL.md`
7. `CONTRIBUTING.md`
8. `docs/dev-log/after-task/2026-05-11-ci-site-team-repair.md`
9. Most-recent Shannon audit in `docs/dev-log/shannon-audits/`
10. `docs/dev-log/check-log.md`
11. `docs/dev-log/decisions.md`

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, generated Rd, or pkgdown navigation changed.
Documentation-only handoff update.

## Files Changed

- `docs/dev-log/claude-group-handoff-2026-05-11.md` (M)
- `docs/dev-log/after-task/2026-05-11-handoff-readfirst-update.md`
  (new -- this file)

## Checks Run

Inspection only -- the change is to a markdown handoff doc, no R
code or workflow touched.

## Tests Of The Tests

A new agent reading the handoff "Read First" list will now see
the task-allocation doc and the Shannon SKILL.md without having
to discover them by browsing. Verifiable by reading the diff and
the final state of the Read-First section.

## Consistency Audit

- The new Read-First list includes every standing rule doc
  referenced by `AGENTS.md` and `CLAUDE.md` (Rose, Shannon,
  task allocation, after-task protocol).
- The reordering puts the canonical-roadmap doc (`ROADMAP.md`)
  ahead of the more specific design docs, consistent with the
  general-to-specific reading principle in `AGENTS.md` writing
  style.

## What Did Not Go Smoothly

While preparing this edit I noticed that the working tree shows
`vignettes/articles/morphometrics.Rmd` as modified -- Codex has
**started** the Phase 1a row-1 rewrite but has not committed
yet. My handoff edit touches a different file
(`docs/dev-log/claude-group-handoff-2026-05-11.md`) so there is
no collision; Codex's uncommitted work is preserved untouched in
the working tree. This is a clean test of the lane discipline
codified in `docs/design/11-task-allocation.md`: parallel work in
disjoint file domains, no collision.

## Team Learning

- Shannon's `WARN-LITE` finding moved cleanly into a small
  closing PR. The "every flagged item gets a small follow-up PR
  before moving on" pattern works.
- Each new standing-doc landing (Shannon, task allocation)
  should ship with a handoff-doc update in the same commit OR
  the very next PR. Not retrofit.

## Known Limitations

This handoff doc is dated 2026-05-11. Future agents joining the
work after the date should expect the next handoff doc to
supersede this one. The Read-First list pattern itself is the
durable artefact, not the specific date.

## Next Actions

- Codex continues the morphometrics.Rmd rewrite when ready.
  Their work is uncommitted in the working tree; my edit does
  not touch their file.
- The remaining six collaboration-improvement rules drafted
  earlier in chat (merge authority, integrate-first,
  agent-to-agent handoffs, surface-to-maintainer, pre-edit lane
  check, after-task at branch start) await the maintainer's
  text-check before landing in a codification PR.
