## dev/m3-pilot-report.R
##
## Design 66 power study -- RESULTS + ISSUES recording and the
## coverage/power VISUALISATION layer for the Phase-1 pilot.
##
## This file is the reporting companion to dev/m3-pilot-launch.R (the
## accumulate engine) and dev/power-pilot-run.R (the CLI sweep wrapper).
## It reads the ACCUMULATED per-cell results (the GHA `power-pilot-results`
## orphan-branch store + any local store), folds them into one tidy
## per-cell table that carries BOTH the coverage/power numbers AND the
## issue columns (failed fits, non-PD Hessian, convergence failure rates,
## a flag), draws the drmTMB-style coverage-vs-nominal forest + per-family
## power curves, and writes a durable markdown + RDS record with an
## explicit ISSUES section.
##
## drmTMB reuse note: drmTMB exposes no EXPORTED coverage/power simulation
## plotter (its NAMESPACE exports only plot_corpairs / plot_parameter_surface,
## which are parameter/correlation plots). The "really nice" coverage/power
## grammar lives INLINE in drmTMB's vignettes/simulation-plot-grammar.Rmd
## (faint replicate-block dots + aggregate proportion points + 95% binomial
## MCSE interval bars + a dotted reference line at the nominal target,
## faceted by surface, on a colour-blind-safe Okabe-Ito palette and a
## shared theme_sim_grammar()). Because there is nothing to source, the
## STYLE is replicated here, faithfully, in self-contained pilot_plot()
## helpers. See PR body for the exact path/grammar.
##
## This file is in `.Rbuildignore` (dev/) -- NOT shipped with the package.
##
## Usage (interactive):
##   source("dev/m3-grid.R")          # m3_summarise() + harness
##   source("dev/m3-pilot-report.R")
##   df  <- pilot_collect(results_dirs = c("dev/m3-pilot-results"))
##   ggs <- pilot_plot(df)            # writes PNGs to dev/m3-pilot-figures/
##   pilot_record(df)                 # writes dev/m3-pilot-summary.{md,rds}
##
## Usage (CLI, for the GHA summary job -- prints one ISSUES line to stdout):
##   Rscript dev/m3-pilot-report.R --emit-issues \
##     --results-dir=dev/m3-pilot-results

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

## ---- Guard: the harness must be sourced for m3_summarise() ------------

## pilot_collect() reuses m3_summarise() (the validated per-cell coverage
## aggregator) rather than re-deriving coverage. Source dev/m3-grid.R first.
if (!exists("m3_summarise", mode = "function")) {
  ## Best-effort auto-source when run as a script from the repo root.
  .m3_grid <- file.path("dev", "m3-grid.R")
  if (file.exists(.m3_grid)) {
    source(.m3_grid)
  }
}
if (!exists("pilot_grid", mode = "function")) {
  .m3_launch <- file.path("dev", "m3-pilot-launch.R")
  if (file.exists(.m3_launch) && exists("m3_run_cell", mode = "function")) {
    source(.m3_launch)
  }
}

## Default output locations (all under dev/, build-ignored).
PILOT_FIGURE_DIR_DEFAULT <- "dev/m3-pilot-figures"
PILOT_SUMMARY_MD_DEFAULT <- "dev/m3-pilot-summary.md"
PILOT_SUMMARY_RDS_DEFAULT <- "dev/m3-pilot-summary.rds"

## Gate thresholds (Design 66 locked: report BOTH the 94% audit gate and
## the stricter 95% gate). Mirrors pilot_accum_status().
PILOT_GATE_94 <- 0.94
PILOT_GATE_95 <- 0.95

## Issue-flag thresholds: a cell is flagged when its fit-failure,
## non-PD-Hessian, or bootstrap-CI failure rate clears these. Tunable.
PILOT_FLAG_FIT_FAIL_RATE <- 0.10
PILOT_FLAG_NONPD_RATE <- 0.10
PILOT_FLAG_CONV_FAIL_RATE <- 0.10

## =====================================================================
## pilot_collect(): read + fold ALL accumulated per-cell results
## =====================================================================

