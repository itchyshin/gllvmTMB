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

M3_FAMILIES <- c(
  "gaussian",
  "binomial",
  "nbinom2",
  "ordinal_probit",
  "mixed",
  "binomial_probit"
)
M3_CONTROL_FAMILIES <- c("poisson")
M3_SUPPORTED_FAMILIES <- unique(c(M3_FAMILIES, M3_CONTROL_FAMILIES))

M3_DEFAULT_N_UNITS <- 60L
M3_DEFAULT_N_TRAITS <- 5L
M3_DEFAULT_LAMBDA_SCALE <- 1
M3_DEFAULT_PSI_SCALE <- 1
M3_DEFAULT_PHI_SHAPE <- 5
M3_DEFAULT_PHI_RATE <- 5
M3_DEFAULT_NOMINAL <- 0.95
M3_PASS_GATE <- 0.94 # audit-1 exit threshold
M3_INTERVAL_TARGETS <- c("psi", "Sigma_unit_diag")
M3_STRESS_RUN_STAGE <- "point_stress"
M3_START_PROBE_STAGE <- "start_probe"

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

m3_target_method <- function(target, n_boot = NULL) {
  switch(
    target,
    psi = "profile",
    Sigma_unit_diag = if (
      !is.null(n_boot) && identical(as.integer(n_boot), 0L)
    ) {
      "none"
    } else {
      "bootstrap"
    },
    stop("Unknown M3 interval target: ", target)
  )
}

m3_family_seed_index <- function(family) {
  match(family, M3_SUPPORTED_FAMILIES)
}

m3_is_binary_family <- function(family) {
  family %in% c("binomial", "binomial_probit")
}

m3_rep_index_range <- function(
  n_reps,
  rep_index_start = NULL,
  rep_index_end = NULL
) {
  n_reps <- as.integer(n_reps)
  if (is.na(n_reps) || n_reps < 1L) {
    stop("n_reps must be a positive integer")
  }
  if (is.null(rep_index_start)) {
    rep_index_start <- 1L
  }
  if (is.null(rep_index_end)) {
    rep_index_end <- n_reps
  }
  rep_index_start <- as.integer(rep_index_start)
  rep_index_end <- as.integer(rep_index_end)
  if (
    is.na(rep_index_start) ||
      is.na(rep_index_end) ||
      rep_index_start < 1L ||
      rep_index_end > n_reps ||
      rep_index_start > rep_index_end
  ) {
    stop(
      "rep_index_start/rep_index_end must define a non-empty range ",
      "inside 1:n_reps"
    )
  }
  seq.int(rep_index_start, rep_index_end)
}

