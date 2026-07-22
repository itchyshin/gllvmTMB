# Design 86 lane — parallel EVA design work, decoupled from 0.6

**Decision:** Shinichi, 2026-07-22, in session. Recorded by Claude Code.
**Shape:** start Design 86 now on its own branch; **0.6 stays Laplace-only**; revisit EVA
admission at the **M3 freeze window**, with evidence rather than an estimate.

This file holds (a) the paste-ready GOAL block for the new lane and (b) the reasoning and
fences a future reader needs. The authoritative amendment is `LOOP/GOAL.md` **Amendment 3**.

---

## Why this shape

EVA's cost is not the branch — it is the **release coupling**. `LOOP/ultra-plan.md` makes M3
"the only 0.6 feature-integration window", so *admitting* EVA to 0.6 puts an eleven-step
scientific ladder in front of the release. The old-scope estimate was **4–7 weeks**; the
sparse-binary target Shinichi actually wants is recorded as **UNESTIMATED**. 0.6 is currently
one wording review from closing M1, then ~4–7 agent days plus page reviews.

Decoupling costs nothing, because **the first EVA work is a document, not code.** Design 86 was
never written — `LOOP/decision-queue.md` records it `NOT YET OPEN`, and it exists only as a
sketch in `LOOP/ultra-plan.md` / `LOOP/arcs.md`. Writing it needs no compute, touches no shipped
code, and is required for EVA whenever it lands.

**This does NOT reverse Amendment 1.** 0.6 remains Laplace-only; M2 remains CUT. Amendment 3
authorises *0.7 design work to begin early and in parallel*, which Amendment 1 never forbade —
it only forbade EVA entering 0.6.

---

## 🎯 GOAL — paste verbatim to start the Design 86 lane

