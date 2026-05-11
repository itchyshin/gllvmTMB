## ggplot2-based S3 plot method for `gllvmTMB_multi` fits.
##
## Lifted in spirit from gllvm2lev::plot.gllvm2lev() but re-implemented
## around gllvmTMB's extractor API: extract_Sigma(), extract_proportions(),
## extract_communality(), extract_ICC_site(), extract_ordination(),
## getLoadings(). One dispatcher, five plot types.

#' Plot a fitted multivariate `gllvmTMB_multi` model
#'
#' Produces a variety of `ggplot2` visualisations for a stacked-trait
#' multivariate GLLVM. Dispatches on `type` to one of five panels:
#'
#' \describe{
#'   \item{`"correlation"`}{Combined heatmap of trait correlations.
#'     Upper triangle = between-unit correlations (`level = "unit"`),
#'     lower triangle = within-unit correlations (`level = "unit_obs"`),
#'     diagonal = 1. Falls back to whichever level is present if the
#'     other tier is absent.}
#'   \item{`"loadings"`}{Tile heatmap of `Lambda_B` (and `Lambda_W` if
#'     present), faceted by level. Rows = traits, columns = factors.
#'     Pinned cells (from `lambda_constraint`) are drawn with a heavy
#'     outline.}
#'   \item{`"integration"`}{Dot-and-whisker plot of repeatability (ICC),
#'     between-tier communality and within-tier communality per trait,
#'     sorted by repeatability. Optional whiskers from a `boot` object
#'     (skipped if `boot = NULL`).}
#'   \item{`"variance"`}{Stacked-bar variance partition per trait, using
#'     `extract_proportions(format = "long")`. One bar per trait,
#'     stacks summing to 1.}
#'   \item{`"ordination"`}{Two-axis biplot of latent scores plus loading
#'     arrows. 1D fits (`d = 1`) get a horizontal lollipop; 2D fits get
#'     a standard biplot; for `d >= 3` pick the axis pair via `axes`.}
#' }
#'
#' @param x A `gllvmTMB_multi` fit.
#' @param type One of `"correlation"`, `"loadings"`, `"integration"`,
#'   `"variance"`, `"ordination"`.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Legacy aliases `"B"` and `"W"` are accepted with a deprecation warning.
#'   Used by `"loadings"` (which level to plot; the default
#'   `c("unit", "unit_obs")` means "both available levels, faceted
#'   side-by-side"; pass a length-1 string to plot one tier) and
#'   `"ordination"` (single level required, default `"unit"`). Ignored for
#'   `"correlation"` (which always shows both if available), `"integration"`,
#'   and `"variance"`.
#'
#'   *Note*: the default `level = c("unit", "unit_obs")` is intentionally a
#'   length-2 vector, not the usual `match.arg` shortcut. The dispatcher
#'   does **not** call `match.arg(level)` itself; each helper inspects
#'   `level` and decides whether to plot one tier or both. If you copy
#'   one of these helpers into your own code, mirror that pattern rather
#'   than reflexively calling `match.arg(level)` (which would silently
#'   collapse the default to `"B"` and drop the W panel).
#' @param boot Optional bootstrap object (currently a list with elements
#'   `repeatability`, `communality_B`, `communality_W`, each a data
#'   frame with columns `trait`, `lower`, `upper`) used to add whiskers
#'   to the `"integration"` plot. Default `NULL` skips whiskers.
#' @param axes Length-2 integer vector for `"ordination"` when
#'   `d >= 2`. Default `c(1, 2)`. Ignored when `d = 1`.
#' @param ... Currently unused.
#' @return A `ggplot` object.
#' @method plot gllvmTMB_multi
#' @export
plot.gllvmTMB_multi <- function(x,
                                type = c("correlation", "loadings",
                                         "integration", "variance",
                                         "ordination"),
                                level = c("unit", "unit_obs"),
                                boot  = NULL,
                                axes  = c(1L, 2L),
                                ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE))
    cli::cli_abort("Install ggplot2: {.code install.packages(\"ggplot2\")}.")
  type  <- match.arg(type)
  ## level intentionally not match.arg'd up-front: each helper decides
  ## whether to require a single value or accept "both/NULL".
  ## Boundary normalisation per element when present, then de-duplicate
  ## so a user passing legacy + canonical (`c("unit", "B")`) collapses
  ## to a single internal slot (`c("B")`) rather than fooling the
  ## length-based "both tiers" guards in `.plot_loadings_gtmb` /
  ## `.plot_ordination_gtmb`. Regression: PR #60 R-CMD-check #95
  ## (test-plot-gllvmTMB.R:47) failed with `match.arg(level, c("B","W"))`
  ## "'arg' must be of length 1" because the prior length-4 default
  ## `c("unit", "unit_obs", "B", "W")` normalised to `c("B","W","B","W")`,
  ## skipped the length-2 guard, then hit match.arg.
  if (is.character(level) && length(level) > 0L) {
    level <- vapply(level, .normalise_level, character(1L), arg_name = "level")
    level <- unique(level)
  }
  switch(type,
    correlation = .plot_correlation_gtmb(x),
    loadings    = .plot_loadings_gtmb(x, level),
    integration = .plot_integration_gtmb(x, boot = boot),
    variance    = .plot_variance_gtmb(x),
    ordination  = .plot_ordination_gtmb(x, level, axes = axes)
  )
}