m3_shard_rep_range <- function(n_reps, shard = 1L, n_shards = 1L) {
  n_reps <- as.integer(n_reps)
  shard <- as.integer(shard)
  n_shards <- as.integer(n_shards)
  if (is.na(n_reps) || n_reps < 1L) {
    stop("n_reps must be a positive integer")
  }
  if (is.na(n_shards) || n_shards < 1L) {
    stop("n_shards must be a positive integer")
  }
  if (is.na(shard) || shard < 1L || shard > n_shards) {
    stop("shard must be an integer in 1:n_shards")
  }
  if (n_shards > n_reps) {
    stop("n_shards must not exceed n_reps")
  }
  c(
    start = floor((shard - 1L) * n_reps / n_shards) + 1L,
    end = floor(shard * n_reps / n_shards)
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
  stopifnot(family %in% M3_SUPPORTED_FAMILIES, d >= 1L)
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

  ## Per-trait family assignment (mirrors m3_simulate_response).
  ## Used to apply the 2026-05-25 binomial-psi correction below.
  row_family <- if (family == "mixed") {
    c("gaussian", "binomial", "nbinom2")[((seq_len(n_traits) - 1L) %% 3L) + 1L]
  } else {
    rep(family, n_traits)
  }

  ## Patch 2026-05-25 (maintainer ruling): for 1-trial Bernoulli, the
  ## per-observation latent variance `psi` is not identifiable
  ## separately from the binomial sampling variance — single-trial
  ## Bernoulli has no overdispersion parameter and the link-residual
  ## is fixed at pi^2/3 (logit) or 1 (probit) by construction. The
  ## DGP must NOT include psi in the truth for binomial traits, and
  ## `m3_simulate_response` must NOT add `e_unique` for those rows.
  ## This applies to family == "binomial" / "binomial_probit" (all
  ## traits binomial) and to binomial rows inside family == "mixed".
  ## psi is still drawn (for record-keeping in $psi) but the truth Sigma
  ## uses psi_effective (zeroed for binomial rows).
  ##
  ## Cross-ref: docs/dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md
  ## §3.2 + §4 — N-sweep falsified small-n hypothesis; the gap was
  ## a DGP-vs-fitter scale mismatch from including psi in binary truth.
  psi_effective <- psi
  psi_effective[m3_is_binary_family(row_family)] <- 0

  ## Regression guard (maintainer 2026-05-25): a future m3-grid edit
  ## must NOT silently re-introduce a free `psi` component for binary
  ## traits. Single-trial Bernoulli has no overdispersion parameter
  ## and the binomial sampling distribution IS the per-observation
  ## variance; adding `e_unique ~ N(0, psi)` for binary rows
  ## generates non-identifiable noise that inflates `truth_diag_Sigma`
  ## while producing data no fitter can recover the `psi` from. The
  ## stopifnot below fails loudly if that invariant breaks.
  stopifnot(
    "m3-grid binomial-psi invariant violated: psi_effective must be 0 for binomial rows. See PR #263 + the maintainer 2026-05-25 design ruling." = all(
      psi_effective[m3_is_binary_family(row_family)] == 0
    )
  )

  ## Implied Sigma_unit (T x T): the rotation-invariant target
  Sigma <- tcrossprod(Lambda) + diag(psi_effective, n_traits)
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
  ## Gaussian traits carry NO separate observation residual: `e_unique`
  ## (~ N(0, psi), inside `eta`) is the only per-row noise, so the
  ## simulated response is `eta` itself and the per-unit variance is
  ## exactly `diag(Lambda Lambda^T + diag(psi))` = `diag_Sigma` (the
  ## scored truth). A separate `sigma_eps` is non-identifiable from `psi`
  ## with one obs per (unit, trait) and previously biased the fit's `psi`
  ## high by `sigma_eps^2`; removed 2026-07-13 (see m3_simulate_response).

  list(
    Lambda = Lambda,
    psi = psi,
    psi_effective = psi_effective, # zero for binomial rows; see comment above
    row_family = row_family,
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
  ## Patch 2026-05-25 (maintainer ruling): use psi_effective (zero for
  ## binomial traits) rather than the originally drawn psi. Single-
  ## trial Bernoulli can't carry per-observation latent variance on
  ## top of the link-residual; the simulation must not add e_unique
  ## for those rows. See `m3_sample_truth` for the rationale +
  ## cross-ref to the Jason scout audit memo.
  psi <- truth$psi_effective %||% truth$psi
  Z <- truth$Z

  ## Linear predictor on the latent scale (no fixed-effect mean here;
  ## the fit estimates a per-trait intercept which absorbs that).
  ## eta = Z %*% Lambda^T + e_unique with e_unique ~ N(0, diag(psi))
  ## For binomial traits psi=0 (per patch above) so e_unique = 0.
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
      ## Gaussian trait: the latent linear predictor `eta_t` (= Lambda Z +
      ## e_unique, e_unique ~ N(0, psi)) IS the response. NO separate
      ## observation residual is added. With one observation per
      ## (unit, trait) cell, a per-observation latent RE `psi` and a
      ## Gaussian observation residual `sigma_eps` are FUNDAMENTALLY
      ## non-identifiable — the fitter's single `indep(0 + trait | unit)`
      ## component absorbs both. The old DGP added `rnorm(sd = 0.5)` on top
      ## of `eta`, so the fit's `psi` consistently estimated
      ## `psi + sigma_eps^2` (a constant +0.25) while the truth
      ## `diag_Sigma = diag(Lambda Lambda^T + diag(psi))` omitted it: a
      ## fixed estimand-vs-truth offset that made bootstrap coverage
      ## COLLAPSE as n grew (0.90 @ n=50 -> 0.54 @ n=150). Mirror image of
      ## the 2026-05-25 binomial-psi patch. See
      ## docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md.
      gaussian = eta_t,
      binomial = stats::rbinom(n_units, size = 1L, prob = stats::plogis(eta_t)),
      binomial_probit = stats::rbinom(
        n_units,
        size = 1L,
        prob = stats::pnorm(eta_t)
      ),
      poisson = {
        mu_t <- exp(pmin(pmax(eta_t, -10), 10))
        stats::rpois(n_units, lambda = mu_t)
      },
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
  rep_index_start = NULL,
  rep_index_end = NULL,
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
  ## Primary target is `Sigma_unit_diag` (bootstrap); `psi` (profile) is
  ## a diagnostic proxy only. See the 2026-05-19 target-scale audit
  ## (Design 44 6, CI-08/CI-10) -- the gate is on `Sigma_unit_diag`.
  targets = c("psi", "Sigma_unit_diag"),
  n_boot = 30L,
  n_cores_boot = 1L,
  ci_level = M3_DEFAULT_NOMINAL,
  verbose = TRUE
) {
  stopifnot(family %in% M3_SUPPORTED_FAMILIES, d >= 1L, n_reps >= 1L)
  rep_indices <- m3_rep_index_range(
    n_reps,
    rep_index_start = rep_index_start,
    rep_index_end = rep_index_end
  )
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
      "[m3] cell %s, reps %d-%d of %d; targets = %s\n",
      cell_id,
      min(rep_indices),
      max(rep_indices),
      n_reps,
      paste(targets, collapse = ",")
    ))
  }

  rows <- vector("list", length(rep_indices))
  for (j in seq_along(rep_indices)) {
    r <- rep_indices[j]
    rep_seed <- seed_base +
      1000L * d +
      100000L * m3_family_seed_index(family) +
      r
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
        binomial_probit = stats::binomial(link = "probit"),
        poisson = stats::poisson(),
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
      rows[[j]] <- m3_add_fit_health(
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
              ci_method = m3_target_method(target, n_boot = n_boot),
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
        covered_prof <- if (ci_available) {
          psi_truth >= prof_lo[t] && psi_truth <= prof_hi[t]
        } else {
          NA
        }
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
        covered_sig <- if (ci_available) {
          sig_truth >= sig_lo[t] && sig_truth <= sig_hi[t]
        } else {
          NA
        }
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
          ci_method = m3_target_method("Sigma_unit_diag", n_boot = n_boot),
          ci_level = ci_level,
          ci_lo = sig_lo[t],
          ci_hi = sig_hi[t],
          covered = covered_sig,
          ci_available = ci_available,
          fit_converged = TRUE,
          ci_failed = if (n_boot == 0L) FALSE else !ci_available,
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
    rows[[j]] <- m3_add_fit_health(do.call(rbind, rep_rows), fit_diag)
    rows[[j]]$runtime_s <- rep_runtime

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
  rep_index_start = NULL,
  rep_index_end = NULL,
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
  ## Primary target is `Sigma_unit_diag` (bootstrap); `psi` (profile) is
  ## a diagnostic proxy only. See the 2026-05-19 target-scale audit
  ## (Design 44 6, CI-08/CI-10) -- the gate is on `Sigma_unit_diag`.
  targets = c("psi", "Sigma_unit_diag"),
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
          rep_index_start = rep_index_start,
          rep_index_end = rep_index_end,
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
        rep_index_start = rep_index_start,
        rep_index_end = rep_index_end,
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

## ---- Surface registers ------------------------------------------------

m3_nb2_stress_surfaces <- function(include_controls = FALSE) {
  nb2 <- data.frame(
    surface_id = c(
      "nbinom2-d1-baseline-phi1-n60",
      "nbinom2-d1-lowphi-n120",
      "nbinom2-d1-weakvar-phi1-n60"
    ),
    scenario = c(
      "baseline_phi1_n60",
      "lowphi_n120",
      "weakvar_phi1_n60"
    ),
    family = "nbinom2",
    d = 1L,
    n_units = c(60L, 120L, 60L),
    n_traits = 5L,
    lambda_scale = c(1, 1, 0.5),
    psi_scale = c(1, 1, 1.5),
    phi = c(1, 0.4, 1),
    fit_phi_modes = "estimated,known",
    target = "Sigma_unit_diag",
    ci_method = "none",
    link_residual = "none",
    n_boot = 0L,
    n_cores_boot = 1L,
    run_stage = M3_STRESS_RUN_STAGE,
    stringsAsFactors = FALSE
  )

  rows <- nb2
  if (isTRUE(include_controls)) {
    controls <- data.frame(
      surface_id = c(
        "gaussian-d1-baseline-n60",
        "poisson-d1-baseline-n60"
      ),
      scenario = c(
        "gaussian_control_n60",
        "poisson_control_n60"
      ),
      family = c("gaussian", "poisson"),
      d = 1L,
      n_units = 60L,
      n_traits = 5L,
      lambda_scale = 1,
      psi_scale = 1,
      phi = NA_real_,
      fit_phi_modes = "estimated",
      target = "Sigma_unit_diag",
      ci_method = "none",
      link_residual = "none",
      n_boot = 0L,
      n_cores_boot = 1L,
      run_stage = M3_STRESS_RUN_STAGE,
      stringsAsFactors = FALSE
    )
    rows <- rbind(rows, controls)
  }

  split_rows <- lapply(seq_len(nrow(rows)), function(i) {
    modes <- strsplit(rows$fit_phi_modes[i], ",", fixed = TRUE)[[1L]]
    out <- rows[rep(i, length(modes)), , drop = FALSE]
    out$fit_phi_mode <- trimws(modes)
    out
  })
  out <- do.call(rbind, split_rows)
  out$fit_phi_modes <- NULL
  rownames(out) <- NULL
  out
}

m3_run_surface_register <- function(
  surfaces,
  n_reps = 10L,
  seed_base = 20260520L,
  init_strategy = "single_trait_warmup",
  start_method = list(method = "res", jitter.sd = 0.2),
  optimizer = "optim",
  optArgs = list(method = "BFGS"),
  n_init = 3L,
  init_jitter = 0.05,
  se = FALSE,
  ci_level = M3_DEFAULT_NOMINAL,
  verbose = TRUE
) {
  required <- c(
    "surface_id",
    "scenario",
    "family",
    "d",
    "n_units",
    "n_traits",
    "lambda_scale",
    "psi_scale",
    "fit_phi_mode",
    "target",
    "n_boot",
    "n_cores_boot",
    "run_stage"
  )
  missing <- setdiff(required, names(surfaces))
  if (length(missing)) {
    stop("Surface register missing columns: ", paste(missing, collapse = ", "))
  }

  rows <- vector("list", nrow(surfaces))
  for (i in seq_len(nrow(surfaces))) {
    s <- surfaces[i, , drop = FALSE]
    phi_i <- if ("phi" %in% names(s) && is.finite(s$phi)) s$phi else NULL
    target_i <- m3_normalise_targets(strsplit(
      as.character(s$target),
      ",",
      fixed = TRUE
    )[[1L]])
    if (verbose) {
      cat(sprintf(
        "[m3] surface %s (%s, fit_phi_mode = %s)\n",
        s$surface_id,
        s$scenario,
        s$fit_phi_mode
      ))
    }
    grid_i <- m3_run_grid(
      cells = data.frame(
        family = s$family,
        d = as.integer(s$d),
        stringsAsFactors = FALSE
      ),
      n_reps = n_reps,
      seed_base = seed_base,
      n_units = as.integer(s$n_units),
      n_traits = as.integer(s$n_traits),
      lambda_scale = as.numeric(s$lambda_scale),
      psi_scale = as.numeric(s$psi_scale),
      phi = phi_i,
      init_strategy = init_strategy,
      start_method = start_method,
      optimizer = optimizer,
      optArgs = optArgs,
      n_init = n_init,
      init_jitter = init_jitter,
      se = se,
      fit_phi_mode = s$fit_phi_mode,
      targets = target_i,
      n_boot = as.integer(s$n_boot),
      n_cores_boot = as.integer(s$n_cores_boot),
      ci_level = ci_level,
      parallel = FALSE
    )
    grid_i$surface_id <- s$surface_id
    grid_i$scenario <- s$scenario
    grid_i$run_stage <- s$run_stage
    grid_i$declared_ci_method <- s$ci_method %||% NA_character_
    grid_i$declared_link_residual <- s$link_residual %||% NA_character_
    rows[[i]] <- grid_i
  }

  do.call(rbind, rows)
}

m3_nb2_start_probe_configs <- function(include_optimizer_probe = TRUE) {
  configs <- data.frame(
    probe_id = c(
      "current_res_bfgs_n3_j005",
      "res_bfgs_n10_j020",
      "res_bfgs_n10_j050",
      "indep_bfgs_n10_j020"
    ),
    probe_label = c(
      "current residual BFGS n_init=3",
      "residual BFGS n_init=10 jitter=0.20",
      "residual BFGS n_init=10 jitter=0.50",
      "independent BFGS n_init=10 jitter=0.20"
    ),
    init_strategy = "single_trait_warmup",
    start_method_name = c("res", "res", "res", "indep"),
    start_jitter = c(0.2, 0.2, 0.2, 0.2),
    optimizer = "optim",
    optim_method = "BFGS",
    n_init = c(3L, 10L, 10L, 10L),
    init_jitter = c(0.05, 0.2, 0.5, 0.2),
    stringsAsFactors = FALSE
  )

  if (isTRUE(include_optimizer_probe)) {
    configs <- rbind(
      configs,
      data.frame(
        probe_id = "res_nlminb_n10_j020",
        probe_label = "residual nlminb n_init=10 jitter=0.20",
        init_strategy = "single_trait_warmup",
        start_method_name = "res",
        start_jitter = 0.2,
        optimizer = "nlminb",
        optim_method = NA_character_,
        n_init = 10L,
        init_jitter = 0.2,
        stringsAsFactors = FALSE
      )
    )
  }

  rownames(configs) <- NULL
  configs
}

m3_run_start_probe <- function(
  surfaces = m3_nb2_stress_surfaces(),
  configs = m3_nb2_start_probe_configs(),
  n_reps = 5L,
  seed_base = 20260520L,
  targets = "Sigma_unit_diag",
  n_boot = 0L,
  n_cores_boot = 1L,
  se = FALSE,
  ci_level = M3_DEFAULT_NOMINAL,
  verbose = TRUE
) {
  required <- c(
    "probe_id",
    "probe_label",
    "init_strategy",
    "start_method_name",
    "start_jitter",
    "optimizer",
    "n_init",
    "init_jitter"
  )
  missing <- setdiff(required, names(configs))
  if (length(missing)) {
    stop(
      "Start-probe config missing columns: ",
      paste(missing, collapse = ", ")
    )
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

  surfaces <- surfaces[surfaces$family == "nbinom2", , drop = FALSE]
  surfaces$target <- paste(targets, collapse = ",")
  surfaces$n_boot <- n_boot
  surfaces$n_cores_boot <- n_cores_boot
  surfaces$ci_method <- if (n_boot == 0L) "none" else "bootstrap"
  surfaces$run_stage <- M3_START_PROBE_STAGE

  rows <- vector("list", nrow(configs))
  for (i in seq_len(nrow(configs))) {
    cfg <- configs[i, , drop = FALSE]
    if (verbose) {
      cat(sprintf(
        "[m3] start probe %s (%s)\n",
        cfg$probe_id,
        cfg$probe_label
      ))
    }
    start_method <- list(
      method = if (identical(cfg$start_method_name, "default")) {
        NULL
      } else {
        cfg$start_method_name
      },
      jitter.sd = as.numeric(cfg$start_jitter)
    )
    optArgs <- if (identical(cfg$optimizer, "optim")) {
      method <- cfg$optim_method
      if (is.null(method) || length(method) == 0L || is.na(method)) {
        method <- "BFGS"
      }
      list(method = method)
    } else {
      list()
    }
    grid_i <- m3_run_surface_register(
      surfaces = surfaces,
      n_reps = n_reps,
      seed_base = seed_base,
      init_strategy = cfg$init_strategy,
      start_method = start_method,
      optimizer = cfg$optimizer,
      optArgs = optArgs,
      n_init = as.integer(cfg$n_init),
      init_jitter = as.numeric(cfg$init_jitter),
      se = se,
      ci_level = ci_level,
      verbose = verbose
    )
    grid_i$probe_id <- cfg$probe_id
    grid_i$probe_label <- cfg$probe_label
    grid_i$probe_stage <- M3_START_PROBE_STAGE
    grid_i$probe_start_method <- cfg$start_method_name
    grid_i$probe_start_jitter <- as.numeric(cfg$start_jitter)
    grid_i$probe_optimizer <- cfg$optimizer
    grid_i$probe_optim_method <- cfg$optim_method
    grid_i$probe_n_init <- as.integer(cfg$n_init)
    grid_i$probe_init_jitter <- as.numeric(cfg$init_jitter)
    rows[[i]] <- grid_i
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
  if ("surface_id" %in% names(grid_df)) {
    split_keys <- c(list(grid_df$surface_id), split_keys)
  }
  if ("probe_id" %in% names(grid_df)) {
    split_keys <- c(list(grid_df$probe_id), split_keys)
  }
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
      if (identical(sub$ci_method[1], "none")) {
        pilot_status <- "POINT_ONLY"
      }
      ## Diagnostic gate columns: profile CI on `psi` (`theta_diag_B`).
      ## After the 2026-05-19 target-scale audit (Design 44 6) `psi` is a
      ## DIAGNOSTIC target only -- it is a rotation-variant proxy, not the
      ## estimand the coverage claim is about. These columns are retained
      ## for the binomial-psi=0 regression diagnostic and for back-compat,
      ## but they no longer drive promotion; see *_primary below.
      coverage_prof <- if (
        identical(sub$target[1], "psi") &&
          identical(sub$ci_method[1], "profile")
      ) {
        coverage
      } else {
        NA_real_
      }
      profile_gate_status <- if (is.na(coverage_prof)) {
        "NOT_EVALUATED"
      } else if (coverage_prof >= gate) {
        "PASS"
      } else {
        "FAIL"
      }
      passes_94pct_prof <- if (is.na(coverage_prof)) {
        NA
      } else {
        coverage_prof >= gate
      }
      ## Primary gate columns: bootstrap CI on total `Sigma_unit_diag`.
      ## This is the rotation-invariant estimand the coverage claim is
      ## about (Design 44 6, Design 50 3); the M3 94% promotion gate is
      ## evaluated HERE, not on the `psi` proxy above. This is the
      ## correction to the 2026-05-19 production-run confound (CI-08/CI-10):
      ## the run profiled `psi` while the claim is about `Sigma_unit[tt]`.
      coverage_primary <- if (
        identical(sub$target[1], "Sigma_unit_diag") &&
          identical(sub$ci_method[1], "bootstrap")
      ) {
        coverage
      } else {
        NA_real_
      }
      primary_gate_status <- if (is.na(coverage_primary)) {
        "NOT_EVALUATED"
      } else if (coverage_primary >= gate) {
        "PASS"
      } else {
        "FAIL"
      }
      passes_94pct_primary <- if (is.na(coverage_primary)) {
        NA
      } else {
        coverage_primary >= gate
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
        coverage_primary = coverage_primary,
        passes_94pct_primary = passes_94pct_primary,
        primary_gate_status = primary_gate_status,
        coverage_prof = coverage_prof,
        passes_94pct_prof = passes_94pct_prof,
        profile_gate_status = profile_gate_status,
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
      if ("surface_id" %in% names(sub)) {
        row <- data.frame(
          surface_id = sub$surface_id[1],
          row,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
      probe_cols <- intersect(
        c(
          "probe_id",
          "probe_label",
          "probe_stage",
          "probe_start_method",
          "probe_start_jitter",
          "probe_optimizer",
          "probe_optim_method",
          "probe_n_init",
          "probe_init_jitter"
        ),
        names(sub)
      )
      if (length(probe_cols)) {
        row <- data.frame(
          sub[1, probe_cols, drop = FALSE],
          row,
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
      if ("run_stage" %in% names(sub)) {
        row <- data.frame(
          run_stage = sub$run_stage[1],
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

## ---- Diagnostic report data -------------------------------------------

m3_split_apply <- function(df, keys, fun) {
  keys <- intersect(keys, names(df))
  if (!length(keys) || !nrow(df)) {
    return(data.frame())
  }
  groups <- split(df, df[keys], drop = TRUE)
  out <- lapply(groups, fun)
  out <- out[!vapply(out, is.null, logical(1))]
  if (!length(out)) {
    return(data.frame())
  }
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

m3_diagnostic_report_data <- function(
  grid_df,
  pilot_gate = 0.90,
  promotion_gate = M3_PASS_GATE
) {
  if (!is.data.frame(grid_df) || !nrow(grid_df)) {
    stop("grid_df must be a non-empty data frame")
  }
  summary <- m3_summarise(grid_df, gate = promotion_gate)
  summary$pilot_gate <- pilot_gate
  summary$promotion_gate <- promotion_gate

  header_cols <- intersect(
    c(
      "surface_id",
      "scenario",
      "run_stage",
      "family",
      "d",
      "n_units",
      "n_traits",
      "lambda_scale",
      "psi_scale",
      "truth_phi",
      "target",
      "ci_method",
      "fit_phi_mode",
      "declared_link_residual",
      "n_boot",
      "n_cores_boot",
      "seed_base",
      "probe_id",
      "probe_label",
      "probe_stage",
      "probe_start_method",
      "probe_start_jitter",
      "probe_optimizer",
      "probe_optim_method",
      "probe_n_init",
      "probe_init_jitter"
    ),
    names(grid_df)
  )
  header <- unique(grid_df[header_cols])
  rownames(header) <- NULL

  trait_rows <- grid_df[
    !is.na(grid_df$trait_id) &
      is.finite(grid_df$truth) &
      is.finite(grid_df$estimate) &
      grid_df$truth != 0,
    ,
    drop = FALSE
  ]
  trait_keys <- c(
    "probe_id",
    "surface_id",
    "scenario",
    "family",
    "d",
    "target",
    "ci_method",
    "fit_phi_mode",
    "trait_id"
  )
  trait_ratios <- m3_split_apply(trait_rows, trait_keys, function(sub) {
    key <- sub[1, intersect(trait_keys, names(sub)), drop = FALSE]
    ratio <- sub$estimate / sub$truth
    phi_ratio <- if (all(c("est_phi_nbinom2", "truth_phi") %in% names(sub))) {
      x <- sub$est_phi_nbinom2 / sub$truth_phi
      x[is.finite(x)]
    } else {
      numeric(0)
    }
    link_ratio <- if ("est_link_residual" %in% names(sub)) {
      x <- sub$est_link_residual / sub$truth
      x[is.finite(x)]
    } else {
      numeric(0)
    }
    data.frame(
      key,
      n_trait_rows = nrow(sub),
      n_ci_available = if ("ci_available" %in% names(sub)) {
        sum(sub$ci_available %in% TRUE)
      } else {
        NA_integer_
      },
      coverage = if (
        "covered" %in%
          names(sub) &&
          "ci_available" %in% names(sub) &&
          any(sub$ci_available %in% TRUE & !is.na(sub$covered))
      ) {
        mean(sub$covered[sub$ci_available %in% TRUE], na.rm = TRUE)
      } else {
        NA_real_
      },
      median_est_truth_ratio = stats::median(ratio, na.rm = TRUE),
      median_est_phi_truth_ratio = if (length(phi_ratio)) {
        stats::median(phi_ratio, na.rm = TRUE)
      } else {
        NA_real_
      },
      median_link_residual_truth_ratio = if (length(link_ratio)) {
        stats::median(link_ratio, na.rm = TRUE)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })

  failure_cols <- intersect(
    c(
      "surface_id",
      "scenario",
      "fit_phi_mode",
      "family",
      "d",
      "target",
      "ci_method",
      "n_reps",
      "n_completed",
      "n_failed",
      "n_trait_rows",
      "n_ci_missing",
      "n_boot_failed",
      "n_boot_attempted",
      "boot_fail_rate",
      "pd_hessian_rate",
      "sdreport_ok_rate",
      "median_max_gradient",
      "median_restart_count",
      "median_objective_spread",
      "pilot_status",
      "probe_id",
      "probe_label",
      "probe_stage",
      "probe_start_method",
      "probe_optimizer",
      "probe_n_init",
      "probe_init_jitter"
    ),
    names(summary)
  )
  failure_ledger <- summary[failure_cols]
  rownames(failure_ledger) <- NULL

  structure(
    list(
      header = header,
      summary = summary,
      trait_ratios = trait_ratios,
      failure_ledger = failure_ledger,
      verdict = unique(summary[
        intersect(
          c(
            "surface_id",
            "scenario",
            "fit_phi_mode",
            "target",
            "ci_method",
            "pilot_status",
            "probe_id",
            "probe_label",
            "probe_stage"
          ),
          names(summary)
        )
      ])
    ),
    class = "m3_diagnostic_report"
  )
}

## ---- Diagnostic dashboard data ----------------------------------------

m3_source_map_probe_label <- function(probe_id) {
  probe_id <- as.character(probe_id)
  probe_id <- sub("^current_res_bfgs_", "current ", probe_id)
  probe_id <- sub("^res_bfgs_", "BFGS ", probe_id)
  probe_id <- sub("^res_nlminb_", "nlminb ", probe_id)
  probe_id <- gsub("_", " ", probe_id, fixed = TRUE)
  probe_id <- gsub("j0", "j=0.", probe_id, fixed = TRUE)
  probe_id
}

m3_source_map_label <- function(df, include_probe = TRUE) {
  source <- if ("scenario" %in% names(df)) {
    as.character(df$scenario)
  } else if ("surface_id" %in% names(df)) {
    as.character(df$surface_id)
  } else {
    as.character(df$cell)
  }
  source <- gsub("_", " ", source, fixed = TRUE)
  if ("fit_phi_mode" %in% names(df)) {
    mode <- ifelse(
      df$fit_phi_mode == "known",
      "known phi",
      "estimated phi"
    )
    source <- paste0(source, " | ", mode)
  }
  if (isTRUE(include_probe) && "probe_id" %in% names(df)) {
    source <- paste0(source, " | ", m3_source_map_probe_label(df$probe_id))
  }
  source
}

m3_source_map_dashboard_data <- function(
  grid_df,
  pilot_gate = 0.90,
  promotion_gate = M3_PASS_GATE
) {
  report <- m3_diagnostic_report_data(
    grid_df,
    pilot_gate = pilot_gate,
    promotion_gate = promotion_gate
  )
  summary <- report$summary
  include_probe <- "probe_id" %in%
    names(summary) &&
    length(unique(stats::na.omit(summary$probe_id))) > 1L
  summary$source_label <- m3_source_map_label(
    summary,
    include_probe = include_probe
  )
  summary$source_label <- factor(
    summary$source_label,
    levels = rev(unique(summary$source_label))
  )

  trait <- report$trait_ratios
  if (nrow(trait)) {
    trait$source_label <- m3_source_map_label(
      trait,
      include_probe = include_probe
    )
    trait$source_label <- factor(
      trait$source_label,
      levels = levels(summary$source_label)
    )
  }

  ratio_specs <- list(
    list(
      metric = "Sigma estimate/truth",
      column = "median_est_truth_ratio"
    ),
    list(
      metric = "NB2 phi estimate/truth",
      column = "median_est_phi_truth_ratio"
    ),
    list(
      metric = "Link residual/truth",
      column = "median_link_residual_truth_ratio"
    )
  )
  ratio_points <- do.call(
    rbind,
    lapply(ratio_specs, function(spec) {
      if (!nrow(trait) || !spec$column %in% names(trait)) {
        return(NULL)
      }
      value <- trait[[spec$column]]
      keep <- is.finite(value)
      if (!any(keep)) {
        return(NULL)
      }
      cols <- intersect(
        c(
          "source_label",
          "surface_id",
          "scenario",
          "family",
          "d",
          "target",
          "ci_method",
          "fit_phi_mode",
          "trait_id",
          "probe_id",
          "probe_label",
          "n_trait_rows",
          "n_ci_available"
        ),
        names(trait)
      )
      out <- trait[keep, cols, drop = FALSE]
      out$metric <- spec$metric
      out$value <- value[keep]
      out$reference <- 1
      out
    })
  )
  if (is.null(ratio_points)) {
    ratio_points <- data.frame()
  } else {
    rownames(ratio_points) <- NULL
    ratio_points$metric <- factor(
      ratio_points$metric,
      levels = c(
        "Sigma estimate/truth",
        "NB2 phi estimate/truth",
        "Link residual/truth"
      )
    )
  }

  ledger <- report$failure_ledger
  if (nrow(ledger)) {
    ledger$source_label <- m3_source_map_label(
      ledger,
      include_probe = include_probe
    )
    ledger$source_label <- factor(
      ledger$source_label,
      levels = levels(summary$source_label)
    )
  }
  rate_specs <- list(
    list(
      metric = "Fit failed",
      numerator = "n_failed",
      denominator = "n_reps",
      reference = 0.10
    ),
    list(
      metric = "CI missing",
      numerator = "n_ci_missing",
      denominator = "n_trait_rows",
      reference = 0.10
    ),
    list(
      metric = "Bootstrap failed",
      numerator = "n_boot_failed",
      denominator = "n_boot_attempted",
      reference = 0.10
    ),
    list(
      metric = "pdHess TRUE",
      numerator = "pd_hessian_rate",
      denominator = NA_character_,
      reference = 1
    ),
    list(
      metric = "sdreport OK",
      numerator = "sdreport_ok_rate",
      denominator = NA_character_,
      reference = 1
    )
  )
  failure_rates <- do.call(
    rbind,
    lapply(rate_specs, function(spec) {
      if (!nrow(ledger) || !spec$numerator %in% names(ledger)) {
        return(NULL)
      }
      cols <- intersect(
        c(
          "source_label",
          "surface_id",
          "scenario",
          "family",
          "d",
          "target",
          "ci_method",
          "fit_phi_mode",
          "pilot_status",
          "probe_id",
          "probe_label"
        ),
        names(ledger)
      )
      out <- ledger[, cols, drop = FALSE]
      if (is.na(spec$denominator)) {
        out$value <- ledger[[spec$numerator]]
        out$denominator_label <- "rate"
      } else {
        denominator <- ledger[[spec$denominator]]
        numerator <- ledger[[spec$numerator]]
        out$value <- ifelse(
          is.finite(denominator) & denominator > 0,
          numerator / denominator,
          NA_real_
        )
        out$denominator_label <- paste0(numerator, "/", denominator)
      }
      out$metric <- spec$metric
      out$reference <- spec$reference
      out
    })
  )
  if (is.null(failure_rates)) {
    failure_rates <- data.frame()
  } else {
    rownames(failure_rates) <- NULL
    point_only <- failure_rates$ci_method == "none" &
      failure_rates$metric == "CI missing"
    failure_rates$value[point_only] <- NA_real_
    failure_rates$denominator_label[point_only] <- "point only"
    failure_rates$value_label <- ifelse(
      failure_rates$denominator_label == "point only",
      "point only",
      ifelse(
        is.finite(failure_rates$value) &
          failure_rates$denominator_label != "rate",
        paste0(
          sprintf("%.0f%%", 100 * failure_rates$value),
          "\n",
          failure_rates$denominator_label
        ),
        ifelse(
          is.finite(failure_rates$value),
          sprintf("%.2g", failure_rates$value),
          "not reported"
        )
      )
    )
    failure_rates$status_bucket <- ifelse(
      failure_rates$denominator_label == "point only",
      "point only",
      ifelse(
        is.finite(failure_rates$value) & failure_rates$value == 0,
        "zero",
        ifelse(is.finite(failure_rates$value), "nonzero", "not reported")
      )
    )
    failure_rates$metric <- factor(
      failure_rates$metric,
      levels = c(
        "Fit failed",
        "CI missing",
        "Bootstrap failed",
        "pdHess TRUE",
        "sdreport OK"
      )
    )
  }

  verdict_tiles <- summary[,
    intersect(
      c(
        "source_label",
        "surface_id",
        "scenario",
        "family",
        "d",
        "target",
        "ci_method",
        "fit_phi_mode",
        "pilot_status",
        "profile_gate_status",
        "coverage",
        "n_reps",
        "n_completed",
        "n_failed",
        "n_ci_missing",
        "n_trait_rows",
        "probe_id",
        "probe_label"
      ),
      names(summary)
    ),
    drop = FALSE
  ]
  if (nrow(verdict_tiles)) {
    verdict_tiles$status_label <- paste0(
      verdict_tiles$pilot_status,
      "\nprofile: ",
      verdict_tiles$profile_gate_status
    )
    verdict_tiles$denominator_label <- paste0(
      "fit ",
      verdict_tiles$n_completed,
      "/",
      verdict_tiles$n_reps,
      "; CI miss ",
      verdict_tiles$n_ci_missing,
      "/",
      verdict_tiles$n_trait_rows
    )
  }

  structure(
    list(
      report = report,
      summary = summary,
      ratio_points = ratio_points,
      failure_rates = failure_rates,
      verdict_tiles = verdict_tiles
    ),
    class = "m3_source_map_dashboard_data"
  )
}

m3_require_ggplot2 <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 must be installed to render the M3 source-map dashboard")
  }
}

m3_source_map_status_palette <- function() {
  c(
    PASS_TO_SCALE = "#0072B2",
    POINT_ONLY = "#4D4D4D",
    TARGET_FAIL = "#D55E00",
    COMPUTE_FAIL = "#CC79A7",
    PASS = "#009E73",
    FAIL = "#D55E00",
    NOT_EVALUATED = "#999999"
  )
}

m3_plot_source_map_ratios <- function(dashboard) {
  m3_require_ggplot2()
  if (!inherits(dashboard, "m3_source_map_dashboard_data")) {
    stop("dashboard must come from m3_source_map_dashboard_data()")
  }
  ratio_points <- dashboard$ratio_points
  if (!nrow(ratio_points)) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate(
          "text",
          x = 0,
          y = 0,
          label = "No finite estimate/truth ratios"
        ) +
        ggplot2::theme_void()
    )
  }
  summary_status <- dashboard$summary[,
    intersect(c("source_label", "pilot_status"), names(dashboard$summary)),
    drop = FALSE
  ]
  summary_status <- unique(summary_status)
  ratio_points <- merge(
    ratio_points,
    summary_status,
    by = "source_label",
    all.x = TRUE,
    sort = FALSE
  )
  ratio_points$trait_label <- paste0("trait ", ratio_points$trait_id)
  shape_var <- if ("fit_phi_mode" %in% names(ratio_points)) {
    "fit_phi_mode"
  } else {
    "ci_method"
  }
  ggplot2::ggplot(
    ratio_points,
    ggplot2::aes(
      x = .data$value,
      y = .data$source_label,
      colour = .data$pilot_status,
      shape = .data[[shape_var]]
    )
  ) +
    ggplot2::geom_vline(
      xintercept = 1,
      linewidth = 0.35,
      linetype = "dashed",
      colour = "grey35"
    ) +
    ggplot2::geom_point(
      ggplot2::aes(group = .data$trait_label),
      size = 2.1,
      alpha = 0.86,
      position = ggplot2::position_jitter(height = 0.08, width = 0)
    ) +
    ggplot2::facet_wrap(~metric, scales = "free_x", ncol = 1) +
    ggplot2::scale_colour_manual(
      values = m3_source_map_status_palette(),
      drop = FALSE
    ) +
    ggplot2::labs(
      x = "Median estimate / truth by trait",
      y = NULL,
      colour = "Surface status",
      shape = shape_var,
      title = "M3.3b source-map ratios",
      subtitle = "Point-only rows keep estimates visible but are not interval-coverage evidence."
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      axis.text.y = ggplot2::element_text(size = 8)
    )
}

m3_plot_source_map_failure_ledger <- function(dashboard) {
  m3_require_ggplot2()
  if (!inherits(dashboard, "m3_source_map_dashboard_data")) {
    stop("dashboard must come from m3_source_map_dashboard_data()")
  }
  failure_rates <- dashboard$failure_rates
  if (!nrow(failure_rates)) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0, y = 0, label = "No failure ledger") +
        ggplot2::theme_void()
    )
  }
  ggplot2::ggplot(
    failure_rates,
    ggplot2::aes(
      x = .data$metric,
      y = .data$source_label,
      fill = .data$status_bucket
    )
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.5) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$value_label),
      size = 2.5,
      lineheight = 0.9
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "zero" = "#E6F2EF",
        "nonzero" = "#F2D5C4",
        "point only" = "#D9D9D9",
        "not reported" = "#F0F0F0"
      ),
      drop = FALSE
    ) +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Ledger cell",
      title = "M3.3b failure ledger",
      subtitle = "Each cell prints its denominator; point-only rows are labelled instead of counted as missing-CI failures."
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 20, hjust = 1),
      axis.text.y = ggplot2::element_text(size = 8)
    )
}

m3_plot_source_map_verdict <- function(dashboard) {
  m3_require_ggplot2()
  if (!inherits(dashboard, "m3_source_map_dashboard_data")) {
    stop("dashboard must come from m3_source_map_dashboard_data()")
  }
  verdict_tiles <- dashboard$verdict_tiles
  if (!nrow(verdict_tiles)) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0, y = 0, label = "No verdict rows") +
        ggplot2::theme_void()
    )
  }
  verdict_long <- rbind(
    data.frame(
      source_label = verdict_tiles$source_label,
      metric = "Pilot status",
      status_key = verdict_tiles$pilot_status,
      label = verdict_tiles$pilot_status,
      stringsAsFactors = FALSE
    ),
    data.frame(
      source_label = verdict_tiles$source_label,
      metric = "Profile gate",
      status_key = verdict_tiles$profile_gate_status,
      label = verdict_tiles$profile_gate_status,
      stringsAsFactors = FALSE
    ),
    data.frame(
      source_label = verdict_tiles$source_label,
      metric = "Denominator",
      status_key = "NOT_EVALUATED",
      label = verdict_tiles$denominator_label,
      stringsAsFactors = FALSE
    )
  )
  verdict_long$source_label <- factor(
    verdict_long$source_label,
    levels = levels(verdict_tiles$source_label)
  )
  verdict_long$metric <- factor(
    verdict_long$metric,
    levels = c("Pilot status", "Profile gate", "Denominator")
  )
  verdict_long$text_colour <- ifelse(
    verdict_long$status_key %in% c("POINT_ONLY", "TARGET_FAIL", "COMPUTE_FAIL"),
    "white",
    "black"
  )
  ggplot2::ggplot(
    verdict_long,
    ggplot2::aes(
      x = .data$metric,
      y = .data$source_label,
      fill = .data$status_key
    )
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.5) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$label, colour = .data$text_colour),
      size = 2.5,
      lineheight = 0.9
    ) +
    ggplot2::scale_fill_manual(
      values = m3_source_map_status_palette(),
      drop = FALSE
    ) +
    ggplot2::scale_colour_identity() +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Pilot status",
      title = "M3.3b surface verdicts"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "bottom",
      axis.text.y = ggplot2::element_text(size = 8)
    )
}

