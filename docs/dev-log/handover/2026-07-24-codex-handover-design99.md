# Codex Handover: Design 99 exact-reference infrastructure stop

**Date:** 2026-07-24  
**From:** Codex  
**To:** a fresh Codex task, inspection only  
**Worktree:** `/private/tmp/gllvmtmb-design99-exact-reference`  
**Branch:** `codex/design99-exact-reference-20260724`  
**Implementation/closeout commit:** `41930f8e`

## Critical Context

Design 99 is terminal as `INFRASTRUCTURE_INCOMPLETE`. The branch contains a
substantial private pure-R q=2 adaptive Gaussian--Hermite implementation and
passing bounded synthetic tests, but the strict independent-oracle mechanical
gate did not produce its required terminal receipt. Therefore no exact
reference was admitted.

Do not rerun or repair Design 99. Do not freeze its scientific fixture, create
a real UUID, create `REAL_RUN.json`, start optimization, execute the information
ladder, or infer stability, identification, recovery, or VA/JJ consequences.
Any changed oracle execution, timeout, progress schema, fixture, start, chart,
node order, optimizer, or question requires a separately approved Design 100.

## What Was Accomplished

- Created a fresh Design-99 lane from terminal Design-98 commit `7ca5da1c`.
- Froze and repeatedly verified a 732-row protected inventory with aggregate
  SHA-256
  `0b8910908bd9b89a21994f008f806a2e973005fc69ae1d39e5b88396c6b64531`.
- Implemented private numerics, adaptive quadrature, direct original-\(u\)
  comparators, two loading charts, fixtures, optimizer routes, immutable
  records, worker supervision, and a 208-task graph.
- Passed the bounded numerics, charts, optimizer, infrastructure,
  runtime-wiring, orchestration, provenance, runtime-isolation, and protected
  inventory suites.
- Retained the failed strict-gate history and terminal
  `INFRASTRUCTURE_INCOMPLETE` record.
- Wrote the plan-versus-actual reconciliation, check-log entry, and validated
  after-task report.

The authoritative detailed record is
`docs/dev-log/after-task/2026-07-24-design99-exact-reference.md`.

## Current Working State

- **Working:** private pure-R components and bounded synthetic
  `NON_EVIDENCE` suites.
- **Terminal:** Design 99, labelled `INFRASTRUCTURE_INCOMPLETE`.
- **Not created:** approved fixture, real UUID, real-run lock, optimization
  records, information-ladder records, or an admission verdict.
- **Not authorized:** replay, repair, package integration, VA/JJ/EVA work,
  campaign compute, push, PR, or merge.

## Key Decisions And Rationale

1. Synthetic checks remain mechanical evidence only. They cannot replace the
   independent-oracle receipt required by the contract.
2. The corrected strict gate was interrupted after 2,700 seconds without a
   progress or terminal record. The contract did not prospectively define that
   mechanical timeout; the adaptive operator cutoff is recorded as a deviation,
   not recast as a numerical failure or pass.
3. No cheaper comparator, extended timeout, or real-fixture execution followed.
   This preserves the one-shot discipline and prevents post-result tuning.
4. The branch stays local because the approved plan explicitly prohibited push,
   PR, and merge work.

## Landing State

The required handoff gate was run after commit `41930f8e`. It reported this
branch as unpushed and therefore unlanded from a remote receiver's perspective.
That failure is explicitly declared here:

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---:|---|
| `gllvmtmb-design99-exact-reference` / `codex/design99-exact-reference-20260724` / `41930f8e` | yes | no | none | `CARRIED-OVER` |

**Why carried over:** the approved Design-99 contract requires a local commit
only and prohibits push, PR, and merge work.

**Resume command:**

```sh
cd /private/tmp/gllvmtmb-design99-exact-reference &&
git status --short --branch &&
git log -3 --oneline
```

The handoff gate also listed many unrelated historical unpushed branches. They
are not owned by Design 99 and were not changed.

## Files Created Or Modified

Every Design-99 path is enumerated by area in
`docs/dev-log/after-task/2026-07-24-design99-exact-reference.md`, Section 4.
The durable closeout set is:

- `docs/design/99-exact-q2-reference-stabilization.md`
- `dev/design99-exact-reference/`
- `docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-24-design99-exact-reference.md`
- `docs/dev-log/handover/2026-07-24-codex-handover-design99.md`

No package implementation, public API, README, NEWS, vignette, generated help,
NAMESPACE, DESCRIPTION, or pkgdown path changed.

## Next Immediate Steps

There is no execution step inside Design 99. A fresh task may inspect the
commits, after-task report, terminal record, and implementation without running
them.

If the maintainer wants to continue the research, first draft and approve a
new Design 100. Its prospective contract should add pattern-level heartbeats,
explicit per-pattern and whole-gate timeouts, bounded parallelism, and a
non-evidence cost benchmark before any scientific fixture is frozen. It must
still pass an independent exact-reference gate before any new VA/JJ factorial.

## Blockers And Open Questions

The GitHub API was unreachable during the pre-edit and closeout PR/issue
censuses. This did not block local private work, but remote PR state was not
verified.

The substantive blocker is architectural: the strict independent-oracle stage
has no sufficiently granular progress or terminal protocol for its observed
cost. Changing that protocol belongs to a new design.

## Gotchas And Failed Approaches

- `dQuote()` generated locale-sensitive curly quotes in a child Rscript
  expression. The repaired launcher uses shell-safe encoded quoting.
- The corrected nested-integration process was silent for 45 minutes and
  produced no receipt. Do not rerun it under Design 99.
- A test file originally depended on `testthat` already being attached and on a
  particular working directory. Direct execution exposed this; the test is now
  standalone.
- Early implementation reviews caught and removed an unbacktracked Newton
  fallback, incomplete oracle-error propagation, weak source/run identity
  validation, and accidental package-root files.

## Mission Control

| Lane | Branch / commit | State | Highest-leverage next action |
|---|---|---|---|
| Design 98 | terminal `7ca5da1c` | immutable `TECHNICAL_INCOMPLETE` | read only |
| Design 99 | `codex/design99-exact-reference-20260724` / `41930f8e` | local `INFRASTRUCTURE_INCOMPLETE`; no real run | inspect only |
| Potential Design 100 | not created | unapproved | blueprint a progress-aware independent-oracle design |

## How To Resume

Read `AGENTS.md` first, then inspect:

1. `docs/dev-log/handover/2026-07-24-codex-handover-design99.md`
2. `docs/dev-log/after-task/2026-07-24-design99-exact-reference.md`
3. `docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md`
4. `docs/design/99-exact-q2-reference-stabilization.md`
5. `dev/design99-exact-reference/results/non-evidence/gate3-infrastructure-incomplete.json`

Paste into a fresh Codex task:

```text
Read AGENTS.md first. Rehydrate from
docs/dev-log/handover/2026-07-24-codex-handover-design99.md and inspect the
Design-99 after-task report and terminal record. Preserve Design 99 as terminal
INFRASTRUCTURE_INCOMPLETE. Inspection only: do not rerun, repair, freeze a
fixture, create a real UUID or REAL_RUN lock, optimize, start an information
ladder, touch package paths, or begin VA/JJ/EVA work. If continuation is
desired, propose a separately approved Design 100.
```
