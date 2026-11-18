<!--
Evidence-chapter draft section for the gllvmTMB methods paper.
No manuscript directory (docs/paper/, paper/, ms/, .tex, .qmd with manuscript
frontmatter) exists in this repository as of this writing; this file is a
standalone markdown draft pending a decision on manuscript format and
location. Convert headings/citations to the paper's eventual format
(LaTeX/Quarto) at integration time. Cross-references are left as HTML
comments naming the source file and are not yet resolved to paper section
numbers or a bibliography.
-->

# Missing-response uncertainty is information-limited by design shape, not sample size

<!-- source: docs/design/119-predict-missing-uncertainty.md (secs 7-8) -->
<!-- source: docs/dev-log/handover/2026-08-16-claude-handover-missing-data-arc-closed.md -->
<!-- source: docs/dev-log/2026-08-15-missing-data-evidence-chapter-DRAFT.md (sec 4, for cross-check) -->

## Motivation

`predict_missing()` reconstructs masked response cells from the fitted
model's fixed effects, latent scores, and loadings, returning point
reconstructions only; standard errors and prediction intervals are
documented as not currently returned. Two considerations motivated closing
this gap. First, the package's existing standard-error machinery
propagates only the fixed-effect block, holding random effects at their
conditional mode with zero derivative — adequate elsewhere, but understating
uncertainty specifically at a masked cell, where the linear predictor is
dominated by the latent-score term. Second, a calibrated reconstruction
interval would be a genuine capability the closest published competitor for
phylogenetic imputation does not offer, since its EM algorithm carries a
conditional covariance internally but never surfaces it as an interval.

Two targets were distinguished throughout and never conflated: a
confidence interval for a masked cell's conditional mean, and a
(necessarily wider) prediction interval for the value itself, which
additionally carries the family's variance function.

## A pre-registered calibration gate

Following the package's standing rule that interval claims do not survive
without pre-registered coverage evidence, a route had to clear an explicit
gate before advertising: for a nominal 90% or 95% interval, empirical
coverage within twice the Monte Carlo standard error of nominal, on a
fixed, pre-declared grid, failure-inclusive. Until cleared, the feature
would ship internal-only, flagged unvalidated.

## Six routes, one grid

Six candidate variance routes were measured on one identical 1,600-fit
gaussian grid (50 units, 25 traits, two latent dimensions, four
missingness mechanisms spanning uniform and structured missing-at-random
designs, 400 replicates/cell), making the comparison exact rather than
approximate. Each route propagates strictly more uncertainty than the
last. The cheapest — fixed-effect block plus a diagonal latent-curvature
term — over-covered at 95% (0.960–0.966). The exact joint precision
under-covered (0.925–0.933). Adding the missing loading-derivative block —
at which point no gradient term remained missing, checked against a dense
brute force — improved but still fell short (0.935–0.939). An
empirical-quantile route (draws from the estimated joint precision, no
normality assumption, exact family draw) was best-measured at 0.941–0.946
against nominal 0.95, and still failed. A full parametric bootstrap
(B=200, refitting on every replicate, propagating essentially everything)
performed *worse* (0.926–0.933) — routes propagating strictly more
uncertainty were not converging monotonically toward nominal, so the
deficit was not a missing propagation term.

A final variant generated the bootstrap's simulated world from an
auxiliary REML fit rather than the maximum-likelihood fit, whose
small-sample bias was suspected of narrowing the bootstrap's own
data-generating process. Coverage moved the correct direction in all 16
measured cells — a uniform sign ruling out noise — but recovered only
about 18% of the gap, still four to eight times outside the gate. This was
the final route tried under a stopping rule fixed and time-stamped before
that run's data existed: narrows-but-fails means document the measured
coverage and stop, rather than proceed to a further, costlier variant.
That rule fired as specified. No route reached calibration;
`predict_missing()` standard errors remain internal, unvalidated, and
unexported; the best measured coverage — roughly 93–95% actual for nominal
95% — is reported rather than withheld.

## The mechanism: traits per unit, not units

The stopped programme's working explanation named a small-sample property
of the fitted model at this scale, without testing sample size and trait
count separately. A follow-up swept each axis in isolation on the
cheapest well-measured route. Sweeping sample size across a 32-fold range
(50 to 1,600 units, traits fixed at 25) left the confidence-interval
deficit essentially flat (0.61 to 0.51 points short of nominal, slope
−0.046 points per e-fold). Sweeping trait count across a 10-fold range
instead (10 to 100 traits, units fixed at 200) cut the same deficit 78%
(1.32 to 0.29 points), reaching nominal at 100 traits for the 90% level.
Prediction intervals showed the converse pattern — deficit tracking sample
size (roughly halving) and flat against trait count. This double
dissociation identifies the mechanism: a masked cell's linear predictor
sums a fixed-effect term and a latent-score term, and a unit's latent
score is reconstructed almost entirely from that same unit's *other
observed traits* — information scaling with traits measured per unit, not
with how many other units exist. Confidence-interval calibration improves
with more traits per unit and is largely indifferent to more units;
prediction-interval calibration additionally carries the residual
variance, estimated globally across all cells, so it improves with units
instead.

This mechanism was reached independently, from an unrelated direction, on
this package's adaptive-quadrature engine: a flat downward bias in latent
SD estimates that a sixteen-fold increase in sample size did not move,
attributed there to an error term governed by traits per cluster rather
than cluster count. Two unrelated investigations, different estimands,
converged on the same lesson: in a stacked-trait model, within-unit
accuracy is governed by traits measured per unit, and dataset size along
the unit dimension is the wrong lever.

## Why this is mechanistic, not merely empirical

An empirical negative says a method failed on a given grid and leaves open
whether more compute would close the gap. This result instead identifies
*why* more data along the obvious axis cannot: the information a masked
cell's uncertainty depends on is structurally bounded by traits per unit,
not dataset size. No further variance route, and no larger sample size in
the ordinary sense, addresses that limit; only more traits per unit does.

## Practical guidance and scope

The actionable consequence: where calibrated reconstruction intervals
matter, the lever is more traits per unit, not more units. Point
reconstructions from `predict_missing()` are unaffected — this concerns
interval calibration only, not point accuracy, which was evidenced
separately: clearly above a naive baseline for some response families
(multinomial), while for others (binary, ordinal, hurdle-type) accuracy
sits near baseline and is deliberately not advertised. Scope: gaussian responses, a two-dimensional latent structure,
an unstructured covariance, four missing-at-random mechanisms, 400
replicates per cell; it does not speak to other families, higher-dimensional
latent structures, or missing-not-at-random mechanisms.
