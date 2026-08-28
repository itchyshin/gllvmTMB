# GOAL — exact two-cell `engine = "julia"` bridge requalification

**IMMUTABLE for this run.** Re-read this file at the top of EVERY arc, before anything else.

## Definition of done
- [ ] A reproducible, independently reviewed bridge verdict exists for exactly four planned fit records: Gaussian TMB, Gaussian Julia, Poisson TMB, and Poisson Julia.
- [ ] Tested source is pinned to gllvmTMB `86e95fff170767b23980152b7d6fce9bb2207718` and GLLVM.jl `00a2d7b7024b21f55cb124bee2d2e4cf8a546b40`, or a terminal `NO_RUN_SOURCE_CONTRACT` receipt proves why fitting could not start.
- [ ] Every planned record ends as passed, failed, unavailable, interrupted, or not-started-after-abort; the denominator remains four with no replacement or retuning.
- [ ] Only rotation-invariant covariance/correlation and fitted means support cross-engine conclusions.
- [ ] Totoro compute is one-threaded and stops at 30 minutes.
- [ ] Independent method, scope, and provenance review is retained; closeout includes after-task, plan-vs-actual, local commit, final re-verification, and lease release.

## Invariants (never violate, even to finish faster)
- Never push, merge, or publish — those are HUMAN GATES. Land work on this branch only.
- Verification means reading the LOG and inspecting the ARTEFACT, never the exit code.
- A narrow or negative search is not proof. "No X exists" usually means the query missed X.
- Destructive or irreversible ⇒ STOP and surface, even if it feels urgent.

## Pre-authorisation (copied from approved ultra-plan)
- Routine scoped edits, local commands, tests, builds, checkpoints, local commits, the approved Totoro deployment, and exactly four planned fit records: CONTINUE.
- Optional remote authority: Totoro deployment and execution only; no push, PR, merge, release, or public message.
- Must stop: merge/release/public message or claim; credentials/security changes; destructive work outside this worktree; new compute/cost beyond the estimate; scope-changing evidence.

## Out of scope (the fence — do NOT drift here)
- Any edit, branch, lease, commit, or push in GLLVM.jl.
- New families; X/X_lv; masks; missing data; offsets; mixed families; structured covariance; Psi; intervals; simulation recovery; performance claims; API changes; CI; public promotion.
- Threshold changes, replacement fits, optimizer retuning, or defect repair discovered by this gate.
