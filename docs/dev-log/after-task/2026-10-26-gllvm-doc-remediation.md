## 1. Goal

Implement the approved first-wave documentation fixes from the twin audit: D001, D008, D011, D012, D036, and D039, using one coordinated lane and separate package changes. Resolve D010 only after its bridge/inference owner approves its example and diagnostic scope.

## 2. Implemented

- R D001: made the data-loading and setup chunks visible and executable in the affected articles.
- R D008: corrected the README interval-default summary by target and directed readers to the returned method and target help.
- R D039: described the integrated example's optimizer convergence as PASS and Hessian positive-definiteness as WARN, with the warning scoped to curvature.
- Julia D011/D012: clarified that score uncertainty conditions on fitted fixed parameters and stated the precision/Hessian sign convention; documented TMB's default parameter-uncertainty propagation and the conditional comparison option.
- Julia D036: added the missing direct `Poisson` import to the documented cross-validation example.

## 3a. Decisions and Rejected Alternatives

- D010 remains deferred because no owner approval for the bridge/inference example and diagnostic scope was received.
- Deployment remains deferred. No parity, calibration, or general interval-coverage claim was added.
- Assumption: the two package changes can share a remediation goal while using separate branches and PRs, as approved.

## 4. Files Touched

- R: `README.md`; `vignettes/articles/morphometrics.Rmd`; `vignettes/articles/covariance-correlation.Rmd`; `vignettes/articles/random-regression-reaction-norms.Rmd`; `vignettes/articles/pitfalls.Rmd`; `vignettes/articles/integrated-multi-source-example.Rmd`.
- Julia: `docs/src/se-profile-machinery.md`; `src/cv.jl`.
- R and Julia: dated check-log and after-task records.

## 5. Checks Run

- All five affected R articles rendered after final edits: all exited 0. The exact source package was installed in a temporary library; three articles were built individually after the full run reached covariance and integrated multi-source pages.
- `pkgdown::check_pkgdown()`: passed.
- The first full `pkgdown::build_articles()` attempt loaded a stale installed package, whose `extract_correlations()` signature rejected `entries = "all"`. After installing the exact checkout in a temporary library, the full build passed covariance and integrated multi-source pages but was stopped after exceeding its 15-minute estimate. The full 42-article build is incomplete.
- `pkgdown::build_article()` passed for morphometrics, random-regression, and pitfalls using that temporary library. All five affected HTML outputs were generated and checked under ignored `pkgdown-site/articles/`.
- Julia Documenter/VitePress build with deployment disabled: exited 0.
- Exact Julia Poisson CV examples for random-cell and site-block splits: both executed and returned finite metrics.
- `git diff --check` passed in both worktrees; prose style checks had no findings other than the documented checklist waiver.

## 6. Tests of the Tests

No test files or implementation behavior changed, so no test was added. The exact Julia example was executed; the R example chunks were rendered and evaluated. No negative-control corruption test was relevant to these documentation-only corrections.

## 7a. Issue Ledger

- Fixed: D001, D008, D011, D012, D036, D039.
- Deferred: D010 pending bridge/inference owner approval.
- Follow-up: full 42-article build remains incomplete. The first run used a stale installed library; the exact-source retry passed the affected covariance and integrated pages before its time limit. Preserve the initial shared sass cache permission warning as an environment issue.

## 8. Consistency Audit

Reviewed the six R public surfaces and both Julia surfaces in the approved first wave. All five affected R HTML pages were generated, and the Julia site build verified cross references and doctests. The full 42-article R build remains incomplete.

## 9. What Did Not Go Smoothly

The first full R article build loaded a stale installed namespace and failed at `covariance-correlation.Rmd:438-447` with `unused argument (entries = "all")`. Installing the checkout fixed that issue. The 42-article run then exceeded its 15-minute estimate and was stopped after the affected covariance and integrated pages rendered. The closeout helper also resolves its output root to the brain repository rather than either package worktree, so records had to be created directly.

## 10. Known Residuals

- The full 42-article R build remains incomplete; all five affected pages and `pkgdown::check_pkgdown()` passed.
- D010 remains pending owner approval.
- No deployment or public claim was made.

## 11. Team Learning

When a full article build fails but the edited articles render individually, report both levels of evidence and retain the exact failing chunk. A package build can load a different function surface than a direct article render; compare the loaded namespace and source before treating the failure as unrelated.

Memory receipt: used the repo instructions and routed GLLVM/gllvmTMB dossier notes; the route manifest reported no manifest. Their ownership and public-claim boundaries shaped the scope. Golden Set: not checked because this slice changed documentation only and no known-mistake engine class was in scope.

## 12. Cross-Product Coverage

Covers: the named public README/article and Julia reference/example surfaces.

Does NOT cover: D010, any engine behavior, full R article-suite success, deployment, parity, or interval calibration.
