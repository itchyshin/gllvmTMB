# Scientific fitting helpers for the private Design 98 discriminator.
# No function in this file creates a real-run root.

d98_fit_design_dir <- function() {
  candidates <- c(
    getOption("d98_design_dir"),
    file.path(getwd(), "dev", "design98-factorial-va-jj"),
    getwd()
  )
  hit <- candidates[
    file.exists(file.path(candidates, "R", "oracle.R")) &
      file.exists(file.path(candidates, "src", "design98_gh.cpp"))
  ]
  if (!length(hit)) stop("Cannot locate the Design 98 private sources")
  normalizePath(hit[[1L]])
}

if (!exists("d98_gh", mode = "function")) {
  source(file.path(d98_fit_design_dir(), "R", "oracle.R"))
}
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

d98_fit_num <- function(x) {
  as.numeric(unlist(x, recursive = TRUE, use.names = FALSE))
}

d98_fit_matrix <- function(x, nrow = NULL, ncol = NULL) {
  if (is.matrix(x)) return(matrix(as.numeric(x), nrow(x), ncol(x)))
  if (is.list(x) && length(x) &&
      all(vapply(x, is.list, logical(1)))) {
    rows <- lapply(x, d98_fit_num)
    widths <- vapply(rows, length, integer(1))
    if (length(unique(widths)) != 1L) stop("Ragged matrix payload")
    return(do.call(rbind, rows))
  }
  values <- d98_fit_num(x)
  if (is.null(nrow) || is.null(ncol) || length(values) != nrow * ncol) {
    stop("Matrix payload needs compatible dimensions")
  }
  matrix(values, nrow, ncol)
}

d98_fit_truth <- function(x) {
  if (is.null(x)) return(NULL)
  beta <- d98_fit_num(x$beta)
  loading <- d98_fit_matrix(x$loading)
  if (length(beta) != nrow(loading) || ncol(loading) != 2L) {
    stop("Truth beta/loading dimensions disagree")
  }
  list(beta = beta, loading = loading)
}

d98_declared_global_starts <- function(y, truth) {
  d98_validate_response(y)
  truth <- d98_fit_truth(truth)
  if (is.null(truth) || length(truth$beta) != ncol(y)) {
    stop("Declared starts require conformable truth")
  }
  empirical <- qlogis(pmin(0.95, pmax(0.05, colMeans(y))))
  traits <- ncol(y)
  if (traits != 6L) {
    # Toy-only extension retains the exact A/C leading block and truncates the
    # frozen row-wise tail. Real Design 98 fixtures are always T = 6.
    tail_a <- rep(0, 2L * traits - 4L)
    tail_c <- rep(c(0.10, -0.10, -0.10, 0.10, 0.15, -0.10,
                    -0.10, -0.15), length.out = 2L * traits - 4L)
    beta_c_delta <- rep(c(0.15, -0.10, 0.05, 0.10, -0.05, -0.15),
                        length.out = traits)
  } else {
    tail_a <- rep(0, 8L)
    tail_c <- c(0.10, -0.10, -0.10, 0.10, 0.15, -0.10, -0.10, -0.15)
    beta_c_delta <- c(0.15, -0.10, 0.05, 0.10, -0.05, -0.15)
  }
  truth_delta <- rep(c(0.05, -0.04, 0.03, -0.02, 0.01, -0.05),
                     length.out = traits)
  list(
    A = list(
      start_id = "A",
      beta = empirical,
      loading_free = c(log(0.40), 0, log(0.40), tail_a)
    ),
    B = list(
      start_id = "B",
      beta = truth$beta + truth_delta,
      loading_free = d98_loading_to_free(0.90 * truth$loading)
    ),
    C = list(
      start_id = "C",
      beta = empirical + beta_c_delta,
      loading_free = c(log(0.65), 0.10, log(0.60), tail_c)
    )
  )
}

d98_declared_local_start <- function(n, full) {
  list(
    mean = matrix(0, n, 2L),
    chol_free = if (isTRUE(full)) {
      cbind(rep(log(0.8), n), rep(0, n), rep(log(0.8), n))
    } else {
      cbind(rep(log(0.8), n), rep(log(0.8), n))
    }
  )
}

d98_fit_method_id <- function(method) {
  ids <- c(QD = 0L, QF = 1L, JD = 2L, JF = 3L)
  if (length(method) != 1L || !method %in% names(ids)) {
    stop("method must be QD, QF, JD, or JF")
  }
  unname(ids[[method]])
}

d98_fit_full <- function(method) method %in% c("QF", "JF")

.d98_fit_cache <- new.env(parent = emptyenv())

d98_compile_fit_template <- function(kind, design_dir = d98_fit_design_dir()) {
  if (!kind %in% c("gh", "variational")) stop("Unknown template kind")
  if (exists(kind, envir = .d98_fit_cache, inherits = FALSE)) {
    return(get(kind, envir = .d98_fit_cache, inherits = FALSE))
  }
  if (!requireNamespace("TMB", quietly = TRUE)) stop("TMB is required")
  stem <- if (kind == "gh") "design98_gh" else "design98_variational"
  build_dir <- tempfile(paste0(stem, "-"))
  if (!dir.create(build_dir)) stop("Cannot create temporary build directory")
  copied <- file.copy(
    file.path(design_dir, "src", paste0(stem, ".cpp")),
    file.path(build_dir, paste0(stem, ".cpp"))
  )
  if (!copied) stop("Cannot copy private TMB source")
  old <- setwd(build_dir)
  on.exit(setwd(old), add = TRUE)
  TMB::compile(paste0(stem, ".cpp"), flags = "-O0")
  dll_path <- normalizePath(TMB::dynlib(stem))
  dyn.load(dll_path)
  setwd(old)
  value <- list(
    kind = kind,
    stem = stem,
    build_dir = build_dir,
    dll_path = dll_path
  )
  assign(kind, value, envir = .d98_fit_cache)
  value
}

