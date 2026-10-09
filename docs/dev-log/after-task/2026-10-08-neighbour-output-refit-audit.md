# Neighbouring output and refit bug audit

## 1. Goal

Search for defects related to issues 1467 and 1469 and repair confirmed cases. The maintainer cancelled additional SE work; uncertainty fallbacks are outside this task.

## 2. Implemented

Correlation pair indices are validated before integer coercion. Matrix plots reject conflicting duplicate estimates, intervals or provenance instead of selecting a row by input order. Ordination checks retained score-block dimensions and refuses unsupported temporal components. getLV uses the same loading-prior curvature provenance check as LV-effect extraction, withholding unsafe legacy uncertainty while preserving points.

Native fits retain their control record. Covariance and internal LV bootstrap refits preserve ridge, integration, optimiser and REML settings, disabling only unused refit standard errors. Legacy fits recover retained ridge and integration metadata. Bootstrap counts and confidence levels receive scalar validation. The internal LV bootstrap refuses MSPL inference before simulation instead of switching estimators.

## 3a. Decisions and Rejected Alternatives

Keep invalid fit uncertainty unavailable. Do not manufacture SEs, change defaults or widen test tolerances. Matching mirrored rows remain supported; conflicting payloads must be corrected by the caller. Older unrecorded optimiser options cannot be reconstructed. No new public inference route is exported.

## 4. Files Touched

R/bootstrap-sigma.R, R/bootstrap-lv-effects.R, R/fit-multi.R, R/extract-correlations.R, R/plot-covariance-tables.R, R/extractors.R and R/output-methods.R. Four new regression files cover refit settings, correlation inputs, ordination integrity and prior-curvature provenance. Related Rd pages, README, covariance article, NEWS and check-log are updated.

## 5. Checks Run

Fresh installations passed 24 focused and neighbouring test files. These include the new regressions and existing ridge, summary, contrasts, selected trait names, correlation layouts, covariance plotting, ordination, lazy standard errors and bootstrap checks. Heavy recovery cases retain their explicit skip gates. The final frozen-source installation also passed all 24 files, including both correlation count routes. Explicit heavy and CRAN skip gates remained active. Remote CI is pending at this revision.

## 6. Tests of the Tests

Before patches, numeric indices were truncated, conflicting tables changed when reordered, malformed score blocks recycled values, temporal components were ignored and legacy prior SDs leaked. Mocked bootstrap calls captured missing ridge, optimiser and REML settings. The MSPL test observed simulation and ML refits before the new refusal. Regression tests now check both rejection and retained valid behaviour. A small real fit verifies control retention.

## 7a. Issue Ledger

Issues 1467 and 1469 remain closed after their earlier merged repairs. This follow-up addresses nine confirmed neighbouring defect cases on codex/neighbour-bug-audit. It does not reopen the cancelled SE request. Landing receipts will be recorded on the follow-up PR.

## 8. Consistency Audit

Installed tests exercise compatible unique/full correlation layouts and valid one-axis output. Prior-curvature criteria are shared rather than duplicated. Bootstrap settings match the fitted estimator; missing historical options are not claimed recoverable. Independent correlation and bootstrap integration reviews passed. Final count-forwarding review also found the cross-correlation route; both routes now retain the raw count for validation.

## 9. What Did Not Go Smoothly

The first bootstrap test fixture lacked its tier-presence flag and was corrected before reproducing the refit bug. A source-loaded test runner initially used the older installed fitter; fresh installed checks exercise the control metadata addition. Review caught the internal MSPL route switching to ML, which was reproduced and repaired. No accuracy tolerance changed.

## 10. Known Residuals

Remote checks and merge are pending at this report revision. This audit covers the named output and refit paths, not every package function. Existing unrelated repository acceptance ledgers remain open. No sampling-coverage campaign or CRAN release is part of this work.

## 11. Team Learning

Refit routines must retain the estimator and model settings alongside the formula. Validate counts before coercion and vector lengths before constructing matrices. Symmetric plots must not conceal conflicting inputs. Share uncertainty provenance checks across extractors and older aliases.

## 12. Cross-Product Coverage

This work covers native R output guards, ordinary score extraction and native bootstrap refit settings. It does NOT cover new SE fallbacks, calibrated interval coverage, scientific rank choice, unsupported VA bootstrap routes, Julia engine changes or a CRAN release.
