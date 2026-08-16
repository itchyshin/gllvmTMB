# Paper 1 evidence chapter -- draft 0 (private staging)

**Status:** private draft assembled from the 2026-08-15 measured programme.
Not reader-facing; no empirical claim; figures referenced are design/synthetic
figures. Numbers cite the committed results notes and
`frontier-campaign/artifacts/`.

## When can an integrated model separate ecology from opportunistic sampling?

Integrated species distribution models promise to combine structured surveys
with opportunistic records by letting the two sources share one ecological
process while each keeps its own observation process. The promise has a
quiet premise: that the data can distinguish a source-specific spatial
pattern from the shared ecological one. We asked when that premise holds, in
the smallest model that contains the problem -- two sources (a three-visit
presence--absence survey and a Poisson point-count stream with a known effort
offset), three species, one shared latent spatial field, and one
opportunistic-only bias field, all on a known-truth synthetic design
(Fig. P1-F1v2).

The question was forced on us, not chosen. A fitting programme against one
frozen realisation of this design consumed twenty-four estimator routes --
quasi-Newton variants, coordinate charts, trust regions -- without one
admission. The diagnosis, reached by measurement rather than by another
route, was that nothing was wrong with the estimator: the opportunistic-only
field's true amplitude (64% of the ecological field's) sat inside the
likelihood's indifference region (raising the collapsed estimate to the truth
cost 0.57 nats; p = 0.765), and the collapsed point is a stationary point of
the marginal likelihood for any data, by the model's exact sign symmetry.
Re-fitting could only reproduce the artifact at higher precision. The right
question was never *which optimiser* but *how much design*.

## Three axes, one law

We measured the design's recoverability frontier along three axes, holding
the predictor-scale truth constant throughout (each geometry's field scale
anchored to the same exactly-computed discrete marginal variance; anchor
rebuilds reproduced the frozen objective to 5.5e-12; every campaign's anchor
cell reproduced its predecessor within predeclared Monte Carlo error).

**Effort.** Multiplying opportunistic records at fixed geometry buys
identifiability -- the probability of a positive-definite Hessian crosses one
half at an effort multiplier of 1.85 (95% bootstrap CI 1.43--3.17, about 850
expected detections here) -- but not amplitude: the median relative amplitude
error is still 0.58 at sixteen times the baseline records, and the
identifiable fraction plateaus near 0.68 (Fig. P1-F2). Failures are bimodal:
the sign-symmetric collapse, or a whole-field runaway in which the range and
both loading blocks blow up together.

**Finer patches.** Shrinking the spatial correlation range on the fixed grid
-- more independent patches, same cells -- made every metric monotonically
worse (identifiable fraction 0.485 to 0.270 at the highest effort tested;
Fig. P1-F3). Each new patch arrives by taking sampled cells from the others.

**More domain.** Growing the domain at fixed range and fixed cell size --
more patches with per-patch sampling intact -- improved every metric
monotonically (identifiable fraction 0.330 to 0.555, median amplitude error
0.993 to 0.633, convergence to 1.00 across 360 to 2,250 cells at doubled
baseline effort; Fig. P1-F4).

The two replication arms differ in exactly one respect and move in opposite
directions, which yields the chapter's law:

> **Spatial replication identifies a source-specific field if and only if it
> preserves the information within each replicate. Cells buy what records
> cannot.**

## Design guidance

The amplitude frontier was not crossed within the measured span; the last
doubling of cells moved the median error from 0.98 to 0.63, placing the
crossing -- as extrapolation, not measurement -- near ten to twenty thousand
cells at realistic per-cell record densities. That is precisely the scale of
the intended empirical designs (a 50-km continental grid; a 100-km global
grid of 25,000--40,000 sites). Three consequences for practice: a grid of
that size is plausibly sufficient, provided per-cell record support is
maintained; sub-sampling cells to save computation is the one economy the
design cannot afford; and absolute loading thresholds cannot police this
model class, because loadings absorb the field scale (the true loading norm
here sits at the shipped threshold; a scale-free diagnostic follows from the
runaway signature, in which the range and loadings blow up jointly).

## Boundaries

All statements are design-level, from known-truth simulation under one truth
configuration per axis; the frontier crossing beyond 2,250 cells is
extrapolation; interval calibration for the source-bias coefficients
under-covers even where the Hessian is positive definite and is unresolved;
and nothing here is evidence about any empirical dataset. The measured
surface is the map; the empirical papers are the territory.

---
*Figure sources: P1-F1v2 (design), P1-F2 (effort), P1-F3 (finer patches),
P1-F4 (domain growth) -- `frontier-campaign/artifacts/`. Results notes:
`2026-08-15-{frontier-campaign,replication-axis,domain-growth}-results.md`,
`2026-08-15-g2g-information-check-on-frozen-paper1-fixture.md` (section 1b),
`2026-08-15-runaway-classification-note.md`.*
