## dev/m3-grid.R
## =============
## M3.2 — DGP grid pipeline for empirical coverage validation.
## Implements docs/design/42-m3-dgp-grid.md.
##
## Per-cell DGP recipe (Design 42 §3):
##   1. Sample truth (Lambda_true, psi_true, family-specific nuisance).
##   2. Simulate response (per-family inverse link + sampling).
##   3. Fit gllvmTMB with the matching family + d.
##   4. Compute target-explicit CIs:
##      - profile CIs on per-trait psi (diagnostic target);
##      - optional bootstrap CIs on total Sigma_unit[tt] (primary target).
##   5. Record both legacy profile-psi columns and target-explicit
##      long-form columns so old audit scripts remain readable while the
##      next M3.3 pilot can validate the intended target.
##
## Public entry points:
##   m3_run_cell(family, d, n_reps, seed, ...)
##   m3_run_grid(cells, n_reps, ..., parallel = TRUE)
##
## "Truth" = the simulated Sigma_unit diagonals plus psi
##   Sigma_unit_tt = (Lambda_true %*% t(Lambda_true))_tt + psi_true_t
## Sigma_unit is the canonical rotation-invariant target (per pitfalls
## and Design 42). The 2026-05-19 production grid profiles psi because
## theta_diag_B is the available direct profile target; see the M3.3
## target-scale audit before treating this diagnostic as a promotion gate.
##
## Source from precompute-vignettes.R via `source("dev/m3-grid.R")`.
## This file is in `.Rbuildignore` (dev/ directory) — NOT shipped with
## the package.

## ---- Constants --------------------------------------------------------

M3_FAMILIES <- c("gaussian", "binomial", "nbinom2", "ordinal_probit", "mixed")

M3_DEFAULT_N_UNITS <- 60L
M3_DEFAULT_N_TRAITS <- 5L
M3_DEFAULT_LAMBDA_SCALE <- 1
M3_DEFAULT_PSI_SCALE <- 1
M3_DEFAULT_PHI_SHAPE <- 5
M3_DEFAULT_PHI_RATE <- 5
M3_DEFAULT_NOMINAL <- 0.95
M3_PASS_GATE <- 0.94 # audit-1 exit threshold
M3_INTERVAL_TARGETS <- c("psi", "Sigma_unit_diag")

m3_normalise_targets <- function(targets = "psi") {
  if (is.null(targets) || !length(targets)) {
    targets <- "psi"
  }
  targets <- unique(trimws(as.character(targets)))
  if ("all" %in% targets) {
    targets <- M3_INTERVAL_TARGETS
  }
  unknown <- setdiff(targets, M3_INTERVAL_TARGETS)
  if (length(unknown)) {
    stop("Unknown M3 interval target(s): ", paste(unknown, collapse = ", "))
  }
  targets
}

m3_target_method <- function(target) {
  switch(
    target,
    psi = "profile",
    Sigma_unit_diag = "bootstrap",
    stop("Unknown M3 interval target: ", target)
  )
}

m3_miss_side <- function(truth, lo, hi, covered, ci_available) {
  if (!isTRUE(ci_available)) {
    return("ci_unavailable")
  }
  if (isTRUE(covered)) {
    return("covered")
  }
  if (is.na(truth) || is.na(lo) || is.na(hi)) {
    return("ci_unavailable")
  }
  if (truth < lo) {
    return("truth_below_lower")
  }
  if (truth > hi) {
    return("truth_above_upper")
  }
  "other_miss"
}

m3_bootstrap_supported <- function(fit) {
  fids <- unique(fit$tmb_data$family_id_vec)
  unsupported <- setdiff(fids, 0:5)
  list(ok = length(unsupported) == 0L, unsupported = unsupported)
}

m3_muffle_bootstrap_warning <- function(w) {
  if (
    grepl(
      '`level = "B"` is deprecated as of gllvmTMB 0.2.0',
      conditionMessage(w),
      fixed = TRUE
    )
  ) {
    invokeRestart("muffleWarning")
  }
}

m3_start_method_label <- function(start_method) {
  if (is.null(start_method)) {
    return("default")
  }
  if (is.character(start_method) && length(start_method) == 1L) {
    return(start_method)
  }
  method <- start_method$method
  if (is.null(method) || length(method) == 0L || is.na(method)) {
    return("default")
  }
  as.character(method)
}

m3_start_method_jitter <- function(start_method) {
  if (is.list(start_method) && !is.null(start_method$jitter.sd)) {
    return(as.numeric(start_method$jitter.sd))
  }
  0
}

m3_fit_health_row <- function(fit = NULL, fit_error = NULL) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    return(data.frame(
      fit_error = fit_error %||% NA_character_,
      fit_convergence_code = NA_integer_,
      fit_message = NA_character_,
      fit_objective = NA_real_,
      max_gradient = NA_real_,
      pd_hessian = NA,
      sdreport_ok = NA,
      sdreport_error = NA_character_,
      selected_restart = NA_integer_,
      restart_count = NA_integer_,
      objective_spread = NA_real_,
      boundary_flags = NA_character_,
      stringsAsFactors = FALSE
    ))
  }
  health <- fit$fit_health
  if (is.null(health)) {
    grad <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
    health <- list(
      max_gradient = if (length(grad) == 0L || all(is.na(grad))) {
        NA_real_
      } else {
        max(abs(grad), na.rm = TRUE)
      },
      pd_hessian = if (
        !is.null(fit$sd_report) && !is.null(fit$sd_report$pdHess)
      ) {
        isTRUE(fit$sd_report$pdHess)
      } else {
        NA
      },
      sdreport_ok = !is.null(fit$sd_report),
      sdreport_error = fit$sdreport_error %||% NA_character_,
      selected_restart = NA_integer_,
      boundary_flags = character(0)
    )
  }
  rh <- fit$restart_history %||% data.frame()
  obj <- if (nrow(rh) && "objective" %in% names(rh)) {
    rh$objective[is.finite(rh$objective)]
  } else {
    numeric(0)
  }
  data.frame(
    fit_error = NA_character_,
    fit_convergence_code = fit$opt$convergence %||% NA_integer_,
    fit_message = fit$opt$message %||% NA_character_,
    fit_objective = fit$opt$objective %||% NA_real_,
    max_gradient = health$max_gradient %||% NA_real_,
    pd_hessian = health$pd_hessian %||% NA,
    sdreport_ok = health$sdreport_ok %||% NA,
    sdreport_error = health$sdreport_error %||% NA_character_,
    selected_restart = health$selected_restart %||% NA_integer_,
    restart_count = nrow(rh),
    objective_spread = if (length(obj) >= 2L) max(obj) - min(obj) else NA_real_,
    boundary_flags = paste(
      health$boundary_flags %||% character(0),
      collapse = ";"
    ),
    stringsAsFactors = FALSE
  )
}

m3_add_fit_health <- function(df, diag) {
  cbind(df, diag[rep(1L, nrow(df)), , drop = FALSE])
}

