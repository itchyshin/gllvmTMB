## Fitted-model predictive checks and diagnostic residuals for
## gllvmTMB_multi fits. These helpers deliberately say "fitted-model
## predictive" rather than "posterior predictive": draws currently come
## from simulate.gllvmTMB_multi() at fitted parameters, not from a
## Bayesian parameter posterior.

#' Fitted-model predictive checks for a multivariate `gllvmTMB` fit
#'
#' `predictive_check()` compares the observed stacked-trait response to
#' draws from the fitted model. The frequentist semantics are explicit:
#' these are fitted-model predictive checks, not Bayesian posterior
#' predictive checks.
#'
#' The returned object is a `ggplot`. Its plotted data, fit-health table
#' from [check_gllvmTMB()], and `fit$fit_health` snapshot are also stored
#' in `attr(plot, "gllvmTMB_diagnostic")` so the figure can be audited
#' without reverse-engineering ggplot layers.
#'
#' Scope: fitted-model predictive plots and residual Q-Q/rootogram helpers
#' for `gllvmTMB_multi` fits, with exact randomized-quantile residuals for
#' Gaussian, binomial, Poisson, lognormal, Gamma, NB2, Beta, betabinomial,
#' Student-t, zero-truncated Poisson, zero-truncated NB2, NB1, and
#' ordinal-probit rows, plus a simulation-rank fallback. These are
#' diagnostic displays, not formal uniformity, dispersion,
#' interval-calibration, or Bayesian posterior-predictive tests. Exact
#' residual support for tweedie, the delta/hurdle families, and multinomial
#' is not implemented (see [residuals.gllvmTMB_multi()] for why); the
#' simulation-rank fallback's own family coverage is separately limited and
#' is not audited here.
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param type Diagnostic plot type. `"rq_qq"` plots exact randomized-
#'   quantile residuals when available; `"rootogram"` compares observed
#'   count frequencies with fitted-model simulated count frequencies;
#'   `"stat_grouped"` compares grouped summary statistics; `"dens_overlay"`
#'   overlays observed and simulated densities and is mainly useful for
#'   continuous responses.
#' @param nsim,ndraws Number of fitted-model draws. `ndraws` is accepted as
#'   a bayesplot/brms-style alias; supply only one.
#' @param seed Optional RNG seed.
#' @param trait Optional character vector of trait names to keep.
#' @param group Row-metadata column used by `"stat_grouped"`. Default is
#'   `"trait"`.
#' @param stat Grouped statistic for `"stat_grouped"`.
#' @param residual_type Residual type used by `"rq_qq"`. Defaults to exact
#'   `"randomized_quantile"` residuals; `"simulation_rank"` is available as
#'   a simulation-based fallback.
#' @param condition_on_RE Logical. Passed to [simulate.gllvmTMB_multi()] for
#'   simulation-based checks. The default `TRUE` checks the fitted response
#'   distribution conditional on fitted random-effect modes.
#' @param max_count Optional upper count shown separately in `"rootogram"`.
#'   Counts larger than this value are pooled into a final `">max_count"`
#'   bin. Default `NULL` chooses a bounded automatic display range and pools
#'   larger counts so that a single extreme simulated draw cannot create a
#'   very wide rootogram.
#' @return A `ggplot` object with diagnostic metadata attached in
#'   `attr(plot, "gllvmTMB_diagnostic")`.
#' @export
#' @examples
#' \donttest{
#' set.seed(1)
#' n <- 24
#' df <- data.frame(
#'   unit = factor(rep(seq_len(n), each = 2)),
#'   trait = factor(rep(c("a", "b"), n)),
#'   value = rpois(2 * n, lambda = 2)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | unit, d = 1),
#'   data = df,
#'   trait = "trait",
#'   unit = "unit",
#'   family = poisson()
#' )
#' predictive_check(fit, type = "rq_qq", seed = 1)
#' predictive_check(fit, type = "rootogram", ndraws = 20, seed = 1)
#' }
predictive_check <- function(
  object,
  type = c("rq_qq", "rootogram", "stat_grouped", "dens_overlay"),
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  group = NULL,
  stat = c("mean", "median", "zero_fraction"),
  residual_type = c("randomized_quantile", "simulation_rank"),
  condition_on_RE = TRUE,
  max_count = NULL
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Install ggplot2 to use {.fn predictive_check}.")
  }
  .gllvmTMB_validate_diagnostic_fit(object)
  type <- match.arg(type)
  stat <- match.arg(stat)
  residual_type <- match.arg(residual_type)
  nsim <- .gllvmTMB_resolve_nsim(nsim, ndraws)

  if (identical(type, "rq_qq")) {
    res <- residuals(
      object,
      type = residual_type,
      nsim = nsim,
      seed = seed,
      trait = trait,
      condition_on_RE = condition_on_RE,
      scale = "normal"
    )
    plot <- .gllvmTMB_plot_rq_qq(res)
    return(.gllvmTMB_attach_diagnostic_metadata(
      plot,
      data = res,
      type = type,
      method = attr(res, "method") %||% residual_type,
      seed = seed,
      nsim = if (identical(residual_type, "simulation_rank")) {
        nsim
      } else {
        NA_integer_
      },
      condition_on_RE = condition_on_RE,
      object = object
    ))
  }

  draws <- .gllvmTMB_predictive_draws(
    object,
    nsim = nsim,
    seed = seed,
    trait = trait,
    condition_on_RE = condition_on_RE
  )

  plot <- switch(
    type,
    dens_overlay = .gllvmTMB_plot_density(draws),
    stat_grouped = .gllvmTMB_plot_stat_grouped(
      draws,
      group = group,
      stat = stat
    ),
    rootogram = .gllvmTMB_plot_rootogram(draws, max_count = max_count)
  )
  .gllvmTMB_attach_diagnostic_metadata(
    plot,
    data = plot$data,
    type = type,
    method = "simulation_from_fitted_model",
    seed = seed,
    nsim = nsim,
    condition_on_RE = condition_on_RE,
    object = object
  )
}

