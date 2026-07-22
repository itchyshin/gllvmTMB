# Codex handover — Design 86, Gate 1 (EVA sparse-binary feasibility)

**Meta:** 2026-07-22 · from Claude Code (design86 lane) · to **Codex** · cross-tool, sequential.
**WORKSTREAM TRANSFER — executed ARC BY ARC, maintainer-driven.** You are Codex, receiving the whole
EVA feasibility workstream, but the maintainer drives it **one arc at a time**: you do an arc, verify
it, **STOP, and report**; the maintainer reviews and hands you the next arc as a separate task.
**This hand-off is Arc 1 only** (Gate 0 + Gate 1). The gate ladder below is the full map so you know
where Arc 1 sits — it is **not** a licence to run ahead. This doc stands alone; you will not see the
Claude chat that produced it. Read it, then the two in-repo files it points to, and you have
everything.

---

## Critical context — read this or go wrong

1. **The contract is APPROVED (maintainer, 2026-07-22), but this is a *feasibility probe*, not a
   feature.** You are proving whether an estimator is correct, not shipping it. Nothing you build
   touches the 0.6 release surface.
2. **0.6 ships Laplace-only and must stay byte-unchanged.** Do **not** modify `src/gllvmTMB.cpp`,
   `NAMESPACE`, `DESCRIPTION`, `NEWS`, any vignette, or any `man/` page. EVA lives in a **standalone
   prototype template** + an **unexported** R driver. This is the whole reason this lane is allowed
   to exist beside the release lane — if you touch the shipped surface, that guarantee is gone.
3. **Two documents are your turnkey spec. Read both before writing a line of code:**
   - `docs/design/86-eva-sparse-binary-admission-contract.md` — the approved contract. The math is
     §5.1 (objective, **note the `+ q` KL constant**), §5.3 (the bound-property derivation — already
     done, you *reproduce* it), §7 (numerical requirements — hard rules), §11 Gate 0 + Gate 1.
   - `docs/design/86-gate1-build-brief.md` — the build brief. It names the four deliverables, the
     verification matrix, the reuse map, and the file layout. **Follow it; it defers every tolerance
     to the contract so the two cannot drift.**
4. **This hand-off is Arc 1 = Gate 0 + Gate 1 ONLY.** Do Gate 0 (freeze the parameter file) and
   Gate 1 (the algebra/autodiff/bound probe), verify, then **STOP and report.** The maintainer
   reviews and hands you Arc 2 (Gate 2) as a **separate** task. **Do NOT roll on into Gate 2 or 3
   yourself** — the maintainer is driving this arc by arc, and reviews between arcs. (Approval does
   cover Gates 0–3 in principle, but the cadence is one arc per hand-off, not a run-through.) Gate 4
   is the coverage campaign — a separate compute approval, far past this arc; do not run any compute
   campaign.
5. **The headline scientific finding is already in hand and it is a caution, not a green light:**
   §5.3 proves EVA's objective is **not a bound in the sparse regime** (`p̄ < 0.211` — the whole
   admitted `z ∈ [0.90, 0.97]` band). Gate 1's bound-probe *observes* that overshoot; it does not
   fix it. Do not let a clean Gate-1 pass be read as EVA being fit for purpose — it licenses Gate 2
   and nothing else.

---

## What was accomplished (the design lane, now closed)

- The Design 86 EVA contract was written, twice-reviewed by adversarial D-43 panels, and **approved**.
  Round 2 independently re-derived §5.3 from scratch (confirmed the fourth-derivative sign flip at
  `(3±√3)/6`) and confirmed the Gate-4 CUT can fire.
- The `q >= 4` threshold that once motivated this work was traced to a single `url: null` corpus
  entry and **retired** — do not reintroduce it.
- A Gate-1 build brief was written so you do not re-derive what to build.
- Full arc: `docs/dev-log/2026-07-22-design86-lane-research-and-ultra-plan.md`.

## Current working state

- **Working / landed:** the contract, the build brief, and the lane dev-log are committed and pushed
  on branch **`claude/design86-eva-contract-20260722`** (tip after this handover). That branch is
  `origin/main` + docs-only commits, so it contains **all of main's code** (including the `va_r3`
  assets you will reuse) plus the approved contract.
- **Not merged:** the design86 branch is **not** merged to `main` (the design lane was under a
  no-self-merge rule). You do **not** need it merged — branch your Gate-1 work off the design86
  branch directly and you inherit both the contract and the code.
- **Not started:** all code. Gate 0 has not run; the frozen parameter file does not exist yet.

---

## Execution model — arc by arc, maintainer-driven (NOT a loop)