d98_cleanup_fit_cache <- function() {
  for (kind in ls(.d98_fit_cache, all.names = TRUE)) {
    value <- get(kind, envir = .d98_fit_cache, inherits = FALSE)
    try(dyn.unload(value$dll_path), silent = TRUE)
    unlink(value$build_dir, recursive = TRUE, force = TRUE)
    rm(list = kind, envir = .d98_fit_cache)
  }
  invisible(TRUE)
}

d98_fit_y <- function(input, root = NULL) {
  if (!is.null(input$y)) {
    y <- d98_fit_matrix(input$y)
  } else {
    if (is.null(root) || is.null(input$fixture$label)) {
      stop("Fixture reference cannot be resolved")
    }
    fixture_path <- file.path(
      root, "fixtures", paste0(input$fixture$label, ".json")
    )
    fixture_read <- d98_read_json(fixture_path)
    if (!fixture_read$ok) stop("Fixture record is missing or malformed")
    fixture <- fixture_read$value
    y <- d98_fit_matrix(fixture$y)
    expected <- input$fixture
    if (!identical(as.character(fixture$label), as.character(expected$label)) ||
        nrow(y) != as.integer(expected$n) ||
        ncol(y) != as.integer(expected$traits) ||
        !identical(as.character(fixture$sha256),
                   as.character(expected$sha256)) ||
        !identical(
          d98_hash_object(matrix(
            as.integer(y), nrow = nrow(y), ncol = ncol(y)
          )),
          as.character(expected$sha256)
        )) {
      stop("Fixture record does not match immutable task reference")
    }
  }
  storage.mode(y) <- "double"
  d98_validate_response(y)
  y
}

d98_fit_method <- function(input) {
  if (is.list(input$method) && !is.null(input$method$id)) {
    return(as.character(input$method$id))
  }
  as.character(input$method)
}

d98_fit_start <- function(input, y, truth) {
  start <- input[["start"]]
  if (is.null(start) && !is.null(input[["start_id"]])) {
    return(d98_declared_global_starts(y, truth)[[
      as.character(input[["start_id"]])
    ]])
  }
  if (is.null(start) || is.null(start$id)) {
    stop("Phase-1 task lacks its immutable declared start")
  }
  beta_rule <- as.character(start$beta_rule %||% "")
  beta <- if (!is.null(start$beta)) {
    d98_fit_num(start$beta)
  } else if (identical(beta_rule, "empirical_logit")) {
    empirical <- qlogis(pmin(0.95, pmax(0.05, colMeans(y))))
    empirical + d98_fit_num(start$beta_offset %||% rep(0, ncol(y)))
  } else {
    stop("Declared start does not define beta")
  }
  loading_free <- d98_fit_num(start$loading_free)
  if (length(beta) != ncol(y) ||
      length(loading_free) != 2L * ncol(y) - 1L) {
    stop("Declared start dimensions disagree with fixture")
  }
  list(
    start_id = as.character(start$id),
    beta = beta,
    loading_free = loading_free
  )
}

d98_fit_gh <- function(input, order = 31L) {
  requested <- input$gh_orders[[as.character(order)]]
  if (!is.null(requested)) {
    gh <- list(
      z = d98_fit_num(requested$z),
      w = d98_fit_num(requested$w)
    )
  } else {
    gh <- d98_gh(order)
  }
  if (length(gh$z) != order || length(gh$w) != order ||
      any(!is.finite(gh$z)) || any(!is.finite(gh$w)) ||
      any(gh$w <= 0) || abs(sum(gh$w) - 1) > 1e-12) {
    stop("Invalid normalized GH rule")
  }
  gh
}

d98_dependency_value <- function(x) {
  if (is.list(x) && "payload" %in% names(x)) x$payload else x
}

d98_dependency_payload <- function(dependencies, index = 1L) {
  if (length(dependencies) < index) stop("Missing dependency payload")
  payload <- d98_dependency_value(dependencies[[index]])
  if (is.null(payload)) stop("Dependency retained no payload")
  if (!identical(payload$status, "healthy")) {
    stop("Dependency payload is not healthy")
  }
  payload
}

d98_global_from_payload <- function(payload, traits) {
  if (!is.null(payload$transformed_parameters$beta) &&
      !is.null(payload$transformed_parameters$loading_free)) {
    return(list(
      beta = d98_fit_num(payload$transformed_parameters$beta),
      loading_free = d98_fit_num(
        payload$transformed_parameters$loading_free
      )
    ))
  }
  d98_unpack_global(d98_fit_num(payload$raw_coordinates), traits)
}

d98_build_gh_objective <- function(y, beta, loading_free, gh) {
  compiled <- d98_compile_fit_template("gh")
  TMB::MakeADFun(
    data = list(y = y, gh_nodes = gh$z, gh_weights = gh$w),
    parameters = list(beta = beta, loading_free = loading_free),
    DLL = compiled$stem,
    silent = TRUE
  )
}

d98_build_va_objective <- function(
    y, beta, loading_free, mean, chol_free, method, gh,
    fixed_global = FALSE) {
  compiled <- d98_compile_fit_template("variational")
  map <- if (isTRUE(fixed_global)) {
    list(
      beta = factor(rep(NA, length(beta))),
      loading_free = factor(rep(NA, length(loading_free)))
    )
  } else {
    NULL
  }
  TMB::MakeADFun(
    data = list(
      y = y,
      method_id = d98_fit_method_id(method),
      gh_nodes = gh$z,
      gh_weights = gh$w
    ),
    parameters = list(
      beta = beta,
      loading_free = loading_free,
      mean = mean,
      chol_free = chol_free
    ),
    map = map,
    DLL = compiled$stem,
    silent = TRUE
  )
}