# ---- helpers --------------------------------------------------------------

.gtmb_trait_names <- function(fit) {
  levels(fit$data[[fit$trait_col]])
}


# ---- correlation heatmap --------------------------------------------------

.plot_correlation_gtmb <- function(fit) {
  tn <- .gtmb_trait_names(fit)
  Tn <- length(tn)

  R_B <- if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B))
    suppressMessages(extract_Sigma(fit, level = "unit", part = "total"))$R else NULL
  R_W <- if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W))
    suppressMessages(extract_Sigma(fit, level = "unit_obs", part = "total"))$R else NULL

  if (is.null(R_B) && is.null(R_W))
    cli::cli_abort("No correlation matrix available -- neither B nor W tier has rr/diag.")

  ## Combined matrix: upper = B, lower = W, diag = 1
  combined <- matrix(NA_real_, Tn, Tn, dimnames = list(tn, tn))
  if (!is.null(R_B)) combined[upper.tri(combined)] <- R_B[upper.tri(R_B)]
  if (!is.null(R_W)) combined[lower.tri(combined)] <- R_W[lower.tri(R_W)]
  diag(combined) <- 1

  ## In single-tier fallback fill the *empty* triangle with the available one
  if (is.null(R_B) && !is.null(R_W))
    combined[upper.tri(combined)] <- R_W[upper.tri(R_W)]
  if (!is.null(R_B) && is.null(R_W))
    combined[lower.tri(combined)] <- R_B[lower.tri(R_B)]

  idx <- which(!is.na(combined), arr.ind = TRUE)
  dat <- data.frame(
    row   = factor(tn[idx[, 1L]], levels = rev(tn)),
    col   = factor(tn[idx[, 2L]], levels = tn),
    value = combined[idx],
    stringsAsFactors = FALSE
  )

  subtitle <- if (!is.null(R_B) && !is.null(R_W)) {
    "Upper triangle: between-unit  |  Lower triangle: within-unit"
  } else if (!is.null(R_B)) {
    "Between-unit only"
  } else {
    "Within-unit only"
  }

  ggplot2::ggplot(dat,
                  ggplot2::aes(x = .data$col, y = .data$row,
                               fill = .data$value)) +
    ggplot2::geom_tile(colour = "grey90") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", .data$value)),
                       size = 3) +
    ggplot2::scale_fill_gradient2(
      low = "steelblue", mid = "white", high = "firebrick",
      midpoint = 0, limits = c(-1, 1), name = "rho"
    ) +
    ggplot2::labs(x = NULL, y = NULL,
                  title = "Trait correlation matrix",
                  subtitle = subtitle) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}


