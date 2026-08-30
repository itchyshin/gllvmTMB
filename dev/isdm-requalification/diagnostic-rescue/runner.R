## Retained runner for the approved 52-task sentinel experiment.
## Fitting enters only through public gllvmTMB().

.diag_script <- Sys.getenv("ISDM_DIAG_RUNNER_FILE", unset = "")
if (!nzchar(.diag_script)) {
  .diag_script <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
}
if (is.null(.diag_script) || !nzchar(.diag_script)) {
  .diag_script <- local({
    current <- NULL
  if (is.null(current) || !nzchar(current)) {
    script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
    candidates <- c(
      if (length(script) == 1L) sub("^--file=", "", script) else character(),
      file.path("dev", "isdm-requalification", "diagnostic-rescue", "runner.R"),
      "runner.R"
    )
    current <- candidates[file.exists(candidates)][[1L]]
  }
  current
  })
}
.diag_dir <- dirname(normalizePath(.diag_script, mustWork = TRUE))
.repo_root <- normalizePath(file.path(.diag_dir, "..", "..", ".."),
                            mustWork = TRUE)
source(file.path(.diag_dir, "record.R"), local = TRUE)
source(file.path(.diag_dir, "contract.R"), local = TRUE)
source(file.path(.diag_dir, "diagnostics.R"), local = TRUE)
source(file.path(.repo_root, "dev", "isdm-requalification", "fixture.R"),
       local = TRUE)

diagnostic_verify_runtime_identity <- function(qualification) {
  if (!identical(qualification$schema, "isdm-diagnostic-qualification-v1") ||
      !identical(qualification$source_sha,
                 "09eca7b1eb9018958bad367be824871161a60af1") ||
      !identical(qualification$source_tree,
                 "fb979daa5d9a93d0804a053ff1bb00eced47ad09")) {
    diagnostic_abort("invalid qualification source identity",
                     "isdm_diagnostic_source_unavailable")
  }
  package_path <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
  dlls <- getLoadedDLLs()
  dll_path <- if ("gllvmTMB" %in% names(dlls)) {
    normalizePath(dlls[["gllvmTMB"]][["path"]], mustWork = TRUE)
  } else NA_character_
  observed_dll <- if (!is.na(dll_path)) unname(diagnostic_sha256(dll_path)) else NA_character_
  installed_files <- sort(list.files(package_path, recursive = TRUE,
                                     full.names = TRUE, all.files = TRUE,
                                     no.. = TRUE))
  installed_files <- installed_files[!file.info(installed_files)$isdir]
  installed_manifest <- data.frame(
    path = substring(installed_files, nchar(package_path) + 2L),
    sha256 = unname(diagnostic_sha256(installed_files)),
    stringsAsFactors = FALSE
  )
  if (!identical(package_path, qualification$package_path) ||
      !identical(dll_path, qualification$dll_path) ||
      !identical(observed_dll, qualification$dll_sha256) ||
      !identical(diagnostic_object_hash(installed_manifest),
                 qualification$installed_manifest_sha256)) {
    diagnostic_abort("loaded package/DLL differs from qualification",
                     "isdm_diagnostic_source_unavailable")
  }
  if (!identical(unname(diagnostic_sha256(
        qualification$harness_manifest_path)),
      qualification$harness_manifest_sha256)) {
    diagnostic_abort("harness manifest differs from qualification",
                     "isdm_diagnostic_source_unavailable")
  }
  old_wd <- setwd(qualification$harness_root)
  on.exit(setwd(old_wd), add = TRUE)
  checked <- system2("sha256sum", c("-c", qualification$harness_manifest_path),
                     stdout = TRUE, stderr = TRUE)
  if (!identical(as.integer(attr(checked, "status") %||% 0L), 0L)) {
    diagnostic_abort("harness bytes differ from qualification",
                     "isdm_diagnostic_source_unavailable")
  }
  invisible(TRUE)
}

diagnostic_verify_plan_identity <- function(plan_path, run_kind, qualification) {
  observed <- unname(diagnostic_sha256(plan_path))
  expected <- qualification$plan_sha256[[run_kind]] %||% NA_character_
  if (!identical(observed, expected)) {
    diagnostic_abort("plan bytes differ from qualification",
                     "isdm_diagnostic_plan_unavailable")
  }
  invisible(TRUE)
}

