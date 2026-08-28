## One-task public-route campaign runner. Sourceable without fitting.

.ISDM_CAMPAIGN_DIR <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(current) && nzchar(current)) {
    dirname(normalizePath(current, mustWork = TRUE))
  } else if (file.exists("contract.R") && file.exists("fixture.R")) {
    normalizePath(".", mustWork = TRUE)
  } else {
    normalizePath(file.path("dev", "isdm-requalification"), mustWork = TRUE)
  }
})
.isdm_campaign_dir <- function() .ISDM_CAMPAIGN_DIR
.ISDM_REPO_ROOT <- normalizePath(file.path(.ISDM_CAMPAIGN_DIR, "..", ".."),
                                 mustWork = TRUE)
source(file.path(.isdm_campaign_dir(), "contract.R"), local = TRUE)
source(file.path(.isdm_campaign_dir(), "fixture.R"), local = TRUE)
source(file.path(.isdm_campaign_dir(), "runner.R"), local = TRUE)

ISDM_PUBLIC_FORMULAS <- list(
  ordinary = value ~ 0 + trait + trait:env + offset(log_support) +
    latent(0 + trait | cell_id, d = 1),
  spatial = value ~ 0 + trait + trait:env + offset(log_support) +
    spatial_latent(0 + trait | coords, d = 1)
)

