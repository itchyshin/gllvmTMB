# One v4 attempt. This preserves the core DGP and fit call while extending the
# ledger with source, warm-restart, structural-Psi, and NB2-dispersion evidence.

cran07_v4_align_phi_nbinom2 <- function(phi, trait_names,
                                        engine_trait_id = NULL,
                                        data_trait = NULL) {
  if (!is.numeric(phi) || length(phi) != length(trait_names) ||
      any(!is.finite(phi)) || any(phi <= 0) || anyDuplicated(trait_names)) {
    stop("NB2 requires one finite positive phi_nbinom2 per unique frozen trait.",
         call. = FALSE)
  }
  phi_names <- names(phi)
  if (!is.null(phi_names) && any(nzchar(phi_names))) {
    if (any(!nzchar(phi_names)) || anyDuplicated(phi_names) ||
        !setequal(phi_names, trait_names)) {
      stop("Named phi_nbinom2 must match the frozen trait names exactly.",
           call. = FALSE)
    }
    return(stats::setNames(as.numeric(phi[trait_names]), trait_names))
  }
  if (is.null(engine_trait_id) || is.null(data_trait)) {
    stop("Unnamed phi_nbinom2 requires an explicit verified engine trait-order map.",
         call. = FALSE)
  }
  expected_id <- as.integer(factor(data_trait, levels = trait_names)) - 1L
  if (!identical(as.integer(engine_trait_id), expected_id)) {
    stop("Engine trait IDs do not prove the frozen unnamed phi order.",
         call. = FALSE)
  }
  stats::setNames(as.numeric(phi), trait_names)
}

cran07_v4_bind_estimand_identity <- function(estimands, campaign_id,
                                              registry_sha256,
                                              source_archive_sha256) {
  estimands$campaign_id <- campaign_id
  estimands$registry_sha256 <- registry_sha256
  estimands$source_archive_sha256 <- source_archive_sha256
  estimands[, c(CRAN07_V4_IDENTITY_COLUMNS,
                setdiff(names(estimands), CRAN07_V4_IDENTITY_COLUMNS)),
            drop = FALSE]
}

cran07_v4_extract_estimands <- function(fit, fixture, cell_id, replicate, seed,
                                         mode, family_name, campaign_id,
                                         registry_sha256,
                                         source_archive_sha256) {
  out <- cran07_extract_estimands(fit, fixture, cell_id, replicate, seed, mode)
  out <- cran07_v4_normalize_structural_psi(out)
  if (identical(family_name, "nbinom2")) {
    traits <- levels(fixture$data$trait)
    phi <- cran07_v4_align_phi_nbinom2(fit$report$phi_nbinom2, traits,
      engine_trait_id = fit$tmb_data$trait_id, data_trait = fixture$data$trait)
    dispersion <- data.frame(
      cell_id = cell_id, replicate = replicate, seed = seed,
      estimand = "phi_nbinom2", component = names(phi),
      trait_i = seq_along(phi), trait_j = seq_along(phi), applicable = TRUE,
      truth = rep(as.numeric(fixture$dispersion), length(phi)),
      estimate = unname(phi), stringsAsFactors = FALSE
    )
    out <- rbind(out, dispersion)
  }
  cran07_v4_bind_estimand_identity(out, campaign_id, registry_sha256,
                                   source_archive_sha256)
}

