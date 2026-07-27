# Session Handoff: VA/EVA engines → speed-up and comparator arc

**Meta:** 2026-07-27 · target = Claude · author = Claude · lane =
`claude/va-wiring-20260726` · worktree `/private/tmp/gllvmtmb-va-wiring-20260726`
· base `main` `dc79753a`, **`main` `c3d11667` already merged in** · HEAD
`5db5265a` + merge commit. Not pushed, not merged.

## Critical context — read before planning

VA/EVA/JJ work as **internal** engines and are verified against `gllvm` to 1e-9.
**But the reason for building them is refuted by their own evidence.** Do not
plan as though VA is the faster or better estimator:

- **No speed crossover exists.** VA arms scale ~n^1.9–2.7; Laplace ~n^0.98
  (linear). Laplace is faster at every tested n (500–5000) and p (27, 50).
- **Our VA times out 12/12 at n=2500 and n=5000.** Ayumi's model is n=5397, so
  VA cannot fit it at all.
- **The tighter GH bound recovers `Sigma_B` worse than the looser JJ bound**,
  20/20 paired seeds, engine held fixed. Not an optimiser artefact, not a
  starting-value artefact — both were tested and cleared.

What the evidence **does** support: ours was the **only arm returning a number in
all 640 grid cells**, 1% degenerate, and **never reported a clean status on a
degenerate fit**. gllvmTMB's Laplace was 12% degenerate with 59/70 reporting
`convergence = 0` + `pdHess = TRUE`; gllvm's EVA was 68% degenerate with **all**
reporting converged.

**So the product is a second opinion, not an estimator.** That reframing is
Shinichi's (2026-07-27): *"VA is required to be able to compare with Laplace and
also to compare with gllvm."*

## Goals / mission

Two things, in order: (1) make VA fast enough to be worth running; (2) ship it as
a cross-engine comparator. Full plan:
`docs/dev-log/2026-07-27-ultra-plan-va-speedup-and-comparator.md`.

## What was accomplished

- VA/EVA/JJ as swappable evaluation tiers (`eval_method = "auto" | "jj"`),
  families Poisson / Bernoulli / multi-trial binomial. Nothing exported.
- Verified against `gllvm` 2.0.13: Poisson 4.4e-09, JJ binomial 2.7e-07 median
  relative difference; bound ordering correct **320/320** cells.
- 640-cell Totoro grid + 48-cell scale sweep; results local (D-50).
- Designs 104–108: family architecture, density spec, structural extension
  (incl. **Proposition 2**), missing-data design, parity programme.
- Found, fixed and handed off the binary/OLRE positive-logLik defect — merged to
  `main` as `c3d11667` (PR #796) by a separate lane, with a second older instance
  found by sweeping.

## Current working state

- **Working:** merged `main` into the lane cleanly (no conflicts). Full
  `devtools::test()` was **still running** at handoff — **its result is unknown
  and must be re-run before any push.**
- **Blocked / decision-gated:** NEWS entry and the public GitHub issue for the
  merged logLik defect are maintainer calls, unfiled.

## Key decisions and rationale

- VA ships as a **comparator**, not `method = "VA"`. The evidence does not
  support an estimator claim, and `compare_loadings()` already exists as the
  socket.
- Default quadrature **H = 15** (agrees with H=61 to 8.85e-07, ~3.4x faster).
- Laplace stays the package default. Unchanged.

## Next immediate steps

1. **Re-run `devtools::test()`** and confirm green before pushing. Do not push on
   an unrun suite — this lane touches TMB templates.
2. **Arc 0 (60 min, highest value in the plan):** flip the binomial default from
   GH to **JJ**, and swap `stats::optim(method="BFGS")` for **`"L-BFGS-B"`** at
   `R/va-r3-proto.R:639`. Both already measured: 5–8x and 16x, identical
   objectives.
3. **R2: re-run the Totoro scale sweep** and check whether the n>=2500 wall falls.
4. Then the comparator plumbing (R3–R4).

## Gotchas / failed approaches — do not repeat

- **Never time from a single sequential pass.** A ~3x first-fit-in-session
  penalty (a full TMB compile can be 19 s) caused **three** retracted claims.
  Interleave replicates; report objective evaluations alongside wall clock.
- **The warm start is a no-op for accuracy.** `max|ELBO_warm − ELBO_cold| =
  1.63e-08`, 3 seeds positive / 3 negative. Keep it (~21% faster) but the cold
  start is **cleared** as the explanation for the recovery gap.
- **Do not attribute the GH-vs-JJ gap to the optimiser.** Cross-evaluating the GH
  objective at JJ's optimum gives `f_GH(theta_A) < f_GH(theta_B)` on 6/6 seeds.
- **"Quadrature beats JJ" is not novel** — published since 2011 (Knowles & Minka;
  Marlin/Khan/Murphy; Tiao). Only the *inside-a-GLLVM* instantiation is unfound.
- **Do not resurrect `design94/95/96`** — same bound at half the PG convention.
- **Do not route multinomial through this architecture** — it needs a
  T-dimensional integral.
- **The degeneracy detector's 100%/100% is in-sample.** Resubstitution estimate;
  needs out-of-sample validation before it is quoted.
- `gllvmTMB_wide()` cannot suppress Psi — the only valid matched Laplace
  comparator is the formula path with `latent(..., unique = FALSE)`.
- `extract_Sigma_B()` returns a **list** (`$Sigma_B`, `$R_B`), not a matrix.
- Tar the worktree with `COPYFILE_DISABLE=1` before shipping to Totoro; macOS
  `._*` files get compiled as source and break the install.

## Ideas borrowed from gllvm (ideas, not code)

From `gllvm` 2.0.13 source, read during prior-art work:

- `Ab.struct` — variational covariance structure, default **`"blockdiagonal"`**,
  not unstructured. We hardcode full unstructured Cholesky, their most expensive
  option.
- `Ab.struct.rank = 1` — **rank-1 Cholesky** for the variational covariance.
- `diag.iter = 1` — two-stage warm-up: diagonal `S` first, then relax.

**Proposition 2 (Design 106) proves their `blockdiagonal` default is *exactly*
optimal** under the loading-support criterion — a justification they do not cite.

## Landing state

| Artifact | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/va-wiring-20260726` | yes | **no** | none | LOCAL ONLY |

`main` is at `c3d11667` and is **already merged into** this lane.

## How to resume

```sh
cd /private/tmp/gllvmtmb-va-wiring-20260726 && claude "Read docs/dev-log/handover/2026-07-27-claude-handover-va-speedup.md then docs/dev-log/2026-07-27-ultra-plan-va-speedup-and-comparator.md and the morning brief docs/dev-log/2026-07-27-morning-brief-va-eva.md. Re-run devtools::test() and confirm green BEFORE pushing. Then execute Arc 0: flip the binomial default from GH to JJ, and swap stats::optim(method='BFGS') to 'L-BFGS-B' at R/va-r3-proto.R:639. Verify objectives are IDENTICAL before and after, and measure the speed-up with INTERLEAVED replicates - never a single sequential pass. Poisson must be untouched. Do not plan as though VA is a faster or better estimator; it is not, and the plan explains why."
```