isdm_sha256 <- function(paths) {
  paths <- normalizePath(paths, mustWork = TRUE)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
  args <- if (command == "shasum") c("-a", "256", shQuote(paths)) else shQuote(paths)
  output <- system2(command, args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status") %||% 0L
  if (!identical(as.integer(status), 0L) || length(output) != length(paths)) {
    stop("SHA-256 command failed or returned the wrong number of hashes")
  }
  hashes <- sub("[[:space:]].*$", "", output)
  if (any(!grepl("^[[:xdigit:]]{64}$", hashes))) {
    stop("SHA-256 command returned malformed output")
  }
  names(hashes) <- paths
  hashes
}

isdm_installed_package_hashes <- function(package_path) {
  package_path <- normalizePath(package_path, mustWork = TRUE)
  files <- sort(list.files(package_path, recursive = TRUE, full.names = TRUE,
                           all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(files)$isdir]
  if (!length(files)) stop("installed package contains no hashable files")
  hashes <- unname(isdm_sha256(files))
  names(hashes) <- substring(files, nchar(package_path) + 2L)
  hashes
}

isdm_source_identity <- function() {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
    stop("gllvmTMB namespace is unavailable for loaded package/DLL identity")
  }
  git <- function(args) {
    out <- system2("git", c("-C", .ISDM_REPO_ROOT, args),
                   stdout = TRUE, stderr = FALSE)
    if (!length(out)) NA_character_ else out[[1L]]
  }
  relevant <- c(
    file.path(.isdm_campaign_dir(),
              c("contract.R", "fixture.R", "runner.R", "campaign.R",
                "summarise.R")),
    file.path(.ISDM_REPO_ROOT, "R",
              c("isdm-sources.R", "gllvmTMB.R", "fit-multi.R",
                "methods-gllvmTMB.R", "extract-sigma.R")),
    file.path(.ISDM_REPO_ROOT, "src", "gllvmTMB.cpp")
  )
  dll <- getLoadedDLLs()
  dll_path <- if ("gllvmTMB" %in% names(dll)) dll[["gllvmTMB"]][["path"]] else NA_character_
  package_path <- tryCatch(find.package("gllvmTMB"), error = function(e) NA_character_)
  list(
    source_sha = git(c("rev-parse", "HEAD")),
    source_tree = git(c("rev-parse", "HEAD^{tree}")),
    worktree_status = system2("git", c("-C", .ISDM_REPO_ROOT, "status", "--short"),
                              stdout = TRUE, stderr = FALSE),
    source_hashes = isdm_sha256(relevant),
    package_path = package_path,
    library_paths = .libPaths(),
    package_version = tryCatch(as.character(utils::packageVersion("gllvmTMB")),
                               error = function(e) NA_character_),
    package_hashes = if (!is.na(package_path) && dir.exists(package_path))
      isdm_installed_package_hashes(package_path) else character(),
    dll_path = dll_path,
    dll_sha256 = if (!is.na(dll_path) && file.exists(dll_path))
      unname(isdm_sha256(dll_path)) else NA_character_
  )
}

isdm_campaign_task <- function(programme, task_id) {
  task_id <- as.integer(task_id)
  plan <- switch(programme,
                 ordinary = isdm_point_plan("ordinary"),
                 attack = isdm_point_plan("attack"),
                 spatial = isdm_point_plan("spatial"),
                 interval = isdm_interval_plan(),
                 prerun = isdm_prerun_plan(),
                 stop("unknown programme: ", programme))
  task <- plan[plan$task_id == task_id, , drop = FALSE]
  if (nrow(task) != 1L) stop("task_id absent from immutable programme")
  task
}

isdm_prepare_task <- function(task) {
  programme <- task$programme[[1L]]
  if (programme %in% c("ordinary", "attack")) {
    fixture <- isdm_nonspatial_fixture(
      seed = task$structure_seed[[1L]] %||% task$seed[[1L]],
      observation_seed = task$seed[[1L]],
      n_sources = task$n_sources[[1L]], overlap = task$overlap[[1L]],
      n_cells = task$n_cells[[1L]]
    )
    formula <- ISDM_PUBLIC_FORMULAS$ordinary
  } else if (programme %in% c("spatial", "interval")) {
    fixture <- isdm_spatial_fixture(
      seed = task$seed[[1L]], n_sources = task$n_sources[[1L]],
      overlap = task$overlap[[1L]], n_cells = task$n_cells[[1L]]
    )
    formula <- ISDM_PUBLIC_FORMULAS$spatial
  } else stop("unsupported programme")
  isdm_assert_observed_source_completeness(fixture$data)
  list(task = task, fixture = fixture, formula = formula)
}

.isdm_named_fixed <- function(fit) {
  values <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  if (length(values) != length(fit$X_fix_names)) {
    stop("fixed-effect extraction length mismatch")
  }
  stats::setNames(as.numeric(values), fit$X_fix_names)
}

.isdm_bind_fixed_truth <- function(fit, truth_fixed, tolerance = 1e-8) {
  X <- as.matrix(fit$X_fix %||% fit$tmb_data$X_fix)
  if (is.null(colnames(X))) colnames(X) <- fit$X_fix_names
  if (nrow(X) != length(truth_fixed) || qr(X)$rank != ncol(X)) {
    stop("fixed truth cannot be bound to the fitted full-rank design")
  }
  value <- qr.solve(X, truth_fixed)
  residual <- max(abs(as.numeric(X %*% value) - truth_fixed))
  if (!is.finite(residual) || residual > tolerance) {
    stop("fixed truth does not lie in the fitted design column space")
  }
  stats::setNames(as.numeric(value), colnames(X))
}

.isdm_fit_diagnostics <- function(fit) {
  gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par),
                       error = function(e) NA_real_)
  checks <- tryCatch(gllvmTMB::check_gllvmTMB(fit),
                     error = function(e) NULL)
  pd <- if (is.null(checks)) NA else {
    state <- checks$status[checks$component == "pd_hessian"]
    length(state) == 1L && identical(state, "PASS")
  }
  list(convergence = fit$opt$convergence,
       objective = fit$opt$objective,
       max_gradient = if (any(is.finite(gradient)))
         max(abs(gradient), na.rm = TRUE) else NA_real_,
       pd_hessian = pd)
}

