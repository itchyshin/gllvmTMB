# Design 126 — Prediction on integrated (iSDM) fits: what exists, what is broken, what a map needs

Status: SCOPING (no implementation in this lane). Owner: unassigned.
Evidence: `dev/isdm-predict-probe/probe.R` + `probe-output.txt` +
`dev/isdm-predict-probe/findings.md` (lane `claude/isdm-predict-20260817`,
2026-08-17). Certified baseline: `tests/testthat/test-isdm-predict.R`.

## 1. Why this document exists

The SDM article collection ends at fitted models; its implied next step is a
prediction map. The 2026-08-17 handover made "probe whether `predict()` on an
`isdm_sources()` fit returns anything defensible" the first OWED item. The
probe's answer: the in-sample surface is right; the `newdata` surface cannot
make the promised map. This document scopes the API slice that would.

## 2. Certified today (do not rebuild)

See `findings.md` "Defensible": in-sample `est == report$eta` (offset + all
REs, SPDE included); per-row arm inverse links on `type = "response"`;
exact non-spatial newdata round-trip; `re_form = ~0`; unseen-unit fixed-only
fallback; in-sample `se.fit` + classed newdata refusal. All pinned by
`test-isdm-predict.R`.

## 3. Defects (bug-class; fixes are maintainer-gated R/ changes)

### 3.1 Spatial fits: `newdata` silently drops the SPDE field

`predict.gllvmTMB_multi`'s newdata branch re-adds only the `rr_B`, `diag_B`
and `propto` terms. A spatial fit's field is simply absent — at training
locations too — while the branch prints "Random effects … have been added".
Measured on a converged two-arm spatial fit: dropped-piece sd 0.381 vs
linear-predictor sd 0.949; cor(−diff, true field) = 0.82; on a pure-spatial
fit `re_form = ~.` equals `re_form = ~0` exactly. This affects **every**
spatial `gllvmTMB_multi` fit, not only isdm declarations.

Fix shape: re-add the SPDE contribution for rows whose unit/coordinates are
in the training set (the mesh already carries them); until then, the honest
minimum is a loud per-call warning naming the omitted terms instead of the
current message implying inclusion.

### 3.2 `re_form = NA` contradicts its documentation

Roxygen: "pass `~ 0` (or `NA`) to predict the fixed-effects-only …
prediction". Code: `re_zero <- inherits(re_form, "formula") &&
identical(deparse(re_form), "~0")` — `NA` is not a formula, so REs are
included. Either honour `NA` (glmmTMB/lme4 convention) or correct the
roxygen; honouring it is one guard clause.

## 4. The gap (feature-class): what a prediction map needs

1. **Off-mesh projection.** `predict(newdata)` at new coordinates is
   fixed-effects-only; a fine-grid intensity map needs `A_proj` at the new
   locations (`make_mesh()`/fmesher already produce it for training data).
2. **Scale semantics.** `response` includes the row's offset: an expected
   count at that effort, or a detection probability at that support. A map
   wants relative intensity — either document "set `log_support = 0` in
   `newdata`" (works today on the fixed path) or add an explicit
   `type = "intensity"`.
3. **Arm attribution.** In-sample output has no source column; a mixed-scale
   `est` invites misreading. Carry the `family_var` column through.
4. **Uncertainty.** `se.fit` is training-rows, conditional, fixed-effect-only;
   map-scale uncertainty is the calibrated-uncertainty campaign's problem
   (see `docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md`)
   and is NOT promised by this slice.

A map-making article is fenced until 3.1 is fixed and 4.1 exists; anything
earlier maps a field-free surface while claiming the field.

## 5. Draft issue texts (file after review)

**Issue A (bug):** "predict(newdata=) on spatial fits silently omits the SPDE
field — even at training locations" — body = §3.1 with the probe numbers, plus
§3.2 as a second checklist item (same function, same fix PR).

**Issue B (feature):** "Prediction-map API for spatial/iSDM fits: A_proj
projection at new locations, intensity scale, arm column" — body = §4,
explicitly fencing the article behind it.

## 6. Register

`docs/design/35-validation-debt-register.md` row ISDM-03 records this split:
`partial` — in-sample certified, newdata-spatial broken/absent, no map claim
on any reader surface until §3–§4 land.
