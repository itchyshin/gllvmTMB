# Design 51 - Fitted-Model Predictive And Residual Diagnostics

**Status:** public scoped API for issue #228, promoted from the #222
prototype.
**Validation rows:** DIA-11 and DIA-12 in
`docs/design/35-validation-debt-register.md`.
**Primary readers:** Fisher, Florence, Pat, and R package contributors.

## Purpose

`check_gllvmTMB()` tells us whether a fit is numerically healthy. It does
not tell an applied reader whether the fitted model reproduces the
observed response distribution, trait-level count tails, or grouped
patterns. Design 51 defines the model-checking lane: fitted-model
predictive plots and residual diagnostics that return auditable tables
and `ggplot` objects.

This lane is deliberately conservative. The public API uses
`simulate.gllvmTMB_multi()` to generate fitted-model draws. Those draws
are useful for predictive checks, but they are not Bayesian posterior
draws unless a future workflow supplies parameter draws. The exported
function is therefore `predictive_check()`, not `pp_check()`, and the
documentation says "fitted-model predictive" rather than "posterior
predictive".

## Sister-Package Lessons Checked

- `sdmTMB` documents analytical randomized-quantile residuals via
  `residuals(fit, type = "mle-mvn")`, and also shows a
  simulation-based route through `simulate()` plus DHARMa-style
  residuals. Its key transferable lesson is to distinguish analytical
  residuals from simulation-based residuals.
- `bayesplot` provides the `pp_check()` S3 generic and asks package
  authors to return the `ggplot` object created by the predictive-check
  plotting function. It also names the core data shape: observed `y`
  and a matrix of replicated outcomes `yrep`.
- `brms::pp_check()` is a useful interface model for `type`, `ndraws`,
  `group`, `resp`, and a `ggplot` return value. `gllvmTMB` uses `trait`
  as the local analogue of `resp`, because rows are stacked by trait.
- `drmTMB::plot_parameter_surface()` separates prediction-table
  construction from plotting, validates required columns, returns a
  `ggplot`, and keeps rows without supported finite intervals visible as
  point/line estimates. The same discipline belongs here: diagnostics
  preserve row status instead of quietly dropping awkward rows.

Sources checked on 2026-05-20:

- <https://sdmtmb.github.io/sdmTMB/articles/residual-checking.html>
- <https://mc-stan.org/bayesplot/reference/pp_check.html>
- <https://mc-stan.org/bayesplot/reference/PPC-overview.html>
- <https://paulbuerkner.com/brms/reference/pp_check.brmsfit.html>

## Public Surface

The public API is package-specific to avoid a Bayesian posterior-draw
claim:

```r
predictive_check(
  fit,
  type = c("rq_qq", "rootogram", "stat_grouped", "dens_overlay"),
  nsim = 50,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  group = NULL,
  stat = c("mean", "median", "zero_fraction"),
  residual_type = c("randomized_quantile", "simulation_rank"),
  condition_on_RE = TRUE,
  max_count = NULL
)

residuals(
  fit,
  type = c("randomized_quantile", "simulation_rank"),
  scale = c("normal", "uniform"),
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = TRUE
)
```

`nsim` is the local simulation vocabulary. `ndraws` is accepted as a
bayesplot/brms-style alias, but callers must not supply contradictory
values.

## Data Contract

The internal predictive-draw object contains:

- `observed`: the observed response vector after optional trait
  filtering;
- `simulations`: an `n_obs x nsim` matrix returned by `simulate()`;
- `yrep`: the transposed `nsim x n_obs` matrix expected by
  bayesplot-style functions;
- `row_data`: `.row`, `trait`, `trait_id`, `family_id`, `family`, and
  `link_id`;
- `seed`, `nsim`, and `condition_on_RE` metadata.

Every plotting helper attaches:

```r
attr(plot, "gllvmTMB_diagnostic")
```

with the plotted data, diagnostic type, method, seed, draw count, row
status summary, `check_gllvmTMB()` output, and the fitted object's
`fit_health` snapshot. This attribute is part of the public diagnostic
contract: Florence can inspect the figure, while Rose and Fisher can
inspect the underlying rows and fit-health state.

## Randomized-Quantile And Simulation-Rank Residuals

For a fitted observation `i`, exact randomized-quantile residuals use:

```text
continuous: u_i = F_i(y_i)
discrete:   u_i ~ Uniform(F_i(y_i^-), F_i(y_i))
residual:   r_i = Phi^{-1}(u_i)
```

Exact family-CDF residuals are implemented for Gaussian, Poisson, and
NB2 rows. These are the scoped DIA-12 covered families for the first
public release.

The simulation-rank fallback computes:

```text
u_i = (#{yrep_is < y_i} + Uniform(0, #{yrep_is = y_i} + 1)) / (S + 1)
r_i = Phi^{-1}(u_i)
```

where `S` is `nsim`. Rows with non-finite observed values, non-finite
simulated values, invalid count values, missing dispersion, or an
unsupported exact family stay in the returned data with explicit
`status` values. Plots may draw only finite residuals, but the attached
diagnostic data retain all rows.

## In Scope

- Exported `predictive_check()` for fitted-model predictive plots.
- Exported `residuals.gllvmTMB_multi()` with exact Gaussian, Poisson,
  and NB2 randomized-quantile residuals.
- Simulation-rank residuals as a separate fitted-model fallback.
- `trait` filtering.
- `ndraws` / `nsim` alias support with explicit conflict errors.
- `seed` discipline.
- Conditional checks via `condition_on_RE = TRUE` and default simulation
  semantics via `condition_on_RE = FALSE`.
- `ggplot` returns with non-default theme, labels, and source data.
- Row-status preservation for non-finite, invalid, or unsupported rows.
- `check_gllvmTMB()` and `fit$fit_health` metadata on residual and plot
  objects.

## Out Of Scope Until A Later Slice

- Bayesian posterior predictive checks from parameter draws.
- DHARMa object compatibility or claims of DHARMa-equivalent tests.
- Formal uniformity, dispersion, outlier, or autocorrelation tests.
- Exact residual semantics for delta, hurdle, truncated, ordinal, and
  mixture families.
- A Tier-1 diagnostic article. The public reference pages are present;
  the article waits until Florence and Fisher sign off on real examples.

## Figure Gate

Florence's minimum bar for the first public diagnostic plot is:

1. The plot returns a `ggplot` object and does not save to disk.
2. The plot has a clear title, axis labels, colorblind-safe colors, and
   no accidental default grey-panel look.
3. The plotted data or attached metadata records `trait`, `family`,
   diagnostic type, draw count, seed, row status, and fit-health state.
4. Non-finite or unsupported rows are not silently deleted.
5. Count-family figure notes name the family and, for NB2, preserve the
   fitted dispersion context before any diagnostic conclusion is made.

DIA-11 and DIA-12 are covered for the scoped Gaussian, Poisson, and NB2
public surface tested in `test-predictive-diagnostics.R`. They remain
partial for unsupported families, formal residual tests, and any
posterior-predictive claim.
