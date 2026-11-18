# Plan vs actual — random-slope surface lane (Melissa)

**Date:** 2026-08-18 · **Lane:** `claude/rand-slope-surface-20260818` · **Worktree:**
`/private/tmp/gllvmtmb-randslope` · **Frame:** D-113 track 6 (Shinichi, 2026-08-01:
"at least one random slope for each distribution"; 2026-08-08 clarifying note: propose a
test programme and STOP FOR APPROVAL).

## Planned

Six slices, ultra-plan shape: **S0** (Haiku recon of the truth-vs-board gap) → **S1**
(Sonnet board correction) → **S2** (Sonnet interval-computability probe) → **S3** (Sonnet
campaign costing) → **S4** (Opus adversarial review) → **S5** (Sonnet reconcile/close).
Fan-out budget: 6 children, 1 ceiling (i.e. no second-level sub-agent spawn). Named agents
this session: Curie-S0, Curie-S1, Gauss-S2, Curie-S3, Rose-S4.

## Actual

All six slices ran, in order, none skipped, none descoped. Fan-out stayed within budget —
5 named agents plus this closeout, 0 ceiling-level (second-generation) spawns. Deliverables:
`dev/rand-slope-truth-ledger.md`, `dev/board-correction-notes.md`,
`docs/dev-log/capability-surface.html` (5 cells corrected), `dev/slope-interval-feasibility*`
(script/results/log), `docs/design/128-slope-per-family-campaign.md`,
`dev/S4-adversarial-review.md`, this after-task
(`docs/dev-log/after-task/2026-08-18-rand-slope-surface.md`) and reconciliation.

## Material deviations

| Axis | Planned | Actual | Tag | Owner |
|---|---|---|---|---|
| Scope | Answer 3 questions (all-families feasibility, interval feasibility, board correctness) via 5 slices | Same 3 questions answered; scope held — no slice expanded into implementation, no family admitted, no export built | Met (no deviation) | — |
| Evidence/verification | One board pass (S1), one probe pass (S2), one review pass (S4) | S1 board pass needed a same-session post-review correction (ID 14); **S2 needed 3 build passes plus a 4th post-review fix pass** (see Deviation A below); S4 returned CHANGES REQUIRED rather than a clean pass (see Deviation B) | **adaptive** (both A and B) | Ada / Rose |
| Model routing | Haiku (S0) → Sonnet (S1/S2/S3) → Opus (S4) → Sonnet (S5) | Matches exactly; S4 (adversarial, correctness-critical) stayed on Opus per the roster's own rule, and no slice was escalated or downgraded outside plan | Met | — |
| Safety gates | D-139 (no run without estimate + pre-run test above 30 min); D-113 track-6 STOP-FOR-APPROVAL; no `R/`/`src/`/`tests/`/`NEWS.md`/`DESCRIPTION` edit; no ✓ added to the board | All four held: Design 128 is costing-only with an unexecuted pre-run test spec; nothing bumped `DESCRIPTION`; `git diff --name-only origin/main...HEAD -- R/ src/ NEWS.md DESCRIPTION tests/` is empty (checked); no `class="yes"` added to the Rand. slope column (checked) | Met | — |
| Public claims | None planned beyond "the board now matches the evidence" | None made beyond that; explicitly refused a "works for all families" framing (grepped for and absent); tweedie/truncated_*/delta_* explicitly left `open`/fenced | Met | — |
| Handoff state | PR opened, marked needs-review, not merged; two open questions surfaced for Shinichi | PR opened not merged (this closeout); two open questions surfaced (campaign ordering; extractor scope) — matches plan exactly | Met | — |

## Deviation A — S2 needed three build passes, not one (adaptive)

**Planned:** one probe pass produces a computability verdict.

**Actual:** four passes total.
1. **Pass 1** measured no slope parameters at all — the probe's first `theta_dep_chol`
   read targeted the wrong slot and returned nothing usable, so the run was
   uninformative about computability, not evidence of infeasibility.
2. **Pass 2** produced fits with a non-PD Hessian — informative about fragility, but not
   a clean computability answer, since a non-PD Hessian fit's `cov.fixed` cannot be
   trusted to demonstrate a well-posed interval.
3. **Pass 3** succeeded: a healthy fit (`convergence == 0`, `pdHess == TRUE`), both
   routes' parameters located in `par.fixed`/`cov.fixed`, delta-method numbers computed.
   This is the version S4 reviewed.
4. **Pass 4** (post-adversarial-review, commit `d5e9f198`) corrected a real indexing bug
   in pass 3's Route A reading — see the after-task report's R2 for detail.

**Classification: adaptive, not drift.** Passes 1–2 are ordinary iterative debugging
toward a working probe (the kind of rework any dev-script build goes through before it
produces a trustworthy number) — they did not change the plan's scope or claim anything
false while broken; they simply hadn't yet produced a result. Pass 4 is different in
kind: it is a **correctness fix made in direct response to a named reviewer finding**,
which is exactly what the S4 gate exists to produce. Calling passes 1–2 "drift" would
punish debugging; calling pass 4 anything other than the gate working as designed would
undersell the review's value. Note for the ledger: three build attempts before a
trustworthy result is on the high side for a single slice and is worth a line in
[[PLAN-DRIFT-LEDGER]] if this recurs — a probe against an unfamiliar internal parameter
packing (Cholesky block layout) is exactly the kind of task where a first assumption
about internal structure is likely to be wrong, and a cheaper first move (grep the C++
source for the packing order before writing the R-side indexing) might have saved passes
1–2.

## Deviation B — S4 returned CHANGES REQUIRED, not a clean pass (adaptive)

**Planned:** an adversarial review slice that either passes or blocks consolidation.

**Actual:** Rose's review (`dev/S4-adversarial-review.md`) returned **CHANGES REQUIRED**
with two required changes (R1: the ordinal_probit board annotation was mis-scoped and
contained a false claim; R2: the S2 probe's Route A indexing bug, above). Both were fixed
in follow-on commits (`f2a75761`, `d5e9f198`) before this closeout, and Rose's own review
verified both fixes' correctness at source.

**Classification: adaptive, not drift — and not a failure of the lane.** A
CHANGES-REQUIRED verdict is one of the review gate's two designed outcomes, not an
overrun; the plan never specified "the review must pass clean," only that a review must
happen before consolidation. Both required changes were substantive (a false claim in
each case, not wording), which is exactly the class of finding an adversarial pass is
supposed to catch and a same-session self-review was structurally unlikely to catch (R1
was a judgment-call error about column semantics; R2 was a wrong assumption about
internal Cholesky packing verified only by reading `src/gllvmTMB.cpp` directly). Per the
task brief's own framing: **cosmetic changes are not drift, and neither is a substantive
review finding that gets fixed before close.** No further review round was needed after
the fixes — Rose's own required-changes list is narrow and both items map 1:1 to landed
commits.

## Verdict

**2 material deviations, both tagged adaptive; 0 drift; 0 unclear.** Deviation A (S2's
three-pass rework, including the post-review indexing fix) and Deviation B (S4's
CHANGES-REQUIRED verdict) are the only two departures from the six-axis plan, both
justified above and both recorded rather than smoothed over. Every other axis (scope,
model routing, safety gates, public claims, handoff state) matched the plan exactly — no
deviation to classify. The lane closes with both of S4's required changes landed, the
honesty invariants holding (verified in the after-task report §4), and two named open
questions for Shinichi rather than an implicit decision made on his behalf.
