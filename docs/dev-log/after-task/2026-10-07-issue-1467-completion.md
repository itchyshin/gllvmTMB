# Issue 1467 output and uncertainty repairs

## 1. Goal

Repair missing LV predictor summaries, factor coding, one-axis plotting and loading-ridge uncertainty. Provide discoverable fitting code and push a reviewed change. Collaborator reply work remains stopped.

## 2. Implemented

summary() prints latent-axis and induced trait coefficients with uncertainty. Loading-ridge uncertainty uses the likelihood Hessian plus exact Gaussian prior curvature at the fitted MAP point. Fit-time, lazy and joint uncertainty paths share the correction. Matching parameter and objective provenance is required; older reports without it withhold uncertainty. Factor design matrices preserve requested contrasts and remove the actual intercept column. ordiplot() supports a horizontal one-axis display and retains user plotting overrides. Diagnostics and worked code suggest loading_ridge = 2 for ordinary between-unit binomial loadings.

## 3a. Decisions and Rejected Alternatives

Keep the general unpenalised default. The explicit prior changes maximum likelihood to MAP, and its scale depends on the response and model. Approximate posterior SDs are conditional on the chosen scale and latent orientation. They do not establish repeated-sampling coverage. Do not replace a missing or mismatched covariance with a fabricated SD. Do not automatically remove a valid rare indicator.

## 4. Files Touched

R/brms-sugar.R, R/lv-predictor.R, R/fit-multi.R, R/extractors.R, R/methods-gllvmTMB.R, R/standard-errors.R, R/ordination-uncertainty.R, R/output-methods.R, R/diagnose.R and R/gllvmTMB.R; related tests and Rd pages; DESCRIPTION, README.md, NEWS.md, the latent-axis article, dev/issue-1467/ and check-log.md. Native likelihood code is unchanged. Regenerated Rd files reconcile inherited source/documentation differences.

## 5. Checks Run

The initial focused regression set passed 776 expectations. A fresh native installation passed all 94 curvature and LV-summary checks. Independent numerical curvature and joint precision tests passed. CI portability repairs passed installed plotting (6), factor recovery (45) and actionable-error checks (7). Final diagnostic, sanity and summary checks passed 150 expectations, with one inherited implicit-unit deprecation warning. Rd regeneration, pkgdown reference checks, article rendering, reader-surface checks, Actions boundary checks and git diff checks passed.

A committed-source tarball passed R CMD check with tests run separately: zero errors, zero warnings and one inherited TMB internal-call note. Its SHA-256 is 3f315ec521bd28e40cc9a3584f887ca4cfb37dc81aa7716100d976d493babc46. Final remote CI receipts are on PR 1468; this report is written before that final run completes. Routine CI excludes gated heavy recovery checks.

## 6. Tests of the Tests

Producer failures were reproduced before the output fixes. Prior-curvature tests compare against an independent penalised quadratic reference and verify full covariance propagation. Legacy and mismatched reports are guarded. Real graphics devices exercise one-axis plotting. The plotting regression traces the actual generic called, avoiding platform-dependent S3 method interception. Factor recovery retains its original gradient and accuracy thresholds; the fixture explicitly uses BFGS after tighter nlminb stopping reported false convergence.

## 7a. Issue Ledger

Issue 1467 output, factor and ridge uncertainty repairs are implemented on codex/issue-1467-fixes in PR 1468. Dataset-specific results, CSVs, fitted objects and fit logs remain local. No collaborator reply is included. The separate trait-name grammar lane is outside this patch.

## 8. Consistency Audit

Independent mathematical review found no remaining blocker in the prior-curvature correction or its scope. The public-surface review identified broad prior advice; README, article and help now specify ordinary between-unit loadings, matching the theta_rr_B-only penalty. Summary, extractor and legacy guards share uncertainty statuses. The initial draft reply is excluded from the public branch.

## 9. What Did Not Go Smoothly

CI found an extra unactionable error, a graphics trace interception difference, platform-sensitive fixture stopping and an obsolete diagnostic-text assertion. All were repaired without widening accuracy thresholds. A documentation review also narrowed the ridge recommendation to its supported loading block. Automatic publication review rejected data-derived evidence, so the published branch excludes it. An initial local tarball omitted built vignettes and preceded the optional ade4 declaration; the committed-source check resolved those warnings.

## 10. Known Residuals

Final remote checks were pending when this report was written. Merge and release are outside the authorised publication step. Predictor-informed score uncertainty remains unsupported. Scientific rank selection, interval calibration and other-family recovery are not certified. The report structure validator passes, while repository-wide inherited unrelated acceptance ledgers remain unmet; those goals are not closed here.

## 11. Team Learning

An R-level penalty must enter every uncertainty path, including lazy and joint precision requests. Diagnostic recommendations must state which loading block they regularise. Check neighbouring message assertions when changing advice, and exercise installed-package graphics dispatch as well as source-loaded tests.

## 12. Cross-Product Coverage

This work covers native Laplace LV summaries, factor contrasts, ordinary between-unit loading-ridge curvature, one-axis plotting and the associated regression checks. It does NOT cover sampling-interval calibration, scientific rank selection, predictor-informed score uncertainty, other-family recovery or Julia parity. AGHQ metadata identifies fixed-adaptation curvature; it does not certify quadrature accuracy.
