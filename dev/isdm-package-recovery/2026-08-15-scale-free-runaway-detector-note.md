# Scale-free runaway detector -- prototype, corpus-validated

Prototype in `scale-free-runaway-detector.R` (dev/ only; R/ integration is a
separately reviewed slice). Tests: `test-scale-free-runaway-detector.R`,
13 expectations, all failing modes exercised.

**Rule.** RUNAWAY iff link-scale amplitude `||lambda|| * sd_field(kappa)` > 3,
OR fitted range `sqrt(8)/kappa` < the design's own mesh cutoff while the block
carries amplitude > 0.1. Both coordinates are invariant to the lambda-kappa
gauge that defeats absolute loading thresholds (#851 class).

**Corpus validation (5,600 fits, three campaigns).**
- Catches 489/495 raw-lambda runaways, including 31/37 SILENT ones (conv 0).
- The 6 "misses" have healthy link-scale amplitude (0.88-1.20) with range at
  the resolution boundary -- marginal by mechanism; the raw label over-counts.
- Of 185 additional flags among "raw-healthy" fits, inspection shows genuine
  ray pathologies the raw cut missed (lambda_int 750-930 with range
  0.022-0.030 -- under the raw 1000 cut but grossly under-resolved).
- The shipped `loading_runaway_thresh = 25` on this corpus: 60% false-positive
  rate on healthy fits (true loading norm sits at the threshold). The
  prototype passes those cases.

**Boundaries.** Thresholds (3 / 0.1) calibrated on THIS design family's
corpus; the continuum sd_field approximation is interior-accurate to ~6%
(pass the exact per-design value when available); ground truth at the margin
is mechanism-based, not label-based. Integration into `check_gllvmTMB()`
needs its own review, a behaviour-change note, and maintainer sign-off.