d98_transform_global <- function(beta, loading_free, gh61 = d98_gh(61L)) {
  loading <- d98_loading_from_free(loading_free, length(beta))
  Sigma <- loading %*% t(loading)
  eigenvalues <- eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values
  list(
    beta = as.numeric(beta),
    loading_free = as.numeric(loading_free),
    loading = loading,
    Sigma = Sigma,
    covariance_eigenvalues = eigenvalues[seq_len(2L)],
    marginal_probability = d98_marginal_probability(
      beta, loading_free, gh61
    )
  )
}

d98_transform_variational <- function(
    beta, loading_free, mean, chol_free, method, gh61 = d98_gh(61L)) {
  global <- d98_transform_global(beta, loading_free, gh61)
  geometry <- d98_geometry(chol_free, d98_fit_full(method))
  c(global, list(
    variational_mean = mean,
    variational_covariance = cbind(
      s11 = geometry$s11,
      s12 = geometry$s12,
      s22 = geometry$s22
    ),
    chol_free = chol_free
  ))
}

d98_accuracy_metrics <- function(transformed, truth = NULL) {
  eigenvalues <- d98_fit_num(transformed$covariance_eigenvalues)
  out <- list(
    second_covariance_eigenvalue = eigenvalues[2L]
  )
  truth <- d98_fit_truth(truth)
  if (is.null(truth)) return(out)
  truth_free <- d98_loading_to_free(truth$loading)
  truth_sigma <- truth$loading %*% t(truth$loading)
  truth_probability <- d98_marginal_probability(
    truth$beta, truth_free, d98_gh(61L)
  )
  beta <- d98_fit_num(transformed$beta)
  Sigma <- d98_fit_matrix(transformed$Sigma)
  probability <- d98_fit_num(transformed$marginal_probability)
  beta_rmse <- sqrt(mean((beta - truth$beta)^2))
  covariance_max_error <- max(abs(Sigma - truth_sigma))
  probability_rmse <- sqrt(mean((probability - truth_probability)^2))
  c(out, list(
    beta_rmse = beta_rmse,
    covariance_max_error = covariance_max_error,
    marginal_probability_rmse = probability_rmse,
    accuracy_flag = beta_rmse < 0.35 &&
      covariance_max_error < 0.50 &&
      probability_rmse < 0.08
  ))
}

