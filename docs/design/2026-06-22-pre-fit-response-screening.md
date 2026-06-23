# Pre-fit response screening for binary candidate traits

Date: 2026-06-22

Status: implemented as `screen_gllvmTMB()` v1; validation row `DIA-14`.

## Purpose

`screen_gllvmTMB()` is a formula-aware pre-fit screen for candidate
responses before fitting a stacked-trait GLLVM. It answers:

> Are these traits, items, or indicators risky to put into this exact model?

It does not select variables, remove responses, choose a latent rank, prove
identifiability, solve separation, or guarantee convergence. The first module
is binary/binomial because this is where constants, near-constants, duplicates,
complements, sparse minority outcomes, and separation-like designs most often
create runaway fitted loadings.

The immediate applied trigger is Ayumi-495/urbanisation_map#3. The issue asks
for clearer package-side support when near-universal binary indicators later
produce very large loadings and weak-axis diagnostics. PR #524 adds a post-fit
`check_gllvmTMB()` diagnostic. `screen_gllvmTMB()` is the pre-fit companion:
it points users to the candidate indicators that should be checked before the
first latent block is fitted.

## Formula-aware scope

"Formula-aware" means model-design-aware, not only "scan a response matrix".
The screen reuses the package's existing formula preparation where possible:

- `traits(...)` wide-to-long rewriting;
- long-format `trait =` and `unit =` columns;
- response-missing row dropping through `drop_missing_response_rows()`;
- weight-shape normalisation through `normalise_weights()`;
- binomial response interpretation for Bernoulli rows, `cbind(success, failure)`
  responses, and flat successes with `weights = n_trials`;
- fixed-effect model-frame and model-matrix construction;
- parsed covariance terms so requested latent rank can be compared with the
  number of screened traits.

This makes the screen about the candidate responses under the same formula
shape that the user intends to fit.

## Evidence-informed thresholds

The defaults are diagnostic heuristics. They are evidence-informed, but they
are not deletion laws.

Per-trait rules:

- `FAIL`: invalid binomial values, zero usable denominator, or all observed
  outcomes on one side.
- strong `WARN`: minority count below 5.
- `WARN`: minority count below 10.
- `INFO`: prevalence outside `[0.02, 0.98]` or `[0.05, 0.95]` when the
  minority count is not sparse.
- `PASS`: no pre-fit prevalence/support warning.

The count-first logic is intentional. A 5% event rate in 20 Bernoulli rows is
not the same evidence as 5% in 100000 rows. The table therefore reports
`n_obs`, `n_units`, `n_success`, `n_failure`, `total_trials`, `prevalence`,
`minority_count`, and `info_fraction = 4 p (1 - p)`.

Pairwise rules:

- `FAIL`: exact duplicate or exact complement on paired binary rows.
- strong `WARN`: discordant paired rows below 5.
- `WARN`: discordant paired rows below 10, normalized Hamming rate at or below
  0.01, absolute phi at or above 0.90/0.95, or Jaccard co-presence at or above
  0.90/0.95.

Design rules:

- `FAIL`: rank-deficient fixed-effect design matrix.
- `WARN`: one-level unit grouping or requested latent rank not smaller than the
  number of candidate traits.

## Literature boundary

The separation boundary follows the classic logistic/probit maximum-likelihood
literature: Albert and Anderson (1984) give the existence conditions for
logistic maximum likelihood estimates. Events-per-variable work by Peduzzi et
al. (1996) and Vittinghoff and McCulloch (2007) supports using minority counts
as evidence, while also warning against treating a single count threshold as a
universal rule. Mansournia, Geroldinger, Greenland, and Heinze (2018) connect
complete/quasi-complete separation to sparse outcomes, rare exposures, strong
effects, and highly correlated predictors; that is the direct statistical
reason for flagging constants, rare indicators, and redundant candidate
responses before a latent block is fitted. The UCLA OARC separation FAQ is a
reader-facing reference for the practical distinction between complete and
quasi-complete separation.

Psychometric item-analysis practice, including tools such as
`mirt::itemstats()` (Chalmers 2012), similarly treats item support, response
frequencies, item-total information, and redundancy as diagnostic evidence to
inspect before interpretation. The SAS IRT overview is a second applied
reference for binary items as observed responses that measure latent traits.
The machine-learning preprocessing precedents `recipes::step_nzv()` and
`recipes::step_corr()` show that near-zero variance and high-correlation
screens are useful, but `screen_gllvmTMB()` deliberately does not inherit their
deletion semantics. It reports candidate-response risks for this formula
because deleting an item solely to improve a diagnostic statistic can harm
criterion validity (Raykov 2008).

