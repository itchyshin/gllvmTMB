# After-task — VGH Phase 2 close: built, verified, and the premise disproved

Date: 2026-07-29. Lane: `claude/vgh-phase2-20260730`. Platform: Claude.
Plan: `~/.claude/plans/dazzling-inventing-coral.md`.

## What the arc set out to do

Deliver a verified VGH → Laplace warm-start path hitting **≥1.5× end-to-end at a provably
identical optimum**, and land PR #819.

## What happened

**Built and working.** `control$vgh_warm_start = TRUE` runs VGH, maps its solution onto the
template's `theta_rr_B` via `.vgh_to_laplace_start()`, asserts the start landed, and lets
Laplace report the MLE. Fail-closed on free diagonal tiers, within-unit tiers, non-admitted
families, missing data, unbalanced grids.

**The optimum half PASSES.** Log-likelihood agrees to **1.65e-13 – 1.96e-11** across 18 live
end-to-end cells spanning three families, both fits converged, start confirmed landed every
time.

**The speed half FAILS, in every family VGH admits.**

| family | median ratio | detail |
|---|---|---|
| gaussian | ≈ 0.99× | parity |
| poisson | ≈ 1.05× | erratic, 0.38× – 1.63× |
| binomial | ≈ 0.73× | **consistently slower, 0/6 cells at parity** |

**Why.** `R/fit-multi.R:4029` already calls `.gllvmTMB_residual_factor_start()`
unconditionally — an SVD of the residual covariance through the same lower-triangular
rotation. `.vgh_init()` (`R/va-vgh.R:466`) seeds VGH from an eigendecomposition of the same
matrix. VGH re-derives a start Laplace already had. We paid for a start we already owned.

## Evidence

| Claim | Number | Source |
|---|---|---|
| packing transform preserves eta, live fit | 4.44e-16 | `tests/testthat/test-vgh-warmstart.R` |
| the helper the handover named moves eta | 5.55 | negative control, same file |
| warm vs cold loglik agreement, 18 cells | 1.65e-13 – 1.96e-11 | `dev/vgh/e2e-*.R` |
| `z_B` seeding harm, gaussian n=120 | 0.39× → 4.43× | `dev/vgh/e2e-3arm-zseed.R` |
| `rcmdcheck --as-cran` | 0 errors, 0 warnings, 1 note | local, twice |
| test suites | 19 + 45 assertions, 0 failures | `test-vgh-warmstart.R`, `test-vgh-verify.R` |

## Defects found and fixed

1. **The handover named the wrong rotation helper** — `.va_r3_rotate_to_lower_triangular()`
   is Lambda-only and moves eta by 5.55. Corrected to
   `.gllvmTMB_lower_triangular_rotation()`.
2. **Six defects in the verification harness**, found by adversarial review after it passed
   its own 8-block suite. Worst: two fits that *both failed to converge* were certified
   "SAME optimum" because the code tested flag equality, not truth.
3. **`z_B` seeding was actively harmful** — a random effect TMB re-solves internally.
   Default is now loadings-only.
4. **A CRAN-blocking NOTE in my own code** — `ave()` without `stats::`. Caught by the check.
5. **The gllvm comparison was extracting loadings wrongly** — `params$theta` is
   identification-constrained (1.0 on the diagonal); the scale is in `params$sigma.lv`.
   Uncorrected it would have published "gllvm has a G-error of 5772".

## Two corrections to my own earlier claims

- I called `dev/vgh/*` scratch to be pruned. It is not: `dev` is `.Rbuildignore`d and commit
  `c18ccc51` had deliberately preserved those receipts.
- I told Shinichi a "defensible sentence" about beating `gllvm` that was not defensible —
  it benchmarked VGH alone (not VGH+Laplace, the actual claim), with VGH's dispersion fixed
  at the true simulated value. Corrected in
  `docs/dev-log/2026-07-29-vgh-vs-gllvm-headtohead.md`.

## Not done, and why

- **S5 Totoro campaign** — not run. The premise failed at local scale in every family, so a
  384-core campaign would have measured a disproved hypothesis more precisely. Totoro was
  verified reachable (384 cores, load 0.23) and is ready if a future arc needs it.
- **Scratch pruning** — deliberately declined, see above.

## What should happen next

The warm-start-for-speed premise is disproved for the families VGH covers. Genuinely open:

1. **Robustness, not speed.** At gaussian n=120 seed 1 the *cold* fit took 0.895 s where the
   same size at seed 2 took 0.104 s, and the warm start avoided it. That is the Phase 3
   degenerate-fit-screen use case. One cell is an anecdote; a seed-stratified test would
   settle it, and it is the most promising remaining use for this engine.
2. **Do not quote Phase 1's internal speedups as if they were this number.** They measure
   VGH against gllvmTMB's own engines on VGH's own objective. This measures what a user
   would feel.

## Melissa reconciliation — the two "unclear" items, answered

Full reconciliation: `docs/dev-log/plan-actual/2026-07-29-vgh-phase2.md`. Seven deviations
came back *adaptive*; two came back **unclear** for want of a recorded rationale. Both are
answered here rather than left open.

**Unclear #6 — model routing.** The plan's slice table specified Sonnet for S1–S6/S8, Opus
for S7, Haiku for S5. What actually ran: the orchestrator did most slices inline on the
session model (Fable), and the S7 adversarial-verify function was delivered **inside the two
workflows** rather than as a standalone agent — `verify:adversarial` (Opus, high) on the
verification harness, and `adjudicate:refute` (Opus, high) on the competitive claim. Both
returned `REFUTED: true` with reproduced defects, so the gate fired twice and did its job.
Haiku ran S0 recon, not S5. **Assessment: the routing was cheaper than planned at the
producer tier and correct at the gate tier, but it was never written down — Melissa is right
that an unrecorded deviation is indistinguishable from drift.** The rule for the next arc:
when the adversarial gate is delivered via a workflow phase rather than a plan row, say so in
the plan row.

**Unclear #9 — branch landing.** Closed: PR #820 opened for this branch. Nothing is
carried over silently.

## Handoff state — explicit

- **LANDED:** PR #819 (Phase 0 + Phase 1) is merged to `main`.
- **PUSHED, PR #820 OPEN:** `claude/vgh-phase2-20260730`, 13 commits, `rcmdcheck --as-cran`
  clean (0/0/1 benign). Contains the wiring, the transform, the verification harness, and the
  negative result. **The merge is the maintainer's**, as with #819.
- **CARRIED-OVER (fenced, not started):** the Phase 3 degenerate-fit screen — the one
  genuinely promising remaining use for this engine, motivated by the n=120 seed-1 cell where
  a cold fit took 8.6× longer than the same size at another seed and the warm start avoided
  it. Needs a seed-stratified test, not a campaign.
- **CARRIED-OVER (flagged separately):** `.vgh_fit` returns `elbo = prev`, the ELBO from the
  previous sweep rather than at the returned parameters. Spawned as its own task; it is on
  `main` now via #819 and is not this branch's to fix.
- **NOT carried over:** the Totoro campaign. Deliberately dropped, not deferred — the
  hypothesis it would have measured is disproved.