isdm_fit_public_task <- function(prepared) {
  fixture <- prepared$fixture
  spatial <- prepared$task$programme[[1L]] %in% c("spatial", "interval")
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    prepared$formula, data = fixture$data, trait = "trait", unit = "cell_id",
    family = fixture$families, mesh = if (spatial) fixture$mesh else NULL,
    silent = TRUE
  ))
  diagnostics <- .isdm_fit_diagnostics(fit)
  fixed <- .isdm_named_fixed(fit)
  fixed_truth <- .isdm_bind_fixed_truth(fit, fixture$data$truth_fixed)
  if (!spatial) {
    total <- gllvmTMB::extract_Sigma(
      fit, level = "unit", part = "total", link_residual = "none"
    )$Sigma
    unique <- gllvmTMB::extract_Sigma(
      fit, level = "unit", part = "unique", link_residual = "none"
    )$s
    predicted <- suppressMessages(stats::predict(
      fit, newdata = fixture$scoring, type = "link"
    ))$est
    estimate <- list(fixed = fixed, Sigma = total, Psi = diag(unique),
                     surface = predicted)
  } else {
    training <- suppressMessages(stats::predict(
      fit, newdata = fixture$data, type = "link"
    ))$est
    in_sample <- suppressMessages(stats::predict(fit, type = "link"))$est
    heldout <- suppressMessages(stats::predict(
      fit, newdata = fixture$map_newdata, type = "link"
    ))$est
    dispatch_link <- suppressMessages(stats::predict(
      fit, newdata = fixture$heldout, type = "link"
    ))$est
    response <- suppressMessages(stats::predict(
      fit, newdata = fixture$heldout, type = "response"
    ))$est
    laws <- fixture$design$laws[as.character(fixture$heldout$isdm_source)]
    expected_response <- ifelse(
      laws == "poisson", exp(dispatch_link), -expm1(-exp(dispatch_link))
    )
    far <- fixture$map_newdata
    far$x <- far$x + 10
    far$y <- far$y + 10
    out_of_hull_warning <- FALSE
    tryCatch(suppressMessages(withCallingHandlers(
      stats::predict(fit, newdata = far, type = "link"),
      warning = function(w) {
        if (inherits(w, "gllvmTMB_predict_newdata_outside_mesh")) {
          out_of_hull_warning <<- TRUE
        }
        invokeRestart("muffleWarning")
      }
    )), error = function(e) NULL)
    estimate <- list(
      fixed = fixed, heldout_surface = heldout,
      heldout_response = response,
      training_identity_error = max(abs(training - in_sample)),
      source_dispatch_error = max(abs(response - expected_response)),
      zero_offset_ok = all(fixture$map_newdata$log_support == 0) &&
        all(fixture$map_newdata$bias_x == 0) &&
        length(unique(fixture$map_newdata$isdm_source)) == 1L,
      out_of_hull_warning_ok = out_of_hull_warning
    )
  }
  truth <- fixture$truth
  truth$fixed <- fixed_truth
  list(diagnostics = diagnostics, estimate = estimate,
       truth = truth, design = fixture$design,
       optimizer_start = fit$tmb_obj$par,
       extraction_status = list(
         fixed = all(is.finite(fixed)),
         point = all(vapply(estimate, function(x) all(is.finite(x)), logical(1L)))
       ))
}

