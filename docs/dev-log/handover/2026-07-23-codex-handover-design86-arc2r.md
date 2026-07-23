# Session Handoff: Design 86 Arc 2R — Gate-2 re-admission packet

**To:** Codex
**From:** Codex
**Date:** 2026-07-23
**Status:** STOPPED — maintainer review required; no smoke authority.

## Critical Context

You are Codex, picking up an **approval packet**, not a live Gate-2 experiment.
The historical Gate-2 smoke is red: the information screen passed, but all four
starts failed the frozen `max_abs_gradient < 1e-4` rule. There is no admitted
winner or interval. Do not invoke either Gate-2 runner, create a campaign
artifact, compile, select Totoro/DRAC, or begin Gate 3/4 without a new,
explicit maintainer-signed Gate-2R amendment.

The governing packet is `docs/design/86-gate2r-readmission-brief.md`; its
status is DRAFT, not approval. The immutable fixture is
`docs/design/86-eva-gate2-anchor-parameters.json` (SHA-256
`fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6`), and
its seed-array receipt is
`9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a`.

## Goals and Plan

Design 86 remains a private EVA feasibility programme. Arc 2R repaired the
dev-only fence and made a later numerical decision auditable; it did **not**
change the estimator, DGP, starts, controls, thresholds, public API, or shipped
engine. The only next plan is maintainer review of the packet. If approved,
the amendment must first lock the new fixture/version, exact source hashes,
clean-tree rule, stage-receipt schema, and a narrowly specified one-seed smoke.

## What Was Accomplished

- Restored `R/eva-proto.R` byte-for-byte to sealed Arc-1 commit `3b479354`.
- Moved Gate-2 helpers into the two private `dev/` runners and added a
  controlled no-DGP optimiser harness.
- Enforced the frozen fixture and seed receipts before input construction;
  receipts encode unavailable values as JSON `null` and capture a clean-source
  snapshot before outputs can dirty the tree.
- Added truthful stage states (`attempted`, `error`,
  `skipped_after_failure`) without changing the frozen optimiser schedule.
- Added EVA and live-Laplace provenance receipts with the correct source paths.
- Passed focused checks: input/provenance tests **33 PASS**, harness tests
  **42 PASS**; after-task structure check and source guards pass.
- Fresh independent math/provenance, numerical, and scope lenses returned
  **DONE for the packet only**. They did not authorise a smoke.

## Current Working State

- **Working:** branch is clean at `65973ada43a3e2869db6cda6f0bc807b5f699663`.
- **In progress:** none. This Arc must stop here.
- **Blocked:** fresh smoke requires explicit maintainer sign-off of a versioned
  Gate-2R amendment. The existing fixture and red-smoke evidence remain
  historical and immutable.

## Key Decisions and Rationale

- Private Gate-2 support stays in `dev/`; `R/` is installed package source
  even when unexported. Do not relax this fence.
- Provenance is captured immediately after a clean-tree guard, before input or
  manifest output. A later output must not invalidate the run's preflight
  provenance snapshot.
- A failed optimiser stage is recorded as `error`; later unrun stages are
  explicitly `skipped_after_failure`. Do not interpret them as attempted.
- The frozen optimiser, truth, DGP, health/acceptance rules, and the historical
  red result are deliberately untouched. Any proposed revision belongs in the
  future versioned amendment, not in code or a smoke.

## Files Created / Modified

Relative to Arc-2 stop `3ab3b3a9`:

