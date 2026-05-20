## Prototype posterior-predictive / simulation-rank diagnostics for #222.
##
## This file is intentionally non-exported prototype code. Source it after
## loading gllvmTMB, for example:
##
##   pkgload::load_all()
##   source("inst/prototypes/ppcheck-diagnostics.R")
##
## The public API is still under design. These helpers exercise the proposed
## data contract and figure contract without exporting `pp_check()` or
## `residuals(type = "randomized_quantile")` prematurely.

gllvmTMB_ppc_draws_prototype <- function(
  object,
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = FALSE
) {
  validate_gllvmTMB_ppc_fit(object)
  nsim <- resolve_gllvmTMB_ppc_nsim(nsim, ndraws)

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
    stop(
      "simulate(object) returned a matrix that does not align with the observed response.",
      call. = FALSE
    )
  }

  row_meta <- gllvmTMB_ppc_row_metadata(object)
  keep <- rep(TRUE, length(observed))
  if (!is.null(trait)) {
    keep <- row_meta$trait %in% as.character(trait)
    if (!any(keep)) {
      stop("No rows matched the requested trait filter.", call. = FALSE)
    }
  }

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
  class(out) <- "gllvmTMB_ppc_draws_prototype"
  out
}

gllvmTMB_simulation_rank_residuals_prototype <- function(
  object,
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  condition_on_RE = FALSE,
  scale = c("normal", "uniform")
) {
  scale <- match.arg(scale)
  draws <- gllvmTMB_ppc_draws_prototype(
    object,
    nsim = nsim,
    ndraws = ndraws,
    seed = seed,
    trait = trait,
    condition_on_RE = condition_on_RE
  )
  observed <- draws$observed
  simulations <- draws$simulations
  n <- length(observed)
  nsim <- ncol(simulations)

  nonfinite_observed <- !is.finite(observed)
  nonfinite_simulation <- !is.finite(rowSums(simulations))
  ok <- !(nonfinite_observed | nonfinite_simulation)

  u <- rep(NA_real_, n)
  residual <- rep(NA_real_, n)
  if (any(ok)) {
    less <- rowSums(simulations[ok, , drop = FALSE] < observed[ok])
    ties <- rowSums(simulations[ok, , drop = FALSE] == observed[ok])
    ## Simulation-rank randomized PIT. The +1 denominator leaves room for
    ## the observed value among the simulated draws and avoids exact 0/1.
    u_ok <- (less + stats::runif(sum(ok), min = 0, max = ties + 1)) /
      (nsim + 1)
    eps <- .Machine$double.eps
    u_ok <- pmin(pmax(u_ok, eps), 1 - eps)
    u[ok] <- u_ok
    residual[ok] <- if (identical(scale, "normal")) {
      stats::qnorm(u_ok)
    } else {
      u_ok
    }
  }

  status <- rep("ok", n)
  status[nonfinite_observed] <- "nonfinite_observed"
  status[!nonfinite_observed & nonfinite_simulation] <- "nonfinite_simulation"
  status[!is.finite(residual) & status == "ok"] <- "nonfinite_residual"

  out <- cbind(
    draws$row_data,
    data.frame(
      observed = observed,
      u = u,
      residual = residual,
      status = status,
      scale = scale,
      nsim = nsim,
      seed = if (is.null(seed)) NA_integer_ else seed,
      condition_on_RE = isTRUE(condition_on_RE),
      stringsAsFactors = FALSE
    )
  )
  rownames(out) <- NULL
  out
}

