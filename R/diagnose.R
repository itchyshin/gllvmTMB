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

  ## #1092: judge the objective the fit actually optimised. On a ridged fit
  ## the raw `tmb_obj$gr()` is missing the R-level loading penalty, so it sits
  ## at |lambda|/tau^2 (>> gtol) at a perfectly converged MAP optimum, and
  ## every downstream reader of `max_gradient` -- the `converged` conjunction
  ## below first -- misread ridged fits until routed through the penalised
  ## accessor. The raw gradient stays reachable via `tmb_obj$gr()`;
  ## `gradient_is_penalised` in the list below discloses which objective this
  ## number describes.
  ridge_tau <- object$aghq$ridge_tau %||% Inf
  grad <- tryCatch(
    .gllvmTMB_penalised_gradient(object$tmb_obj, object$opt$par, ridge_tau),
    error = function(e) {
      NA_real_
    }
  )
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
    gradient_is_penalised = .gllvmTMB_loading_ridge_applies(
      ridge_tau, names(object$tmb_obj$par)
    ),
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

## `sd_B` (unit level) and `sd_W` (per-row / OLRE tier) are both REPORTed
## for every trait, including ones R/fit-multi.R's auto-skip gates pin to
## `log(1e-6)` and map off: `sd_B` for single-trial Bernoulli and
## multinomial fid-16 contrasts (`skip_psi_b_t`, `diag_B_skip`,
## src/gllvmTMB.cpp:1586), and `sd_W` for single-trial Bernoulli, ordinal
## probit (fid 14), and multinomial fid-16 contrasts (`skip_olre_t`,
## `diag_W_skip`, src/gllvmTMB.cpp:1646) -- the identical mapped-off
## mechanism one tier over. Those pinned entries are plumbing residue, not
## a fitted quantity, and their 1e-6 value fires an absolute near-zero
## threshold unconditionally. Every raw reader of either quantity that
## screens for near-zero must drop the mapped-off entries the same way, or
## a default auto-skip fit and its explicit `latent(..., unique = FALSE)` /
## row-level-diagonal mirror disagree on boundary diagnostics for a model
## that is otherwise identical.
##
## Complete mask inventory (grep "_skip" across R/fit-multi.R and
## src/gllvmTMB.cpp): `diag_B_skip` and `diag_W_skip` are the only two
## per-trait skip masks the engine carries; there is no third. Both are
## guaranteed length `n_traits` by a C++ hard error whenever their
## component is actually REPORTed (`use_diag_B` / `use_diag_W`
## respectively; src/gllvmTMB.cpp:1576-1577 and :1637-1638), so the
## length-equality guard below is defensive, not load-bearing -- but it is
## kept for both entries rather than assumed.
.gllvmTMB_estimable_component_masks <- c(
  sd_B = "diag_B_skip",
  sd_W = "diag_W_skip"
)

