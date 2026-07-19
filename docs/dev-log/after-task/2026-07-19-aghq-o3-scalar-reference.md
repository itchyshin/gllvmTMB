# After Task: O3 Scalar AGHQ / Cox--Reid Research Reference

**Branch:** `codex/aghq-o3-research-planning-20260719`
**Date:** 2026-07-19
**Role engaged:** Ada (implementation and evidence record)

## 1. Goal

Establish a small, reproducible numerical reference for scalar binomial AGHQ
and a Cox--Reid outer adjustment before considering any gllvmTMB integration.

## 2. Implemented

- `dev/aghq-o3-scalar-spike.R`: scalar adaptive Gauss--Hermite marginal ML
  and Cox--Reid reference, including safe log-scale summation.
- `tests/testthat/test-aghq-o3-scalar-spike.R`: deterministic node-ladder,
  finite Cox--Reid, and optional `lme4` external-comparator checks.
- `docs/dev-log/spikes/2026-07-19-aghq-o3-scalar-research.md`: exact model,
  coordinates, observed result, boundaries, and promotion/stop rules.

## 3. Mathematical contract

The reference is a scalar binomial-logit random intercept with fixed
\(\beta\) coordinates and a positive SD parameterised as \(\log\sigma\).
It is not a gllvmTMB estimator, does not alter TMB, and does not resolve
latent-loading rotation or a coupled multivariate integration block.

## 3a. Decisions and Rejected Alternatives

Decision: start with a pure-R scalar reference and require independent
one-node and high-node comparators before any TMB hook.  Rejected: adding an
unvalidated public `REML` or AGHQ interface.  The latter would conflate a
numerical experiment with a supported non-Gaussian estimator.

## 4. Files Touched

- `dev/aghq-o3-scalar-spike.R`
- `tests/testthat/test-aghq-o3-scalar-spike.R`
- `docs/dev-log/spikes/2026-07-19-aghq-o3-scalar-research.md`
- `docs/dev-log/after-task/2026-07-19-aghq-o3-scalar-reference.md`

`docs/dev-log/check-log.md`, the Bartlett worktree, CI-11, multinom/tier-2a,
and Ayumi were deliberately untouched.

## 5. Checks Run

- `gh pr list --state open` -> no open PR listed before the dev-log edit.
- `git log --all --oneline --since='6 hours ago' -20` -> reviewed for an
  overlapping dev-log lane; none found for this O3 reference.
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-aghq-o3-scalar-spike.R", reporter = "summary")'`
  -> PASS (four expectations).
- `Rscript --vanilla dev/aghq-o3-scalar-spike.R` -> PASS; node ladder stable
  by 15 versus 25 nodes and finite Cox--Reid result.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> PASS; full package suite completed after adding the scalar reference test.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS; no pkgdown
  problems.
- `R CMD build . && R CMD check --as-cran gllvmTMB_0.5.0.tar.gz` -> PASS;
  all package tests, vignettes, manuals, and checks passed with the standard
  `New submission` NOTE only.
- `git diff --check` -> PASS.

No compute campaign, public claim, or release gate was run: the clean local
check is package-health evidence, not evidence that O3 is ready to ship.

## 6. Tests of the Tests

The node ladder would fail on a material quadrature-regression for the fixed
fixture.  Where `lme4` is installed, the test independently checks the
one-node Laplace and 25-node AGHQ values.  A finite Cox--Reid result alone is
explicitly insufficient to promote any inference claim.

## 7a. Issue Ledger

No GitHub issue was opened, changed, or closed.  This research-only reference
does not tick a public roadmap item.

## 8. Consistency Audit

The new record consistently says “reference”, “research-only”, and “not a
package feature”.  No public file was changed, so the Rose pre-publish gate is
not applicable at this stage.

## 9. What Did Not Go Smoothly

The initial mode-cache expression treated an unfilled list element as a valid
numeric start.  It was corrected to use zero when the cache element is `NULL`.
The deterministic receipt and test then passed.

## 10. Known Residuals

No public claim moves.  The 0.6 Gaussian REML certificate remains withheld.
This reference has no gllvmTMB unit-score hook, no coupled q=2 block, no
recovery or coverage campaign, and no release implication.

## 11. Team Learning

The useful low-cost boundary is scalar AGHQ first: it lets us validate
quadrature, Laplace equivalence, coordinate treatment, and Cox--Reid
numerics before coupling them to the much harder gllvmTMB latent block.

## 12. Cross-Product Coverage

This arc covers only the standalone scalar binomial numerical mechanism,
including the one-node/Laplace and high-node external comparisons.  It does NOT cover gllvmTMB's TMB engine, any family implementation, a public `REML`
argument, predictor-informed latent scores, rank selection, missingness,
aggregation, covariance tiers, q=2 integration, recovery, coverage, pkgdown,
or a release claim.  The next task must construct and validate a scalar
gllvmTMB unit-score hook in fixed coordinates; it must stop before q=2 if the
one-node comparison, node ladder, or coordinate contract fails.