## Read every per-cell `<cell>.rds` (the long per-replicate grid written
## by m3_run_cell / the accumulate engine) from each directory in
## `results_dirs`, COMBINE same-cell grids across directories (so the
## GHA-branch store and a local store add up), DEDUP replicates by their
## true per-draw key (`rep_seed`, falling back to `rep`), and reduce each
## combined cell to ONE tidy row carrying:
##   - cell metadata: cell_id, family (label), harness_family, d, n_units,
##     signal, lambda_scale  (joined from pilot_grid() when available)
##   - accumulated reps: n_sim (distinct draws kept after dedup)
##   - coverage: coverage_primary (from m3_summarise), and the both-gate
##     pass flags passes_94 / passes_95 + primary_gate_status
##   - power: power (CI-excludes-zero rejection rate on the primary
##     Sigma_unit_diag target -- a Type-I proxy at signal == 0, a power
##     proxy at signal > 0; see note below)
##   - ISSUES: n_failed_fits, fit_failure_rate, n_nonPD, nonpd_rate,
##     n_conv_fail, conv_failure_rate, n_boot_failed, boot_fail_rate, flag
##
## Returns a tidy data.frame, one row per cell, ordered family/d/n/signal.
## Cells that exist only in an index (no `.rds` yet) are NOT invented here;
## this function reports cells with stored replicate data.
pilot_collect <- function(
  results_dirs = "dev/m3-pilot-results",
  index_file = "pilot-index.rds",
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  stopifnot(length(results_dirs) >= 1L)
  if (!exists("m3_summarise", mode = "function")) {
    stop(
      "pilot_collect() needs m3_summarise(); source(\"dev/m3-grid.R\") first."
    )
  }
  results_dirs <- results_dirs[dir.exists(results_dirs)]
  if (!length(results_dirs)) {
    warning("pilot_collect(): no existing results_dirs; returning empty table.")
    return(pilot_collect_empty())
  }

  ## ---- gather per-cell grids keyed by cell id, across all dirs ----
  grids <- list() # cell_id -> combined long grid
  for (dir in results_dirs) {
    files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
    files <- files[basename(files) != index_file]
    for (f in files) {
      cid <- sub("\\.rds$", "", basename(f))
      g <- tryCatch(readRDS(f), error = function(e) NULL)
      if (is.null(g) || !is.data.frame(g) || nrow(g) == 0L) {
        next
      }
      grids[[cid]] <- pilot_rbind_cell(grids[[cid]], g)
    }
  }
  if (!length(grids)) {
    warning("pilot_collect(): no per-cell .rds found; returning empty table.")
    return(pilot_collect_empty())
  }

  ## ---- grid metadata (family/d/n/signal) when the harness is loaded ----
  meta <- if (exists("pilot_grid", mode = "function")) {
    pilot_grid()
  } else {
    NULL
  }

  rows <- lapply(names(grids), function(cid) {
    pilot_collect_cell(grids[[cid]], cid, meta, gate_94, gate_95)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  ord <- order(out$family, out$d, out$n_units, out$signal, na.last = TRUE)
  out[ord, , drop = FALSE]
}

## Combine two long per-rep grids for the SAME cell, then drop duplicate
## draws so reps summed across stores are not double-counted. The unique
## draw key is rep_seed (the true per-draw seed); fall back to rep, then
## to a row-identity de-dup. Renumbers `rep` to stay globally unique so
## m3_summarise()'s per-rep grouping is correct.
pilot_rbind_cell <- function(prev, new) {
  if (is.null(prev)) {
    combined <- new
  } else {
    common <- intersect(names(prev), names(new))
    combined <- rbind(prev[, common, drop = FALSE], new[, common, drop = FALSE])
  }
  ## Drop duplicate draws.
  if ("rep_seed" %in% names(combined)) {
    ## Keep all rows of each distinct (rep_seed) draw; a draw is a block of
    ## trait rows sharing one rep_seed. De-dup whole draws, not rows: a
    ## draw is duplicated if its rep_seed already appeared with identical
    ## per-row content. Use rep_seed + trait_id + target as the row key.
    key_cols <- intersect(
      c("rep_seed", "trait_id", "target", "ci_method"),
      names(combined)
    )
    combined <- combined[!duplicated(combined[, key_cols, drop = FALSE]), ]
    ## Renumber rep contiguously within each distinct rep_seed so grouping
    ## by `rep` matches grouping by draw.
    combined$rep <- match(combined$rep_seed, unique(combined$rep_seed))
  } else if ("rep" %in% names(combined)) {
    key_cols <- intersect(c("rep", "trait_id", "target", "ci_method"), names(combined))
    combined <- combined[!duplicated(combined[, key_cols, drop = FALSE]), ]
  }
  combined
}

## Reduce ONE combined long grid to a single tidy per-cell row.
pilot_collect_cell <- function(g, cid, meta, gate_94, gate_95) {
  ## --- coverage via the validated aggregator (primary target row) ---
  cov_p <- NA_real_
  gate_status <- NA_character_
  pd_rate_summ <- NA_real_
  boot_fail_rate <- NA_real_
  s <- tryCatch(m3_summarise(g), error = function(e) NULL)
  if (!is.null(s)) {
    prim <- s[!is.na(s$coverage_primary), , drop = FALSE]
    if (nrow(prim)) {
      cov_p <- prim$coverage_primary[1]
      gate_status <- prim$primary_gate_status[1] %||% NA_character_
      if ("pd_hessian_rate" %in% names(prim)) {
        pd_rate_summ <- prim$pd_hessian_rate[1]
      }
      if ("boot_fail_rate" %in% names(prim)) {
        boot_fail_rate <- prim$boot_fail_rate[1]
      }
    }
  }

  ## --- per-rep issue + power accounting from the raw grid ---
  ## "Primary" rows: the rotation-invariant Sigma_unit_diag / bootstrap
  ## target -- the estimand the coverage claim is about.
  prim_rows <- pilot_primary_rows(g)
  rep_key <- if ("rep_seed" %in% names(g)) "rep_seed" else "rep"

  ## n_sim = distinct accumulated draws.
  n_sim <- if (rep_key %in% names(g)) {
    length(unique(g[[rep_key]]))
  } else {
    NA_integer_
  }

  ## Fit failures: a draw is a failed fit if its rows say so. Use
  ## fit_converged (preferred) else converged; FALSE => failed.
  fit_ok_col <- if ("fit_converged" %in% names(g)) {
    "fit_converged"
  } else if ("converged" %in% names(g)) {
    "converged"
  } else {
    NA_character_
  }
  n_failed_fits <- NA_integer_
  fit_failure_rate <- NA_real_
  if (!is.na(fit_ok_col) && rep_key %in% names(g)) {
    per_draw_ok <- tapply(g[[fit_ok_col]], g[[rep_key]], function(x) all(x %in% TRUE))
    n_failed_fits <- sum(!per_draw_ok)
    fit_failure_rate <- mean(!per_draw_ok)
  }

  ## Non-PD Hessian: per-draw pd_hessian flag (from fit health). A draw
  ## is non-PD if its first row's pd_hessian is not TRUE.
  n_nonpd <- NA_integer_
  nonpd_rate <- NA_real_
  if ("pd_hessian" %in% names(g) && rep_key %in% names(g)) {
    per_draw_pd <- tapply(g$pd_hessian, g[[rep_key]], function(x) any(x %in% TRUE))
    n_nonpd <- sum(!(per_draw_pd %in% TRUE))
    nonpd_rate <- mean(!(per_draw_pd %in% TRUE))
  } else if (!is.na(pd_rate_summ)) {
    nonpd_rate <- 1 - pd_rate_summ
  }

  ## Convergence failure rate: the optimiser convergence code != 0 on a
  ## draw (distinct from fit_converged, which can also fold in CI health).
  n_conv_fail <- NA_integer_
  conv_failure_rate <- NA_real_
  if ("fit_convergence_code" %in% names(g) && rep_key %in% names(g)) {
    per_draw_conv <- tapply(
      g$fit_convergence_code,
      g[[rep_key]],
      function(x) {
        x <- x[!is.na(x)]
        if (!length(x)) NA else all(x == 0L)
      }
    )
    n_conv_fail <- sum(per_draw_conv %in% FALSE)
    conv_failure_rate <- mean(per_draw_conv %in% FALSE)
  } else if (!is.na(fit_failure_rate)) {
    ## Fall back to the fit-failure rate as the convergence proxy.
    conv_failure_rate <- fit_failure_rate
    n_conv_fail <- n_failed_fits
  }

  ## Bootstrap-CI failure: fraction of attempted boot reps that failed
  ## (already aggregated by m3_summarise as boot_fail_rate). Keep counts.
  n_boot_failed <- NA_integer_
  if ("n_boot_failed" %in% names(prim_rows) && nrow(prim_rows)) {
    nb <- suppressWarnings(max(prim_rows$n_boot_failed, na.rm = TRUE))
    if (is.finite(nb)) n_boot_failed <- as.integer(nb)
  }

  ## --- power / rejection rate on the primary target ---
  ## Power here is the rejection rate of H0: Sigma_unit_diag = 0, i.e. the
  ## fraction of (converged, CI-available) draws whose primary CI EXCLUDES
  ## zero. At signal == 0 (the null cell) this is the empirical Type-I
  ## error proxy; at signal > 0 it is the empirical power. (Design 66
  ## sec. 9 defers a full reject-rate rule to Phase 2; this is the natural
  ## CI-based proxy computable from the stored intervals.)
  power <- pilot_rejection_rate(prim_rows)

  ## --- flag ---
  flag <- pilot_make_flag(
    fit_failure_rate, nonpd_rate, conv_failure_rate, boot_fail_rate
  )

  ## --- metadata join ---
  m <- if (!is.null(meta)) meta[meta$cell_id == cid, , drop = FALSE] else NULL
  fam_label <- if (!is.null(m) && nrow(m)) {
    m$family_label[1]
  } else if ("family" %in% names(g)) {
    g$family[1]
  } else {
    NA_character_
  }

  data.frame(
    cell_id = cid,
    family = fam_label,
    harness_family = if (!is.null(m) && nrow(m)) m$harness_family[1]
      else (if ("family" %in% names(g)) g$family[1] else NA_character_),
    d = if (!is.null(m) && nrow(m)) m$d[1]
      else (if ("d" %in% names(g)) g$d[1] else NA_integer_),
    n_units = if (!is.null(m) && nrow(m)) m$n_units[1]
      else (if ("n_units" %in% names(g)) g$n_units[1] else NA_integer_),
    signal = if (!is.null(m) && nrow(m)) m$signal[1] else NA_real_,
    lambda_scale = if (!is.null(m) && nrow(m)) m$lambda_scale[1]
      else (if ("lambda_scale" %in% names(g)) g$lambda_scale[1] else NA_real_),
    n_sim = as.integer(n_sim),
    coverage_primary = cov_p,
    passes_94 = if (is.na(cov_p)) NA else cov_p >= gate_94,
    passes_95 = if (is.na(cov_p)) NA else cov_p >= gate_95,
    primary_gate_status = gate_status,
    power = power,
    n_failed_fits = as.integer(n_failed_fits),
    fit_failure_rate = fit_failure_rate,
    n_nonPD = as.integer(n_nonpd),
    nonpd_rate = nonpd_rate,
    n_conv_fail = as.integer(n_conv_fail),
    conv_failure_rate = conv_failure_rate,
    n_boot_failed = as.integer(n_boot_failed),
    boot_fail_rate = boot_fail_rate,
    flag = flag,
    stringsAsFactors = FALSE
  )
}

## Subset of a long grid to the PRIMARY target rows (the rotation-
## invariant Sigma_unit_diag estimand under bootstrap CIs). Falls back to
## all rows if those columns are absent (legacy artifacts).
pilot_primary_rows <- function(g) {
  if (all(c("target", "ci_method") %in% names(g))) {
    sel <- g$target == "Sigma_unit_diag" & g$ci_method == "bootstrap"
    if (any(sel)) {
      return(g[sel, , drop = FALSE])
    }
  }
  g
}

## Rejection rate = fraction of converged, CI-available primary draws
## whose CI excludes 0. NA when no usable interval rows.
pilot_rejection_rate <- function(prim_rows) {
  if (is.null(prim_rows) || !nrow(prim_rows)) {
    return(NA_real_)
  }
  ok <- rep(TRUE, nrow(prim_rows))
  if ("fit_converged" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$fit_converged %in% TRUE)
  }
  if ("ci_available" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$ci_available %in% TRUE)
  }
  lo <- prim_rows$ci_lo
  hi <- prim_rows$ci_hi
  ok <- ok & is.finite(lo) & is.finite(hi)
  if (!any(ok)) {
    return(NA_real_)
  }
  lo <- lo[ok]
  hi <- hi[ok]
  ## Reject H0: theta = 0 when 0 is OUTSIDE [lo, hi].
  mean(!(lo <= 0 & 0 <= hi))
}

