# GOAL — gllvmTMB 0.6 single-lane arc-loop

**IMMUTABLE FOR THIS RUN. Re-read this file at the start of every arc.**

## Mission

Take `gllvmTMB` through the evidence required for a truthful 0.6 release
candidate using one continuously owned, semi-autonomous L2 arc-loop. The
approved programme has five serial macro-arcs: M1 release truth and a green
heavy baseline; M2 a new Design 86 scientific-admission experiment for narrow
EVA; M3 public-feature admission; M4 reader-ready candidate construction; and
M5 immutable platform/CRAN ceremony.

Shinichi has put EVA in the intended 0.6 scope. That intent does not override
evidence gates. EVA enters the public package only if the new narrow fixed-rank
experiment passes every sequential scientific and package gate. If it fails,
the automatic 0.6 fallback is Laplace-only.

## Headline

Reliability is the gating variable. Stabilise and qualify M1 before funding
new estimator work. A fast loop that compounds unverified work is failure, not
progress.

## Invariants

- One repository owner, one writer, one mutating macro-arc, one branch, and one
  PR at a time. Claude and Codex are sequential, never concurrent, in this repo.
- The dirty Dropbox primary checkout remains quarantined. Work continues only
  in the clean isolated builder or a clean successor that checks out the exact
  pushed branch.
- Reversible work runs without repeated permission. The loop stops at every
  human gate: scientific contract, remote compute, public EVA admission,
  source/API freeze, candidate freeze, RC/final tags, submission, merge, or
  public release/readiness claim.
- Design 85 remains a closed NO-GO. No q4/q6, no salvage of its mixed Gate-3/4
  pilot, and no universal high-dimensional VA claim.
- M2 starts only after M1 closes. It begins by writing and obtaining approval
  for Design 86; it may not treat this goal file as that approval.
- Design 72's sequential logic remains binding: deterministic/fixed-rank proof
  precedes broader rank, family, structured, or public work. A later gate can
  never compensate for an earlier failure.
- No EVA objective is called an ELBO, marginal likelihood, REML objective, or
  likelihood-comparable quantity unless the approved mathematical contract
  establishes that exact claim.
- Scientific simulations run on Totoro/DRAC only after approval, never on
  GitHub Actions. Totoro is the mandatory smoke/reference host; DRAC is the
  replicated-evidence platform. All attempts and failures remain in the
  denominator and in immutable campaign manifests.
- GitHub Actions is for package checks/docs only. Platform evidence is tied to
  an exact source SHA. Any source edit invalidates later receipts.
- Read the log, not just the exit code; inspect the generated artifact; prove
  the loaded namespace is this checkout before diagnosing a package defect.
- Every arc records what it did not cover, updates `LOOP/checkpoint.md`, and
  updates Mission Control when the material state changes.

## Authoritative detail

- `LOOP/ultra-plan.md` — frozen approved programme and gates.
- `LOOP/arcs.md` — status-marked macro-arcs and current batch.
- `docs/design/85-highdim-nongaussian-va-formal-contract.md` — landed NO-GO.
- `docs/design/72-variational-approximation-feasibility.md` — predecessor and
  sequential proof logic.
- `docs/dev-log/handover/2026-07-20-codex-handover-va-no-go.md` — Design 85
  closeout.
- Latest handover named by `CLAUDE.md` — live resume pointer.

## Definition of done

The loop is complete only when either:

1. a Laplace-only 0.6 candidate, or
2. a narrowly evidence-admitted EVA 0.6 candidate

has a frozen source/tarball identity, clean local package and pkgdown evidence,
green exact-SHA three-OS and heavy package checks, reconciled public claims,
fresh adversarial reviews, and explicit maintainer approval at every remaining
ceremony gate. CRAN submission itself remains a separate maintainer act.

---

# MAINTAINER AMENDMENT — 2026-07-21

**Everything above this line is the ORIGINAL frozen goal and is left intact and
auditable. It was not edited. This block amends it by maintainer decision taken
at a gate, which is the only legitimate way this file changes.**

**Authority:** Shinichi Nakagawa, 2026-07-21, in session. Recorded by Claude Code.

## The decision (verbatim)

- gllvmTMB **0.6 ships Laplace-only**. EVA moves to **0.7**.
- 0.7's EVA should target **sparse binary first**, not the `q = 1` multi-trial cell.
- Failures this arc did not cause may **not** be waived on the agent's judgment;
  each needs individual maintainer sign-off and a durable record.

## What this amendment supersedes above

- **Mission, paragraph 3** — "EVA enters the public package only if the new narrow
  fixed-rank experiment passes every sequential scientific and package gate. If it
  fails, the automatic 0.6 fallback is Laplace-only." The condition is no longer
  live: the fallback is now the chosen route. EVA is not attempted for 0.6.
- **Invariants, "M2 starts only after M1 closes"** — M2 is **CUT** from this
  programme, so it does not start at all. The invariant is retained for 0.7.
- **Definition of done, item 2** — "a narrowly evidence-admitted EVA 0.6 candidate"
  is **VOID**. Item 1, the Laplace-only candidate, is now the sole completion route.

## What is UNCHANGED and still binding

- Design 85 remains a closed **NO-GO**. `docs/design/85-*` is **READ-ONLY**: never
  amend a closed NO-GO; supersede it with a new dated note.
- Design 72's sequential proof logic remains binding for any future EVA work.
- Every gate, quarantine, compute, and claim invariant above stands unchanged.
- The no-ELBO/marginal-likelihood/REML-language rule stands.

## Reasoning, and its epistemic status

The reasoning behind this decision is **AGENT-INFERRED** and is recorded separately
so it is never mistaken for the maintainer's own stated reasons. Two load-bearing
corrections a later reader must not lose:

1. Design 85 is **unproven with a known numerical weakness**, NOT "the estimator
   failed" — its predeclared Gate-3 experiment was never obtained (the pilot
   conflated fixed-rank Gate 3 with ML-rank Gate 4), and 8 applicable q1/q2 fits
   failed the predeclared optimiser gate.
2. **Design 86 was never written or approved.** It exists only as a sketch in
   `LOOP/ultra-plan.md` and `LOOP/arcs.md`; `LOOP/decision-queue.md` records it as
   `NOT YET OPEN`. Do not cite it as an existing contract.

The `q >= 4` threshold that motivates the sparse-binary target is
**UNVERIFIED — source not supplied**, and must be citation-checked BEFORE it is
used to define any 0.7 admission gate. Note also that sparse binary at high `q`
lies **outside Design 85's admitted data contract**, so 0.7 requires a new Gate-0
scope freeze, not a `q`-extension.

Full record: `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`.
