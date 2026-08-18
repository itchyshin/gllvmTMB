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
REs; on spatial fits this includes the SPDE field — that spatial instance is
**probe-measured only**, the test fixture is non-spatial); per-row arm
inverse links on **in-sample** `type = "response"`; exact non-spatial newdata
round-trip on the link scale; `re_form = ~0` on newdata equals fixed + offset
exactly; unseen-unit fixed-only fallback; in-sample `se.fit` + classed
newdata refusal. All pinned by `test-isdm-predict.R` (16 assertions) except
the spatial in-sample result (B1), which is probe-measured only.

## 3. Defects (bug-class; fixes are maintainer-gated R/ changes)

### 3.1 Spatial fits: `newdata` silently drops the SPDE field

`predict.gllvmTMB_multi`'s newdata branch re-adds only the `rr_B`, `diag_B`
and `propto` terms — 3 of the ~30 random-effect `use` tiers enumerated at
`R/methods-gllvmTMB.R:3081-3090`. **Every other tier is dropped on
`newdata`**: spatial is the instance measured; phylogenetic and kernel tiers
are structurally identical and unmeasured. A spatial fit's field is simply
absent — at training locations too — while the branch prints "Random effects
… have been added". Measured on a converged two-arm spatial fit:
dropped-piece sd 0.381 vs linear-predictor sd 0.949, and the dropped piece is
the field **by identity** — the fit carries exactly one random tier
(`use$spde`), so −diff is the entire RE contribution (cor(−diff, true field)
= 0.82 corroborates that the field is real); on a pure-spatial fit
`re_form = ~.` equals `re_form = ~0` exactly. Independently confirmed by the
adversarial verification on a **non-isdm** `gaussian()` spatial fit
(`verify-report.md` VER[D0]–[D4]: sd 0.516 vs eta sd 0.786;
`-diff == report$eta − fixed-only` exactly), establishing the generality by
measurement, not only code reading.

Fix shape: re-add the SPDE contribution for rows whose unit/coordinates are
in the training set (the mesh already carries them); until then, the honest
minimum is a loud per-call warning naming the omitted terms instead of the
current message implying inclusion.

### 3.2 `re_form` is honoured only on the `newdata` path, and only as the literal `~0`

Roxygen: "pass `~ 0` (or `NA`) to predict the fixed-effects-only …
prediction". Two failures against that contract, the first the larger:

- **In-sample, `re_form` is ignored entirely.** The `is.null(newdata)` branch
  (`R/methods-gllvmTMB.R:2212-2229`) never reads it — it returns
  `report$eta` unconditionally. On the package's *default* calling
  convention, `predict(fit, re_form = ~0)` silently returns the full
  conditional predictor (measured: `~0` and `NA` both bit-identical to the
  default; `verify-report.md` VER[C2]).
- **On newdata, only the literal `~0` is honoured.** `re_zero <-
  inherits(re_form, "formula") && identical(deparse(re_form), "~0")` — so
  `NA` (probe A5), numeric `0` and `~1` (VER[C4b,c]) all silently fall
  through to full-RE.

Fix shape: honour the documented forms (`~0`, `NA`, and in-sample `re_form`)
or correct the roxygen; honouring them is a small guard change.

### 3.3 `newdata` + `type = "response"` applies the wrong arm's inverse link on isdm fits

The newdata response branch (`R/methods-gllvmTMB.R:2327-2361`) reduces the
per-row family/link vectors to a **per-trait modal** id via
`.modal_integer_id()` (L2342-2350). An `isdm_sources()` fit varies family by
**source within trait** — never by trait — so the reduction is structurally
incapable of representing it. Measured on the probe's Part-A fixture
(probe A2c/A2c2, found by the adversarial verification VER[C1]):
detection-arm rows return `exp(eta)` instead of `1-exp(-exp(eta))`, giving
"probabilities" in **[0.253, 2.32]** — values above 1, silently — with
`max|diff| = 1.42` against the certified in-sample response. Not a tie
artifact: in any realistic iSDM the presence-only arm has more rows than the
survey arm and wins the mode every time.

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

**Issue A (bug):** "predict(newdata=) silently omits most random-effect tiers
and mishandles re_form and per-row families" — body = §3.1 with the probe
numbers, plus §3.2 and §3.3 as second and third checklist items (same
function, same fix PR).

**Issue B (feature):** "Prediction-map API for spatial/iSDM fits: A_proj
projection at new locations, intensity scale, arm column" — body = §4,
explicitly fencing the article behind it.

## 6. Register

`docs/design/35-validation-debt-register.md` row ISDM-03 records this split:
`partial` — in-sample certified, newdata-spatial broken/absent, no map claim
on any reader surface until §3–§4 land.
