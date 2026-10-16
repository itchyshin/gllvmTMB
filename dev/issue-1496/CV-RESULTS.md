# Issue 1496 — CV continuation local validation

Base: d8f3bbe4b9cbf5541a62810cc67c1e96fad9a7eb (bootstrap PR1507).
Branch: codex/issue-1496-cv. Publication/CI status is recorded in the draft PR.
R4.6.0 macOSarm64, TMB1.9.21, testthat3.3.2, roxygen2 8.0.0.
No native code changed. User default package0.7.1 was not replaced.

## Observed before editing

`R_LIBS=<repo>/dev/issue-1496/check-review-output/gllvmTMB.Rcheck Rscript --vanilla /tmp/gllvmTMB-1496-cv-red-probe.R`
-18 heldout cells generated19 predictions because one previously missing cell leaked in.
-All18 known heldout trial totals were wrong; only7/19 old log densities finite versus18 finite manual count densities.
-The trait null aborted: successes above its implicit single-trial limit.

New regression file run against corrected bootstrap-only prebuilt package:
`NOT_CRAN=true R_LIBS=<prebuilt> Rscript --vanilla -e 'x<-testthat::test_local(load_package="installed",filter="^cv-binomial-response$",reporter="summary",stop_on_failure=FALSE); saveRDS(as.data.frame(x),"dev/issue-1496/cv-red-tests.rds")'`
Observed20 failed assertions,2 errors,15 warning captures,17 passes. The failures include trial expansion metrics, trial truth, lost single-column weights, wrong fold denominator/logscore and missing null comparisons. See local cv-red-tests.log/RDS. Tests were subsequently expanded with boundary and mixed-wide regressions; those extra cases are prophylactic unless already covered by these red failures.

## Passing corrected-source checks

`R_LIBS=<prebuilt> GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla /tmp/gllvmTMB-1496-affected-heavy.R`
Compiler-free bootstrap/refit check before CV edits:14 files,78 test blocks,437 passing assertions,0 failures/errors/skips,23 warning captures. Warnings include deliberately tiny bootstrap intervals, unused optional cluster argument and rejected loading-bootstrap refits; no coverage certification. This uses the final bootstrap helper (namespace body verified against source), not the stale /tmp installation.

Final CV/encoding sweep:
```r
pkgload::load_all('.', compile=FALSE, quiet=TRUE)
x <- testthat::test_local(load_package='none',
  filter='^cv-(binomial-response|internal)$|^(bootstrap-binomial-response|bootstrap-isdm-response|cbind-binomial|binomial-cbind-missing-response|traits-cbind-binomial|wide-weights-matrix)$',
  reporter='summary', stop_on_failure=FALSE)
```
With GLLVMTMB_HEAVY_TESTS=1 and NOT_CRAN=true:7 selected files,308 passing assertions,0 failures/errors/warnings/skips.70 assertions in new CV file;119 existing CV assertions. cv-final-validation.log/RDS. The cbind-binomial alternative name matches no additional file; actual selection/count is reported, not inferred from regex alternatives.

`roxygen2::roxygenise(load_code=function(path) pkgload::load_all(path,compile=FALSE,helpers=FALSE,attach_testthat=FALSE)$env)` passed; only unrelated sigma S3 registration spelling drift was generated and restored. No public export/Rd change.
`pkgload::load_all(compile=FALSE); pkgdown::check_pkgdown()` passed; Pandoc mathml deprecation warnings remain.
`bash tools/check-actions-boundary.sh` and `bash tools/check-reader-surface.sh` passed. air format and R parse checks passed.

Independent statistical review supported frequency-weight metrics; implementation review caught a predictor-removal alignment gap. Required original formula/grouping columns are now checked, with a regression. Final review found no remaining source blocker.

## Full-suite boundary and partition proof

Bootstrap normal CI passed four shards at d8f3bbe4. Heavy run38832422557 reached120-minute timeout during tests; not a pass, no final summary. This does not certify this later CV source. Fresh exact-commit CI follows publication.

Current working source:678 test files, complete disjoint4-way partition170/170/169/169, verified with existing helper-shard-util.R and its actual regex filters. Only tests/testthat.R is a top-level R test entry point; no nested test-suite runners bypass its filter. Setup/helpers and package examples repeat per job. Re-prove at final commit. Optional manual heavy sharding workflow approval is pending; no workflow edit/run has been performed.

System git and compiler discovery encounter pending Xcode license (exit69). Existing gert/libgit2 works for source control, and pkgload compile=FALSE loads unchanged native code legitimately. Homebrew GCC16.2.0 exists but selects an Apple SDK; no toolchain substitution, direct Apple-tool bypass, license acceptance, security change or compiler rebuild attempted. Local full fresh package check remains unavailable via configured compiler.
