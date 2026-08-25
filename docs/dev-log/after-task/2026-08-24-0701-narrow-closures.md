# After-task — 0.7.1 trust-release narrow closures

## 1. Scope and state

This is the pre-integration closure report for Codex branch
`codex/0701-trust-release`, initially based on
`a94a156fa2522319ba7ab3625648109300128ecc`. It covers #1190, #1194, and the
#1189 VA documentation fence only. It is not a release-candidate receipt.

## 2. What changed

- #1190 adds a warning for an explicitly supplied, non-`NULL` optional
  `unit_obs` or `cluster` slot when no covariance keyword consumes its column.
  The check reads both sides of parsed covariance terms so kernel terms remain
  silent when they consume their column.
- #1194 keeps `extract_Sigma_B()` and `extract_Sigma_W()` public and
  soft-deprecated. Their migration target is visible in wrapper and canonical
  help; unexported internal use is warning-free and keeps historical payload
  names.
- #1189 adds a conservative VA status fence: opt-in experimental route,
  uncalibrated inference, native Laplace default, no MSPL or low-prevalence
  expansion.

## 3. Files changed

`R/gllvmTMB.R`, `R/extractors.R`, `R/extract-sigma.R`, `R/methods-gllvmTMB.R`,
`R/diagnose.R`, `R/output-methods.R`, their regenerated Rd files,
`tests/testthat/test-unused-grouping-slots.R`,
`tests/testthat/test-sigma-rename.R`, `docs/dev-log/known-limitations.md`,
the check log, and the release plan.

## 4. Validation

Focused #1190: 13 passes. Focused #1194: 24 passes. The existing two-kernel
file, which exposed the initial #1190 kernel false positive, passes 123 checks
with 21 intentional heavy skips. `git diff --check` passes. `devtools::document()`
regenerated the affected Rd files.

The first full `NOT_CRAN=true devtools::test()` run had 16,428 passes, 879
skips, 60 warnings, and four failures. One failure was the repaired #1190
kernel false positive. Three materializer errors require historical no-fit
sources that are unavailable; they are unrelated to this lane. This is not
candidate evidence; the exact frozen candidate must run its own complete gates.

## 5. Documentation and reader path

The wrapper migration is visible in `extract_Sigma_B.Rd`,
`extract_Sigma_W.Rd`, and the canonical `extract_Sigma.Rd`. The optional-slot
warning tells the reader to omit the argument or use its column in the intended
covariance keyword. No public random-slope, MSPL, calibration, or broad
prediction claim was added.

## 6. Scope fences and deferred work

No TMB likelihood, parameter, formula grammar, API removal, version bump,
MSPL, calibration campaign, iSDM expansion, broad `predict(newdata = )`, tag,
CRAN action, or public release work occurred. Random slopes remain outside this
closure's public claims.

## 7. Review and coordination

Lane preflight detected live direct-to-main and other Codex lanes. The release
lane held a renewed narrow lease for all edited paths. GitHub PR enumeration
could not run because the API connection was unavailable. No merge, push, or
external CI action occurred.

## 8. Resolved scope gate and remaining blockers

Shinichi resolved G4 on 2026-08-24: retain existing public MSPL and
random-slope reader surfaces, but apply the 0.7.1 fence only to new 0.7.1
prose. MSPL remains opt-in experimental and is not expanded or promoted by
this candidate. The baseline still has three unavailable-source materializer
test errors and existing `aghq-report.R` roxygen S3-export diagnostics.

## 9. Next safest action

On resumption: re-run lane preflight and a path lease, integrate the versioned
candidate, freeze a new source SHA, and rerun all candidate gates from that
SHA. Do not publish a candidate.