.gllvmTMB_estimable_components <- function(object, name) {
  val <- object$report[[name]]
  if (is.null(val)) {
    return(NULL)
  }
  val <- as.numeric(val)
  mask_name <- unname(.gllvmTMB_estimable_component_masks[name])
  if (!is.na(mask_name)) {
    skip <- object$tmb_data[[mask_name]]
    if (!is.null(skip) && length(skip) == length(val)) {
      val <- val[skip != 1L]
    }
  }
  ## `sd_kernel_diag` (src/gllvmTMB.cpp:1760-1861) does not fit the mask
  ## table above: it is an `n_traits x n_kernel_tiers` matrix, not a
  ## per-trait vector, and its companion `kernel_has_diag` uses the
  ## OPPOSITE polarity from `diag_B_skip` / `diag_W_skip` -- `1` means the
  ## tier's diag IS estimated (keep), not that it is mapped off (skip). As
  ## of this writing the R-level multi-kernel grammar hard-blocks a fitted
  ## kernel-tier Psi (`kernel_has_diag` is unconditionally 0 for every
  ## tier; R/fit-multi.R:3456-3462, cli_abort at :3375-3381), so whenever
  ## `sd_kernel_diag` is REPORTed at all it is currently an all-zero
  ## placeholder -- screening it unfiltered would fire on every
  ## 2+-named-kernel fit (issue #1119). Filter to the (currently empty) set
  ## of tiers that actually carry a fitted diag, so the screen stays inert
  ## today and starts working the day the R-level block above is lifted.
  if (identical(name, "sd_kernel_diag")) {
    has_diag <- object$tmb_data[["kernel_has_diag"]]
    if (!is.null(has_diag) && length(has_diag) > 0L &&
        length(val) %% length(has_diag) == 0L) {
      keep <- rep(has_diag == 1L, each = length(val) / length(has_diag))
      val <- val[keep]
    }
  }
  val
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
      "sd_phy_diag",
      ## `sd_spde_unique` is the spatial `*_unique()` Psi companion
      ## (src/gllvmTMB.cpp:2150); `sd_kernel_diag` is its multi-kernel
      ## analogue (src/gllvmTMB.cpp:1861). Neither was in this list before
      ## issue #1119 -- a collapsed spatial or kernel Psi went unflagged.
      ## (The bare literals `"sd_phy"` and `"sd_spde"` that used to sit here
      ## never matched a REPORTed name -- src/gllvmTMB.cpp REPORTs
      ## `sd_phy_diag` and `sd_spde_unique`, not those -- so they are
      ## removed rather than corrected onto a real name that already has
      ## its own entry above/below.)
      "sd_spde_unique",
      "sd_kernel_diag",
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
    val <- .gllvmTMB_estimable_components(object, nm)
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

## ---- shared scaffolding for the family-specific detector rows ----
##
## These three helpers are the genuinely reusable pieces behind the binomial
## prevalence/loading row and the multinomial contrast-degeneracy row below:
## a `tmb_data` presence/field guard, a trait-id -> label lookup, and a
## report-matrix-row -> trait-id matcher that mirrors the rowname-or-
## positional convention `.gllvmTMB_max_loading_by_trait()` already uses.
## Extracting them keeps the binomial row's own logic (prevalence,
## saturation, the relative/runaway/absolute loading arms) untouched -- the
## refactor is required to be byte-identical in behaviour, verified by the
## existing binomial/runaway-warning test suites before and after.

## Returns `object$tmb_data` unchanged if every name in `required` is
## present, else `NULL`. This is the "presence" half of a detector row's
## guard; row-specific length/consistency checks (e.g. binomial's
## `length(family_id) != n`) stay in the calling row, since those checks
## are not shared across families.
.gllvmTMB_tmb_data_or_null <- function(object, required) {
  tmb <- object$tmb_data
  if (is.null(tmb) || !all(required %in% names(tmb))) {
    return(NULL)
  }
  tmb
}

## The trait-id -> label lookup every per-trait/per-contrast row uses:
## the fitted trait name where one is registered, else a positional
## `trait_<id>` fallback.
.gllvmTMB_trait_label <- function(trait_names, id) {
  if (id <= length(trait_names)) {
    trait_names[[id]]
  } else {
    paste0("trait_", id)
  }
}

## Matches each entry of `ids` (1-based trait ids) to a row index in the
## report matrix `L`. Mirrors `.gllvmTMB_max_loading_by_trait()`'s own
## matching rule: prefer `rownames(L)` against the fitted trait labels
## when any are present, else fall back to positional alignment (row i of
## `L` is trait i, for i <= nrow(L)). Returns an integer vector the same
## length as `ids`, `NA` where a trait has no row in `L`.
.gllvmTMB_match_rows_by_trait <- function(L, trait_names, ids) {
  if (!is.null(rownames(L)) && any(rownames(L) %in% trait_names)) {
    return(match(trait_names[ids], rownames(L)))
  }
  out <- rep(NA_integer_, length(ids))
  in_range <- ids <= nrow(L)
  out[in_range] <- ids[in_range]
  out
}

.gllvmTMB_binomial_prevalence_loading_row <- function(
  object,
  prevalence_thresh = 0.9,
  saturation_prob_thresh = 0.99,
  saturation_share_thresh = 0.5,
  loading_relative_thresh = 8,
  loading_runaway_thresh = 25,
  loading_absolute_thresh = 8
) {
  required <- c("y", "family_id_vec", "link_id_vec", "trait_id")
  tmb <- .gllvmTMB_tmb_data_or_null(object, required)
  if (is.null(tmb)) {
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
      trait = .gllvmTMB_trait_label(trait_names, id),
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
      "treat the fit as unusable rather than interpreting it: this is quasi-complete separation, which lowering the rank does not resolve; try gllvmTMBcontrol(loading_ridge = 0.25) (0.25 to 0.5; larger tau shrinks less) to shrink runaway loadings, or gllvmTMBcontrol(integration = 'va') for latent(..., unique = FALSE) fits with at least 100 units and d <= 2 -- either makes the result a penalised (MAP) or variational estimate, so logLik(), AIC() and BIC() no longer apply to it"
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

## The absolute domain diameter reachable from a fitted spatial fit's stored
## mesh, in the coordinate units `xy_cols` was fit in. `.gllvm_new_mesh()`
## (R/mesh.R) stores the raw fitting coordinates as `mesh$loc_xy`, an n x 2
## matrix -- this reads them directly rather than through fmesher, so it works
## whether or not fmesher is available at diagnose time. Returns `NA_real_`
## when the coordinates are not reachable (e.g. a hand-built fixture with no
## `mesh` element), which callers treat as "fall back to the absolute range
## threshold".
.gllvmTMB_spatial_domain_diameter <- function(object) {
  loc <- object$mesh$loc_xy
  if (is.null(loc) || !is.matrix(loc) || ncol(loc) < 2L || nrow(loc) < 2L) {
    return(NA_real_)
  }
  span <- apply(
    loc[, 1:2, drop = FALSE], 2L,
    function(x) diff(range(x, na.rm = TRUE))
  )
  if (!all(is.finite(span))) {
    return(NA_real_)
  }
  sqrt(sum(span^2))
}

#' Multinomial K-1 contrast pseudo-trait degeneracy screen
#'
#' `multinomial()` (family_id 16) is fitted as K-1 baseline-category
#' contrast pseudo-traits per categorical response
#' (`expand_multinomial_response()`, named `"<base>:<category>"`). Three
#' failure mechanisms are specific to that expansion and invisible to the
#' generic weak-axis/near-zero-psi rows, which screen every trait's loadings
#' pooled together rather than a single categorical response's own K-1
#' contrasts against each other:
#'   The variance-collapse screen (`contrast_variance_collapse`) flags one
#'   contrast whose loading energy
#'     (`rowSums(Lambda^2)`) collapses to ~0, absolutely or relative to its
#'     sibling contrasts.
#'   The contrast-rail screen (`contrast_rail`) flags two contrasts of the
#'   same response that load almost
#'     perfectly on the same axis (`|rho| ~ 1` in the implied contrast-level
#'     covariance), a rank collapse that only shows up when the tier carries
#'     `d >= 2` -- at `d = 1` every healthy fit reaches `rho = +-1` by row
#'     proportionality, so `d = 1` is exempt by construction.
#'   The spatial-range screen (`spatial_range_collapse`) flags a fitted spatial
#'   practical range that
#'     (`sqrt(8) / kappa`) collapses relative to the coordinate domain the
#'     multinomial response was fit over.
#' Lambda matrices are read directly from `object$report` rather than
#' through `.gllvmTMB_latent_specs()`, which deliberately skips `Lambda_phy`
#' under `use$phylo_dep` -- irrelevant here, since the implied covariance
#' `Lambda %*% t(Lambda)` is rotation-invariant, and a `phylo_dep` rail is
#' precisely a failure this row must be able to see.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param multinomial_collapse_floor Absolute floor on a contrast's fitted
#'   loading energy (`rowSums(Lambda^2)`), at or below which it is a
#'   collapsed contrast. Default `1e-10`, the campaign code's own guard;
#'   labeled evidence: 7/20 `phylo_indep` seeds at or below `1e-9`, every one
#'   reporting `convergence = 0` and a positive-definite Hessian.
#'   **Calibrated** (2026-08-17): sensitivity **6/7** on the labeled
#'   `phylo_indep` collapse seeds (the miss sat at 1.79e-10, just above the
#'   floor; the threshold was NOT loosened to capture it), and **7/7** on a
#'   fully out-of-sample replicated diagonal-V cell with 0/13 firings on
#'   that cell's healthy fits. A genuinely zero variance component fires
#'   this arm by design -- at the fit level a true zero and a collapse are
#'   indistinguishable, which is what the row's action text addresses.
#' @param multinomial_collapse_rel_thresh Threshold on the ratio of the
#'   smallest to the largest fitted contrast loading energy within one
#'   response's K-1 contrasts, below which the smallest is flagged as
#'   collapsed relative to its siblings. Default `Inf`
#'   (disarmed): the K-1 contrasts of one multinomial response are
#'   `pi^2/6`-correlated siblings through their shared baseline category,
#'   not the independent siblings `psi_rel_thresh` (0.01) was calibrated on,
#'   so this arm is provisional pending the S3 calibration campaign.
#' @param multinomial_rail_thresh Threshold on the largest absolute
#'   off-diagonal correlation of the implied contrast-level covariance
#'   (`Lambda %*% t(Lambda)`) within one response's contrasts, at or above
#'   which two contrasts are reported as rail-correlated. Only
#'   evaluated at tiers with rank `d >= 2` (see Details). Default `0.99`,
#'   **calibrated** (2026-08-17, 128 refits of labeled cells): sensitivity
#'   **8/8** on the labeled `phylo_dep` rail seeds, plus 4/4 on individually
#'   railed fits sitting inside a cell whose AGGREGATE gate passed --
#'   verified by refitting (rho = +-1.00000 on all four; non-firing controls
#'   0.490 and -0.145). Specificity: zero false positives on 40 informative
#'   healthy fits, which bounds the false-positive rate at roughly 7.5% by
#'   the rule of three -- a real improvement on the binomial screen's
#'   measured 25% (issue #897), but NOT a verified zero. The `d >= 2` gate is
#'   load-bearing, not defensive: at rank 1 every pair of contrast rows is
#'   proportional, so `|rho| = 1` exactly on healthy fits; suppression
#'   confirmed out-of-sample at 0/20 on a healthy `d = 1` cell.
#' @param multinomial_range_collapse_thresh Threshold on the fitted spatial
#'   practical range (`sqrt(8) / kappa`) relative to the coordinate-domain
#'   diameter (the ratio, when the fit's mesh coordinates are reachable via
#'   `object$mesh$loc_xy`), or on the practical range itself in absolute
#'   coordinate units (the fallback, when they are not), at or below which
#'   the spatial field is reported as collapsed. Default `0.02`;
#'   labeled evidence: collapsed ratios 7e-5 to 3.4e-4. This arm measured
#'   **0/3** in the first calibration pass for a scope reason rather than a
#'   threshold one -- it gated on `Lambda_spde`, which the engine reports
#'   only on the low-rank `spatial_latent()`/`spatial_dep()` route, so
#'   `spatial_indep()` fits (the labeled collapse cell) were invisible to
#'   it. Both routes are now covered, and the re-measurement gives
#'   sensitivity **3/3** on those labeled seeds with **0/11** false positives
#'   on the same cell's healthy fits (2026-08-17, 20 refits, row now emitted
#'   for 20/20 rather than 0/20).
#' @return A one-row data frame in the [check_gllvmTMB()] row shape, or
#'   `NULL` when the fit has no multinomial (fid 16) contrast pseudo-traits.
#' @keywords internal
.gllvmTMB_multinomial_degeneracy_row <- function(
  object,
  multinomial_collapse_floor = 1e-10,
  multinomial_collapse_rel_thresh = Inf,
  multinomial_rail_thresh = 0.99,
  multinomial_range_collapse_thresh = 0.02
) {
  required <- c("trait_id", "multinom_K_per_trait")
  tmb <- .gllvmTMB_tmb_data_or_null(object, required)
  if (is.null(tmb)) {
    return(NULL)
  }

  mnK <- as.integer(tmb$multinom_K_per_trait)
  is_mn <- is.finite(mnK) & mnK > 0L
  if (!any(is_mn)) {
    return(NULL)
  }

  trait_names <- .gllvmTMB_trait_names(object)
  ids <- which(is_mn)
  labels <- vapply(
    ids, function(id) .gllvmTMB_trait_label(trait_names, id), character(1)
  )
  ## Group K-1 contrast pseudo-traits into one response's block by their
  ## shared "<base>:" prefix (expand_multinomial_response() names each
  ## contrast "<base>:<category>").
  block <- sub(":[^:]*$", "", labels)

  ## Tiers read DIRECTLY from the report -- see roxygen Details above for why
  ## `.gllvmTMB_latent_specs()` is not used here.
  tiers <- c(
    unit = "Lambda_B",
    unit_obs = "Lambda_W",
    phylo = "Lambda_phy",
    spatial = "Lambda_spde"
  )

  cells <- list()
  for (level in names(tiers)) {
    L <- .gllvmTMB_report_matrix(object, tiers[[level]])
    if (is.null(L)) {
      next
    }
    row_idx <- .gllvmTMB_match_rows_by_trait(L, trait_names, ids)
    for (b in unique(block)) {
      b_row <- row_idx[block == b]
      keep <- !is.na(b_row)
      ## The K-1 >= 2 contrasts of one response can be a genuine M1/M2
      ## sibling set even with only 2 rows present in this tier; a lone row
      ## still gets an M1 floor test but no M2 rail test (handled below via
      ## d_eligible).
      if (sum(keep) < 1L) {
        next
      }
      Lb <- L[b_row[keep], , drop = FALSE]
      d <- ncol(Lb)
      contrast_var <- rowSums(Lb^2)
      finite_var <- contrast_var[is.finite(contrast_var)]
      min_var <- if (length(finite_var) > 0L) min(finite_var) else NA_real_
      floor_hit <- is.finite(min_var) && min_var <= multinomial_collapse_floor
      ## Disarmed by construction when the threshold is non-finite (the
      ## `Inf` default): `.gllvmTMB_relative_collapse()`'s own `<` test would
      ## otherwise fire on every finite ratio.
      sibling_hit <- is.finite(multinomial_collapse_rel_thresh) &&
        .gllvmTMB_relative_collapse(contrast_var, multinomial_collapse_rel_thresh)
      m1 <- isTRUE(floor_hit || sibling_hit)

      ## HARD PRECONDITION: at d = 1 every healthy fit has rho = +-1 exactly
      ## by row proportionality (a single shared loading column), so M2 is
      ## evaluated only where the tier's rank is >= 2.
      m2 <- FALSE
      max_rho <- NA_real_
      if (d >= 2L && sum(keep) >= 2L) {
        V <- Lb %*% t(Lb)
        dg <- diag(V)
        ok <- is.finite(dg) & dg > 0
        if (sum(ok) >= 2L) {
          Vok <- V[ok, ok, drop = FALSE]
          dgok <- diag(Vok)
          R <- Vok / sqrt(outer(dgok, dgok))
          diag(R) <- NA_real_
          if (any(is.finite(R))) {
            max_rho <- max(abs(R), na.rm = TRUE)
            m2 <- isTRUE(max_rho >= multinomial_rail_thresh)
          }
        }
      }

      cells[[length(cells) + 1L]] <- data.frame(
        block = b, tier = level, d = d, n_contrasts = sum(keep),
        min_contrast_var = min_var, m1 = m1,
        max_rail_rho = max_rho, m2 = m2,
        stringsAsFactors = FALSE
      )
    }
  }
  tab <- if (length(cells) > 0L) do.call(rbind, cells) else NULL

  ## M3: spatial practical range vs the coordinate domain, once per response
  ## block that actually loads on the spatial tier -- SPDE loadings stay OUT
  ## of every absolute-loading statistic elsewhere in this file (the
  ## 6.5e6-vs-66 unit-tier hazard), but a practical range compared against a
  ## coordinate-scale diameter is itself in coordinate units, not link units,
  ## so that hazard does not apply to M3.
  ## Two mutually exclusive engine routes reach the spatial tier, and M3 must
  ## see BOTH. `Lambda_spde` is REPORTed only when `spde_lv_k > 0`
  ## (src/gllvmTMB.cpp, the low-rank spatial_latent()/spatial_dep() route);
  ## spatial_indep() runs the per-trait diagonal route, which has no loading
  ## matrix at all and reports `log_tau_spde` instead. Gating M3 on
  ## `Lambda_spde` therefore made it structurally blind to exactly the fits it
  ## was built for (measured 0/3 on the labeled spatial_indep collapse cell,
  ## dev/multinomial-structured/pass-criteria-detector-mn.md). On the diagonal
  ## route the C++ loops over every trait unconditionally, so every trait
  ## carries a field and participation needs no per-trait test.
  m3_cells <- list()
  if (isTRUE(object$use$spde)) {
    L_spde <- .gllvmTMB_report_matrix(object, "Lambda_spde")
    kappa <- tryCatch(.gllvm_spatial_kappa(object), error = function(e) NULL)
    kappa_ok <- is.numeric(kappa) && length(kappa) == 1L &&
      is.finite(kappa) && kappa > 0
    if (kappa_ok) {
      practical_range <- sqrt(8) / as.numeric(kappa)
      diameter <- .gllvmTMB_spatial_domain_diameter(object)
      m3_row <- function(b, route) {
        if (is.finite(diameter) && diameter > 0) {
          value <- practical_range / diameter
          metric <- "range_over_diameter"
        } else {
          value <- practical_range
          metric <- "range_absolute"
        }
        data.frame(
          block = b, metric = metric, value = value,
          m3 = is.finite(value) && value < multinomial_range_collapse_thresh,
          route = route, stringsAsFactors = FALSE
        )
      }
      if (!is.null(L_spde)) {
        row_idx <- .gllvmTMB_match_rows_by_trait(L_spde, trait_names, ids)
        for (b in unique(block)) {
          b_row <- row_idx[block == b]
          keep <- !is.na(b_row)
          if (sum(keep) < 1L) {
            next
          }
          Lb <- L_spde[b_row[keep], , drop = FALSE]
          loads_spatial <- any(is.finite(Lb) & Lb != 0)
          if (!loads_spatial) {
            next
          }
          m3_cells[[length(m3_cells) + 1L]] <- m3_row(b, "low_rank")
        }
      } else {
        log_tau_spde <- object$report$log_tau_spde
        if (is.numeric(log_tau_spde) && length(log_tau_spde) > 0L &&
            any(is.finite(log_tau_spde))) {
          for (b in unique(block)) {
            m3_cells[[length(m3_cells) + 1L]] <- m3_row(b, "diagonal")
          }
        }
      }
    }
  }
  m3_tab <- if (length(m3_cells) > 0L) do.call(rbind, m3_cells) else NULL

  if (is.null(tab) && is.null(m3_tab)) {
    return(NULL)
  }

  any_m1 <- !is.null(tab) && any(tab$m1)
  any_m2 <- !is.null(tab) && any(tab$m2)
  any_m3 <- !is.null(m3_tab) && any(m3_tab$m3)
  status <- if (any_m1 || any_m2 || any_m3) "WARN" else "PASS"
  arms <- c(
    if (any_m1) "variance collapse" else NULL,
    if (any_m2) "contrast rail" else NULL,
    if (any_m3) "spatial range collapse" else NULL
  )

  ## The worst cell drives the reported value/message, mirroring the
  ## binomial row's "worst trait" convention. M1+M2 share `tab`; M3 lives in
  ## its own table because it is keyed by block only, not block x tier.
  worst_line <- character(0)
  if (!is.null(tab)) {
    hit <- tab[tab$m1 | tab$m2, , drop = FALSE]
    src <- if (nrow(hit) > 0L) hit[1L, , drop = FALSE] else tab[1L, , drop = FALSE]
    worst_line <- c(worst_line, paste0(
      src$block, "@", src$tier, ": d=", src$d,
      "; min_contrast_var=", .gllvmTMB_fmt_num(src$min_contrast_var),
      "; max_rail_rho=", .gllvmTMB_fmt_num(src$max_rail_rho)
    ))
  }
  if (!is.null(m3_tab)) {
    hit3 <- m3_tab[m3_tab$m3, , drop = FALSE]
    src3 <- if (nrow(hit3) > 0L) hit3[1L, , drop = FALSE] else m3_tab[1L, , drop = FALSE]
    worst_line <- c(worst_line, paste0(
      src3$block, "@spatial: ", src3$metric, "=",
      .gllvmTMB_fmt_num(src3$value)
    ))
  }

  msg <- if (identical(status, "PASS")) {
    "multinomial K-1 contrast pseudo-trait degeneracy screen"
  } else {
    paste0(
      "multinomial contrast degeneracy detected (arms: ",
      paste(arms, collapse = ","), ")"
    )
  }
  action <- if (identical(status, "PASS")) {
    "none"
  } else {
    parts <- character(0)
    if (any_m1) {
      ## House wording (shared with the near-zero-psi row): a true-zero
      ## variance fit fires M1 by design, so the action must not assert
      ## pathology outright.
      parts <- c(
        parts,
        "check whether the component is intentionally mapped off, boundary-pinned, or genuinely collapsed"
      )
    }
    if (any_m2) {
      parts <- c(
        parts,
        "a rail (|rho| near 1) between two contrasts of the same response suggests the fitted rank is not supported by these K-1 contrasts; compare a lower rank or re-check baseline-category coding"
      )
    }
    if (any_m3) {
      parts <- c(
        parts,
        "the spatial practical range is small relative to the coordinate domain; check mesh resolution and whether the spatial term is identified for this response"
      )
    }
    paste(parts, collapse = "; ")
  }

  .gllvmTMB_check_row(
    "multinomial_contrast_degeneracy",
    status,
    paste(worst_line, collapse = "; "),
    paste0(
      "variance <= ", multinomial_collapse_floor,
      " (absolute) or sibling ratio < ", multinomial_collapse_rel_thresh,
      " (relative); rail |rho| >= ", multinomial_rail_thresh,
      " at tier rank d >= 2; spatial range/domain (or absolute range) < ",
      multinomial_range_collapse_thresh
    ),
    msg,
    action
  )
}

## Per-trait fitted cutpoint span (`max(tau) - min(tau)` over the free
## cutpoints `tau_2 .. tau_{K-1}`; `tau_1 = 0` is fixed by the Hadfield
## convention and is not itself a free parameter) for the O2-variant
## calibration statistic in `.gllvmTMB_ordinal_degeneracy_row()`. Mirrors the
## `n_ordinal_cuts_per_trait` / `ordinal_offset_per_trait` packing that
## `extract_cutpoints()` (`R/extract-cutpoints.R`) already uses. Returns a
## named numeric vector (names = trait_id as character), `NA` for any trait
## with fewer than one free cutpoint (`K = 2`, no free cutpoint under the
## Hadfield convention) or where the packing metadata is unreachable (e.g. a
## hand-built fixture without it) -- fails closed rather than dividing by
## zero; callers must not treat a `0`-length span as "no spread", only as
## "undefined".
.gllvmTMB_ordinal_cutpoint_span_by_trait <- function(object, ids) {
  out <- rep(NA_real_, length(ids))
  names(out) <- as.character(ids)
  tmb <- object$tmb_data
  n_cuts_pt <- tmb$n_ordinal_cuts_per_trait
  off_pt <- tmb$ordinal_offset_per_trait
  taus <- object$report$ordinal_cutpoints
  if (is.null(n_cuts_pt) || is.null(off_pt) || is.null(taus)) {
    return(out)
  }
  n_cuts_pt <- as.integer(n_cuts_pt)
  off_pt <- as.integer(off_pt)
  taus <- as.numeric(taus)
  for (id in ids) {
    if (id > length(n_cuts_pt) || id > length(off_pt)) {
      next
    }
    nk <- n_cuts_pt[id]
    if (!is.finite(nk) || nk < 1L) {
      next
    }
    base <- off_pt[id]
    idx <- base + seq_len(nk)
    if (any(idx > length(taus))) {
      next
    }
    tk <- taus[idx]
    if (length(tk) > 0L && all(is.finite(tk))) {
      out[[as.character(id)]] <- max(tk) - min(tk)
    }
  }
  out
}

#' Ordinal-probit loading degeneracy screen
#'
#' `ordinal_probit()` (family_id 14) traits drop the auto-Psi at parse time
#' (`auto_unique_off_family` in `R/fit-multi.R`, fids 12/13/14), so a
#' pure-ordinal fit has no `report$sd_B` and the `near_zero_psi_*` rows
#' elsewhere in [check_gllvmTMB()] are dark by design -- these two loading
#' arms are the ONLY degeneracy coverage a default all-ordinal fit gets,
#' which is exactly issue #897's gap in one sentence (`ordinal_probit` had
#' zero detector coverage, 239/239 fits unflagged, where the binomial screen
#' caught 272/272).
#'
#' The detector-S1 mechanism probe (`dev/ordinal-degeneracy/probe-criteria.md`,
#' VERDICT 2026-08-17) measured the mechanism behind 24 degenerate ordinal
#' fits over a 60-fit grid and found **category-level separation, not link
#' saturation**: `gll_log_pnorm_diff`'s cutpoint-underflow condition (both
#' bracketing cutpoints more than 8.2924 from `eta` on the same side) never
#' fired on any observed row of any degenerate fit (flat-row share exactly
#' 0/24 fits), while dichotomising every degenerate fit's response to binary
#' at the middle cutpoint and refitting as `binomial(link = "probit")` fired
#' the package's EXISTING `binomial_prevalence_loading` detector on 24/24
#' refits. **A flat-fit/saturation arm therefore has no empirical basis in
#' this probe and is deliberately not built here.** This row is instead
#' modeled directly on `.gllvmTMB_binomial_prevalence_loading_row()`'s
#' loading arms, because the probe found the pathology concentrated in a
#' single trait's loading column (worked example: one trait's loading 44.2
#' against a true `max|Lambda| = 4.79` while sibling traits stayed near
#' truth) -- the same per-trait quasi-separation geometry, not a
#' cutpoint-arithmetic artifact.
#'
#' Two arms, both loading-only. Unlike the binomial row there is no
#' prevalence/saturation conjunct: an ordinal trait has no single Bernoulli
#' "prevalence" to test against, and the probe found no evidence that an
#' extreme-category-prevalence conjunct would add sensitivity here; if the
#' detector-S2 calibration campaign shows otherwise, one can be added later.
#'   - **O1 (`runaway_loading`)**: `relative_loading` (a trait's largest
#'     loading divided by the typical loading among the OTHER ordinal
#'     traits, via `.gllvmTMB_max_loading_by_trait(object, reference_traits =
#'     <ordinal trait ids>)` -- the family-scoped denominator, so a
#'     gaussian/binomial partner trait can neither mask nor manufacture an
#'     ordinal runaway) at or above `ordinal_loading_runaway_thresh`.
#'   - **O2 (`extreme_magnitude`)**: `max_loading_unit` (unit tiers ONLY --
#'     never the SPDE tier; see `.gllvmTMB_max_loading_by_trait()`'s own
#'     comment on the `sqrt(4*pi)*kappa` normalisation hazard, measured at
#'     6.5e6 against 66 on the unit tier of the same fit) at or above
#'     `ordinal_loading_absolute_thresh`. This is scale-free for
#'     `ordinal_probit` by the same argument that justifies binomial's
#'     absolute arm: the probit-liability residual variance is EXACTLY 1
#'     under the Wright/Falconer/Hadfield threshold convention
#'     (`R/extract-sigma.R`, `sigma_d^2 = 1` fixed, no free scale
#'     parameter), so a loading IS the trait's latent SD in liability units.
#'
#' Both thresholds default to `Inf` (fully disarmed) pending the detector-S2
#' calibration campaign staged at `dev/ordinal-degeneracy/`
#' (`campaign-ordinal-calibration.R`, `pass-criteria-ordinal.md`) -- shipping
#' an armed default ahead of that evidence would repeat the mistake the
#' binomial thresholds in this file were originally calibrated to correct.
#'
#' A third statistic is computed and reported for the calibration campaign's
#' own use but is **NOT** wired into `flag` or `status`: `cutpoint_span`
#' (a trait's fitted cutpoint span, `max(tau) - min(tau)` over its free
#' cutpoints `tau_2 .. tau_{K-1}`, via
#' `.gllvmTMB_ordinal_cutpoint_span_by_trait()`) and the derived
#' `loading_over_span` (`max_loading_unit / cutpoint_span`). Whether this
#' variant adds sensitivity beyond O1/O2, and whether the span itself is
#' confounded with the degeneracy label it would be screening for (a
#' precondition the calibration campaign must report before this variant
#' could ever ship), is exactly what that campaign is for. `K = 2` traits
#' (no free cutpoint under the Hadfield `tau_1 = 0` convention) return `NA`
#' for `cutpoint_span` rather than dividing by zero, and `loading_over_span`
#' is `NA` wherever `cutpoint_span` is `NA` or non-positive.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param ordinal_loading_runaway_thresh Threshold on an ordinal trait's
#'   loading magnitude relative to the typical loading among the fit's OTHER
#'   ordinal traits (O1; family-scoped denominator, so a gaussian or binomial
#'   partner can neither mask nor manufacture an ordinal runaway). Default
#'   `Inf` — **DISARMED**, and deliberately so: see
#'   `ordinal_loading_absolute_thresh` for the calibration that could not
#'   find a defensible armed value.
#' @param ordinal_loading_absolute_thresh Threshold on an ordinal trait's
#'   largest unit-tier loading in liability units (O2). Unit tiers only —
#'   never the SPDE tier, whose loadings carry a different normalisation.
#'   Scale-free by construction: the probit-liability residual variance is
#'   exactly 1, so an ordinal loading IS the trait's latent SD in liability
#'   units. Default `Inf` — **DISARMED**.
#'
#'   Both ordinal arms ship disarmed because a pre-registered 315-fit
#'   calibration (2026-08-17; four arms — degenerate, healthy, transport,
#'   mixed) could not find a threshold meeting its frozen targets
#'   (sensitivity >= 90% on the degenerate arm AND zero false positives
#'   across the healthy, transport and mixed arms combined). Measured under
#'   that rule: at a threshold of 6, sensitivity 100% but **39.2% false
#'   positives**; at 40, 80.5% and 11.0%; the first zero-FP point sits at
#'   250, where sensitivity is 0%. The classes are not separable at all on
#'   this statistic, because the healthy pool reaches `max_loading_unit`
#'   216.9 while the degenerate arm starts at 13.5.
#'
#'   Two findings from that campaign are worth stating. First, borrowing
#'   binomial's own threshold of 6 would have shipped a screen with a ~39%
#'   false-alarm rate — reproducing on ordinal exactly the defect issue #897
#'   reports in binomial (25%), which is precisely why that issue insists
#'   ordinal thresholds be set on ordinal evidence rather than inherited.
#'   Second, the false alarms concentrate in designs with heterogeneous
#'   per-trait loading scales: an absolute liability-scale threshold cannot
#'   transport across them, because a legitimately large loading on a
#'   wide-cutpoint trait is indistinguishable from a runaway.
#'
#'   The row still computes and reports its statistics, so a user who wants
#'   the screen can set either threshold explicitly. Arming a default is a
#'   maintainer decision that this evidence does not support.
#' @return A one-row data frame in the [check_gllvmTMB()] row shape, or
#'   `NULL` when the fit has no `ordinal_probit()` (family_id 14) trait.
#' @keywords internal
.gllvmTMB_ordinal_degeneracy_row <- function(
  object,
  ordinal_loading_runaway_thresh = Inf,
  ordinal_loading_absolute_thresh = Inf
) {
  required <- c("family_id_vec", "trait_id")
  tmb <- .gllvmTMB_tmb_data_or_null(object, required)
  if (is.null(tmb)) {
    return(NULL)
  }

  family_id <- as.integer(tmb$family_id_vec)
  trait_id <- as.integer(tmb$trait_id) + 1L
  if (length(trait_id) != length(family_id)) {
    return(NULL)
  }
  ordinal_rows <- family_id == 14L
  if (!any(ordinal_rows)) {
    return(NULL)
  }

  ids <- sort(unique(trait_id[ordinal_rows]))
  trait_names <- .gllvmTMB_trait_names(object)
  loadings <- .gllvmTMB_max_loading_by_trait(object, reference_traits = ids)
  tab <- loadings[loadings$trait_id %in% ids, , drop = FALSE]
  if (nrow(tab) == 0L) {
    return(NULL)
  }

  span <- .gllvmTMB_ordinal_cutpoint_span_by_trait(object, ids)
  tab$cutpoint_span <- unname(span[as.character(tab$trait_id)])
  tab$loading_over_span <- ifelse(
    is.finite(tab$max_loading_unit) & is.finite(tab$cutpoint_span) &
      tab$cutpoint_span > 0,
    tab$max_loading_unit / tab$cutpoint_span,
    NA_real_
  )

  ## Same standalone-arm shape as binomial's `runaway_loading` /
  ## `extreme_magnitude` (no prevalence gate) -- see roxygen for why there is
  ## no ordinal analogue of `dominant_loading`.
  tab$runaway_loading <- is.finite(tab$relative_loading) &
    tab$relative_loading >= ordinal_loading_runaway_thresh
  tab$extreme_magnitude <- is.finite(tab$max_loading_unit) &
    tab$max_loading_unit >= ordinal_loading_absolute_thresh
  tab$flag <- tab$runaway_loading | tab$extreme_magnitude

  score <- ifelse(is.finite(tab$relative_loading), tab$relative_loading, -Inf) +
    ifelse(tab$flag, 1000, 0)
  best <- tab[which.max(score), , drop = FALSE]
  any_o1 <- any(tab$runaway_loading)
  any_o2 <- any(tab$extreme_magnitude)
  status <- if (any_o1 || any_o2) "WARN" else "PASS"
  arms <- c(if (any_o1) "O1" else NULL, if (any_o2) "O2" else NULL)

  msg <- if (!identical(status, "WARN")) {
    "ordinal-probit trait loading screen (O1 relative / O2 absolute liability-scale magnitude)"
  } else {
    paste0(
      "ordinal trait loading has run away from the rest (quasi-complete ",
      "category-level separation; see dev/ordinal-degeneracy/probe-criteria.md; arms: ",
      paste(arms, collapse = ","), ")"
    )
  }
  action <- if (!identical(status, "WARN")) {
    "none"
  } else {
    "treat the fit as unusable rather than interpreting it: the S1 probe found this is the same quasi-complete-separation geometry the binomial screen catches (24/24 dichotomised refits fired binomial_prevalence_loading); try gllvmTMBcontrol(loading_ridge = 0.25) (0.25 to 0.5; larger tau shrinks less) to shrink runaway loadings, or gllvmTMBcontrol(integration = 'va') for latent(..., unique = FALSE) fits with at least 100 units and d <= 2 -- either makes the result a penalised (MAP) or variational estimate, so logLik(), AIC() and BIC() no longer apply to it"
  }

  .gllvmTMB_check_row(
    "ordinal_liability_loading",
    status,
    paste0(
      best$trait,
      " max_loading=", .gllvmTMB_fmt_num(best$max_loading),
      "; relative_loading=", .gllvmTMB_fmt_num(best$relative_loading),
      "; max_loading_unit=", .gllvmTMB_fmt_num(best$max_loading_unit),
      "; cutpoint_span=", .gllvmTMB_fmt_num(best$cutpoint_span)
    ),
    paste0(
      "relative_loading >= ", ordinal_loading_runaway_thresh,
      " (O1) or max_loading_unit >= ", ordinal_loading_absolute_thresh,
      " on the link scale (O2); both disarmed at Inf pending the detector-S2 calibration campaign"
    ),
    msg,
    action
  )
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
#'   deviation in link units: a value of this size already implies a
#'   fitted probability indistinguishable from 0 or 1 across an ordinary
#'   swing of the axis. Default 8, raised from 6 (issue #1098) after the
#'   earlier calibration pool (3,944 simulated binomial fits, no healthy
#'   fit above 3.99) turned out to be unrepresentative: its true loading
#'   scale never reached the regime where this arm misfires. A second pool
#'   built specifically to cross `sigma_lambda in c(0.7, 3.0)` (928 healthy
#'   / 272 degenerate binomial-probit fits) -- 3.0 chosen to hit issue
#'   #847's `aghq_ridge` ridge-failure regime, not argued for realism --
#'   measured this arm as the SOLE source of every false positive found
#'   (232/928 at threshold 6, all attributable to this arm alone). Raising
#'   the threshold to 8 lowers the false-positive rate on that pool from
#'   0.2500 to 0.1552 while sensitivity on its degenerate fits falls only
#'   from 1.0000 to 0.9963 (one additional missed fit out of 272). This is
#'   an interim improvement, not a fix. The arm is regime/effect-size
#'   dependent, not response-scale dependent (probit fixes the residual
#'   variance at 1, so there is no free response scale here for a
#'   `tau * sd(y)`-style rescale to absorb): false-positive rate 3.85% at
#'   a mild true loading scale of `sigma_lambda = 0.7` versus 49.08% at
#'   `sigma_lambda = 3.0`, so no fixed constant is correct across loading
#'   scales, and this default should not be read as calibrated against
#'   that regime. `aghq_ridge = 2` reduces but does not remove the problem
#'   (46.0% -> 13.5% false positives at `sigma_lambda = 3.0`). Being a
#'   link-scale quantity it does not transport to families whose response
#'   scale is arbitrary, which is why this row is binomial-only. This gate
#'   applies to every link (`family_id == 1L`), but the calibration above
#'   is probit-only: logit loadings run larger than probit loadings for
#'   the same underlying model (the standard logistic/probit
#'   variance-matching ratio, commonly cited as ~1.6-1.8), so the same
#'   fixed threshold is reached by a smaller true effect on the logit
#'   link, and the false-positive rate measured here should be read as a
#'   lower bound on logit fits, not a transportable number -- no logit
#'   evidence exists in the calibration pool. See
#'   `dev/heywood/fp-scale-dependence.md` for the full mechanism note.
#' @param multinomial_collapse_floor Absolute floor on a `multinomial()`
#'   (fid 16) contrast pseudo-trait's fitted loading energy
#'   (`rowSums(Lambda^2)`), at or below which it is a collapsed contrast.
#'   Default `1e-10`, the campaign code's own guard. Provisional pending the
#'   S3 calibration campaign; labeled evidence: 7/20 `phylo_indep` seeds at
#'   or below `1e-9`, every one reporting `convergence = 0` and a
#'   positive-definite Hessian.
#' @param multinomial_collapse_rel_thresh Threshold on the ratio of the
#'   smallest to the largest fitted contrast loading energy within one
#'   `multinomial()` response's K-1 contrasts, below which the smallest is
#'   flagged as collapsed relative to its siblings. Default `Inf`
#'   (disarmed): those K-1 contrasts are `pi^2/6`-correlated siblings through
#'   their shared baseline category, not the independent siblings
#'   `psi_rel_thresh` was calibrated on, so this arm is provisional pending
#'   the S3 calibration campaign.
#' @param multinomial_rail_thresh Threshold on the largest absolute
#'   off-diagonal correlation of the implied contrast-level covariance
#'   within one `multinomial()` response's contrasts, at or above which two
#'   contrasts are reported as rail-correlated. Only evaluated at tiers with
#'   rank `d >= 2` -- at `d = 1` every healthy fit reaches `|rho| = 1`
#'   exactly by row proportionality. Default `0.99`, provisional pending the
#'   S3 calibration campaign; labeled evidence: 8/20 seeds at or above it.
#' @param multinomial_range_collapse_thresh Threshold on the fitted spatial
#'   practical range (`sqrt(8) / kappa`) relative to the coordinate-domain
#'   diameter (when the fit's mesh coordinates are reachable), or on the
#'   practical range itself in absolute coordinate units (the fallback when
#'   they are not), at or below which a `multinomial()` response's spatial
#'   field is reported as collapsed. Default `0.02`, provisional pending the
#'   S3 calibration campaign; labeled evidence: collapsed ratios 7e-5 to
#'   3.4e-4.
#' @param ordinal_loading_runaway_thresh Threshold on an `ordinal_probit()`
#'   (fid 14) trait's largest loading relative to the typical loading among
#'   the other ordinal traits, at or above which the loading is reported on
#'   its own. Mirrors `loading_runaway_thresh`'s binomial arm. Default `Inf`
#'   (disarmed): the detector-S1 mechanism probe
#'   (`dev/ordinal-degeneracy/probe-criteria.md`) established that degenerate
#'   ordinal fits share binomial's quasi-complete-separation mechanism, but
#'   the threshold itself awaits the detector-S2 calibration campaign.
#' @param ordinal_loading_absolute_thresh Threshold on an `ordinal_probit()`
#'   trait's largest loading on the link (liability) scale, unit tiers only,
#'   at or above which it is reported regardless of the other traits.
#'   Meaningful because the probit-liability residual variance is exactly 1
#'   under the Wright/Falconer/Hadfield threshold convention, so a loading
#'   is the trait's latent standard deviation in liability units, mirroring
#'   `loading_absolute_thresh`'s binomial justification. Default `Inf`
#'   (disarmed pending the detector-S2 calibration campaign).
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
  loading_absolute_thresh = 8,
  multinomial_collapse_floor = 1e-10,
  multinomial_collapse_rel_thresh = Inf,
  multinomial_rail_thresh = 0.99,
  multinomial_range_collapse_thresh = 0.02,
  ordinal_loading_runaway_thresh = Inf,
  ordinal_loading_absolute_thresh = Inf,
  ## R4 (2026-09-02 review): a per-trait NB2 dispersion (fid 5 nbinom2 OR
  ## fid 18 zi_nbinom2, which REUSES the same log_phi_nbinom2 vector) can
  ## run to the Poisson boundary (phi -> Inf) while reporting
  ## convergence = 0, a PD Hessian, and max_gradient well under threshold
  ## -- a small-sample identifiability collapse with NO existing detector
  ## (found on the zi_nbinom2 recovery DGP: phi_hat = 2.66e6 against a
  ## true phi = 6, zero non-PASS rows before this fix). Design 48's own
  ## STARTING-value clamp treats [0.01, 100] as the sane range (R/fit-
  ## multi.R's `.clamp_log_phi()`); two orders of magnitude beyond its
  ## upper bound is unambiguously a runaway, not a plausible large but
  ## real dispersion, hence 1e4.
  phi_nbinom2_ceiling_thresh = 1e4
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
  multinomial_row <- .gllvmTMB_multinomial_degeneracy_row(
    object,
    multinomial_collapse_floor = multinomial_collapse_floor,
    multinomial_collapse_rel_thresh = multinomial_collapse_rel_thresh,
    multinomial_rail_thresh = multinomial_rail_thresh,
    multinomial_range_collapse_thresh = multinomial_range_collapse_thresh
  )
  ordinal_row <- .gllvmTMB_ordinal_degeneracy_row(
    object,
    ordinal_loading_runaway_thresh = ordinal_loading_runaway_thresh,
    ordinal_loading_absolute_thresh = ordinal_loading_absolute_thresh
  )
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
  if (!is.null(multinomial_row)) {
    rows <- c(rows, list(multinomial_row))
  }
  if (!is.null(ordinal_row)) {
    rows <- c(rows, list(ordinal_row))
  }

  psi_specs <- c(
    unit = "sd_B",
    unit_obs = "sd_W",
    phylo = "sd_phy_diag",
    ## `"sd_spde"` was never a REPORTed name (src/gllvmTMB.cpp REPORTs
    ## `sd_spde_unique`, not `sd_spde`), so this row's `nm %in%
    ## names(object$report)` guard below always failed and produced zero
    ## `near_zero_psi_spatial` rows on every spatial fixture -- issue #1119.
    spatial = "sd_spde_unique"
  )
  for (level in names(psi_specs)) {
    nm <- psi_specs[[level]]
    if (!nm %in% names(object$report)) {
      next
    }
    ## `.gllvmTMB_estimable_components()` drops the mapped-off `sd_B` / `sd_W`
    ## placeholders (see its own comment above) before the finite filter, the
    ## minimum, and the sibling set passed to `.gllvmTMB_relative_collapse()`,
    ## so a deliberately-suppressed Psi does not read as a collapsed one.
    ## This screen and `.gllvmTMB_boundary_flags()` below share that FILTER
    ## on the same reported quantity, not the verdict: this loop's
    ## `psi_rel_thresh` (default 1e-2) and boundary_flags's `sd_rel_thresh`
    ## (default 1e-3) are deliberately different thresholds, so the same
    ## fit can PASS one screen and WARN the other.
    val <- .gllvmTMB_estimable_components(object, nm)
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
    mapped_off <- .gllvmTMB_sigma_eps_mapped_off(object)
    scale_names <- if (length(sigma_eps) >= 2L) {
      c("gaussian", "lognormal")
    } else "continuous"
    for (j in seq_along(sigma_eps)) {
      check_id <- if (length(sigma_eps) >= 2L) {
        paste0("boundary_sigma_eps_", scale_names[[j]])
      } else {
        "boundary_sigma_eps"
      }
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          check_id,
          if (isTRUE(mapped_off) || sigma_eps[[j]] >= sigma_eps_thresh) {
            "PASS"
          } else {
            "WARN"
          },
          .gllvmTMB_fmt_num(sigma_eps[[j]], digits = 4L),
          sigma_eps_thresh,
          if (isTRUE(mapped_off)) {
            "sigma_eps is mapped off by the fitted model/family path"
          } else {
            paste0("estimated ", scale_names[[j]], " residual scale")
          },
          "if estimated near zero, check row-level unique terms or residual-scale identifiability"
        ))
      )
    }
  }

  ## Zero-inflated families (fid 17/18/19, Arc D): a boundary-pinned
  ## structural-zero probability means the mixture has effectively
  ## collapsed to its ordinary (zi -> 0) or all-structural (zi -> 1) limit,
  ## which is worth flagging the same way other boundary parameters are.
  zi_report <- as.numeric(object$report$zi %||% numeric(0L))
  fid_zi <- as.integer(object$tmb_data$family_id_vec %||% integer(0L))
  tid_zi <- as.integer(object$tmb_data$trait_id %||% integer(0L))
  zi_traits <- if (length(fid_zi) && length(tid_zi) == length(fid_zi)) {
    sort(unique(tid_zi[fid_zi %in% c(17L, 18L, 19L)]))
  } else {
    integer(0L)
  }
  if (length(zi_traits) > 0L && length(zi_report) >= max(zi_traits) + 1L) {
    trait_names_zi <- .gllvmTMB_trait_names(object)
    for (t in zi_traits) {
      zi_t <- zi_report[t + 1L]
      status_zi <- if (!is.finite(zi_t)) {
        "WARN"
      } else if (zi_t < 0.01 || zi_t > 0.95) {
        "WARN"
      } else {
        "PASS"
      }
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          paste0("boundary_zi_", .gllvmTMB_trait_label(trait_names_zi, t + 1L)),
          status_zi,
          .gllvmTMB_fmt_num(zi_t, digits = 4L),
          "0.01 / 0.95",
          if (!is.finite(zi_t)) {
            "zi (structural-zero probability) is not finite"
          } else if (zi_t < 0.01) {
            "zi has collapsed toward 0: the fit is indistinguishable from the ordinary (non-inflated) count family"
          } else if (zi_t > 0.95) {
            "zi has run toward 1: almost every observation is being explained as a structural zero"
          } else {
            "zi (structural-zero probability) is within the interior of (0, 1)"
          },
          "if pinned at a boundary, consider the plain (non-zi) family, or check for a data-entry issue producing excess zeros"
        ))
      )
    }
  }

  ## NB2 dispersion boundary (fid 5 nbinom2 and fid 18 zi_nbinom2 share
  ## log_phi_nbinom2, R4 above): flag any trait whose ESTIMATED phi (not
  ## masked off, i.e. the trait actually uses one of those two families)
  ## sits at or above the numerical ceiling.
  phi_nbinom2_report <- as.numeric(object$report$phi_nbinom2 %||% numeric(0L))
  fid_phi <- as.integer(object$tmb_data$family_id_vec %||% integer(0L))
  tid_phi <- as.integer(object$tmb_data$trait_id %||% integer(0L))
  phi_nbinom2_traits <- if (length(fid_phi) && length(tid_phi) == length(fid_phi)) {
    sort(unique(tid_phi[fid_phi %in% c(5L, 18L)]))
  } else {
    integer(0L)
  }
  if (length(phi_nbinom2_traits) > 0L &&
      length(phi_nbinom2_report) >= max(phi_nbinom2_traits) + 1L) {
    trait_names_phi <- .gllvmTMB_trait_names(object)
    for (t in phi_nbinom2_traits) {
      phi_t <- phi_nbinom2_report[t + 1L]
      status_phi <- if (!is.finite(phi_t) || phi_t >= phi_nbinom2_ceiling_thresh) {
        "WARN"
      } else {
        "PASS"
      }
      rows <- c(
        rows,
        list(.gllvmTMB_check_row(
          paste0("boundary_phi_nbinom2_", .gllvmTMB_trait_label(trait_names_phi, t + 1L)),
          status_phi,
          .gllvmTMB_fmt_num(phi_t, digits = 4L),
          phi_nbinom2_ceiling_thresh,
          if (!is.finite(phi_t)) {
            "NB2 dispersion (phi) is not finite"
          } else if (phi_t >= phi_nbinom2_ceiling_thresh) {
            "phi has run to the numerical ceiling: the fit is indistinguishable from the Poisson limit (phi -> Inf) for this trait"
          } else {
            "NB2 dispersion (phi) is within the sane range"
          },
          "if phi is at the ceiling, the NB2 overdispersion is not identified for this trait at this sample size; consider poisson()/zi_poisson() instead, or more data"
        ))
      )
    }
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
  out_Sigma_B <- tryCatch(
    .extract_Sigma_legacy_payload(object, level = "unit"),
    error = function(e) NULL
  )
  out_Sigma_W <- tryCatch(
    .extract_Sigma_legacy_payload(object, level = "unit_obs"),
    error = function(e) NULL
  )
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