## Build the per-cell issue flag string ("" when nothing tripped).
pilot_make_flag <- function(fit_fail, nonpd, conv_fail, boot_fail) {
  bits <- character(0)
  if (!is.na(fit_fail) && fit_fail >= PILOT_FLAG_FIT_FAIL_RATE) {
    bits <- c(bits, sprintf("fit-fail %.0f%%", 100 * fit_fail))
  }
  if (!is.na(nonpd) && nonpd >= PILOT_FLAG_NONPD_RATE) {
    bits <- c(bits, sprintf("nonPD %.0f%%", 100 * nonpd))
  }
  if (!is.na(conv_fail) && conv_fail >= PILOT_FLAG_CONV_FAIL_RATE) {
    bits <- c(bits, sprintf("conv-fail %.0f%%", 100 * conv_fail))
  }
  if (!is.na(boot_fail) && boot_fail >= PILOT_FLAG_FIT_FAIL_RATE) {
    bits <- c(bits, sprintf("boot-fail %.0f%%", 100 * boot_fail))
  }
  paste(bits, collapse = "; ")
}

pilot_collect_empty <- function() {
  data.frame(
    cell_id = character(0),
    family = character(0),
    harness_family = character(0),
    d = integer(0),
    n_units = integer(0),
    signal = numeric(0),
    lambda_scale = numeric(0),
    n_sim = integer(0),
    coverage_primary = numeric(0),
    passes_94 = logical(0),
    passes_95 = logical(0),
    primary_gate_status = character(0),
    power = numeric(0),
    n_failed_fits = integer(0),
    fit_failure_rate = numeric(0),
    n_nonPD = integer(0),
    nonpd_rate = numeric(0),
    n_conv_fail = integer(0),
    conv_failure_rate = numeric(0),
    n_boot_failed = integer(0),
    boot_fail_rate = numeric(0),
    flag = character(0),
    stringsAsFactors = FALSE
  )
}

