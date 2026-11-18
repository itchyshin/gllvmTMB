# Model 2 gamma-recovery campaign — results (v2, split metric)

**1,200 fits, 0 harness errors; 1,199/1,200 converged; `pd_hessian` PASS 1,140/1,200
(95%).** Totoro, 100 cores, OPENBLAS single-thread. Grid: `n_sources {2,3,4}` × mix
{all-PO, (n−1)PO+PA} × effort-ratio {1×, 10×} × 100 seeds. Nonspatial, 150 cells,
3 species, reference-coded `gamma[d,j]`. Raw rows:
`campaign-gamma-recovery-results.csv` (committed beside this note).

> **v2 note — a v1 claim is RETRACTED.** The first pass of this document read a pooled
> RMSE and claimed *"more arms even help slightly on the PA mix (0.129 → 0.102)"*.
> Review showed that to be an averaging artifact: the pooled metric dilutes the fixed
> 3 PA gammas with a growing pool of easy PO gammas as arms are added. The campaign was
> re-run with the metric split by arm type, and the split table below shows the PA-arm
> error is **flat to slightly worse** with more arms (0.129 → 0.133 → 0.133 at ratio 1).
> Do not cite the v1 reading.

## The split table (the one that answers the question)

PA mix only; `gamma_rmse_pa` is the 3 detection-arm gammas, `gamma_rmse_po` the
presence-only-arm gammas:

| n_sources | eff_ratio | PA-arm RMSE | PO-arm RMSE |
|---|---|---|---|
| 2 | 1 | 0.129 | — |
| 3 | 1 | 0.133 | 0.071 |
| 4 | 1 | 0.133 | 0.075 |
| 2 | 10 | 0.186 | — |
| 3 | 10 | 0.184 | 0.187 |
| 4 | 10 | 0.194 | 0.181 |

All-PO mix (pooled = PO by construction): 0.070/0.073/0.075 at ratio 1;
0.176/0.187/0.185 at ratio 10. Bias ≤ |0.023| everywhere.

## The three honest readings

1. **Adding sources neither helps nor hurts the arms you already have.** Every arm
   type's own error is flat in `n_sources` — PO ~0.07, PA ~0.13 at ratio 1. The earlier
   "helps" reading is retracted (above); the correct statement is *no interference*:
   at these settings, near-collinear arms do not degrade each other's recovery.
2. **Effort ratio, not source count, drives error.** Arms at a tenth of the reference
   effort roughly double their RMSE, whatever the arm type. A weak extra source costs
   precision on its own gamma, not on the others'.
3. **Bias is negligible everywhere**, so reference coding `gamma[1,j] = 0` behaves at
   every measured n.

## Boundaries — including two the first version under-stated

- **The PA arm is never well-conditioned in this grid.** At ratio 1 its support (2.0)
  saturates detection — mean p ≈ 0.81, roughly a third of cells above 0.95 — so its
  gammas are hard because the arm is near-ceiling, not because integration is hard. At
  ratio 10 the arm is informative (p ≈ 0.21) but has a tenth of the effort. A healthy,
  high-information PA cell is not in this grid, and PA-arm conclusions are bounded by that.
- **"Near-collinear" here means identical-effort, fully-crossed, balanced arms** —
  every arm observes all 150 cells × 3 species. The realistic hard case, arms with
  *partial and overlapping* spatial coverage, is not in this grid, and Design 120 §3's
  conditioning worry is about that case. This campaign does not settle it.
- The all-PO half of the grid uses plain `poisson()` (an all-count declaration needs no
  admission), so **`isdm_sources()` itself is exercised by the 600 PA-mix fits**, not
  all 1,200.
- Nonspatial; one design size; reference-coded gammas; no intervals.

## Compute receipt (D-139), reconciled

Priced from the 12-fit pre-run at ~3.6 s/fit → ~72 core-minutes ≈ **1–2 minutes wall on
100 cores**, under the 30-minute wall-clock line, so run without a separate approval
gate. Both runs completed in well under a minute of compute per the harness's own
timing; the first launch died on an environment error (`R_LIBS_USER` + `--vanilla`
hiding the dependency library) and was relaunched. The pre-run's per-fit time includes
`devtools::load_all()` overhead absent from the installed-package campaign runs, which
is why campaign fits are ~3× faster than the pre-run priced; the price was therefore
conservative in the safe direction.