diagnostic_public_formula <- function(slice) {
  if (identical(slice, "nonspatial")) {
    value ~ 0 + trait + trait:env + offset(log_support) +
      latent(0 + trait | cell_id, d = 1)
  } else {
    value ~ 0 + trait + trait:env + offset(log_support) +
      spatial_latent(0 + trait | coords, d = 1)
  }
}

diagnostic_fit_health <- function(fit, curvature) {
  gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par),
                       error = function(e) NA_real_)
  list(
    convergence = as.integer(fit$opt$convergence),
    optimizer_objective = as.numeric(fit$opt$objective),
    fresh_objective = curvature$fresh_objective %||% NA_real_,
    objective_difference = curvature$objective_difference %||% NA_real_,
    finite_objective = is.finite(curvature$fresh_objective %||% NA_real_),
    max_gradient = if (any(is.finite(gradient)))
      max(abs(gradient), na.rm = TRUE) else NA_real_,
    pd_hessian = fit$sd_report$pdHess %||% NA,
    restart_history = fit$restart_history,
    start_provenance = fit$start_provenance
  )
}

diagnostic_fit_return_receipt <- function(fit) {
  list(
    convergence = as.integer(fit$opt$convergence %||% NA_integer_),
    optimizer_objective = as.numeric(fit$opt$objective %||% NA_real_),
    pd_hessian = fit$sd_report$pdHess %||% NA,
    restart_history = fit$restart_history %||% data.frame(),
    start_provenance = fit$start_provenance %||% list()
  )
}

diagnostic_relative_frobenius <- function(estimate, truth) {
  sqrt(sum((estimate - truth)^2)) / sqrt(sum(truth^2))
}

diagnostic_psi_matrix <- function(unique, truth) {
  values <- if (is.matrix(unique)) diag(unique) else as.numeric(unique)
  psi <- diag(values, nrow = length(values))
  if (!identical(dim(psi), dim(truth))) {
    diagnostic_abort("unique covariance dimensions differ from truth")
  }
  dimnames(psi) <- dimnames(truth)
  psi
}

diagnostic_nonspatial_payload <- function(fit, fixture) {
  truth <- diagnostic_nonspatial_truth_components(fixture)
  estimate <- diagnostic_extract_nonspatial(fit, fixture)
  trait <- as.character(fixture$scoring$trait)
  truth_vectors <- lapply(truth[c("fixed", "shared", "full")],
                          .diagnostic_surface_vector,
                          scoring = fixture$scoring)
  metrics <- lapply(names(truth_vectors), function(target) {
    diagnostic_surface_metrics(estimate[[target]], truth_vectors[[target]], trait)
  })
  names(metrics) <- names(truth_vectors)
  sigma <- gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "none"
  )$Sigma
  unique <- gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "unique", link_residual = "none"
  )$s
  psi <- diagnostic_psi_matrix(unique, fixture$truth$Psi)
  curvature <- diagnostic_curvature(fit)
  list(
    diagnostics = diagnostic_fit_health(fit, curvature),
    curvature = curvature,
    estimate = list(surfaces = estimate[c("fixed", "shared", "full")],
                    Sigma = sigma, Psi = psi),
    truth = list(surfaces = truth_vectors, Sigma = fixture$truth$Sigma,
                 Psi = fixture$truth$Psi, trait = trait),
    metrics = c(metrics, list(
      Sigma_relative_frobenius = diagnostic_relative_frobenius(
        sigma, fixture$truth$Sigma
      ),
      Psi_relative_error = diag(abs(psi - fixture$truth$Psi) /
                                  diag(fixture$truth$Psi)),
      full_public_identity_error = estimate$identity_error,
      sign_invariance_error = estimate$sign_invariance$max_error
    )),
    optimizer_start_hash = diagnostic_object_hash(fit$tmb_obj$par),
    design = fixture$design
  )
}

