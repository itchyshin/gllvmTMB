# Design 127 — Implementing the prediction-map API (#1133)

Status: IMPLEMENTED POINT ROUTE / PARTIAL EVIDENCE. Owner: iSDM requalification.
Foundation: [#1132](https://github.com/itchyshin/gllvmTMB/issues/1132), which
landed the ordinary SPDE random-effect re-add and off-mesh projection.
Boundary parent: `docs/design/126-isdm-prediction-api.md`.
Register: ISDM-03 (`partial`).

## 1. Why this document exists

The original Design 126 named four gaps between what `predict()` returned and
what a prediction map needed. This document records which implementation
items landed and which scientific evidence remains owed.

The ordinary intercept-only SPDE point route is implemented. The remaining
fences concern held-out accuracy, unsupported spatial slopes, and calibrated
map uncertainty rather than basic point-map construction.

## 2. What #1132 already delivered (read before re-planning item 1)

#1132's SPDE fix rebuilds the mesh projector with
`fmesher::fm_basis(fit$mesh$mesh, loc = <coords from newdata>)` rather than
reusing the stored `A_st` rows. That was chosen deliberately: `A_st` is
indexed by training observation, so reusing it would have restricted the fix
to training rows, whereas `fm_basis()` accepts arbitrary coordinates.

**Consequence: a large part of §4.1 (off-mesh projection) is a side effect of
the bug fix.** `predict(newdata = )` at coordinates absent from the training
set now projects the field rather than silently returning the fixed-effects
prediction.

🔴 **Fence, as measured** (`VERIFY-adversarial.md`, 2026-08-18):

- **Established.** Across 16 configurations spanning all three `use_spde`
  paths, `predict(newdata = training rows) == report$eta` to **≤ 8.9e-16**,
  and the checks were shown to have *power*: a transposed `omega_spde` is
  non-conformable and errors hard, a wrong trait column shifts eta by 2.35, a
  transposed `Lambda_spde` at `d = 2` by 2.42. The rebuilt `fm_basis()`
  projector equals the stored `A_st` at 0.000e+00, and shuffled `newdata` row
  order stays exact.
- **Established for new in-domain coordinates only as a smoke check**: 25/25
  finite, non-zero, varying smoothly (sd 0.2224). No oracle, no accuracy or
  coverage claim.
- 🔴 **NOT established, and the exactness claim does NOT extend here:** the
  *other two* spatial engines. A `spatial_*(1 + x | coords)` fit activates
  `use_spde_slope` or `use_spde_latent_slope`, which are **not re-added at
  all** — measured discrepancies of **3.30 and 3.75**. They are *declared*
  failures (predict warns, naming the omitted tier) rather than silent ones,
  but any statement of the form "the spatial field is re-added" must be read
  as "the `use_spde` field is re-added". Tracked in #1138.

Item 1's projection machinery is complete for the ordinary `use_spde` tier;
its held-out accuracy evidence remains open.

## 3. Item 1 — off-mesh projection (IMPLEMENTED; ACCURACY OWED)

**Current route and remaining evidence:**

1. **Prepared `newdata`, not an exported grid helper.** Users build a
   prediction grid with the fitted coordinate, trait, source, covariate, and
   offset columns. The route accepts response-free `newdata`, so a dummy
   outcome is neither needed nor recommended. No exported grid-building
   helper is planned in the requalification programme.
2. ~~**Extrapolation honesty.**~~ **DONE in #1132** — found by the adversarial
   verification and fixed in the same PR. `fm_basis()` returns an all-zero row
   outside the mesh hull, so the field read as exactly 0: a blank patch of map
   indistinguishable from a cold one, while `make_mesh()` rejects such rows at
   *fit* time. `predict()` was quietly more permissive than the fit. It now
   checks the projector's row masses and warns
   (`gllvmTMB_predict_newdata_outside_mesh`), with a test pinning that
   in-domain rows stay silent. User-prepared grids should filter to the hull
   rather than relying on the warning.
3. **An oracle for new coordinates remains owed.** Fit on a subset of
   locations, predict at the held-out ones, and compare against the
   simulated field. That is a recovery-style check, so it belongs with the
   validation harness rather than the unit suite.

## 4. Item 2 — scale semantics

`type = "response"` includes the row's offset, so it returns an expected
count *at that effort*, or a detection probability *at that support*. A map
almost always wants relative intensity instead.

Two routes, and the recommendation is the first:

- **Document the `log_support = 0` idiom.** Setting the offset column to zero
  in `newdata` already gives exactly this, and #1132's regression tests pin
  that the fixed path honours the newdata offset. Zero new API, zero new
  failure mode. The cost is that the user must know to do it.
- **Add `type = "intensity"`.** Discoverable, but it is a third scale on a
  function that already has two, and it must decide what "intensity" means
  for every one of the 16 families — for a Bernoulli-cloglog arm it is not
  an intensity at all. **Not recommended without a per-family contract.**

## 5. Item 3 — arm attribution (DONE)

`predict()` and `fitted()` carry the fitted `family_var` column on
mixed-family fits. This labels each `est` as an expected count or a detection
probability on the appropriate source/link scale. Single-family output keeps
its previous shape, and `est` remains the final column.

## 6. Item 4 — uncertainty (the one with a measured obstacle)

**Do not offer `se.fit` as a map interval.** The 2026-08-18 feasibility grid
(`dev/isdm-intervals/2026-08-18-feasibility-results.md`, 1,600 fits) measured
the existing conditional fixed-effect-only `se.fit` at **0.23–0.82 coverage**
of the true linear predictor, and coverage *falls with grid size* — because
the latent/field reconstruction error it ignores is exactly what dominates on
a map.

So map-scale uncertainty needs a random-effect-aware construction based on
joint precision and simulation. That work belongs to the separate gated
uncertainty slice; it does not follow from the point-map implementation.

The completed E1 campaign does not close this gap. Its 22,200 fits passed
48/48 cells for one fixed `trait:env` coefficient (coverage 0.939--0.959;
positive-definite-Hessian availability 0.858--0.947). Those fixed-coefficient
intervals do not include uncertainty in reconstructing the SPDE field.

`.gllvmTMB_predict_se_guard()` currently hard-refuses `se.fit` with `newdata`.
**That refusal is correct and should stay** until an RE-aware route exists —
it is the only thing preventing a mis-calibrated interval being drawn on a map.

## 7. Suggested order

1. ~~Extrapolation honesty (§3.2)~~ — done in #1132.
2. ~~Scale documentation (§4, route one)~~ — done; zero the offset in
   `newdata` for effort-free relative intensity.
3. ~~Arm column (§5)~~ — done on mixed-family fits.
4. Held-out in-hull point recovery (§3.3) — owed before an accuracy claim.
5. RE-aware uncertainty (§6) — its own gated implementation and calibration
   slice.

The map-making article may demonstrate the implemented point route only with
an explicit statement that the surfaces have neither calibrated intervals nor
a held-out point-accuracy certificate.
