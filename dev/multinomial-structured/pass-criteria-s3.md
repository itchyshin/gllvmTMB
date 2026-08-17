# Slice-3 pass criteria — multinomial structured random effects (spatial / SPDE mode axis)

**STATUS: DRAFT — pending Shinichi sign-off.** This is a pre-registered criteria
block copied verbatim into this file so the aggregation logic cannot drift from
what was agreed before results exist. Do not weaken or add cells to this
block after seeing the `--mode full` output; any change after that point needs
a fresh dated note explaining why, not a silent edit.

---

20 seeds; fits enter the aggregate only if convergence==0 and PD Hessian
(non-PD → counted+reported, excluded); rail rate = seeds with
`kappa_hat` at the mesh-resolution boundary (`range_hat < 0.02` or
`range_hat > 5x` the mesh's spatial extent), reported separately, >6/20
rails = FAIL.

**GATE (the only numeric pass/fail criterion): the practical-range ratio
(`range_hat / range_true`, `range = sqrt(8) / kappa`) — ONE value per fit
(kappa is a SINGLE shared parameter per SPDE term, not per-contrast; only the
marginal SD `tau`/`log_tau_spde` is per-contrast) — median ratio across
non-railed, PD seeds ∈ [0.33, 3.0].**

Cross-contrast field correlation (from `extract_Sigma(level = "spatial")` on
the `spatial_latent`/`spatial_dep` cells only — `spatial_indep()` has no
extractable Sigma, see the note below) is **descriptive only, reported with
an attenuation caveat, never gated**: a reduced-rank shared-field loading at
small `n_site` is known to attenuate estimated cross-contrast correlation
toward zero (the same shape as the phylo/animal/kernel mode axis's
one-draw-per-unit data-hunger, S1/S2's own caveat), so a numeric band on it
would be miscalibrated without a larger dedicated spike.

---

## Per-keyword evaluation

Evaluated **per keyword** (`spatial_latent`, `spatial_indep`, `spatial_dep`)
separately. `spatial_dep` is VERIFIED numerically equivalent to
`spatial_latent(d = K - 1)` (same `kappa_hat`/`range_hat` at every smoke-mode
seed, task item 1's desugar-identity check + test-matrix-multinomial-
spatial.R's equivalence test), so its band is expected to track
`spatial_latent`'s exactly rather than needing independent calibration.

## Notes (not part of the pre-registered block above)

- `range_true = 0.3` (the DGP default in `campaign-s3-spatial.R`'s
  `dgp_multinomial_spatial()`); the mesh cutoff (`0.1` for `--mode
  timing`/`smoke`) should stay well under `range_true` at whatever `n_site`
  `--mode full` eventually uses.
- **`extract_Sigma(level = "spatial")` on a `spatial_indep()`-only fit
  aborts** ("Fit has no `spatial_latent()` term") -- a PRE-EXISTING,
  family-agnostic limitation (not introduced by Slice 3, not fixed by it;
  see test-matrix-multinomial-spatial.R's regression test and the FAM-20E
  register row). `spatial_indep()`'s recovery is read off `fit$report$kappa`
  / `fit$report$log_tau_spde` directly, matching
  test-matrix-ordinal-spatial.R's own convention for the same cell.
- The MEASURED timing fit for this campaign (D-139, this task, 2026-08-16):
  `--mode timing` (n_site = 300, spatial_latent, seed = 1): **elapsed 2.54
  sec**, convergence = 0, pdHess = TRUE, `range_hat = 0.401` (true = 0.3) --
  a good first-seed recovery. Projected 60-fit full run ≈ 2.5 min on the
  timing fit's own rate, far under the 30-min line; `--mode smoke` (n_site =
  100, 2 seeds x 3 keywords, 6 fits, elapsed ≈ 12 sec total) shows seed 1
  converging PD for all three keywords (`spatial_latent`/`spatial_dep`
  reporting IDENTICAL `kappa_hat`/`range_hat` at every seed, reinforcing the
  desugar-identity finding quantitatively) and seed 2 failing PD for all
  three (n_site = 100 is small; `--mode full`'s n_site = 300 is 3x larger).
- `--mode full` was **NOT run** as part of this task -- staged only, per
  Design 122's D-139 discipline and pending this file's sign-off. `n_site =
  300` is the task brief's starting point, NOT calibrated against a prior
  spike (unlike S1/S2's `n_sp = 800`, which traces to the 2026-07-17
  phylo-multinomial spike) -- a calibration pass may be needed before
  `--mode full` is approved.