d98_fit_phase <- function(obj, action, coordinates, input) {
  warnings <- character()
  toy <- isTRUE(input$toy_smoke)
  result <- withCallingHandlers(
    if (grepl("phase1$", action)) {
      stats::nlminb(
        start = coordinates,
        objective = obj$fn,
        gradient = obj$gr,
        control = list(
          iter.max = as.integer(
            input$nlminb_iter_max %||% if (toy) 300L else 1000L
          ),
          eval.max = as.integer(
            input$nlminb_eval_max %||% if (toy) 500L else 1400L
          )
        )
      )
    } else {
      stats::optim(
        par = coordinates,
        fn = obj$fn,
        gr = obj$gr,
        method = "BFGS",
        control = list(
          reltol = as.numeric(input$bfgs_reltol %||% 1e-12),
          maxit = as.integer(
            input$bfgs_maxit %||% if (toy) 700L else 1500L
          )
        )
      )
    },
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  if (grepl("phase1$", action)) {
    list(
      par = result$par,
      objective = result$objective,
      code = result$convergence,
      message = result$message %||% "",
      iterations = result$iterations,
      evaluations = result$evaluations,
      warnings = unique(warnings)
    )
  } else {
    list(
      par = result$par,
      objective = result$value,
      code = result$convergence,
      message = result$message %||% "",
      iterations = unname(result$counts[["function"]] %||% NA_integer_),
      evaluations = result$counts,
      warnings = unique(warnings)
    )
  }
}

d98_phase_payload <- function(
    action, input, dependency_payloads = list(), root = NULL) {
  y <- d98_fit_y(input, root)
  traits <- ncol(y)
  n <- nrow(y)
  truth <- input$truth
  gh31 <- d98_fit_gh(input, 31L)
  gh61 <- d98_fit_gh(input, 61L)
  declared_start <- input[["start"]]
  start_id <- if (is.null(declared_start$id)) {
    as.character(input[["start_id"]] %||% "fixed")
  } else {
    as.character(declared_start$id)
  }

  if (action %in% c("gh_phase1", "gh_phase2")) {
    if (identical(action, "gh_phase1")) {
      start <- d98_fit_start(input, y, truth)
      beta <- start$beta
      loading_free <- start$loading_free
      start_id <- start$start_id
      coordinates <- d98_pack_global(beta, loading_free)
    } else {
      dep <- d98_dependency_payload(dependency_payloads)
      coordinates <- d98_fit_num(dep$raw_coordinates)
      unpacked <- d98_unpack_global(coordinates, traits)
      beta <- unpacked$beta
      loading_free <- unpacked$loading_free
      start_id <- as.character(dep$start_id %||% start_id)
    }
    obj <- d98_build_gh_objective(y, beta, loading_free, gh31)
    fit <- d98_fit_phase(obj, action, coordinates, input)
    final <- d98_unpack_global(fit$par, traits)
    transformed <- d98_transform_global(
      final$beta, final$loading_free, gh61
    )
    estimator_kind <- "gh"
    method <- "GH"
    fixed_global <- FALSE
  } else if (action %in% c("va_phase1", "va_phase2")) {
    method <- d98_fit_method(input)
    full <- d98_fit_full(method)
    if (identical(action, "va_phase1")) {
      global <- d98_fit_start(input, y, truth)
      start_id <- global$start_id
      local <- d98_declared_local_start(n, full)
      coordinates <- d98_pack_variational(
        global$beta, global$loading_free,
        local$mean, local$chol_free
      )
      beta <- global$beta
      loading_free <- global$loading_free
      mean <- local$mean
      chol_free <- local$chol_free
    } else {
      dep <- d98_dependency_payload(dependency_payloads)
      coordinates <- d98_fit_num(dep$raw_coordinates)
      unpacked <- d98_unpack_variational(
        coordinates, n, traits, full
      )
      beta <- unpacked$beta
      loading_free <- unpacked$loading_free
      mean <- unpacked$mean
      chol_free <- unpacked$chol_free
      start_id <- as.character(dep$start_id %||% start_id)
    }
    obj <- d98_build_va_objective(
      y, beta, loading_free, mean, chol_free, method, gh31
    )
    fit <- d98_fit_phase(obj, action, coordinates, input)
    final <- d98_unpack_variational(fit$par, n, traits, full)
    transformed <- d98_transform_variational(
      final$beta, final$loading_free, final$mean,
      final$chol_free, method, gh61
    )
    estimator_kind <- "variational"
    fixed_global <- FALSE
  } else if (action %in% c(
      "fixed_local_phase1", "fixed_local_phase2")) {
    method <- d98_fit_method(input)
    full <- d98_fit_full(method)
    if (identical(action, "fixed_local_phase1")) {
      dep <- d98_dependency_payload(dependency_payloads)
      global <- d98_global_from_payload(dep, traits)
      local <- d98_declared_local_start(n, full)
      beta <- global$beta
      loading_free <- global$loading_free
      mean <- local$mean
      chol_free <- local$chol_free
      coordinates <- c(as.vector(mean), as.vector(chol_free))
    } else {
      dep <- d98_dependency_payload(dependency_payloads)
      global <- list(
        beta = d98_fit_num(dep$transformed_parameters$beta),
        loading_free = d98_fit_num(
          dep$transformed_parameters$loading_free
        )
      )
      beta <- global$beta
      loading_free <- global$loading_free
      mean_count <- 2L * n
      coordinates <- d98_fit_num(dep$raw_coordinates)
      mean <- matrix(coordinates[seq_len(mean_count)], n, 2L)
      chol_cols <- if (full) 3L else 2L
      chol_free <- matrix(
        coordinates[mean_count + seq_len(chol_cols * n)],
        n, chol_cols
      )
    }
    obj <- d98_build_va_objective(
      y, beta, loading_free, mean, chol_free,
      method, gh31, fixed_global = TRUE
    )
    fit <- d98_fit_phase(obj, action, coordinates, input)
    mean_count <- 2L * n
    final_mean <- matrix(fit$par[seq_len(mean_count)], n, 2L)
    chol_cols <- if (full) 3L else 2L
    final_chol <- matrix(
      fit$par[mean_count + seq_len(chol_cols * n)],
      n, chol_cols
    )
    transformed <- d98_transform_variational(
      beta, loading_free, final_mean, final_chol, method, gh61
    )
    estimator_kind <- "fixed_local"
    fixed_global <- TRUE
  } else {
    stop("Unknown fitting phase action")
  }

  gradient <- obj$gr(fit$par)
  gradient_max <- max(abs(gradient))
  metrics <- d98_accuracy_metrics(transformed, truth)
  phase2 <- grepl("phase2$", action)
  finite <- is.finite(fit$objective) &&
    all(is.finite(fit$par)) && all(is.finite(gradient))
  second_ok <- isTRUE(fixed_global) ||
    is.finite(metrics$second_covariance_eigenvalue) &&
      metrics$second_covariance_eigenvalue > 1e-6
  healthy <- fit$code == 0L && finite && second_ok &&
    (!phase2 || gradient_max < 1e-4)
  list(
    status = if (healthy) "healthy" else "unhealthy",
    healthy = healthy,
    reason = if (healthy) NULL else paste(
      c(
        if (fit$code != 0L) paste0("phase_code=", fit$code),
        if (!finite) "non_finite",
        if (!second_ok) "rank_deficient_covariance",
        if (phase2 && is.finite(gradient_max) &&
            gradient_max >= 1e-4) "gradient_gate"
      ),
      collapse = ";"
    ),
    action = action,
    estimator_kind = estimator_kind,
    method = method,
    start_id = start_id,
    raw_coordinates = as.numeric(fit$par),
    transformed_parameters = transformed,
    objective = as.numeric(fit$objective),
    objective_type = if (method == "GH") {
      "negative_GH31_marginal"
    } else if (startsWith(method, "Q")) {
      "negative_direct_Gaussian_ELBO31"
    } else {
      "negative_profiled_JJ_bound"
    },
    phase_code = as.integer(fit$code),
    gradient = as.numeric(gradient),
    gradient_max = gradient_max,
    metrics = metrics,
    optimizer = list(
      message = fit$message,
      iterations = fit$iterations,
      evaluations = fit$evaluations
    ),
    warnings = fit$warnings,
    error = NULL
  )
}

d98_dependency_entry <- function(x, fallback_id = NULL) {
  if (is.list(x) && "payload" %in% names(x)) {
    return(list(
      task_id = as.character(x$task_id %||% fallback_id),
      terminal_status = as.character(
        x$terminal_status %||% x$terminal$status %||% "unknown"
      ),
      terminal = x$terminal,
      payload_sha256 = x$payload_sha256,
      payload = x$payload
    ))
  }
  list(
    task_id = as.character(fallback_id %||% x$task_id %||% NA_character_),
    terminal_status = as.character(x$status %||% "unknown"),
    terminal = NULL,
    payload_sha256 = NULL,
    payload = x
  )
}

d98_evaluate_endpoint <- function(input, dep, y, truth) {
  if (is.null(dep) || !identical(dep$status, "healthy")) {
    stop("Endpoint dependency payload is not healthy")
  }
  transformed <- dep$transformed_parameters
  beta <- d98_fit_num(transformed$beta)
  loading_free <- d98_fit_num(transformed$loading_free)
  values <- vapply(c(31L, 41L, 61L), function(order) {
    d98_gh_log_marginal(
      y, beta, loading_free, d98_fit_gh(input, order)
    )
  }, numeric(1))
  epsilon <- max(abs(values[1L] - values[2L]),
                 abs(values[2L] - values[3L]))
  ladder_ok <- epsilon <= 1e-6 * max(1, abs(values[3L]))
  endpoint_ok <- ladder_ok
  gh_gradient_61 <- NA_real_
  gradient_ok <- TRUE
  if (identical(dep$estimator_kind, "gh")) {
    gh61 <- d98_fit_gh(input, 61L)
    gh_obj <- d98_build_gh_objective(y, beta, loading_free, gh61)
    gh_gradient_61 <- max(abs(gh_obj$gr(gh_obj$par)))
    gradient_ok <- is.finite(gh_gradient_61) && gh_gradient_61 < 1e-3
    endpoint_ok <- endpoint_ok && gradient_ok
  }
  common <- d98_accuracy_metrics(
    d98_transform_global(beta, loading_free, d98_fit_gh(input, 61L)),
    truth
  )
  metrics <- c(common, list(
    gh_log_marginal_31 = values[1L],
    gh_log_marginal_41 = values[2L],
    gh_log_marginal_61 = values[3L],
    epsilon_GH = epsilon,
    gh_gradient_max_61 = gh_gradient_61,
    node_ladder_pass = ladder_ok,
    optimized_objective = as.numeric(dep$objective),
    optimized_objective_type = dep$objective_type
  ))
  if (identical(dep$estimator_kind, "fixed_local")) {
    posterior <- d98_posterior_moments(
      y, beta, loading_free, d98_fit_gh(input, 61L)
    )
    covariance <- d98_fit_matrix(
      transformed$variational_covariance
    )
    difference <- vapply(seq_len(nrow(y)), function(i) {
      fitted <- matrix(c(
        covariance[i, 1L], covariance[i, 2L],
        covariance[i, 2L], covariance[i, 3L]
      ), 2L, 2L)
      sqrt(sum((fitted - posterior$covariance[i, , ])^2))
    }, numeric(1))
    metrics$posterior_covariance_frobenius <- difference
    metrics$posterior_covariance_max_frobenius <- max(difference)
  }
  list(
    status = if (endpoint_ok) "healthy" else "unhealthy",
    healthy = endpoint_ok,
    reason = if (endpoint_ok) {
      NULL
    } else if (!ladder_ok) {
      "GH_node_ladder"
    } else {
      "GH61_gradient_gate"
    },
    action = "evaluate",
    estimator_kind = dep$estimator_kind,
    method = dep$method,
    start_id = dep$start_id,
    raw_coordinates = d98_fit_num(dep$raw_coordinates),
    transformed_parameters = transformed,
    objective = -values[3L],
    objective_type = "negative_GH61_common_scale",
    phase_code = 0L,
    gradient = numeric(),
    gradient_max = NA_real_,
    metrics = metrics,
    optimizer = NULL,
    warnings = character(),
    error = NULL
  )
}

d98_failed_endpoint <- function(entry, reason = NULL) {
  payload <- entry$payload
  list(
    status = "unhealthy",
    healthy = FALSE,
    reason = reason %||% payload$reason %||% entry$terminal_status,
    action = "evaluate",
    estimator_kind = payload$estimator_kind %||% NA_character_,
    method = payload$method %||% NA_character_,
    start_id = payload$start_id %||% NA_character_,
    raw_coordinates = payload$raw_coordinates %||% numeric(),
    transformed_parameters = payload$transformed_parameters %||% list(),
    objective = payload$objective %||% NA_real_,
    objective_type = payload$objective_type %||% NA_character_,
    phase_code = payload$phase_code %||% NA_integer_,
    gradient = payload$gradient %||% numeric(),
    gradient_max = payload$gradient_max %||% NA_real_,
    metrics = payload$metrics %||% list(),
    optimizer = payload$optimizer,
    warnings = payload$warnings %||% character(),
    error = payload$error,
    source_task_id = entry$task_id,
    source_terminal_status = entry$terminal_status,
    source_payload_sha256 = entry$payload_sha256
  )
}

d98_evaluate_attempt <- function(input, entry, y, truth) {
  payload <- entry$payload
  if (is.null(payload) || !identical(payload$status, "healthy") ||
      !identical(entry$terminal_status, "healthy")) {
    return(d98_failed_endpoint(entry))
  }
  result <- tryCatch(
    d98_evaluate_endpoint(input, payload, y, truth),
    error = function(error) {
      d98_failed_endpoint(entry, paste0(
        "endpoint_error:", conditionMessage(error)
      ))
    }
  )
  result$source_task_id <- entry$task_id
  result$source_terminal_status <- entry$terminal_status
  result$source_payload_sha256 <- entry$payload_sha256
  result
}

d98_evaluation_shell <- function(
    status, reason, estimator_kind, method, attempts) {
  list(
    status = status,
    healthy = identical(status, "healthy"),
    reason = reason,
    action = "evaluate",
    estimator_kind = estimator_kind,
    method = method,
    start_id = NA_character_,
    raw_coordinates = numeric(),
    transformed_parameters = list(),
    objective = NA_real_,
    objective_type = NA_character_,
    phase_code = 0L,
    gradient = numeric(),
    gradient_max = NA_real_,
    metrics = list(),
    optimizer = NULL,
    warnings = character(),
    error = NULL,
    attempts = attempts
  )
}

d98_evaluate_representative <- function(input, entries, y, truth) {
  attempts <- lapply(entries, d98_evaluate_attempt,
                     input = input, y = y, truth = truth)
  method <- if (is.list(input$method)) {
    as.character(input$method$id %||% input$method$kind)
  } else {
    as.character(input$method)
  }
  estimator_kind <- if (identical(method, "GH")) "gh" else "variational"
  selection <- d98_select_representative(attempts, estimator_kind)
  selection_record <- selection
  selection_record$selected <- NULL
  if (!isTRUE(selection$comparable)) {
    out <- d98_evaluation_shell(
      "unhealthy",
      paste0("representative_selection:", selection$reason),
      estimator_kind,
      method,
      attempts
    )
    out$selection <- selection_record
    return(out)
  }
  selected <- selection$selected
  selected$attempts <- attempts
  selected$selection <- selection_record
  selected$method <- method
  selected
}

d98_fixed_coordinates <- function(payload, n, method) {
  coordinates <- d98_fit_num(payload$raw_coordinates)
  mean_count <- 2L * n
  chol_cols <- if (d98_fit_full(method)) 3L else 2L
  expected <- mean_count + chol_cols * n
  if (length(coordinates) != expected) {
    stop("Fixed-local coordinates have the wrong dimension")
  }
  list(
    mean = matrix(coordinates[seq_len(mean_count)], n, 2L),
    chol_free = matrix(
      coordinates[mean_count + seq_len(chol_cols * n)],
      n, chol_cols
    )
  )
}

d98_fixed_factorial_contrasts <- function(attempts, y, input) {
  required <- c("QD", "QF", "JD", "JF")
  methods <- vapply(
    attempts,
    function(x) as.character(x$method %||% NA_character_),
    character(1)
  )
  if (anyDuplicated(methods[methods %in% required])) {
    stop("Fixed-local evaluation received duplicate methods")
  }
  named <- setNames(attempts, methods)
  healthy <- setNames(vapply(required, function(method) {
    method %in% names(named) &&
      identical(named[[method]]$status, "healthy")
  }, logical(1)), required)
  objective <- setNames(rep(NA_real_, length(required)), required)
  for (method in required[healthy]) {
    objective[[method]] <- as.numeric(
      named[[method]]$metrics$optimized_objective
    )
  }
  q_at_j <- setNames(rep(NA_real_, 2L), c("D", "F"))
  for (geometry in names(q_at_j)) {
    jj_method <- paste0("J", geometry)
    direct_method <- paste0("Q", geometry)
    if (!healthy[[jj_method]]) next
    payload <- named[[jj_method]]
    local <- d98_fixed_coordinates(payload, nrow(y), jj_method)
    q_at_j[[geometry]] <- d98_variational_elbo(
      y = y,
      beta = d98_fit_num(payload$transformed_parameters$beta),
      loading_free = d98_fit_num(
        payload$transformed_parameters$loading_free
      ),
      mean = local$mean,
      chol_free = local$chol_free,
      method = direct_method,
      gh = d98_fit_gh(input, 31L)
    )
  }
  available <- list(
    G_Q = healthy[["QD"]] && healthy[["QF"]],
    G_J = healthy[["JD"]] && healthy[["JF"]],
    B_D = healthy[["JD"]] && is.finite(q_at_j[["D"]]),
    B_F = healthy[["JF"]] && is.finite(q_at_j[["F"]]),
    D_D = healthy[["QD"]] && healthy[["JD"]] &&
      is.finite(q_at_j[["D"]]),
    D_F = healthy[["QF"]] && healthy[["JF"]] &&
      is.finite(q_at_j[["F"]])
  )
  list(
    available = available,
    method_health = as.list(healthy),
    missing_methods = names(healthy)[!healthy],
    G_Q = if (available$G_Q) {
      unname(objective[["QD"]] - objective[["QF"]])
    } else NA_real_,
    G_J = if (available$G_J) {
      unname(objective[["JD"]] - objective[["JF"]])
    } else NA_real_,
    B_D = if (available$B_D) {
      unname(q_at_j[["D"]] + objective[["JD"]])
    } else NA_real_,
    B_F = if (available$B_F) {
      unname(q_at_j[["F"]] + objective[["JF"]])
    } else NA_real_,
    D_D = if (available$D_D) {
      unname(-objective[["QD"]] - q_at_j[["D"]])
    } else NA_real_,
    D_F = if (available$D_F) {
      unname(-objective[["QF"]] - q_at_j[["F"]])
    } else NA_real_,
    Q_at_phi_J_D = unname(q_at_j[["D"]]),
    Q_at_phi_J_F = unname(q_at_j[["F"]]),
    optimized_objectives = as.list(objective)
  )
}

d98_evaluate_fixed_local <- function(input, entries, y, truth) {
  attempts <- lapply(entries, d98_evaluate_attempt,
                     input = input, y = y, truth = truth)
  contrasts <- tryCatch(
    d98_fixed_factorial_contrasts(attempts, y, input),
    error = function(error) list(
      available = list(),
      reason = paste0("factorial_error:", conditionMessage(error))
    )
  )
  healthy_index <- which(vapply(
    attempts, function(x) identical(x$status, "healthy"), logical(1)
  ))
  if (!length(healthy_index)) {
    out <- d98_evaluation_shell(
      "unhealthy",
      contrasts$reason %||% "no_healthy_fixed_local_method",
      "fixed_local",
      "factorial",
      attempts
    )
    out$contrasts <- contrasts
    return(out)
  }
  methods <- vapply(attempts, function(x) x$method, character(1))
  preferred <- match(c("QF", "QD", "JF", "JD"), methods)
  preferred <- preferred[!is.na(preferred)]
  representative_index <- preferred[
    vapply(preferred, function(i) {
      identical(attempts[[i]]$status, "healthy")
    }, logical(1))
  ][1L]
  representative <- attempts[[representative_index]]
  representative$estimator_kind <- "fixed_local_factorial"
  representative$method <- "factorial"
  representative$attempts <- attempts
  representative$contrasts <- contrasts
  representative
}

d98_summary_material <- function(a, b, delta) {
  if (is.null(a) || is.null(b) ||
      !identical(a$status, "healthy") ||
      !identical(b$status, "healthy")) {
    return(FALSE)
  }
  epsilon_a <- as.numeric(a$metrics$epsilon_GH)
  epsilon_b <- as.numeric(b$metrics$epsilon_GH)
  is.finite(delta) && is.finite(epsilon_a) && is.finite(epsilon_b) &&
    delta > 10 * (epsilon_a + epsilon_b)
}

d98_evaluate_summary <- function(input, entries) {
  payloads <- lapply(entries, `[[`, "payload")
  names(payloads) <- vapply(entries, `[[`, character(1), "task_id")
  terminal_status <- setNames(
    vapply(entries, `[[`, character(1), "terminal_status"),
    names(payloads)
  )
  required <- c(
    "evaluate_gh_low", "evaluate_gh_high", "evaluate_fixed_local",
    "evaluate_qd", "evaluate_qf", "evaluate_jd", "evaluate_jf"
  )
  available <- required %in% names(payloads) &
    vapply(required, function(id) {
      id %in% names(payloads) &&
        identical(terminal_status[[id]], "healthy") &&
        !is.null(payloads[[id]]) &&
        identical(payloads[[id]]$status, "healthy")
    }, logical(1))
  names(available) <- required
  get <- function(id) if (isTRUE(available[[id]])) payloads[[id]] else NULL
  low <- get("evaluate_gh_low")
  high <- get("evaluate_gh_high")
  fixed <- get("evaluate_fixed_local")
  qd <- get("evaluate_qd")
  qf <- get("evaluate_qf")
  jd <- get("evaluate_jd")
  jf <- get("evaluate_jf")
  contrasts <- fixed$contrasts %||% NULL
  ell <- function(x) {
    if (is.null(x)) return(NA_real_)
    as.numeric(x$metrics$gh_log_marginal_61)
  }
  deltas <- list(
    Q_geometry = ell(qf) - ell(qd),
    J_geometry = ell(jf) - ell(jd),
    JJ = ell(qf) - ell(jf),
    Gaussian_or_global = ell(low) - ell(qf)
  )
  accuracy <- function(x) {
    if (is.null(x)) return(NA)
    isTRUE(x$metrics$accuracy_flag)
  }
  flags <- c(
    NESTED_FIXTURE_INFORMATION_SIGNAL = NA,
    MEAN_FIELD_SIGNAL = NA,
    JJ_SIGNAL = NA,
    GAUSSIAN_OR_GLOBAL_SIGNAL = NA
  )
  if (!is.null(low) && !is.null(high)) {
    flags[["NESTED_FIXTURE_INFORMATION_SIGNAL"]] <-
      !accuracy(low) && accuracy(high)
  }
  if (!is.null(qd) && !is.null(qf) && !is.null(fixed) &&
      isTRUE(contrasts$available$G_Q)) {
    fixed_methods <- setNames(
      fixed$attempts,
      vapply(fixed$attempts, function(x) x$method, character(1))
    )
    covariance_gain <- as.numeric(
      fixed_methods$QD$metrics$posterior_covariance_max_frobenius %||% Inf
    ) - as.numeric(
      fixed_methods$QF$metrics$posterior_covariance_max_frobenius %||% Inf
    )
    flags[["MEAN_FIELD_SIGNAL"]] <-
      d98_summary_material(qf, qd, deltas$Q_geometry) &&
      isTRUE(contrasts$G_Q > 1e-4) &&
      is.finite(covariance_gain) && covariance_gain > 1e-3 &&
      !accuracy(qd) && accuracy(qf)
  }
  if (!is.null(qf) && !is.null(jf) && !is.null(fixed) &&
      isTRUE(contrasts$available$D_F) &&
      isTRUE(contrasts$available$B_F)) {
    flags[["JJ_SIGNAL"]] <-
      d98_summary_material(qf, jf, deltas$JJ) &&
      isTRUE(contrasts$D_F > 1e-4) &&
      isTRUE(contrasts$B_F > 1e-4) &&
      !accuracy(jf) && accuracy(qf)
  }
  if (!is.null(low) && !is.null(qf)) {
    flags[["GAUSSIAN_OR_GLOBAL_SIGNAL"]] <-
      d98_summary_material(low, qf, deltas$Gaussian_or_global) &&
      !accuracy(qf) && accuracy(low)
  }
  missing <- names(available)[!available]
  if (isTRUE(available[["evaluate_fixed_local"]])) {
    needed_contrasts <- c("G_Q", "B_F", "D_F")
    missing_contrasts <- needed_contrasts[
      !vapply(needed_contrasts, function(name) {
        isTRUE(payloads$evaluate_fixed_local$contrasts$available[[name]])
      }, logical(1))
    ]
    missing <- c(missing, paste0("fixed_contrast:", missing_contrasts))
  }
  count <- sum(flags %in% TRUE)
  decision_status <- if (length(missing)) {
    "TECHNICAL_INCOMPLETE"
  } else if (count >= 2L) {
    "MIXED_SIGNAL"
  } else if (count == 1L) {
    names(flags)[which(flags %in% TRUE)][[1L]]
  } else {
    "NO_DIAGNOSTIC"
  }
  out <- d98_evaluation_shell(
    "healthy", NULL, "summary", "dependency_valid_labels", list()
  )
  out$decision_status <- decision_status
  out$mechanism_flags <- as.list(flags)
  out$missing_dependencies <- missing
  out$dependency_availability <- as.list(available)
  out$dependency_records <- entries
  out$contrasts <- contrasts
  out$common_scale_deltas <- deltas
  out$metrics <- list(
    comparable_method_count = sum(available),
    mechanism_flag_count = count,
    mechanism_flag_available_count = sum(!is.na(flags))
  )
  out
}

d98_evaluate_payload <- function(
    input, dependency_payloads = list(), root = NULL) {
  entries <- Map(
    d98_dependency_entry,
    dependency_payloads,
    as.list(input$dependencies %||% rep(NA_character_,
                                        length(dependency_payloads)))
  )
  method <- input$method
  kind <- if (is.list(method)) {
    as.character(method$kind %||% method$id)
  } else {
    as.character(method)
  }
  decision <- if (is.list(method)) {
    as.character(method$decision %||% "")
  } else {
    ""
  }
  if (identical(kind, "summary")) {
    return(d98_evaluate_summary(input, entries))
  }
  y <- d98_fit_y(input, root)
  truth <- input$truth
  if (identical(kind, "fixed_local") ||
      identical(decision, "factorial_contrasts")) {
    return(d98_evaluate_fixed_local(input, entries, y, truth))
  }
  if (identical(decision, "select_representative")) {
    return(d98_evaluate_representative(input, entries, y, truth))
  }
  if (length(entries) != 1L) {
    stop("Single-endpoint evaluation requires exactly one dependency")
  }
  d98_evaluate_attempt(input, entries[[1L]], y, truth)
}

d98_run_fit_action <- function(
    input, dependency_payloads = list(),
    design_dir = d98_fit_design_dir(), root = NULL) {
  options(d98_design_dir = design_dir)
  action <- as.character(input$action)
  allowed <- c(
    "gh_phase1", "gh_phase2", "va_phase1", "va_phase2",
    "fixed_local_phase1", "fixed_local_phase2", "evaluate"
  )
  if (length(action) != 1L || !action %in% allowed) {
    stop("Unsupported fit-worker action")
  }
  if (identical(action, "evaluate")) {
    d98_evaluate_payload(input, dependency_payloads, root)
  } else {
    d98_phase_payload(action, input, dependency_payloads, root)
  }
}

d98_payload_matrix <- function(payload, name) {
  d98_fit_matrix(payload$transformed_parameters[[name]])
}

d98_select_representative <- function(payloads, estimator_kind) {
  if (!length(payloads)) {
    return(list(comparable = FALSE, reason = "no_attempts"))
  }
  healthy <- payloads[vapply(
    payloads,
    function(x) identical(x$status, "healthy"),
    logical(1)
  )]
  if (length(healthy) < 2L) {
    return(list(
      comparable = FALSE,
      reason = "fewer_than_two_healthy",
      attempt_count = length(payloads),
      healthy_count = length(healthy)
    ))
  }
  ids <- vapply(healthy, function(x) as.character(x$start_id), character(1))
  disagreement <- list(covariance = 0, beta = 0, probability = 0)
  pairs <- utils::combn(seq_along(healthy), 2L)
  for (column in seq_len(ncol(pairs))) {
    a <- healthy[[pairs[1L, column]]]
    b <- healthy[[pairs[2L, column]]]
    disagreement$covariance <- max(
      disagreement$covariance,
      max(abs(d98_payload_matrix(a, "Sigma") -
              d98_payload_matrix(b, "Sigma")))
    )
    disagreement$beta <- max(
      disagreement$beta,
      max(abs(d98_fit_num(a$transformed_parameters$beta) -
              d98_fit_num(b$transformed_parameters$beta)))
    )
    disagreement$probability <- max(
      disagreement$probability,
      max(abs(
        d98_fit_num(a$transformed_parameters$marginal_probability) -
          d98_fit_num(b$transformed_parameters$marginal_probability)
      ))
    )
  }
  agrees <- disagreement$covariance < 0.25 &&
    disagreement$beta < 0.25 &&
    disagreement$probability < 0.05
  if (!agrees) {
    return(list(
      comparable = FALSE,
      reason = "healthy_starts_disagree",
      attempt_count = length(payloads),
      healthy_count = length(healthy),
      disagreement = disagreement
    ))
  }
  objective <- if (identical(estimator_kind, "gh")) {
    vapply(healthy, function(x) {
      marginal <- x$metrics$gh_log_marginal_61
      if (is.null(marginal) || !is.finite(as.numeric(marginal))) {
        stop("GH representative selection requires evaluated ell_61 endpoints")
      }
      -as.numeric(marginal)
    }, numeric(1))
  } else {
    vapply(healthy, function(x) {
      optimized <- x$metrics$optimized_objective
      if (is.null(optimized) || !is.finite(as.numeric(optimized))) {
        stop("Variational selection requires its optimized objective")
      }
      as.numeric(optimized)
    }, numeric(1))
  }
  ordering <- order(objective, match(ids, c("A", "B", "C")))
  selected <- healthy[[ordering[1L]]]
  list(
    comparable = TRUE,
    reason = NULL,
    attempt_count = length(payloads),
    healthy_count = length(healthy),
    disagreement = disagreement,
    selected_start_id = selected$start_id,
    selected = selected,
    healthy_start_order = ids[ordering],
    estimator_kind = estimator_kind
  )
}

d98_start_concurrent_heartbeat <- function(
    root, task_id, interval_sec = 5) {
  if (.Platform$OS.type == "windows") {
    stop("Design 98 concurrent heartbeat requires a Unix-alike platform")
  }
  interval_sec <- as.numeric(interval_sec)
  if (!is.finite(interval_sec) || interval_sec <= 0) {
    stop("heartbeat interval must be positive")
  }
  parent_pid <- Sys.getpid()
  parallel::mcparallel({
    repeat {
      parent_alive <- tryCatch(
        isTRUE(tools::pskill(parent_pid, signal = 0L)),
        error = function(e) FALSE
      )
      if (!parent_alive) break
      d98_write_heartbeat(root, task_id, "running")
      Sys.sleep(interval_sec)
    }
  }, silent = TRUE)
}

d98_stop_concurrent_heartbeat <- function(job) {
  if (!is.null(job)) {
    try(parallel::mckill(job), silent = TRUE)
    try(parallel::mccollect(job, wait = FALSE), silent = TRUE)
  }
  invisible(TRUE)
}