## =====================================================================
## pilot_plot(): the drmTMB-style coverage/power figures
## =====================================================================

## Okabe-Ito colour-blind-safe palette by family, mirroring drmTMB's
## simulation-plot-grammar surface palette.
PILOT_FAMILY_PALETTE <- c(
  gaussian = "#0072B2",
  nbinom2 = "#D55E00",
  binomial_probit = "#009E73",
  ordinal_probit = "#CC79A7"
)

## Shared theme, replicating drmTMB's theme_sim_grammar().
pilot_theme_grammar <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey30", lineheight = 1.05),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      plot.margin = ggplot2::margin(6, 10, 12, 6)
    )
}

## Build BOTH pilot figures and (by default) save them as PNGs:
##   1. coverage-vs-nominal forest: per cell, coverage_primary point with a
##      95% binomial MCSE bar, faceted by family, with dotted reference
##      lines at the 94% and 95% gates (the drmTMB coverage grammar).
##   2. power curve: rejection rate vs signal {0, 0.2, 0.5}, one line per
##      family, faceted by (n_units x d), with the signal == 0 point being
##      the Type-I proxy.
## Returns a named list of ggplot objects (invisibly when saving).
pilot_plot <- function(
  df,
  figure_dir = PILOT_FIGURE_DIR_DEFAULT,
  save = TRUE,
  width = 9,
  height = 6,
  dpi = 150
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("pilot_plot() requires the 'ggplot2' package.")
  }
  if (!nrow(df)) {
    stop("pilot_plot(): empty data.frame; run pilot_collect() first.")
  }
  plots <- list(
    coverage = pilot_plot_coverage(df),
    power = pilot_plot_power(df)
  )
  if (isTRUE(save)) {
    if (!dir.exists(figure_dir)) {
      dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
    }
    paths <- c(
      coverage = file.path(figure_dir, "pilot-coverage-vs-nominal.png"),
      power = file.path(figure_dir, "pilot-power-curve.png")
    )
    ggplot2::ggsave(
      paths[["coverage"]], plots$coverage,
      width = width, height = height, dpi = dpi
    )
    ggplot2::ggsave(
      paths[["power"]], plots$power,
      width = width, height = height, dpi = dpi
    )
    attr(plots, "paths") <- paths
    cat(sprintf("[pilot] wrote figures:\n  %s\n", paste(paths, collapse = "\n  ")))
    return(invisible(plots))
  }
  plots
}

