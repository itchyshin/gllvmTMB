# GOAL — <one sentence: what "done" looks like>

**IMMUTABLE for this run.** Re-read this file at the top of EVERY arc, before anything else.

## Definition of done
- [ ] <the observable end state, not the activity>

## Invariants (never violate, even to finish faster)
- Never push, merge, or publish — those are HUMAN GATES. Land work on this branch only.
- Verification means reading the LOG and inspecting the ARTEFACT, never the exit code.
- A narrow or negative search is not proof. "No X exists" usually means the query missed X.
- Destructive or irreversible ⇒ STOP and surface, even if it feels urgent.

## Pre-authorisation (copied from approved ultra-plan)
- Routine scoped edits, local commands, tests, builds, checkpoints, local commits, and listed checks: CONTINUE.
- Optional remote authority: <none | push named branch | create named draft PR; never merge or release>.
- Must stop: merge/release/public message or claim; credentials/security changes; destructive work outside this worktree; new compute/cost beyond the estimate; scope-changing evidence.

## Out of scope (the fence — do NOT drift here)
- <...>