m3_fitted_nbinom2_phi <- function(fit, n_traits) {
  out <- rep(NA_real_, n_traits)
  if (!inherits(fit, "gllvmTMB_multi")) {
    return(out)
  }
  fids <- fit$tmb_data$family_id_vec
  tids <- fit$tmb_data$trait_id + 1L
  phi <- as.numeric(fit$report$phi_nbinom2 %||% rep(NA_real_, n_traits))
  for (t in seq_len(n_traits)) {
    rows_t <- which(tids == t)
    if (length(rows_t) && any(fids[rows_t] == 5L)) {
      out[t] <- if (length(phi) >= t) phi[t] else phi[1L]
    }
  }
  out
}

m3_fitted_link_residual <- function(fit, n_traits) {
  out <- rep(NA_real_, n_traits)
  if (!inherits(fit, "gllvmTMB_multi")) {
    return(out)
  }
  sigma_none <- tryCatch(
    gllvmTMB::extract_Sigma(
      fit,
      level = "unit",
      link_residual = "none"
    ),
    error = function(e) NULL
  )
  sigma_auto <- tryCatch(
    suppressMessages(gllvmTMB::extract_Sigma(
      fit,
      level = "unit",
      link_residual = "auto"
    )),
    error = function(e) NULL
  )
  if (is.null(sigma_none) || is.null(sigma_auto)) {
    return(out)
  }
  diag(sigma_auto$Sigma) - diag(sigma_none$Sigma)
}

## ---- Truth sampler ----------------------------------------------------

m3_sample_truth <- function(
  family,
  d,
  n_traits = M3_DEFAULT_N_TRAITS,
  n_units = M3_DEFAULT_N_UNITS,
  seed,
  lambda_scale = M3_DEFAULT_LAMBDA_SCALE,
  psi_scale = M3_DEFAULT_PSI_SCALE,
  phi = NULL,
  phi_shape = M3_DEFAULT_PHI_SHAPE,
  phi_rate = M3_DEFAULT_PHI_RATE
) {
  stopifnot(family %in% M3_FAMILIES, d >= 1L)
  if (
    !is.numeric(lambda_scale) ||
      length(lambda_scale) != 1L ||
      !is.finite(lambda_scale) ||
      lambda_scale <= 0
  ) {
    stop("lambda_scale must be one positive finite number")
  }
  if (
    !is.numeric(psi_scale) ||
      length(psi_scale) != 1L ||
      !is.finite(psi_scale) ||
      psi_scale <= 0
  ) {
    stop("psi_scale must be one positive finite number")
  }
  if (
    !is.null(phi) &&
      (!is.numeric(phi) || length(phi) != 1L || !is.finite(phi) || phi <= 0)
  ) {
    stop("phi must be NULL or one positive finite number")
  }
  if (
    !is.numeric(phi_shape) ||
      length(phi_shape) != 1L ||
      !is.finite(phi_shape) ||
      phi_shape <= 0
  ) {
    stop("phi_shape must be one positive finite number")
  }
  if (
    !is.numeric(phi_rate) ||
      length(phi_rate) != 1L ||
      !is.finite(phi_rate) ||
      phi_rate <= 0
  ) {
    stop("phi_rate must be one positive finite number")
  }
  set.seed(seed)

  ## Lambda: T x d, uniform on [-1.5, 1.5]
  Lambda <- matrix(
    stats::runif(n_traits * d, -1.5, 1.5),
    nrow = n_traits,
    ncol = d
  ) *
    lambda_scale
  ## psi (per-trait unique variance): Gamma(2, 2) -> mean 1.0, sd 0.7
  psi <- stats::rgamma(n_traits, shape = 2, rate = 2) * psi_scale
  ## Latent factor scores
  Z <- matrix(stats::rnorm(n_units * d), nrow = n_units, ncol = d)

  ## Implied Sigma_unit (T x T): the rotation-invariant target
  Sigma <- tcrossprod(Lambda) + diag(psi, n_traits)
  diag_Sigma <- diag(Sigma)

  ## Family-specific nuisance. Mixed-family populates ALL of them since
  ## it cycles families across trait rows.
  nuisance <- list()
  if (family == "nbinom2" || family == "mixed") {
    nuisance$phi <- phi %||%
      stats::rgamma(1, shape = phi_shape, rate = phi_rate)
  }
  if (family == "ordinal_probit") {
    K <- 4L # n_categories
    nuisance$K <- K
    nuisance$cutpoints <- stats::qnorm(seq_len(K - 1L) / K)
  }
  if (family == "gaussian" || family == "mixed") {
    nuisance$sigma_eps <- 0.5 # Fix residual SD so identifiability is OK
  }

  list(
    Lambda = Lambda,
    psi = psi,
    Z = Z,
    Sigma = Sigma,
    diag_Sigma = diag_Sigma,
    nuisance = nuisance,
    family = family,
    d = d,
    n_units = n_units,
    n_traits = n_traits,
    lambda_scale = lambda_scale,
    psi_scale = psi_scale,
    phi_shape = phi_shape,
    phi_rate = phi_rate
  )
}

## ---- Response simulator -----------------------------------------------

m3_simulate_response <- function(truth) {
  family <- truth$family
  d <- truth$d
  n_units <- truth$n_units
  n_traits <- truth$n_traits
  Lambda <- truth$Lambda
  psi <- truth$psi
  Z <- truth$Z

  ## Linear predictor on the latent scale (no fixed-effect mean here;
  ## the fit estimates a per-trait intercept which absorbs that).
  ## eta = Z %*% Lambda^T + e_unique with e_unique ~ N(0, diag(psi))
  e_unique <- matrix(
    stats::rnorm(n_units * n_traits),
    nrow = n_units,
    ncol = n_traits
  ) *
    matrix(rep(sqrt(psi), each = n_units), nrow = n_units, ncol = n_traits)
  eta <- Z %*% t(Lambda) + e_unique # n_units x n_traits

  ## Apply per-family inverse link + sampling
  Y <- matrix(NA_real_, n_units, n_traits)
  row_family <- character(n_traits) # which family each trait uses

  for (t in seq_len(n_traits)) {
    fam_t <- if (family == "mixed") {
      # Cycle: gauss, binom, nbinom2, gauss, binom, ...
      c("gaussian", "binomial", "nbinom2")[(t - 1L) %% 3L + 1L]
    } else {
      family
    }
    row_family[t] <- fam_t

    eta_t <- eta[, t]
    Y[, t] <- switch(
      fam_t,
      gaussian = eta_t +
        stats::rnorm(n_units, sd = truth$nuisance$sigma_eps %||% 0.5),
      binomial = stats::rbinom(n_units, size = 1L, prob = stats::plogis(eta_t)),
      nbinom2 = {
        ## Clamp eta to [-10, 10] -> mu in [4.5e-5, 22000]; protects
        ## rnbinom against NaN from extreme draws of Lambda x Z.
        mu_t <- exp(pmin(pmax(eta_t, -10), 10))
        phi_t <- truth$nuisance$phi
        stats::rnbinom(n_units, mu = mu_t, size = phi_t) # size = dispersion (TMB convention)
      },
      ordinal_probit = {
        cuts <- truth$nuisance$cutpoints
        K <- truth$nuisance$K
        latent_y <- eta_t + stats::rnorm(n_units)
        ## Assign category: 1 if y < c_1, 2 if c_1 <= y < c_2, ..., K otherwise
        cat <- rep(K, n_units)
        for (k in seq_along(cuts)) {
          cat[latent_y < cuts[k]] <- pmin(cat[latent_y < cuts[k]], k)
        }
        cat
      },
      stop("Unknown family: ", fam_t)
    )
  }

  ## Long-format data frame
  unit_levels <- paste0("u", seq_len(n_units))
  trait_levels <- paste0("t", seq_len(n_traits))

  df <- data.frame(
    unit = factor(rep(unit_levels, each = n_traits), levels = unit_levels),
    trait = factor(rep(trait_levels, times = n_units), levels = trait_levels),
    value = as.numeric(t(Y))
  )

  ## For mixed-family, attach a per-row `family_id` lookup column so
  ## the gllvmTMB() `family = list(...)` + `attr(., 'family_var')`
  ## API can dispatch the per-row family. The column maps every row
  ## (a given trait observation) to that trait's assigned family.
  if (family == "mixed") {
    df$family_id <- factor(
      rep(row_family, times = n_units),
      levels = unique(row_family)
    )
  }

  list(data = df, row_family = row_family)
}

