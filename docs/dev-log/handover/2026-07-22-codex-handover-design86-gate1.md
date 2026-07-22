# Codex handover — Design 86, Gate 1 (EVA sparse-binary feasibility)

**Meta:** 2026-07-22 · from Claude Code (design86 lane) · to **Codex** · cross-tool, sequential.
You are Codex, picking up the **first coding rung** of an approved feasibility experiment. This doc
stands alone; you will not see the Claude chat that produced it. Read it, then the two in-repo files
it points to, and you have everything.

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
4. **Your scope is Gate 0 + Gate 1 ONLY.** Approval unlocked Gates 0–3. Do Gate 0 (freeze the
   parameter file) and Gate 1 (the algebra/autodiff/bound probe). You *may* proceed into Gate 2 and
   Gate 3 if Gate 1 passes cleanly, but **STOP at the Gate-3 boundary** — Gate-4 (the coverage
   campaign, needs Totoro/DRAC) is a **separate, later maintainer approval**. Do not run any
   compute campaign.
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

## Next immediate steps — in order

1. **Branch a fresh worktree off the design86 branch**, outside Dropbox (repo convention: worktrees
   live under `~/local-scratch/worktrees/`). E.g. branch `codex/design86-gate1-<date>` off
   `origin/claude/design86-eva-contract-20260722`.
2. **Gate 0 — freeze the parameter file.** Build the single machine-readable frozen file the
   contract §2.5 specifies (the `n` ladder, the `T`/`z` second ladders, `R`, `T`, `q`, planted
   `beta`/`Lambda`, zero-fraction target, `I_unit` floor, the named Schur-complement covariance
   estimator, **both arms' convergence criteria**, the full per-replicate seed list, and the
   denominator rules). Compute its checksum and **record it in the contract's §2.5 / Status** (that
   edit is now in-scope for the coding lane). Gate-1 fixtures are tiny and may not need every field,
   but the file must exist and be checksummed.
3. **Gate 1 — the four deliverables from the build brief (§4):**
   - **D1** a pure-R scalar oracle for `ell_EVA` (Bernoulli-logit, §5.1, **with `+ q`**), sharing no
     code with the template;
   - **D2** the EVA objective in a **standalone** `inst/tmb/gllvmTMB_eva.cpp` + unexported
     `R/eva-proto.R`, `random = NULL` in `MakeADFun`;
   - **D3** the AGHQ marginal bound probe at `q = 1` (reuse `.va_r3_gh_rule` from `R/va-r3-proto.R`);
   - **D4** a checked-in reproduction of the §5.3 derivation (finite-difference `s''''`, MC sign of
     `E_q[R]` for `p̄ < 0.211`).
4. **Run the verification matrix (brief §5).** Identities to `1e-10`, gradients to `1e-5`, small-`v`
   continuity, quadrature oracle. Honour every §7 numerical rule — the `+ q` constant, stabilised
   `softplus` (`η` runs far negative in this regime by construction), the small-`v` limit, loud
   failure on non-finite values.
5. **If Gate 1 passes:** you may continue into Gate 2 (correctness anchor, information-rich cell) and
   Gate 3 (EVA-vs-GH reference at fixed coordinates), each with its own contract tolerances — **but
   STOP at the Gate-3 boundary and hand back for the Gate-4 compute approval.**
6. **Before any "done" claim:** run the repo's mandatory review lens (Rose, `.codex/agents/*.toml`),
   and write an after-task report under `docs/dev-log/after-task/`.

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

## How to resume (one paste, in your own terminal at the repo root)

```
Rehydrate from docs/dev-log/handover/2026-07-22-codex-handover-design86-gate1.md plus the two
files it points to (docs/design/86-eva-sparse-binary-admission-contract.md and
docs/design/86-gate1-build-brief.md), then execute the Next Immediate Steps: branch off
origin/claude/design86-eva-contract-20260722, do Gate 0 (freeze + checksum the parameter file),
then Gate 1 (D1–D4), stopping at the Gate-3 boundary.
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
| Gate 0 (freeze param file) | **NOT STARTED** — your first action |
| Gate 1 (algebra/autodiff/bound probe) | **NOT STARTED** — D1–D4 in the brief |
| Gates 2–3 | Optional continuation if Gate 1 passes; STOP at the Gate-3 boundary |
| Gate 4 (coverage campaign) | **FENCED** — separate maintainer + compute approval |
| Shipped surface (`src/gllvmTMB.cpp`, NAMESPACE, …) | **DO NOT TOUCH** |
| Release (M1) lane | Separate lane, separate checkout; do not edit its surfaces (`LOOP/`, CLAUDE.md pointer) |

**One-line routing:** Codex builds and runs the live TMB Gate-1 code in an isolated worktree behind a
standalone prototype template; Claude did the design and the two review panels. The next platform
boundary is Gate 4, which neither tool starts without a fresh maintainer approval.
