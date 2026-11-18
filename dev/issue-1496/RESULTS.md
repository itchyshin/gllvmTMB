# Issue 1496 validation commands

Run from the isolated gllvmTMB-1496 checkout on the authorized office Mac.
Source: aec24e16629f5030caa98232b6c2315ae618a5aa plus this patch; package
0.8.0.9000. R 4.6.0, macOS Tahoe 26.7.1, arm64, Accelerate BLAS;
TMB 1.9.21, Matrix 1.7.5, devtools 2.5.2, pkgload 1.5.3, testthat 3.3.2,
roxygen2 8.0.0, pkgdown 2.2.0, Apple clang 21.0.0. Global installed gllvmTMB
was 0.7.1; parallel checks use /tmp/gllvmtmb-1496-lib, never replace it.
R reports America/Edmonton; the sitting's UTC date is 2026-10-16.

- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter="^bootstrap-binomial-response$", reporter="summary")'`
  on old code: 3 trial-total failures. `red.log`. On final source: 69 passes,
  0 failures/errors/warnings/skips. `regression-final.log`, `regression-results.rds`.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter="bootstrap-binomial-response|bootstrap-refit-settings|cbind-binomial|binomial-cbind-missing-response|traits-cbind-binomial|wide-weights-matrix", reporter="summary")'`
  passed all six selected files. `targeted.log`. This earlier run had 64 assertions
  in the new file; the expanded final new file is covered by the separate run.
- `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'x <- devtools::test(filter="bootstrap-Sigma|bootstrap-lv-effects|loading-ci-bootstrap|m1-8-bootstrap-mixed-family|confint-bootstrap|extract-repeatability-bootstrap|extract-communality-bootstrap|bootstrap-refit-settings", reporter="summary"); saveRDS(as.data.frame(x), "dev/issue-1496/bootstrap-results.rds")'`
  249 passes, 0 assertion failures, 24 warning captures, 0 skips; one error in
  the two-core test because serverSocket() is prohibited in the sandbox.
  `bootstrap-suite.log`, `bootstrap-results.rds`.
- `R CMD INSTALL --no-multiarch --no-test-load --library=/tmp/gllvmtmb-1496-lib .`
  passed. `install.log`. Rerun after the final helper namespace qualification.
- `R_LIBS=/tmp/gllvmtmb-1496-lib Rscript --vanilla dev/issue-1496/parallel.R`
  initially blocked on the local server socket. The same command with sandbox
  escalation passed: 3/3 refits in both sequential and parallel modes, equal draw
  lists within 1e-7, cbind expression plus retained missing rows. `parallel.log`.
- `Rscript --vanilla -e 'devtools::document(quiet=TRUE)'` passed. `document.log`.
  Only unrelated sigma S3 registration spelling changed under roxygen2 8.0.0;
  restored the base NAMESPACE to avoid unrelated changes. No roxygen changed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed: No problems found.
  `pkgdown.log` also captures Pandoc's --mathml deprecation messages.
- `air format R/bootstrap-response.R tests/testthat/test-bootstrap-binomial-response.R dev/issue-1496/parallel.R`
  passed. Existing large caller files were not reformatted wholesale.
- `git diff --check` passed.

Final package-check and existing two-core test rerun receipts are appended below.
An earlier quiet devtools check exited 1 without retaining a final report; it
saw an unqualified tail() note in its older source snapshot. The source was
corrected to utils::tail(). A follow-up command using build_vignettes=FALSE
was rejected by this devtools version (unused argument); vignettes=FALSE is
the correct spelling. Neither attempt counts as a passing package check.

- `R_LIBS=/tmp/gllvmtmb-1496-lib GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'cat("Worker package:", find.package("gllvmTMB"), "\n"); x <- devtools::test(filter="^bootstrap-Sigma$", reporter="summary"); saveRDS(as.data.frame(x), "dev/issue-1496/matching-install-results.rds")'`
  with permitted local worker sockets passed: 50 assertions, 0 failures/errors,
  12 warning captures, 0 skips. Warnings are the small-B bounds/coverage warnings
  and one unused cluster argument. `matching-install-unsandboxed.log`.
  The sandboxed matching-install run still had the same serverSocket error;
  the source/install mismatch was a precaution, not the observed error cause.