## ---- Helper: NULL-coalesce (R doesn't have this built in) -------------

`%||%` <- function(a, b) if (is.null(a)) b else a

m3_refit_known_nbinom2_phi <- function(
  fit,
  phi,
  optimizer = "nlminb",
  optArgs = list(),
  n_init = 1L,
  init_jitter = 0.3
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    stop("fit must be a gllvmTMB_multi object")
  }
  if (!is.numeric(phi) || length(phi) != 1L || !is.finite(phi) || phi <= 0) {
    stop("phi must be one positive finite number")
  }
  optimizer <- match.arg(optimizer, c("nlminb", "optim"))
  n_init <- as.integer(n_init)
  if (is.na(n_init) || n_init < 1L) {
    stop("n_init must be a positive integer")
  }
  if (
    !is.numeric(init_jitter) ||
      length(init_jitter) != 1L ||
      !is.finite(init_jitter) ||
      init_jitter < 0
  ) {
    stop("init_jitter must be one finite non-negative number")
  }
  if (!any(fit$tmb_data$family_id_vec == 5L)) {
    stop("known NB2 phi refit requires nbinom2 rows")
  }

  params <- fit$tmb_params
  params$log_phi_nbinom2 <- rep(
    log(phi),
    length(params$log_phi_nbinom2)
  )
  map <- fit$tmb_map
  map$log_phi_nbinom2 <- factor(rep(
    NA_integer_,
    length(params$log_phi_nbinom2)
  ))

  obj <- TMB::MakeADFun(
    data = fit$tmb_data,
    parameters = params,
    map = map,
    random = fit$tmb_obj$env$random,
    DLL = "gllvmTMB",
    silent = TRUE
  )

  run_one <- function(par_init) {
    if (identical(optimizer, "optim")) {
      opt_args <- optArgs
      method <- opt_args$method %||% "BFGS"
      opt_args$method <- method
      opt_args$control <- utils::modifyList(
        list(maxit = 2000),
        opt_args$control %||% list()
      )
      raw <- do.call(
        stats::optim,
        c(list(par = par_init, fn = obj$fn, gr = obj$gr), opt_args)
      )
      return(list(
        par = raw$par,
        objective = raw$value,
        convergence = raw$convergence,
        message = raw$message %||% "",
        iterations = unname(raw$counts[["function"]] %||% NA_integer_),
        evaluations = unname(raw$counts[["gradient"]] %||% NA_integer_)
      ))
    }

    nlminb_args <- optArgs
    keep <- names(nlminb_args) %in% c("control", "lower", "upper", "scale")
    nlminb_args <- nlminb_args[keep]
    nlminb_args$control <- utils::modifyList(
      list(eval.max = 2000, iter.max = 1500),
      nlminb_args$control %||% list()
    )
    raw <- do.call(
      stats::nlminb,
      c(
        list(start = par_init, objective = obj$fn, gradient = obj$gr),
        nlminb_args
      )
    )
    list(
      par = raw$par,
      objective = raw$objective,
      convergence = raw$convergence,
      message = raw$message %||% "",
      iterations = raw$iterations %||% NA_integer_,
      evaluations = raw$evaluations %||% NA_integer_
    )
  }

  restart_row <- function(
    restart,
    start_label,
    jitter_sd,
    objective = NA_real_,
    convergence = NA_integer_,
    message = "",
    elapsed_s = NA_real_,
    iterations = NA_integer_,
    evaluations = NA_integer_,
    success = FALSE
  ) {
    data.frame(
      restart = restart,
      start_label = start_label,
      start_method = "known_phi",
      optimizer = optimizer,
      jitter_sd = jitter_sd,
      objective = objective,
      convergence = convergence,
      message = message,
      elapsed_s = elapsed_s,
      iterations = iterations,
      evaluations = evaluations,
      success = success,
      selected = FALSE,
      stringsAsFactors = FALSE
    )
  }

  best_opt <- NULL
  best_obj <- Inf
  restart_history <- vector("list", n_init)
  for (i in seq_len(n_init)) {
    par0 <- if (i == 1L) {
      obj$par
    } else {
      obj$par + stats::rnorm(length(obj$par), sd = init_jitter)
    }
    elapsed_start <- proc.time()[["elapsed"]]
    opt_i <- tryCatch(run_one(par0), error = function(e) e)
    elapsed_s <- proc.time()[["elapsed"]] - elapsed_start
    if (inherits(opt_i, "error")) {
      restart_history[[i]] <- restart_row(
        restart = i,
        start_label = if (i == 1L) "initial" else "jitter",
        jitter_sd = if (i == 1L) 0 else init_jitter,
        message = conditionMessage(opt_i),
        elapsed_s = elapsed_s,
        success = FALSE
      )
      next
    }
    restart_history[[i]] <- restart_row(
      restart = i,
      start_label = if (i == 1L) "initial" else "jitter",
      jitter_sd = if (i == 1L) 0 else init_jitter,
      objective = opt_i$objective,
      convergence = opt_i$convergence %||% NA_integer_,
      message = opt_i$message %||% "",
      elapsed_s = elapsed_s,
      iterations = opt_i$iterations %||% NA_integer_,
      evaluations = opt_i$evaluations %||% NA_integer_,
      success = is.finite(opt_i$objective)
    )
    if (is.finite(opt_i$objective) && opt_i$objective < best_obj) {
      best_obj <- opt_i$objective
      best_opt <- opt_i
    }
  }
  restart_history <- do.call(rbind, restart_history)
  if (is.null(best_opt)) {
    stop("All known-phi restarts failed")
  }
  selected <- which(
    restart_history$success &
      restart_history$objective == best_obj
  )[1L]
  restart_history$selected[selected] <- TRUE

  invisible(obj$fn(best_opt$par))
  obj$env$last.par.best <- obj$env$last.par

  out <- fit
  out$tmb_obj <- obj
  out$tmb_params <- params
  out$tmb_map <- map
  out$opt <- best_opt
  out$report <- obj$report()
  out$sd_report <- NULL
  out$sdreport_error <- paste0(
    "standard-error calculation skipped by M3 known-phi diagnostic refit; ",
    "log_phi_nbinom2 fixed at log(",
    signif(phi, 6),
    ")"
  )
  out$restart_history <- restart_history
  out$start_provenance$known_phi_nbinom2 <- TRUE
  out$start_provenance$known_phi_value <- phi
  out$start_provenance$selected_restart <- restart_history$restart[selected]
  out$fit_health <- getFromNamespace(
    ".gllvmTMB_build_fit_health",
    "gllvmTMB"
  )(out)
  out
}

