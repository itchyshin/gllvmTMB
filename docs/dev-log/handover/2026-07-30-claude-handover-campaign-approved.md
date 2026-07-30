# Claude → Claude handover — session CLOSED; the re-aimed campaign is APPROVED and unstarted

Date: 2026-07-30. Author: Claude. Target: **Claude** (same platform).
Supersedes: `2026-07-30-claude-handover-lane-transition.md` (merged as #850; still accurate on the
gaussian arm, superseded on next steps).
Lane map: `2026-07-25-active-lane-split.md`.

**You are Claude, starting the approved campaign.** Everything before it is merged and closed.
Nothing is blocked on compute or on Shinichi. **Your first substantive act is to open a new lane
and ultra-plan the campaign — the design below is a starting point, not a finished plan.**

## Mission control

| item | state |
|---|---|
| **`main`** | `bef1a5aa` — #840 and #850 both MERGED. `--as-cran` 0E/0W/1N; CI green |
| **lanes closed this session** | `claude/vgh-pluralism-20260730` (#840) and `handover/2026-07-30-claude` (#850). **Both worktrees removed** |
| **next arc** | **VGH degeneracy at scale — APPROVED by Shinichi 2026-07-30, option (a). NOT STARTED.** |
| **scope** | `docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md` (943 lines) — **read its "READ FIRST" section before planning** |
| **your first act** | fresh branch + worktree off `main`, then **ultra-plan** the re-aimed campaign |
| **D3** | request brief landed at `docs/dev-log/handover/2026-07-30-request-to-la-aghq-ridge-lane-take-D3.md`; Shinichi is routing it. **Not your lane — do not act on it.** |
| **fenced** | every other lane on the split board, and the LA + AGHQ + ridge lane |

## Why the campaign was re-aimed — the single most important thing to absorb

**Shinichi approved option (a): run the re-aimed campaign** — map where the boundary is, and whether
the region VGH wins in is big enough to justify an engine. He chose it knowing the alternative
(don't bother) had become a live answer.

**The original framing is dead.** It was *"VGH is 0/148 degenerate — does that survive at scale?"*
Ten probe fits at the corner the design would have extended into answered it **before any production
fit**: `.vgh_fit()`, binomial-logit, Q=15, the same 148-fit DGP, seeds 1–4, at **n=40 / p=80 / q=4**:

| | observed |
|---|---|
| `rel_frob` | **10.671 / 10.449** on 2 of 4 seeds — degenerate by the `> 10` definition |
| `atten_F > 2` | **4 of 4** |
| `max\|Λ\|` | **8.53 – 12.53** |
| `converged` | **TRUE on every one** |

**Two consequences, and the second one is easy to miss:**

1. **VGH's tail advantage is regime-bounded, not general.** The 0/148 held at **n ≥ 60, p ≤ 12,
   q = 2** — and `q` was **never a grid column** in `dev/heywood/vgh-vs-laplace-degeneracy.R`; it is a
   module scalar at `:30`, fixed at 2. So the claim never covered the axis that appears to drive the
   failure.
2. **🔴 `converged = TRUE` on degenerate VGH fits, structurally** — `R/va-vgh.R:603` only tests
   `outer < maxit`. **VGH's convergence flag is not a health signal either.** This lane had treated
   "98% silent failure" as Laplace's distinguishing defect; it is **shared**. The standing discipline
   — health is recovery against known truth, *never* convergence — applies to **both** engines.

**So the campaign's question is now:** *where is the boundary in (n, p, q), and is the region where
VGH wins large enough to be worth an engine?* **Not** *"does the advantage survive?"* (answered: no,
at q=4 / p=80).

**Do not open an engine-building arc on the strength of the 0/148 figure.**

## A suggested design — treat as input to your ultra-plan, not as the plan

The scope doc's grid (3,570 fits) was costed for the *old* question. A boundary-mapping question
wants a different and probably smaller shape, because **three axes moved at once in the probe**, so
which one drives the failure is **not established** — the scope's "q looks like the primary driver"
is an inference, not a measurement.

**Stage 1 — marginal sweeps from the known-good corner, to find the driver.** Baseline
n=100, p=12, q=2 (inside the 0/148 regime). Then vary **one axis at a time**:
- `q ∈ {2, 3, 4, 5}` at n=100, p=12
- `p ∈ {12, 24, 48, 80}` at n=100, q=2
- `n ∈ {40, 60, 100, 200}` at p=12, q=2

Both arms (`.vgh_fit()` + Laplace), ~20 seeds for a rate. ≈ 10 unique cells → ~400 fits. This is
cheap and it is the experiment that actually identifies the driver.

**Stage 2 — refine around wherever Stage 1 puts the boundary**, plus the interaction corners. Size
it from Stage 1's answer rather than guessing now.

**Seed on every design axis** — two scripts in the previous arc failed to (`gaussian-collapse.R:69`
did not seed on `n`; `gaussian-degeneracy-reachability.R:29` did not seed on regime), which silently
cut effective replication.

## Hard constraints, all measured — see the scope doc for citations

- **Use `R/va-vgh.R::.vgh_fit()`** (in-package, so results transfer). `dev/vgh/vgh-engine.R::vgh_fit()`
  **cannot run multi-trial binomial at all** — no `n_trials` argument, its warm start hardcodes the
  Bernoulli denominator (`:360`, NaN for y ≥ 2, dies in `eigen`), and its ELBO omits the `n_trials`
  multiplier. Bernoulli-only: not a fallback, not a cross-check.
- **`.vgh_fit()` rejects probit and cloglog**, so **no same-link VGH-vs-`gllvm` binomial head-to-head
  is possible** (`gllvm`'s VA is probit-only for binary). Any such comparison is cross-link — say so.
- **`latent(..., unique = FALSE)` only** — so the campaign's fits are **not** of the default
  user-facing model, which has carried Psi since 2026-06-18. Disclose this.
- No per-trait covariates; no missing cells; `q ≤ 6`.
- **`.vgh_fit()` is self-fenced** `research_only = TRUE, model_selection_comparable = FALSE`
  (`R/va-vgh.R:606-607`). Any claim must carry that fence.
- **Neither engine can be multi-started** without code changes (deterministic eigendecomposition
  inits, no start argument). If you need "bad basin" separated from "the maximum IS bad", that
  separation is not currently producible — and note the warm-start route was already **refuted** for
  the analogous Laplace problem (*"the runaway IS the maximum-likelihood solution"*, three
  independent confirmations, **do not re-litigate**). Make it an explicit design decision.

## Compute — and it is NOT the constraint

At the scope's sizing the whole thing is **~13.5 CPU-hours**; the Stage-1 design above is a small
fraction of that. **Local is viable and avoids the Totoro blocker entirely.** If you do go remote:

- **🔴 Totoro's installed `gllvmTMB` does NOT contain the VGH engine.**
  `exists(".vgh_fit", asNamespace("gllvmTMB"))` → **FALSE**, and no source tree on the box has
  `va-vgh.R`. It was built **2.5 h after** `R/va-vgh.R` reached `main` but **not from `main`** — so
  **VGH presence cannot be inferred from the version string or the build date.** Push source and
  reinstall first, or the VGH arm errors on every cell.
- **🔴 Re-running `run-grid.R` as-is would CLOBBER the 2026-07-26 grid results** — the very numbers
  the lane brief cites as its evidence base. New directory **and** new `tag`.
- **Totoro's shared `$HOME`** holds Codex-owned `design9*` / eta material that `CLAUDE.md` fences.
  Fresh directory only.
- **`run-grid.R` has no resume and no per-fit budget** (`FITSEC` accepted, never used; one original
  cell ran 3742.7 s). Reuse `dev/scale/run-scale.R:303`'s per-cell `saveRDS` + callr budget.
  **Do NOT use `setTimeLimit`** — `dev/scale/SCALE.md:164-167` records that it HUNG.
- Results stay **LOCAL (D-50)** — never GitHub artifacts.

## Two reporting-layer defects to fix, not inherit

- **`analyse-grid.R:100`** uses an **unanchored** `grepl("pdHessTRUE|healthy|converged", status)`,
  which **already produced a published wrong number** (RESULTS.md:117's 203 should be 160). Replace
  with exact matching, and **never give an arm a status vocabulary where a failure label contains a
  success substring** (i.e. never `not_converged`).
- **`analyse-grid.R:85`** medians over *all* finite rows with no status filter. "Degeneracy rate among
  fits the engine calls good" is a different question — decide which one you are asking.

## Metrics and the health definition

Recovery against known truth, **never** convergence — now doubly so, since **both** engines report
`converged = TRUE` on degenerate fits. Report **both** degeneracy definitions in circulation
(`rel_frob > 10`; `atten_F` outside [0.2, 2]) because they disagree, and carry the warning that both
are **truth-normalised** so they false-positive when true Λ is small — **check absolute loading
magnitude alongside** (in the previous arc the "degenerate" fits had loadings *half* the size of the
healthy ones).

Also: `loading_absolute_thresh = 6` is **binomial-gated** (`R/diagnose.R:464-471`) and never
evaluates on a gaussian fit — but this campaign **is** binomial, so it does apply here. Its
justification is logit-scale, which is the right scale for binomial.

## Gotchas carried forward

1. **A resume command is executable instruction.** A one-word compression (`gaussian_anchor` → "VGH")
   inverted a fact that the next session acted on before reading the evidence. Name engines exactly.
2. **`test-vgh-oracle.R` requires `devtools::load_all()`** — against the installed package it errors
   11 of 12 tests with `could not find function ".vgh_fit"`. Reads as failure, is not.
3. **A metadata flag proves nothing about the math** — `expect_true(fit$phi_pool)` survived a break
   that inverted the behaviour it names.
4. **Never analyse a driver's console log for precision** — `%+9.5f` rounded a real ~1e-7 residual to
   `-0.00000` and I nearly published "exactly zero".
5. **Fire the adversarial gate BEFORE publishing.** The previous arc's one real process drift: the
   gate was scheduled first but ran after both result docs were pushed, and it then refuted a
   headline — which had already reached another lane's message bus.
6. **Check a threshold applies before comparing to it.** I compared a gaussian quantity to a
   binomial-gated, logit-scaled constant and had to withdraw the claim.

## Files this session (all merged)

#840: the gaussian arm — see `docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`.
#850: `docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md`,
`docs/dev-log/handover/2026-07-30-claude-handover-lane-transition.md`, the lane-board rows, the
`CLAUDE.md` snapshot, and a correction to a stale `check-log.md` entry of my own.
This handover adds: this file, `docs/dev-log/handover/2026-07-30-request-to-la-aghq-ridge-lane-take-D3.md`,
and the board/snapshot refresh.

## Plans / roadmap beyond this arc — carried forward, do not narrow

- **EVA — standing interest (Shinichi, 2026-07-25):** *"I am still interested in EVA stuff too —
  please remember."* Cut to **0.7**, **Codex-owned**. Picking it up is a lane-reassignment decision,
  not agent initiative. **Keep it on the menu; raise it with him.**
- **⚠ `claude/va-implementation-20260725` is DO-NOT-MERGE** pending Shinichi's Design-85 §10 decision.
- **0.6 release** — rung **NOT READY**; the real blocker is the one-by-one docs review *with him*.
- **Profile / Tier-2a**, **HVT-1** (`ORACLE_NOT_CERTIFIED`), **Design-103** (closed), **docs-infra** —
  per the board.
- **The scale-dependent-constants class** (their `τ = 2` + my `loading_absolute_thresh = 6`) — Shinichi
  acknowledged; ownership still to assign.
- Toward 1.0: Julia parity, the methods paper, the full coverage campaign.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git pull && claude "Rehydrate from docs/dev-log/handover/2026-07-30-claude-handover-campaign-approved.md, then docs/dev-log/2026-07-30-vgh-degeneracy-at-scale-scope.md (read its READ FIRST section first) and the lane map docs/dev-log/handover/2026-07-25-active-lane-split.md. Shinichi APPROVED the re-aimed VGH degeneracy campaign. Open a NEW lane (fresh branch + worktree off main) and ULTRA-PLAN it there. The question is 'where is the boundary in (n,p,q), and is the region VGH wins in big enough to justify an engine' — NOT 'does the 0/148 survive', which is already answered no at q=4/p=80. Use the in-package R/va-vgh.R::.vgh_fit(), NOT dev/vgh/vgh-engine.R::vgh_fit() which cannot do multi-trial binomial. Note BOTH engines report converged=TRUE on degenerate fits, so health is recovery against truth only. Stage 1 = marginal sweeps varying ONE axis at a time from n=100/p=12/q=2 to find which axis drives the failure; seed on every axis. Local compute is fine (~13.5 CPU-h total); if you go to Totoro note its installed gllvmTMB does NOT contain the VGH engine. Fire the adversarial gate BEFORE publishing."
```
