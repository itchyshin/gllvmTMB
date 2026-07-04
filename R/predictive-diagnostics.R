## Fitted-model predictive checks and diagnostic residuals for
## gllvmTMB_multi fits. These helpers deliberately say "fitted-model
## predictive" rather than "posterior predictive": draws currently come
## from simulate.gllvmTMB_multi() at fitted parameters, not from a
## Bayesian parameter posterior.

#' Fitted-model predictive checks for a multivariate `gllvmTMB` fit
#'
#' `predictive_check()` compares the observed stacked-trait response to
#' draws from the fitted model. It is the public version of the diagnostic
#' prototype from issue #222, but keeps the frequentist semantics explicit:
#' these are fitted-model predictive checks, not Bayesian posterior
#' predictive checks.
#'
#' The returned object is a `ggplot`. Its plotted data, fit-health table
#' from [check_gllvmTMB()], and `fit$fit_health` snapshot are also stored
#' in `attr(plot, "gllvmTMB_diagnostic")` so the figure can be audited
#' without reverse-engineering ggplot layers.
#'
#' Scope boundary (DIA-11 / DIA-12): IN, fitted-model predictive plots
#' and residual Q-Q/rootogram helpers for `gllvmTMB_multi` fits, with
#' exact randomized-quantile residuals for Gaussian, Poisson, and NB2
#' rows and a simulation-rank fallback. PARTIAL, these are diagnostic
#' displays, not formal uniformity, dispersion, interval-calibration, or
#' Bayesian posterior-predictive tests. PLANNED, exact residual support
#' for delta, hurdle, truncated, ordinal, and mixture families remains
#' future validation work.
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
#'   bin. Default `NULL` uses all observed and simulated count values.
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
#' Gaussian, Poisson, and NB2 rows. `type = "simulation_rank"` uses
#' fitted-model simulations and is available as a fallback for checking
#' the same row contract when exact family-CDF plumbing is not yet
#' implemented.
#'
#' Rows are retained even when a residual cannot be computed. Inspect the
#' `status` column before treating residuals as complete.
#'
#' Scope boundary (DIA-12): IN, exact family-CDF randomized-quantile
#' residuals for Gaussian, Poisson, and NB2 rows plus simulation-rank
#' residuals from fitted-model draws. PARTIAL, unsupported families are
#' retained with row status rather than promoted to exact residual
#' claims. PLANNED, broader family coverage and formal residual tests
#' remain later validation work.
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
  n <- length(observed)

  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  u <- rep(NA_real_, n)
  residual <- rep(NA_real_, n)
  status <- rep("ok", n)

  sigma_eps <- .gllvmTMB_sigma_eps(object)
  phi_nbinom2 <- object$report$phi_nbinom2
  phi_nbinom1 <- object$report$phi_nbinom1

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
      lower[i] <- stats::pnorm(y_i, mean = eta[i], sd = sigma_eps)
      upper[i] <- lower[i]
      u[i] <- lower[i]
    } else if (fid == 2L) {
      if (y_i < 0 || y_i != floor(y_i)) {
        status[i] <- "invalid_observed"
        next
      }
      lambda <- exp(eta[i])
      lower[i] <- if (y_i <= 0) 0 else stats::ppois(y_i - 1, lambda = lambda)
      upper[i] <- stats::ppois(y_i, lambda = lambda)
      u[i] <- stats::runif(1L, min = lower[i], max = upper[i])
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
    } else {
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
      "{.arg type = \"rootogram\"} requires Poisson or NB2 rows.",
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
  count_rows <- draws$row_data$family_id %in%
    c(2L, 5L) &
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
    max_count <- max(c(observed, simulations), na.rm = TRUE)
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

.gllvmTMB_sigma_eps <- function(object) {
  sigma_eps <- as.numeric(object$report$sigma_eps)
  if (
    is.null(sigma_eps) || length(sigma_eps) == 0L || !is.finite(sigma_eps[1])
  ) {
    sigma_eps <- exp(unname(object$opt$par["log_sigma_eps"]))
  }
  if (is.na(sigma_eps[1]) || sigma_eps[1] <= 0) {
    sigma_eps <- 1
  }
  sigma_eps[1L]
}

.gllvmTMB_clip_unit_interval <- function(u) {
  eps <- .Machine$double.eps
  pmin(pmax(u, eps), 1 - eps)
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
    "15" = "nbinom1"
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