gllvmTMB_pp_check_prototype <- function(
  object,
  type = c("dens_overlay", "stat_grouped", "rq_qq"),
  nsim = NULL,
  ndraws = NULL,
  seed = NULL,
  trait = NULL,
  group = NULL,
  stat = c("mean", "median", "zero_fraction"),
  condition_on_RE = FALSE
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("gllvmTMB_pp_check_prototype() requires ggplot2.", call. = FALSE)
  }
  type <- match.arg(type)
  stat <- match.arg(stat)
  nsim <- resolve_gllvmTMB_ppc_nsim(nsim, ndraws)

  if (identical(type, "rq_qq")) {
    residuals <- gllvmTMB_simulation_rank_residuals_prototype(
      object,
      nsim = nsim,
      seed = seed,
      trait = trait,
      condition_on_RE = condition_on_RE,
      scale = "normal"
    )
    plot <- plot_gllvmTMB_ppc_rq_qq(residuals)
    return(attach_gllvmTMB_ppc_metadata(
      plot,
      data = residuals,
      type = type,
      method = "simulation_rank_residuals",
      seed = seed,
      nsim = nsim,
      condition_on_RE = condition_on_RE
    ))
  }

  draws <- gllvmTMB_ppc_draws_prototype(
    object,
    nsim = nsim,
    seed = seed,
    trait = trait,
    condition_on_RE = condition_on_RE
  )

  plot <- switch(
    type,
    dens_overlay = plot_gllvmTMB_ppc_density(draws),
    stat_grouped = plot_gllvmTMB_ppc_stat_grouped(
      draws,
      group = group,
      stat = stat
    )
  )
  attach_gllvmTMB_ppc_metadata(
    plot,
    data = plot$data,
    type = type,
    method = "simulation_from_fitted_model",
    seed = seed,
    nsim = nsim,
    condition_on_RE = condition_on_RE
  )
}

gllvmTMB_ppc_row_metadata <- function(object) {
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
  if (length(family_id) != n) {
    family_id <- rep(NA_integer_, n)
  }
  if (length(link_id) != n) {
    link_id <- rep(NA_integer_, n)
  }

  data.frame(
    .row = seq_len(n),
    trait = trait,
    family_id = family_id,
    family = family_label_from_id(family_id),
    link_id = link_id,
    stringsAsFactors = FALSE
  )
}

plot_gllvmTMB_ppc_density <- function(draws) {
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
      title = "Observed response against simulated fitted-model draws"
    ) +
    theme_gllvmTMB_ppc()
}

plot_gllvmTMB_ppc_stat_grouped <- function(
  draws,
  group = NULL,
  stat = c("mean", "median", "zero_fraction")
) {
  stat <- match.arg(stat)
  group <- if (is.null(group)) "trait" else group
  if (!group %in% names(draws$row_data)) {
    stop(
      "group must name a column in the diagnostic row metadata.",
      call. = FALSE
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
    theme_gllvmTMB_ppc()
}

plot_gllvmTMB_ppc_rq_qq <- function(residuals) {
  invalid <- sum(residuals$status != "ok")
  caption <- if (invalid > 0L) {
    paste0(
      invalid,
      " row(s) retained with non-ok simulation-rank residual status; ",
      "inspect attr(plot, \"gllvmTMB_diagnostic\")$data."
    )
  } else {
    "All rows had finite observed values, simulations, and residuals."
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
    ggplot2::facet_wrap(~trait, scales = "free") +
    ggplot2::labs(
      x = "Theoretical normal quantile",
      y = "Simulation-rank residual",
      title = "Simulation-rank residual Q-Q check",
      caption = caption
    ) +
    theme_gllvmTMB_ppc()
}

theme_gllvmTMB_ppc <- function(base_size = 11) {
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

attach_gllvmTMB_ppc_metadata <- function(
  plot,
  data,
  type,
  method,
  seed,
  nsim,
  condition_on_RE
) {
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
    }
  )
  plot
}

validate_gllvmTMB_ppc_fit <- function(object) {
  if (!inherits(object, "gllvmTMB_multi")) {
    stop("object must be a gllvmTMB_multi fit.", call. = FALSE)
  }
  required <- c("y", "family_id_vec", "link_id_vec")
  missing <- setdiff(required, names(object$tmb_data))
  if (length(missing) > 0L) {
    stop(
      paste0(
        "object$tmb_data is missing required field(s): ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

resolve_gllvmTMB_ppc_nsim <- function(nsim = NULL, ndraws = NULL) {
  if (
    !is.null(nsim) &&
      !is.null(ndraws) &&
      !identical(as.integer(nsim), as.integer(ndraws))
  ) {
    stop(
      "Specify only one of nsim or ndraws, or give them the same value.",
      call. = FALSE
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
    stop("nsim / ndraws must be a single integer >= 2.", call. = FALSE)
  }
  as.integer(out)
}

family_label_from_id <- function(family_id) {
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
    "14" = "ordinal_probit"
  )
  out <- unname(labels[as.character(family_id)])
  out[is.na(out)] <- paste0("family_id_", family_id[is.na(out)])
  out
}
