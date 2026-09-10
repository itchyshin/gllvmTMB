# One immutable attempt, including complete failure accounting.

cran07_run_attempt <- function(cell, replicate, campaign_id, registry_sha256) {
  seed <- cran07_seed(cell$cell_number, replicate,
                     cran07_campaign_seed_offset(campaign_id))
  started <- proc.time()[["elapsed"]]
  warnings <- character()
  fixture <- NULL
  fit <- NULL
  estimands <- NULL
  gate_evidence <- list(n_trials_min = NA_integer_, n_trials_max = NA_integer_,
                        diag_B_skip = "", diag_B_all_free = NA)
  constructed <- FALSE
  error_class <- error_message <- ""
  fixture <- tryCatch(cran07_make_fixture(cell, seed), error = function(e) {
    error_class <<- class(e)[[1L]]; error_message <<- conditionMessage(e); NULL
  })
  if (!is.null(fixture)) {
    constructed <- TRUE
    fit <- tryCatch(withCallingHandlers({
      args <- list(formula = fixture$formula, data = fixture$data,
                   family = fixture$family, trait = "trait", unit = "unit",
                   silent = TRUE)
      if (!is.null(fixture$weights)) args$weights <- fixture$weights
      if (fixture$missing_include) args$missing <- gllvmTMB::miss_control(response = "include")
      do.call(gllvmTMB::gllvmTMB, args)
    }, warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    }), error = function(e) {
      error_class <<- class(e)[[1L]]; error_message <<- conditionMessage(e); NULL
    })
  }
  if (!is.null(fit)) {
    if (!inherits(fit, "gllvmTMB_multi") || inherits(fit, "gllvmTMB_va") ||
        inherits(fit, "gllvmTMB_julia")) {
      error_class <- "non_laplace_route"
      error_message <- "Attempt did not return the native default Laplace fit class."
    } else {
      gate_evidence <- tryCatch(cran07_binomial_gate_evidence(fit, fixture),
        error = function(e) {
          error_class <<- "binomial_trial_gate_error"
          error_message <<- conditionMessage(e)
          NULL
        })
      if (!is.null(gate_evidence)) {
        estimands <- tryCatch(cran07_extract_estimands(
          fit, fixture, cell$cell_id, replicate, seed, as.character(cell$mode)),
          error = function(e) {
            error_class <<- "estimand_mapping_error"
            error_message <<- conditionMessage(e)
            NULL
          })
      }
    }
  }
  health <- if (!is.null(fit)) fit$fit_health else NULL
  optimizer <- isTRUE(health$optimizer_converged)
  stationary <- isTRUE(health$stationary_by_gradient)
  pd_hessian <- isTRUE(health$pd_hessian)
  assessed <- if (!is.null(estimands)) cran07_assess_estimands(estimands) else
    list(finite = FALSE, boundary = FALSE, geometry_flag = FALSE,
         catastrophic_truth_error = TRUE, relative_covariance_error = Inf,
         max_eigen_ratio = Inf)
  status <- cran07_classify_attempt(
    constructed = constructed,
    fit_error = nzchar(error_class) || nzchar(error_message),
    finite_estimands = assessed$finite,
    optimizer_converged = optimizer,
    stationary = stationary,
    pd_hessian = pd_hessian,
    boundary = assessed$boundary,
    geometry_flag = assessed$geometry_flag
  )
  detector_flagged <- status != "usable"
  attempt <- data.frame(
    campaign_id = campaign_id, registry_sha256 = registry_sha256,
    cell_id = as.character(cell$cell_id), replicate = as.integer(replicate), seed = seed,
    status = status, constructed = constructed, optimizer_converged = optimizer,
    stationary = stationary, pd_hessian = pd_hessian,
    finite_estimands = assessed$finite, boundary = assessed$boundary,
    geometry_flag = assessed$geometry_flag, detector_flagged = detector_flagged,
    catastrophic_truth_error = assessed$catastrophic_truth_error,
    relative_covariance_error = assessed$relative_covariance_error,
    max_eigen_ratio = assessed$max_eigen_ratio, error_class = error_class,
    error_message = error_message,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    convergence_code = if (!is.null(fit$opt$convergence)) fit$opt$convergence else NA_integer_,
    objective = if (!is.null(health$objective)) health$objective else NA_real_,
    max_gradient = if (!is.null(health$max_gradient)) health$max_gradient else NA_real_,
    scaled_gradient = if (!is.null(health$scaled_gradient)) health$scaled_gradient else NA_real_,
    n_trials_min = if (is.null(gate_evidence)) NA_integer_ else gate_evidence$n_trials_min,
    n_trials_max = if (is.null(gate_evidence)) NA_integer_ else gate_evidence$n_trials_max,
    diag_B_skip = if (is.null(gate_evidence)) "" else gate_evidence$diag_B_skip,
    diag_B_all_free = if (is.null(gate_evidence)) FALSE else gate_evidence$diag_B_all_free,
    warning_count = length(warnings), warning_messages = paste(unique(warnings), collapse = " | "),
    family = as.character(cell$family), mode = as.character(cell$mode),
    n_unit = as.integer(cell$n_unit), n_traits = as.integer(cell$n_traits),
    rank = as.integer(cell$rank), truth_profile = as.character(cell$truth_profile),
    stringsAsFactors = FALSE
  )
  cran07_validate_attempt_table(attempt)
  list(attempt = attempt, estimands = estimands,
       metadata = list(R = R.version.string, platform = R.version$platform,
                       gllvmTMB = as.character(utils::packageVersion("gllvmTMB")),
                       fit_class = if (!is.null(fit)) class(fit) else character(),
                       integration = "native default Laplace (integration argument omitted)",
                       formula = if (!is.null(fixture)) paste(deparse(fixture$formula), collapse = " ") else NA_character_))
}
