# Plan vs actual — missing-data lane (lane 3), 2026-07-28

Reconciliation of the ultra-plan against what happened. Material deviations only; each tagged
**adaptive** (justified, recorded — not a defect) or **drift** (unjustified).

## Scope

| Planned | Actual | Tag |
|---|---|---|
| Audit the missing-data surface; fix reader surfaces owned by the lane; propose runtime changes rather than ship them | Done as planned | — |
| S2 = "test-first pins for the three uncovered claims" | Written, but one of the three (the one-`mi()` scope claim) turned out **not** to be a defect — the guard exists and fires. It became a regression pin instead of a failing test. | **adaptive** — a negative result, recorded rather than manufactured into a finding |
| Findings expected in the missing-response surface | The three most severe findings (B1 README, B2 `offset()`, B3 identifier `NA`) are **outside** that surface, and two are outside the lane's remit entirely | **adaptive** — surfaced and reported, not silently absorbed or silently dropped |
| S5 to fix "the article + man pages + roxygen" | Only the **article** was changed. The man pages proved accurate; the roxygen needing correction is in a fenced file | **adaptive** — less change than planned because less was wrong |

## Evidence / verification

| Planned | Actual | Tag |
|---|---|---|
| Every finding verified by a live fit | Held. No behavioural row rests on static reading. | — |
| S1 live-fit grid | Ran; plus the orchestrator ran an **independent** crux check rather than relying on the agent | **adaptive** — duplication was deliberate, the claim is load-bearing |
| S3 skip counts | First measurement **invalid** (env var never reached the runner; default and heavy returned identical counts). Discarded and re-measured by the orchestrator. | **adaptive** — the agent flagged its own result; the invalid figure never entered the ledger |
| S6 adversarial pass | Ran, 12 attack fronts, **SURVIVES-WITH-SCOPE** with 4 scope restrictions | — |
| — | **S6 caught an overclaim in the lane's own fix** (asserted exact FIML; non-Gaussian marginal is Laplace). Corrected before commit. | **adaptive** — this is the pass working as designed |
| `devtools::test()` before push | Done: default 133 pass / 80 skip / 0 fail; heavy 665 pass / 0 skip / 0 fail | — |
| `rcmdcheck` before push | Run at close | — |
| Mutation-check the new pins | Not in the plan; added because the after-task protocol requires "tests of the tests" | **adaptive** — added rigour |

## Model routing

| Planned | Actual | Tag |
|---|---|---|
| S1 Sonnet·high, S3 Haiku·low, S6 Opus·high, ≤6 children, ≤1 ceiling | 4 children total (3 scouts + S1/S3/S6 overlap), exactly 1 Opus (S6) | — within budget |
| S2/S4/S5/S7 to sub-agents | **Run by the orchestrator instead.** All the evidence was already in the orchestrator's context; dispatching would have meant re-deriving it. | **adaptive** — fewer children than planned, and cheaper |

## Safety gates

| Gate | Status |
|---|---|
| Phase 0.25 sweep receipt before decomposing | Present, evidence-cited per surface |
| Lane preflight at orient and before claiming | Run twice; `PLATFORM: claude / LANE: missing-data / FOREIGN LANE: none` |
| Fenced files untouched | Held — `R/gllvmTMB.R`, `R/fit-multi.R` read only; the roxygen patch prepared, not applied |
| Scoped staging, never `git add -A` | Held — five paths named explicitly |
| No coverage claim | Held |
| No internal register codes on reader surfaces | Held |
| Totoro untouched (at cap for another lane) | Held — all compute local |

## Public claims

The headline claim was **narrowed twice** before shipping:

1. From "the docs systematically call this complete-case, a misnomer" → to a **single-surface**
   imprecision, after sweeping the neighbourhood showed `man/traits.Rd` already states the
   distinction correctly.
2. From "the default is FIML over the observed data" → to the full-information **principle**, with
   the Laplace approximation stated, after the adversarial pass showed the stronger form was not
   demonstrated.

Both narrowings are recorded in the ledger. No claim shipped that a fit did not demonstrate.

## Handoff state

Committed `e4f5d377` on `claude/missing-data-20260728`. Five carried-over items, all declared in the
handover with the reason each is not fixable from this lane. Nothing left undeclared.

## Drift

**None identified.** Every deviation above is adaptive and recorded. The plan's shape held; what
changed is that the audit found less wrong on the surface it targeted and more wrong just outside
it — and that the most valuable findings came from the adversarial pass rather than the audit
proper.

## Lesson for the ledger

The plan allocated one slice to adversarial verification and it returned the highest-value output of
the lane — one blocker, two highs, and a correction to the lane's own fix. **Where a lane's
deliverable is a claim, the refutation slice is not a formality at the end; it is the instrument.**
