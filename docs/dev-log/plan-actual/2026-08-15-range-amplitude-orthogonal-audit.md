# Plan vs actual: Paper 1 range--amplitude orthogonal chart audit

**Reconciler**: Melissa · **Date**: 2026-08-15 · **Lane**:
`codex/isdm-range-amplitude-orthogonal` · **Plan**:
`~/.claude/plans/recursive-conjuring-floyd.md`

Material deviations only, six axes. Cosmetic wording and ordering changes are
not drift.

| # | Axis | Planned | Actual | Tag |
| --- | --- | --- | --- | --- |
| 1 | Scope | S1--S7, chart lane only | plus S8, a 30-file test sourcing-guard sweep | **adaptive** |
| 2 | Evidence | S5 verifies the audit | S5 **refuted** part of it; audit, contract, design and tests rewritten | **adaptive** |
| 3 | Routing | 3 new children (2 build, 1 ceiling) | 7 total (3 Phase-0 scouts + 2 build + 1 ceiling + 1 extra build) | **adaptive** |
| 4 | Safety gates | per-file lane pre-flight before editing | run at repo level first; per-file closed later in session | **drift (corrected)** |
| 5 | Public claims | none | none | compliant |
| 6 | Handoff | local commits, no push, no PR | `10edecc2`, `cd3fac12`; unpushed; no PR | compliant |
| 7 | Estimate | ~2 h, 3 agents, 1 batch | ~7 agents, 2 batches, longer | **drift** |

## Axis 1 -- scope expansion (adaptive)

A latent defect found in passing (isdm tests sourcing from build-ignored `dev/`)
was filed as a chip rather than fixed silently, which is the correct default.
The maintainer then handed the chip back as an explicit instruction, which is a
user checkpoint. Recorded as adaptive, not scope creep: the expansion was
requested, and the original slices were completed in full alongside it.

## Axis 2 -- verification changed the deliverable (adaptive, and the point of the phase)

The plan treated S5 as a confirmation step. It was not. It refuted the audit's
prescribed fix for F3, found §4 incomplete, showed F2's derivation degenerate at
`B = 0`, refuted one F1 sentence, upgraded F5, added F7, and falsified a row of
the audit's own verification receipt. Roughly a third of the audit was rewritten
as a result.

This is the phase working as designed and is **not** drift. It is recorded here
because the plan's own estimate assumed verification would be cheap, and a plan
that budgets nothing for the verifier being right will under-resource this phase
every time.

## Axis 3 -- fan-out budget (adaptive, checkpoint named)

The plan declared 3 new children against a 6-child budget. Seven ran: three
Phase-0 scouts (2 Haiku, 1 Sonnet), two build (Sonnet), one ceiling (Opus), and
one further build (Sonnet) for the added sweep. The seventh child postdates the
maintainer's explicit instruction to action the chip, which is the user
checkpoint the budget rule requires for exceeding six. Ceiling children: **1**,
within limit. No slice was silently absorbed onto the orchestrator.

## Axis 4 -- per-file lane pre-flight (drift, corrected in session)

The handover's step 1 asks for `lane_preflight.sh --file <path>` **before
editing every file**. The repo-level pre-flight ran at Phase 0.2, but the
per-file check was run only after the first two files had been edited. No
collision resulted (no foreign lane owns `dev/isdm-package-recovery/`), so the
impact was nil, but the sequence was wrong. Recorded because the guard's value
is entirely in running it *first*.

## Axis 7 -- estimate (drift)

The plan said ~2 h / 3 agents / 1 batch. Actual was materially larger, driven by
axes 1 and 2. Neither cause was foreseeable at plan time; the estimate was not
padded for "the reviewer finds something real".

## Routed to

- **Rose** -- axis 2, for the closeout claim (the audit's status changed from
  "confirms the chart" to "confirms it in part; the optimum half awaits the
  sign-orbit gate").
- **Ada** -- axes 3 and 7, for future budget and estimate calibration.
- **Shannon** -- axis 4, per-file pre-flight sequencing.

## Recurring-class candidate for [[PLAN-DRIFT-LEDGER]]

*Plans budget for verification confirming, not for verification refuting.* Seen
here on axes 2 and 7 together. If it recurs, the fix is an explicit rework
allowance in the estimate whenever a plan contains an adversarial verify slice.
