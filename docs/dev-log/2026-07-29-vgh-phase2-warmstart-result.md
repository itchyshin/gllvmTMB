# VGH → Laplace warm start: wired, correct, and it does NOT deliver the speedup

Date: 2026-07-29. Lane: `claude/vgh-phase2-20260730`. Status: **negative result, measured.**

Phase 2's target was **≥1.5× end-to-end at a provably identical optimum**. The path is now
wired end-to-end and measured. **The optimum half passes. The speed half fails.**

## What was built

`control$vgh_warm_start = TRUE` in `gllvmTMB()` runs VGH, maps its solution onto the
template's `theta_rr_B` / `z_B` via `.vgh_to_laplace_start()`, and asserts the start landed
before Laplace runs. Fail-closed via `.vgh_warm_start_eligible()`: declines a free diagonal
tier, any within-unit tier, non-admitted families, missing data, and unbalanced grids.
Insertion at `R/fit-multi.R` immediately after the `start_from` block — no overlap with
PR #818, which touches `:2495-2516`.

## The measurement

Gaussian, T = 5, q = 2, 2 seeds per size, `unique = FALSE` (no Psi). Warm time **includes**
the VGH solve. Every cell confirmed the start actually landed.

| n | seed | cold (s) | warm (s) | ratio | landed | loglik rel diff | g_rel_frob |
|---|---|---|---|---|---|---|---|
| 120 | 1 | 0.887 | 2.224 | **0.40×** | TRUE | 4.65e-12 | 5.90e-06 |
| 120 | 2 | 0.094 | 0.213 | **0.44×** | TRUE | 6.34e-12 | 1.67e-05 |
| 400 | 1 | 0.198 | 0.197 | 1.01× | TRUE | 4.59e-12 | 1.07e-05 |
| 400 | 2 | 0.242 | 0.283 | 0.86× | TRUE | 1.50e-11 | 9.74e-06 |
| 1000 | 1 | 0.439 | 0.457 | 0.96× | TRUE | 2.75e-13 | 1.82e-06 |
| 1000 | 2 | 0.594 | 0.569 | 1.04× | TRUE | 1.00e-12 | 4.38e-06 |

**Median ratio ≈ 0.96×.** Target ≥ 1.5×. At n = 120 the warm start is **2.5× slower**.
The VGH solve itself is not the cost — it takes 0.074 s where the end-to-end gap is 1.34 s.

## Why — and this is the part worth keeping

**Laplace was already warm-started.** `R/fit-multi.R:4029` calls
`.gllvmTMB_residual_factor_start()` unconditionally in the default path: an **SVD of the
residual covariance**, packed through the same `.gllvmTMB_lower_triangular_rotation()` the
Phase 2 transform uses.

And `.vgh_init()` (`R/va-vgh.R:466`) initialises VGH from an **eigendecomposition of the
link-scale residual covariance** — the same object.

So VGH starts from what Laplace already had, iterates to refine it, and hands back a start
that is not materially better for Laplace's purposes. The refinement is real for VGH's own
ELBO; it is not information Laplace lacked. We paid for a start we already owned.

This independently corroborates the competitive audit's finding that a bare `eigen()` ties
VGH's recovery in ≤ 1 ms: all three — VGH's init, gllvmTMB's default start, and the naive
closed form — are the same eigendecomposition.

## The optimum half DID pass

Log-likelihood agrees to **2.75e-13 – 1.5e-11** across all six cells, both fits converged.
The warm-started fit lands on the same optimum. The transform, the packing, the transpose,
and the landed-assertion all work in a live fit.

**Calibration note, deliberately not "fixed":** `.vgh_compare_optima()` reported
`identical_optimum = FALSE` in these cells because `g_rel_frob`, `eta`, and the parameter
check sit at ~3e-6 against a 1e-6 tolerance, while the log-likelihood agrees to 1e-12.
That is the optimiser stopping at slightly different points on a flat surface, not a
different optimum. The right response is to set those tolerances from the optimiser's
actual convergence precision and say so — **not** to loosen them until the answer turns
green, which would destroy the instrument's only value.

## What this means for Phase 2

The hypothesis "a VGH warm start makes Laplace meaningfully faster" is **not supported for
gaussian at n ≤ 1000**. Options, in order of honesty:

