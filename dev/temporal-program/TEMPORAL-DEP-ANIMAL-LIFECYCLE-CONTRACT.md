# Replicated temporal-dependent animal lifecycle contract

## Purpose

This contract admits two composed lifecycle routes for one replicated Gaussian
identity-link AR1 `temporal_dep() + animal_indep()` fit: a direct profile of
the fitted persistence parameter and an unconditional parametric bootstrap
that refits the saved public call.  The covariance is additive,

\[
  1(g=g')\phi^{|t-t'|}\Sigma_{T,jj'} +
  A_{hh'}1(j=j')v_{A,j} + 1(i=i')\sigma_\epsilon^2,
\]

where \(\Sigma_T\) is the full temporal trait covariance and \(A\) is the
fixed labelled animal relationship.  Neither helper fits an animal-by-time
product, conditions on fitted random effects, or changes the estimator.

`profile_temporal()` holds only `theta_temporal_time` fixed at each point and
re-optimizes the full packed temporal covariance, all animal variances, the
measurement variance, and fixed effects in the marginal TMB/Laplace objective.
Its reported AR1 scale is
\(\phi=(1-10^{-6})\tanh(\theta_{temporal})\).  Its endpoints are not
calibrated intervals.

For each `bootstrap_temporal()` attempt, `simulate(..., condition_on_RE =
FALSE)` redraws the complete joint temporal-plus-animal response.  The helper
replaces only the response column in the saved long or wide training data and
uses `update()` to refit it.  Every draw seed, objective, persistence estimate,
convergence code, and failure text is retained.

## Admission and refusals

Require exactly one replicated Gaussian AR1 temporal-dependent intercept block
and one fixed intercept-only `animal_indep()` block at `rho = 1`, with no
ordinary tier, kernel, phylogenetic, spatial, attenuation, slope, second
source, temporal Psi, or additional temporal block.  The relationship may have
entered through a labelled dense `A`, pedigree, or sparse `Ainv`, provided the
saved public call is replayable.

Refuse OU, temporal-independent or rank-one animal pairs, generic bootstrap
or profile APIs, profiles of covariance entries or animal variances, selection, intervals, and
every other source pair. Forecasting has a separate full
conditional-Gaussian contract; it is not an interval or a generic new-data route.

## Required evidence and boundary

The focused lifecycle tests must (1) compare the transformed profile estimate
with the direct `TMB::tmbprofile()` trace at the fitted objective, (2) prove
that a changed OU structure is refused, and (3) obtain two deterministic
unconditional redraw/refit attempts with one retained row per draw.  Existing
temporal-dependent animal tests separately establish its independent dense
likelihood/gradient oracle, relationship representations, update replay, and
unconditional simulation covariance.

This is local helper evidence only.  It does not change the retained failed
dependent-animal recovery gate, establish bootstrap sampling properties,
interval calibration or coverage, forecast calibration, cross-platform
verification, merge, or release readiness.
