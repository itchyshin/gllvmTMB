# Codex handover — Design 98 factorial VA/JJ terminal record

## Critical context

Read `AGENTS.md`,
`docs/design/98-factorial-va-jj-discriminator.md`, and
`docs/dev-log/after-task/2026-07-24-design98-factorial-va-jj-technical-incomplete.md`
before acting.

Design 98 is terminal at `TECHNICAL_INCOMPLETE`. Do not rerun, resume, rescore,
repair, delete, overwrite, add starts, change thresholds, change GH order, or
create a second UUID. The immutable real UUID is
`20260724T161436-30841-62d0004f`.

## What completed

- Gate 0 mathematical and scope/provenance reviews passed.
- The private R/C++ objective mechanics, supervised worker DAG, provenance
  guards and failure injections passed.
- The retained N=16/T=3 non-evidence smoke passed.
- All 52 real task inputs reached terminal records.
- QD, QF and JD were comparable on the low fixture.

## Why the result is incomplete

- All low-GH endpoints failed the 31/41/61 ladder and 61-node gradient check.
- All high-GH BFGS endpoints exceeded the `<1e-4` gradient threshold.
- Fixed-global tasks were therefore dependency-blocked.
- All JF BFGS endpoints exceeded `<1e-4`, so JF was not comparable.

The summary correctly leaves all four mechanism flags unavailable. QD/QF/JD
metrics may be described only as retained single-fixture observations.

## Scope fence

No package `R/`, `src/`, test, manual, vignette, README, NAMESPACE,
DESCRIPTION, NEWS or pkgdown path changed. Designs 72/85/95/96/97 remain
byte-identical. No EVA, q4/q6, structured prior, campaign, Totoro/DRAC,
Actions, public API, merge, push or PR work occurred.

## Landing state

| Lane | State | Next action |
|---|---|---|
| Design 97 | immutable `SMOKE_STOP` | never replay |
| Design 98 | `CARRIED-OVER` on private branch `codex/design98-factorial-va-jj-20260724`; deliberately unpushed because push/PR/merge were outside the approved scope | retain as immutable `TECHNICAL_INCOMPLETE`; resume with `git -C /private/tmp/gllvmtmb-design98-factorial-va-jj status --short --branch` |
| Any revised GH/JF research | not approved | create a separately numbered design |

## Resume text

```text
Read AGENTS.md first. Rehydrate from docs/dev-log/handover/2026-07-24-codex-handover-design98.md and docs/dev-log/after-task/2026-07-24-design98-factorial-va-jj-technical-incomplete.md. Preserve Design 98 UUID 20260724T161436-30841-62d0004f as immutable TECHNICAL_INCOMPLETE. Do not rerun, resume, rescore, tune, or repair it. Any further GH, VA, or JJ work requires a separately approved new research design.
```