# ---- loadings heatmap -----------------------------------------------------

.plot_loadings_gtmb <- function(fit, level) {
  ## level: NULL or the default-vector c("B","W") -> both available levels;
  ## a length-1 "B" or "W" -> single level.
  if (missing(level) || is.null(level) ||
      (length(level) == 2L && setequal(level, c("B", "W")))) {
    levels_to_plot <- character(0)
    if (isTRUE(fit$use$rr_B)) levels_to_plot <- c(levels_to_plot, "B")
    if (isTRUE(fit$use$rr_W)) levels_to_plot <- c(levels_to_plot, "W")
  } else {
    level <- match.arg(level, c("B", "W"))
    levels_to_plot <- level
  }
  if (length(levels_to_plot) == 0L)
    cli::cli_abort("No latent() loadings to plot at the requested level(s).")

  tn <- .gtmb_trait_names(fit)
  rows <- list()
  for (lv in levels_to_plot) {
    L <- suppressMessages(getLoadings(
      fit, level = .canonical_level_name(lv), rotate = "none"
    ))
    if (is.null(L)) next
    if (is.null(rownames(L))) rownames(L) <- tn
    constraint <- fit$lambda_constraint[[lv]]
    for (j in seq_len(ncol(L))) {
      pinned <- if (!is.null(constraint))
        !is.na(constraint[, j])
      else
        rep(FALSE, nrow(L))
      rows[[length(rows) + 1L]] <- data.frame(
        trait   = rownames(L),
        factor  = paste0("LV", j),
        loading = L[, j],
        level   = paste0("Level ", .canonical_level_name(lv)),
        pinned  = pinned,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L)
    cli::cli_abort("No loadings to plot.")

  dat <- do.call(rbind, rows)
  dat$trait <- factor(dat$trait, levels = rev(tn))

  p <- ggplot2::ggplot(dat,
                       ggplot2::aes(x = .data$factor, y = .data$trait,
                                    fill = .data$loading)) +
    ggplot2::geom_tile(colour = "grey90") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", .data$loading)),
                       size = 3)

  ## Heavy outline on pinned cells
  if (any(dat$pinned)) {
    p <- p + ggplot2::geom_tile(
      data    = dat[dat$pinned, , drop = FALSE],
      colour  = "black",
      fill    = NA,
      linewidth = 1
    )
  }

  p +
    ggplot2::scale_fill_gradient2(
      low = "steelblue", mid = "white", high = "firebrick",
      midpoint = 0, name = "Loading"
    ) +
    ggplot2::facet_wrap(~ level) +
    ggplot2::labs(x = "Latent factor", y = NULL,
                  title = "Factor loadings (Lambda)") +
    ggplot2::theme_minimal()
}


# ---- integration indices --------------------------------------------------

.plot_integration_gtmb <- function(fit, boot = NULL) {
  tn <- .gtmb_trait_names(fit)
  rep   <- suppressMessages(extract_ICC_site(fit))
  com_B <- suppressMessages(extract_communality(fit, level = "unit"))
  com_W <- suppressMessages(extract_communality(fit, level = "unit_obs"))

  if (is.null(rep) && is.null(com_B) && is.null(com_W))
    cli::cli_abort("No integration indices computable from this fit.")

  pull_ci <- function(boot, name, traits) {
    if (is.null(boot) || is.null(boot[[name]])) {
      data.frame(trait = traits,
                 lower = rep(NA_real_, length(traits)),
                 upper = rep(NA_real_, length(traits)),
                 stringsAsFactors = FALSE)
    } else {
      ci <- boot[[name]]
      ci[match(traits, ci$trait), c("trait", "lower", "upper"), drop = FALSE]
    }
  }

  rows <- list()
  if (!is.null(rep)) {
    ci <- pull_ci(boot, "repeatability", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait    = tn,
      index    = "Repeatability",
      estimate = unname(rep[tn]),
      lower    = ci$lower, upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(com_B)) {
    ci <- pull_ci(boot, "communality_B", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait    = tn,
      index    = "Communality (B)",
      estimate = unname(com_B[tn]),
      lower    = ci$lower, upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(com_W)) {
    ci <- pull_ci(boot, "communality_W", tn)
    rows[[length(rows) + 1L]] <- data.frame(
      trait    = tn,
      index    = "Communality (W)",
      estimate = unname(com_W[tn]),
      lower    = ci$lower, upper = ci$upper,
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)

  ## Order by repeatability descending if available, else by name
  if (!is.null(rep)) {
    trait_order <- names(sort(rep, decreasing = TRUE))
  } else {
    trait_order <- tn
  }
  dat$trait <- factor(dat$trait, levels = rev(trait_order))
  dat$index <- factor(dat$index,
                      levels = c("Repeatability",
                                 "Communality (B)",
                                 "Communality (W)"))

  p <- ggplot2::ggplot(dat,
                       ggplot2::aes(x = .data$estimate, y = .data$trait,
                                    colour = .data$index,
                                    shape = .data$index)) +
    ggplot2::geom_point(size = 3,
                        position = ggplot2::position_dodge(width = 0.5))

  if (any(!is.na(dat$lower))) {
    p <- p + ggplot2::geom_errorbarh(
      ggplot2::aes(xmin = .data$lower, xmax = .data$upper),
      height = 0.2,
      position = ggplot2::position_dodge(width = 0.5)
    )
  }

  p +
    ggplot2::scale_x_continuous(limits = c(0, 1)) +
    ggplot2::labs(x = "Estimate", y = NULL,
                  colour = NULL, shape = NULL,
                  title = "Integration indices by trait") +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "bottom")
}


# ---- variance partition ---------------------------------------------------

.plot_variance_gtmb <- function(fit) {
  dat <- suppressMessages(extract_proportions(fit, format = "long"))
  ## extract_proportions already returns trait + component as factors,
  ## variance + proportion numeric.

  ## Stable, pleasant component palette
  pal <- c(
    "shared_phy"      = "#762A83",
    "shared_unit"     = "#2166AC",
    "unique_unit"     = "#92C5DE",
    "shared_unit_obs" = "#B2182B",
    "unique_unit_obs" = "#F4A582",
    "link_residual"   = "grey70"
  )
  ## Drop entries the data does not contain (so the legend is tight)
  pal <- pal[intersect(names(pal), levels(dat$component))]

  ggplot2::ggplot(dat,
                  ggplot2::aes(x = .data$trait,
                               y = .data$proportion,
                               fill = .data$component)) +
    ggplot2::geom_col(position = "stack") +
    ggplot2::scale_fill_manual(values = pal, name = "Component") +
    ggplot2::scale_y_continuous(limits = c(0, 1.001),
                                expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(x = NULL, y = "Proportion of variance",
                  title = "Variance decomposition by trait") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    )
}


# ---- ordination biplot ----------------------------------------------------

.plot_ordination_gtmb <- function(fit, level, axes = c(1L, 2L)) {
  ## The dispatcher's default is the c("B","W") internal vector; for
  ## ordination the user must pick one explicitly.
  if (missing(level) || is.null(level) || length(level) != 1L)
    cli::cli_abort("Specify a single {.arg level} for ordination: {.val unit} or {.val unit_obs}.")
  if (!level %in% c("B", "W"))
    cli::cli_abort("{.arg level} must be {.val unit} or {.val unit_obs}.")
  level_label <- .canonical_level_name(level)

  ord <- suppressMessages(extract_ordination(
    fit, level = level_label
  ))
  if (is.null(ord))
    cli::cli_abort("No {.code latent()} term at level {.val {level_label}}; nothing to plot.")

  L  <- ord$loadings
  Sc <- ord$scores
  if (is.null(rownames(L))) rownames(L) <- .gtmb_trait_names(fit)
  d  <- ncol(L)

  if (d == 1L) {
    ## 1D lollipop along x-axis, traits on x, points at y = 0.
    dat_l <- data.frame(
      trait   = rownames(L),
      loading = L[, 1L],
      stringsAsFactors = FALSE
    )
    dat_s <- data.frame(
      x = Sc[, 1L],
      y = 0,
      stringsAsFactors = FALSE
    )
    p <- ggplot2::ggplot() +
      ggplot2::geom_hline(yintercept = 0, colour = "grey80") +
      ggplot2::geom_point(data = dat_s,
                          ggplot2::aes(x = .data$x, y = .data$y),
                          colour = "grey50", alpha = 0.6) +
      ggplot2::geom_segment(
        data = dat_l,
        ggplot2::aes(x = .data$loading, xend = .data$loading,
                     y = 0, yend = 0.5 * sign(.data$loading) +
                       ifelse(.data$loading == 0, 0.3, 0)),
        colour = "firebrick", linewidth = 0.6
      ) +
      ggplot2::geom_point(
        data = dat_l,
        ggplot2::aes(x = .data$loading,
                     y = 0.5 * sign(.data$loading) +
                       ifelse(.data$loading == 0, 0.3, 0)),
        colour = "firebrick", size = 2
      ) +
      ggplot2::geom_text(
        data = dat_l,
        ggplot2::aes(x = .data$loading,
                     y = 0.5 * sign(.data$loading) +
                       ifelse(.data$loading == 0, 0.3, 0),
                     label = .data$trait),
        vjust = -0.5, size = 3.5
      ) +
      ggplot2::labs(x = "LV1", y = NULL,
                    title = paste0("Level ", level_label, ": 1D ordination")) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        axis.text.y  = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank()
      )
    return(p)
  }

  ## d >= 2: 2D biplot of the requested axis pair.
  if (length(axes) != 2L)
    cli::cli_abort("{.arg axes} must be length 2.")
  if (max(axes) > d)
    cli::cli_abort("Requested {.arg axes = c({axes[1L]}, {axes[2L]})} exceed d_{level_label} = {d}.")
  a1 <- axes[1L]; a2 <- axes[2L]

  dat_s <- data.frame(
    x = Sc[, a1],
    y = Sc[, a2],
    stringsAsFactors = FALSE
  )
  ## Scale loadings to the score range so arrows are visible alongside points.
  span <- max(abs(c(dat_s$x, dat_s$y)), na.rm = TRUE)
  loading_max <- max(abs(L[, c(a1, a2)]), 1e-9)
  sc <- 0.7 * span / loading_max
  dat_l <- data.frame(
    trait = rownames(L),
    x     = L[, a1] * sc,
    y     = L[, a2] * sc,
    stringsAsFactors = FALSE
  )

  ggplot2::ggplot() +
    ggplot2::geom_hline(yintercept = 0, colour = "grey80",
                        linetype = "dashed") +
    ggplot2::geom_vline(xintercept = 0, colour = "grey80",
                        linetype = "dashed") +
    ggplot2::geom_point(data = dat_s,
                        ggplot2::aes(x = .data$x, y = .data$y),
                        colour = "grey50", alpha = 0.5) +
    ggplot2::geom_segment(
      data = dat_l,
      ggplot2::aes(x = 0, y = 0, xend = .data$x, yend = .data$y),
      arrow = ggplot2::arrow(length = ggplot2::unit(0.2, "cm")),
      colour = "firebrick", linewidth = 0.6
    ) +
    ggplot2::geom_text(
      data = dat_l,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$trait),
      colour = "firebrick", vjust = -0.5, size = 3.5
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = paste0("LV", a1),
      y = paste0("LV", a2),
      title = paste0("Level ", level_label, ": ordination biplot")
    ) +
    ggplot2::theme_minimal()
}
