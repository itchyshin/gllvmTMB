#!/usr/bin/env Rscript

## Private VA / EVA comparator spine.
##
## This file is deliberately outside the package API.  It records two separate
## research scenarios: VA-R3 for complete multi-trial binomial-logit data and
## sealed Gate-1 EVA for complete Bernoulli-logit fixtures.  Their objectives
## have different meanings, so this comparator never creates a common
## shared objective-value column, rank, or comparison.  Any supplied exact result is
## an oracle/reference diagnostic only.

`%||%` <- function(x, y) if (is.null(x)) y else x

.va_eva_scalar_character <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(name, " must be one non-missing character string.", call. = FALSE)
  }
  x
}

.va_eva_empty_matrix <- function() matrix(numeric(), nrow = 0L, ncol = 0L)

.va_eva_empty_truth_gap <- function(reason = "No oracle/reference quantities supplied.") {
  list(available = FALSE, label = "oracle/reference only", reason = reason,
       beta_max_abs = NA_real_, LambdaLambdaT_max_abs = NA_real_,
       probability_max_abs = NA_real_)
}

.va_eva_as_numeric <- function(x) {
  if (is.null(x)) numeric() else as.numeric(x)
}

.va_eva_extract_tmb_handle <- function(result) {
  raw <- result$engine_result
  if (identical(result$engine, "va_r3")) return(raw$objective %||% NULL)
  if (identical(result$engine, "eva")) return(raw$objective %||% NULL)
  NULL
}

.va_eva_extract_par <- function(result, handle) {
  if (identical(result$engine, "va_r3")) {
    return(result$engine_result$best$par %||% result$fitted$parameters %||% numeric())
  }
  if (!is.null(handle$par)) return(handle$par)
  result$fixed$parameters %||% numeric()
}

.va_eva_extract_par_list <- function(handle, par) {
  if (is.null(handle) || is.null(handle$env$parList) || !is.numeric(par)) {
    return(list())
  }
  tryCatch(handle$env$parList(par), error = function(e) list())
}

.va_eva_extract_report <- function(result, handle, par) {
  if (identical(result$engine, "va_r3")) {
    return(result$engine_result$report %||% list())
  }
  if (is.null(handle) || is.null(handle$report)) return(list())
  tryCatch(handle$report(par), error = function(e) list(report_error = conditionMessage(e)))
}

.va_eva_observed_probabilities <- function(report) {
  mu <- report$mu_by_obs
  if (is.null(mu) || !is.numeric(mu) || any(!is.finite(mu))) {
    return(list(scale = "conditional_at_variational_mean", values = numeric()))
  }
  list(scale = "conditional_at_variational_mean", values = stats::plogis(as.numeric(mu)))
}

.va_eva_negative_quantity <- function(engine, score) {
  field <- switch(engine,
    va_r3 = "negative_elbo_gh",
    eva = "negative_ell_eva_taylor2",
    stop("Unsupported private engine.", call. = FALSE)
  )
  value <- score[[field]] %||% NA_real_
  if (!is.numeric(value) || length(value) != 1L) value <- NA_real_
  list(
    name = field,
    value = as.numeric(value),
    minimize = identical(score$direction, "minimize"),
    model_selection_comparable = isTRUE(score$model_selection_comparable)
  )
}