cran07_v4_run_attempt <- function(cell, replicate, campaign_id,
                                   registry_sha256, source_archive_sha256,
                                   stage) {
  seed <- cran07_seed(cell$cell_number, replicate,
                     cran07_v4_seed_offset(campaign_id, stage))
  started <- proc.time()[["elapsed"]]
  warnings <- character()
  fixture <- fit <- estimands <- NULL
  gate_evidence <- list(n_trials_min = NA_integer_, n_trials_max = NA_integer_,
                        diag_B_skip = "", diag_B_all_free = NA)
  restart <- cran07_v4_restart_evidence(NULL, require_provenance = FALSE)
  constructed <- FALSE
  error_class <- error_message <- ""
  fixture <- tryCatch(cran07_make_fixture(cell, seed), error = function(e) {
    error_class <<- class(e)[[1L]]
    error_message <<- conditionMessage(e)
    NULL
  })
  if (!is.null(fixture)) {
    constructed <- TRUE
    fit <- tryCatch(withCallingHandlers({
      args <- list(formula = fixture$formula, data = fixture$data,
                   family = fixture$family, trait = "trait", unit = "unit",
                   silent = TRUE)
      if (!is.null(fixture$weights)) args$weights <- fixture$weights
      if (fixture$missing_include) {
        args$missing <- gllvmTMB::miss_control(response = "include")
      }
      do.call(gllvmTMB::gllvmTMB, args)
    }, warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }), error = function(e) {
      error_class <<- class(e)[[1L]]
      error_message <<- conditionMessage(e)
      NULL
    })
  }
  if (!is.null(fit)) {
    if (!inherits(fit, "gllvmTMB_multi") || inherits(fit, "gllvmTMB_va") ||
        inherits(fit, "gllvmTMB_julia")) {
      error_class <- "non_laplace_route"
      error_message <- "Attempt did not return the native default Laplace fit class."
    } else {
      restart <- tryCatch(cran07_v4_restart_record_from_fit(fit), error = function(e) {
        error_class <<- "restart_provenance_error"
        error_message <<- conditionMessage(e)
        cran07_v4_restart_evidence(NULL, require_provenance = FALSE)
      })
      gate_evidence <- tryCatch(cran07_binomial_gate_evidence(fit, fixture),
        error = function(e) {
          error_class <<- "binomial_trial_gate_error"
          error_message <<- conditionMessage(e)
          NULL
        })
      if (!is.null(gate_evidence) && !nzchar(error_class)) {
        estimands <- tryCatch(cran07_v4_extract_estimands(
          fit, fixture, as.character(cell$cell_id), replicate, seed,
          as.character(cell$mode), as.character(cell$family), campaign_id,
          registry_sha256, source_archive_sha256),
          error = function(e) {
            error_class <<- "estimand_mapping_error"
            error_message <<- conditionMessage(e)
            NULL
          })
      }
    }
  }
  health <- if (!is.null(fit)) fit$fit_health else NULL
  assessed <- if (!is.null(estimands)) cran07_v4_assess_estimands(estimands) else
    list(finite = FALSE, boundary = FALSE, geometry_flag = FALSE,
         catastrophic_truth_error = TRUE, relative_covariance_error = Inf,
         max_eigen_ratio = Inf)
  optimizer <- isTRUE(health$optimizer_converged)
  stationary <- isTRUE(health$stationary_by_gradient)
  pd_hessian <- isTRUE(health$pd_hessian)
  status <- cran07_classify_attempt(
    constructed = constructed,
    fit_error = nzchar(error_class) || nzchar(error_message),
    finite_estimands = assessed$finite, optimizer_converged = optimizer,
    stationary = stationary, pd_hessian = pd_hessian,
    boundary = assessed$boundary, geometry_flag = assessed$geometry_flag)
  attempt <- data.frame(
    campaign_id = campaign_id, registry_sha256 = registry_sha256,
    source_archive_sha256 = source_archive_sha256,
    cell_id = as.character(cell$cell_id), replicate = as.integer(replicate),
    seed = seed, status = status, constructed = constructed,
    optimizer_converged = optimizer, stationary = stationary,
    pd_hessian = pd_hessian, finite_estimands = assessed$finite,
    boundary = assessed$boundary, geometry_flag = assessed$geometry_flag,
    detector_flagged = status != "usable",
    catastrophic_truth_error = assessed$catastrophic_truth_error,
    relative_covariance_error = assessed$relative_covariance_error,
    max_eigen_ratio = assessed$max_eigen_ratio,
    family = as.character(cell$family),
    n_trials_min = if (is.null(gate_evidence)) NA_integer_ else gate_evidence$n_trials_min,
    n_trials_max = if (is.null(gate_evidence)) NA_integer_ else gate_evidence$n_trials_max,
    diag_B_skip = if (is.null(gate_evidence)) "" else gate_evidence$diag_B_skip,
    diag_B_all_free = if (is.null(gate_evidence)) FALSE else gate_evidence$diag_B_all_free,
    error_class = error_class, error_message = error_message,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    convergence_code = if (!is.null(fit$opt$convergence)) fit$opt$convergence else NA_integer_,
    objective = if (!is.null(health$objective)) health$objective else NA_real_,
    max_gradient = if (!is.null(health$max_gradient)) health$max_gradient else NA_real_,
    scaled_gradient = if (!is.null(health$scaled_gradient)) health$scaled_gradient else NA_real_,
    warning_count = length(warnings),
    warning_messages = paste(unique(warnings), collapse = " | "),
    mode = as.character(cell$mode), n_unit = as.integer(cell$n_unit),
    n_traits = as.integer(cell$n_traits), rank = as.integer(cell$rank),
    truth_profile = as.character(cell$truth_profile),
    warm_restart_attempted = restart$warm_restart_attempted,
    warm_restart_accepted = restart$warm_restart_accepted,
    objective_before_restart = restart$objective_before_restart,
    objective_after_restart = restart$objective_after_restart,
    max_gradient_before_restart = restart$max_gradient_before_restart,
    max_gradient_after_restart = restart$max_gradient_after_restart,
    convergence_code_before_restart = restart$convergence_code_before_restart,
    convergence_code_after_restart = restart$convergence_code_after_restart,
    pd_hessian_before_restart = restart$pd_hessian_before_restart,
    pd_hessian_after_restart = restart$pd_hessian_after_restart,
    boundary_before_restart = restart$boundary_before_restart,
    boundary_after_restart = restart$boundary_after_restart,
    warm_restart_trigger_reason = restart$warm_restart_trigger_reason,
    stringsAsFactors = FALSE
  )
  cran07_v4_validate_attempt_table(attempt)
  list(attempt = attempt, estimands = estimands,
       metadata = list(R = R.version.string, platform = R.version$platform,
         gllvmTMB = as.character(utils::packageVersion("gllvmTMB")),
         fit_class = if (!is.null(fit)) class(fit) else character(),
         integration = "native default Laplace (integration argument omitted)",
         formula = if (!is.null(fixture)) paste(deparse(fixture$formula),
                                                collapse = " ") else NA_character_))
}

