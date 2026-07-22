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

---

# MAINTAINER AMENDMENT 2 — 2026-07-21 (later the same day)

**Authority:** Shinichi Nakagawa, 2026-07-21, in session. Recorded by Claude Code.
Same legitimacy as Amendment 1: a maintainer decision taken at a gate.

## What prompted it

A session `/goal` issued earlier this day carried the discipline line **"stop before any
push/CI spend"** alongside the deliverable **"Close M1 (release truth + qualified head)"**.
Those are contradictory: M1's definition of done requires exact-SHA three-OS platform
evidence, which only CI can produce. The lane obeyed the discipline line and stopped,
leaving M1 unclosable by construction.

The conflict was **accidental**: that discipline line silently revoked a CI authorisation
the standing handover had already granted ("CI spend is authorised. Push, Ubuntu, heavy and
the three-OS matrix are approved — do not re-ask").

## The decision

**CI authorisation is RESTORED.** Push, the Ubuntu run, the heavy run, and the full
three-OS matrix are approved for this arc. **Do not re-ask.** The "stop before any push/CI
spend" line is **superseded** and no longer binds.

## What is UNCHANGED and still binding

- **Every other discipline stands**: no merge, no tag, no submission, no readiness claim.
- **"No exception is self-granted"** stands unchanged. **R-10 still requires the
  maintainer's individual sign-off**, and by the register's own rule an `AWAITING SIGN-OFF`
  row blocks M1's closing claim regardless of CI being green.
- Scientific simulation compute remains **LOCAL only** — this restores *package-check* CI,
  not campaign compute. D-50 stands: no simulation/coverage/power campaigns on GitHub
  Actions, no campaign artifacts there.
- Design 85 remains a closed NO-GO; EVA stays cut to 0.7.

## Sequencing this creates — do not get it backwards

If R-10 is answered **"rewrite"**, it requires source edits, which re-mint the source
identity and **invalidate any receipts and any CI run made before them**. So the order is:
**R-10 decision → apply → freeze → push → CI → third D-43 panel.** Pushing before R-10 is
settled spends a CI cycle on a SHA that is about to change.

---

# MAINTAINER AMENDMENT 3 — 2026-07-22

**Authority:** Shinichi Nakagawa, 2026-07-22, in session. Recorded by Claude Code.
Same legitimacy as Amendments 1 and 2: a maintainer decision taken at a gate.

## The decision

**Design 86 design work starts NOW, on its own branch, in parallel. 0.6 stays Laplace-only.**
EVA admission is reconsidered at the **M3 freeze window**, on evidence rather than an estimate.

## What this does NOT change — read this before concluding anything

**This is NOT a reversal of Amendment 1.** 0.6 still ships **Laplace-only**; **M2 remains CUT**;
Definition-of-done item 2 stays **VOID**. Amendment 1 forbade EVA *entering 0.6*. It never
forbade 0.7's design work *starting early*. Amendment 3 authorises only the latter.

**The new lane does not gate 0.6.** Nothing in it may block, delay, or be cited as evidence by
M1, M3, M4 or M5. If Design 86 is unfinished when M3's freeze window arrives, 0.6 freezes
without it — that is the expected case, not a failure.

## What this DOES amend

**Invariants, "one mutating macro-arc, one branch, and one PR at a time."** A **second lane is
permitted**, on exactly these conditions:

1. **Disjoint write scope.** The Design 86 lane writes `docs/design/86-*.md` and its own
   dev-log entry — **nothing else**. No `R/`, `src/`, `tests/`, `man/`, `vignettes/`,
   `DESCRIPTION`, `NAMESPACE`. Separate write scopes are what makes parallel work legal here
   (`CLAUDE.md`, Collaboration Rhythm); breaking the fence dissolves the permission.
2. **Separate worktree, outside Dropbox** — `~/local-scratch/worktrees/` (D-69, D-77).
3. **Design-only.** No implementation, no campaign, no compute, no public API.
4. **Still sequential per tool.** Claude and Codex do not run concurrently on this repo; the
   two *lanes* are separated by write scope, not by running two tools at once.

The single-writer rule otherwise stands, and returns in full the moment the Design 86 lane
attempts anything outside its fence.

## Three prerequisites, unresolved, before any derivation

1. **Name the estimator.** Design 85 = full-covariance Gaussian VA (1-D Gauss–Hermite);
   EVA (Korhonen et al. 2023) = second-order Taylor surrogate. **Different estimators.** The
   planning has been sliding between them.
2. **Citation-check the `q >= 4` threshold** — recorded **UNVERIFIED, source not supplied**.
   It must not define a gate until grounded.
3. **A new Gate-0 scope freeze.** Sparse binary at high `q` lies **outside** Design 85's
   admitted data contract — a fresh scope, not an extension of existing evidence.

## Scientific caution to carry into the document

The second-order surrogate's fixed-order bias is **worst in exactly the sparse regime** that
carries the user value. Design 86 must state this plainly and **predeclare what result would
CUT it**, and must separate the **correctness anchor** (easy, information-rich: is it right?)
from the **admission criterion** (sparse binary: does it beat Laplace where Laplace is weak?).
Conflating those two is what invalidated Design 85's Gate 4.

## Unchanged and still binding

- `docs/design/85-*` remains a closed **NO-GO** and **READ-ONLY** — supersede with a new dated
  note, never amend.
- **Design 72's** sequential proof logic; the **no-ELBO/marginal-likelihood/REML** language rule.
- Every compute, claim, and ceremony gate above. **No exception is self-granted.**
- **Design 86 is not a contract until Shinichi approves the written document.**
  `LOOP/decision-queue.md` records it `NOT YET OPEN`. The lane may not treat this amendment as
  that approval.

Full brief and the paste-ready lane GOAL: `docs/dev-log/2026-07-22-design86-lane-brief.md`.
