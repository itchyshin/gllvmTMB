# Current-engine loading-ridge comparison, 18 October 2026

## Decision

Retain the unpenalised ordinary native-Laplace default, equivalent to
loading_ridge = Inf. Its formal NULL spelling and separate AGHQ defaults
are unchanged. Shinichi approved this decision after reviewing the completed
study, then requested permanent records and guidance on when to try 2.

Ridge 2 is an explicit sensitivity choice for extreme or unstable ordinary
between-unit loadings. It supplies a Gaussian loading prior, not a general
Hessian repair. Compare scientifically meaningful covariance/effect estimates
and uncertainty, and report sensitivity to the prior scale.

## Design and estimands

The source pin is 161abe09a417cad88b51c018a09a930d964ee3de. Totoro ran 32
single-thread workers using the private pilot binary under R 4.6.1 and TMB
1.9.25. The 12 conditions combine grouped-binomial probit, replicated
Gaussian and replicated Poisson; n = 100 or 400; loading multiplier 0.5 or 2.
Each has 500 independent datasets, paired at Inf, 1, 2 and 4: 24,000 fits.
The frozen task manifest and generator fix independent data/initialisation
seeds, six traits, rank two, estimated per-trait diagonal unit covariance
and one latent predictor. Data and initialisation seeds are shared across
all four arms of each dataset. Gaussian and Poisson have two visits;
binomial trial totals cycle through 2, 7 and 20. See runner/generate.R for
the exact fixed truths and row mapping. No truth is redrawn across datasets.

Recovery targets are shared, unique and total unit covariance, induced
trait effects B_lv = Lambda alpha, and conditional fitted response means
at observed units. The three primary effects are t1 positive, t3 zero and
t4 negative. No raw loading-axis interval is scored. Intervals use the
public extract_lv_effects(type = "trait_effect", method = "wald") route;
finite-ridge bounds are local approximate posterior intervals conditional
on tau. The experiment measures their repeated-sampling containment.

## Results

| tau | Attempts | Fit/extractor exceptions | Optimiser code 0 | Non-PD Hessian / unavailable intervals |
|---|---:|---:|---:|---:|
| Inf | 6,000 | 0 | 6,000 | 64 |
| 1 | 6,000 | 0 | 6,000 | 56 |
| 2 | 6,000 | 0 | 6,000 | 66 |
| 4 | 6,000 | 0 | 6,000 | 62 |

All attempts and 144,000 effect rows remain in the summaries. Finite-bound
conditional coverage includes every available interval without filtering on
optimiser code. Interval availability and the all-attempt covered fraction
are separate columns. Point recovery includes every finite estimate.
Paired contrasts use common finite pairs with explicit dropped counts.
Monte Carlo standard errors use independent datasets, never trait rows.

Ridge 2 lowered observed mean total-covariance relative Frobenius error in
all 12 conditions. The largest improvement was grouped-probit, n = 100,
strong loadings: 0.254668 to 0.236599, paired difference -0.018069 with Monte
Carlo standard error 0.002095. Positive/zero/negative effect RMSE changed
from 0.25037/0.27658/0.24187 to 0.24576/0.27049/0.23628. Gaussian effect
recovery changed very little. These are descriptive cell-specific gains,
not a universal accuracy ranking.

In that same binomial condition, positive-effect finite-bound coverage was
92.05%, 90.06%, 91.63% and 92.10% for Inf/1/2/4. Zero-effect coverage was
94.77%, 92.55%, 94.14% and 94.39%. The all-attempt covered-fraction
contrasts for 2 minus Inf were -0.4 percentage points (positive) and -0.6
(zero), with paired Monte Carlo standard errors 0.94 and 0.96 percentage
points. Smaller differences are not resolved clearly by this experiment.
The negative effect in weak-loading Poisson at n = 100 retained about 91.1%
coverage at all four settings. Ridge 2 restored intervals on 16 datasets
relative to Inf and lost them on 18; 48 were unavailable under both.

## Files and provenance

recovery.csv has 48 cell/scale summaries; effects.csv has 288 target
summaries, including all six effects; paired-vs-Inf.csv has 180 paired
comparisons with Monte Carlo uncertainty. summary.json records all-attempt
counts and interval statuses. unique-recovery-summary.csv separately
summarizes public unique-variance recovery. The original collector expected
a matrix but the public unique extractor returns the variance vector s.
Supplementary recovery uses diag(s), verified against exp(2*theta_diag_B)
and total minus shared covariance. Original attempts were preserved and
no fit was repeated to correct this representation mismatch.

All 24,000 raw fit/result pairs passed 17 independent retained-object
checks, with no audit errors. All 18,000 finite-ridge arms passed exact
curvature provenance and deliberately mismatched-metadata controls. Counts
are in independent-audit-counts.csv. The audit rejects empty objects and
never evaluates serialized native objective pointers.

The raw inventory retains 6,000 fixtures, 24,000 fits, 24,000 result RDSs
and 48,000 arm/effect CSVs, about 27.4 GB in total. Raw objects remain on
Totoro, and every CSV is also in the local archived attempt ledger. All
48,000 member digests were verified after transfer. provenance.json gives
exact paths, source/binary hashes and runtime; retention.sha256 and
evidence-metadata.sha256 bind the retained private archives. Campaign
outputs were not stored as GitHub Actions artifacts. SHA256SUMS inventories
this portable aggregate and runner record. It does not bundle the private
raw fits or installed binary.

## Scope

Validation mapping: EXT-31 remains partial; MSPL-05 is unchanged. This adds
fixed-truth native-Laplace evidence and preserves previous broader evidence.
It does not compare MSPL, AGHQ, VA or Julia, calibrate covariance or score
intervals, certify intercept-only ordination, or support general 95%
coverage. The user-facing workflow is in the fit-diagnostics article.
