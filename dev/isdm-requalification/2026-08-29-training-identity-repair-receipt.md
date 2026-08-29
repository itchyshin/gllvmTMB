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
- The fit stores that basis explicitly. Prediction therefore reuses the exact
  training contrasts after an `options(contrasts = )` change and after an
  object is serialized and restored.
- New-data source blocks use exact reconstructed-column matching, including
  source labels such as `a` and `a:b`; absent declared sources remain zero.
  A source-label/interaction-term encoding collision is refused at fit time
  with `gllvmTMB_isdm_observation_name_collision`.
- Public prediction refuses missing or unknown source labels, absent source
  covariates, and unseen source-observation factor levels with typed errors.
- Unseen source-observation factor values are checked only on rows belonging
  to that source; an off-source value remains neutral rather than causing a
  global factor-level refusal.
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
the typed unseen-level refusal, fit-time contrast freezing, serialized-fit
replay, and bare-law source/link dispatch.

The recovery harness was tightened in the same candidate. Full- and
weak-overlap target availability are gated separately, spatial deterministic
oracles are scored across every eligible fit, and the uncertainty pre-run now
either calls the future marginal route with `level = 0.95`, `nsim = 1000`, and
the registered seed or retains a typed unavailable record. It cannot measure
interval runtime by falling back to point prediction.

## Verification

- `test-isdm-requalification-prediction.R`: PASS, 86 assertions.
- `test-isdm-requalification-campaign.R`: PASS, 73 assertions.
- `test-isdm-requalification-summary.R`: PASS, 44 assertions.
- All tests selected by `filter = "isdm"`: PASS, 565 assertions and one
  deliberately skipped heavy test.
- Independent adversarial review first found six P1 defects: off-source unseen
  factors, a missing bare-law source requirement, unfrozen contrasts,
  overlap-pooled target availability, available-only spatial oracles, and
  point-only uncertainty timing. Each now has a regression test and repair.
  Terminal API/method, reproducibility, and Rose pre-publish re-reviews passed
  on the final diff with no unresolved P0--P2 finding.
- Full `devtools::test(stop_on_failure = TRUE)`: PASS with 18,652 assertions,
  52 expected warnings, 879 skips, and zero failures. Duration was 2,332.3 s
  (38m52s), exceeding the 30-minute estimate; the overrun is retained and the
  command is not represented as a <=30-minute gate.
- `pkgdown::check_pkgdown()`: PASS with no problems.
- The pre-repair exact-head manual CI run `33255953258` passed Ubuntu, macOS,
  and Windows at `7b1a281c42821a0b6315fa6a832df54a829f2786`; it is stale after
  the six repairs and truth sync and cannot qualify the final source.
- The earlier `devtools::check(args = "--no-manual")`: PASS in 21m01s with 0 errors,
  0 warnings, and 3 non-blocking notes (system-clock verification, the existing
  `logLik` global-definition note, and macOS `xcrun_db` temp detritus).
- Built-tarball boundary: the six developer-harness suites register explicit
  skips because `dev/` is intentionally excluded, while the same suites run
  fully and pass in the source checkout.

This is a repair receipt, not source qualification. It creates no production or
pre-run attempt and changes no evidence denominator. Claim-bearing fits remain
blocked until this final diff is reviewed, passes replacement exact-head CI,
lands on green `main`, is installed from that exact source, and is requalified
with package and DLL hashes.
