# Lane brief — VGH as an estimator, and the pluralist route

Date: 2026-07-30. Author: Claude. Lane: `claude/vgh-pluralism-20260730`,
worktree `/private/tmp/gllvmtmb-vgh-pluralism`, based on `main` @ `a51ca881`.
Predecessor: `docs/dev-log/handover/2026-07-30-claude-handover-heywood-gate-landed.md`.

## The gate is lifted

The Heywood-gate goal fenced *"any VGH campaign — it is gated behind Arc B and
must not run first."* **Arc B is complete and merged (#838), so the fence is
lifted.** Two decisions were taken at that close and should not be re-opened:

1. **The Heywood gate ships with ONE new statistic**, not two. Six candidates
   were measured; only `loading_absolute_thresh` (on `max_loading_unit`) earned
   its place. Maintainer accepted the measured answer on 2026-07-30.
2. **`aghq_ridge` is announced** in `NEWS.md` with both costs stated.

## Why this lane exists

**The Heywood gate is a Laplace-specific patch for a pathology VA does not
have.** That is measured, not argued:

| | degenerate | of which silent |
|---|---|---|
| Laplace, paired binomial (148 fits) | **50 (33.8%)** | **49** |
| VGH, same data | **0 (0.0%)** | — |
| `gtmb_jj` (Totoro grid, 320 fits) | **0** | — |
| `gllvm_va` (Totoro grid, 600 fits) | **0** | — |
| `gtmb_laplace` (Totoro grid, 601 fits) | **70 (12%)** | **59** |

Sources: `dev/heywood/vgh-vs-laplace-degeneracy.csv`,
`dev/totoro-grid/results/RESULTS.md` §4.

**Shinichi's framing, which the evidence supports:** *"VGH does not need to be
better at everything — it can be just good for some things and we can mix it
with LA too. We want to be flexible and innovative."* The two engines fail in
**disjoint** ways, so the route is not "VA replaces LA" but **both engines plus
an honest gate saying which to trust** — which neither `gllvm` nor gllvmTMB
ships today.

## What is already known — do NOT re-derive

- **Our JJ engine IS `gllvm`'s VA algebra**, verified: median relative difference
  **2.69e-07**, 100% agreeing under 1%. GH sits above JJ in 100% of 320 cells
  (correct bound ordering). `dev/vgh/crosscheck-va-r3.csv` matches TMB to ~1e-13.
- **VGH is fast in the right regime**: 11.5x / 8.4x / 14.6x against Laplace at
  n = 200/500/1000 (gaussian, m = 20) — **as interpreted R against compiled C++
  with AD**. But it is **~20–25% SLOWER** at small binomial problems
  (p 6–12, n 60–200). The win comes from Laplace's O(m^3) determinant and
  inner-mode iterations, which bite only at large m and large n. **Always quote
  the regime.**
- **`gllvm`'s VA is NOT faster than its LA** in our measurements: LA 3.3x faster
  at n = 200, m = 50. The received wisdom does not survive.
- **The warm-start route is refuted.** Ridged warm start rescued 0/7 runaway
  fits where the ridge itself rescued 7/7, because **the runaway IS the maximum-
  likelihood solution** (`R/fit-multi.R:5297-5303`: refitting from the TRUE
  parameters ties the objective 40/40 and walks back out). A starting point
  cannot fix a problem whose destination is wrong. Three independent
  confirmations. **Do not re-litigate.**
- **The VGH screen refutation was OVER-SCOPED** and is corrected in
  `docs/dev-log/2026-07-29-vgh-phase3-screen-result.md`. The statistic tested
  (`h`) contains no `Lambda`; the doc calls it *"the worst candidate available"*.
- **`gllvm_eva`'s 68% figure must not be cited** — the fairness audit found the
  arms were not scored on the same fields.

## The one thing blocking a claim

**No equal-accuracy statement exists in either direction.** The speed benchmark
is confounded: Laplace fits **60** parameters and VGH **79** (per-trait `phi_j`
against one shared gaussian `sigma`), so VGH's +6.2 to +10.0 log-likelihood
advantage is roughly what 19 extra parameters buy on their own.

**Slice 1, and it gates everything else: a MATCHED-PARAMETERISATION accuracy
run.** Same parameter count both arms, same data, recovery scored against known
truth. Until that exists, neither "VGH is as accurate" nor "VGH is less
accurate" may be said.

## Candidate slices, after Slice 1

2. **VGH's degeneracy rate at scale**, on the Totoro grid design it postdates
   (n 40–400, p 8–80, q 2/4, 10 seeds). The 0/148 result is one regime.
3. **Compile VGH to C++/TMB.** It is 8–15x faster *as interpreted R*; the
   remaining deficit at small problems is plausibly the interpreter.
4. **Quadrature order.** Q = 15 is current and nothing below it has been tested;
   the error table exists (Q=15 → 2.0e-03 against a Q=80 reference).
5. **The mixed route**: Laplace for the median, the ridge to repair in place,
   VGH as the independent second engine, with `check_gllvmTMB()` saying which to
   trust. This is the deliverable the other slices serve.

## Standing discipline

Healthy is defined by **recovery against known truth, never convergence** —
59/70 recorded degenerate fits reported `convergence = 0`. Every threshold ships
with a measured false-positive rate. Sweep the heterogeneity of whatever sits in
a ratio's denominator; homogeneous truth flatters a ratio every time. Reject a
candidate only on a measurement **as wide as the candidate**. Heavy compute →
Totoro; results stay local (D-50). No self-merge on API changes.

Full background: `~/shinichi-brain/memory/VGH in gllvmTMB — the settled
position, and the three questions that kept getting conflated.md`.
