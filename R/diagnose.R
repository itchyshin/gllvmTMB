## One-call user-facing diagnostic for a fitted gllvmTMB model.
## Wraps sanity_multi(), checks rotation identifiability, reports the
## key biological summaries, and prints actionable hints for any WARN
## or FAIL signal. Designed to be the first call a user makes after
## fitting.

## Conservative stationarity tolerance. The objective-scaled gradient remains a
## descriptive diagnostic, but it cannot by itself certify convergence because
## its value changes with arbitrary additive/replicate scaling of the objective.
## `converged` therefore requires the optimiser's success code, a finite objective,
## and a small unscaled maximum gradient. Hessian health remains a separate
## inference diagnostic rather than part of this point-stationarity flag.
.gllvmTMB_converged_gtol <- 1e-2

.gllvmTMB_build_fit_health <- function(object) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }

  grad <- tryCatch(object$tmb_obj$gr(object$opt$par), error = function(e) {
    NA_real_
  })
  se <- if (!is.null(object$sd_report)) {
    tryCatch(
      .gllvmTMB_b_fix_se(object),
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

  ## Separate descriptive stationarity signals from the conservative conjunction.
  max_grad_val <- if (length(grad) == 0L || all(is.na(grad))) {
    NA_real_
  } else {
    max(abs(grad), na.rm = TRUE)
  }
  obj_val <- object$opt$objective %||% NA_real_
  scaled_gradient <- if (is.na(max_grad_val) || is.na(obj_val)) {
    NA_real_
  } else {
    max_grad_val / (1 + abs(obj_val))
  }
  stationary_by_scaled_gradient <- isTRUE(
    scaled_gradient < .gllvmTMB_converged_gtol
  )
  stationary_by_gradient <- isTRUE(max_grad_val < .gllvmTMB_converged_gtol)
  optimizer_converged <- isTRUE(identical(object$opt$convergence, 0L))
  converged <- isTRUE(
    optimizer_converged && is.finite(obj_val) && stationary_by_gradient
  )

  list(
    optimizer = if (nrow(restart_history) > 0L) {
      restart_history$optimizer[which.max(restart_history$selected)]
    } else {
      NA_character_
    },
    convergence = object$opt$convergence %||% NA_integer_,
    message = object$opt$message %||% "",
    objective = obj_val,
    max_gradient = max_grad_val,
    scaled_gradient = scaled_gradient,
    stationary_by_scaled_gradient = stationary_by_scaled_gradient,
    stationary_by_gradient = stationary_by_gradient,
    optimizer_converged = optimizer_converged,
    converged = converged,
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

## A variance component can be fully collapsed and still clear an absolute
## standard-deviation threshold: `sd_thresh = 1e-4` on the sd scale demands a
## variance below 1e-8, so a boundary-pinned component with sd 6.8e-4 (variance
## 4.7e-7) passes while its siblings sit near 1. `psi` is estimated on the log
## scale, so `psi -> 0` is an interior point of the transformed space and
## `pdHess` stays positive definite there too -- neither existing signal can see
## a Heywood case. The relative test below is the isSingular-style signal this
## function's contract promises: a component orders of magnitude below its
## siblings is collapsed regardless of its absolute size.
##
## It needs at least two components to have something to compare against; a
## lone component is still covered only by the absolute threshold.
.gllvmTMB_relative_collapse <- function(val, rel_thresh) {
  val <- abs(val[is.finite(val)])
  if (length(val) < 2L) {
    return(FALSE)
  }
  max_val <- max(val)
  if (!is.finite(max_val) || max_val <= 0) {
    return(FALSE)
  }
  min(val) / max_val < rel_thresh
}

.gllvmTMB_boundary_flags <- function(
  object,
  loading_thresh = 1e-3,
  sd_thresh = 1e-4,
  sd_rel_thresh = 1e-3
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
      "sd_spde",
      ## Augmented random-slope variances (the dep/indep/`||` slope engines and
      ## the spatial slope). These are the cells most prone to a boundary
      ## (singular) fit -- weakly-identified per-trait intercept/slope variances,
      ## esp. `||` and spatial slopes -- so surfacing a near-zero flag here is
      ## the isSingular-style signal for a weakly-identified random-slope fit.
      "sd_b",
      "sd_spde_b"
    ),
    names(rep)
  )) {
    val <- as.numeric(rep[[nm]])
    val <- val[is.finite(val)]
    if (length(val) > 0L &&
        (any(val < sd_thresh) ||
           .gllvmTMB_relative_collapse(val, sd_rel_thresh))) {
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
  dimension <- ncol(cov_fixed)
  # A converged fit can still yield a non-finite fixed-effect covariance
  # (e.g. NaN standard errors from a weakly identified sdreport). qr() aborts
  # on non-finite input ("NA/NaN/Inf in foreign function call"), so report an
  # undefined rank -- which the caller renders as a WARN row -- rather than
  # letting a diagnostic crash on an otherwise-usable fit.
  if (!all(is.finite(cov_fixed))) {
    return(list(rank = NA_integer_, dimension = dimension))
  }
  rank <- tryCatch(qr(cov_fixed, tol = tol)$rank, error = function(e) NA_integer_)
  list(rank = rank, dimension = dimension)
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
    ## `phylo_dep()` reuses the Lambda_phy storage block for a constrained
    ## full-covariance factor. Its columns are not exchangeable latent axes,
    ## so rotation and weak-axis diagnostics do not apply.
    if (
      identical(spec$level, "phylo") &&
        isTRUE(object$use$phylo_dep)
    ) {
      next
    }
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

.gllvmTMB_trait_names <- function(object) {
  trait_id <- object$tmb_data$trait_id
  inferred_n_traits <- if (length(trait_id) > 0L && any(is.finite(trait_id))) {
    max(trait_id + 1L, na.rm = TRUE)
  } else {
    0L
  }
  n_traits <- object$n_traits %||% inferred_n_traits
  trait_col <- object$trait_col
  if (
    !is.null(trait_col) &&
      trait_col %in% names(object$data) &&
      is.factor(object$data[[trait_col]])
  ) {
    lv <- levels(object$data[[trait_col]])
    if (length(lv) >= n_traits) {
      return(lv[seq_len(n_traits)])
    }
  }
  paste0("trait_", seq_len(n_traits))
}

## `keep` restricts which traits define the typical loading size. Pooling that
## reference across families lets a large-scale gaussian trait set a binomial
## trait's yardstick -- inflating the denominator until a genuine runaway looks
## ordinary, or deflating it until an ordinary loading looks like a runaway.
## Callers screening one family pass that family's trait ids.
## NOTE: the merge loop below uses a local `keep`, so this argument must not
## share that name.
.gllvmTMB_max_loading_by_trait <- function(object, reference_traits = NULL) {
  trait_names <- .gllvmTMB_trait_names(object)
  out <- rep(NA_real_, length(trait_names))
  names(out) <- trait_names

  for (spec in .gllvmTMB_latent_specs(object)) {
    L <- abs(spec$matrix)
    if (nrow(L) == 0L || ncol(L) == 0L) {
      next
    }
    vals <- apply(L, 1L, max, na.rm = TRUE)
    vals[!is.finite(vals)] <- NA_real_
    if (!is.null(rownames(L)) && any(rownames(L) %in% trait_names)) {
      hit <- match(rownames(L), trait_names)
      keep <- !is.na(hit)
      old <- out[hit[keep]]
      new <- vals[keep]
      replace <- is.finite(new) & (!is.finite(old) | new > old)
      old[replace] <- new[replace]
      out[hit[keep]] <- old
    } else {
      n <- min(length(out), length(vals))
      old <- out[seq_len(n)]
      new <- vals[seq_len(n)]
      replace <- is.finite(new) & (!is.finite(old) | new > old)
      old[replace] <- new[replace]
      out[seq_len(n)] <- old
    }
  }

  reference <- if (is.null(reference_traits)) {
    out
  } else {
    out[intersect(as.integer(reference_traits), seq_along(out))]
  }
  finite <- reference[is.finite(reference) & reference > 0]
  typical <- if (length(finite) > 0L) {
    stats::median(finite, na.rm = TRUE)
  } else {
    NA_real_
  }
  spread <- if (length(finite) > 1L) {
    stats::mad(finite, constant = 1, na.rm = TRUE)
  } else {
    NA_real_
  }
  denom_candidates <- c(typical, spread)
  denom_candidates <- denom_candidates[
    is.finite(denom_candidates) & denom_candidates > 0
  ]
  denom <- if (length(denom_candidates) > 0L) {
    max(denom_candidates)
  } else {
    NA_real_
  }

  ## The ABSOLUTE criterion is justified only where the latent scores are
  ## standard normal by identification, which makes a loading the trait's latent
  ## SD in link units. That holds for the unit tiers. It does NOT hold for the
  ## SPDE tier, whose loadings multiply basis coefficients carrying their own
  ## sqrt(4*pi)*kappa normalisation -- measured at 6.5e6 against 66 on the unit
  ## tier in the same fit. Pooling that into an absolute link-scale threshold
  ## would flag a spatial fit on the strength of a parameterisation, so the
  ## absolute column is reported separately from the pooled maximum.
  unit_levels <- c("unit", "unit_obs")
  out_unit <- rep(NA_real_, length(trait_names))
  names(out_unit) <- trait_names
  for (spec in .gllvmTMB_latent_specs(object)) {
    if (!spec$level %in% unit_levels) {
      next
    }
    L <- abs(spec$matrix)
    if (nrow(L) == 0L || ncol(L) == 0L) {
      next
    }
    vals <- apply(L, 1L, max, na.rm = TRUE)
    vals[!is.finite(vals)] <- NA_real_
    if (!is.null(rownames(L)) && any(rownames(L) %in% trait_names)) {
      hit <- match(rownames(L), trait_names)
      k <- !is.na(hit)
      old <- out_unit[hit[k]]
      new <- vals[k]
      rep_i <- is.finite(new) & (!is.finite(old) | new > old)
      old[rep_i] <- new[rep_i]
      out_unit[hit[k]] <- old
    } else {
      nn <- min(length(out_unit), length(vals))
      old <- out_unit[seq_len(nn)]
      new <- vals[seq_len(nn)]
      rep_i <- is.finite(new) & (!is.finite(old) | new > old)
      old[rep_i] <- new[rep_i]
      out_unit[seq_len(nn)] <- old
    }
  }

  data.frame(
    trait_id = seq_along(trait_names),
    trait = trait_names,
    max_loading = unname(out),
    max_loading_unit = unname(out_unit),
    relative_loading = if (is.finite(denom)) unname(out) / denom else NA_real_,
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_binomial_prevalence_loading_row <- function(
  object,
  prevalence_thresh = 0.9,
  saturation_prob_thresh = 0.99,
  saturation_share_thresh = 0.5,
  loading_relative_thresh = 8,
  loading_runaway_thresh = 25,
  loading_absolute_thresh = 6
) {
  tmb <- object$tmb_data
  required <- c("y", "family_id_vec", "link_id_vec", "trait_id")
  if (is.null(tmb) || !all(required %in% names(tmb))) {
    return(NULL)
  }

  y <- as.numeric(tmb$y)
  n <- length(y)
  family_id <- as.integer(tmb$family_id_vec)
  link_id <- as.integer(tmb$link_id_vec)
  trait_id <- as.integer(tmb$trait_id) + 1L
  if (
    length(family_id) != n ||
      length(link_id) != n ||
      length(trait_id) != n
  ) {
    return(NULL)
  }

  observed <- tmb$is_y_observed %||% rep(1L, n)
  observed <- as.integer(observed) == 1L
  trials <- as.numeric(tmb$n_trials %||% rep(1, n))
  binomial_rows <- family_id == 1L &
    observed &
    is.finite(y) &
    is.finite(trials) &
    trials > 0
  if (!any(binomial_rows)) {
    return(NULL)
  }

  eta <- as.numeric(object$report$eta %||% rep(NA_real_, n))
  fitted_prob <- rep(NA_real_, n)
  if (length(eta) == n) {
    fitted_prob <- .apply_linkinv_per_row(eta, family_id, link_id)
  }

  trait_names <- .gllvmTMB_trait_names(object)
  ids <- sort(unique(trait_id[binomial_rows]))
  rows <- vector("list", length(ids))
  for (i in seq_along(ids)) {
    id <- ids[[i]]
    idx <- binomial_rows & trait_id == id
    prob_i <- fitted_prob[idx]
    prob_i <- prob_i[is.finite(prob_i)]
    rows[[i]] <- data.frame(
      trait_id = id,
      trait = if (id <= length(trait_names)) {
        trait_names[[id]]
      } else {
        paste0("trait_", id)
      },
      n = sum(idx),
      prevalence = sum(y[idx], na.rm = TRUE) / sum(trials[idx], na.rm = TRUE),
      saturation_share = if (length(prob_i) > 0L) {
        mean(
          prob_i >= saturation_prob_thresh |
            prob_i <= (1 - saturation_prob_thresh)
        )
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
  tab <- do.call(rbind, rows)
  loadings <- .gllvmTMB_max_loading_by_trait(object, reference_traits = ids)
  tab <- merge(tab, loadings, by = c("trait_id", "trait"), all.x = TRUE)

  tab$extreme_prevalence <- is.finite(tab$prevalence) &
    (tab$prevalence >= prevalence_thresh |
      tab$prevalence <= (1 - prevalence_thresh))
  tab$dominant_loading <- is.finite(tab$relative_loading) &
    tab$relative_loading >= loading_relative_thresh
  tab$saturated_fit <- is.finite(tab$saturation_share) &
    tab$saturation_share >= saturation_share_thresh
  ## A loading this far above the other traits' is an improper solution
  ## whatever the marginal prevalence does. Quasi-complete separation is a
  ## property of the fitted linear predictor, so it runs a loading away at
  ## ordinary prevalence -- which the extreme-prevalence conjunct below cannot
  ## see. `dominant_loading` stays gated on prevalence because at 8x it is a
  ## hint that needs corroboration; `runaway_loading` does not, because a
  ## healthy fit does not reach it.
  tab$runaway_loading <- is.finite(tab$relative_loading) &
    tab$relative_loading >= loading_runaway_thresh
  ## A ratio is blind to a loading matrix inflated as a whole: under
  ## Lambda -> c * Lambda every per-trait maximum scales by c, the denominator
  ## scales by c, and the ratio does not move. The link scale supplies the
  ## missing absolute reference here -- the latent scores are standard normal by
  ## identification, so a binomial loading IS the trait's latent SD in link
  ## units, and a value this large means a fitted probability indistinguishable
  ## from 0 or 1 across an ordinary swing of the axis.
  ## judged on the unit tiers only -- see the note in
  ## `.gllvmTMB_max_loading_by_trait()`; a structured tier's loadings are not on
  ## the link scale this threshold is defined against.
  tab$extreme_magnitude <- is.finite(tab$max_loading_unit) &
    tab$max_loading_unit >= loading_absolute_thresh
  tab$flag <- (tab$extreme_prevalence &
    (tab$dominant_loading | tab$saturated_fit)) |
    tab$runaway_loading |
    tab$extreme_magnitude

  score <- abs(tab$prevalence - 0.5)
  score[!is.finite(score)] <- -Inf
  score <- score +
    ifelse(tab$flag, 10, 0) +
    ifelse(tab$dominant_loading, 2, 0) +
    ifelse(tab$saturated_fit, 1, 0)
  best <- tab[which.max(score), , drop = FALSE]
  status <- if (any(tab$flag)) "WARN" else "PASS"
  ## The wording follows the trait actually being reported. A near-constant
  ## trait is usually the CAUSE of the separation, so where prevalence explains
  ## the loading the near-constant advice is the more actionable one; the
  ## runaway wording is for the case prevalence cannot explain.
  runaway_hit <- (isTRUE(best$runaway_loading) ||
    isTRUE(best$extreme_magnitude)) &&
    !isTRUE(best$extreme_prevalence)
  msg <- if (!identical(status, "WARN")) {
    "binomial trait prevalence/loading/saturation screen"
  } else if (runaway_hit) {
    "trait loading has run away from the rest (an improper solution, or Heywood case); quasi-complete separation produces this at ordinary prevalence"
  } else {
    "near-constant binomial trait with dominant loading or saturated fitted probabilities"
  }

  out <- .gllvmTMB_check_row(
    "binomial_prevalence_loading",
    status,
    paste0(
      best$trait,
      " prevalence=",
      .gllvmTMB_fmt_num(best$prevalence),
      "; max_loading=",
      .gllvmTMB_fmt_num(best$max_loading),
      "; relative_loading=",
      .gllvmTMB_fmt_num(best$relative_loading),
      "; saturated_fit=",
      .gllvmTMB_fmt_num(best$saturation_share)
    ),
    paste0(
      "prevalence >= ",
      prevalence_thresh,
      " or <= ",
      .gllvmTMB_fmt_num(1 - prevalence_thresh),
      "; fitted p >= ",
      saturation_prob_thresh,
      " or <= ",
      .gllvmTMB_fmt_num(1 - saturation_prob_thresh),
      "; loading >= ",
      loading_relative_thresh,
      "x typical with extreme prevalence, >= ",
      loading_runaway_thresh,
      "x typical on its own, or >= ",
      loading_absolute_thresh,
      " on the link scale"
    ),
    msg,
    if (!identical(status, "WARN")) {
      "none"
    } else if (runaway_hit) {
      "treat the fit as unusable rather than interpreting it: this is quasi-complete separation, which lowering the rank does not resolve; refit with a loading penalty via gllvmTMBcontrol(aghq_ridge = 2), which makes the result a penalised (MAP) estimate, so logLik(), AIC() and BIC() no longer apply to it"
    } else {
      "remove or re-code the near-constant binary indicator; lowering rank will not resolve quasi-separation by itself"
    }
  )
  ## Which path fired, so the weak-axis row can give matching advice: a
  ## runaway trait need not be near-constant, and telling the reader to
  ## re-code a trait sitting at prevalence 0.6 sends them the wrong way.
  attr(out, "runaway_loading") <- runaway_hit
  out
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
#' boundary, latent-identifiability, and binomial prevalence/loading
#' diagnostics. It is the machine-readable companion to
#' [gllvmTMB_diagnose()]: use this in simulations, tests, and reports
#' where parsing printed messages would be brittle.
#'
#' Scope: optimisation and inference-risk signals for fitted
#' models, including latent-axis rotation, weak-axis, near-zero
#' `psi`, residual-scale boundary flags, a binomial
#' near-constant/loading/saturation screen, and the intentional
#' `gllvmTMBcontrol(se = FALSE)` point-estimate path. The table
#' does not calibrate interval coverage, prove formal separation,
#' or prove the selected latent rank by itself. Target-explicit
#' known-DGP simulations will decide when broader interval or
#' rank-selection claims can move beyond diagnostic status.
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
#' @param psi_rel_thresh Threshold on the ratio of the smallest to the
#'   largest fitted per-trait `psi` standard deviation, below which the
#'   smallest is flagged as collapsed relative to its siblings. This
#'   catches boundary-pinned (Heywood) components whose absolute standard
#'   deviation still clears `psi_thresh`: `psi` is estimated on the log
#'   scale, so a component at the boundary is an interior point of the
#'   transformed space and `pdHess` stays positive definite there.
#'   Needs at least two components. Default 0.01, raised from 0.001 on
#'   measured evidence: across 360 gaussian and Poisson fits with a
#'   deliberately over-specified latent rank, 58% drove a unique standard
#'   deviation below a tenth of its true value while reporting
#'   `convergence = 0` (208 of 209) and `pdHess = TRUE` (190 of 209). At
#'   0.001 the row reported 73.7% of those; at 0.01 it reports 96.2%. The
#'   false-positive rate is zero at both, measured on 151 healthy fits and
#'   again on 359 healthy fits whose *true* unique variances differ by up
#'   to a factor of 1000 — the case that decides transport, since a small
#'   ratio is then correct rather than pathological. Looser thresholds do
#'   not transport: 0.1 reaches full sensitivity but flags 19% of those
#'   healthy heterogeneous fits.
#' @param sigma_eps_thresh Threshold below which an estimated residual
#'   `sigma_eps` is flagged as near boundary. Default 0.0001.
#' @param cross_loading_thresh Minimum median trait dominance on a
#'   single latent axis before a multi-axis loading matrix is treated as
#'   block-structured enough for direct interpretation. Default 0.6.
#' @param binary_prevalence_thresh Prevalence at or beyond which a
#'   binomial trait is treated as near-constant. Default 0.9.
#' @param binary_saturation_prob_thresh Response-scale fitted probability
#'   threshold for saturation in binomial traits. Default 0.99.
#' @param binary_saturation_share_thresh Minimum share of saturated
#'   fitted probabilities before a binomial trait is flagged. Default
#'   0.5.
#' @param loading_relative_thresh Threshold for the largest trait loading
#'   relative to the typical fitted loading size. At this level the
#'   loading is only reported alongside an extreme prevalence, because a
#'   sparse but genuine loading structure reaches it on healthy fits.
#'   Default 8.
#' @param loading_runaway_thresh Threshold for the largest trait loading,
#'   relative to the typical fitted loading size, at which the loading is
#'   reported on its own without requiring an extreme prevalence. This
#'   catches an improper solution (Heywood case) from quasi-complete
#'   separation, which runs a loading away while the trait's marginal
#'   prevalence stays unremarkable. Default 25, calibrated on 6,824
#'   simulated **single-family binomial** fits: no healthy fit reached it
#'   (the largest was 12.1), while it reported 96.3% of fits whose
#'   implied covariance was wrong by a factor of five or more. Two limits
#'   on that calibration are worth knowing. It has not been measured on
#'   mixed-family fits, and it would not transport to another family on
#'   its own, because a sparse but genuine loading structure pushes the
#'   ratio much higher there. The typical loading size is therefore taken
#'   over the binomial traits alone, so that a trait from another family
#'   cannot set the scale this threshold is judged against.
#' @param loading_absolute_thresh Threshold on the largest trait loading
#'   itself, on the link scale, at which it is reported regardless of the
#'   other traits. A ratio cannot see a loading matrix inflated as a
#'   whole, because scaling every loading leaves every ratio unchanged;
#'   this supplies the absolute reference the ratio lacks. It is
#'   meaningful because the latent scores are standard normal by
#'   identification, so a binomial loading is the trait's latent standard
#'   deviation in link units: a value of 6 already implies a fitted
#'   probability indistinguishable from 0 or 1 across an ordinary swing
#'   of the axis. Default 6. Measured over 3,944 simulated binomial fits:
#'   no healthy fit exceeded 3.99 and none was flagged, while the
#'   threshold reported 97.3% of degenerate fits and caught 14 that the
#'   relative criterion missed. Being a link-scale quantity it does not
#'   transport to families whose response scale is arbitrary, which is
#'   why this row is binomial-only.
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
  psi_rel_thresh = 1e-2,
  sigma_eps_thresh = 1e-4,
  cross_loading_thresh = 0.6,
  binary_prevalence_thresh = 0.9,
  binary_saturation_prob_thresh = 0.99,
  binary_saturation_share_thresh = 0.5,
  loading_relative_thresh = 8,
  loading_runaway_thresh = 25,
  loading_absolute_thresh = 6
) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  is_mspl <- .gllvmTMB_is_mspl(object)
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
      if (is_mspl) "INFO" else if (isTRUE(health$sdreport_ok)) "PASS" else "WARN",
      if (is_mspl) "withheld" else isTRUE(health$sdreport_ok),
      if (is_mspl) "not applicable" else TRUE,
      if (is_mspl) {
        "sdreport is deliberately withheld for the MSPL point-estimation surface"
      } else if (isTRUE(health$sdreport_ok)) {
        "sdreport available"
      } else {
        health$sdreport_error %||% "sdreport unavailable"
      },
      if (is_mspl) {
        "MSPL is point-only; inspect its stationarity and penalty provenance without requesting intervals"
      } else {
        "use point summaries cautiously and prefer profile/bootstrap intervals"
      }
    ),
    .gllvmTMB_check_row(
      "pd_hessian",
      if (is_mspl) "INFO" else if (isTRUE(health$pd_hessian)) "PASS" else "WARN",
      if (is_mspl) "withheld" else health$pd_hessian,
      if (is_mspl) "not applicable" else TRUE,
      if (is_mspl) {
        "curvature-based inference is outside the MSPL point-estimation contract"
      } else {
        "positive-definite Hessian for curvature-based inference"
      },
      if (is_mspl) {
        "check gradients, boundary behaviour, latent rank, and starts; MSPL curvature inference is withheld"
      } else {
        "check gradients, boundary variances, rank, starts, and profile/bootstrap targets"
      }
    ),
    .gllvmTMB_check_row(
      "hessian_rank",
      if (is_mspl) {
        "INFO"
      } else if (
        is.finite(hessian_rank$rank) &&
          is.finite(hessian_rank$dimension) &&
          hessian_rank$rank == hessian_rank$dimension
      ) {
        "PASS"
      } else {
        "WARN"
      },
      if (is_mspl) "withheld" else paste0(hessian_rank$rank, "/", hessian_rank$dimension),
      if (is_mspl) "not applicable" else "full rank",
      if (is_mspl) {
        "fixed-parameter covariance rank is not computed for an MSPL point estimate"
      } else {
        "rank of the fixed-parameter covariance matrix from sdreport"
      },
      if (is_mspl) {
        "use the retained latent-rank and stationarity diagnostics"
      } else {
        "treat rank loss as a Hessian/identifiability warning"
      }
    ),
    .gllvmTMB_check_row(
      "max_fixed_se",
      if (is_mspl) {
        "INFO"
      } else if (
        is.finite(health$max_fixed_se) &&
          health$max_fixed_se < se_thresh
      ) {
        "PASS"
      } else {
        "WARN"
      },
      if (is_mspl) "withheld" else signif(health$max_fixed_se, 4),
      if (is_mspl) "not applicable" else se_thresh,
      if (is_mspl) {
        "fixed-effect standard errors are outside the MSPL point-estimation contract"
      } else {
        "largest fixed-effect standard error"
      },
      if (is_mspl) {
        "inspect fixed-design separation, gradients, and point-estimate sensitivity"
      } else {
        "check collinearity, scaling, or weakly identified fixed effects"
      }
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
        if (is_mspl) {
          "MSPL has no simple boundary flag; still inspect stationarity and latent-rank diagnostics"
        } else {
          "still inspect profile/bootstrap output for target-specific weakness"
        }
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
  binomial_row <- .gllvmTMB_binomial_prevalence_loading_row(
    object,
    prevalence_thresh = binary_prevalence_thresh,
    saturation_prob_thresh = binary_saturation_prob_thresh,
    saturation_share_thresh = binary_saturation_share_thresh,
    loading_relative_thresh = loading_relative_thresh,
    loading_runaway_thresh = loading_runaway_thresh,
    loading_absolute_thresh = loading_absolute_thresh
  )
  binomial_warn <- !is.null(binomial_row) &&
    identical(binomial_row$status[[1L]], "WARN")
  binomial_runaway <- binomial_warn &&
    isTRUE(attr(binomial_row, "runaway_loading"))
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
          if (isTRUE(binomial_runaway)) {
            "if driven by a runaway trait loading, treat the fit as an improper solution rather than re-ranking it; otherwise compare lower ranks and use known-DGP simulations to evaluate the selection rule"
          } else if (isTRUE(binomial_warn)) {
            "if driven by a high-loading near-constant binary trait, remove or re-code that indicator; otherwise compare lower ranks and use known-DGP simulations to evaluate the selection rule"
          } else {
            "compare lower ranks, inspect fit stability, and avoid over-interpreting weak axes"
          }
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
  if (!is.null(binomial_row)) {
    rows <- c(rows, list(binomial_row))
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
    ## Absolute OR relative: a component orders of magnitude below its siblings
    ## is collapsed even when its absolute sd clears `psi_thresh`. See
    ## `.gllvmTMB_relative_collapse()` for why the absolute test alone cannot
    ## detect a Heywood case.
    relative_collapse <- .gllvmTMB_relative_collapse(val, psi_rel_thresh)
    passes <- is.finite(min_val) && min_val >= psi_thresh && !relative_collapse
    rows <- c(
      rows,
      list(.gllvmTMB_check_row(
        paste0("near_zero_psi_", level),
        if (passes) "PASS" else "WARN",
        .gllvmTMB_fmt_num(min_val, digits = 4L),
        paste0(psi_thresh, " absolute / ", psi_rel_thresh, " relative"),
        paste0(
          nm, " minimum fitted per-trait psi standard deviation",
          if (relative_collapse) {
            paste0(
              "; collapsed relative to the largest (ratio ",
              .gllvmTMB_fmt_num(min_val / max(abs(val)), digits = 4L),
              ")"
            )
          } else {
            ""
          }
        ),
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
#' Scope: first-line convergence, Hessian, standard-error,
#' restart, and rotation diagnostics. It reports risks and
#' summaries but does not replace profile, bootstrap, or
#' simulation calibration. Target-explicit validation will
#' decide which interval warnings can be promoted to broader
#' guarantees.
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
  is_mspl <- .gllvmTMB_is_mspl(object)

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
        "optArgs = list(method = \"BFGS\"))`, more starts with modest",
        "jitter, or `start_method = list(method = \"indep\")`",
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
      if (is_mspl) {
        paste(
          "MSPL is a point-only estimator, so Hessian-based inference is",
          "withheld. Inspect `check_gllvmTMB(fit)`, gradients, penalty",
          "provenance, boundary behaviour, and redundant latent dimensions;",
          "do not substitute profile or bootstrap intervals in this release."
        )
      } else {
        paste(
          "Hessian is not positive-definite. Treat this as an inference",
          "and identifiability warning rather than automatic point-estimate",
          "failure. Inspect `check_gllvmTMB(fit)`, gradients, boundary",
          "variances, redundant latent dimensions, and prefer profile or",
          "bootstrap intervals for interpretable Sigma targets."
        )
      }
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