.va_eva_extract_quantities <- function(result) {
  if (identical(result$engine, "eva")) {
    score <- result$score
    return(list(
      fixed_quantities = c(result$fixed %||% list(), list(evaluation = result$evaluation %||% list())),
      fitted_quantities = result$fitted %||% list(
        available = FALSE,
        reason = "Sealed Gate-1 EVA is a fixed evaluation, not a fitted result."
      ),
      fitted_probabilities = list(
        available = FALSE, scale = "not_available", values = numeric(),
        reason = "No EVA fitted probabilities are available from a fixed evaluation."
      ),
      beta = numeric(),
      LambdaLambdaT = .va_eva_empty_matrix(),
      negative_quantity = .va_eva_negative_quantity("eva", score)
    ))
  }
  handle <- .va_eva_extract_tmb_handle(result)
  par <- .va_eva_extract_par(result, handle)
  par_list <- .va_eva_extract_par_list(handle, par)
  report <- .va_eva_extract_report(result, handle, par)
  Lambda <- report$Lambda %||% NULL
  LambdaLambdaT <- if (is.matrix(Lambda) && is.numeric(Lambda) &&
      all(is.finite(Lambda))) tcrossprod(Lambda) else .va_eva_empty_matrix()
  negative_quantity <- .va_eva_negative_quantity(result$engine, result$score)
  list(
    fixed_quantities = result$fixed %||% list(),
    fitted_quantities = list(
      available = TRUE,
      q = result$fitted$q %||% NA_integer_,
      parameters = par,
      report = report,
      parameter_list = par_list
    ),
    fitted_probabilities = c(list(available = TRUE), .va_eva_observed_probabilities(report)),
    beta = .va_eva_as_numeric(par_list$beta),
    LambdaLambdaT = LambdaLambdaT,
    negative_quantity = negative_quantity
  )
}

.va_eva_exact_truth_gap <- function(record, exact_truth = NULL) {
  if (is.null(exact_truth)) return(.va_eva_empty_truth_gap())
  if (!is.list(exact_truth) || any(vapply(exact_truth, is.function, logical(1)))) {
    stop("exact_truth must be a precomputed named list, never a function to call.",
         call. = FALSE)
  }
  allowed <- c("beta", "LambdaLambdaT", "probabilities", "label", "provenance")
  unknown <- setdiff(names(exact_truth), allowed)
  if (length(unknown)) {
    stop("exact_truth has unsupported fields: ", paste(unknown, collapse = ", "), ".",
         call. = FALSE)
  }
  max_gap <- function(observed, reference) {
    if (is.null(reference) || !is.numeric(observed) || !is.numeric(reference) ||
        length(observed) != length(reference) || any(!is.finite(reference)) ||
        !length(observed)) return(NA_real_)
    max(abs(as.numeric(observed) - as.numeric(reference)))
  }
  beta_gap <- max_gap(record$beta, exact_truth$beta)
  lambda_gap <- max_gap(record$LambdaLambdaT, exact_truth$LambdaLambdaT)
  probability_gap <- max_gap(record$fitted_probabilities$values, exact_truth$probabilities)
  available <- any(is.finite(c(beta_gap, lambda_gap, probability_gap)))
  list(
    available = available,
    label = exact_truth$label %||% "oracle/reference only",
    provenance = exact_truth$provenance %||% list(),
    beta_max_abs = beta_gap,
    LambdaLambdaT_max_abs = lambda_gap,
    probability_max_abs = probability_gap
  )
}

