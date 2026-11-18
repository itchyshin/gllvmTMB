# Domain-growth results -- the N_cells frontier: cells buy what records cannot

1,600/1,600 fits, 0 errors, 1,536 s wall on Totoro. Anchor-consistency vs A1
PASSED (|z| <= 1.97). Amendment A2 design; anchor rebuild gate 5.5e-12;
predictor-scale truth constant across levels within 3%.

## The measurement

Domain grown at FIXED range and FIXED cell size (patch count rises WITHOUT
diluting per-patch sampling -- the arm A1 could not test):

  n_cell     360    810   1440   2250      (E = 2)
  pd_rate  0.330  0.430  0.455  0.555     monotone UP
  med_rel  0.993  0.985  0.981  0.633     monotone DOWN
  cos95    0.255  0.375  0.470  0.575     monotone UP
  conv     0.940  0.985  0.995  1.000     monotone UP
  bias_q   -0.005  0.079  0.091  0.081    small, stable

E=1 improves on the same axes, more slowly (med_rel 0.997 -> 0.982; iqr_lo
0.979 -> 0.291). Contrast with A1's range-shrink arm: OPPOSITE sign on every
metric. Together the two arms give the clean statement:

  **Spatial replication helps if and only if per-patch information is
  preserved. Cells buy what records cannot.**

## Frontier location

At E <= 2 the amplitude frontier (med_rel <= 0.25) is NOT crossed by 2,250
cells; pd crosses 0.5 at ~2,000 cells (E=2). The last doubling moved med_rel
0.98 -> 0.63, so crossing plausibly requires a further ~2-3 doublings --
~10,000-20,000 cells at these effort densities. Stated as EXTRAPOLATION, not
measurement. It is, however, exactly the scale of the empirical designs (the
NA 50-km grid, thousands of cells; the global 100-km grid, 25,000-40,000
sites) -- the synthetic programme's frontier and the real designs' sizes are
mutually consistent, which is the design guidance the papers needed:

  the integrated-JSDM papers' grids are plausibly LARGE ENOUGH, provided
  per-cell record support is maintained; sub-sampling cells to save compute
  is the one thing the design cannot afford.

## Honest limits

Frontier crossing beyond the measured span is extrapolation; b's unit period
repeats across domains (stated design feature); fit cost grows ~linearly in
cells (9.6 s -> 107 s), so the next doubling costs ~4 min/fit -- a designed
campaign, not a default. Synthetic, known-truth, design guidance only.
