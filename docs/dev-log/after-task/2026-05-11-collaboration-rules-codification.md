# After-Task: Codify six agent-collaboration improvements

## Goal

Codify five working-rule improvements (plus the after-task-at-branch-
start discipline already in this commit) that surfaced from the
2026-05-11 doc-PR sprint and end-of-day maintainer reflection. The
maintainer asked for concrete rule text in chat for review before
landing.

## Implemented

Six rules landed in their natural files:

1. **Merge authority default** -- `CLAUDE.md` "Collaboration
   Rhythm" / new "Merge authority" subsection. Agents self-merge
   low-risk PRs when CI is green; ask maintainer for the
   `ROADMAP.md` Discussion Checkpoints (deletions, API, grammar,
   likelihood / TMB / family, broad article rewrites).
2. **Integrate before adding** -- `CLAUDE.md` new subsection.
   Edit existing sections inline before adding new ones; the
   reactive-edit anti-pattern from earlier today.
3. **Agent-to-agent handoffs go in the repo** -- `CLAUDE.md` new
   subsection. PR comments or directed `check-log.md` lines, not
   maintainer relay.
4. **Surface review asks explicitly** -- `CLAUDE.md` new
   subsection. When opening a PR, follow up in chat with a
   specific list of maintainer review items.
5. **Pre-edit lane check on shared rule files** -- `AGENTS.md`
   "Multi-Agent Collaboration". 30-second check before editing
   any of the documentation-triangle files; explicitly named the
   2026-05-11 Shannon double-ship as the lesson.
6. **After-task report at branch start** -- `CONTRIBUTING.md`
   "Definition of Done". Create the after-task skeleton at branch
   creation, not as a post-PR afterthought.

Combined `decisions.md` entry summarising all six rules.

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, generated Rd, or pkgdown navigation changed.

## Files Changed

- `CLAUDE.md` (M -- 4 new subsections under "Collaboration Rhythm")
- `AGENTS.md` (M -- pre-edit lane check paragraph)
- `CONTRIBUTING.md` (M -- after-task at branch start paragraph)
- `docs/dev-log/decisions.md` (M -- combined entry)
- `docs/dev-log/after-task/2026-05-11-collaboration-rules-codification.md`
  (new -- this file)

## Checks Run

- The pre-edit lane check passed at commit time: no other open PR
  was editing any of `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`,
  `decisions.md`. Codex's in-flight morphometrics.Rmd work is on
  a different file.
- Each rule's wording aligns with the chat-drafted text the
  maintainer asked to see before landing.
- The merge-authority rule's "high-risk" set is verified against
  `ROADMAP.md` "Discussion Checkpoints" -- both lists name the
  same five categories.

## Tests Of The Tests

- The merge-authority "high-risk" boundary is the same set the
  `ROADMAP.md` "Collaboration Stops" / "Discussion Checkpoints"
  section uses. A future agent reading either file gets the same
  bright line, with the merge rule mirroring the discussion rule.
- The pre-edit lane check is callable as `gh pr list --state open
  && git log --all --oneline --since="6 hours ago"` -- both
  one-liners, no special tooling needed.

## Consistency Audit

- The four `CLAUDE.md` rules sit under "Collaboration Rhythm",
  which is the right home (process / how-we-work) rather than
  "Project Identity" or "Syntax Rules to Preserve".
- The pre-edit lane check sits under `AGENTS.md` "Multi-Agent
  Collaboration", which is the standing-rule home for agent-to-
  agent behaviour.
- The after-task at branch start sits under `CONTRIBUTING.md`
  "Definition of Done", which is the right home for completion
  criteria.
- The `decisions.md` entry follows the existing date-stamped
  one-paragraph format used by today's earlier entries.

## What Did Not Go Smoothly

- Codex's `vignettes/articles/morphometrics.Rmd` work-in-progress
  is uncommitted in the working tree throughout this PR. The
  pre-edit lane check correctly identified that none of my edits
  collide with that file. Codex's work is preserved untouched.
- The handoff doc (`docs/dev-log/claude-group-handoff-2026-05-11.md`)
  has also been expanded by Codex with new sections (Current
  Priorities, Role Dispatch, Required Checks By Change Type,
  Pre-Publish Rose Sweep, Discussion Checkpoints). My earlier
  Read-First-only update via PR #21 was a subset; Codex's version
  is more comprehensive. Per the non-revert rule I am not touching
  it. Claude-Codex parallel doc work is now happening more
  fluidly.

## Team Learning

- The maintainer-as-relay role is shrinking. Today the maintainer
  was the explicit dispatcher and message bus for many
  cross-agent handoffs; codifying the four CLAUDE.md rules moves
  more of that traffic into the repo, where both agents already
  read.
- A "high-risk vs low-risk" merge boundary that mirrors existing
  Discussion Checkpoints means agents do not need a second mental
  model -- one set of rules, two consequences (discussion +
  maintainer merge for high-risk; self-merge for low-risk).
- After-task report at branch start (vs. PR close) is a small
  structural change with a large discipline payoff. Worth
  watching whether the next 5-10 PRs all include it without
  forgetting.

## Known Limitations

- The rules are project-local to `gllvmTMB`. If Codex or Claude
  Code start work in a different repository, they will not have
  these rules unless transplanted. That is fine for now -- the
  rules are the result of this project's coordination
  experiences.
- The merge-authority "low-risk" definition is enumerative
  (documentation, dev-log, audits, after-task, design docs,
  CI workflow tweaks, asset additions, individual article
  rewrites). Borderline cases will surface; the agent should
  default to "ask the maintainer" when uncertain.

## Next Actions

- Codex continues `morphometrics.Rmd` rewrite. On the next branch
  Codex creates, the after-task report at branch start should
  appear naturally as the first commit per the new
  `CONTRIBUTING.md` rule.
- Future PRs from either agent should be openable with no chat
  ambiguity about what the maintainer needs to check, because the
  agent will explicitly surface it (per the new `CLAUDE.md`
  "Surface review asks explicitly" rule).
- Watch the next 3 Codex/Claude PRs to confirm:
  (a) after-task at branch start;
  (b) self-merge for low-risk only;
  (c) PR-comment handoff between agents;
  (d) chat surface of review items.
  Any miss feeds back into Shannon's next audit.
