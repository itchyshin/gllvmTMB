# Plan vs actual — MSPL interval calibration, Phase A (ultra-plan, 2026-08-15)

Melissa (Sonnet, medium), per the plan's own `## Reconcile` line and A6 Brief 2. Phase A
only. Plan: `~/.claude/plans/vivid-sleeping-sprout.md`. Lane: `claude/mspl-interval-calibration`,
worktree `/private/tmp/gllvmtmb-mspl-interval-calibration`.

**Evidence used:** task-list history (A1..A6 + added A1b); reports and derived artefacts in
`scratchpad/phase-a/` (A1, A1b, A2, A3, A4, `orchestrator-spot-checks.md`); the committed
lane packet (`dcb26fc1`, `3c60c6a5`, `cda77ca4`, `8cbb37c7`); `git log`/`git diff` against
the pre-Phase-A base `0e05ed6f`; the lane-B handoff commit `e91c7b7c` (on
`codex/lane-b-mspl-interval-feasibility`, confirmed not an ancestor of this branch); a
direct `shinichi-brain` search for the sweep-receipt fold-in claim.

## Scope

| planned (Phase A table) | actual | tag |
|---|---|---|
| A1 mechanism partition (Curie, Sonnet high) | done — `A1-mechanism-partition.md` (344 ln archived), 55 failures partitioned 26 over / 6 under / 1 availability-only / 22 borderline-MCSE | — |
| A2 primary verification (Ranganathan, Sonnet high) | done — `A2-kosmidis-firth-primary.md` (192 ln archived), K&F 2021 caveat verified against arXiv:1812.01938v4, survives profiling | — |
| A3 calibrator design (Fisher, Opus high) | done — `A3-calibrator-design.md` (679 ln archived), S1–S5 backbone | — |
| A4 BCa simulated acceleration (Fisher, Sonnet high) | done — `A4-bca-simulated-acceleration.md` (444 ln archived), canonical/ABC/IJ routes structurally blocked, perturbation-resimulation the one viable (unverified) route | — |
| A5 adjudicate + pre-register (Fisher+Rose, planned Opus) | done — Design 118 (653 ln, `dcb26fc1`), Design 117 §6.2 pointer edit (`3c60c6a5`), dev-log adjudication record (`cda77ca4`) | see Model routing |
| A6 mechanical verify (scout, Haiku low) | Brief 1 dispatched concurrently with this reconcile (A6-BRIEFS.md: "fire both in ONE message"); its PASS/FAIL output was not yet in `scratchpad/phase-a/` at the time this document was written | not evaluated here — see Evidence/verification |
| — (not in original Phase-A table) | **A1b pinning root-cause** — `A1b-pinning-root-cause.md` (286 ln archived), verdict **INTRINSIC**: C011 is the exact penalty-determined optimum under quasi-complete separation, not a bug | **adaptive** |
| — | **`8cbb37c7`** — orchestrator archived all six Phase-A evidence reports + spot-checks verbatim into `docs/dev-log/mspl-interval-phase-a/` | **adaptive** |
| — | **`orchestrator-spot-checks.md`** — orchestrator independently re-derived the three load-bearing numbers mid-flight, while A5 was in flight | **adaptive** |
| — | **lane-B backup push `e91c7b7c`** (force-with-lease, user-authorized) on `codex/lane-b-mspl-interval-feasibility` | **adaptive** |

