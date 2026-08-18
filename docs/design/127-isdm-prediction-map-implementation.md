# Design 127 — Implementing the prediction-map API (#1133)

Status: DESIGN (no implementation in this lane). Owner: unassigned.
Depends on: [#1132](https://github.com/itchyshin/gllvmTMB/issues/1132) — same
function, and its RE re-add must exist before off-mesh projection means
anything. Scoping parent: `docs/design/126-isdm-prediction-api.md` §4.
Register: ISDM-03 (`partial`).

## 1. Why this document exists

Design 126 §4 named four gaps between what `predict()` returns and what a
prediction map needs. It scoped them; it did not say how to build them. This
document does, so the work can be picked up without re-deriving the shape.

**Nothing here is implemented.** The map-making article stays fenced until
items 1 and 2 land.

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

Item 1 below is therefore reduced, not closed.

## 3. Item 1 — off-mesh projection (REDUCED by #1132)

**Remaining work, not delivered by #1132:**

1. **A grid helper.** Users build a prediction grid by hand today. A small
   `predict_grid()` / `expand_grid_for()` helper that takes a fit and a
   bounding box or `sf` object and returns a `newdata` frame with the mesh's
   `xy_cols`, the trait factor at its training levels, and a zeroed offset
   column. This is where the offset trap (item 2) is most cheaply defused.
2. ~~**Extrapolation honesty.**~~ **DONE in #1132** — found by the adversarial
   verification and fixed in the same PR. `fm_basis()` returns an all-zero row
   outside the mesh hull, so the field read as exactly 0: a blank patch of map
   indistinguishable from a cold one, while `make_mesh()` rejects such rows at
   *fit* time. `predict()` was quietly more permissive than the fit. It now
   checks the projector's row masses and warns
   (`gllvmTMB_predict_newdata_outside_mesh`), with a test pinning that
   in-domain rows stay silent. A grid helper (item 1 above) should still
   *filter* to the hull rather than relying on the warning.
3. **An oracle for new coordinates.** The natural one: fit on a subset of
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

## 5. Item 3 — arm attribution

In-sample output carries no source column, so a mixed-scale `est` invites
misreading: Poisson counts and detection probabilities in one numeric column,
distinguishable only by the reader's memory of which rows were which.

Carry the `family_var` column through to the output on both paths. #1132
already recovers `fam_var <- attr(fit$family_input, "family_var")` inside
`.gllvmTMB_newdata_family_ids()`, so the lookup exists; this is a matter of
adding the column, and deciding whether it is unconditional (a schema change
for every mixed-family caller) or opt-in.

**Needs a decision:** adding a column changes the returned data frame's shape.
`test-fitted-multi.R` asserts `expect_identical(fitted(...), predict(...))`,
which survives a shape change only if both paths change together.

## 6. Item 4 — uncertainty (the one with a measured obstacle)

**Do not offer `se.fit` as a map interval.** The 2026-08-18 feasibility grid
(`dev/isdm-intervals/2026-08-18-feasibility-results.md`, 1,600 fits) measured
the existing conditional fixed-effect-only `se.fit` at **0.23–0.82 coverage**
of the true linear predictor, and coverage *falls with grid size* — because
the latent/field reconstruction error it ignores is exactly what dominates on
a map.

So map-scale uncertainty needs an RE-aware construction: joint-precision (as
in the MIS-37 wave-1b machinery) or sample-based. Both are substantially more
work than items 1–3 and neither is scoped here.

`.gllvmTMB_predict_se_guard()` currently hard-refuses `se.fit` with `newdata`.
**That refusal is correct and should stay** until an RE-aware route exists —
it is the only thing preventing a mis-calibrated interval being drawn on a map.

## 7. Suggested order

1. ~~Extrapolation honesty (§3.2)~~ — done in #1132.
2. Scale documentation (§4, route one) — documentation only.
3. Arm column (§5) — needs the schema decision first.
4. Grid helper (§3.1) — convenience, once the above are settled.
5. RE-aware uncertainty (§6) — its own arc, gated on the E1 campaign.

The map-making article unfences after 1 and 2, **with an explicit statement
that the map carries no interval**.