## Coverage-vs-nominal forest (drmTMB coverage grammar).
pilot_plot_coverage <- function(df) {
  d <- df[!is.na(df$coverage_primary), , drop = FALSE]
  if (!nrow(d)) {
    return(pilot_empty_plot("No coverage_primary values yet"))
  }
  ## Binomial MCSE on the coverage proportion (n = accumulated reps).
  n <- pmax(d$n_sim, 1L)
  d$mcse <- sqrt(d$coverage_primary * (1 - d$coverage_primary) / n)
  d$lower <- pmax(0, d$coverage_primary - 1.96 * d$mcse)
  d$upper <- pmin(1, d$coverage_primary + 1.96 * d$mcse)
  ## A readable per-cell y label (n / d / signal); family is the facet.
  d$cell_label <- sprintf("n%d d%d sig%.1f", d$n_units, d$d, d$signal)
  d$cell_label <- factor(d$cell_label, levels = rev(unique(d$cell_label)))
  d$family <- factor(d$family, levels = names(PILOT_FAMILY_PALETTE))

  gate_lines <- data.frame(
    gate = c("94% audit gate", "95% gate"),
    x = c(PILOT_GATE_94, PILOT_GATE_95)
  )

  ggplot2::ggplot(
    d,
    ggplot2::aes(x = .data$coverage_primary, y = .data$cell_label, colour = .data$family)
  ) +
    ggplot2::geom_vline(
      data = gate_lines,
      ggplot2::aes(xintercept = .data$x, linetype = .data$gate),
      colour = "grey45",
      inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      ggplot2::aes(x = .data$lower, xend = .data$upper, yend = .data$cell_label),
      linewidth = 0.45,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(size = 2.2, na.rm = TRUE) +
    ggplot2::facet_wrap(~family, scales = "free_y") +
    ggplot2::scale_colour_manual(
      values = PILOT_FAMILY_PALETTE, drop = FALSE, guide = "none"
    ) +
    ggplot2::scale_linetype_manual(values = c(
      "94% audit gate" = "dotted",
      "95% gate" = "dashed"
    )) +
    ggplot2::coord_cartesian(xlim = c(min(0.80, min(d$lower)), 1)) +
    ggplot2::labs(
      title = "Interval coverage vs nominal gates need Monte Carlo uncertainty",
      subtitle = paste(
        "Points: accumulated coverage_primary (Sigma_unit_diag, bootstrap CI);",
        "bars: 95% binomial MCSE. Lines: 94%/95% gates."
      ),
      x = "Empirical coverage",
      y = NULL,
      linetype = NULL
    ) +
    pilot_theme_grammar()
}

## Power curve vs signal, one line per family, faceted by (n_units, d).
pilot_plot_power <- function(df) {
  d <- df[!is.na(df$power) & !is.na(df$signal), , drop = FALSE]
  if (!nrow(d)) {
    return(pilot_empty_plot("No power / rejection-rate values yet"))
  }
  d$family <- factor(d$family, levels = names(PILOT_FAMILY_PALETTE))
  d$panel <- sprintf("n_units %d, d %d", d$n_units, d$d)

  ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$signal, y = .data$power,
      colour = .data$family, group = .data$family
    )
  ) +
    ## A faint marker at signal == 0 (the Type-I proxy reference).
    ggplot2::geom_vline(
      xintercept = 0, linetype = "dotted", colour = "grey70"
    ) +
    ggplot2::geom_line(linewidth = 0.6, na.rm = TRUE) +
    ggplot2::geom_point(size = 2.1, na.rm = TRUE) +
    ggplot2::facet_wrap(~panel) +
    ggplot2::scale_colour_manual(values = PILOT_FAMILY_PALETTE, drop = FALSE) +
    ggplot2::scale_x_continuous(breaks = c(0, 0.2, 0.5)) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(
      title = "Rejection rate vs signal (power curve; signal 0 = Type-I proxy)",
      subtitle = paste(
        "Fraction of primary CIs excluding zero.",
        "At signal = 0 this is the empirical Type-I error."
      ),
      x = "Signal (between-unit variance share)",
      y = "Rejection rate",
      colour = "Family"
    ) +
    pilot_theme_grammar()
}

