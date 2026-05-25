## One-call user-facing diagnostic for a fitted gllvmTMB model.
## Wraps sanity_multi(), checks rotation identifiability, reports the
## key biological summaries, and prints actionable hints for any WARN
## or FAIL signal. Designed to be the first call a user makes after
## fitting.

.gllvmTMB_build_fit_health <- function(object) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }

  grad <- tryCatch(object$tmb_obj$gr(object$opt$par), error = function(e) {
    NA_real_
  })
  se <- if (!is.null(object$sd_report)) {
    tryCatch(
      suppressWarnings(summary(object$sd_report, "fixed"))[, "Std. Error"],
      error = function(e) NA_real_
    )
  } else {
    NA_real_
  }
  max_se <- if (length(se) == 0L || all(is.na(se))) {
    NA_real_
  } else {
    max(se, na.rm = TRUE)
  }
  restart_history <- object$restart_history %||% data.frame()
  selected_restart <- if (
    nrow(restart_history) > 0L &&
      "selected" %in% names(restart_history) &&
      any(restart_history$selected)
  ) {
    restart_history$restart[which(restart_history$selected)[1L]]
  } else {
    NA_integer_
  }

  list(
    optimizer = if (nrow(restart_history) > 0L) {
      restart_history$optimizer[which.max(restart_history$selected)]
    } else {
      NA_character_
    },
    convergence = object$opt$convergence %||% NA_integer_,
    message = object$opt$message %||% "",
    objective = object$opt$objective %||% NA_real_,
    max_gradient = if (length(grad) == 0L || all(is.na(grad))) {
      NA_real_
    } else {
      max(abs(grad), na.rm = TRUE)
    },
    pd_hessian = if (
      !is.null(object$sd_report) &&
        !is.null(object$sd_report$pdHess)
    ) {
      isTRUE(object$sd_report$pdHess)
    } else {
      NA
    },
    sdreport_ok = !is.null(object$sd_report),
    sdreport_error = object$sdreport_error %||% NA_character_,
    max_fixed_se = max_se,
    boundary_flags = .gllvmTMB_boundary_flags(object),
    start_provenance = object$start_provenance %||% list(),
    selected_restart = selected_restart
  )
}

.gllvmTMB_boundary_flags <- function(
  object,
  loading_thresh = 1e-3,
  sd_thresh = 1e-4
) {
  flags <- character(0)
  rep <- object$report
  if (isTRUE(object$use$rr_B) && !is.null(rep$Lambda_B)) {
    diag_B <- diag(rep$Lambda_B[
      seq_len(object$d_B),
      seq_len(object$d_B),
      drop = FALSE
    ])
    if (any(abs(diag_B) < loading_thresh)) {
      flags <- c(flags, "near_zero_B_loading")
    }
  }
  if (isTRUE(object$use$rr_W) && !is.null(rep$Lambda_W)) {
    diag_W <- diag(rep$Lambda_W[
      seq_len(object$d_W),
      seq_len(object$d_W),
      drop = FALSE
    ])
    if (any(abs(diag_W) < loading_thresh)) {
      flags <- c(flags, "near_zero_W_loading")
    }
  }
  for (nm in intersect(
    c(
      "sd_B",
      "sd_W",
      "sd_phy",
      "sd_phy_diag",
      "sd_spde"
    ),
    names(rep)
  )) {
    val <- as.numeric(rep[[nm]])
    val <- val[is.finite(val)]
    if (length(val) > 0L && any(val < sd_thresh)) {
      flags <- c(flags, paste0("near_zero_", nm))
    }
  }
  unique(flags)
}