1. **Report the negative result and stop.** The engine is still verified and fast on its
   own objective; it just does not accelerate Laplace here.
2. **Test where the premise could still hold:** binomial and poisson (the families that
   actually need the 15-point Gauss-Hermite quadrature, where Laplace is dearer and its
   default SVD start is a worse fit), and larger n where the Laplace solve dominates.
   That is a genuine test, not a rescue attempt.
3. **Drop `z_B` from the seed.** `z_B` is a random effect TMB re-solves in its inner
   problem at every outer iteration; seeding it may be worthless or harmful. Seeding only
   `theta_rr_B` is a cheap, falsifiable variant.

## Follow-up: option 3 was tested, and `z_B` seeding IS the harm

Three arms on identical data — cold, warm with both seeded, warm with loadings only:

| n | seed | cold | warm (both) | warm (θ only) | ratio both | ratio θ-only |
|---|---|---|---|---|---|---|
| 120 | 1 | 0.895 | 2.284 | 0.202 | 0.39× | **4.43×** |
| 120 | 2 | 0.104 | 0.110 | 0.099 | 0.95× | 1.05× |
| 400 | 1 | 0.202 | 0.199 | 0.201 | 1.02× | 1.00× |
| 400 | 2 | 0.260 | 0.279 | 0.276 | 0.93× | 0.94× |
| 1000 | 1 | 0.432 | 0.515 | 0.438 | 0.84× | 0.99× |
| 1000 | 2 | 0.520 | 0.574 | 0.567 | 0.91× | 0.92× |

Log-likelihood still agrees to 2.85e-13 – 6.34e-12 in the θ-only arm, so correctness is
unaffected.

**Seeding `z_B` is a defect, and the default is now loadings-only** (`R/fit-multi.R`;
`control$vgh_warm_start_z = TRUE` restores it for re-measurement). The 2.5× slowdown was
entirely attributable to it.

**But θ-only still does not deliver the target.** Median ratio ≈ 0.99× — parity, not
≥1.5×. The conclusion above is unchanged: VGH is re-deriving a start Laplace already had.

## Follow-up 2: poisson and binomial tested — the premise fails there too

The one place the premise could still have held: families where Laplace is dearer per
iteration and its default SVD-on-link-residuals start is a cruder approximation. Both
families VGH admits were run end-to-end, loadings-only, T = 5, q = 2, 3 seeds:

| family | n | ratios (3 seeds) | median |
|---|---|---|---|
| poisson | 200 | 0.38, 0.55, 1.32 | 0.55× |
| poisson | 600 | 1.16, 0.95, 1.63 | 1.16× |
| binomial | 200 | 0.67, 0.65, 0.81 | 0.67× |
| binomial | 600 | 0.77, 0.86, 0.69 | 0.77× |

**Binomial is consistently SLOWER — zero of six cells reach parity.** Poisson is a wash
with high variance (0.38× to 1.63×); one cell clears 1.5×, which at this sample size is
noise, not a result. Log-likelihood agreement stays excellent throughout
(1.65e-13 – 1.96e-11), so correctness is unaffected in every family.

Confound checked and cleared: this was re-run after reinstalling with the loadings-only
default, and the numbers were identical to the run under the old default — so `z_B`
seeding is not the dominant factor for non-gaussian, unlike gaussian.

**Verdict across all three admitted families: the ≥1.5× target is not reachable with this
design.** gaussian ≈ 0.99×, poisson ≈ 1.05× and erratic, binomial ≈ 0.73× and consistently
worse. The hypothesis that a VGH warm start accelerates Laplace is disproved for the
families VGH covers, at the sizes tested.

**One cell worth a targeted follow-up, NOT a claim.** At n=120 seed 1 the *cold* fit took
0.895 s where the same size at seed 2 took 0.104 s — an 8.6× spread at identical n. The
warm start avoided whatever that was (0.202 s). That hints the real value may be
**robustness against a bad cold start** rather than raw speed — which is the Phase 3
degenerate-fit-screen use case, not Phase 2's. One cell is an anecdote; it justifies a
seed-stratified test, nothing more.

What must **not** happen is quoting the Phase 1 internal speedups as though they were this
number. They measure different things, and this is the one that matters to a user.