The maintainer hands you **one arc at a time**. You do that arc, verify it, **STOP, and report.** The
maintainer reviews, then hands you the next arc as a separate task. There is no autonomous loop and
nothing to "continue" while you wait: the gates are strictly sequential (Design 72), so a later arc
cannot start until this one passes, and a later gate never compensates for an earlier failure. The
arcs are:

- **Arc 1 = Gate 0 (freeze) + Gate 1 (objective correctness)** — this hand-off.
- **Arc 2 = Gate 2** (correctness anchor) — handed separately after Arc 1 passes.
- **Arc 3 = Gate 3** (reference comparison) — after Arc 2.
- **Arc 4 = Gate 4** (admission campaign) — needs a separate compute approval + target; smoke-first.

## Arc 1 — the ultra-plan (do this, then STOP)

**0. Set up.** Branch a fresh worktree off `origin/claude/design86-eva-contract-20260722`, outside
Dropbox (`~/local-scratch/worktrees/`), e.g. `codex/design86-arc1-<date>`. It inherits all of main's
code (incl. the `va_r3` assets) plus the approved contract.

**1. Orient.** Read contract §5.1 (objective, **with `+ q`**), §5.3 (bound derivation), §7 (numerical
rules), §11 Gate 0/1, and build brief §4–5.

**2. Build the slices** — mostly yourself; they are small and interdependent, so do **not** shard
them across parallel sub-agents (you would create integration seams for no speed gain):

| Slice | Deliverable | Note |
|---|---|---|
| **S0** | Gate 0: freeze + checksum the parameter file (contract §2.5); record the checksum in the contract §2.5 / Status | first; Gate-1 fixtures are tiny but the file must exist + be checksummed |
| **S1** | D1: pure-R scalar oracle for `ell_EVA` (Bernoulli-logit, §5.1, **+ q**), no code shared with the template | the independent yardstick |
| **S2** | D2: EVA objective in a **standalone** `inst/tmb/gllvmTMB_eva.cpp` + unexported `R/eva-proto.R`, `random = NULL` | the shipped `src/gllvmTMB.cpp` stays byte-unchanged |
| **S3** | D3: AGHQ bound probe at `q = 1` (reuse `.va_r3_gh_rule`) — a **measurement**, observes the §5.3 overshoot | needs S2 |
| **S4** | D4: reproduce §5.3 in code (finite-diff `s''''`, MC sign of `E_q[R]` for `p̄ < 0.211`) | standalone |

**3. Verify — the fan-out lives here, not in the build.** Run the verification matrix (brief §5):
identities to `1e-10` (S2 template vs S1 oracle, plus the Gaussian exactness identity), gradients to
`1e-5`, small-`v` continuity, the quadrature oracle. Honour every §7 rule — the `+ q` constant,
stabilised `softplus` (`η` runs far negative here by construction), the small-`v` limit, loud failure
on any non-finite value. Then **fan out a 3-lens adversarial panel** (each defaulting NOT-DONE, ≥2
withhold): **(a) math** — code matches §5.1/§5.3; **(b) numerics** — softplus/small-`v`/finiteness,
no clipping, `+ q` present; **(c) scope** — standalone template, shipped surface untouched, nothing
over-claimed.

**4. Consolidate, then STOP.** After-task report under `docs/dev-log/after-task/`; **Rose review
before any "Arc 1 passed" claim** (`.codex/agents/*.toml`); then STOP and report to the maintainer.
**Do not begin Arc 2.**

**Arc 1 is done when:** the frozen file exists + its checksum is recorded; the template matches the
oracle to `1e-10` and the Gaussian identity holds; gradients match finite differences to `1e-5`; the
bound probe has *observed* the sign of `ell_EVA − log p(y)` at `q = 1` (the §5.3 overshoot, in code);
no numerical rule is violated; `src/gllvmTMB.cpp` is byte-unchanged; and the panel + Rose clear it.
**A pass licenses the maintainer to hand you Arc 2 — nothing else.**

## Blockers / open questions (for the maintainer, not for you to self-resolve)

- **Gate-4 compute** is a separate approval. Do not run it.
- **Merging the design86 branch to `main`** is a maintainer decision (docs-only, low-risk, but the
  design lane held a no-self-merge rule). Not required for your work.
- **The ledger** `LOOP/decision-queue.md:10` still reads `CUT 2026-07-21` and the CLAUDE.md snapshot
  pointer still points at the release (M1) lane — both are the **release lane's surface**; do not
  edit them from this lane. Correcting the ledger to reflect approval is a release-lane action.

## Gotchas / failed approaches — do not repeat