diagnostic_spatial_payload <- function(fit, fixture) {
  curvature <- diagnostic_curvature(fit)
  training_newdata <- fixture$data[setdiff(names(fixture$data), "value")]
  training <- suppressMessages(stats::predict(
    fit, newdata = training_newdata, type = "link"
  ))$est
  in_sample <- suppressMessages(stats::predict(fit, type = "link"))$est
  heldout <- suppressMessages(stats::predict(
    fit, newdata = fixture$map_newdata, type = "link"
  ))$est
  metrics <- diagnostic_surface_metrics(
    heldout, fixture$truth$heldout_surface, fixture$truth$heldout_trait
  )
  list(
    diagnostics = diagnostic_fit_health(fit, curvature),
    curvature = curvature,
    estimate = list(heldout_surface = heldout,
                    training_identity_error = max(abs(training - in_sample))),
    truth = list(heldout_surface = fixture$truth$heldout_surface,
                 heldout_trait = fixture$truth$heldout_trait),
    metrics = list(heldout = metrics),
    optimizer_start_hash = diagnostic_object_hash(fit$tmb_obj$par),
    design = fixture$design
  )
}

diagnostic_fit_public <- function(fixture, slice, control = NULL) {
  args <- list(
    formula = diagnostic_public_formula(slice), data = fixture$data,
    trait = "trait", unit = "cell_id", family = fixture$families,
    silent = TRUE
  )
  if (identical(slice, "spatial")) args$mesh <- fixture$mesh
  if (!is.null(control)) args$control <- control
  suppressMessages(do.call(gllvmTMB::gllvmTMB, args))
}

