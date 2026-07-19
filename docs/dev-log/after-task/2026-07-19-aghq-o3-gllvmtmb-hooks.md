# After Task: O3 gllvmTMB Unit-Score Hooks

**Branch:** `codex/aghq-o3-unit-hook-20260719`
**Date:** 2026-07-19
**Role engaged:** Ada (implementation and numerical evidence record)

## 1. Goal

After the scalar O3 reference merged, verify the corresponding fixed-coordinate
gllvmTMB unit-score factor for q = 1, then make a bounded q = 2 numerical
decision without widening to a user-facing feature.

## 2. Implemented

- `dev/aghq-o3-gllvmtmb-unit-hook.R`: extracts a fitted binomial d = 1
  `latent(..., unique = FALSE)` unit factor and reconstructs its adaptive
  integral.
- `dev/aghq-o3-q2-coupled-spike.R`: q = 2 adaptive tensor-grid reference
  with a Cholesky-Hessian transform and conditioning gate.
- Two focused deterministic testthat files, one for each reference.
- The companion spike records exact coordinates, numerical results, and the
  q >= 3 stop decision.

## 3. Mathematical Contract

`b_fix` and `Lambda_B` are held at the existing joint ML fit.  For every unit,
the reference integrates only the standard-normal score block.  The one-node
adaptive rule is therefore compared to the existing joint TMB Laplace
objective.  Neither script estimates a new parameter, profiles a fixed-effect
coordinate, nor evaluates a restricted likelihood.

## 3a. Decisions and Rejected Alternatives

Decision: implement q = 1 and q = 2 only as independently reconstructed,
fixed-coordinate numerical references.  Rejected: a generic high-dimensional
tensor quadrature helper or a public AGHQ/REML argument.  The latter would
offer a scalability and inference claim unsupported by this evidence.

## 4. Files Touched

- `dev/aghq-o3-gllvmtmb-unit-hook.R`
- `dev/aghq-o3-q2-coupled-spike.R`
- `dev/aghq-o3-scalar-spike.R` (now a thin local runner for the canonical helper)
- `tests/testthat/test-aghq-o3-gllvmtmb-unit-hook.R`
- `tests/testthat/test-aghq-o3-q2-coupled-spike.R`
- `tests/testthat/test-aghq-o3-scalar-spike.R` (now sources the packaged helper)
- `tests/testthat/helper-aghq-o3.R` (canonical scalar, q = 1, and q = 2
  numerical reference implementation)
- `docs/dev-log/spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md`
- `docs/dev-log/after-task/2026-07-19-aghq-o3-gllvmtmb-hooks.md`
- `docs/dev-log/handover/2026-07-19-codex-aghq-o3-handoff.md`

`docs/dev-log/check-log.md`, Bartlett, CI-11, multinom/tier-2a, and Ayumi
were deliberately untouched.

## 5. Checks Run

- `gh pr list --state open` and `git log --all --oneline --since='6 hours ago' -20`
  -> reviewed before editing the shared dev-log folders; no competing O3
  writer found.
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-aghq-o3-gllvmtmb-unit-hook.R", reporter = "summary")'`
  -> PASS (two expectations).
- `Rscript --vanilla dev/aghq-o3-gllvmtmb-unit-hook.R` -> PASS; q = 1
  reconstructed Laplace difference `1.39e-9` and 15/25 ladder passed.
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-aghq-o3-q2-coupled-spike.R", reporter = "summary")'`
  -> PASS (three expectations).
- `Rscript --vanilla dev/aghq-o3-q2-coupled-spike.R` -> PASS; q = 2
  reconstructed Laplace difference `9.84e-8`, 7/9 ladder passed, and maximum
  condition number was `1.79`.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> the new O3 tests passed, but the full suite ended with the two existing
  `vdiffr` failures for dispatcher communality and variance-partition plots.
  Their `.new.svg` candidates were left untracked and untouched; they do not
  involve these O3 files.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS; no pkgdown
  problems.
- After the preceding PR's Ubuntu CI failed because `R CMD build` excludes
  `dev/`, moved the canonical O3 helpers to
  `tests/testthat/helper-aghq-o3.R`; all three test files now source that
  packaged-test helper and the three `dev/` scripts are thin local runners.
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file(...)'` for the
  scalar, q = 1 hook, and q = 2 hook files -> PASS after that repair; direct
  `Rscript` execution of all three `dev/` runners also -> PASS.