cran07_v4_write_attempt <- function(result, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = ".cran07-v4-attempt-", tmpdir = dirname(path),
                  fileext = ".rds")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  saveRDS(result, tmp, version = 3)
  cran07_v4_validate_attempt_table(readRDS(tmp)$attempt)
  if (!file.rename(tmp, path)) stop("Atomic attempt rename failed: ", path,
                                    call. = FALSE)
  invisible(path)
}

cran07_v4_run_manifest <- function(registry, manifest, output_dir, stage,
                                    pilot_admitted_cells = NULL) {
  campaign_id <- unique(manifest$campaign_id)
  source_sha <- unique(manifest$source_archive_sha256)
  selected <- sort(unique(manifest$cell_id))
  if (length(campaign_id) != 1L || length(source_sha) != 1L) {
    stop("V4 manifest must have one campaign and source identity.", call. = FALSE)
  }
  if (stage == "production") {
    if (is.null(pilot_admitted_cells) ||
        any(!selected %in% pilot_admitted_cells)) {
      stop("V4 production runner requires the exact pilot-admitted cell subset.",
           call. = FALSE)
    }
  }
  cran07_v4_validate_manifest(manifest, registry, campaign_id, stage, source_sha,
                              selected)
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
             BLIS_NUM_THREADS = "1")
  for (i in seq_len(nrow(manifest))) {
    key <- manifest[i, , drop = FALSE]
    path <- cran07_attempt_path(output_dir, key$cell_id, key$replicate)
    if (file.exists(path)) {
      old <- tryCatch(readRDS(path), error = function(e) NULL)
      valid <- !is.null(old) && tryCatch({
        cran07_v4_validate_attempt_table(old$attempt)
        cran07_v4_assert_attempt_manifest_identity(old$attempt, key)
        TRUE
      }, error = function(e) FALSE)
      if (valid) next
      stop("Existing v4 attempt is corrupt or has another identity: ", path,
           call. = FALSE)
    }
    cell <- registry[registry$cell_id == key$cell_id, , drop = FALSE]
    result <- cran07_v4_run_attempt(cell, key$replicate, key$campaign_id,
      key$registry_sha256, key$source_archive_sha256, stage)
    cran07_v4_write_attempt(result, path)
  }
  invisible(TRUE)
}