#' Diagnostic residuals for a multivariate `gllvmTMB` fit
#'
#' Returns row-wise residual diagnostics for a fitted `gllvmTMB_multi`
#' model. `type = "randomized_quantile"` uses exact family CDFs for
#' Gaussian, binomial, Poisson, lognormal, Gamma, NB2, Beta, betabinomial,
#' Student-t, zero-truncated Poisson, zero-truncated NB2, NB1, and
#' ordinal-probit rows. `type = "simulation_rank"` uses fitted-model
#' simulations and is available as a fallback for checking the same row
#' contract when exact family-CDF plumbing is not implemented for a family;
#' its own family coverage (what [simulate.gllvmTMB_multi()] can draw from)
#' is tracked separately and is not extended here.
#'
#' Rows are retained even when a residual cannot be computed. Inspect the
#' `status` column before treating residuals as complete.
#'
#' Scope: exact family-CDF randomized-quantile residuals for Gaussian,
#' binomial, Poisson, lognormal, Gamma, NB2, Beta, betabinomial, Student-t,
#' zero-truncated Poisson, zero-truncated NB2, NB1, and ordinal-probit rows,
#' plus simulation-rank residuals from fitted-model draws. Tweedie, the
#' delta/hurdle families (`delta_lognormal`, `delta_gamma`), and
#' multinomial are deliberately not implemented: tweedie has no closed-form
#' CDF without a new dependency, the delta/hurdle families mix a point mass
#' at zero with a continuous part and need an explicit design decision for
#' splitting the point mass, and multinomial's categories are unordered so a
#' randomized-quantile residual is undefined without inventing an ordering.
#' Unsupported families are retained with row status rather than promoted
#' to exact residual claims. Formal residual tests (beyond the recovery
#' checks in `tests/testthat/test-exact-rq-residuals-families.R`) remain
#' later validation work.
#'
#' The returned data frame also carries `attr(x, "gllvmTMB_diagnostic")`
#' with [check_gllvmTMB()] output and the fitted object's `fit_health`
#' snapshot.
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param type `"randomized_quantile"` for exact family-CDF randomized
#'   quantile residuals where implemented, or `"simulation_rank"` for
#'   simulation-rank residuals from fitted-model draws.
#' @param scale `"normal"` returns normal-quantile residuals; `"uniform"`
#'   returns the randomized PIT value.
#' @param nsim,ndraws Number of fitted-model draws for
#'   `type = "simulation_rank"`. Ignored by exact randomized-quantile
#'   residuals.
#' @param seed Optional RNG seed.
#' @param trait Optional character vector of trait names to keep.
#' @param condition_on_RE Logical. Passed to [simulate.gllvmTMB_multi()] for
#'   simulation-rank residuals.
#' @param ... Currently unused.
#' @return A data frame with row metadata (`.row`, `trait`, `family_id`,
#'   `family`, `link_id`), `observed`, randomized PIT value `u`,
#'   `residual`, `status`, `scale`, and method metadata. The attribute
#'   `method` records the residual engine.
#' @method residuals gllvmTMB_multi
#' @export
#' @examples
#' \donttest{
#' set.seed(2)
#' n <- 24
#' df <- data.frame(
#'   unit = factor(rep(seq_len(n), each = 2)),
#'   trait = factor(rep(c("a", "b"), n)),
#'   value = rpois(2 * n, lambda = 2)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | unit, d = 1),
#'   data = df,
#'   trait = "trait",
#'   unit = "unit",
#'   family = poisson()
#' )
#' residuals(fit, type = "randomized_quantile", seed = 1)
#' }
residuals.gllvmTMB_multi <- function(
  object,
  type = c("randomized_quantile", "simulation_rank"),
  scale = c("normal", "uniform"),
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = TRUE,
  ...
) {
  .gllvmTMB_validate_diagnostic_fit(object)
  type <- match.arg(type)
  scale <- match.arg(scale)
  if (identical(type, "randomized_quantile")) {
    out <- .gllvmTMB_exact_rq_residuals(
      object,
      seed = seed,
      trait = trait,
      scale = scale
    )
    return(.gllvmTMB_attach_residual_metadata(
      out,
      object = object,
      residual_type = type,
      method = "exact_family_cdf",
      seed = seed,
      nsim = NA_integer_,
      condition_on_RE = NA,
      scale = scale
    ))
  }

  out <- .gllvmTMB_simulation_rank_residuals(
    object,
    nsim = nsim,
    ndraws = ndraws,
    seed = seed,
    trait = trait,
    condition_on_RE = condition_on_RE,
    scale = scale
  )
  .gllvmTMB_attach_residual_metadata(
    out,
    object = object,
    residual_type = type,
    method = "simulation_rank_residuals",
    seed = seed,
    nsim = out$nsim[1L] %||% NA_integer_,
    condition_on_RE = condition_on_RE,
    scale = scale
  )
}

.gllvmTMB_predictive_draws <- function(
  object,
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = TRUE
) {
  .gllvmTMB_validate_diagnostic_fit(object)
  nsim <- .gllvmTMB_resolve_nsim(nsim, ndraws)

  observed <- as.numeric(object$tmb_data$y)
  simulations <- stats::simulate(
    object,
    nsim = nsim,
    seed = seed,
    condition_on_RE = condition_on_RE
  )
  simulations <- as.matrix(simulations)
  if (
    nrow(simulations) != length(observed) &&
      ncol(simulations) == length(observed)
  ) {
    simulations <- t(simulations)
  }
  if (nrow(simulations) != length(observed)) {
    cli::cli_abort(
      "{.fn simulate} returned a matrix that does not align with the observed response."
    )
  }

  row_meta <- .gllvmTMB_diagnostic_row_metadata(object)
  keep <- .gllvmTMB_trait_keep(row_meta, trait)

  out <- list(
    observed = observed[keep],
    simulations = simulations[keep, , drop = FALSE],
    yrep = t(simulations[keep, , drop = FALSE]),
    row_data = row_meta[keep, , drop = FALSE],
    nsim = nsim,
    seed = seed,
    condition_on_RE = isTRUE(condition_on_RE),
    method = "simulation_from_fitted_model"
  )
  class(out) <- "gllvmTMB_predictive_draws"
  out
}

