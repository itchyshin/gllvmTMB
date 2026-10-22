# Design 126 — Prediction on integrated (iSDM) fits: the implemented point route and the evidence still owed

Status: ACTIVE / PARTIAL. The point-prediction machinery is implemented; held-out
spatial accuracy and map uncertainty are not certified. Evidence:
`tests/testthat/test-isdm-predict.R`, `dev/isdm-predict-probe/`, and
`dev/isdm-requalification/`.

## 1. Why this document exists

Applied ecologists need to know which parts of an integrated-SDM map are
computed by the public API and which parts still lack recovery evidence. The
original 2026-08-17 probe found three defects in `predict(newdata = )`.
Those defects and the ordinary intercept-only SPDE point route have since been
repaired. This document now records that implemented route without turning a
deterministic identity check into a held-out accuracy or interval claim.

## 2. Implemented point-prediction contract

For the ordinary intercept-only `use_spde` route, `predict()` now:

- reproduces `report$eta` at the training rows to numerical identity when
  random effects are included;
- builds the SPDE projector at new in-hull coordinates with
  `fmesher::fm_basis()` and emits a classed warning outside the mesh hull;
- dispatches each row through its own source-specific family and link;
- carries the fitted `family_var` source column so expected counts and
  detection probabilities are not presented without their scale label;
- honours `re_form = ~0`, `NA`, or numeric `0` on both prediction paths;
- accepts response-free `newdata`; users do not add a dummy outcome column;
- reconstructs source-specific observation formulas from the fitted terms,
  factor levels, contrasts, and retained column basis, including transformed
  terms and rank-reduced designs; and
- obtains effort-free relative intensity when the user sets the fitted offset
  variable to zero in `newdata`.

Unknown sources, missing observation covariates, unseen observation-factor
levels on rows where that source is active, and ambiguous encoded source-column
names fail with typed errors.
Declared sources absent from a prepared prediction grid contribute neutral
zero observation-effect blocks rather than changing the fitted column order.

## 3. Evidence boundary

The exact training-row identity is a projection and packing oracle. It proves
that the fitted point predictor is reconstructed on rows whose target is
already known from the fit; it does not measure prediction accuracy at held-out
locations. The new-coordinate check remains a finite, smoothly varying smoke
test. The requalification programme therefore still owes its preregistered
held-out in-hull point campaign for full and weak overlap with two and three
sources.

The public route is deliberately narrow. Spatial slopes
(`use_spde_slope` and `use_spde_latent_slope`) and other random-effect tiers
without an established reconstruction convention remain warnings or
refusals. Users supply prepared `newdata`; no exported prediction-grid helper
is planned in this programme.

## 4. Uncertainty boundary

`se.fit` remains refused with `newdata`. The existing training-row standard
error is fixed-effect-only and cannot be used as a map interval: the retained
1,600-fit feasibility study covered the true linear predictor only
0.23--0.82 of the time. A separate fixed `trait:env` Wald campaign passed
48/48 cells over 22,200 fits (coverage 0.939--0.959; positive-definite-Hessian
availability 0.858--0.947), but that result concerns one fixed coefficient and
does not transfer to a spatial surface.

Map intervals require the separate joint-precision, random-effect-aware
construction and calibration programme. Until that gate passes, point maps
may be shown only with an explicit statement that they carry no interval and
no held-out accuracy certificate.

## 5. Register

Register row `ISDM-03` remains `partial`: the public point-prediction route is
implemented, while held-out point accuracy and calibrated SPDE map uncertainty
remain owed.