m3_plot_source_map_dashboard <- function(grid_df) {
  dashboard <- m3_source_map_dashboard_data(grid_df)
  structure(
    list(
      data = dashboard,
      plots = list(
        ratios = m3_plot_source_map_ratios(dashboard),
        failure_ledger = m3_plot_source_map_failure_ledger(dashboard),
        verdict = m3_plot_source_map_verdict(dashboard)
      )
    ),
    class = "m3_source_map_dashboard"
  )
}

m3_write_source_map_dashboard <- function(
  grid_df,
  path,
  width = 11,
  height = 12,
  dpi = 150
) {
  m3_require_ggplot2()
  dashboard <- m3_plot_source_map_dashboard(grid_df)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(
    filename = path,
    width = width,
    height = height,
    units = "in",
    res = dpi
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  layout <- grid::grid.layout(
    nrow = 3,
    ncol = 1,
    heights = grid::unit(c(4.5, 3.6, 2.2), "null")
  )
  grid::pushViewport(grid::viewport(layout = layout))
  print(
    dashboard$plots$ratios,
    vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1)
  )
  print(
    dashboard$plots$failure_ledger,
    vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1)
  )
  print(
    dashboard$plots$verdict,
    vp = grid::viewport(layout.pos.row = 3, layout.pos.col = 1)
  )
  invisible(path)
}

