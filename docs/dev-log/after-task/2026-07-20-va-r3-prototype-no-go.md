# After task — Design 85 R3 VA prototype decision

**Branch:** `codex/va-r3-prototype-20260720`  
**Date:** 2026-07-20  
**Roles engaged:** Ada, Gauss, Noether, Curie, Fisher, Grace, Rose

## 1. Goal

Build the smallest internal full-covariance Gaussian-VA prototype needed to
falsify or admit a later high-dimensional experiment, compare it with the
landed q=1/q=2 references, and stop honestly if the sequential gates fail.

## 2. Implemented

- Added a research-only R/TMB VA objective for complete multi-trial
  binomial-logit ordinary `latent(..., unique = FALSE)` fixtures.
- Added stable one-dimensional H61 quadrature, analytic gradients, Gaussian
  exactness, O3 moment/bound checks, four deterministic starts, bounded polish,
  source provenance, and variance-domain failure.
- Added a resumable local/Totoro pilot runner with ML rank selection, retained
  failures, predictive replicate scores, and source/platform receipts.
- Corrected the final classifier to use any three agreeing healthy starts and
  made axis-collapse reporting unavailable when fitted and planted ranks differ.
- Ran 25 q1 plus 25 q2 Totoro replicates and closed the arc **NO-GO** before
  q4/q6. No larger campaign was run.

## 3a. Decisions and Rejected Alternatives

**Decision:** NO-GO; retain Laplace. **Rationale:** Gate 3 was not executed as
the frozen fixed-rank experiment, eight applicable fits failed the optimiser
gate, and gates are sequential. **Rejected:** running q4/q6 anyway, excluding
failures, treating conditional recovery as the missing denominator, widening
tolerances, or surfacing an API. **Confidence:** high for the stop decision;
the pilot is deliberately insufficient for a positive estimator claim.

**Plan versus actual (Melissa lens):** R0--R2 and the internal R3 prototype
landed; the q1/q2 25-replicate pilot ran on Totoro. R4 q4/q6 stress, the
100/500 promotion ladder, public surfaces, and release work were deliberately
not executed because the sequential stop rule fired. This is the planned
NO-GO branch of the approved funnel, not an incomplete GO path.

## 4. Files Touched

- `R/va-r3-proto.R`
- `inst/tmb/gllvmTMB_va_r3.cpp`
- `tests/testthat/test-va-r3-prototype.R`
- `tools/va-r3-pilot.R`
- `docs/design/85-highdim-nongaussian-va-formal-contract.md`
- `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`
- `docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md`
- `docs/dev-log/handover/2026-07-20-codex-handover-va-no-go.md`

No exported R function, NAMESPACE, package TMB engine, formula grammar, family,
README, NEWS, vignette, roxygen/Rd, pkgdown navigation, validation-register row,
or parked-lane file changed. The entangled `docs/dev-log/check-log.md` was not
touched.

## 5. Checks Run

- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter =
  "va-r3-prototype", stop_on_failure = TRUE)'` — PASS, 133 expectations.