| Path | State / purpose |
| --- | --- |
| `R/eva-proto.R` | Restored to Arc-1 state; no Gate-2 helper remains. |
| `dev/design86-gate2-eva-runner.R` | Private fixture/input/provenance and stage receipt. |
| `dev/design86-gate2-laplace-runner.R` | Private unchanged-live comparator provenance. |
| `dev/design86-optimizer-diagnostic-harness.R` | Controlled no-DGP diagnostic. |
| `tests/testthat/test-design86-gate2-input-contract.R` | Fixture, provenance, stage, and replay contract tests. |
| `tests/testthat/test-design86-optimizer-diagnostic-harness.R` | Convergent/non-stationary trace tests. |
| `docs/design/86-gate2r-readmission-brief.md` | Draft amendment/sign-off packet. |
| `docs/dev-log/check-log.md` | Arc 2R check receipt. |
| `docs/dev-log/after-task/2026-07-23-design86-arc2r-gate2-readmission.md` | Complete closeout evidence. |
| `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc2r.md` | This handoff. |

No `NAMESPACE`, `DESCRIPTION`, `NEWS`, `man/`, vignette, public R surface,
or `src/gllvmTMB.cpp` changed.

## Landing State

`/Users/z3437171/shinichi-brain/tools/handoff_gate.sh` reports this branch as
unpushed. The work is deliberately **CARRIED-OVER** as a clean local commit:
the maintainer did not authorise a push/PR, and this arc must not gain external
state while it is awaiting review.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/design86-arc2r-20260723` at `65973ada` | yes | no | none | CARRIED-OVER — local review packet; do not push without maintainer direction. |

## Next Immediate Steps

1. Obtain a maintainer decision on
   `docs/design/86-gate2r-readmission-brief.md`; a new smoke is not implied by
   the packet.
2. If sign-off is received, create a **new versioned amendment/fixture** first;
   do not edit the historical fixture or smoke artifacts.
3. Re-run the listed guards and have Rose review the exact amendment before any
   one-seed smoke authority is exercised.
4. Only the explicitly authorised later Arc may run a smoke. A green smoke
   would be a prerequisite to reconsidering bounded Totoro use, not authority
   for Gate 3/4.

## Blockers / Open Questions

- Does the maintainer approve a new fixture version and the stated one-seed
  smoke scope? Until yes, execution is blocked.
- If a future amendment changes optimisation settings or acceptance logic, it
  must explain the diagnostic evidence and receive a separate sign-off; Arc 2R
  provides no permission to make that change.
- GitHub API access was unavailable during the pre-edit coordination check, so
  no live PR/issue status was inferred. Review the tracker when online.

## Gotchas and Failed Approaches

- Do not trust the old red receipt's `"NA"` strings; Arc 2R's writer now uses
  JSON `null` for unavailable numerics.
- Do not recalculate source cleanliness after a default in-repo manifest is
  written; the preflight snapshot is the valid provenance receipt.
- Do not label skipped optimiser stages as executed. The test suite covers this
  early-error path.
- The deterministic replay test is an in-memory fixture contract test, not a
  Gate-2 runner invocation, smoke, or campaign.

## Mission Control

| Repo / lane | Branch / commit | What shipped | Next leverage |
| --- | --- | --- | --- |
| `gllvmTMB`, Design 86 Arc 2R | `codex/design86-arc2r-20260723` / `65973ada` | Private fence + auditable provenance/telemetry packet | Maintainer signs or rejects the versioned amendment; stop until then. |

The repository has multiple active worktrees/lanes. Do not rewrite the broad
`CLAUDE.md` rolling handover pointer for this narrow Arc; it would orphan other
lanes. `AGENTS.md` has no separate live-phase snapshot block.

## How to Resume

From the Arc-2R worktree, start Codex and paste:

```text
Read AGENTS.md first, then docs/dev-log/handover/2026-07-23-codex-handover-design86-arc2r.md and docs/design/86-gate2r-readmission-brief.md. Verify git status and stop unless the maintainer has supplied an explicit versioned Gate-2R amendment/sign-off; do not run a smoke, DGP, or campaign.
```

For live R/TMB work only after a future explicit authority, use the normal local
R/TMB environment from this worktree. No Arc-2R-specific exports are required;
`NOT_CRAN=true` is appropriate for non-check R test runs. Codex owns any later
live compile/fit/render work and must use `.codex/agents/*.toml` with Rose's
audit; planning-only work may remain with a planning tool.
