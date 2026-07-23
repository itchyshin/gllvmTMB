# Session Handover: Design 86 Arc 3 — G2R-V1 EVA smoke

**Branch:** `codex/design86-arc2r-20260723`
**Signature commit:** `74dacae5`
**State:** local-only; do not push or open a PR without maintainer direction.

## Outcome

The sole signed EVA smoke for seed `86200002` completed and produced a valid
immutable receipt. All four starts had optimizer code zero but failed the
frozen `max_abs_gradient < 1e-4` screen (0.0337028, 0.1037681, 0.0722319,
0.1050105). There is no accepted winner or interval; the replicate is marked
collapsed.

This is a one-seed smoke failure record only. It does not change the historical
red smoke, establish Gate 2, or authorise retry, additional seeds, Laplace,
Totoro/DRAC, Gate 3/4, public API, or shipped-engine work.

## Evidence

- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/`
- `docs/dev-log/after-task/2026-07-23-design86-arc3-g2r-v1-eva-smoke.md`
- `docs/design/86-gate2r-v1-arc3-ultraplan.md`

Gauss, Rose, and Noether independently returned `VALID_RECEIPT`. Historical
fixture/artifacts and sealed source guards remain unchanged.

## Resume rule

Do not resume a Design 86 runner from this state. A new arc requires a fresh
maintainer decision and versioned amendment that explicitly addresses the
frozen-protocol failure; it may not silently tune or rerun this smoke.