- `NOT_CRAN=true R CMD build . && R CMD check --as-cran gllvmTMB_0.5.0.tar.gz`
  -> the former missing-`dev/` O3 test error did not recur.  The check ended
  with the same two visual-snapshot test failures (5345 pass, 809 skip) and
  two NOTE conditions: the standard new-submission NOTE plus a non-portable
  path NOTE because the deliberately preserved local `.new.svg` candidates
  were included in this local tarball.  The clean CI checkout does not contain
  those untracked candidates and is the decisive source-build receipt.
- `git diff --check` -> PASS.
- `tools/handoff_gate.sh` -> expected local-residue warning only: the two
  preserved visual `.new.svg` candidates remain untracked and many historical
  branches elsewhere in the shared clone are unpushed.  The O3 commit itself
  is pushed; neither the snapshot candidates nor the unrelated branches were
  deleted, staged, or altered.

No coverage/recovery campaign, Totoro/DRAC run, public documentation render,
release gate, or claim promotion was run: these fixed-fixture numerical checks
do not justify any of them.

## 6. Tests of the Tests

The q = 1 test fails if the package's joint Laplace objective and independently
reconstructed one-dimensional factor cease to agree.  The q = 2 test separately
fails on the Laplace identity, node-ladder instability, or poor local Hessian
conditioning.  The tests do not test finite-sample inferential quality.

## 7a. Issue Ledger

No GitHub issue was opened, edited, or closed.  This closes a bounded research
substage, not a public roadmap item.

## 8. Consistency Audit

`rg -n -i 'non-gaussian.*reml|aghq|gaussian-only rem[lm]|release-ready|release ready'
README.md NEWS.md docs/design/01-formula-grammar.md
docs/design/35-validation-debt-register.md _pkgdown.yml` -> REVIEWED.  The
public surfaces retain Gaussian-only REML and research-planned AGHQ wording;
this branch changes none of them.  Rose's narrow claim audit therefore PASSes:
no public-facing surface, validation-debt status, NEWS entry, roxygen page,
article, or pkgdown navigation was changed.

## 9. What Did Not Go Smoothly

The first reconstructed scalar attempt used a Bernoulli log-density while the
gllvmTMB fixture stores multi-trial binomial counts.  Reconstructing the exact
`dbinom(y, n_trials, ...)` kernel corrected the comparison and exposed the
needed equality to numerical precision.  The first scalar PR also revealed
that package-check tests cannot source `dev/`; the shared test helper repair
keeps the implementation runnable both locally and from the built test tree.

## 10. Known Residuals

The 0.6 Gaussian REML certificate remains withheld.  No non-Gaussian REML or
AGHQ estimator, Cox--Reid calculation in gllvmTMB coordinates, q >= 3 method,
or recovery/coverage evidence exists.  Remote CI for the preceding scalar
reference PR was still in progress when this hook work began.

## 11. Team Learning

Matching the joint Laplace objective first is a useful fail-fast gate: it
validates the selected conditional likelihood, normal prior, loading order,
and Hessian transform before a quadrature result is interpreted.  q = 2 can
be a diagnostic reference; it is not a credible general-purpose route.

Curie/Fisher evidence verdict: PASS only for the fixed-coordinate q = 1/q = 2
numerical stop decision; withhold recovery, calibration, coverage, robustness,
practical AGHQ-fitting, Cox--Reid, and non-Gaussian REML claims.  Rose verdict:
PASS on public-claim alignment after the complete file inventory and surface
scan; no public capability or release claim has moved.

## 12. Cross-Product Coverage

This arc covers only fixed-coordinate, multi-trial binomial ordinary latent
unit-score numerical references for q = 1 and q = 2.  It does NOT cover the
gllvmTMB public engine/API, Gaussian REML scope, non-Gaussian restricted
likelihood, Cox--Reid in rotating/loading coordinates, other families,
unique/Psi terms, predictor-informed scores, rank selection, missingness,
aggregation, q >= 3, recovery, coverage, pkgdown, CI policy, or release
readiness.
