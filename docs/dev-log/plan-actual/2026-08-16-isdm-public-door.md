# Plan vs actual — iSDM public door (2026-08-16)

Reconciler: Melissa. Plan: `~/.claude/plans/generic-giggling-tulip.md`.
Lane: `claude/isdm-public-door-20260816` · PR
[#1016](https://github.com/itchyshin/gllvmTMB/pull/1016).

## Scope

**ADAPTIVE — the plan itself replaced an approved plan, and said so.** The
inherited baton specified an exported wrapper; the maintainer overrode it
mid-planning. The plan recorded the conflicting handover in its sweep receipt
rather than quietly dropping it, and #945 was cited as the maintainer's own
prior specification. Deliverable shipped as re-scoped.

**ADAPTIVE — spatial arm admitted, which the plan flagged as a "separate,
harder decision".** Scout 2 established the article uses `spatial = TRUE`, so
admitting only the non-spatial arm would not have let the article be rewired —
i.e. would not have met the goal. Admitted on the same structural contract and
recorded in `ISDM-01` as resting on campaign experience, not a cleared gate.
**Routed to the maintainer as an explicit PR question**, not settled unilaterally.

## Evidence and verification

**ADAPTIVE.** Planned S5/S6 as separate mechanical (Haiku) and judgment (Opus)
slices; ran the mechanical checks inline and the judgment review as one Opus
agent. Same coverage, one fewer child.

**Material finding, correctly handled:** the review found a real fence bypass
after three commits were already written. The plan's own Ada note said *"the
one thing that would re-open this plan is [the sweep] finding a prior lane…"* —
the actual re-opener was the adversarial review, which is what Phase 4 exists
for. Fixed in `56477e6a` before any push.

**DRIFT (minor, disclosed):** the plan's DISCIPLINE line named Gauss on the gate
change. Gauss did **not** review the offset-coherence argument independently;
it is carried from #945/#946 and the existing source comment. Disclosed in the
after-task report §5 and raised as PR item 2 rather than left implicit.

## Model routing

**DRIFT (forced, not chosen).** The plan routed S2 (the gate change) to an Opus
sub-agent and S3/S4 to Sonnet. **The permission classifier blocked every
write-capable Agent dispatch**, so S2–S4 were implemented inline by the
orchestrator (Fable) instead. Only read-only agents ran: 2 Sonnet scouts and
1 Opus reviewer. Net effect on cost is unmeasured; net effect on quality is
arguably positive — the reviewer stayed a genuinely fresh context, which is the
property that caught the bypass. Recorded because a plan naming models it did
not use is exactly the drift class this file exists to catch.

**Children: 3 of the 7 authorised** (2 scouts + 1 ceiling reviewer). Under budget.

## Safety gates

**Clean.** Preflight run and pasted; per-file preflight re-run before editing
`R/fit-multi.R`; sweep receipt complete with commands cited; lane named. Ledger
race avoided — `ISDM-01` chosen over `MIS-37`, which another lane already holds.
No `src/`, likelihood, grammar, or NAMESPACE change, as fenced. Every DEFER item
stayed deferred.

## Public claims

**Clean.** Register row is `partial` and enumerates what it does not establish.
NEWS carries IN / PARTIAL / NOT-INCLUDED in plain language. No register codes on
reader-facing surfaces (scanned). D-43 panel correctly **not** fired — nothing
was promoted to `covered`. Two capability claims were actively narrowed during
the lane: the article's scope-boundary section was added, and the spatial arm's
evidence basis was stated rather than implied.

## Handoff state

**Clean.** Branch pushed, worktree clean, PR open with four explicit maintainer
asks. After-task and check-log landed. Merge deliberately left to the maintainer.

## For the drift ledger

One recurring class worth watching: **a plan that names sub-agent models cannot
assume the dispatch will be permitted.** This is the second observable case of
the executing surface differing from the planned one. If it recurs, the plan
template should carry a fallback routing line rather than a single assignment.