va_eva_validate_record <- function(record) {
  required <- c(
    "scenario", "engine", "objective_type", "admitted_regime", "fixed_quantities",
    "fitted_quantities", "fitted_probabilities", "beta", "LambdaLambdaT",
    "runtime_seconds", "convergence", "max_abs_gradient", "provenance",
    "research_only", "negative_quantity", "exact_truth_gap", "status", "error"
  )
  if (!is.list(record) || !identical(sort(names(record)), sort(required))) {
    stop("Comparator record has an invalid schema.", call. = FALSE)
  }
  .va_eva_scalar_character(record$scenario, "record$scenario")
  .va_eva_scalar_character(record$engine, "record$engine")
  .va_eva_scalar_character(record$objective_type, "record$objective_type")
  .va_eva_scalar_character(record$status, "record$status")
  if (!is.list(record$admitted_regime) || !is.list(record$fixed_quantities) ||
      !is.list(record$fitted_quantities) || !is.list(record$fitted_probabilities) ||
      !is.list(record$provenance) || !is.list(record$exact_truth_gap) ||
      !is.list(record$negative_quantity) || !is.list(record$error)) {
    stop("Comparator list-valued fields must remain lists, including errors.", call. = FALSE)
  }
  if (!is.numeric(record$beta) || !is.matrix(record$LambdaLambdaT) ||
      !is.numeric(record$LambdaLambdaT)) {
    stop("Comparator beta and LambdaLambdaT fields must be numeric.", call. = FALSE)
  }
  if (length(record$runtime_seconds) != 1L ||
      (!is.na(record$runtime_seconds) && (!is.finite(record$runtime_seconds) || record$runtime_seconds < 0))) {
    stop("Comparator runtime_seconds must be one non-negative finite value or NA.", call. = FALSE)
  }
  if (length(record$max_abs_gradient) != 1L || is.nan(record$max_abs_gradient) ||
      (!is.na(record$max_abs_gradient) && record$max_abs_gradient < 0)) {
    stop("Comparator max_abs_gradient must be one non-negative value, +Inf, or NA.", call. = FALSE)
  }
  if (!is.logical(record$research_only) || length(record$research_only) != 1L ||
      !isTRUE(record$research_only)) {
    stop("Comparator records must be explicitly research_only = TRUE.", call. = FALSE)
  }
  negative <- record$negative_quantity
  required_negative <- c("name", "value", "minimize", "model_selection_comparable")
  if (!identical(sort(names(negative)), sort(required_negative)) ||
      !is.character(negative$name) || length(negative$name) != 1L ||
      !is.numeric(negative$value) || length(negative$value) != 1L ||
      !identical(negative$minimize, TRUE) ||
      !identical(negative$model_selection_comparable, FALSE)) {
    stop("Comparator records require one engine-specific negative quantity marked minimize and non-comparable.",
         call. = FALSE)
  }
  if (record$engine %in% c("va_r3", "eva") &&
      !identical(negative$name, if (identical(record$engine, "va_r3")) "negative_elbo_gh" else "negative_ell_eva_taylor2")) {
    stop("Private-engine negative quantity does not match its engine-specific contract.", call. = FALSE)
  }
  invisible(record)
}

va_eva_validate_records <- function(records) {
  if (!is.list(records) || !length(records)) stop("records must be a non-empty list.", call. = FALSE)
  invisible(lapply(records, va_eva_validate_record))
  scenarios <- vapply(records, `[[`, character(1), "scenario")
  engines <- vapply(records, `[[`, character(1), "engine")
  if (anyDuplicated(paste(scenarios, engines, sep = "::"))) {
    stop("Each scenario-engine attempt must have its own record.", call. = FALSE)
  }
  invisible(records)
}

.va_eva_error_record <- function(scenario, engine, objective_type, admitted_regime,
                                 provenance, elapsed, error) {
  list(
    scenario = scenario,
    engine = engine,
    objective_type = objective_type,
    admitted_regime = admitted_regime,
    fixed_quantities = list(),
    fitted_quantities = list(),
    fitted_probabilities = list(scale = "not_available", values = numeric()),
    beta = numeric(),
    LambdaLambdaT = .va_eva_empty_matrix(),
    runtime_seconds = elapsed,
    convergence = NA_integer_,
    max_abs_gradient = NA_real_,
    provenance = provenance,
    research_only = TRUE,
    negative_quantity = list(
      name = if (identical(engine, "va_r3")) "negative_elbo_gh" else "negative_ell_eva_taylor2",
      value = NA_real_, minimize = TRUE, model_selection_comparable = FALSE
    ),
    exact_truth_gap = .va_eva_empty_truth_gap("Engine call failed before an oracle diagnostic."),
    status = "error",
    error = list(class = class(error), message = conditionMessage(error))
  )
}

