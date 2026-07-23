# Session Handover: Design 86 Arc 4 — post-smoke forensic decision packet

**Meta:** 2026-07-23 · from Codex · to Codex

## Critical Context

You are Codex, picking up a closed private Design 86 feasibility lane.  Arc 3
executed the one and only Gate-B-authorized G2R-V1 EVA smoke for seed
`86200002`.  Its receipt is valid, but all four starts failed the frozen
`max_abs_gradient < 1e-4` health rule.  There is no accepted winner or
interval; the record is collapsed.  The historical seed `86200001` red smoke
and all historical evidence remain immutable.

Do **not** invoke any Design 86 runner from this state.  In particular, do not
retry, construct inputs, compile, run a DGP, call Laplace, add a seed, alter a
threshold/start/DGP/scorer, or begin C++/public/Gate-3/Gate-4 work.  Two failed
one-seed records are not the frozen 500-attempt Gate-2 denominator and are not
a Gate-2 verdict.

## Goals / Mission

The immediate recommended arc is **Design 86 Arc 4 — post-smoke forensic
decision packet**.  It is a read-only analysis and maintainer decision memo:
explain the shared frozen-health failure pattern in the two immutable smoke
records; distinguish receipt/provenance validity from optimizer nonstationarity;
and present bounded next decisions.  It must not invent a numerical remedy or
authorize a changed run.

## Plans / Roadmap

1. Draft an ultra-plan for Arc 4 and obtain explicit maintainer approval before
   any tracked edit.
2. Read-only review the historical and V1 result/receipt/telemetry records and
   the existing controlled no-DGP diagnostic harness.  Record only facts
   visible in those materials.
3. Produce a private forensic memo with three decision options: park/close the
   Design 86 feasibility lane; request a new versioned amendment with a
   specifically justified numerical change; or defer pending independent
   numerical analysis.  Do not choose or implement an amendment without the
   maintainer.
4. If a future changed run is proposed, require a fresh versioned authorization,
   independent numerical review, exact hashes, and an explicit pre-run gate.

## What Was Accomplished

- Arc 2R created the guarded, versioned G2R-V1 candidate packet while preserving
  the historical red fixture and artifacts.
- The maintainer's Gate-B signature was recorded at `74dacae5`; fixture and
  amendment state agree on the signed V1 receipt.
- Arc 3 ran exactly one canonical-root EVA smoke with `seed = 86200002L` and
  `rebuild = FALSE`.  It emitted exactly three prospective artifacts: input
  manifest, result, and receipt.
- The result is a **valid receipt / frozen-health failure**: optimizer codes
  were zero, but the four maximum absolute gradients were `0.03370284`,
  `0.1037681`, `0.07223192`, and `0.1050105`, all above `1e-4`.  Thus
  `accepted_starts = false`, `selected_start = null`, no interval was produced,
  and `collapsed = true`.
- Gauss, Rose, and Noether independently returned `VALID_RECEIPT`.  Static
  source, historical-fixture, and sealed-engine guards passed.
- Arc 3 was closed and committed at `1cf956c1`; no push and no PR were made.

Read the detailed Arc-3 closeout rather than relying on this summary:
`docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md`.

## Current Working State

- **Working:** no Design 86 job is running.
- **In progress:** none.  Arc 3 is closed as a valid one-seed failure record.
- **Blocked:** any runner action or protocol alteration awaits a new explicit
  maintainer decision and versioned amendment.  Arc 4 itself awaits explicit
  approval of its read-only forensic scope.

## Key Decisions & Rationale

- **Preserve evidence:** both smoke records, fixtures, source receipts, and
  artifacts are immutable evidence.  Retrospective re-scoring is prohibited.
- **Maintain the denominator boundary:** a one-seed smoke is feasibility
  evidence only, never 500-attempt Gate-2 admission or a capability claim.
- **No C++ lane:** the shipped engine is unchanged by design.  Integrating or
  tuning C++ would be a materially new method/protocol decision, not a remedy
  implied by this receipt.
- **No retry hidden as repair:** the runner rejected an initial *relative* root
  before input construction.  A later canonical-root invocation occurred only
  after explicit maintainer approval and is the sole live smoke.
- **Multi-lane snapshot left intact:** `CLAUDE.md` has a single Live Phase
  Snapshot for a separate active public-boundary lane.  Repointing it only to
  this private Design 86 handover would orphan that lane, so no snapshot edit
  was made.

## Landing State