pilot_empty_plot <- function(label) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = label) +
    ggplot2::theme_void()
}

## =====================================================================
## pilot_record(): durable RESULTS + ISSUES record (markdown + RDS)
## =====================================================================

## Write a durable record of the pilot to `md_path` (an ASCII markdown
## report with a results table AND an explicit ISSUES section) and
## `rds_path` (the tidy data.frame, for programmatic reuse). Returns the
## paths invisibly. The ISSUES section lists every flagged cell with its
## failure / non-PD / convergence rates, plus any stuck cells (n_sim == 0)
## and cross-cell anomalies (e.g. coverage far from nominal).
pilot_record <- function(
  df,
  md_path = PILOT_SUMMARY_MD_DEFAULT,
  rds_path = PILOT_SUMMARY_RDS_DEFAULT,
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  saveRDS(df, rds_path)
  lines <- pilot_record_lines(df, gate_94, gate_95)
  writeLines(lines, md_path)
  cat(sprintf(
    "[pilot] wrote record:\n  %s\n  %s\n", md_path, rds_path
  ))
  invisible(c(md = md_path, rds = rds_path))
}

## Build the markdown record as a character vector (ASCII only). Exposed
## so the GHA summary job can embed the same issues block.
pilot_record_lines <- function(df, gate_94 = PILOT_GATE_94, gate_95 = PILOT_GATE_95) {
  fmt <- function(x, digits = 3) {
    ifelse(is.na(x), "-", formatC(x, format = "f", digits = digits))
  }
  pct <- function(x) ifelse(is.na(x), "-", sprintf("%.0f%%", 100 * x))
  ylab <- function(x) ifelse(is.na(x), "-", ifelse(x, "Y", "n"))

  n_cells <- nrow(df)
  n_reps <- sum(df$n_sim, na.rm = TRUE)
  cov_done <- df[!is.na(df$coverage_primary), , drop = FALSE]
  cov_signal <- cov_done[cov_done$signal > 0 & !is.na(cov_done$signal), , drop = FALSE]

  lines <- c(
    "# Design 66 power pilot -- results + issues record",
    "",
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
    "",
    "## Summary",
    "",
    sprintf("- Cells with stored data: %d", n_cells),
    sprintf("- Replicates accumulated (sum n_sim): %d", n_reps),
    if (nrow(cov_signal)) {
      sprintf(
        "- Coverage (signal>0, %d cells): mean=%s  >=94%%: %d/%d  >=95%%: %d/%d",
        nrow(cov_signal),
        fmt(mean(cov_signal$coverage_primary)),
        sum(cov_signal$passes_94, na.rm = TRUE), nrow(cov_signal),
        sum(cov_signal$passes_95, na.rm = TRUE), nrow(cov_signal)
      )
    } else {
      "- Coverage (signal>0): <no cells with coverage yet>"
    },
    ""
  )

  ## ---- results table ----
  lines <- c(
    lines,
    "## Results (per cell)",
    "",
    paste(
      "| cell | family | d | n | signal | n_sim | coverage |",
      ">=94% | >=95% | power | fit-fail | nonPD | conv-fail |"
    ),
    paste(
      "|------|--------|--:|--:|-------:|------:|---------:|",
      ":---:|:---:|------:|--------:|------:|----------:|"
    )
  )
  for (i in seq_len(n_cells)) {
    lines <- c(lines, sprintf(
      "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
      df$cell_id[i], df$family[i],
      ifelse(is.na(df$d[i]), "-", as.character(df$d[i])),
      ifelse(is.na(df$n_units[i]), "-", as.character(df$n_units[i])),
      fmt(df$signal[i], 1), as.character(df$n_sim[i]),
      fmt(df$coverage_primary[i]),
      ylab(df$passes_94[i]), ylab(df$passes_95[i]),
      fmt(df$power[i]),
      pct(df$fit_failure_rate[i]), pct(df$nonpd_rate[i]),
      pct(df$conv_failure_rate[i])
    ))
  }
  lines <- c(lines, "")

  ## ---- ISSUES section ----
  lines <- c(lines, pilot_issue_lines(df))
  lines
}