va_eva_run_record <- function(scenario, engine = c("va_r3", "eva"), args,
                              exact_truth = NULL, adapter = .approximation_engine_fit) {
  engine <- match.arg(engine)
  scenario <- .va_eva_scalar_character(scenario, "scenario")
  if (!is.list(args)) stop("args must be a named list passed to the private adapter.", call. = FALSE)
  started <- proc.time()[["elapsed"]]
  result <- tryCatch(
    do.call(adapter, c(list(engine = engine), args)),
    error = identity
  )
  elapsed <- proc.time()[["elapsed"]] - started
  admitted <- tryCatch(.approximation_engine_regime(engine), error = function(e) list())
  if (inherits(result, "error")) {
    record <- .va_eva_error_record(
      scenario, engine,
      if (identical(engine, "va_r3")) "ELBO_GH" else "EVA_TAYLOR2",
      admitted, list(adapter = "R/approximation-engine.R"), elapsed, result
    )
    va_eva_validate_record(record)
    return(record)
  }
  if (!inherits(result, "gllvmTMB_approximation_result") || !identical(result$engine, engine)) {
    stop("The private adapter returned an unsupported engine result.", call. = FALSE)
  }
  quantities <- .va_eva_extract_quantities(result)
  runtime <- result$diagnostics$runtime_seconds %||% elapsed
  record <- list(
    scenario = scenario,
    engine = engine,
    objective_type = result$objective_type,
    admitted_regime = result$admitted_regime,
    fixed_quantities = quantities$fixed_quantities,
    fitted_quantities = quantities$fitted_quantities,
    fitted_probabilities = quantities$fitted_probabilities,
    beta = quantities$beta,
    LambdaLambdaT = quantities$LambdaLambdaT,
    runtime_seconds = as.numeric(runtime),
    convergence = result$diagnostics$convergence %||% NA_integer_,
    max_abs_gradient = as.numeric(result$diagnostics$max_abs_gradient %||% NA_real_),
    provenance = c(list(adapter = "R/approximation-engine.R"), result$provenance),
    research_only = isTRUE(result$research_only),
    negative_quantity = quantities$negative_quantity,
    exact_truth_gap = list(),
    status = result$status,
    error = list()
  )
  record$exact_truth_gap <- .va_eva_exact_truth_gap(record, exact_truth)
  va_eva_validate_record(record)
  record
}

va_eva_reference_only_record <- function(scenario, engine = c("laplace", "gllvm"),
                                         note = "Hook retained; reference computation deliberately not called.") {
  engine <- match.arg(engine)
  record <- list(
    scenario = .va_eva_scalar_character(scenario, "scenario"),
    engine = engine,
    objective_type = "REFERENCE_ONLY_NOT_EVALUATED",
    admitted_regime = list(reference_only = TRUE, no_truth_call = TRUE),
    fixed_quantities = list(),
    fitted_quantities = list(),
    fitted_probabilities = list(scale = "not_available", values = numeric()),
    beta = numeric(),
    LambdaLambdaT = .va_eva_empty_matrix(),
    runtime_seconds = NA_real_,
    convergence = NA_integer_,
    max_abs_gradient = NA_real_,
    provenance = list(note = note, gllvm_version_inspected = if (identical(engine, "gllvm")) "2.0.11" else NA_character_),
    research_only = TRUE,
    negative_quantity = list(
      name = "not_evaluated", value = NA_real_, minimize = TRUE,
      model_selection_comparable = FALSE
    ),
    exact_truth_gap = .va_eva_empty_truth_gap("LA/gllvm truth calls are deliberately prohibited."),
    status = "reference_only_not_run",
    error = list()
  )
  va_eva_validate_record(record)
  record
}

