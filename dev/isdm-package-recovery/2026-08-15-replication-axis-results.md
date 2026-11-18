# Replication-axis results -- the hypothesis is REFUTED on the fixed grid

2,400/2,400 fits, 0 errors, 0 gate failures, 276 s wall. Anchor-consistency
kill rule PASSED (|z| <= 2.53 across E in {1,2,4}). Amendment A1 design;
discrete-anchored normalisation held the predictor-scale truth exactly
constant across range levels (drift factor down to 0.834 corrected).

## The measurement

At EVERY effort level, increasing spatial replication (more Matern patches on
the frozen 360-cell grid, via range shrink) made identifiability WORSE,
monotonically:

  pd_rate            r=0.22  0.165  0.132  0.11    (patches/side 4.5 -> 9.1)
    E=1               0.355  0.395  0.300  0.275
    E=2               0.425  0.340  0.315  0.225
    E=4               0.485  0.410  0.385  0.270
  conv_rate declines in parallel (0.975 -> 0.755 at E=4); median relative
  amplitude error stays ~1 (collapse) at E=1,2 everywhere, and at E=4 sits
  ~0.53-0.58 until the mesh ceiling (r=0.11) where it collapses to 0.97.
  bias_q at E=1 is strongly negative (-0.4 -> -1.2): the fit cannot even see
  the shorter ranges.

## The two-axis frontier statement (closure of the goal)

1. **Effort buys identifiability but not amplitude**: E*_pd = 1.85
   [1.43, 3.17]; median amplitude error still 0.58 at E=16; PD plateau ~0.68.
2. **Replication-via-finer-patches buys NOTHING on a fixed grid**: it
   monotonically degrades identifiability, because per-patch information
   (cells and GBIF counts per range-patch) falls exactly as patch count
   rises, and the fit-side SPDE representation degrades as the range
   approaches mesh resolution (both mechanisms present and confounded here;
   both push the same direction for design guidance).
3. **The binding quantity is therefore per-patch information JOINTLY with
   patch count** -- not patches per side. The arm that could still move the
   amplitude frontier is growing the DOMAIN (more cells at fixed range,
   option (a) of the handover), which raises patch count without diluting
   per-patch sampling. That is new geometry and a new campaign.

## Design guidance for the empirical papers

More grid cells with adequate per-cell records -- never finer effective
resolution on a fixed cell budget. For the North American integrated model:
coarsening the grid (fewer, better-sampled cells relative to the field's
range) is favoured over refining it, at fixed record counts.

## Honest limits

The range-shrink arm confounds sampling dilution with fit-side mesh
under-resolution (bias_q shows the latter). Disentangling them requires the
domain-growth arm with a denser mesh. Anchor pd-rates run systematically ~0.1
below the effort campaign's (different seed streams; |z| within the
predeclared 3-MCSE rule). All claims are design-level, synthetic,
known-truth; no empirical or admission claim.