## The ISSUES block as a character vector (ASCII). Reused by the record
## and by the GHA summary one-liner (pilot_issue_oneline()).
pilot_issue_lines <- function(df) {
  flagged <- df[nzchar(df$flag %||% ""), , drop = FALSE]
  flagged <- flagged[!is.na(flagged$cell_id), , drop = FALSE]
  stuck <- df[df$n_sim %in% 0L | is.na(df$n_sim), , drop = FALSE]
  ## Coverage anomalies: |coverage - 0.95| large despite enough reps.
  anom <- df[
    !is.na(df$coverage_primary) &
      df$n_sim >= 50L &
      abs(df$coverage_primary - 0.95) > 0.10,
    ,
    drop = FALSE
  ]

  out <- c("## ISSUES", "")
  if (!nrow(flagged) && !nrow(stuck) && !nrow(anom)) {
    out <- c(out, "No flagged cells: no fit/non-PD/convergence rate above threshold,",
             "no stuck cells, no large coverage anomalies.", "")
    return(out)
  }

  if (nrow(flagged)) {
    out <- c(out, sprintf(
      "### Cells with high failure / non-PD / convergence rates (%d)",
      nrow(flagged)
    ), "")
    for (i in seq_len(nrow(flagged))) {
      out <- c(out, sprintf(
        "- %s (family=%s, signal=%.1f, n_sim=%d): %s",
        flagged$cell_id[i], flagged$family[i], flagged$signal[i],
        flagged$n_sim[i], flagged$flag[i]
      ))
    }
    out <- c(out, "")
  }
  if (nrow(stuck)) {
    out <- c(out, sprintf("### Stuck cells (no accumulated reps) (%d)", nrow(stuck)), "")
    for (i in seq_len(nrow(stuck))) {
      out <- c(out, sprintf("- %s (family=%s, signal=%.1f)",
                            stuck$cell_id[i], stuck$family[i], stuck$signal[i]))
    }
    out <- c(out, "")
  }
  if (nrow(anom)) {
    out <- c(out, sprintf(
      "### Coverage anomalies (|coverage - 0.95| > 0.10, n_sim >= 50) (%d)",
      nrow(anom)
    ), "")
    for (i in seq_len(nrow(anom))) {
      out <- c(out, sprintf(
        "- %s: coverage=%.3f (n_sim=%d)",
        anom$cell_id[i], anom$coverage_primary[i], anom$n_sim[i]
      ))
    }
    out <- c(out, "")
  }
  out
}