The Phase-A gate line in the plan ("A5 returns either *calibration is viable* or *the
pocket is not calibratable, here is the narrower surface*") anticipated exactly the
disjunctive answer A5 in fact returned — a hybrid: **level-calibrated profile is viable
for the bulk (26 overcoverage cells)**, and **the C011 pocket is refused by a fence, not
calibrated** (Design 118 §0.1). That is not a deviation; it is the gate firing as designed.

## Evidence / verification

Independently re-checked, not just cited:

- `git diff 0e05ed6f..HEAD --stat` touches **only** `docs/` (9 files, +2753/−12); nothing
  under `R/`, `src/`, or `tests/` changed on this lane. Confirms "zero new compute" and
  "fences untouched" structurally, not just by commit-message assertion.
- `git diff 0e05ed6f -- docs/design/117-separation-estimability-programme.md` shows the
  §6.2 edit is the **only** hunk in that file — the brief's Brief-1 check item, verified
  here independently (do not rely on Brief 1's own report, which was not yet written).
- `docs/design/35-validation-debt-register.md` does not appear in the diff — MSPL-04
  remains `blocked`, as A5's brief required.
- `git status -sb` on the lane branch shows no upstream; `git rev-parse @{u}` errors
  "no upstream configured" — nothing from this lane has been pushed.
- The lane-B commit `e91c7b7c` ("docs: hand off MSPL interval feasibility to Claude")
  is reachable and lives on `codex/lane-b-mspl-interval-feasibility` (local **and**
  `remotes/origin/`, i.e. pushed) — confirmed **not** an ancestor of
  `claude/mspl-interval-calibration`, i.e. it is a separate, prior lane's handoff, not a
  slice of this plan, consistent with the plan's own framing ("Codex lane-B... closed
  with this work explicitly OWED").
- **A6 Brief 1 (mechanical verify) has not yet reported** as of this write — its
  PASS/FAIL table is the independent numeric cross-check against
  `orchestrator-spot-checks.md` and `gate-map-108.tsv`; this reconcile does not
  duplicate that check, only confirms the orchestrator's own mid-flight spot-check
  (3/3 confirmed against primaries, per `orchestrator-spot-checks.md`) and treats Brief
  1 as a parallel, not sequential, dependency — as the dispatch note specifies.
- **Brain sweep fold-in** (the plan's Phase-0.25 "brain" row was `pending` at approval):
  verified by direct `shinichi-brain` search rather than taking the claim on faith.
  `dr32` ("Separation and rare species in JSDMs: estimability, detection, remedies") and
  `dr34` ("LA-MSPL as a parallel Laplace estimator — theory, counterpoints, and family
  sequencing") both exist and are topically on point for this arc — the reuse claim is
  **confirmed**. The **jackknife-rejection promotion is confirmed still queued, not yet
  landed**: no DECISIONS.md-style entry surfaced in three targeted searches, which
  matches A6-BRIEFS.md's own "Also owed at close" item stating neither the jackknife
  rejection nor the Phase-A verdict is recorded yet as a numbered decision. This is not
  a gap in Phase A — it is explicitly orchestrator-owed work, tracked below under
  Handoff state.

## Model routing

| planned | actual | tag |
|---|---|---|
| A1 Sonnet, A2 Sonnet, A4 Sonnet | as planned | — |
| A3 Opus | as planned | — |
| A5 "Fisher + Rose", Opus, high | **ran on Fable** | **adaptive** |
| — (not in plan) | A1b, **Fable** | **adaptive** |
| A6 Haiku, low | as planned (Brief 1 dispatched Haiku/low) | — |
| Reconcile: Melissa, Sonnet, medium | this document, Sonnet, medium | — |

Both Fable substitutions are **maintainer-prompted**, not model drift: the orchestrator
was told "we have Fable 5 now" between plan approval and A1b/A5 dispatch. Reasoning for
the **adaptive** tag rather than **drift**: (i) the instruction originates from the
maintainer, not from agent discretion; (ii) effort level was preserved (A5 stayed
"high"; A1b's role — a root-cause split the original plan did not anticipate — needed
the higher tier the plan reserved for A3/A5, not the Sonnet tier of A1/A2/A4); (iii) no
scope or claim discipline was relaxed as a result — A5's own claim-discipline section
("no public fence lifted... anything unverified is labelled UNVERIFIED") is intact in
the delivered packet. Direction of the deviation is a **capability upgrade mid-plan**,
not a downgrade or an unrecorded escalation.

## Safety gates

- **Zero new compute**: confirmed structurally (diff above touches only `docs/`; no
  campaign root, no fit, no simulation script ran under this lane's own commits — the
  raw campaign data A1/A1b analysed is lane-B's pre-existing 2026-08-14 output, read
  read-only).
- **Fences untouched**: MSPL-04 register row unedited; `.gllvmTMB_mspl_assert_inference()`
  and the `sdreport()` skip at fit time are not touched by this diff (no `R/` or `src/`
  changes at all).
- **D-139 gate still ahead**: Design 118 §0.3 lists **D1–D6** as required maintainer
  decisions before any Phase-B compute; D2/D3 are explicitly the compute-budget and
  Totoro/DRAC-split decisions the estimate-before-you-run discipline requires. Nothing
  in Phase A pre-empts that gate — the packet is "PRE-REGISTRATION... awaiting
  Shinichi's signature" by its own header, and B0 (the mandatory D-139 pre-run test) is
  listed as **OWED**, not started.
- The lane-B backup push (`e91c7b7c`, force-with-lease) was **user-authorized** per the
  task context; it touches a different branch (`codex/lane-b-mspl-interval-feasibility`),
  not this lane, and is a backup/preservation action, not a compute or claim action —
  assessed as no incremental safety-gate risk to this plan.

## Public claims

None made. No `NEWS.md`, README, article, or exported-function change anywhere in this
lane's diff. The one register-adjacent document touched (Design 117 §6.2) is explicitly
a **pointer**, not a claim of capability — it states the interval design "now lives in
Design 118" and that "Design 88's point-only fence stands until that gate passes." The
Design 118 header states plainly: "No compute is spent, no code is changed, and no
fence is lifted until this document is signed."

## Handoff state

- Branch `claude/mspl-interval-calibration` has **no upstream**; nothing pushed, no PR
  opened — matches the A5 brief's instruction exactly ("do NOT push; do NOT open a PR").
- **Owed at close** (orchestrator responsibility per `A6-BRIEFS.md`, not yet done as of
  this document): (i) promote the jackknife rejection and the Phase-A verdict to
  `shinichi-brain`'s `DECISIONS.md` as a numbered decision — confirmed still outstanding
  by direct search, above; (ii) surface to Shinichi: Design 118 §0.3's **D1–D6** 🔴 list,
  the Phase-B compute ask (45.6 M full vs 26 M reduced fit-equivalents), and the
  PR-or-not question for this lane branch.
- Phase B is fully gated: nothing runs until D1–D6 are signed (Design 118 §0.3); B0 (the
  D-139 local pre-run test) is the first item behind that gate, not yet started.
- A6 Brief 1's mechanical-verify output remains pending at the time of this reconcile;
  it runs in parallel per the dispatch note, so nothing here is blocked on it, but it
  should be checked before the "owed at close" surfacing step treats Phase A as fully
  closed.

## Drift

**Zero drift, zero unclear.** Five deviations from the plan's Phase-A table, all tagged
**adaptive**: A1b added (Fable), A5 run on Fable instead of the planned Opus (both
maintainer-prompted capability upgrades, effort preserved, claim discipline intact), the
orchestrator's evidence-archive commit `8cbb37c7` (durability, prompted by A5's own
closing note that the scratchpad reports are session-local and Design 118 is "the
durable, binding copy"), the orchestrator's mid-flight `orchestrator-spot-checks.md`
(independent verification beyond what the plan required), and the user-authorized
lane-B backup push `e91c7b7c` (outside this plan's slices, on a different branch, no
incremental risk). No plan discipline was bent: zero compute spent, zero fences moved,
zero public claims made, nothing pushed from this lane. The one open item is process,
not defect — the brain-promotion and Shinichi-surfacing steps the plan's own "Also owed
at close" section named are still owed, and are recorded as such here rather than
silently marked done.