diagnostic_run_one <- function(task, output_dir, qualification, fit_fn,
                               dependency_payload = list()) {
  started <- diagnostic_write_started(task, output_dir, qualification)
  begin <- Sys.time()
  warnings <- character()
  condition <- NULL
  public_fit_call_entered <- FALSE
  fit_returned <- FALSE
  fit_return_receipt <- NULL
  mark_public_fit_call_entered <- function() public_fit_call_entered <<- TRUE
  mark_fit_returned <- function(fit) {
    fit_returned <<- TRUE
    fit_return_receipt <<- diagnostic_fit_return_receipt(fit)
    invisible(fit)
  }
  payload <- tryCatch(withCallingHandlers({
    diagnostic_verify_runtime_identity(qualification)
    fit_fn(mark_public_fit_call_entered, mark_fit_returned)
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), interrupt = function(e) { condition <<- e; NULL },
  error = function(e) { condition <<- e; NULL })
  status <- if (fit_returned) "fit_returned" else if (is.null(condition)) {
    "error"
  } else if (
    inherits(condition, "interrupt")) "interrupted" else if (
      inherits(condition, "isdm_diagnostic_source_unavailable")) "unavailable" else
        "error"
  restart_history <- fit_return_receipt$restart_history %||% NULL
  optimizer_entered <- if (!is.null(restart_history)) {
    is.data.frame(restart_history) && nrow(restart_history) > 0L
  } else if (public_fit_call_entered) NA else FALSE
  record <- diagnostic_terminal_record(
    started, status = status,
    runtime_s = as.numeric(difftime(Sys.time(), begin, units = "secs")),
    payload = c(payload %||% list(), dependency_payload,
                list(fit_status = if (fit_returned) "returned" else
                       if (public_fit_call_entered) "not_returned" else "not_entered",
                     extraction_status = if (fit_returned && is.null(condition))
                       "available" else if (fit_returned) "error" else "not_attempted",
                     fit_return = fit_return_receipt,
                     warnings = warnings)),
    condition = condition, optimizer_entered = optimizer_entered,
    public_fit_call_entered = public_fit_call_entered
  )
  diagnostic_write_terminal(record, output_dir)
  list(record = record, payload = payload, condition = condition)
}

diagnostic_run_unavailable <- function(task, output_dir, qualification,
                                       message, dependency_payload = list()) {
  started <- diagnostic_write_started(task, output_dir, qualification)
  condition <- structure(list(message = message, call = NULL),
                         class = c("isdm_diagnostic_dependency_unavailable",
                                   "error", "condition"))
  record <- diagnostic_terminal_record(
    started, status = "unavailable", runtime_s = 0,
    payload = c(dependency_payload,
                list(fit_status = "not_entered",
                     extraction_status = "not_attempted")),
    condition = condition,
    optimizer_entered = FALSE, public_fit_call_entered = FALSE
  )
  diagnostic_write_terminal(record, output_dir)
  list(record = record, payload = NULL, condition = condition)
}

diagnostic_run_nonspatial <- function(task, output_dir, qualification) {
  diagnostic_run_one(task, output_dir, qualification, function(mark_public_fit_call_entered,
                                                                mark_fit_returned) {
    fixture <- isdm_nonspatial_fixture(
      seed = task$structure_seed[[1L]], observation_seed = task$seed[[1L]],
      n_sources = task$n_sources[[1L]], overlap = task$overlap[[1L]],
      n_cells = task$n_cells[[1L]]
    )
    if (identical(task$variant[[1L]], "rep3")) {
      fixture <- diagnostic_rep3_fixture(fixture, task$native_task_id[[1L]])
    }
    set.seed(task$optimizer_seed[[1L]])
    mark_public_fit_call_entered()
    fit <- diagnostic_fit_public(fixture, "nonspatial")
    mark_fit_returned(fit)
    payload <- diagnostic_nonspatial_payload(fit, fixture)
    if (identical(task$variant[[1L]], "rep3")) {
      payload$rep3_baseline_byte_identical <- TRUE
    }
    payload
  })
}

diagnostic_parameter_blocks <- function(fit, blocks) {
  par <- fit$tmb_obj$env$parList(fit$tmb_obj$env$last.par.best)
  par[intersect(blocks, names(par))]
}

diagnostic_copy_check <- function(default_fit, continuation_fit) {
  blocks <- c("b_fix", "log_kappa_spde", "theta_rr_spde_lv",
              "omega_spde_lv")
  expected <- diagnostic_parameter_blocks(default_fit, blocks)
  observed <- continuation_fit$tmb_params[intersect(blocks,
                                                     names(continuation_fit$tmb_params))]
  missing <- setdiff(blocks, intersect(names(expected), names(observed)))
  equality <- vapply(intersect(names(expected), names(observed)), function(block) {
    identical(as.numeric(expected[[block]]), as.numeric(observed[[block]]))
  }, logical(1L))
  list(
    blocks = blocks, missing = missing, equal = equality,
    all_equal = !length(missing) && length(equality) == length(blocks) && all(equality),
    expected_hash = diagnostic_object_hash(expected),
    observed_hash = diagnostic_object_hash(observed)
  )
}

diagnostic_run_spatial_group <- function(tasks, output_dir, qualification) {
  order <- match(c("default", "bfgs_continuation", "nlminb5"), tasks$variant)
  if (anyNA(order)) diagnostic_abort("spatial group lacks three frozen variants")
  tasks <- tasks[order, , drop = FALSE]
  fixture <- isdm_spatial_fixture(
    seed = tasks$seed[[1L]], n_sources = tasks$n_sources[[1L]],
    overlap = tasks$overlap[[1L]], n_cells = tasks$n_cells[[1L]]
  )

  default_task <- tasks[tasks$variant == "default", , drop = FALSE]
  default_fit <- NULL
  default_result <- diagnostic_run_one(
    default_task, output_dir, qualification, function(mark_public_fit_call_entered,
                                                       mark_fit_returned) {
      set.seed(default_task$optimizer_seed[[1L]])
      mark_public_fit_call_entered()
      default_fit <<- diagnostic_fit_public(fixture, "spatial")
      mark_fit_returned(default_fit)
      payload <- diagnostic_spatial_payload(default_fit, fixture)
      observed_class <- tryCatch(isdm_diag_outcome_class(
        default_fit$opt$convergence, default_fit$sd_report$pdHess,
        "fit_returned"), error = function(e) "unavailable")
      payload$production_outcome_class <- default_task$sentinel_class[[1L]]
      payload$observed_outcome_class <- observed_class
      payload$historical_class_match <- identical(
        observed_class, default_task$sentinel_class[[1L]]
      )
      payload
    }, dependency_payload = list(
      production_outcome_class = default_task$sentinel_class[[1L]]
    )
  )

  bfgs_task <- tasks[tasks$variant == "bfgs_continuation", , drop = FALSE]
  if (is.null(default_fit)) {
    bfgs_result <- diagnostic_run_unavailable(
      bfgs_task, output_dir, qualification,
      "live default fit unavailable for public BFGS continuation",
      list(default_task_id = default_task$task_id[[1L]])
    )
  } else {
    bfgs_fit <- NULL
    bfgs_result <- diagnostic_run_one(
      bfgs_task, output_dir, qualification, function(mark_public_fit_call_entered,
                                                      mark_fit_returned) {
        set.seed(bfgs_task$optimizer_seed[[1L]])
        control <- gllvmTMB::gllvmTMBcontrol(
          start_from = default_fit, n_init = 1L, init_jitter = 0,
          optimizer = "optim",
          optArgs = list(method = "BFGS",
                         control = list(maxit = 5000L, reltol = 1e-10))
        )
        mark_public_fit_call_entered()
        bfgs_fit <<- diagnostic_fit_public(fixture, "spatial", control)
        mark_fit_returned(bfgs_fit)
        copy <- diagnostic_copy_check(default_fit, bfgs_fit)
        c(diagnostic_spatial_payload(bfgs_fit, fixture),
          list(continuation_copy = copy,
               target_available = isTRUE(copy$all_equal) &&
                 isTRUE(default_result$payload$historical_class_match),
               target_unavailable_reason = if (!isTRUE(copy$all_equal))
                 "public_start_copy_mismatch" else if (
                   !isTRUE(default_result$payload$historical_class_match))
                 "historical_default_class_mismatch" else NULL,
               default_task_id = default_task$task_id[[1L]]))
      }
    )
  }

  nlminb_task <- tasks[tasks$variant == "nlminb5", , drop = FALSE]
  nlminb_fit <- NULL
  nlminb_result <- diagnostic_run_one(
    nlminb_task, output_dir, qualification, function(mark_public_fit_call_entered,
                                                     mark_fit_returned) {
      set.seed(nlminb_task$optimizer_seed[[1L]])
      control <- gllvmTMB::gllvmTMBcontrol(n_init = 5L, init_jitter = 0.3)
      mark_public_fit_call_entered()
      nlminb_fit <<- diagnostic_fit_public(fixture, "spatial", control)
      mark_fit_returned(nlminb_fit)
      payload <- diagnostic_spatial_payload(nlminb_fit, fixture)
      payload$default_first_start_hash <- default_result$payload$optimizer_start_hash %||%
        NA_character_
      payload$first_start_equal_default <- identical(
        payload$optimizer_start_hash, payload$default_first_start_hash
      )
      payload$target_available <- isTRUE(payload$first_start_equal_default) &&
        isTRUE(default_result$payload$historical_class_match)
      payload$target_unavailable_reason <- if (
        !isTRUE(payload$first_start_equal_default)) "first_start_mismatch" else if (
          !isTRUE(default_result$payload$historical_class_match))
        "historical_default_class_mismatch" else NULL
      payload
    }
  )
  invisible(list(default = default_result, bfgs = bfgs_result,
                 nlminb5 = nlminb_result))
}

diagnostic_runner_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 6L || !args[[1L]] %in% c("nonspatial", "spatial-group") ||
      !args[[6L]] %in% c("smoke", "experiment")) {
    stop(paste("usage: runner.R nonspatial|spatial-group KEY PLAN_RDS",
               "OUTPUT_DIR QUALIFICATION_RDS smoke|experiment"))
  }
  mode <- args[[1L]]
  key <- as.integer(args[[2L]])
  plan <- readRDS(args[[3L]])
  output_dir <- args[[4L]]
  qualification <- readRDS(args[[5L]])
  run_kind <- args[[6L]]
  diagnostic_verify_plan_identity(args[[3L]], run_kind, qualification)
  if (identical(run_kind, "experiment")) isdm_diag_validate_plan(plan) else
    isdm_diag_validate_smoke_plan(plan)
  .libPaths(c(dirname(qualification$package_path), .libPaths()))
  suppressPackageStartupMessages(library(gllvmTMB))
  if (mode == "nonspatial") {
    task <- plan[plan$task_id == key & plan$slice == "nonspatial", , drop = FALSE]
    if (nrow(task) != 1L) stop("nonspatial task key is not unique")
    diagnostic_run_nonspatial(task, output_dir, qualification)
  } else {
    tasks <- plan[plan$native_task_id == key & plan$slice == "spatial", ,
                  drop = FALSE]
    if (nrow(tasks) != 3L) stop("spatial native task key lacks three variants")
    diagnostic_run_spatial_group(tasks, output_dir, qualification)
  }
  cat("DIAGNOSTIC_RUNNER_COMPLETE\n")
}

if (sys.nframe() == 0L) diagnostic_runner_main()