`/Users/z3437171/Dropbox/Github Local/Shinichi/tools/handoff_gate.sh
/private/tmp/gllvmtmb-design86-arc2r` reports this branch has unpushed commits
(and unrelated unpushed commits on other local branches).  This is declared,
not repaired: the maintainer explicitly directed no push and no PR.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `gllvmTMB` `codex/design86-arc2r-20260723` at local `HEAD` (includes this handover) | yes | no | none | **CARRIED-OVER** — local-only by maintainer direction; do not push or open a PR. Resume: `cd /private/tmp/gllvmtmb-design86-arc2r` |

## Files Created / Modified

Relative to base `403be73c`, the complete Design 86 packet comprises:

- `dev/design86-gate2-eva-runner.R`
- `dev/design86-gate2-laplace-runner.R`
- `docs/design/86-eva-gate2r-v1-parameters.json`
- `docs/design/86-gate2r-v1-amendment.md`
- `docs/design/86-gate2r-v1-arc3-ultraplan.md`
- `docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md`
- `docs/dev-log/after-task/2026-07-23-design86-gate2r-v1-candidate.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc3.md`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-gate2r-v1.md`
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/inputs/manifest.json`
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/eva/seed-86200002-result.json`
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/eva/seed-86200002-receipt.json`
- `tests/testthat/test-design86-gate2-input-contract.R`
- `tests/testthat/test-design86-gate2r-v1-guard.R`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc4-forensic.md` (this handover)

## Next Immediate Steps

1. Read `AGENTS.md`, this handover, the Arc-3 after-task report, and all three
   prospective artifacts.
2. Verify `git status --short --branch`, the exact branch/commit, and hashes
   before making any claim.  Do not treat the current unpushed state as remote
   availability.
3. Use the `ultra-plan` method to propose the bounded Arc-4 forensic packet.
   Bring in Rose for scope/provenance and Gauss/Noether only for read-only
   numerical-contract review.
4. Seek explicit maintainer approval.  Until then, produce no tracked edits
   and invoke no runner.

## Blockers / Open Questions

- What precise decision does the maintainer want after the forensic memo:
  park/close, defer, or formulate a new amendment?  This must not be inferred
  from the gradient values alone.
- Any change to the runner, health rule, starts, DGP, seed set, scorer, or
  output root needs a new versioned amendment and fresh pre-run authority.

## Gotchas & Failed Approaches

- Passing the V1 output root as a relative path is rejected by the runner's
  canonical-path guard before DGP/input construction.  It is not a smoke result.
- The existing prospective root is non-empty and must never be overwritten or
  deleted.  Since it now exists, any new runner call must stop.
- `source_tree_clean = true` in the receipt is the pre-input state.  A later
  `git status` includes tracked artifacts and does not justify a second run.
- Code-zero optimizer exits are not health passes: the frozen gradient rule is
  decisive.  Do not report a winner, interval, recovery, or Gate-2 outcome.
- `gh pr list` could not reach the GitHub API during closeout; no remote PR
  state was inferred from that failed command.

## Mission Control

| Repo | Branch / baseline | CI / evidence | What shipped locally | Next by leverage |
| --- | --- | --- | --- | --- |
| `gllvmTMB` Design 86 | `codex/design86-arc2r-20260723` at `1cf956c1` (base `403be73c`) | Static guards and three independent receipt reviews pass; one prospective smoke is a frozen-health failure | Signed G2R-V1 packet and immutable seed-`86200002` receipt; no public/API/engine change | Maintainer-approved, read-only Arc-4 forensic decision packet; no C++ or rerun |

## How to Resume

In your own authenticated terminal:

```sh
cd /private/tmp/gllvmtmb-design86-arc2r
codex
```

Paste this into the new Codex session:

```text
Read AGENTS.md first, then docs/dev-log/handover/2026-07-23-codex-handover-design86-arc4-forensic.md, docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md, and the three G2R-V1 prospective artifacts. Treat the two smoke records as immutable failure evidence. Do not invoke a Design 86 runner, construct inputs, compile, rerun, alter a protocol, or start C++/public/Gate-3/Gate-4 work. Use ultra-plan to propose the read-only Arc-4 forensic decision packet, then obtain explicit maintainer approval before any tracked edit.
```

For future live R/TMB work only when a maintainer explicitly authorizes it, run
from this checkout and set `NOT_CRAN=true`; Codex is the tool that can execute
the live R/TMB compiler path.  Arc 4 itself should remain read-only and requires
no live-run command.
