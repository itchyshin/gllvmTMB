# Session Handover: Design 86 Arc 5 — Gate-A parked

## State

- **Branch:** `codex/design86-arc2r-20260723`
- **Base before Arc 5:** `e0e16079`
- **Outcome:** Gate A is `PARK`; Arc 5 did not create V2 or run a smoke.
- **Immutable evidence:** the two Arc-3 smoke roots were not changed.

## What the evidence supports

The static audit maps the V1 extreme values to raw `theta_rr` loading
coordinates. The controlled Gate-1 diagnostic has locally accurate AD
gradients and shows why optimizer code cannot substitute for the recomputed
gradient. Its `theta_rr / 10` comparison did not satisfy the predeclared
same-target or health criteria, so it does not identify scaling as a remedy.

Rose also found the summary receipt incomplete for a promotion decision: it
does not contain the full A0–A3 audit record. The conservative outcome is
therefore `PARK`, rather than a V2 amendment or runner authorization.

## Read first

1. `docs/dev-log/forensic/2026-07-23-design86-arc5-gate-a-audit.md`
2. `docs/design/86-arc5-gate-a-diagnostic-spec.md`
3. `docs/dev-log/after-task/2026-07-23-design86-arc5-gate-a-diagnosis.md`
4. `docs/dev-log/forensic/2026-07-23-design86-arc4-forensic-decision.md`

## Hard boundary

Do not draft V2, alter either smoke record, construct a Gate-2 input, call a
Design-86 runner, change starts/seeds/thresholds, rescore history, compile the
live lane, or start a campaign from this handover. A future diagnosis is a new
arc and needs explicit maintainer approval, an auditable raw-evidence ledger,
and a different falsifiable mechanism before either amendment or Gate-B work.