isdm_run_task <- function(programme, task_id, output_dir,
                          expected_sha = Sys.getenv("ISDM_PINNED_SHA", ""),
                          expected_tree = Sys.getenv("ISDM_PINNED_TREE", ""),
                          source_contract = NULL,
                          identity_fn = isdm_source_identity,
                          prepare_fn = isdm_prepare_task,
                          fit_fn = isdm_fit_public_task) {
  task <- isdm_campaign_task(programme, task_id)
  leaf <- sprintf("task-%06d.rds", task$task_id[[1L]])
  started <- list(
    schema = ISDM_RECEIPT_SCHEMA, task_id = task$task_id[[1L]],
    programme = task$programme[[1L]], seed = task$seed[[1L]],
    task_spec = as.list(task[1L, , drop = FALSE]), status = "started",
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  isdm_atomic_save(started, file.path(output_dir, "started", leaf))

  identity_result <- tryCatch(identity_fn(), interrupt = function(e) e,
                              error = function(e) e)
  identity_error <- if (inherits(identity_result, "condition")) identity_result else NULL
  identity <- if (is.null(identity_error)) identity_result else list(
    source_sha = NA_character_, source_tree = NA_character_,
    worktree_status = NA_character_, source_hashes = character(),
    package_path = NA_character_, library_paths = .libPaths(),
    package_version = NA_character_, package_hashes = character(),
    dll_path = NA_character_,
    dll_sha256 = NA_character_
  )
  if (is.null(source_contract)) {
    contract_path <- Sys.getenv("ISDM_SOURCE_CONTRACT_RDS", "")
    if (nzchar(contract_path) && file.exists(contract_path)) {
      contract_result <- tryCatch(readRDS(contract_path), error = function(e) e)
    } else {
      contract_result <- NULL
    }
  } else {
    contract_result <- source_contract
  }
  contract_error <- if (inherits(contract_result, "condition")) {
    contract_result
  } else if (!isdm_source_contract_valid(contract_result)) {
    .isdm_condition(
      "source contract is missing its schema or successful three-OS CI receipt",
      "isdm_source_contract_invalid"
    )
  } else NULL
  source_contract <- if (is.null(contract_error)) contract_result else NULL
  prepared <- tryCatch(prepare_fn(task), interrupt = function(e) e,
                       error = function(e) e)
  attempt_base <- c(
    started,
    list(expected_sha = source_contract$source_sha %||% expected_sha,
         expected_tree = source_contract$source_tree %||% expected_tree,
         expected_identity = source_contract,
         formula = if (inherits(prepared, "condition")) NA_character_ else
           paste(deparse(prepared$formula), collapse = " ")),
    identity
  )
  if (!inherits(prepared, "condition")) {
    attempt_base$truth <- prepared$fixture$truth
  }
  start <- Sys.time()
  condition <- NULL
  payload <- NULL
  status <- "fit_returned"
  failure_phase <- "fit"
  if (!is.null(identity_error)) {
    condition <- identity_error
    failure_phase <- "identity"
    status <- if (inherits(identity_error, "interrupt")) "interrupted" else
      "unavailable"
  } else if (!is.null(contract_error)) {
    condition <- contract_error
    failure_phase <- "source_contract"
    status <- "unavailable"
  } else if (inherits(prepared, "condition")) {
    condition <- prepared
    failure_phase <- "preparation"
    status <- if (inherits(prepared, "interrupt")) "interrupted" else
      "unavailable"
  } else if (is.null(source_contract) ||
             !isdm_identity_matches(identity, source_contract)) {
    condition <- .isdm_condition(
      "retained campaign source does not match the approved SHA and tree",
      "isdm_source_unavailable"
    )
    failure_phase <- "identity"
    status <- "unavailable"
  } else {
    warnings <- character()
    result <- tryCatch(
      withCallingHandlers(
        fit_fn(prepared),
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      interrupt = function(e) { condition <<- e; NULL },
      error = function(e) { condition <<- e; NULL }
    )
    if (!is.null(condition)) {
      status <- if (inherits(condition, "interrupt")) "interrupted" else "error"
    } else {
      payload <- c(result, list(warnings = warnings))
    }
  }
  if (!is.null(payload$truth)) {
    attempt_base$truth <- payload$truth
    payload$truth <- NULL
  }
  attempt_base$failure_phase <- failure_phase
  record <- isdm_terminal_record(
    attempt_base, status = status,
    runtime_s = as.numeric(difftime(Sys.time(), start, units = "secs")),
    payload = payload %||% list(), condition = condition
  )
  record$session_info <- capture.output(utils::sessionInfo())
  isdm_atomic_save(record, file.path(output_dir, "attempts", leaf))
  record
}

.isdm_cli_args <- commandArgs(trailingOnly = TRUE)
if (length(.isdm_cli_args) == 4L && identical(.isdm_cli_args[[1L]], "--task")) {
  result <- isdm_run_task(
    programme = .isdm_cli_args[[2L]], task_id = as.integer(.isdm_cli_args[[3L]]),
    output_dir = .isdm_cli_args[[4L]]
  )
  print(result[c("task_id", "programme", "seed", "status", "runtime_s")])
}
