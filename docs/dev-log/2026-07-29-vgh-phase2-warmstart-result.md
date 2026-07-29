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

What must **not** happen is quoting the Phase 1 internal speedups as though they were this
number. They measure different things, and this is the one that matters to a user.
