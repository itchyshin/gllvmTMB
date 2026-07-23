# Session Handover: Design 86 Arc 7 — q=2 diagnosis parked

## State

- **Branch:** `codex/design86-arc2r-20260723`
- **Outcome:** Gate A is `PARK`; no V2, Gate B, or smoke exists.
- **Historical roots:** both prior smoke chains remain unchanged.

## What Arc 7 supports

The q=2 packed lower-triangular loading map is locally full rank at the
controlled fixture; its remaining exact symmetries are four sign reflections.
The tested q=2 common-scale path changes KL and is not objective preserving.
A deliberately separable fixed-effect control behaves differently from balanced
and rank-deficient controls. None of these controlled results identifies the
cause of the historical smoke failures.

## Read first

1. `docs/dev-log/forensic/2026-07-23-design86-arc7-gate-a-audit.md`
2. `docs/dev-log/forensic/2026-07-23-design86-arc7-non-gate2-q2-geometry/ledger.json`
3. `docs/design/86-arc7-gate-a-q2-protocol.md`
4. `docs/dev-log/after-task/2026-07-23-design86-arc7-q2-geometry-park.md`

## Hard boundary

Do not alter historical roots, draft V2, construct a Design-86 input, invoke a
runner, alter starts/seeds/thresholds, rescore history, compile a live lane, or
start a campaign from this handover. A future lane needs a fresh approved
mechanism and a promotion-complete evidence contract before it can request
either amendment or Gate-B authority.
