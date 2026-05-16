---
name: stop-checkpoint
description: Force a maintainer checkpoint between artefact (audit table / draft / honest ledger / design-doc revision) and action (commit / merge / push / next step). Shannon authors; Ada invokes. Phase 0A 2026-05-16 NEW skill — closes the autopilot failure mode demonstrated when steps 5/6/7 were committed in sequence without surfacing for review.
---

# Stop-Checkpoint

This skill exists because the 2026-05-16 Phase 0A session produced
three honest design docs (testing strategy, extractors contract,
validation-debt register) and committed all three to the branch
**without surfacing them for maintainer review between commits**.
The maintainer corrected the pattern: *"I do want to check all these
different documents you're writing as we have been doing so far."*
This skill is the operational discipline that prevents the same
failure mode from recurring.

## When to Invoke

Invoke **before** producing any artefact that the maintainer should
review *before* a commit / merge / push, or before moving to the
next dependent step. Triggers include:

- a validation-debt register update with new `covered` / `partial`
  / `blocked` rows that change the package's honest scope;
- a decisions log entry ratifying a scope or grammar change;
- an after-phase report (the close gate for any phase boundary);
- a design-doc revision that touches public API, formula grammar,
  family list, or extractor contract;
- a rule revision in `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  `docs/design/10-after-task-protocol.md`, or any skill file;
- a sequence of related PRs / commits that depends on the
  maintainer accepting an earlier link in the chain;
- a `/loop` autopilot run that has shipped 2+ artefact commits
  without an intervening review touchpoint.

If the artefact already exists (because the autopilot has shipped
it), the skill recommends rollback-or-surface: do NOT silently
proceed to the next dependent step; surface the artefact NOW.

## The Discipline

**Artefact → checkpoint → action.** Never artefact → action directly.

The checkpoint has three concrete moves:

1. **Surface clickable file links + concise summary** of what
   the artefact contains and what it implies. Bare paths are
   not enough — paste full GitHub blob URLs that open in the
   maintainer's browser.
2. **Name the explicit decision** the maintainer is being asked
   to make ("OK to proceed to Step N?", "Approve the 102-row
   honest tally before AGENTS.md edits?", "Confirm Option C
   reading before propagation to 04 / 35?"). Don't just say
   "let me know what you think."
3. **Wait for an unambiguous reply** before the action. If
   the maintainer says "keep moving" or "yes A and B" or
   another approval form, the action is authorised. If the
   maintainer asks a clarifying question or surfaces a
   contradiction, treat that as a hold, not as approval.

## Required Output Format

When invoked, the skill produces a chat message with **exactly
four** components:

```
1. Title line: "STOP-CHECKPOINT: <one-line summary of artefact>".
2. Artefact links: full GitHub URLs (one per file), with line
   counts and net-change stats.
3. Concise summary: 2-5 bullets per artefact naming the key
   claims, the implied downstream actions, and any surprises.
4. Explicit question: "OK to proceed to <next action>?", or
   the specific binary decision the maintainer should make.
```

Optionally append: a brief reminder of which AGENTS.md rule or
design-doc principle the checkpoint enforces (Rule #10
convention-cascade, validation-debt scope-boundary, etc.).

## Anti-patterns the Skill Prevents

1. **Silent self-merge of artefact PRs.** Even when CI is green
   and the PR is "small", an artefact-producing PR triggers a
   checkpoint. Self-merge is reserved for truly mechanical
   non-artefact PRs (CI tweaks, dev-log appends following an
   already-approved decision, etc.).
2. **Batching multiple unrelated changes past a single
   checkpoint moment.** If a session produces three honest
   artefacts in sequence, each gets its own surface — not one
   batch surface at the end.
3. **Auto-pilot reasoning from "the user said keep moving"** to
   "every subsequent action is approved". `keep moving` is an
   approval to take the *next* step; it is not a license to
   skip future checkpoints.
4. **Treating a clarifying question as approval.** When the
   maintainer asks "what does X mean here?" mid-stream, that's
   a hold, not approval.
5. **Surfacing bare paths instead of clickable URLs.** The
   maintainer cannot review files they can't open. Always
   paste full GitHub blob URLs (and raw fallbacks if needed).

## Anti-patterns the Skill Does NOT Prevent

- It does not slow down truly mechanical work (typo fixes, CI
  cadence, dev-log appends following already-ratified decisions).
- It does not require checkpoints inside a single artefact's
  authoring loop (the maintainer doesn't want to review every
  edit — just the artefact when it's complete).
- It does not replace `rose-pre-publish-audit` (content audit)
  or `shannon-coordination-audit` (cross-team coordination). It
  sits between artefact production and the next action.

## Worked Example (2026-05-16, the original trigger)

During Phase 0A, the autopilot pattern was:

> Step 4 done, commit, push → Step 5 done, commit, push → Step 6
> done, commit, push → Step 7 (validation-debt register, the
> honest ledger) done, commit, push → started Step 8 (AGENTS.md
> edits)

The maintainer caught it before Step 8 landed: *"I do want to
check all these different documents you're writing as we have
been doing so far. Do you remember this?"*

Under this skill, the correct pattern would have been:

> Step 4 done → STOP-CHECKPOINT surface → maintainer approves
> → Step 5 done → STOP-CHECKPOINT surface → maintainer approves
> → ... and so on.

Each artefact is a checkpoint moment. The plan called for an
explicit checkpoint after Step 7 (the register) — the skill
makes that explicit, recurring, and unavoidable.

## Cross-References

- `AGENTS.md` Standing Review Roles — Shannon authors this
  skill; Ada invokes it.
- `docs/design/10-after-task-protocol.md` — the after-task
  protocol consumes this skill's checkpoint moments as
  required-section content.
- `.agents/skills/after-task-audit/SKILL.md` — the after-task
  audit runs AFTER the checkpoint, on the artefact the
  maintainer just approved.
- `.agents/skills/rose-pre-publish-audit/SKILL.md` — the
  pre-publish audit can run BEFORE or AFTER the checkpoint
  depending on whether content is being authored or finalised.
