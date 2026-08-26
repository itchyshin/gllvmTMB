# Interval-calibration seed collision receipt

Date: 2026-08-25

The frozen CI-10 identity uses
`.xfc_rep_seed(20260718, cell_id, rep)` for cell IDs 1 through 18 and
replicates 1 through 5,000. A scan of seed-valued columns in every tracked CSV
found one historical match:

- CI-10 cell 18, replicate 4,381: seed `18065153`;
- historical source: `dev/aghq-evidence/24-campaign-stage1.csv`.

Grace's reproducibility review classified this as a cross-campaign provenance
dependency, not a duplicate within the interval-calibration programme. The
AGHQ campaign and CI-10 answer different questions and their rows will never be
pooled, their Monte Carlo uncertainty will never be combined, and neither will
be described as an independent replication of the other. Changing the frozen
CI-10 base, formula, grid, or replicate identity would instead break the
approved campaign contract.

The verifier accepts exactly this reviewed one-row historical exception and
fails closed if it disappears, changes, or is joined by another collision.
All 175,000 seeds reserved inside the current interval-calibration programme
remain pairwise disjoint.