.gllvmTMB_check_row <- function(
  component,
  status,
  value = NA_character_,
  threshold = NA_character_,
  message = "",
  action = ""
) {
  data.frame(
    component = component,
    status = status,
    value = as.character(value),
    threshold = as.character(threshold),
    message = message,
    action = action,
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_hessian_rank <- function(object, tol = 1e-8) {
  cov_fixed <- tryCatch(object$sd_report$cov.fixed, error = function(e) NULL)
  if (is.null(cov_fixed) || length(cov_fixed) == 0L) {
    return(list(rank = NA_integer_, dimension = NA_integer_))
  }
  cov_fixed <- as.matrix(cov_fixed)
  if (nrow(cov_fixed) == 0L || ncol(cov_fixed) == 0L) {
    return(list(rank = NA_integer_, dimension = NA_integer_))
  }
  list(
    rank = qr(cov_fixed, tol = tol)$rank,
    dimension = ncol(cov_fixed)
  )
}

.gllvmTMB_report_matrix <- function(object, name) {
  x <- object$report[[name]]
  if (is.null(x) || length(x) == 0L) {
    return(NULL)
  }
  x <- as.matrix(x)
  if (nrow(x) == 0L || ncol(x) == 0L) {
    return(NULL)
  }
  x
}

.gllvmTMB_latent_specs <- function(object) {
  specs <- list(
    list(level = "unit", advice = "B", lambda = "Lambda_B"),
    list(level = "unit_obs", advice = "W", lambda = "Lambda_W"),
    list(level = "phylo", advice = "phy", lambda = "Lambda_phy"),
    list(level = "spatial", advice = "spde", lambda = "Lambda_spde")
  )
  out <- list()
  for (spec in specs) {
    L <- .gllvmTMB_report_matrix(object, spec$lambda)
    if (is.null(L)) {
      next
    }
    spec$matrix <- L
    out[[length(out) + 1L]] <- spec
  }
  out
}

.gllvmTMB_axis_summary <- function(L) {
  energy <- colSums(L^2)
  total <- sum(energy)
  axis_share <- if (is.finite(total) && total > 0) {
    energy / total
  } else {
    rep(NA_real_, ncol(L))
  }
  trait_energy <- rowSums(L^2)
  dominance <- rep(NA_real_, nrow(L))
  has_signal <- is.finite(trait_energy) & trait_energy > 0
  if (any(has_signal)) {
    dominance[has_signal] <-
      apply(L[has_signal, , drop = FALSE]^2, 1L, max) /
      trait_energy[has_signal]
  }
  list(
    axis_share = axis_share,
    min_axis_share = if (all(is.na(axis_share))) {
      NA_real_
    } else {
      min(axis_share, na.rm = TRUE)
    },
    median_trait_dominance = if (all(is.na(dominance))) {
      NA_real_
    } else {
      stats::median(dominance, na.rm = TRUE)
    }
  )
}

.gllvmTMB_fmt_num <- function(x, digits = 3L) {
  if (length(x) == 0L || all(is.na(x))) {
    return("NA")
  }
  paste(signif(x, digits), collapse = ",")
}

.gllvmTMB_sigma_eps_mapped_off <- function(object) {
  map <- object$tmb_obj$env$map
  if (is.null(map) || !"log_sigma_eps" %in% names(map)) {
    return(FALSE)
  }
  all(is.na(as.vector(map$log_sigma_eps)))
}

#' Check convergence, Hessian, gradients, and interval readiness
#'
#' Run `check_gllvmTMB()` right after fitting, before interpreting
#' confidence intervals or covariance summaries. It returns a stable
#' table of optimiser, gradient, Hessian, `sdreport()`, restart,
#' boundary, and latent-identifiability diagnostics. It is the
#' machine-readable companion to
#' [gllvmTMB_diagnose()]: use this in simulations, tests, and reports
#' where parsing printed messages would be brittle.
#'
#' Scope boundary (DIA-08 / DIA-10): IN, optimisation and
#' inference-risk signals for fitted models, including latent-axis
#' rotation, weak-axis, near-zero `psi`, and residual-scale boundary
#' flags plus the intentional `gllvmTMBcontrol(se = FALSE)`
#' point-estimate path. PARTIAL, the table does not calibrate interval
#' coverage or prove the selected latent rank by itself. PLANNED,
#' target-explicit M3 simulations and [check_identifiability()] decide
#' when broader interval or rank-selection claims move beyond
#' diagnostic status.
#'
#' A `WARN` row, including `pdHess = FALSE`, means that Wald standard
#' errors or curvature-based inference need more care; it is not by
#' itself proof that the fitted mean, likelihood, or rotation-invariant
#' covariance summaries are unusable.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param gradient_thresh Maximum allowed absolute gradient component.
#'   Default 0.01.
#' @param se_thresh Threshold above which a fixed-effect standard error
#'   is flagged as weakly identified. Default 100.
#' @param weak_axis_thresh Minimum acceptable share of shared loading
#'   energy for a fitted latent axis. Default 0.05.
#' @param psi_thresh Threshold below which a fitted per-trait `psi`
#'   standard deviation is flagged as near zero. Default 0.0001.
#' @param sigma_eps_thresh Threshold below which an estimated residual
#'   `sigma_eps` is flagged as near boundary. Default 0.0001.
#' @param cross_loading_thresh Minimum median trait dominance on a
#'   single latent axis before a multi-axis loading matrix is treated as
#'   block-structured enough for direct interpretation. Default 0.6.
#' @return A data frame with columns `component`, `status`, `value`,
#'   `threshold`, `message`, and `action`. Status values are `"PASS"`,
#'   `"WARN"`, or `"FAIL"`.
#' @export
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'                 data = dat, trait = "trait", unit = "site")
#' check_gllvmTMB(fit)
#' }
check_gllvmTMB <- function(
  object,
  gradient_thresh = 1e-2,
  se_thresh = 100,
  weak_axis_thresh = 0.05,
  psi_thresh = 1e-4,
  sigma_eps_thresh = 1e-4,
  cross_loading_thresh = 0.6
) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  health <- object$fit_health %||% .gllvmTMB_build_fit_health(object)
  hessian_rank <- .gllvmTMB_hessian_rank(object)
  rows <- list(
    .gllvmTMB_check_row(
      "optimizer_convergence",
      if (isTRUE(health$convergence == 0L)) "PASS" else "FAIL",
      health$convergence,
      "0",
      if (isTRUE(health$convergence == 0L)) {
        "optimizer reported convergence"
      } else {
        health$message %||% "optimizer did not report clean convergence"
      },
      "try multiple starts, stronger starts, rescaling, or an alternative optimizer"
    ),
    .gllvmTMB_check_row(
      "max_gradient",
      if (
        is.finite(health$max_gradient) &&
          health$max_gradient < gradient_thresh
      ) {
        "PASS"
      } else {
        "WARN"
      },
      signif(health$max_gradient, 4),
      gradient_thresh,
      "largest absolute gradient component at the selected optimum",
      "tighten optimization, rescale predictors, or inspect weak components"
    ),
    .gllvmTMB_check_row(
      "sdreport",
      if (isTRUE(health$sdreport_ok)) "PASS" else "WARN",
      isTRUE(health$sdreport_ok),
      TRUE,
      if (isTRUE(health$sdreport_ok)) {
        "sdreport available"
      } else {
        health$sdreport_error %||% "sdreport unavailable"
      },
      "use point summaries cautiously and prefer profile/bootstrap intervals"
    ),
    .gllvmTMB_check_row(
      "pd_hessian",
      if (isTRUE(health$pd_hessian)) "PASS" else "WARN",
      health$pd_hessian,
      TRUE,
      "positive-definite Hessian for curvature-based inference",
      "check gradients, boundary variances, rank, starts, and profile/bootstrap targets"
    ),
    .gllvmTMB_check_row(
      "hessian_rank",
      if (
        is.finite(hessian_rank$rank) &&
          is.finite(hessian_rank$dimension) &&
          hessian_rank$rank == hessian_rank$dimension
      ) {
        "PASS"
      } else {
        "WARN"
      },
      paste0(hessian_rank$rank, "/", hessian_rank$dimension),
      "full rank",
      "rank of the fixed-parameter covariance matrix from sdreport",
      "treat rank loss as a Hessian/identifiability warning"
    ),
    .gllvmTMB_check_row(
      "max_fixed_se",
      if (
        is.finite(health$max_fixed_se) &&
          health$max_fixed_se < se_thresh
      ) {
        "PASS"
      } else {
        "WARN"
      },
      signif(health$max_fixed_se, 4),
      se_thresh,
      "largest fixed-effect standard error",
      "check collinearity, scaling, or weakly identified fixed effects"
    )
  )

  restart_history <- object$restart_history %||% data.frame()
  rows <- c(
    rows,
    list(
      .gllvmTMB_check_row(
        "restart_history",
        if (nrow(restart_history) > 0L) "PASS" else "WARN",
        nrow(restart_history),
        ">= 1",
        "number of optimizer starts recorded on the fit",
        "refit with current gllvmTMB if provenance is missing"
      ),
      .gllvmTMB_check_row(
        "selected_restart",
        if (is.finite(health$selected_restart)) "PASS" else "WARN",
        health$selected_restart,
        "finite restart id",
        "restart selected by minimum objective",
        "inspect restart_history for competing likelihood basins"
      )
    )
  )

  flags <- health$boundary_flags %||% character(0)
  if (length(flags) == 0L) {
    rows <- c(
      rows,
      list(.gllvmTMB_check_row(
        "boundary_flags",
        "PASS",
        "none",
        "none",
        "no simple boundary flags detected",
        "still inspect profile/bootstrap output for target-specific weakness"
      ))
    )
  } else {
    for (flag in flags) {
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          "boundary_flags",
          "WARN",
          flag,
          "none",
          "near-boundary loading or variance component detected",
          "consider lower rank, simpler covariance, or stronger starts"
        ))
      )
    }
  }

  latent_specs <- .gllvmTMB_latent_specs(object)
  if (length(latent_specs) == 0L) {
    rows <- c(
      rows,
      list(.gllvmTMB_check_row(
        "rotation_convention",
        "PASS",
        "none",
        "none",
        "no fitted latent loading matrix detected",
        "no loading rotation diagnostic needed"
      ))
    )
  } else {
    rotation <- object$needs_rotation_advice %||% list()
    for (spec in latent_specs) {
      needs_rotation <- isTRUE(rotation[[spec$advice]])
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          paste0("rotation_convention_", spec$level),
          if (needs_rotation) "WARN" else "PASS",
          if (needs_rotation) {
            "rotation_ambiguous"
          } else {
            "as_fit_lower_triangular"
          },
          "rotation-invariant Sigma for covariance interpretation",
          paste0(
            spec$lambda,
            if (needs_rotation) {
              " is identified up to rotation/sign convention"
            } else {
              " has an as-fit identification convention"
            }
          ),
          "use Sigma/correlations/communality for invariant summaries; rotate or constrain loadings before comparing axes"
        ))
      )

      ax <- .gllvmTMB_axis_summary(spec$matrix)
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          paste0("weak_axis_", spec$level),
          if (
            is.finite(ax$min_axis_share) &&
              ax$min_axis_share >= weak_axis_thresh
          ) {
            "PASS"
          } else {
            "WARN"
          },
          paste0(
            "min=",
            .gllvmTMB_fmt_num(ax$min_axis_share),
            "; shares=",
            .gllvmTMB_fmt_num(ax$axis_share)
          ),
          weak_axis_thresh,
          paste0(spec$lambda, " column share of shared loading energy"),
          "compare lower rank, inspect check_identifiability(), and avoid over-interpreting weak axes"
        ))
      )

      if (ncol(spec$matrix) > 1L) {
        rows <- c(
          rows,
          list(.gllvmTMB_check_row(
            paste0("cross_loading_structure_", spec$level),
            if (
              is.finite(ax$median_trait_dominance) &&
                ax$median_trait_dominance >= cross_loading_thresh
            ) {
              "PASS"
            } else {
              "WARN"
            },
            .gllvmTMB_fmt_num(ax$median_trait_dominance),
            cross_loading_thresh,
            "median trait share carried by its dominant latent axis",
            "use varimax/promax rotation for interpretation if loadings are spread across axes"
          ))
        )
      }
    }
  }

  psi_specs <- c(
    unit = "sd_B",
    unit_obs = "sd_W",
    phylo = "sd_phy_diag",
    spatial = "sd_spde"
  )
  for (level in names(psi_specs)) {
    nm <- psi_specs[[level]]
    if (!nm %in% names(object$report)) {
      next
    }
    val <- as.numeric(object$report[[nm]])
    val <- val[is.finite(val)]
    if (length(val) == 0L) {
      next
    }
    min_val <- min(abs(val))
    rows <- c(
      rows,
      list(.gllvmTMB_check_row(
        paste0("near_zero_psi_", level),
        if (is.finite(min_val) && min_val >= psi_thresh) "PASS" else "WARN",
        .gllvmTMB_fmt_num(min_val, digits = 4L),
        psi_thresh,
        paste0(nm, " minimum fitted per-trait psi standard deviation"),
        "check whether the trait-specific component is intentionally mapped off, boundary-pinned, or redundant"
      ))
    )
  }

  sigma_eps <- as.numeric(object$report$sigma_eps %||% numeric(0L))
  sigma_eps <- sigma_eps[is.finite(sigma_eps)]
  if (length(sigma_eps) > 0L) {
    sigma_eps <- sigma_eps[1L]
    mapped_off <- .gllvmTMB_sigma_eps_mapped_off(object)
    rows <- c(
      rows,
      list(.gllvmTMB_check_row(
        "boundary_sigma_eps",
        if (isTRUE(mapped_off) || sigma_eps >= sigma_eps_thresh) {
          "PASS"
        } else {
          "WARN"
        },
        .gllvmTMB_fmt_num(sigma_eps, digits = 4L),
        sigma_eps_thresh,
        if (isTRUE(mapped_off)) {
          "sigma_eps is mapped off by the fitted model/family path"
        } else {
          "estimated continuous-family residual scale"
        },
        "if estimated near zero, check row-level unique terms or residual-scale identifiability"
      ))
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Diagnose a fitted model and suggest next actions
#'
#' This is the human-readable diagnostic to call right after
#' `fit <- gllvmTMB(...)`. It combines the quick numerical screen
#' ([sanity_multi()]), the rotation identifiability advisory, and key
#' biological summaries (correlation diagonals, ICCs, communalities)
#' into a single report with explicit next-step hints for any `WARN`
#' signal. Use [check_gllvmTMB()] when you need the same fit-health
#' checks as a stable table for scripts or reports.
#'
#' Scope boundary (DIA-05 / DIA-08 / DIA-10): IN, first-line
#' convergence, Hessian, standard-error, restart, and rotation
#' diagnostics. PARTIAL, it reports risks and summaries but does not
#' replace profile, bootstrap, or simulation calibration. PLANNED, M3
#' target-explicit validation will decide which interval warnings can
#' be promoted to broader guarantees.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param gradient_thresh,se_thresh Forwarded to [sanity_multi()].
#' @param big_corr_thresh Threshold above which a `Sigma_B` correlation
#'   off-diagonal is flagged as worth highlighting. Default 0.5.
#' @param verbose If `TRUE` (default), prints the report. Always
#'   returns the structured list invisibly.
#' @return Invisibly a list with components: `sanity` (the
#'   [sanity_multi()] flags), `rotation` (rotation-advisory list),
#'   `Sigma_B`, `Sigma_W`, `ICC_site`, `communality_B`, `communality_W`,
#'   and `hints` (character vector of suggested actions).
#' @export
#' @seealso [check_gllvmTMB()], [sanity_multi()],
#'   [suggest_lambda_constraint()],
#'   [extract_Sigma()], [extract_communality()],
#'   [compare_dep_vs_two_psi()] / [compare_indep_vs_two_psi()] for
#'   identifiability cross-checks on the paired phylogenetic fit.
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'                 data = dat, trait = "trait", unit = "site")
#' gllvmTMB_diagnose(fit)
#' }
gllvmTMB_diagnose <- function(
  object,
  gradient_thresh = 1e-2,
  se_thresh = 100,
  big_corr_thresh = 0.5,
  verbose = TRUE
) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }

  ## ---- Pillar 1: sanity flags --------------------------------------
  if (verbose) {
    cli::cli_h2("1. Optimiser & numerical sanity")
  }
  san <- if (verbose) {
    sanity_multi(
      object,
      gradient_thresh = gradient_thresh,
      se_thresh = se_thresh
    )
  } else {
    ## Capture the print output so silent calls don't pollute stdout
    suppressWarnings(utils::capture.output({
      flags <- sanity_multi(
        object,
        gradient_thresh = gradient_thresh,
        se_thresh = se_thresh
      )
    }))
    flags
  }

  ## ---- Pillar 2: rotation identifiability --------------------------
  rot <- object$needs_rotation_advice %||%
    list(B = FALSE, W = FALSE, phy = FALSE)
  if (verbose) {
    cli::cli_h2("2. Rotational identifiability")
    if (any(unlist(rot, use.names = FALSE))) {
      for (lvl in names(rot)) {
        if (isTRUE(rot[[lvl]])) {
          d_lvl <- object[[paste0("d_", lvl)]]
          cli::cli_inform(c(
            "!" = "{.code Lambda_{lvl}} (rank d = {d_lvl}) is identified only up to rotation."
          ))
        }
      }
    } else {
      cli::cli_inform(c(
        "v" = "No latent / phylo_latent term with rotational ambiguity."
      ))
    }
  }

  ## ---- Pillar 3: biological summaries ------------------------------
  out_Sigma_B <- tryCatch(extract_Sigma_B(object), error = function(e) NULL)
  out_Sigma_W <- tryCatch(extract_Sigma_W(object), error = function(e) NULL)
  ICC_site <- tryCatch(extract_ICC_site(object), error = function(e) NULL)
  comm_B <- tryCatch(extract_communality(object, "unit"), error = function(e) {
    NULL
  })
  comm_W <- tryCatch(
    extract_communality(object, "unit_obs"),
    error = function(e) NULL
  )

  if (verbose) {
    cli::cli_h2("3. Biological summaries")
    if (!is.null(out_Sigma_B)) {
      cat("\n  Sigma_B (between-unit covariance) diagonal:\n  ")
      cat(paste(round(diag(out_Sigma_B$Sigma_B), 3), collapse = "  "), "\n")
      ## Surface large correlations
      R <- out_Sigma_B$R_B
      big <- which(abs(R) > big_corr_thresh & lower.tri(R), arr.ind = TRUE)
      if (nrow(big) > 0) {
        nm <- rownames(R) %||% paste0("trait", seq_len(nrow(R)))
        cat(sprintf(
          "  %d trait pair(s) with |corr| > %.2f:\n",
          nrow(big),
          big_corr_thresh
        ))
        for (i in seq_len(min(nrow(big), 8L))) {
          cat(sprintf(
            "    %s ~ %s : %+.2f\n",
            nm[big[i, 1]],
            nm[big[i, 2]],
            R[big[i, 1], big[i, 2]]
          ))
        }
      }
    }
    if (!is.null(out_Sigma_W)) {
      cat("\n  Sigma_W (within-unit covariance) diagonal:\n  ")
      cat(paste(round(diag(out_Sigma_W$Sigma_W), 3), collapse = "  "), "\n")
    }
    if (!is.null(ICC_site)) {
      cat("\n  Per-trait site-level ICC:\n  ")
      cat(paste(round(ICC_site, 3), collapse = "  "), "\n")
    }
    if (!is.null(comm_B)) {
      cat("\n  Global communalities:\n  ")
      cat(paste(round(comm_B, 3), collapse = "  "), "\n")
    }
    if (!is.null(comm_W)) {
      cat("\n  Local communalities:\n  ")
      cat(paste(round(comm_W, 3), collapse = "  "), "\n")
    }
  }

  ## ---- Pillar 4: actionable hints ----------------------------------
  hints <- character(0)
  if (!isTRUE(san$converged)) {
    hints <- c(
      hints,
      paste(
        "Optimiser did NOT converge.",
        "Try `gllvmTMBcontrol(n_init = 5, optimizer = \"optim\",",
        "optArgs = list(method = \"BFGS\"))`, residual starts for",
        "non-Gaussian latent fits, or `start_method = list(method = \"indep\")`",
        "for simpler-model warm starts."
      )
    )
  }
  if (isTRUE(san$max_gradient >= gradient_thresh)) {
    hints <- c(
      hints,
      paste(
        sprintf(
          "Max |gradient| = %.3g exceeds %.1e.",
          san$max_gradient,
          gradient_thresh
        ),
        "Optimum may not be tight; try multiple starts via",
        "`gllvmTMBcontrol(n_init = 5)` or rescale predictors."
      )
    )
  }
  if (!isTRUE(san$pd_hessian)) {
    hints <- c(
      hints,
      paste(
        "Hessian is not positive-definite. Treat this as an inference",
        "and identifiability warning rather than automatic point-estimate",
        "failure. Inspect `check_gllvmTMB(fit)`, gradients, boundary",
        "variances, redundant latent dimensions, and prefer profile or",
        "bootstrap intervals for interpretable Sigma targets."
      )
    )
  }
  if (!is.na(san$max_se) && san$max_se >= se_thresh) {
    hints <- c(
      hints,
      paste(
        sprintf("Largest fixed-effect SE = %.3g.", san$max_se),
        "A coefficient is barely identified -- check for collinearity or",
        "for a fixed effect that is absorbed by a random-effect group."
      )
    )
  }
  if (any(unlist(rot, use.names = FALSE))) {
    hints <- c(
      hints,
      paste(
        "Lambda is identified only up to rotation. For a unique loading",
        "matrix, see `suggest_lambda_constraint()`. For interpretation,",
        "use `getLoadings(fit, rotate = \"varimax\")`. The implied Sigma",
        "matrices are rotation-invariant and need no constraint."
      )
    )
  }

  if (verbose) {
    cli::cli_h2("4. Suggested next steps")
    if (length(hints) == 0) {
      cli::cli_inform(c("v" = "Nothing flagged. Fit looks healthy."))
    } else {
      for (h in hints) {
        cli::cli_inform(c("*" = h))
      }
    }
  }

  invisible(list(
    sanity = san,
    rotation = rot,
    Sigma_B = out_Sigma_B,
    Sigma_W = out_Sigma_W,
    ICC_site = ICC_site,
    communality_B = comm_B,
    communality_W = comm_W,
    hints = hints
  ))
}
