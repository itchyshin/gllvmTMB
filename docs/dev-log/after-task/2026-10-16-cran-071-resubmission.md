# gllvmTMB 0.7.1 CRAN review repairs

## 1. Goal
Address the five requests in Konstanze Lauseker's 15 October 2026 email and resubmit one checked 0.7.1 archive. This report records work in progress; no upload is claimed.

## 2. Implemented
Added shared accessor return documentation; replaced unnecessary dontrun blocks; labelled incomplete reference syntax as templates; corrected animal-example unit metadata; made sanity diagnostics suppressible; moved developer-test output into temporary fixtures; required explicit output destinations in five shipped simulation launch scripts.

## 3a. Decisions and Rejected Alternatives
Retained the historical 0.7.1 release branch rather than incorporating development main. Prediction methods are already registered with stats::predict; generic re-export is unnecessary. Retained the Julia example's external-software exception. No likelihood, parameterisation, formula grammar or capability extension is intended.

## 4. Files Touched
The source commit's full changed-file inventory is authoritative. R roxygen changes and generated man pages are paired. Console behavior changes are confined to sanity_multi and its quiet diagnostic wrapper. File-writing changes affect developer test fixtures and five inst/sim/lane-b shell scripts. No README, root vignette, article, DESCRIPTION, public site or validation-debt claim was changed. Example changes span animal-keyword, bootstrap-sigma, brms-sugar, check-consistency, confint-inspect, coverage-study, diagnose, extract-correlations, extract-cutpoints, extract-omega, extract-repeatability, extract-sigma-table, extract-sigma, extract-two-psi-cross-check, extractors, families, gllvmTMB, isdm-sources, kernel-keywords, loading-ci, loading-profile, output-methods, plot-loadings-confidence-eye, profile-targets, re-uncertainty, ridge-path, rotate-loadings, slope-sd-ci, spde-keyword, standard-errors, suggest-lambda-constraint, traits-keyword, unique-keyword, vcov-coef and z-confint-gllvmTMB. Remaining example blocks were inspected for undefined placeholders; the Julia external-software example remains dontrun.

## 5. Checks Run
Focused sanity-messages, sanity-multi and diagnose tests pass. pkgdown::check_pkgdown reports no problems. All Rd files and 64 extracted example scripts parse. Six animal examples execute successfully. File-write worker reports BFGS, G2d, G2e and G2f tests pass, plus MSPL simulation-contract tests with one conditional skip. Shell bash -n and missing-variable failure checks pass. Full diagnostic tarball check and current-source example execution are in progress. Exact final artifact and Windows checks remain pending. Evidence lives in /Users/z3437171/local-scratch/gllvmTMB-cran-071-evidence/.

Stale/default scans: rg 'saveRDS|save\(|write[.(_]|dir.create|sink\(|pdf\(|png\(' R; rg 'write|save|dir.create|setwd|path.expand|~/' tests vignettes R; rg '\\dontrun' man; rg 'predict' man/gllvmTMB.Rd man/slope_sd_ci.Rd NAMESPACE. No new simulation campaign was run. Source-gate checks do not certify a later archive.

## 6. Tests of the Tests
The new diagnostic test verifies message delivery, suppression, empty stdout and unchanged flags. Required shell variables fail before writing when unset. Temporary-package fixtures preserve developer runners' path/provenance contracts instead of disabling those checks.

## 7a. Issue Ledger
The external CRAN email is the request ledger. Five requested categories are tracked in the evidence REQUESTS.md. No issue was closed and no reply sent.

## 8. Consistency Audit
Independent Rose/Emmy source review found no P0/P1 blocker in the return documentation, labelled templates and console changes. This review does not cover final artifact or platform evidence. The release remains experimental and historical-source scoped.

## 9. What Did Not Go Smoothly
The Gmail connector points to snakagaw@ualberta.ca; the email was found in the existing itchyshin@gmail.com browser tab. System Git triggers an unaccepted Xcode licence; a bundled Git works. Native worktree creation failed for the same reason, so a separate fallback-Git worktree was created. Setting DEVELOPER_DIR to CommandLineTools permits compilation without accepting new licence terms. Initial diagnostic archives precede later example repairs and are not submission files.

## 10. Known Residuals
Final archive identity, full CRAN-shaped check, Windows result, independent artifact reviews, upload and confirmation remain pending. No CRAN acceptance or publication is claimed. Broad interval coverage and later development features remain outside scope.

## 11. Team Learning
Converting dontrun to donttest reveals broken examples; parse checks alone cannot establish runnable examples. A file-write audit must include shipped shell launchers and developer tests, even when package runtime already uses tempdir.

## 12. Cross-Product Coverage
R gllvmTMB 0.7.1 only. No Julia implementation or parity claim changed.
