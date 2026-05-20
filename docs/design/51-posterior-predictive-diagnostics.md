# Posterior-Predictive And Simulation-Rank Diagnostics

**Status:** design/prototype for issue #222; not a public API promise.
**Validation rows:** DIA-11 and DIA-12 in
`docs/design/35-validation-debt-register.md`.
**Primary readers:** Fisher, Florence, Pat, and R package contributors.

## Purpose

`check_gllvmTMB()` tells us whether a fit is numerically healthy. It does
not tell an applied reader whether the fitted model reproduces the
observed response distribution, trait-level count tails, or grouped
patterns. Issue #222 starts a separate model-checking lane: fitted-model
predictive checks and simulation-rank residuals that return auditable
tables and `ggplot` objects.

This lane is deliberately conservative. The dev prototype uses
`simulate.gllvmTMB_multi()` to generate fitted-model draws. Those draws are
useful for posterior-predictive-style checks, but they are not Bayesian
posterior draws unless a future workflow supplies parameter draws. The
prototype therefore says "fitted-model predictive" or "simulation-rank",
not "posterior predictive" or "exact randomized quantile" in capability
claims.

## Sister-Package Lessons Checked

- `sdmTMB` documents analytical randomized-quantile residuals via
  `residuals(fit, type = "mle-mvn")`, and also shows a
  simulation-based route through `simulate()` plus DHARMa-style residuals.
  Its key transferable lesson is to distinguish analytical residuals from
  simulation-based residuals.
- `bayesplot` provides the `pp_check()` S3 generic and asks package
  authors to return the `ggplot` object created by the predictive-check
  plotting function. It also names the core data shape: observed `y`
  and a matrix of replicated outcomes `yrep`.
- `brms::pp_check()` is a useful interface model for `type`, `ndraws`,
  `group`, `resp`, and a `ggplot` return value. `gllvmTMB` should use
  `trait` as the local analogue of `resp`, because rows are stacked by
  trait.
- `drmTMB::plot_parameter_surface()` separates prediction-table
  construction from plotting, validates required columns, returns a
  `ggplot`, and keeps rows without supported finite intervals visible as
  point/line estimates. The same discipline belongs here: diagnostics
  must preserve row status instead of quietly dropping awkward rows.

Sources checked on 2026-05-20:

- <https://sdmtmb.github.io/sdmTMB/articles/residual-checking.html>
- <https://mc-stan.org/bayesplot/reference/pp_check.html>
- <https://mc-stan.org/bayesplot/reference/PPC-overview.html>
- <https://paulbuerkner.com/brms/reference/pp_check.brmsfit.html>

## Prototype Surface

The dev-only file `dev/ppcheck-diagnostics.R` defines three helper
families:

```r
gllvmTMB_ppc_draws_prototype(
  fit,
  ndraws = 50,
  seed = 1,
  trait = NULL,
  condition_on_RE = FALSE
)

gllvmTMB_simulation_rank_residuals_prototype(
  fit,
  ndraws = 50,
  seed = 1,
  trait = NULL,
  condition_on_RE = FALSE,
  scale = "normal"
)

gllvmTMB_pp_check_prototype(
  fit,
  type = c("dens_overlay", "stat_grouped", "rq_qq"),
  ndraws = 50,
  seed = 1,
  trait = NULL,
  group = NULL,
  condition_on_RE = FALSE
)
```

The function names include `prototype` to prevent accidental public API
commitment. A future public API can either define
`pp_check.gllvmTMB_multi()` or keep a package-specific name if the
frequentist fitted-model semantics would make `pp_check()` misleading.

## Data Contract

`gllvmTMB_ppc_draws_prototype()` returns:

- `observed`: the observed response vector after optional trait filtering;
- `simulations`: an `n_obs x ndraws` matrix returned by `simulate()`;
- `yrep`: the transposed `ndraws x n_obs` matrix expected by bayesplot-style
  functions;
- `row_data`: `.row`, `trait`, `family_id`, `family`, and `link_id`;
- `seed`, `ndraws`, and `condition_on_RE` metadata.

Every plotting helper attaches:

```r
attr(plot, "gllvmTMB_diagnostic")
```

with the plotted data, diagnostic type, method, seed, draw count, and row
status summary. This attribute is part of the prototype contract: Florence
can inspect the figure, while Rose and Fisher can inspect the underlying
rows.

## Simulation-Rank Residual Contract

The exact randomized-quantile residual for observation `i` is:

```text
continuous: u_i = F_i(y_i)
discrete:   u_i ~ Uniform(F_i(y_i^-), F_i(y_i))
residual:   r_i = Phi^{-1}(u_i)
```

That exact path needs family-specific fitted CDF plumbing. The prototype
instead computes a simulation-rank analogue from fitted-model draws:

```text
u_i = (#{yrep_is < y_i} + Uniform(0, #{yrep_is = y_i} + 1)) / (S + 1)
r_i = Phi^{-1}(u_i)
```

where `S` is `ndraws`. Rows with non-finite observed values or non-finite
simulated values stay in the returned data with `status` set to
`"nonfinite_observed"`, `"nonfinite_simulation"`, or
`"nonfinite_residual"`. Plots may draw only finite residuals, but the
attached diagnostic data must retain all rows.

## In Scope For This Prototype

- Gaussian, Poisson, and NB2 fitted-model examples.
- `trait` filtering.
- `ndraws` / `nsim` alias support with explicit conflict errors.
- `seed` discipline.
- Conditional checks via `condition_on_RE = TRUE` and default
  simulation semantics via `condition_on_RE = FALSE`.
- `ggplot` returns with non-default theme, labels, and source data.
- Row-status preservation for non-finite observed or simulated values.

## Out Of Scope Until A Later Slice

- Exported `pp_check.gllvmTMB_multi()`.
- Exported `residuals.gllvmTMB_multi(type = "randomized_quantile")`.
- Exact family-CDF randomized-quantile residuals.
- Bayesian posterior predictive checks from parameter draws.
- DHARMa object compatibility or claims of DHARMa-equivalent tests.
- Formal uniformity, dispersion, outlier, or autocorrelation tests.
- Delta/hurdle, truncated, ordinal, and mixture-family residual claims.
- Vignette or reference-page advertisement.

## Figure Gate

Florence's minimum bar for the first public diagnostic plot is:

1. The plot returns a `ggplot` object and does not save to disk.
2. The plot has a clear title, axis labels, colorblind-safe colors, and no
   accidental default grey-panel look.
3. The plotted data or attached metadata records `trait`, `family`,
   diagnostic type, draw count, seed, and row status.
4. Non-finite or unsupported rows are not silently deleted.
5. Count-family figure notes name the family and, for NB2, the fitted
   dispersion context before any diagnostic conclusion is made.

Until this gate passes on real diagnostic examples, DIA-11 and DIA-12 stay
`partial`.
