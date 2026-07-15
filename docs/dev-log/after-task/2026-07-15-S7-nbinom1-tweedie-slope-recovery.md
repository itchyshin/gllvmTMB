# S7 (Phase B) — nbinom1 & tweedie random-slope recovery evidence

**Date:** 2026-07-15
**Scope:** Design 80 gap-closure Phase B, goal slice S7. Produce honest random-slope
recovery evidence for **nbinom1** and **tweedie**; resolve B1 (the reported ~44%
tweedie slope-SD over-estimate) with the #388 validate-before-advertise gate and
D-43 default-NOT-DONE discipline honoured. Isolated worktree off HEAD `8ec161bb`
(Lane A's committed engine). **NOT merged to main** — validate + report only.

## What was done

- Installed the worktree source (which carries the committed `tweedie(p = ...)`
  p-fix hatch, `R/families.R:443` + `R/fit-multi.R:4090-4111`) into a private
  library and ran small **local** fits (maintainer-authorised).
- **nbinom1** is already on the runtime augmented-slope allowlist
  (`R/fit-multi.R:1458,1492`; ids `{0,1,2,3,4,5,7,9,14,15}`, nbinom1 = 15). Ran
  recovery directly, unpatched engine.
- **tweedie is family id 6 — deliberately NOT on the allowlist** (fenced fail-loud,
  the #388 gate). To *measure* whether the p-fix removes the reported over-estimate
  I temporarily added `6L` to the two slope gates, rebuilt into a **separate**
  library, measured, then **reverted** the patch (worktree source is clean; the
  shipped engine still gates tweedie).
- DGP mirrors `make_family_slope_mu` (phylo random slope, coalescent tree, T=3,
  `s2_slope = c(0.3, 0.5, 0.2)`, truth mean slope SD = 0.567). Metric =
  `mean(sd_b slopes) / mean(sqrt(s2_slope))`, aggregated over converged seeds.

## Results

| family  | mode    | n_sp | conv  | mean ratio | median | truth (mean SD) |
|---------|---------|------|-------|-----------|--------|-----------------|
| nbinom1 | free    | 80   | 5/8   | 0.955     | 0.890  | 0.567 |
| nbinom1 | free    | 200  | 7/8   | **1.005** | 0.998  | 0.567 |
| tweedie | free-p  | 80   | 6/8   | 1.038     | 1.019  | 0.567 |
| tweedie | p-fixed | 80   | 6/8   | 1.034     | 1.011  | 0.567 |
| tweedie | free-p  | 200  | 8/8   | 0.883     | 0.943  | 0.567 |
| tweedie | p-fixed | 200  | 8/8   | 0.884     | 0.940  | 0.567 |

Raw per-seed output: `dev/tweedie-slope-diagnosis-results/S7-nbinom1-recovery.out`,
`.../S7-tweedie-freeP-vs-pfix.out`.

Supporting prior arms (`dev/tweedie-slope-diagnosis-results/`): arm3 (engine-free
scalar-RE GHQ vs Laplace) already showed **Laplace ≈ GHQ** (σ_true 0.6 → Laplace
0.567, GHQ 0.564; gap 0.0025) — i.e. Laplace does not over-estimate the tweedie
scalar-RE SD. arm2 (Gaussian control) showed ML ≈ REML gap ~1e-4. The old arm1
engine cells all errored (`unused argument p`) against a stale installed 0.5.0
predating the p-fix — they were never valid evidence.

## Verdicts

- **nbinom1 — RECOVERS.** At n_sp=200 the slope SD is essentially unbiased
  (ratio 1.005, median 0.998, 7/8 converged); adequate at n_sp=80 (0.955). On the
  allowlist already; shipped an indep-slope recovery cell (below).
- **tweedie — the ~44% over-estimate does NOT reproduce** on the current committed
  engine. Free-p recovery is ratio ≈ 1.04 (n_sp=80) and ≈ 0.88 (n_sp=200), a normal
  recovery band. **Fixing p at truth changes nothing** (Δratio < 0.01), because
  free-p already recovers p to within ~0.05 of 1.5 (verified: free p̂ ∈ [1.45,1.53]
  per trait vs pinned 1.5), so the σ↔p↔φ ridge is not flat enough at these sizes to
  distort the slope SD. This is consistent with the 2026-07-12 note that the bias
  "persists with p fixed" — but the *level* is now ~1.0, not 1.44.

### Does the tweedie p-fix escape hatch resolve B1?

**No — and it does not need to.** B1 assumed a ~44% ridge-driven over-estimate that
p-fix would remove. On the current engine there is **no such bias to remove**; the
p-fix works mechanically (pins logit_p per trait) but leaves the slope SD unchanged.
The honest resolution of B1 is: the over-estimate reported from a pre-gate bare fit
(2026-07-12) no longer reproduces on Lane A's committed engine. The p-fix hatch
remains a useful, harmless stabiliser for genuinely flat-ridge regimes (very few
clusters), not the fix for B1.

## Shipped

- `tests/testthat/test-family-slope-recovery.R`: added an **nbinom1** indep-slope
  recovery cell (seed 101, heavy-gated `GLLVMTMB_HEAVY_TESTS=1` + `skip_on_cran`),
  mirroring the lognormal/student cells. Passes on the clean engine (full file: all
  assertions pass). Header note updated to record the tweedie gate + the S7 finding.
- **No recovery assertion shipped for tweedie**: it stays gated fail-loud in the
  engine; asserting recovery would require the local gate-bypass, which is not
  merged. The evidence is promising but preliminary (8 seeds, 2 cells).

## #388 / D-43 — no capability claim

Tweedie augmented-slope recovery is **not** advertised as validated. The measurement
supports opening a proper multi-seed campaign (Totoro, per-trait bias + MCSE + the
ML-vs-REML small-cluster diagnostic) as the gate for un-fencing tweedie. **Needs
maintainer sign-off before any allowlist change or capability claim merges.**

## Discrepancy flagged for maintainer

`tests/testthat/test-tweedie-fixed-p.R` (NOTE lines ~6-10) states the "~44%
slope-variance over-estimate persists with p fixed" and cites it as the reason
tweedie stays off the slope allowlist. On the current committed engine the ~44%
figure does not reproduce (ratio ~0.88-1.04). The *conclusion* (tweedie stays
gated pending a recovery campaign) is still correct under #388, but the stated
*magnitude* is stale. Left unedited (not my scope to silently rewrite another
agent's test comment) — flagged here for review.

## Follow-up

1. Full tweedie slope-recovery campaign (≥50 seeds, n-ladder incl. small clusters),
   per-trait ratios + MCSE, before any un-gating.
2. Reconcile / refresh the `test-tweedie-fixed-p.R` 44% note with S7 numbers.