m3_markdown_table <- function(df, digits = 3) {
  if (!is.data.frame(df) || !nrow(df)) {
    return("_No rows._")
  }
  fmt <- function(x) {
    if (is.numeric(x)) {
      out <- ifelse(is.na(x), "", format(round(x, digits), nsmall = 0))
      return(out)
    }
    ifelse(is.na(x), "", as.character(x))
  }
  out <- as.data.frame(lapply(df, fmt), stringsAsFactors = FALSE)
  header <- paste0("| ", paste(names(out), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(out)), collapse = " | "), " |")
  rows <- apply(out, 1L, function(z) {
    paste0("| ", paste(z, collapse = " | "), " |")
  })
  paste(c(header, sep, rows), collapse = "\n")
}

m3_write_diagnostic_report <- function(report, path) {
  if (!inherits(report, "m3_diagnostic_report")) {
    stop("report must come from m3_diagnostic_report_data()")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lines <- c(
    "# M3 Diagnostic Report",
    "",
    "## Surface Header",
    "",
    m3_markdown_table(report$header),
    "",
    "## Summary",
    "",
    m3_markdown_table(report$summary),
    "",
    "## Trait Estimate/Truth Ratios",
    "",
    m3_markdown_table(report$trait_ratios),
    "",
    "## Failure Ledger",
    "",
    m3_markdown_table(report$failure_ledger),
    "",
    "## Surface Verdict",
    "",
    m3_markdown_table(report$verdict),
    ""
  )
  writeLines(lines, path)
  invisible(path)
}