## One-line ASCII issues string for the GHA #340 board, e.g.:
##   "failures: nbinom2-d2-n50-sig0.0 conv-fail 22%; <cell> nonPD 14% (2 cells flagged)"
## Returns "none" when nothing is flagged.
pilot_issue_oneline <- function(df, max_cells = 4L) {
  flagged <- df[nzchar(df$flag %||% ""), , drop = FALSE]
  flagged <- flagged[!is.na(flagged$cell_id), , drop = FALSE]
  if (!nrow(flagged)) {
    return("none")
  }
  show <- utils::head(flagged, max_cells)
  bits <- sprintf("%s %s", show$cell_id, show$flag)
  extra <- if (nrow(flagged) > max_cells) {
    sprintf(" (+%d more)", nrow(flagged) - max_cells)
  } else {
    ""
  }
  sprintf(
    "%s (%d cell%s flagged)%s",
    paste(bits, collapse = "; "),
    nrow(flagged),
    if (nrow(flagged) == 1L) "" else "s",
    extra
  )
}

## =====================================================================
## CLI: print the one-line issues string (for the GHA summary job)
## =====================================================================

if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  arg_value <- function(flag, default = NULL) {
    hit <- grep(paste0("^", flag, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^", flag, "="), "", hit[1]) else default
  }
  if ("--emit-issues" %in% args) {
    rdirs <- strsplit(
      arg_value("--results-dir", "dev/m3-pilot-results"), ",", fixed = TRUE
    )[[1]]
    df <- tryCatch(
      pilot_collect(results_dirs = rdirs),
      error = function(e) {
        ## Fail-soft: never break the summary job on a report error.
        cat("none\n")
        quit(save = "no", status = 0L)
      }
    )
    cat(pilot_issue_oneline(df), "\n", sep = "")
    quit(save = "no", status = 0L)
  }
}
