# Public-route iJSDM training-identity repair receipt

Date: 2026-08-29  
Lane: `codex:isdm-evidence-map-closure`  
Post-coefficient green main candidate: `ef12dbf497469393745581fcc7029a78016f2b30`  
Rebased preparation head before this repair: `dac27a5791955adf62fecf53de9d3835e6ae33e7`

## Defect and retained negative evidence

The retained 2026-08-28 probe entered fitting and converged, but public
`predict.gllvmTMB_multi(newdata = training_rows)` omitted the fitted
source-observation columns. Its maximum training-row identity error was
`1.10123482841`. The negative receipt remains retained and is not reinterpreted
as a recovery failure.

## Repair

- Prediction reconstructs each source-observation basis from the training
  terms, factor levels, contrasts, and fitted fixed-effect column names.
- New-data source blocks use exact reconstructed-column matching, including
  source labels such as `a` and `a:b`; absent declared sources remain zero.
  A source-label/interaction-term encoding collision is refused at fit time
  with `gllvmTMB_isdm_observation_name_collision`.
- Public prediction refuses missing or unknown source labels, absent source
  covariates, and unseen source-observation factor levels with typed errors.
- The response is not required in `newdata`.
- Every declared source-by-trait arm must retain at least one observed response,
  for both mixed Poisson/cloglog and all-Poisson `isdm_sources()` fits.

## Measured result

The repaired public spatial fixture returned:

- maximum training-row identity error: `0`;
- maximum source/link dispatch error: `0`;
- response column present in prediction `newdata`: `FALSE`.

The dedicated public-path regression additionally covers three sources, a
training-frozen `poly()` basis, a factor basis, a QR-dropped aliased column,
and the typed unseen-level refusal.

## Verification

- `test-isdm-requalification-prediction.R`: PASS.
- Campaign, prediction, source-formula, and multisource focused tests: PASS.
- All tests selected by `filter = "isdm"`: PASS; 13 existing CRAN-skipped
  spatial/heavy tests were reported separately.
- Independent adversarial re-review: PASS after the all-Poisson, source-label,
  typed-refusal, and three-source public-path findings were repaired.
- Full `devtools::test()`: PASS.
- `pkgdown::check_pkgdown()`: PASS with no problems.
- `devtools::check(args = "--no-manual")`: PASS in 21m01s with 0 errors,
  0 warnings, and 3 non-blocking notes (system-clock verification, the existing
  `logLik` global-definition note, and macOS `xcrun_db` temp detritus).
- Built-tarball boundary: the six developer-harness suites register explicit
  skips because `dev/` is intentionally excluded, while the same suites run
  fully and pass in the source checkout.

This is a repair receipt, not source qualification. It creates no production or
pre-run attempt and changes no evidence denominator. Claim-bearing fits remain
blocked until this repair is reviewed, landed on green `main`, installed from
that exact source, and requalified with package and DLL hashes.