- **The parked Phase-1 VA prototype (`origin/claude/va-phase1-proof`) is NOT your anchor.** It is
  mean-field diagonal *closed-form* VA — **not EVA**, no loadings, no `Sigma_B`, no Taylor surrogate.
  Citing it as Gate-2 evidence is the exact error class (inheriting an artifact's status across a
  boundary) that produced Design 85's NO-GO. Context only.
- **Design 85 is a closed NO-GO and READ-ONLY.** You reuse its *apparatus* (`gllvmTMB_va_r3.cpp`
  quadrature, `softplus`, log-Cholesky) but **inherit none of its results** — and only after a fresh
  derivation audit (contract §11 Gate 0 NO-GO).
- **Do not clip `η` or form `S_i`/determinants/inverses directly** (§7). In the sparse regime `η`
  runs far negative; naive `log(1+exp(η))` or `sqrt(v)` at `v=0` will bite.
- **`data.list$random` in the gllvm/va_r3 pattern is a modelling flag** (`DATA_IVECTOR`), **not**
  TMB's `random=` mechanism. Under EVA there is no `random=` at all — the variational coordinates are
  ordinary parameters (contract §4, §7.8). Reading it wrong inverts the whole method.

---

## The full gate ladder (0→5) — the map, handed one arc at a time

You receive the EVA feasibility lane in full, but it is **handed to you one arc at a time** (see the
execution model above) — this table is the map so Arc 1 sits in context, **not** a licence to run
ahead. The gates are **sequential** (Design 72): a later gate never compensates for an earlier
failure, and tolerances are never widened after a result is seen. Full text and NO-GO lists are in
contract §11.

| Gate | Arc | Proves | One-line NO-GO |
|---|---|---|---|
| **0 — freeze** | Arc 1 | scope + coordinates locked; parameter file exists + checksummed | any implicit `Psi`, `n_it≠1`, checksum mismatch, or parked VA source reused without a fresh derivation audit |
| **1 — algebra** | Arc 1 | the objective is implemented correctly and numerically sane on tiny fixtures | omitted constants (incl. `+q`), wrong KL sign, clipping for finiteness, Gaussian identity fails, bound question unresolved |
| **2 — anchor** | Arc 2 | recovery is right on an information-rich (non-sparse) cell | recovery outside the numeric tolerances §11 G2 states; single-start reliance |
| **3 — reference** | Arc 3 | EVA vs the Gauss–Hermite reference at fixed coordinates = pure Taylor error | family mismatch between arms; a one-sided bound test; **tolerances not re-derived for this regime** |
| **4 — admission** | Arc 4 | interval **coverage** across the n-ladder + the T/z second ladder | **separate maintainer + compute approval**; see below |
| **5 — claim audit** | — | nothing public follows without a separate maintainer decision | — |

**Report and STOP after every arc.** Arc 4 additionally needs a compute approval and is the next
platform boundary that returns to the maintainer regardless.

### Gate 4 compute — the plan, for when it is approved (do NOT run it now)

- **Where:** Totoro (≤100 cores, no queue) or DRAC job arrays (one seed per `$SLURM_ARRAY_TASK_ID`).
  Multi-seed coverage over the ladder points to DRAC arrays; Totoro if it fits and you want it
  faster. **Never GitHub Actions, never store outputs as GH artifacts (D-50); results stay local.**
- **Smoke first — the D1 lesson:** run **one cell / tiny n / one rep**, confirm NON-EMPTY, in-range
  output, **read the log**, inspect one fit past its guards. A harness can pass every pre-check then
  die after drawing seeds. Only then park "Gate-4 campaign ready — smoke green, launch on
  <Totoro|DRAC>?" for the maintainer's go.
- **Both arms' convergence criteria must be frozen** (contract §2.5, added after review): an
  asymmetry between "failed Laplace" and "failed EVA" moves the paired margin for reasons unrelated
  to accuracy. This is a NO-GO if left implicit.

### The roadmap beyond this contract (contract §14 — NON-BINDING, not a gate)

The eventual differentiator is **not** "do EVA" — gllvm already does EVA, and even structured
(Kronecker) VA. It is **EVA whose KL term is taken against gllvmTMB's exact sparse precision** (the
Hadfield `A^{-1}`, Design 47; the SPDE `Q`, Design 64) rather than gllvm's nearest-neighbour GP
approximation — the checkable claim being "no nearest-neighbour ordering artefact." Plus
mixed-response GLLVMs (the stacked-trait long format already supports it). Each needs its own scope
freeze, derivation, and gates; none inherits this contract's evidence. **Do not build toward this
during feasibility** — it is recorded so the direction is not lost.