## ---- Per-cell driver --------------------------------------------------

m3_run_cell <- function(
  family,
  d,
  n_reps = 10L,
  seed_base = 42L,
  n_units = M3_DEFAULT_N_UNITS,
  n_traits = M3_DEFAULT_N_TRAITS,
  lambda_scale = M3_DEFAULT_LAMBDA_SCALE,
  psi_scale = M3_DEFAULT_PSI_SCALE,
  phi = NULL,
  phi_shape = M3_DEFAULT_PHI_SHAPE,
  phi_rate = M3_DEFAULT_PHI_RATE,
  init_strategy = "default",
  start_method = list(method = NULL, jitter.sd = 0),
  optimizer = "nlminb",
  optArgs = list(),
  n_init = 1L,
  init_jitter = 0.3,
  se = TRUE,
  fit_phi_mode = c("estimated", "known"),
  targets = "psi",
  n_boot = 30L,
  n_cores_boot = 1L,
  ci_level = M3_DEFAULT_NOMINAL,
  verbose = TRUE
) {
  stopifnot(family %in% M3_FAMILIES, d >= 1L, n_reps >= 1L)
  if (
    !is.numeric(lambda_scale) ||
      length(lambda_scale) != 1L ||
      !is.finite(lambda_scale) ||
      lambda_scale <= 0
  ) {
    stop("lambda_scale must be one positive finite number")
  }
  if (
    !is.numeric(psi_scale) ||
      length(psi_scale) != 1L ||
      !is.finite(psi_scale) ||
      psi_scale <= 0
  ) {
    stop("psi_scale must be one positive finite number")
  }
  if (
    !is.null(phi) &&
      (!is.numeric(phi) || length(phi) != 1L || !is.finite(phi) || phi <= 0)
  ) {
    stop("phi must be NULL or one positive finite number")
  }
  if (
    !is.numeric(phi_shape) ||
      length(phi_shape) != 1L ||
      !is.finite(phi_shape) ||
      phi_shape <= 0
  ) {
    stop("phi_shape must be one positive finite number")
  }
  if (
    !is.numeric(phi_rate) ||
      length(phi_rate) != 1L ||
      !is.finite(phi_rate) ||
      phi_rate <= 0
  ) {
    stop("phi_rate must be one positive finite number")
  }
  init_strategy <- match.arg(init_strategy, c("default", "single_trait_warmup"))
  optimizer <- match.arg(optimizer, c("nlminb", "optim"))
  fit_phi_mode <- match.arg(fit_phi_mode)
  if (!identical(fit_phi_mode, "estimated") && !identical(family, "nbinom2")) {
    stop("fit_phi_mode = 'known' is only supported for family = 'nbinom2'")
  }
  n_init <- as.integer(n_init)
  if (is.na(n_init) || n_init < 1L) {
    stop("n_init must be a positive integer")
  }
  if (
    !is.numeric(init_jitter) ||
      length(init_jitter) != 1L ||
      !is.finite(init_jitter) ||
      init_jitter < 0
  ) {
    stop("init_jitter must be one finite non-negative number")
  }
  if (!is.logical(se) || length(se) != 1L || is.na(se)) {
    stop("se must be TRUE or FALSE")
  }
  targets <- m3_normalise_targets(targets)
  n_boot <- as.integer(n_boot)
  if (is.na(n_boot) || n_boot < 0L) {
    stop("n_boot must be a non-negative integer")
  }
  n_cores_boot <- as.integer(n_cores_boot)
  if (is.na(n_cores_boot) || n_cores_boot < 1L) {
    stop("n_cores_boot must be a positive integer")
  }
  if (
    !is.numeric(ci_level) ||
      length(ci_level) != 1L ||
      ci_level <= 0 ||
      ci_level >= 1
  ) {
    stop("ci_level must be a single number in (0, 1)")
  }
  cell_id <- sprintf("%s-d%d", family, d)
  if (verbose) {
    cat(sprintf(
      "[m3] cell %s, %d reps; targets = %s\n",
      cell_id,
      n_reps,
      paste(targets, collapse = ",")
    ))
  }

  rows <- vector("list", n_reps)
  for (r in seq_len(n_reps)) {
    rep_seed <- seed_base + 1000L * d + 100000L * match(family, M3_FAMILIES) + r
    t0 <- Sys.time()

    truth <- m3_sample_truth(
      family,
      d,
      n_traits = n_traits,
      n_units = n_units,
      seed = rep_seed,
      lambda_scale = lambda_scale,
      psi_scale = psi_scale,
      phi = phi,
      phi_shape = phi_shape,
      phi_rate = phi_rate
    )
    sim <- m3_simulate_response(truth)

    ## Family list for mixed-family fits.
    ## gllvmTMB needs the family helpers (function calls), not strings,
    ## for the non-base families.
    ## For mixed-family: list ELEMENTS NAMED by the row-family string;
    ## `attr(family_list, 'family_var') <- 'family_id'` directs the
    ## engine to look up the per-row family from the `family_id`
    ## column in the data frame. Matches the M1 mixed-family fixture
    ## pattern (inst/extdata/mixed-family-fixture.rds).
    fam_list <- if (family == "mixed") {
      unique_families <- unique(sim$row_family)
      fl <- lapply(unique_families, function(f) {
        switch(
          f,
          gaussian = stats::gaussian(),
          binomial = stats::binomial(),
          nbinom2 = gllvmTMB::nbinom2()
        )
      })
      names(fl) <- unique_families
      attr(fl, "family_var") <- "family_id"
      fl
    } else {
      switch(
        family,
        gaussian = stats::gaussian(),
        binomial = stats::binomial(),
        nbinom2 = gllvmTMB::nbinom2(),
        ordinal_probit = gllvmTMB::ordinal_probit(),
        stop("Unknown family: ", family)
      )
    }

    fit_ok <- TRUE
    fit <- tryCatch(
      withCallingHandlers(
        gllvmTMB::gllvmTMB(
          value ~ 0 +
            trait +
            latent(0 + trait | unit, d = d) +
            unique(0 + trait | unit),
          data = sim$data,
          family = fam_list,
          unit = "unit",
          ## Keep the third grouping at the default placeholder. Setting
          ## cluster = "unit" makes the same `unique(... | unit)` term also
          ## activate the cluster diagonal tier (`diag_species`), which is
          ## not part of the M3 latent + unique DGP.
          control = gllvmTMB::gllvmTMBcontrol(
            init_strategy = init_strategy,
            start_method = start_method,
            optimizer = optimizer,
            optArgs = optArgs,
            n_init = n_init,
            init_jitter = init_jitter,
            se = se
          )
        ),
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = function(e) {
        fit_ok <<- FALSE
        e
      }
    )
    fit_diag <- m3_fit_health_row(
      if (inherits(fit, "gllvmTMB_multi")) fit else NULL,
      fit_error = if (inherits(fit, "error")) {
        conditionMessage(fit)
      } else {
        NA_character_
      }
    )

    if (
      fit_ok &&
        inherits(fit, "gllvmTMB_multi") &&
        fit$opt$convergence == 0L &&
        identical(fit_phi_mode, "known")
    ) {
      fit <- tryCatch(
        m3_refit_known_nbinom2_phi(
          fit,
          phi = truth$nuisance$phi,
          optimizer = optimizer,
          optArgs = optArgs,
          n_init = n_init,
          init_jitter = init_jitter
        ),
        error = function(e) {
          fit_ok <<- FALSE
          e
        }
      )
      fit_diag <- m3_fit_health_row(
        if (inherits(fit, "gllvmTMB_multi")) fit else NULL,
        fit_error = if (inherits(fit, "error")) {
          conditionMessage(fit)
        } else {
          NA_character_
        }
      )
    }

    rep_runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    if (
      !fit_ok || !inherits(fit, "gllvmTMB_multi") || fit$opt$convergence != 0L
    ) {
      rows[[r]] <- m3_add_fit_health(
        do.call(
          rbind,
          lapply(targets, function(target) {
            data.frame(
              cell = cell_id,
              family = family,
              d = d,
              rep = r,
              trait_id = NA_integer_,
              truth_diag_sigma = NA_real_,
              truth_psi = NA_real_,
              est_diag_sigma = NA_real_,
              est_psi = NA_real_,
              est_phi_nbinom2 = NA_real_,
              est_link_residual = NA_real_,
              ci_prof_lo = NA_real_,
              ci_prof_hi = NA_real_,
              covered_prof = NA,
              converged = FALSE,
              target = target,
              truth = NA_real_,
              estimate = NA_real_,
              ci_method = m3_target_method(target),
              ci_level = ci_level,
              ci_lo = NA_real_,
              ci_hi = NA_real_,
              covered = NA,
              ci_available = FALSE,
              fit_converged = FALSE,
              ci_failed = TRUE,
              miss_side = "fit_failed",
              n_boot = NA_integer_,
              n_boot_failed = NA_integer_,
              n_cores_boot = NA_integer_,
              init_strategy = init_strategy,
              start_method = m3_start_method_label(start_method),
              start_method_jitter_sd = m3_start_method_jitter(start_method),
              optimizer = optimizer,
              n_init = n_init,
              init_jitter = init_jitter,
              fit_phi_mode = fit_phi_mode,
              n_units = n_units,
              n_traits = n_traits,
              lambda_scale = lambda_scale,
              psi_scale = psi_scale,
              truth_phi = truth$nuisance$phi %||% NA_real_,
              se = se,
              seed_base = seed_base,
              rep_seed = rep_seed,
              runtime_s = rep_runtime,
              stringsAsFactors = FALSE
            )
          })
        ),
        fit_diag
      )
      if (verbose && r %% 5L == 0L) {
        cat(sprintf("  rep %d/%d (failed)\n", r, n_reps))
      }
      next
    }

    ## M3.3a — Profile-likelihood CIs on per-trait `sd_B` (unique-tier
    ## SD). `sd_B[t]^2 = psi_t` is the per-trait unique variance.
    ## Compare CI against `truth$psi[t]` (the simulated unique variance).
    ## After the 2026-05-19 target-scale audit this is treated as a
    ## diagnostic target; total `Sigma_unit` coverage remains the primary
    ## rotation-invariant validation target for promotion.
    ##
    ## Per Design 44 corrected estimate: tmbprofile_wrapper() uses
    ## TMB's C++ inner optim warm-started from the joint MLE — ~0.5 s
    ## per CI on a 1.5 s fit, NOT 20-40x the fit cost.
    ##
    ## Lambda contribution to the Sigma_unit diagonal is rotation-
    ## ambiguous on individual loading entries; communality CI via
    ## extract_communality(method="profile") covers the
    ## Lambda Lambda^T diag part — deferred to M3.5 (derived-quantity
    ## coverage).
    ## M3 validates the fitted latent+unique unit-tier covariance against
    ## truth$diag_Sigma = diag(Lambda Lambda^T + Psi). Do not add the
    ## family/link observation residual here; that is a different marginal
    ## response-scale target handled by extract_Sigma(link_residual = "auto").
    est_diag <- diag(
      gllvmTMB::extract_Sigma(
        fit,
        level = "unit",
        link_residual = "none"
      )$Sigma
    )
    est_psi <- as.numeric(fit$report$sd_B)^2
    est_phi_nbinom2 <- m3_fitted_nbinom2_phi(fit, n_traits)
    est_link_residual <- m3_fitted_link_residual(fit, n_traits)

    rep_rows <- list()

    if ("psi" %in% targets) {
      prof_lo <- rep(NA_real_, n_traits)
      prof_hi <- rep(NA_real_, n_traits)
      for (t in seq_len(n_traits)) {
        ci_t <- tryCatch(
          gllvmTMB::tmbprofile_wrapper(
            fit,
            name = "theta_diag_B",
            which = t,
            transform = function(x) exp(2 * x),
            level = ci_level
          ),
          error = function(e) {
            c(estimate = NA_real_, lower = NA_real_, upper = NA_real_)
          }
        )
        prof_lo[t] <- ci_t["lower"]
        prof_hi[t] <- ci_t["upper"]
      }

      for (t in seq_len(n_traits)) {
        psi_truth <- truth$psi[t]
        ci_available <- !is.na(prof_lo[t]) && !is.na(prof_hi[t])
        covered_prof <- ci_available &&
          psi_truth >= prof_lo[t] &&
          psi_truth <= prof_hi[t]
        rep_rows[[length(rep_rows) + 1L]] <- data.frame(
          cell = cell_id,
          family = family,
          d = d,
          rep = r,
          trait_id = t,
          truth_diag_sigma = truth$diag_Sigma[t],
          truth_psi = psi_truth,
          est_diag_sigma = est_diag[t],
          est_psi = est_psi[t],
          est_phi_nbinom2 = est_phi_nbinom2[t],
          est_link_residual = est_link_residual[t],
          ci_prof_lo = prof_lo[t],
          ci_prof_hi = prof_hi[t],
          covered_prof = covered_prof,
          converged = TRUE,
          target = "psi",
          truth = psi_truth,
          estimate = est_psi[t],
          ci_method = "profile",
          ci_level = ci_level,
          ci_lo = prof_lo[t],
          ci_hi = prof_hi[t],
          covered = covered_prof,
          ci_available = ci_available,
          fit_converged = TRUE,
          ci_failed = !ci_available,
          miss_side = m3_miss_side(
            psi_truth,
            prof_lo[t],
            prof_hi[t],
            covered_prof,
            ci_available
          ),
          n_boot = NA_integer_,
          n_boot_failed = NA_integer_,
          n_cores_boot = NA_integer_,
          init_strategy = init_strategy,
          start_method = m3_start_method_label(start_method),
          start_method_jitter_sd = m3_start_method_jitter(start_method),
          optimizer = optimizer,
          n_init = n_init,
          init_jitter = init_jitter,
          fit_phi_mode = fit_phi_mode,
          n_units = n_units,
          n_traits = n_traits,
          lambda_scale = lambda_scale,
          psi_scale = psi_scale,
          truth_phi = truth$nuisance$phi %||% NA_real_,
          se = se,
          seed_base = seed_base,
          rep_seed = rep_seed,
          runtime_s = rep_runtime,
          stringsAsFactors = FALSE
        )
      }
    }

    if ("Sigma_unit_diag" %in% targets) {
      boot_ok <- m3_bootstrap_supported(fit)
      boot <- NULL
      if (boot_ok$ok && n_boot > 0L) {
        boot <- tryCatch(
          suppressMessages(withCallingHandlers(
            gllvmTMB::bootstrap_Sigma(
              fit,
              n_boot = n_boot,
              level = "unit",
              what = "Sigma",
              conf = ci_level,
              link_residual = "none",
              seed = rep_seed + 9000000L,
              n_cores = n_cores_boot,
              progress = FALSE
            ),
            warning = m3_muffle_bootstrap_warning
          )),
          error = function(e) NULL
        )
      }
      boot_available <- !is.null(boot) &&
        !is.null(boot$ci_lower$Sigma_B) &&
        !is.null(boot$ci_upper$Sigma_B)
      sig_lo <- if (boot_available) {
        diag(boot$ci_lower$Sigma_B)
      } else {
        rep(NA_real_, n_traits)
      }
      sig_hi <- if (boot_available) {
        diag(boot$ci_upper$Sigma_B)
      } else {
        rep(NA_real_, n_traits)
      }
      n_boot_failed <- if (boot_available) {
        boot$n_failed
      } else if (n_boot == 0L) {
        0L
      } else {
        NA_integer_
      }

      for (t in seq_len(n_traits)) {
        sig_truth <- truth$diag_Sigma[t]
        ci_available <- boot_available &&
          !is.na(sig_lo[t]) &&
          !is.na(sig_hi[t])
        covered_sig <- ci_available &&
          sig_truth >= sig_lo[t] &&
          sig_truth <= sig_hi[t]
        miss_side <- if (!boot_ok$ok) {
          paste0(
            "unsupported_family_id_",
            paste(boot_ok$unsupported, collapse = "_")
          )
        } else {
          m3_miss_side(
            sig_truth,
            sig_lo[t],
            sig_hi[t],
            covered_sig,
            ci_available
          )
        }
        rep_rows[[length(rep_rows) + 1L]] <- data.frame(
          cell = cell_id,
          family = family,
          d = d,
          rep = r,
          trait_id = t,
          truth_diag_sigma = sig_truth,
          truth_psi = truth$psi[t],
          est_diag_sigma = est_diag[t],
          est_psi = est_psi[t],
          est_phi_nbinom2 = est_phi_nbinom2[t],
          est_link_residual = est_link_residual[t],
          ci_prof_lo = NA_real_,
          ci_prof_hi = NA_real_,
          covered_prof = NA,
          converged = TRUE,
          target = "Sigma_unit_diag",
          truth = sig_truth,
          estimate = est_diag[t],
          ci_method = "bootstrap",
          ci_level = ci_level,
          ci_lo = sig_lo[t],
          ci_hi = sig_hi[t],
          covered = covered_sig,
          ci_available = ci_available,
          fit_converged = TRUE,
          ci_failed = !ci_available,
          miss_side = miss_side,
          n_boot = n_boot,
          n_boot_failed = n_boot_failed,
          n_cores_boot = n_cores_boot,
          init_strategy = init_strategy,
          start_method = m3_start_method_label(start_method),
          start_method_jitter_sd = m3_start_method_jitter(start_method),
          optimizer = optimizer,
          n_init = n_init,
          init_jitter = init_jitter,
          fit_phi_mode = fit_phi_mode,
          n_units = n_units,
          n_traits = n_traits,
          lambda_scale = lambda_scale,
          psi_scale = psi_scale,
          truth_phi = truth$nuisance$phi %||% NA_real_,
          se = se,
          seed_base = seed_base,
          rep_seed = rep_seed,
          runtime_s = rep_runtime,
          stringsAsFactors = FALSE
        )
      }
    }

    rep_runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    rows[[r]] <- m3_add_fit_health(do.call(rbind, rep_rows), fit_diag)
    rows[[r]]$runtime_s <- rep_runtime

    if (verbose && (r %% 5L == 0L || r == n_reps)) {
      cat(sprintf("  rep %d/%d (%.1fs)\n", r, n_reps, rep_runtime))
    }
  }

  do.call(rbind, rows)
}

## ---- Grid driver ------------------------------------------------------

m3_run_grid <- function(
  cells = NULL,
  n_reps = 10L,
  seed_base = 42L,
  n_units = M3_DEFAULT_N_UNITS,
  n_traits = M3_DEFAULT_N_TRAITS,
  lambda_scale = M3_DEFAULT_LAMBDA_SCALE,
  psi_scale = M3_DEFAULT_PSI_SCALE,
  phi = NULL,
  phi_shape = M3_DEFAULT_PHI_SHAPE,
  phi_rate = M3_DEFAULT_PHI_RATE,
  init_strategy = "default",
  start_method = list(method = NULL, jitter.sd = 0),
  optimizer = "nlminb",
  optArgs = list(),
  n_init = 1L,
  init_jitter = 0.3,
  se = TRUE,
  fit_phi_mode = c("estimated", "known"),
  targets = "psi",
  n_boot = 30L,
  n_cores_boot = 1L,
  ci_level = M3_DEFAULT_NOMINAL,
  parallel = FALSE
) {
  init_strategy <- match.arg(init_strategy, c("default", "single_trait_warmup"))
  optimizer <- match.arg(optimizer, c("nlminb", "optim"))
  fit_phi_mode <- match.arg(fit_phi_mode)
  targets <- m3_normalise_targets(targets)
  if (is.null(cells)) {
    cells <- expand.grid(
      family = M3_FAMILIES,
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    )
  }
  stopifnot(is.data.frame(cells), all(c("family", "d") %in% names(cells)))

  rows <- vector("list", nrow(cells))

  if (parallel && requireNamespace("future.apply", quietly = TRUE)) {
    rows <- future.apply::future_lapply(
      seq_len(nrow(cells)),
      function(i) {
        m3_run_cell(
          cells$family[i],
          cells$d[i],
          n_reps = n_reps,
          seed_base = seed_base,
          n_units = n_units,
          n_traits = n_traits,
          lambda_scale = lambda_scale,
          psi_scale = psi_scale,
          phi = phi,
          phi_shape = phi_shape,
          phi_rate = phi_rate,
          init_strategy = init_strategy,
          start_method = start_method,
          optimizer = optimizer,
          optArgs = optArgs,
          n_init = n_init,
          init_jitter = init_jitter,
          se = se,
          fit_phi_mode = fit_phi_mode,
          targets = targets,
          n_boot = n_boot,
          n_cores_boot = n_cores_boot,
          ci_level = ci_level,
          verbose = FALSE
        )
      },
      future.seed = TRUE
    )
  } else {
    for (i in seq_len(nrow(cells))) {
      rows[[i]] <- m3_run_cell(
        cells$family[i],
        cells$d[i],
        n_reps = n_reps,
        seed_base = seed_base,
        n_units = n_units,
        n_traits = n_traits,
        lambda_scale = lambda_scale,
        psi_scale = psi_scale,
        phi = phi,
        phi_shape = phi_shape,
        phi_rate = phi_rate,
        init_strategy = init_strategy,
        start_method = start_method,
        optimizer = optimizer,
        optArgs = optArgs,
        n_init = n_init,
        init_jitter = init_jitter,
        se = se,
        fit_phi_mode = fit_phi_mode,
        targets = targets,
        n_boot = n_boot,
        n_cores_boot = n_cores_boot,
        ci_level = ci_level,
        verbose = TRUE
      )
    }
  }

  do.call(rbind, rows)
}

## ---- Summary -----------------------------------------------------------

m3_pilot_status <- function(
  coverage,
  n_ci_missing,
  n_trait_rows,
  n_failed,
  n_reps,
  family,
  miss_below,
  miss_above,
  n_boot_failed = 0L,
  n_boot_attempted = 0L
) {
  fail_rate <- if (n_reps > 0L) n_failed / n_reps else 1
  fail_limit <- if (identical(family, "mixed")) 0.30 else 0.20
  boot_fail_rate <- if (n_boot_attempted > 0L) {
    n_boot_failed / n_boot_attempted
  } else {
    0
  }
  missing_rate <- if (n_trait_rows > 0L) n_ci_missing / n_trait_rows else 1
  total_miss <- miss_below + miss_above
  one_sided <- total_miss > 0L &&
    max(miss_below, miss_above) / total_miss >= 0.80

  if (
    fail_rate > fail_limit ||
      boot_fail_rate > fail_limit ||
      missing_rate > 0.10 ||
      is.na(coverage)
  ) {
    return("COMPUTE_FAIL")
  }
  if (coverage >= 0.90 && !one_sided) {
    return("PASS_TO_SCALE")
  }
  if (coverage < 0.85 || one_sided) {
    return("TARGET_FAIL")
  }
  "TARGET_FAIL"
}

m3_summarise <- function(grid_df, gate = M3_PASS_GATE) {
  if (!"target" %in% names(grid_df)) {
    ## Legacy M3.2 / first-production artifacts.
    by_cell <- split(
      grid_df,
      list(grid_df$cell),
      drop = TRUE
    )
    out <- do.call(
      rbind,
      lapply(by_cell, function(sub) {
        rep_status <- split(sub$converged, sub$rep, drop = TRUE)
        rep_converged <- vapply(rep_status, all, logical(1))
        rep_runtime <- tapply(sub$runtime_s, sub$rep, max, na.rm = TRUE)
        conv_rows <- sub[!is.na(sub$covered_prof), , drop = FALSE]
        coverage_prof <- if (nrow(conv_rows)) {
          mean(conv_rows$covered_prof, na.rm = TRUE)
        } else {
          NA_real_
        }
        data.frame(
          cell = sub$cell[1],
          family = sub$family[1],
          d = sub$d[1],
          n_completed = sum(rep_converged),
          n_failed = sum(!rep_converged),
          coverage_prof = coverage_prof,
          passes_94pct_prof = !is.na(coverage_prof) && coverage_prof >= gate,
          mean_runtime_s = mean(rep_runtime, na.rm = TRUE),
          stringsAsFactors = FALSE
        )
      })
    )
    rownames(out) <- NULL
    return(out)
  }

  ## Group by (cell, family, d), count failed replicates before
  ## dropping rows with unavailable CIs, then compute target-specific
  ## coverage on converged trait rows.
  split_keys <- list(grid_df$cell, grid_df$target, grid_df$ci_method)
  if ("fit_phi_mode" %in% names(grid_df)) {
    split_keys <- c(list(grid_df$fit_phi_mode), split_keys)
  }
  if ("scenario" %in% names(grid_df)) {
    split_keys <- c(list(grid_df$scenario), split_keys)
  }
  by_cell <- split(grid_df, split_keys, drop = TRUE)
  out <- do.call(
    rbind,
    lapply(by_cell, function(sub) {
      fit_converged <- if ("fit_converged" %in% names(sub)) {
        sub$fit_converged
      } else {
        sub$converged
      }
      rep_status <- split(fit_converged, sub$rep, drop = TRUE)
      rep_converged <- vapply(rep_status, all, logical(1))
      rep_runtime <- tapply(sub$runtime_s, sub$rep, max, na.rm = TRUE)

      trait_rows <- sub[
        fit_converged & !is.na(sub$trait_id),
        ,
        drop = FALSE
      ]
      ci_available <- if ("ci_available" %in% names(trait_rows)) {
        trait_rows$ci_available
      } else {
        !is.na(trait_rows$covered_prof)
      }
      available_rows <- trait_rows[
        ci_available & !is.na(trait_rows$covered),
        ,
        drop = FALSE
      ]
      coverage <- if (nrow(available_rows)) {
        mean(available_rows$covered, na.rm = TRUE)
      } else {
        NA_real_
      }
      miss_side <- if ("miss_side" %in% names(trait_rows)) {
        trait_rows$miss_side
      } else {
        rep(NA_character_, nrow(trait_rows))
      }
      miss_below <- sum(miss_side == "truth_below_lower", na.rm = TRUE)
      miss_above <- sum(miss_side == "truth_above_upper", na.rm = TRUE)
      ratio_rows <- trait_rows[
        is.finite(trait_rows$truth) &
          is.finite(trait_rows$estimate) &
          trait_rows$truth != 0,
        ,
        drop = FALSE
      ]
      median_est_truth_ratio <- if (nrow(ratio_rows)) {
        stats::median(ratio_rows$estimate / ratio_rows$truth, na.rm = TRUE)
      } else {
        NA_real_
      }
      phi_ratio_rows <- if (
        all(c("est_phi_nbinom2", "truth_phi") %in% names(trait_rows))
      ) {
        trait_rows[
          is.finite(trait_rows$est_phi_nbinom2) &
            is.finite(trait_rows$truth_phi) &
            trait_rows$truth_phi != 0,
          ,
          drop = FALSE
        ]
      } else {
        trait_rows[FALSE, , drop = FALSE]
      }
      median_est_phi_truth_ratio <- if (nrow(phi_ratio_rows)) {
        stats::median(
          phi_ratio_rows$est_phi_nbinom2 / phi_ratio_rows$truth_phi,
          na.rm = TRUE
        )
      } else {
        NA_real_
      }
      link_residual_rows <- if ("est_link_residual" %in% names(trait_rows)) {
        trait_rows[
          is.finite(trait_rows$est_link_residual),
          ,
          drop = FALSE
        ]
      } else {
        trait_rows[FALSE, , drop = FALSE]
      }
      median_est_link_residual <- if (nrow(link_residual_rows)) {
        stats::median(link_residual_rows$est_link_residual, na.rm = TRUE)
      } else {
        NA_real_
      }
      link_truth_rows <- link_residual_rows[
        is.finite(link_residual_rows$truth) & link_residual_rows$truth != 0,
        ,
        drop = FALSE
      ]
      median_link_residual_truth_ratio <- if (nrow(link_truth_rows)) {
        stats::median(
          link_truth_rows$est_link_residual / link_truth_rows$truth,
          na.rm = TRUE
        )
      } else {
        NA_real_
      }
      n_reps <- length(rep_status)
      n_failed <- sum(!rep_converged)
      n_trait_rows <- nrow(trait_rows)
      n_ci_missing <- sum(!ci_available, na.rm = TRUE)
      if ("n_boot_failed" %in% names(sub) && "n_boot" %in% names(sub)) {
        boot_by_rep <- split(sub, sub$rep, drop = TRUE)
        rep_boot_failed <- vapply(
          boot_by_rep,
          function(rep_df) {
            x <- rep_df$n_boot_failed
            if (all(is.na(x))) 0 else max(x, na.rm = TRUE)
          },
          numeric(1)
        )
        rep_boot_attempted <- vapply(
          boot_by_rep,
          function(rep_df) {
            x <- rep_df$n_boot
            if (all(is.na(x))) 0 else max(x, na.rm = TRUE)
          },
          numeric(1)
        )
        n_boot_failed <- sum(rep_boot_failed, na.rm = TRUE)
        n_boot_attempted <- sum(rep_boot_attempted, na.rm = TRUE)
      } else {
        n_boot_failed <- 0
        n_boot_attempted <- 0
      }
      boot_fail_rate <- if (n_boot_attempted > 0) {
        n_boot_failed / n_boot_attempted
      } else {
        0
      }
      rep_first <- sub[!duplicated(sub$rep), , drop = FALSE]
      pd_hessian_rate <- if ("pd_hessian" %in% names(rep_first)) {
        x <- rep_first$pd_hessian
        if (all(is.na(x))) NA_real_ else mean(x %in% TRUE)
      } else {
        NA_real_
      }
      sdreport_ok_rate <- if ("sdreport_ok" %in% names(rep_first)) {
        x <- rep_first$sdreport_ok
        if (all(is.na(x))) NA_real_ else mean(x %in% TRUE)
      } else {
        NA_real_
      }
      median_max_gradient <- if ("max_gradient" %in% names(rep_first)) {
        stats::median(rep_first$max_gradient, na.rm = TRUE)
      } else {
        NA_real_
      }
      median_restart_count <- if ("restart_count" %in% names(rep_first)) {
        stats::median(rep_first$restart_count, na.rm = TRUE)
      } else {
        NA_real_
      }
      median_objective_spread <- if ("objective_spread" %in% names(rep_first)) {
        stats::median(rep_first$objective_spread, na.rm = TRUE)
      } else {
        NA_real_
      }
      pilot_status <- m3_pilot_status(
        coverage = coverage,
        n_ci_missing = n_ci_missing,
        n_trait_rows = n_trait_rows,
        n_failed = n_failed,
        n_reps = n_reps,
        family = sub$family[1],
        miss_below = miss_below,
        miss_above = miss_above,
        n_boot_failed = n_boot_failed,
        n_boot_attempted = n_boot_attempted
      )
      coverage_prof <- if (
        identical(sub$target[1], "psi") &&
          identical(sub$ci_method[1], "profile")
      ) {
        coverage
      } else {
        NA_real_
      }
      row <- data.frame(
        cell = sub$cell[1],
        family = sub$family[1],
        d = sub$d[1],
        target = sub$target[1],
        ci_method = sub$ci_method[1],
        n_reps = n_reps,
        n_completed = sum(rep_converged),
        n_failed = n_failed,
        n_trait_rows = n_trait_rows,
        n_ci_missing = n_ci_missing,
        n_boot_failed = n_boot_failed,
        n_boot_attempted = n_boot_attempted,
        boot_fail_rate = boot_fail_rate,
        pd_hessian_rate = pd_hessian_rate,
        sdreport_ok_rate = sdreport_ok_rate,
        median_max_gradient = median_max_gradient,
        median_restart_count = median_restart_count,
        median_objective_spread = median_objective_spread,
        coverage = coverage,
        miss_below = miss_below,
        miss_above = miss_above,
        median_est_truth_ratio = median_est_truth_ratio,
        median_est_phi_truth_ratio = median_est_phi_truth_ratio,
        median_est_link_residual = median_est_link_residual,
        median_link_residual_truth_ratio = median_link_residual_truth_ratio,
        mean_runtime_s = mean(rep_runtime, na.rm = TRUE),
        pilot_status = pilot_status,
        coverage_prof = coverage_prof,
        passes_94pct_prof = !is.na(coverage_prof) && coverage_prof >= gate,
        stringsAsFactors = FALSE
      )
      if ("scenario" %in% names(sub)) {
        row <- data.frame(
          scenario = sub$scenario[1],
          row,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
      if ("fit_phi_mode" %in% names(sub)) {
        row <- data.frame(
          fit_phi_mode = sub$fit_phi_mode[1],
          row,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
      row
    })
  )
  rownames(out) <- NULL
  out
}