- Totoro exact-source pilot — 50/50 receipts, no runner errors; corrected
  classification q1 22/24 applicable and q2 19/25.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test(stop_on_failure =
  TRUE)'` — 7,159 PASS, 780 declared opt-in skips, one warning, and the two
  pre-existing `vdiffr` mismatches in dispatcher communality/variance-partition
  snapshots. No VA test failed. The generated `.new.svg` files were removed
  and this diagnostic run is not the source-check admission receipt.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` with `NOT_CRAN=true` —
  PASS, no problems found. No rendered surface changed, so no article rebuild
  was required.
- Clean vignette-complete `R CMD build . --no-manual`, then CRAN-default
  `R CMD check --as-cran --no-manual gllvmTMB_0.5.0.tar.gz` — PASS with zero
  ERROR, zero WARNING, and one expected NOTE (`New submission`).
- `git diff --check` — PASS before each commit.

## 6. Tests of the Tests

Tests independently reconstruct the Gaussian posterior, KL, projected
variance, loading pack/unpack map, O3 fixed-coordinate bounds and moments, and
H15/H25/H61 ladder. Mutation/boundary fixtures cover q>=3 O3 rejection,
out-of-domain projected variance, malformed complete-response input,
small-variance derivative continuity, provenance failure, rank-zero stop, and
the any-three-of-four objective-agreement rule. The classifier test would fail
under the original range-over-all-four implementation.

## 7. Roadmap Tick

N/A. The public queue is already stale about the completed latent-rank article,
but this internal NO-GO arc does not change a public capability row. Mission
Control carries the decision without rewriting that unrelated shared queue.

## 7a. Issue Ledger

Targeted search inspected #705 (matrix-free stochastic-trace Gaussian REML),
#349 (power-simulation capstone), and #230 (article surface reset). None governs
this bounded non-Gaussian VA decision. No relevant open issue; no new issue
created, because the NO-GO explicitly forbids follow-up engine work absent new
evidence.

## 8. Consistency Audit

The final audit records the exact commands and verdicts:

- `rg -n "VA|variational|AGHQ|non-Gaussian REML|rank_source|failed_variance_domain" README.md ROADMAP.md NEWS.md docs vignettes R tests tools` — intentional research records and existing bounded public landscape wording only; no new capability claim.
- `rg -n "logLik|AIC|BIC|REML|AGHQ|q ?[>=]+ ?3|public|export" R/va-r3-proto.R inst/tmb/gllvmTMB_va_r3.cpp tests/testthat/test-va-r3-prototype.R tools/va-r3-pilot.R docs/design/85-highdim-nongaussian-va-formal-contract.md` — prohibitions and ML rank-hand-off bookkeeping only; the prototype exposes no likelihood-like method or export.
- `rg -n "gllvmTMB_va_r3|\.va_r3_" NAMESPACE R man vignettes README.md NEWS.md _pkgdown.yml` — internal R definitions only; no NAMESPACE, help, article, README, NEWS, or navigation surface.

## 9. What Did Not Go Smoothly

The first pilot classifier was stricter than its own contract, and the runner
combined Gate 3 and Gate 4. One rank-mismatched collapse was initially counted
as if ranks agreed. Independent review found all three problems before a public
or scaling claim. A prematurely started full test run was interrupted after the
branch changed and is not cited as evidence; the final-head run replaces it.

## 10. Known Residuals

This work provides no VA validation, q4/q6 evidence, coverage, intervals,
rank-selection calibration, structured covariance, missing-data, mixed-family,
non-Gaussian REML, AGHQ fitting, public API, or release readiness. Retain
Laplace. The next package arc returns to the existing 0.6 queue/closeout; VA is
reopened only under a separately approved plan prompted by genuinely new
evidence.

## 11. Team Learning

**Ada:** sequential gates need separate executable fixtures, not merely prose
labels in one runner. Future funnels should encode each gate as its own mode.

**Gauss:** stable H61 quadrature, analytic gradients, bounded polishing, and
source-compiled TMB gave a credible numerical falsification harness without
touching the production likelihood.

**Noether:** “three of four agree” is not “all healthy starts agree,” and a
collapse comparison is undefined across different ranks. Mathematical review
must include classification and reporting code.

**Curie/Fisher:** all-attempt denominators and planted-rank targets must be
decided before fitting. Conditional healthy-fit recovery cannot repair a
missing experimental cell.

**Grace:** source commit, checksum, host, R version, seeds, and retained failures
made the negative result auditable. Positive timing/recovery would additionally
need a clean fixed-rank runner and complete derived summaries.

**Rose:** the stop decision is useful only if it propagates to every intended
claim surface. Here the correct propagation is an internal design/audit receipt
plus Mission Control, with public surfaces unchanged.

## 12. Cross-Product Coverage

This arc covers the internal complete multi-trial binomial-logit q1/q2
prototype and its negative scaling decision. It does NOT cover q4/q6,
structured covariance, `Psi`, random slopes, missing responses, Bernoulli,
mixed families, non-Gaussian REML, interval calibration, coverage, public API,
pkgdown teaching, or release readiness.

## 13. Mathematical Contract

The internal objective is the Design-85 ELBO for
`q_i(u_i)=N(m_i,L_i L_i^T)`, complete multi-trial binomial-logit responses,
and `u_i~N(0,I)`, evaluated by one-dimensional H61 Gauss--Hermite quadrature.
It is not a marginal likelihood, REML, AGHQ estimator, AIC/BIC source, or
frequentist uncertainty calculation. There is no public API, likelihood,
formula-grammar, family, NAMESPACE, generated-Rd, vignette, or pkgdown change.