### Review history — settled, do not re-litigate

The contract survived **two D-43 adversarial panels** (3 fresh reviewers each, default NOT-DONE).
Round 1 found real structural defects (an un-fireable CUT rule; a `+q` KL-scale bug) — fixed.
Round 2 verified those fixes and found only editorial seams — fixed. The §5.3 bound-property
derivation was **reproduced independently from scratch** by a ceiling reviewer and is settled: your
Gate-1 D4 confirms it in code, it does not re-open it. The full arc is in
`docs/dev-log/2026-07-22-design86-lane-research-and-ultra-plan.md`.

### The design family (how the numbered docs relate)

- **Design 72** — the *sequential proof logic* (this ladder's discipline). Not an implementation spec.
- **Design 85** — a landed **NO-GO, READ-ONLY**. You reuse its *apparatus* (`va_r3` quadrature),
  inherit **none** of its results, and only after a fresh derivation audit.
- **Design 04** — package boundary: VA-as-*primary*-engine is out of scope; gllvm is the VA
  alternative. An optional non-default research path is not excluded, but this contract admits no
  public `method=` surface (Gate 5).
- **Design 43** — the Gaussian-only REML-language reservation. EVA may **not** borrow REML/AI-REML
  language (contract §10).
- **drmTMB Design 160** — the sibling GVA gate; source of the `DATA_INTEGER(method)` flag pattern
  you would use *only at graduation*, never during feasibility.

## How to resume (one paste, in your own terminal at the repo root)

```
Rehydrate from docs/dev-log/handover/2026-07-22-codex-handover-design86-gate1.md plus the two
files it points to (docs/design/86-eva-sparse-binary-admission-contract.md and
docs/design/86-gate1-build-brief.md). Execute ARC 1 ONLY: branch off
origin/claude/design86-eva-contract-20260722, do Gate 0 (freeze + checksum the parameter file)
then Gate 1 (slices S0–S4), run the verification matrix + a 3-lens panel, write an after-task +
Rose review, then STOP and report. Do NOT begin Gate 2 — the maintainer hands the next arc.
```

### Live-toolchain env (Codex runs the real build; Claude could not)

This is an R package with a TMB `src/`. You compile and run what Claude only specified:

```sh
export NOT_CRAN=true
# from the repo root, in your Gate-1 worktree:
Rscript -e 'TMB::compile("inst/tmb/gllvmTMB_eva.cpp")'      # your new prototype template
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-eva-gate1.R")'
```

Adjust to the repo's actual build convention (`src/Makevars` exists; the shipped DLL is
`gllvmTMB`). Keep your prototype template and its object files out of the shipped build if they would
otherwise be picked up — a standalone `inst/tmb/` template compiled on demand (as `va_r3` is) avoids
that.

---

## Mission control

| Item | State |
|---|---|
| Design 86 contract | **APPROVED** 2026-07-22; on branch `claude/design86-eva-contract-20260722`, not merged |
| Gate-1 build brief | Written, turnkey — `docs/design/86-gate1-build-brief.md` |
| **Arc 1** = Gate 0 (freeze) + Gate 1 (algebra/autodiff/bound probe) | **THIS HAND-OFF — NOT STARTED.** Do it, verify, STOP, report |
| Arc 2 (Gate 2, anchor) · Arc 3 (Gate 3, reference) | Handed **separately** by the maintainer after the prior arc passes — do not start them yourself |
| Arc 4 (Gate 4, coverage campaign) | **FENCED** — separate maintainer + compute approval |
| Shipped surface (`src/gllvmTMB.cpp`, NAMESPACE, …) | **DO NOT TOUCH** |
| Release (M1) lane | Separate lane, separate checkout; do not edit its surfaces (`LOOP/`, CLAUDE.md pointer) |

**One-line routing:** the EVA feasibility workstream is yours (live TMB build, isolated worktree,
standalone prototype template), but **executed arc by arc — the maintainer hands one arc, you do it,
verify, STOP, report.** Claude did the design + the two review panels and has closed the design lane.
The next platform boundary that returns to the maintainer is Arc 4 (Gate 4 compute).

**Transfer confirmation.** Nothing about this lane remains on Claude's side. The durable record is:
this handover + the approved contract + the Gate-1 build brief (all on branch
`claude/design86-eva-contract-20260722`), the full arc dev-log
(`docs/dev-log/2026-07-22-design86-lane-research-and-ultra-plan.md`), and the brain note
*"Design 86 EVA contract — APPROVED, Gate 1 to Codex (2026-07-22)"*. If any of those is unreadable,
say so before proceeding rather than reconstructing from assumption.