- `Rscript --vanilla -e 'devtools::check(document=FALSE, args=c("--no-manual", "--no-tests", "--no-examples"), vignettes=FALSE, check_dir="dev/issue-1496/check-output", quiet=FALSE)'`
  completed in 2m45.8s: 0 errors, 1 warning, 3 notes; command exit 1 because
  devtools treats the warning as failure. `check-final.log`, `00check.log`,
  `00install.out`. The warning is duplicate argument `x` in the unchanged
  man/gllvmTMB_julia-methods.Rd; its content is identical to base aec24e166.
  Notes: current time could not be verified remotely, the existing
  TMB:::EvalADFunObject dependency, and xcrun_db temp detritus. Static R code
  checks passed (including the final helper); no unqualified tail() note.
  Tests/examples/manual/vignette execution were explicitly disabled in this
  package-structure check; the regression runs above supply separate test evidence.

## Independent-review correction (supersedes the first patch)

Read `/tmp/review1496.R`, `/tmp/review1496-counterexample.log` and the integrated
source weights guard in R/fit-multi.R. Its all-unit vector regression is real:
explicit weights are refused even when numerically equal to defaults. The helper
now omits exactly all-unit vectors, retaining non-unit trial and likelihood
weights. This preserves the existing admission contract.

- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter="^bootstrap-isdm-response$", reporter="summary")'`
  before correction: three assertion failures (weights must be NULL, bootstrap
  failed count must be zero, draws must equal the manual reference).
  `isdm-red.log`. The initial test also encountered unrelated link-residual
  warnings; the final test explicitly selects link_residual="none" for both
  manual and automatic refits.
- `NOT_CRAN=true Rscript --vanilla -e 'x <- devtools::test(filter="bootstrap-binomial-response|bootstrap-isdm-response|bootstrap-refit-settings|cbind-binomial|binomial-cbind-missing-response|traits-cbind-binomial|wide-weights-matrix|^isdm-multisource$", reporter="summary"); saveRDS(as.data.frame(x), "dev/issue-1496/review-correction-results.rds")'`
  final source: eight files, 225 passed assertions, 0 failures, 0 errors,
  0 warnings, 0 skips. The original binomial regression remains 69 passes;
  the new integrated regression adds 7 passes. `review-correction.log`,
  `review-correction-summary.log`, `review-correction-results.rds`.
- `Rscript --vanilla /tmp/review1496.R > dev/issue-1496/review-reproducer-fixed.log 2>&1`
  reports convergence 0, successful refits with the generated NULL weights,
  patched bootstrap 0/3 failures and original HEAD bootstrap 0/3 failures.
  Original supplied counterexample output is copied to review-counterexample.log.
- `air format R/bootstrap-response.R tests/testthat/test-bootstrap-binomial-response.R tests/testthat/test-bootstrap-isdm-response.R`
  passed. `git diff --check` passed.

The broad bootstrap/parallel receipts above preceded this correction; they are
not presented as new executions of the corrected source. Full-suite and three-OS
CI remain outstanding. The current correction's package-check receipt follows.

- `Rscript --vanilla -e 'devtools::check(document=FALSE, args=c("--no-manual", "--no-tests", "--no-examples"), vignettes=FALSE, check_dir="dev/issue-1496/check-review-output", quiet=FALSE)'`
  on the corrected source completed: 0 errors, 1 warning, 3 notes; exit 1 for
  the warning. Static R code checks passed. The warning remains duplicate `x`
  documentation in unchanged gllvmTMB_julia-methods.Rd. Notes remain offline
  clock verification, existing TMB:::EvalADFunObject and xcrun_db temp detritus.
  `check-review-final.log`, `check-review-00check.log`, `check-review-00install.out`.
  Tests/examples/manual/vignettes were explicitly disabled, as before.