.gllvmTMB_exact_rq_residuals <- function(
  object,
  seed = NULL,
  trait = NULL,
  scale = c("normal", "uniform")
) {
  scale <- match.arg(scale)
  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      .old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
      on.exit(assign(".Random.seed", .old_seed, envir = globalenv()), add = TRUE)
    } else {
      on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
    }
    set.seed(seed)
  }

  observed <- as.numeric(object$tmb_data$y)
  eta <- as.numeric(object$report$eta)
  row_meta <- .gllvmTMB_diagnostic_row_metadata(object)
  keep <- .gllvmTMB_trait_keep(row_meta, trait)

  ## Phase 1 response mask (design 59 sec.4b): a masked row carries the
  ## sentinel y = 0, which is finite and would otherwise yield a meaningless
  ## residual. Skip it -> the residual is NA at every missing-response cell.
  observed_mask <- .gllvmTMB_is_y_observed(object)

  observed <- observed[keep]
  eta <- eta[keep]
  observed_mask <- observed_mask[keep]
  row_meta <- row_meta[keep, , drop = FALSE]
  n_trials <- as.numeric(object$tmb_data$n_trials)[keep]
  n <- length(observed)

  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  u <- rep(NA_real_, n)
  residual <- rep(NA_real_, n)
  status <- rep("ok", n)

  sigma_eps_gaussian <- .gllvmTMB_sigma_eps_for_family(object, 0L)
  sigma_eps_lognormal <- .gllvmTMB_sigma_eps_for_family(object, 3L)
  phi_nbinom2 <- object$report$phi_nbinom2
  phi_nbinom1 <- object$report$phi_nbinom1
  phi_gamma <- object$report$phi_gamma
  phi_beta <- object$report$phi_beta
  phi_betabinom <- object$report$phi_betabinom
  sigma_student <- object$report$sigma_student
  df_student <- object$report$df_student
  phi_truncnb2 <- object$report$phi_truncnb2
  zi <- object$report$zi # length n_traits (fid 17/18/19)

  ## ordinal_probit (fid 14): the report carries only the K-2 free cutpoints
  ## tau_2 .. tau_{K-1} per trait, flattened and split by
  ## n_ordinal_cuts_per_trait / ordinal_offset_per_trait -- the SAME fields
  ## extract_cutpoints() reads. tau_1 = 0 is fixed (Hadfield 2015) and
  ## prepended here so each list element is the full tau_1 .. tau_{K-1}
  ## vector used below.
  n_ordinal_cuts_per_trait <- as.integer(
    object$tmb_data$n_ordinal_cuts_per_trait %||% integer(0)
  )
  ordinal_offset_per_trait <- as.integer(
    object$tmb_data$ordinal_offset_per_trait %||% integer(0)
  )
  ordinal_cutpoints_flat <- as.numeric(object$report$ordinal_cutpoints %||% numeric(0))
  ordinal_full_cuts <- if (length(n_ordinal_cuts_per_trait) > 0L) {
    lapply(seq_along(n_ordinal_cuts_per_trait), function(t) {
      k_minus_2 <- n_ordinal_cuts_per_trait[t]
      if (is.na(k_minus_2) || k_minus_2 < 0L) {
        return(NULL)
      }
      base <- ordinal_offset_per_trait[t]
      extra <- if (k_minus_2 > 0L) {
        ordinal_cutpoints_flat[(base + 1L):(base + k_minus_2)]
      } else {
        numeric(0)
      }
      c(0, extra)
    })
  } else {
    list()
  }

  ## A diagonal random effect indexed at the same resolution as the observed
  ## trait-cell can absorb the observation residual, driving the family's
  ## dispersion/scale parameter toward a degenerate confound (sigma_eps -> 0
  ## for gaussian/lognormal, shape -> Inf for Gamma, precision -> Inf for
  ## Beta, sigma -> 0 for student). Conditional exact-CDF residuals then
  ## collapse near zero and are not a goodness-of-fit check. Warn and direct
  ## users to the marginal simulation-rank route rather than displaying an
  ## automatically perfect Q-Q plot.
  trait_col <- object$trait_col
  per_row_diag <- function(flag, group_col) {
    isTRUE(flag) && !is.null(group_col) && group_col %in% names(object$data) &&
      nrow(unique(object$data[c(trait_col, group_col)])) == nrow(object$data)
  }
  ## Families included: gaussian (0), lognormal (3), Gamma (4), Beta (7),
  ## student (9) -- exactly the families whose residual CDF is computed
  ## EXACT (lower == upper) rather than randomized-quantile above, i.e. those
  ## with a genuinely continuous density that can diverge to +Inf as its
  ## scale/dispersion parameter degenerates (a Gaussian/lognormal/Gamma/
  ## Beta/student density -> Inf as sigma -> 0 / shape,precision -> Inf; a
  ## discrete pmf is bounded by 1 and cannot do this, which is why Poisson,
  ## binomial, NB1/NB2, tweedie, and beta-binomial are excluded here).
  ## gaussian (0) and lognormal (3) additionally get an auto-suppressed
  ## sigma_eps at fit time (`any_sigma_eps` at R/fit-multi.R:5177); Gamma/
  ## Beta/student have no analogous fit-time fix, only this residuals-time
  ## warning -- see #1083. Confirmed empirically (15-seed sweep, n_ind = 36):
  ## Gamma's phi_gamma ran away to > 1e6 (true 6) in 9/15 seeds, student's
  ## sigma_student collapsed below 0.1 (true 0.4) in 6/15 seeds, and Beta's
  ## phi_beta ran away to > 1e8 (true 20) in 2/15 seeds -- all under the
  ## identical per-row-diagonal structure. A matched Poisson sweep (8 seeds)
  ## showed no such collapse (sd(residual) ~ 1 throughout), consistent with
  ## Poisson having no continuous dispersion to degenerate.
  saturating_family <- any(row_meta$family_id %in% c(0L, 3L, 4L, 7L, 9L)) &&
    (
      per_row_diag(object$use$diag_B, object$unit_col) ||
        per_row_diag(object$use$diag_W, object$unit_obs_col)
    )
  if (saturating_family) {
    cli::cli_warn(
      c(
        "Exact conditional residuals are not informative when a diagonal random effect is indexed at the observed trait-cell resolution.",
        "i" = "Use {.code type = \"simulation_rank\"} with {.code condition_on_RE = FALSE} to inspect marginal fitted-model draws."
      ),
      class = "gllvmTMB_conditional_residual_saturated"
    )
  }

  ## Cache of 0:N support vectors for the beta-binomial CDF (fid 8), keyed
  ## by trial count N. N is typically constant within a trait, so this
  ## avoids rebuilding 0:N on every row; only the row-specific a/b terms
  ## are recomputed per row.
  bb_k_cache <- list()

  for (i in seq_len(n)) {
    y_i <- observed[i]
    fid <- row_meta$family_id[i]
    tid <- row_meta$trait_id[i]

    if (observed_mask[i] == 0L) {
      status[i] <- "missing_response"
      next
    }

    if (!is.finite(y_i)) {
      status[i] <- "nonfinite_observed"
      next
    }

    if (fid == 0L) {
      lower[i] <- stats::pnorm(
        y_i, mean = eta[i], sd = sigma_eps_gaussian
      )
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 1L) {
      Nt <- n_trials[i]
      if (!is.finite(Nt) || Nt <= 0 || Nt != floor(Nt)) {
        status[i] <- "missing_trials"
        next
      }
      if (y_i < 0 || y_i > Nt || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      ## Bernoulli / binomial(k-of-n), dispatched on link_id_vec exactly as
      ## src/gllvmTMB.cpp fid == 1 does: 0 = logit, 1 = probit, 2 = cloglog.
      ## An NA or unrecognised link_id gets its own explicit status rather
      ## than silently falling back to logit -- a wrong link on a real fit
      ## would otherwise return a plausible-looking but wrong residual.
      lid_i <- row_meta$link_id[i]
      if (is.na(lid_i) || !(lid_i %in% c(0L, 1L, 2L))) {
        status[i] <- "unknown_link"
        next
      }
      p_i <- .gllvmTMB_binom_prob(eta[i], lid_i)
      p_i <- .gllvmTMB_clip_unit_interval(p_i)
      lower[i] <- if (y_i <= 0) 0 else stats::pbinom(y_i - 1, size = Nt, prob = p_i)
      upper[i] <- stats::pbinom(y_i, size = Nt, prob = p_i)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 2L) {
      if (y_i < 0 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      lambda <- exp(eta[i])
      lower[i] <- if (y_i <= 0) 0 else stats::ppois(y_i - 1, lambda = lambda)
      upper[i] <- stats::ppois(y_i, lambda = lambda)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 3L) {
      ## Lognormal, log(y) ~ Normal(eta, sigma_eps). eta is the mean of
      ## log(y) directly (src/gllvmTMB.cpp fid == 3). Joint Gaussian-
      ## lognormal fits use a distinct log-scale slot, shared within family.
      if (y_i <= 0) {
        status[i] <- "invalid_observed"
        next
      }
      lower[i] <- stats::plnorm(
        y_i, meanlog = eta[i], sdlog = sigma_eps_lognormal
      )
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 4L) {
      ## Gamma, mean-shape parametrisation (src/gllvmTMB.cpp fid == 4):
      ## mu = exp(eta), scale = mu / shape. `scale_g` is deliberately named
      ## away from the outer `scale` argument (normal vs uniform residual
      ## output), which it must not clobber.
      if (y_i <= 0) {
        status[i] <- "invalid_observed"
        next
      }
      shape_g <- phi_gamma[tid]
      if (!is.finite(shape_g) || shape_g <= 0) {
        status[i] <- "missing_phi"
        next
      }
      mu_g <- exp(eta[i])
      scale_g <- mu_g / shape_g
      lower[i] <- stats::pgamma(y_i, shape = shape_g, scale = scale_g)
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 5L) {
      if (y_i < 0 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      size <- phi_nbinom2[tid]
      if (!is.finite(size) || size <= 0) {
        status[i] <- "missing_phi"
        next
      }
      mu <- exp(eta[i])
      lower[i] <- if (y_i <= 0) {
        0
      } else {
        stats::pnbinom(y_i - 1, size = size, mu = mu)
      }
      upper[i] <- stats::pnbinom(y_i, size = size, mu = mu)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 7L) {
      ## Beta, mean-precision parametrisation (src/gllvmTMB.cpp fid == 7):
      ## mu = invlogit(eta), shape1 = mu*phi, shape2 = (1 - mu)*phi. The
      ## engine's Beta log-density hardcodes invlogit with no link_id
      ## dispatch, and R/fit-multi.R aborts at fit time on any link other
      ## than logit for this family -- so plogis(eta) always matches what
      ## was actually fit, regardless of what a link_id row carries.
      if (y_i <= 0 || y_i >= 1) {
        status[i] <- "invalid_observed"
        next
      }
      phi_b <- phi_beta[tid]
      if (!is.finite(phi_b) || phi_b <= 0) {
        status[i] <- "missing_phi"
        next
      }
      mu_b <- stats::plogis(eta[i])
      shape1_b <- mu_b * phi_b
      shape2_b <- (1 - mu_b) * phi_b
      lower[i] <- stats::pbeta(y_i, shape1 = shape1_b, shape2 = shape2_b)
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 8L) {
      ## Beta-binomial (src/gllvmTMB.cpp fid == 8; Hilbe 2014, Bolker 2008):
      ## mu = invlogit(eta) (same hardcoded-logit note as fid == 7; also
      ## enforced at fit time -- R/fit-multi.R aborts on any other link),
      ## a = mu*phi, b = (1 - mu)*phi. No base-R CDF exists, so the pmf is
      ## hand-rolled from the SAME lgamma terms as the engine's log-density
      ## and cumulatively summed.
      Nt <- n_trials[i]
      if (!is.finite(Nt) || Nt <= 0 || Nt != floor(Nt)) {
        status[i] <- "missing_trials"
        next
      }
      if (y_i < 0 || y_i > Nt || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      phi_bb <- phi_betabinom[tid]
      if (!is.finite(phi_bb) || phi_bb <= 0) {
        status[i] <- "missing_phi"
        next
      }
      mu_bb <- stats::plogis(eta[i])
      a_bb <- mu_bb * phi_bb
      b_bb <- (1 - mu_bb) * phi_bb
      Nt_key <- as.character(Nt)
      k_bb <- bb_k_cache[[Nt_key]]
      if (is.null(k_bb)) {
        k_bb <- 0:Nt
        bb_k_cache[[Nt_key]] <- k_bb
      }
      cdf_bb <- .gllvmTMB_betabinom_cdf(Nt, a_bb, b_bb, k = k_bb)
      lower[i] <- if (y_i <= 0) 0 else cdf_bb[y_i]
      upper[i] <- cdf_bb[y_i + 1L]
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 9L) {
      ## Student-t, identity link (src/gllvmTMB.cpp fid == 9): eta IS the
      ## location mu directly, regardless of the family's declared link
      ## (the engine never applies log/inverse to eta here).
      sigma_t <- sigma_student[tid]
      df_t <- df_student[tid]
      if (
        !is.finite(sigma_t) || sigma_t <= 0 ||
          !is.finite(df_t) || df_t <= 1
      ) {
        status[i] <- "missing_phi"
        next
      }
      z_t <- (y_i - eta[i]) / sigma_t
      lower[i] <- stats::pt(z_t, df = df_t)
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 10L) {
      ## Zero-truncated Poisson (src/gllvmTMB.cpp fid == 10): support starts
      ## at y = 1; renormalise the ordinary Poisson CDF by (1 - P(Y = 0)).
      if (y_i < 1 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      lambda_t <- exp(eta[i])
      p0_t <- exp(-lambda_t)
      denom_t <- 1 - p0_t
      if (!is.finite(denom_t) || denom_t <= 0) {
        status[i] <- "nonfinite_residual"
        next
      }
      lower[i] <- if (y_i <= 1) {
        0
      } else {
        (stats::ppois(y_i - 1, lambda = lambda_t) - p0_t) / denom_t
      }
      upper[i] <- (stats::ppois(y_i, lambda = lambda_t) - p0_t) / denom_t
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 11L) {
      ## Zero-truncated NB2 (src/gllvmTMB.cpp fid == 11): support starts at
      ## y = 1, renormalised the same way as truncated Poisson above. NOTE:
      ## the truncated-NB2 dispersion is a SEPARATE per-trait parameter
      ## (phi_truncnb2), not phi_nbinom2 -- the engine fits it as its own
      ## log_phi_truncnb2 PARAMETER_VECTOR (src/gllvmTMB.cpp fid == 11).
      if (y_i < 1 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      size_t <- phi_truncnb2[tid]
      if (!is.finite(size_t) || size_t <= 0) {
        status[i] <- "missing_phi"
        next
      }
      mu_t <- exp(eta[i])
      p0_t <- stats::pnbinom(0, size = size_t, mu = mu_t)
      denom_t <- 1 - p0_t
      if (!is.finite(denom_t) || denom_t <= 0) {
        status[i] <- "nonfinite_residual"
        next
      }
      lower[i] <- if (y_i <= 1) {
        0
      } else {
        (stats::pnbinom(y_i - 1, size = size_t, mu = mu_t) - p0_t) / denom_t
      }
      upper[i] <- (stats::pnbinom(y_i, size = size_t, mu = mu_t) - p0_t) / denom_t
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 14L) {
      ## ordinal_probit (Wright/Falconer/Hadfield threshold model; Hadfield
      ## 2015 eqn 9): tau_1 = 0 fixed, tau_2 .. tau_{K-1} estimated per
      ## trait (K - 2 free cutpoints); tau_0 = -Inf, tau_K = +Inf.
      ## F(k) = Phi(tau_k - eta) for k = 1..K-1, F(0) = 0, F(K) = 1.
      cuts_t <- if (tid >= 1L && tid <= length(ordinal_full_cuts)) {
        ordinal_full_cuts[[tid]]
      } else {
        NULL
      }
      if (is.null(cuts_t)) {
        status[i] <- "missing_cutpoints"
        next
      }
      K_t <- length(cuts_t) + 1L
      if (y_i < 1 || y_i > K_t || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      yk <- as.integer(y_i)
      lower[i] <- if (yk <= 1L) 0 else stats::pnorm(cuts_t[yk - 1L] - eta[i])
      upper[i] <- if (yk >= K_t) 1 else stats::pnorm(cuts_t[yk] - eta[i])
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid == 15L) {
      if (y_i < 0 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      phi <- phi_nbinom1[tid]
      if (!is.finite(phi) || phi <= 0) {
        status[i] <- "missing_phi"
        next
      }
      ## NB1 linear mean-variance Var = mu*(1 + phi): the NB size argument
      ## is mu / phi (NOT phi as for NB2), so Var = mu + mu^2/(mu/phi) =
      ## mu*(1 + phi).
      mu <- exp(eta[i])
      size <- mu / phi
      lower[i] <- if (y_i <= 0) {
        0
      } else {
        stats::pnbinom(y_i - 1, size = size, mu = mu)
      }
      upper[i] <- stats::pnbinom(y_i, size = size, mu = mu)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else if (fid %in% c(17L, 18L, 19L)) {
      ## Zero-inflated families (Arc D / Design 62): TRUE mixture, so the
      ## mixture CDF has the closed form F_mix(y) = zi + (1-zi)*F_count(y)
      ## for y >= 0 (derived in dev/gapclose/arcD/alignment-zi.md) -- the
      ## same shape for all three count kernels, so one branch covers them.
      if (y_i < 0 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      zi_t <- zi[tid]
      if (!is.finite(zi_t) || zi_t < 0 || zi_t > 1) {
        status[i] <- "missing_phi"
        next
      }
      Fc <- if (fid == 17L) {
        mu <- exp(eta[i])
        function(k) stats::ppois(k, lambda = mu)
      } else if (fid == 18L) {
        phi <- phi_nbinom2[tid]
        if (!is.finite(phi) || phi <= 0) {
          status[i] <- "missing_phi"
          next
        }
        mu <- exp(eta[i])
        function(k) stats::pnbinom(k, size = phi, mu = mu)
      } else {
        Nt <- n_trials[i]
        if (!is.finite(Nt) || Nt <= 0 || Nt != floor(Nt)) {
          status[i] <- "missing_trials"
          next
        }
        if (y_i > Nt) {
          status[i] <- "invalid_observed"
          next
        }
        p_i <- stats::plogis(eta[i])
        function(k) stats::pbinom(k, size = Nt, prob = p_i)
      }
      lower[i] <- if (y_i <= 0) 0 else zi_t + (1 - zi_t) * Fc(y_i - 1)
      upper[i] <- zi_t + (1 - zi_t) * Fc(y_i)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
    } else {
      ## Deliberately NOT implemented (fall through to "unsupported_family"):
      ##   * tweedie (fid 6): the compound Poisson-Gamma cdf has no closed
      ##     form without a new package dependency (e.g. `tweedie::ptweedie`,
      ##     which numerically inverts the characteristic function). Adding
      ##     that dependency is out of scope for this slice.
      ##   * delta_lognormal / delta_gamma (fid 12, 13): a two-part hurdle
      ##     mixture with a point mass at y = 0 plus a continuous positive
      ##     part. A randomized-quantile residual needs an explicit design
      ##     decision for how the point mass is split into the [0, p0]
      ##     interval (as glmmTMB/DHARMa do for hurdle models) -- that
      ##     decision has not been made for this package and should not be
      ##     invented silently here.
      ##   * multinomial (fid 16): unordered categories. A randomized-
      ##     quantile residual presumes an ordering of the support (as
      ##     ordinal_probit has); an unordered baseline-category-logit
      ##     response has none, so "the" residual is undefined without
      ##     inventing an arbitrary category order.
      status[i] <- "unsupported_family"
      next
    }

    if (!is.finite(u[i])) {
      status[i] <- "nonfinite_residual"
      next
    }
    u_i <- .gllvmTMB_clip_unit_interval(u[i])
    u[i] <- u_i
    residual[i] <- if (identical(scale, "normal")) {
      stats::qnorm(u_i)
    } else {
      u_i
    }
  }

  out <- cbind(
    row_meta,
    data.frame(
      observed = observed,
      cdf_lower = lower,
      cdf_upper = upper,
      u = u,
      residual = residual,
      status = status,
      scale = scale,
      method = "exact_family_cdf",
      seed = if (is.null(seed)) NA_integer_ else seed,
      stringsAsFactors = FALSE
    )
  )
  rownames(out) <- NULL
  out
}

.gllvmTMB_simulation_rank_residuals <- function(
  object,
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = TRUE,
  scale = c("normal", "uniform")
) {
  scale <- match.arg(scale)
  draws <- .gllvmTMB_predictive_draws(
    object,
    nsim = nsim,
    ndraws = ndraws,
    seed = seed,
    trait = trait,
    condition_on_RE = condition_on_RE
  )
  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      .old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
      on.exit(assign(".Random.seed", .old_seed, envir = globalenv()), add = TRUE)
    } else {
      on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
    }
    set.seed(seed + 1L)
  }

  observed <- draws$observed
  simulations <- draws$simulations
  n <- length(observed)
  nsim <- ncol(simulations)

  ## Phase 1 response mask (design 59 sec.4b): masked cells carry the sentinel
  ## y = 0 and must yield a NA residual, not a meaningless rank. The .row
  ## column of draws$row_data maps each kept row back to its model-row index.
  full_mask <- .gllvmTMB_is_y_observed(object)
  row_index <- draws$row_data$.row
  observed_mask <- if (
    !is.null(row_index) && all(row_index >= 1L) &&
      all(row_index <= length(full_mask))
  ) {
    full_mask[row_index]
  } else {
    rep(1L, n)
  }
  missing_response <- observed_mask == 0L

  nonfinite_observed <- !is.finite(observed)
  nonfinite_simulation <- !is.finite(rowSums(simulations))
  ok <- !(nonfinite_observed | nonfinite_simulation | missing_response)

  u <- rep(NA_real_, n)
  residual <- rep(NA_real_, n)
  if (any(ok)) {
    less <- rowSums(simulations[ok, , drop = FALSE] < observed[ok])
    ties <- rowSums(simulations[ok, , drop = FALSE] == observed[ok])
    u_ok <- (less + stats::runif(sum(ok), min = 0, max = ties + 1)) /
      (nsim + 1)
    u_ok <- .gllvmTMB_clip_unit_interval(u_ok)
    u[ok] <- u_ok
    residual[ok] <- if (identical(scale, "normal")) {
      stats::qnorm(u_ok)
    } else {
      u_ok
    }
  }

  status <- rep("ok", n)
  status[missing_response] <- "missing_response"
  status[!missing_response & nonfinite_observed] <- "nonfinite_observed"
  status[!missing_response & !nonfinite_observed & nonfinite_simulation] <-
    "nonfinite_simulation"
  status[!is.finite(residual) & status == "ok"] <- "nonfinite_residual"

  out <- cbind(
    draws$row_data,
    data.frame(
      observed = observed,
      cdf_lower = NA_real_,
      cdf_upper = NA_real_,
      u = u,
      residual = residual,
      status = status,
      scale = scale,
      method = "simulation_rank_residuals",
      nsim = nsim,
      seed = if (is.null(seed)) NA_integer_ else seed,
      condition_on_RE = isTRUE(condition_on_RE),
      stringsAsFactors = FALSE
    )
  )
  rownames(out) <- NULL
  out
}

## Per-model-row observed-response indicator (1 = observed, 0 = masked),
## length length(y). NULL on the fit (response="drop" / pre-mask fits) means
## every row is observed -> all-ones (design 59 sec.4b).
.gllvmTMB_is_y_observed <- function(object) {
  iyo <- object$tmb_data$is_y_observed
  n <- length(object$tmb_data$y)
  if (is.null(iyo)) {
    rep(1L, n)
  } else {
    as.integer(iyo)
  }
}

.gllvmTMB_diagnostic_row_metadata <- function(object) {
  n <- length(object$tmb_data$y)
  dat <- object$data
  trait_col <- object$trait_col
  trait <- if (
    !is.null(trait_col) && trait_col %in% names(dat) && nrow(dat) == n
  ) {
    as.character(dat[[trait_col]])
  } else {
    paste0("trait_", object$tmb_data$trait_id + 1L)
  }

  family_id <- object$tmb_data$family_id_vec
  link_id <- object$tmb_data$link_id_vec
  trait_id <- object$tmb_data$trait_id + 1L
  if (length(family_id) != n) {
    family_id <- rep(NA_integer_, n)
  }
  if (length(link_id) != n) {
    link_id <- rep(NA_integer_, n)
  }
  if (length(trait_id) != n) {
    trait_id <- rep(NA_integer_, n)
  }

  data.frame(
    .row = seq_len(n),
    trait = trait,
    trait_id = trait_id,
    family_id = family_id,
    family = .gllvmTMB_family_label_from_id(family_id),
    link_id = link_id,
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_plot_density <- function(draws) {
  observed_df <- cbind(
    draws$row_data,
    data.frame(
      draw = 0L,
      value = draws$observed,
      source = "observed",
      stringsAsFactors = FALSE
    )
  )
  sim_index <- rep(
    seq_len(ncol(draws$simulations)),
    each = nrow(draws$simulations)
  )
  row_index <- rep(
    seq_len(nrow(draws$simulations)),
    times = ncol(draws$simulations)
  )
  simulated_df <- cbind(
    draws$row_data[row_index, , drop = FALSE],
    data.frame(
      draw = sim_index,
      value = as.vector(draws$simulations),
      source = "simulated",
      stringsAsFactors = FALSE
    )
  )
  plot_data <- rbind(observed_df, simulated_df)
  plot_data$source <- factor(
    plot_data$source,
    levels = c("simulated", "observed")
  )

  ggplot2::ggplot(plot_data, ggplot2::aes(x = value)) +
    ggplot2::stat_density(
      data = plot_data[plot_data$source == "simulated", , drop = FALSE],
      ggplot2::aes(colour = "simulated"),
      geom = "line",
      linewidth = 0.45,
      na.rm = TRUE,
      adjust = 1.1
    ) +
    ggplot2::stat_density(
      data = plot_data[plot_data$source == "observed", , drop = FALSE],
      ggplot2::aes(colour = "observed"),
      geom = "line",
      linewidth = 0.85,
      na.rm = TRUE,
      adjust = 1.1
    ) +
    ggplot2::facet_wrap(~trait, scales = "free") +
    ggplot2::scale_colour_manual(
      values = c(simulated = "#6B7280", observed = "#0072B2"),
      breaks = c("observed", "simulated")
    ) +
    ggplot2::labs(
      x = "Response value",
      y = "Density",
      colour = NULL,
      title = "Observed response against fitted-model draws"
    ) +
    .gllvmTMB_theme_predictive()
}

.gllvmTMB_plot_stat_grouped <- function(
  draws,
  group = NULL,
  stat = c("mean", "median", "zero_fraction")
) {
  stat <- match.arg(stat)
  group <- if (is.null(group)) "trait" else group
  if (!group %in% names(draws$row_data)) {
    cli::cli_abort(
      "{.arg group} must name a column in the diagnostic row metadata."
    )
  }
  group_value <- draws$row_data[[group]]
  stat_fun <- switch(
    stat,
    mean = function(x) mean(x, na.rm = TRUE),
    median = function(x) stats::median(x, na.rm = TRUE),
    zero_fraction = function(x) mean(x == 0, na.rm = TRUE)
  )

  observed <- tapply(draws$observed, group_value, stat_fun)
  sim_rows <- vector("list", ncol(draws$simulations))
  for (j in seq_len(ncol(draws$simulations))) {
    sim_rows[[j]] <- data.frame(
      group = names(observed),
      draw = j,
      value = as.numeric(tapply(draws$simulations[, j], group_value, stat_fun)),
      stringsAsFactors = FALSE
    )
  }
  sim_df <- do.call(rbind, sim_rows)
  split_sim <- split(sim_df$value, sim_df$group)
  summary_df <- data.frame(
    group = names(observed),
    observed = as.numeric(observed),
    sim_median = vapply(split_sim, stats::median, numeric(1), na.rm = TRUE),
    sim_low = vapply(
      split_sim,
      stats::quantile,
      numeric(1),
      probs = 0.025,
      na.rm = TRUE,
      names = FALSE
    ),
    sim_high = vapply(
      split_sim,
      stats::quantile,
      numeric(1),
      probs = 0.975,
      na.rm = TRUE,
      names = FALSE
    ),
    stat = stat,
    stringsAsFactors = FALSE
  )
  summary_df$group <- factor(summary_df$group, levels = summary_df$group)

  ggplot2::ggplot(summary_df, ggplot2::aes(x = group)) +
    ggplot2::geom_linerange(
      ggplot2::aes(ymin = sim_low, ymax = sim_high),
      colour = "#6B7280",
      linewidth = 0.65,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = sim_median),
      colour = "#6B7280",
      size = 2.1,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = observed),
      colour = "#0072B2",
      fill = "white",
      shape = 21,
      stroke = 0.9,
      size = 2.6,
      na.rm = TRUE
    ) +
    ggplot2::labs(
      x = group,
      y = paste0(stat, " statistic"),
      title = "Observed grouped statistic against fitted-model draws"
    ) +
    .gllvmTMB_theme_predictive()
}

.gllvmTMB_plot_rootogram <- function(draws, max_count = NULL) {
  dat <- .gllvmTMB_rootogram_data(draws, max_count = max_count)
  if (nrow(dat) == 0L) {
    cli::cli_abort(c(
      "{.arg type = \"rootogram\"} requires Poisson, NB1, NB2, zi_poisson, or zi_nbinom2 rows.",
      "i" = "Use {.arg type = \"rq_qq\"} for exact residual Q-Q checks on other families."
    ))
  }
  caption <- .gllvmTMB_rootogram_caption(dat)
  ggplot2::ggplot(dat, ggplot2::aes(x = count_label, y = root_diff)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#4B5563", linewidth = 0.35) +
    ggplot2::geom_col(fill = "#0072B2", width = 0.78, alpha = 0.82) +
    ggplot2::facet_wrap(~ trait + family, scales = "free_x") +
    ggplot2::labs(
      x = "Count",
      y = "sqrt(obs) - sqrt(exp)",
      title = "Count rootogram against fitted-model draws",
      caption = caption
    ) +
    .gllvmTMB_theme_predictive() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid.major.x = ggplot2::element_blank()
    )
}

.gllvmTMB_rootogram_data <- function(draws, max_count = NULL) {
  ## fid 17/18 (zi_poisson/zi_nbinom2) added (2026-09-02 review R1): the
  ## rootogram is entirely draws-based (compares OBSERVED vs SIMULATED
  ## counts, both already family-aware -- simulate() draws the mixture
  ## correctly for these two fids), so no other change is needed here.
  ## zi_binomial (fid 19) is deliberately excluded, matching binomial
  ## (fid 1) staying excluded from the plain-count rootogram already.
  count_rows <- draws$row_data$family_id %in%
    c(2L, 5L, 15L, 17L, 18L) &
    is.finite(draws$observed) &
    draws$observed >= 0 &
    draws$observed == floor(draws$observed)
  if (!any(count_rows)) {
    return(data.frame())
  }
  observed <- draws$observed[count_rows]
  simulations <- draws$simulations[count_rows, , drop = FALSE]
  row_data <- draws$row_data[count_rows, , drop = FALSE]

  if (is.null(max_count)) {
    max_count <- .gllvmTMB_auto_rootogram_max_count(observed, simulations)
  }
  if (!is.finite(max_count) || max_count < 0 || max_count != floor(max_count)) {
    cli::cli_abort("{.arg max_count} must be a non-negative integer or NULL.")
  }
  max_count <- as.integer(max_count)
  count_levels <- c(
    as.character(seq.int(0L, max_count)),
    paste0(">", max_count)
  )

  groups <- unique(row_data[c("trait", "family")])
  rows <- vector("list", nrow(groups))
  for (g in seq_len(nrow(groups))) {
    in_group <- row_data$trait == groups$trait[g] &
      row_data$family == groups$family[g]
    obs_bins <- .gllvmTMB_count_bins(observed[in_group], max_count)
    obs_tab <- tabulate(
      match(obs_bins, count_levels),
      nbins = length(count_levels)
    )

    sim_freq <- matrix(0, nrow = length(count_levels), ncol = ncol(simulations))
    for (j in seq_len(ncol(simulations))) {
      sim_bins <- .gllvmTMB_count_bins(simulations[in_group, j], max_count)
      sim_freq[, j] <- tabulate(
        match(sim_bins, count_levels),
        nbins = length(count_levels)
      )
    }
    expected <- rowMeans(sim_freq)
    rows[[g]] <- data.frame(
      trait = groups$trait[g],
      family = groups$family[g],
      count_label = factor(count_levels, levels = count_levels),
      count = seq_along(count_levels) - 1L,
      observed = obs_tab,
      expected = expected,
      root_diff = sqrt(obs_tab) - sqrt(expected),
      nsim = ncol(simulations),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.gllvmTMB_auto_rootogram_max_count <- function(
  observed,
  simulations,
  cap = 100L
) {
  raw_max <- max(c(observed, simulations), na.rm = TRUE)
  if (!is.finite(raw_max)) {
    return(raw_max)
  }
  if (raw_max <= cap) {
    return(raw_max)
  }
  cli::cli_warn(c(
    "Auto {.arg max_count} for the rootogram was capped at {cap}.",
    "i" = paste0(
      "Counts above ",
      cap,
      " are pooled into the tail bin; pass {.arg max_count} explicitly ",
      "to override."
    )
  ))
  cap
}

.gllvmTMB_count_bins <- function(x, max_count) {
  x <- as.integer(round(x))
  ifelse(x > max_count, paste0(">", max_count), as.character(x))
}

.gllvmTMB_plot_rq_qq <- function(residuals) {
  invalid <- sum(residuals$status != "ok")
  caption <- if (invalid > 0L) {
    paste0(
      invalid,
      " row(s) retained with non-ok residual status; inspect ",
      "attr(plot, \"gllvmTMB_diagnostic\")$data."
    )
  } else {
    "All plotted rows had finite observed values and residuals."
  }

  ggplot2::ggplot(residuals, ggplot2::aes(sample = residual)) +
    ggplot2::stat_qq(
      colour = "#0072B2",
      alpha = 0.75,
      size = 1.6,
      na.rm = TRUE
    ) +
    ggplot2::stat_qq_line(
      colour = "#4B5563",
      linewidth = 0.55,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(~ trait + family, scales = "free") +
    ggplot2::labs(
      x = "Theoretical normal quantile",
      y = "Diagnostic residual",
      title = "Randomized-quantile residual Q-Q check",
      caption = caption
    ) +
    .gllvmTMB_theme_predictive()
}

.gllvmTMB_theme_predictive <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(
        colour = "#E5E7EB",
        linewidth = 0.25
      ),
      panel.grid.major.y = ggplot2::element_line(
        colour = "#E5E7EB",
        linewidth = 0.25
      ),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}

.gllvmTMB_attach_diagnostic_metadata <- function(
  plot,
  data,
  type,
  method,
  seed,
  nsim,
  condition_on_RE,
  object
) {
  fit_meta <- .gllvmTMB_diagnostic_fit_metadata(object)
  attr(plot, "gllvmTMB_diagnostic") <- list(
    data = data,
    type = type,
    method = method,
    seed = seed,
    nsim = nsim,
    condition_on_RE = isTRUE(condition_on_RE),
    invalid_rows = if ("status" %in% names(data)) {
      sum(data$status != "ok")
    } else {
      NA_integer_
    },
    check_gllvmTMB = fit_meta$check_gllvmTMB,
    fit_health = fit_meta$fit_health,
    fit_health_status = fit_meta$status,
    fit_health_error = fit_meta$error
  )
  plot
}

.gllvmTMB_attach_residual_metadata <- function(
  residuals,
  object,
  residual_type,
  method,
  seed,
  nsim,
  condition_on_RE,
  scale
) {
  fit_meta <- .gllvmTMB_diagnostic_fit_metadata(object)
  condition_value <- if (
    length(condition_on_RE) == 0L ||
      is.na(condition_on_RE)
  ) {
    NA
  } else {
    isTRUE(condition_on_RE)
  }
  attr(residuals, "method") <- method
  attr(residuals, "gllvmTMB_diagnostic") <- list(
    type = "residuals",
    residual_type = residual_type,
    method = method,
    seed = seed,
    nsim = nsim,
    condition_on_RE = condition_value,
    scale = scale,
    invalid_rows = if ("status" %in% names(residuals)) {
      sum(residuals$status != "ok")
    } else {
      NA_integer_
    },
    check_gllvmTMB = fit_meta$check_gllvmTMB,
    fit_health = fit_meta$fit_health,
    fit_health_status = fit_meta$status,
    fit_health_error = fit_meta$error
  )
  residuals
}

.gllvmTMB_diagnostic_fit_metadata <- function(object) {
  health_error <- NA_character_
  check_error <- NA_character_
  health <- tryCatch(
    object$fit_health %||% .gllvmTMB_build_fit_health(object),
    error = function(e) {
      health_error <<- conditionMessage(e)
      NULL
    }
  )
  check <- tryCatch(
    check_gllvmTMB(object),
    error = function(e) {
      check_error <<- conditionMessage(e)
      NULL
    }
  )
  status <- if (is.data.frame(check) && "status" %in% names(check)) {
    tab <- table(check$status, useNA = "ifany")
    data.frame(
      status = names(tab),
      n = as.integer(tab),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(status = character(), n = integer(), stringsAsFactors = FALSE)
  }
  list(
    check_gllvmTMB = check,
    fit_health = health,
    status = status,
    error = c(
      check_gllvmTMB = check_error,
      fit_health = health_error
    )
  )
}

.gllvmTMB_validate_diagnostic_fit <- function(object) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("{.arg object} must be a {.cls gllvmTMB_multi} fit.")
  }
  required <- c("y", "family_id_vec", "link_id_vec", "trait_id")
  missing <- setdiff(required, names(object$tmb_data))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "{.arg object$tmb_data} is missing required field(s): {.val {missing}}."
    )
  }
  invisible(TRUE)
}

.gllvmTMB_trait_keep <- function(row_meta, trait = NULL) {
  keep <- rep(TRUE, nrow(row_meta))
  if (!is.null(trait)) {
    keep <- row_meta$trait %in% as.character(trait)
    if (!any(keep)) {
      cli::cli_abort("No rows matched the requested {.arg trait} filter.")
    }
  }
  keep
}

.gllvmTMB_resolve_nsim <- function(nsim = NULL, ndraws = NULL) {
  if (
    !is.null(nsim) &&
      !is.null(ndraws) &&
      !identical(as.integer(nsim), as.integer(ndraws))
  ) {
    cli::cli_abort(
      "Specify only one of {.arg nsim} or {.arg ndraws}, or give them the same value."
    )
  }
  out <- if (!is.null(nsim)) {
    nsim
  } else if (!is.null(ndraws)) {
    ndraws
  } else {
    50L
  }
  if (length(out) != 1L || is.na(out) || out < 2L || out != as.integer(out)) {
    cli::cli_abort("{.arg nsim} / {.arg ndraws} must be a single integer >= 2.")
  }
  as.integer(out)
}

.gllvmTMB_sigma_eps_vector <- function(object) {
  sigma_eps <- as.numeric(object$report$sigma_eps %||% numeric(0L))
  if (!length(sigma_eps) || any(!is.finite(sigma_eps))) {
    par <- object$opt$par %||% numeric(0L)
    idx <- which(names(par) == "log_sigma_eps")
    sigma_eps <- if (length(idx)) exp(unname(par[idx])) else numeric(0L)
  }
  if (!length(sigma_eps)) sigma_eps <- 1
  sigma_eps[!is.finite(sigma_eps) | sigma_eps <= 0] <- 1
  sigma_eps
}

.gllvmTMB_sigma_eps_for_family <- function(object, family_id) {
  family_id <- as.integer(family_id)
  sigma_eps <- .gllvmTMB_sigma_eps_vector(object)
  fitted_families <- unique(as.integer(
    object$tmb_data$family_id_vec %||% integer(0L)
  ))
  has_split <-
    length(sigma_eps) >= 2L && all(c(0L, 3L) %in% fitted_families)
  slot <- if (has_split && identical(family_id, 3L)) 2L else 1L
  sigma_eps[[slot]]
}

.gllvmTMB_sigma_eps <- function(object) {
  .gllvmTMB_sigma_eps_for_family(object, 0L)
}

.gllvmTMB_clip_unit_interval <- function(u) {
  eps <- .Machine$double.eps
  pmin(pmax(u, eps), 1 - eps)
}

## eta -> probability for a binomial (fid 1) row, dispatched on link_id
## EXACTLY as src/gllvmTMB.cpp fid == 1 does: 0 = logit, 1 = probit,
## 2 = cloglog. The caller (the fid == 1 branch above) is responsible for
## checking link_id %in% c(0L, 1L, 2L) BEFORE calling this and setting
## status = "unknown_link" otherwise -- this helper assumes a valid
## link_id and does not itself guard against NA / unrecognised values.
.gllvmTMB_binom_prob <- function(eta, link_id) {
  if (link_id == 0L) {
    stats::plogis(eta)
  } else if (link_id == 1L) {
    stats::pnorm(eta)
  } else {
    -expm1(-exp(eta))
  }
}

## Beta-binomial CDF at k = 0 .. N, given Beta-mixing shape parameters a, b
## (mu = a / (a + b), phi = a + b). No base-R or already-imported CDF exists
## for this distribution, so the pmf is hand-rolled from the SAME lgamma
## terms as the engine's log-density (src/gllvmTMB.cpp fid == 8) --
## lchoose(N, k) + lbeta(k + a, N - k + b) - lbeta(a, b) -- and cumulatively
## summed. Returns a length-(N + 1) vector; element k + 1 is P(Y <= k). `k`
## may be passed in precomputed (the caller caches 0:N by trial count N,
## since N is typically constant within a trait across many rows).
.gllvmTMB_betabinom_cdf <- function(N, a, b, k = 0:N) {
  log_pmf <- lchoose(N, k) + lbeta(k + a, N - k + b) - lbeta(a, b)
  cumsum(exp(log_pmf))
}

.gllvmTMB_family_label_from_id <- function(family_id) {
  labels <- c(
    "0" = "gaussian",
    "1" = "binomial",
    "2" = "poisson",
    "3" = "lognormal",
    "4" = "Gamma",
    "5" = "nbinom2",
    "6" = "tweedie",
    "7" = "Beta",
    "8" = "betabinomial",
    "9" = "student",
    "10" = "truncated_poisson",
    "11" = "truncated_nbinom2",
    "12" = "delta_lognormal",
    "13" = "delta_gamma",
    "14" = "ordinal_probit",
    "15" = "nbinom1",
    "17" = "zi_poisson",
    "18" = "zi_nbinom2",
    "19" = "zi_binomial"
  )
  out <- unname(labels[as.character(family_id)])
  out[is.na(out)] <- paste0("family_id_", family_id[is.na(out)])
  out
}

.gllvmTMB_rootogram_caption <- function(dat) {
  families <- paste(sort(unique(dat$family)), collapse = ", ")
  paste0(
    "Bars show square-root observed minus expected fitted-model frequency; ",
    "families shown: ",
    families,
    "."
  )
}

## Column names referenced bare inside ggplot2::aes() above; declared here to
## avoid R CMD check "no visible binding for global variable" NOTEs.
utils::globalVariables(c(
  "value", "count_label", "root_diff", "residual",
  "sim_low", "sim_high", "sim_median"
))