```text
PLATFORM: read it from the runtime, do NOT infer it from the task type or the branch name
(D-61). Live R/TMB work does not imply Codex. Whichever tool is running this session owns
the lane. Claude and Codex remain SEQUENTIAL per repo, never concurrent.

WORKSPACE: a NEW worktree OUTSIDE Dropbox — ~/local-scratch/worktrees/gllvmtmb-design86
(D-69: never a worktree inside ~/Dropbox/Github Local/; D-77: worktrees live in
~/local-scratch/). Branch from origin/main. Do NOT reuse or disturb the M1 builder at
/private/tmp/gllvmtmb-060-m1-builder, and do NOT touch the quarantined estate (the dirty
Dropbox checkout, 34 parked worktrees, 7 stashes).

DELIVERABLE: docs/design/86-<name>.md — a WRITTEN, APPROVABLE contract for a narrow EVA
scientific-admission experiment. A design document. NOT an implementation, NOT a campaign,
NOT a public API.

WRITE SCOPE — HARD FENCE: docs/design/86-*.md and its own dev-log entry. NOTHING ELSE.
No R/, no src/, no tests/, no man/, no vignettes/, no DESCRIPTION, no NAMESPACE. This fence
is what makes the lane safe to run beside the release lane; breaking it breaks the
"separate write scopes" condition that permits parallel work at all.

THIS LANE DOES NOT GATE 0.6. 0.6 ships Laplace-only (GOAL.md Amendment 1, unchanged).
Nothing here may block, delay, or be cited by M1/M3/M4/M5. Admission is reconsidered at the
M3 freeze window and not before.

BEFORE ANY DERIVATION, resolve these three — they are cheap desk work and all three are
currently unsettled:

  1. NAME THE ESTIMATOR. Design 85 was full-covariance Gaussian VA (1-D Gauss-Hermite).
     EVA (Korhonen et al. 2023) is a second-order Taylor surrogate. These are DIFFERENT
     estimators and the planning has been sliding between them. State which one Design 86
     targets, in its first section.
  2. CITATION-CHECK the q>=4 threshold. It is recorded UNVERIFIED - source not supplied,
     and it is the claim motivating the sparse-binary target. Do not let it define a gate
     until it is grounded. Prefer stating it as per-unit information per latent dimension
     (about T x median n_it / q) below a predeclared floor, NOT an integer in q.
  3. NEW GATE-0 SCOPE FREEZE. Sparse binary at high q lies OUTSIDE Design 85's admitted
     data contract. This is a fresh scope, not an extension of existing evidence.

SCIENTIFIC CAUTION TO CARRY IN THE DOCUMENT, not discover later: the second-order
surrogate's fixed-order bias is WORST in exactly the sparse regime that carries the user
value. The cell most worth shipping is the cell where this estimator is theoretically
weakest. Design 86 must state that plainly and predeclare what result would CUT it.
Separate the CORRECTNESS ANCHOR (an easy, information-rich cell: is it right?) from the
ADMISSION CRITERION (sparse binary: does it beat Laplace where Laplace is weak?). The
earlier sketch conflated these two and that conflation is what invalidated Design 85's
Gate 4.

BINDING AND UNCHANGED:
- docs/design/85-* is a landed NO-GO and is READ-ONLY. Never amend a closed NO-GO;
  supersede it with a new dated note. Design 85 is UNPROVEN WITH A KNOWN NUMERICAL
  WEAKNESS - it is NOT "the estimator failed". Its predeclared Gate-3 experiment was never
  obtained (the pilot conflated fixed-rank Gate 3 with ML-rank Gate 4) and 8 applicable
  q1/q2 fits failed the optimiser gate. Do not relabel or tune that data into a GO.
- Design 72's sequential proof logic binds: deterministic/fixed-rank proof precedes broader
  rank, family, structured, or public work. A later gate NEVER compensates for an earlier
  failure. No family inherits another's evidence.
- NO EVA objective may be called an ELBO, marginal likelihood, REML objective, or any
  likelihood-comparable quantity unless the approved contract establishes that exact claim.
- docs/design/04-sister-package-scope.md puts VA-as-PRIMARY-engine out of scope and names
  gllvm as the VA alternative. An optional non-default method= is not excluded by that, but
  say so deliberately in the document rather than stepping past it.

COMPUTE: NONE. This lane writes a document. No Totoro, no DRAC, no campaign, and never on
GitHub Actions (D-50). Compute requires a separate maintainer approval AFTER the contract is
approved - that is step 5 of the ladder in LOOP/arcs.md, not step 1.

STOP AT: the finished draft. Approval of the Design 86 contract is Shinichi's act and is
step 2 of the ladder. The lane may not treat its own document, this brief, or GOAL.md as
that approval.

DISCIPLINE: no merge, no tag, no submission, no readiness claim. No exception is
self-granted. Verify by reading the artifact, never an exit code or a negative grep.
Commit messages via `git commit -F` from a file - every -m message with backticks has been
mangled in this repo.

READ FIRST: LOOP/GOAL.md (all THREE amendments) -> docs/dev-log/2026-07-22-design86-lane-brief.md
(this file) -> docs/design/85-highdim-nongaussian-va-formal-contract.md (READ-ONLY) ->
docs/design/72-variational-approximation-feasibility.md -> LOOP/arcs.md (the M2 ladder,
retained verbatim for 0.7 with two corrections a 0.7 reader must apply).
```

---

## Fences a future reader must not lose

- **The lane is design-only.** The moment it writes to `R/` it stops being parallel-safe and
  starts competing with the release lane for the same write scope.
- **"Design 86" is not a contract yet.** Do not cite it as one — anywhere — until Shinichi
  approves the written document. `LOOP/decision-queue.md` records it `NOT YET OPEN`.
- **Admission is a separate decision from the document.** A finished, approved Design 86 buys
  the right to run local gates. It does not admit EVA to any release.
- **The estimate is not transferable.** The 4–7 week and 10–16 week figures price the OLD
  non-sparse scope. The sparse-binary target is UNESTIMATED; do not reuse them.
- **D-74 fan-out budget applies to this lane too**: at most six new children and one
  Sol/Opus child between maintainer checkpoints.

## What this brief does NOT cover

- Whether EVA is ever gllvmTMB's job at all, given `gllvm` occupies that niche (recorded as
  an open question, OQ-3, and deliberately left open).
- Any estimate for the sparse-binary target.
- Any authority to run compute, implement code, or admit a public feature.

> Related: `LOOP/GOAL.md` Amendment 3 · `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` ·
> `LOOP/arcs.md` (M2 ladder, CUT for 0.6 / retained for 0.7) · `LOOP/decision-queue.md`