va_eva_run_private_comparator <- function(va_args = NULL,
                                           eva_args = list(fixture = "bernoulli"),
                                           exact_truth = list(va_r3 = NULL, eva = NULL),
                                           include_reference_hooks = TRUE) {
  if (!is.null(va_args) && !is.list(va_args)) stop("va_args must be NULL or a named list.", call. = FALSE)
  if (!is.list(eva_args) || !is.list(exact_truth)) stop("eva_args and exact_truth must be lists.", call. = FALSE)
  records <- list()
  if (!is.null(va_args)) {
    records[["va_r3"]] <- va_eva_run_record(
      "va_complete_multitrial_binomial_logit", "va_r3", va_args, exact_truth$va_r3
    )
  }
  records[["eva"]] <- va_eva_run_record(
    "eva_complete_bernoulli_logit", "eva", eva_args, exact_truth$eva
  )
  if (isTRUE(include_reference_hooks)) {
    records[["laplace_hook"]] <- va_eva_reference_only_record("laplace_reference_hook", "laplace")
    records[["gllvm_hook"]] <- va_eva_reference_only_record("gllvm_reference_hook", "gllvm")
  }
  va_eva_validate_records(records)
  records
}

va_eva_write_receipt <- function(records, path) {
  va_eva_validate_records(records)
  path <- normalizePath(path, mustWork = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(records, path)
  invisible(path)
}

va_eva_source_private_engines <- function(root = getwd(), envir = parent.frame()) {
  root <- normalizePath(root, mustWork = TRUE)
  files <- file.path(root, c("R/va-r3-proto.R", "R/eva-proto.R", "R/approximation-engine.R"))
  if (!all(file.exists(files))) stop("Private prototype or adapter file is absent.", call. = FALSE)
  for (file in files) sys.source(file, envir = envir)
  invisible(files)
}

va_eva_comparator_smoke <- function(root = getwd()) {
  va_eva_source_private_engines(root, envir = .GlobalEnv)
  eva <- va_eva_run_record(
    "eva_complete_bernoulli_logit", "eva", list(fixture = "bernoulli")
  )
  stopifnot(
    identical(eva$negative_quantity$name, "negative_ell_eva_taylor2"),
    identical(eva$negative_quantity$minimize, TRUE),
    identical(eva$negative_quantity$model_selection_comparable, FALSE),
    isFALSE(eva$fitted_quantities$available),
    isFALSE(eva$fitted_probabilities$available),
    !length(eva$beta),
    identical(dim(eva$LambdaLambdaT), c(0L, 0L))
  )
  eva_with_reference <- va_eva_run_record(
    "eva_complete_bernoulli_logit_reference", "eva", list(fixture = "bernoulli"),
    exact_truth = list(
      beta = c(0), LambdaLambdaT = matrix(0, 1L, 1L), probabilities = c(0.5),
      label = "precomputed oracle/reference only"
    )
  )
  stopifnot(
    isFALSE(eva_with_reference$exact_truth_gap$available),
    identical(eva_with_reference$exact_truth_gap$label, "precomputed oracle/reference only")
  )
  va_failure <- .va_eva_error_record(
    "va_complete_multitrial_binomial_logit_failed", "va_r3", "ELBO_GH", list(),
    list(adapter = "synthetic smoke"), 0, simpleError("synthetic failed VA fit")
  )
  stopifnot(
    identical(va_failure$negative_quantity$name, "negative_elbo_gh"),
    identical(va_failure$negative_quantity$minimize, TRUE),
    identical(va_failure$negative_quantity$model_selection_comparable, FALSE)
  )
  hooks <- list(
    laplace = va_eva_reference_only_record("laplace_reference_hook", "laplace"),
    gllvm = va_eva_reference_only_record("gllvm_reference_hook", "gllvm")
  )
  stopifnot(all(vapply(hooks, function(x) identical(x$status, "reference_only_not_run"), logical(1))))
  va_eva_validate_records(c(list(eva = eva, eva_reference = eva_with_reference, va_failure = va_failure), hooks))
  cat("VA_EVA_COMPARATOR_CONTRACT_SMOKE_PASS\n")
  invisible(list(eva = eva, eva_reference = eva_with_reference, va_failure = va_failure, hooks = hooks))
}

if (identical(Sys.getenv("VA_EVA_COMPARATOR_SMOKE"), "true")) {
  va_eva_comparator_smoke()
}