`detectseparation` is the closest software precedent for formal binomial
separation detection, but it targets fixed-effect GLMs. `screen_gllvmTMB()` v1
uses cheaper pre-fit support and design summaries only; optional
`detectseparation` comparator rows are left for a Suggests-only follow-up.

Post-fit loading thresholds, such as an entry-wise 0.30 varimax loading
salience rule, belong to identification and interpretation. They should not be
silently converted into a pre-fit deletion rule. The pre-fit screen asks about
data support and formula risk; post-fit loading rules ask how to rotate, pin,
or interpret an already fitted loading matrix.

## Non-binary roadmap

The exported control object reserves the module concept, but v1 only implements
`module = "binomial"`.

Planned modules should stay family-specific:

- Gaussian: zero variance, near-zero variance, high condition number, and
  near-deterministic fixed-effect fits.
- Count: all-zero traits, few positive cells, zero dominance, invalid support,
  and exposure/offset mismatches.
- Ordinal: empty categories, rare categories, and separated cumulative splits.
- Mixed family: per-trait family checks with no universal threshold.

Non-binary responses are less prone to classical complete separation, but they
can still be deterministic, nearly unsupported, collinear, or singular enough
to destabilise a multivariate latent block.

## Validation plan

Implemented tests in `test-screen-gllvmTMB.R` cover:

- constants, near-constants, balanced binary indicators, and invalid support;
- duplicate and complement pairs;
- the planned sample-size/prevalence grid over
  `n = 20, 50, 200, 1000, 100000` and prevalence
  `0, .001, .005, .01, .05, .5, .95, .99, 1`;
- requested pairwise discordant-count boundaries at `0, 1, 5, 10, 50, 500`;
- `cbind(success, failure)` and `weights = n_trials` binomial modes;
- wide `traits(...)` versus long-form parity;
- rank-deficient fixed-effect design and `d >= n_traits`;
- unsupported-family `NOT_CHECKED` output.

Open validation:

- optional comparator checks against `mirt::itemstats()` and
  `detectseparation` if added as Suggests-only;
- performance benchmarks for high-dimensional systematic maps beyond the
  current focused tests.

## References

- Albert A, Anderson JA (1984). On the existence of maximum likelihood
  estimates in logistic regression models. *Biometrika* 71:1--10.
- Peduzzi P, Concato J, Kemper E, Holford TR, Feinstein AR (1996). A simulation
  study of the number of events per variable in logistic regression analysis.
  *Journal of Clinical Epidemiology* 49:1373--1379.
- Vittinghoff E, McCulloch CE (2007). Relaxing the rule of ten events per
  variable in logistic and Cox regression. *American Journal of Epidemiology*
  165:710--718.
- Mansournia MA, Geroldinger A, Greenland S, Heinze G (2018). Separation in
  logistic regression: causes, consequences, and control. *American Journal of
  Epidemiology* 187:864--870.
- UCLA OARC. Complete or quasi-complete separation in logistic/probit
  regression. <https://stats.oarc.ucla.edu/other/mult-pkg/faq/general/faqwhat-is-complete-or-quasi-complete-separation-in-logisticprobit-regression-and-how-do-we-deal-with-them/>
- Chalmers RP (2012). mirt: A multidimensional item response theory package for
  the R environment. *Journal of Statistical Software* 48(6):1--29.
- Chalmers RP. `mirt::itemstats()` documentation: generic item summary
  statistics without prior IRT fitting. <https://rdrr.io/cran/mirt/man/itemstats.html>
- An X, Yung Y-F (2014). Item Response Theory: what it is and how you can use
  the IRT procedure to apply it. SAS Global Forum paper SAS364-2014.
  <https://support.sas.com/resources/papers/proceedings14/SAS364-2014.pdf>
- Kosmidis I, Schumacher D. `detectseparation`: detect and check for separation
  and infinite maximum-likelihood estimates in binomial-response GLMs.
  <https://cran.r-project.org/package=detectseparation>
- Kuhn M, Wickham H. `recipes::step_nzv()` and `recipes::step_corr()`
  documentation. <https://recipes.tidymodels.org/reference/step_nzv.html> and
  <https://recipes.tidymodels.org/reference/step_corr.html>
- Raykov T (2008). Alpha if item deleted: a note on loss of criterion validity
  in scale development if maximizing coefficient alpha. *British Journal of
  Mathematical and Statistical Psychology* 61:275--285.
