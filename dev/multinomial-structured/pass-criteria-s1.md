# Slice-1 pass criteria — multinomial structured random effects (animal_latent / kernel_latent)

**STATUS: DRAFT — pending Shinichi sign-off.** This is a pre-registered criteria
block copied verbatim into this file so the aggregation logic cannot drift from
what was agreed before results exist. Do not weaken or add cells to this
block after seeing the `--mode full` output; any change after that point needs
a fresh dated note explaining why, not a silent edit.

---

20 seeds; fits enter the aggregate only if convergence==0 and PD Hessian
(non-PD → counted+reported, excluded); rail rate = seeds with any
|rho_hat|>0.99, reported separately, >6/20 rails = FAIL; direction-correct
rate for rho_hat ≥ 16/20 non-railed; median rho_hat ∈ [0.30, 0.60]; median
contrast-SD ratio ∈ [0.5, 2.0].

---

## Notes (not part of the pre-registered block above)

- "contrast-SD ratio" = `sd_hat / sd_true` per contrast dimension (2 values
  per fit at K = 3); the criterion is on the median across all (seed, keyword,
  contrast) cells.
- Criteria are evaluated **per keyword** (`animal_latent`, `kernel_latent`)
  separately, since they are two admission questions, not one pooled claim.
- `rho_true = 0.6` under the DGP defaults in
  `dgp-multinomial-structured.R`; "direction-correct" means
  `sign(rho_hat) == sign(rho_true)`.
- Non-PD-excluded and railed fits must both be **reported**, not silently
  dropped from the write-up — a high exclusion/rail rate is itself a finding
  (cf. Design 84's own "data-hungry, especially with one observation per
  species" caveat).
