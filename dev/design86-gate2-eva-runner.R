## Design 86 Gate 2: private EVA recovery arm.  This is a research runner, not
## package API.  It reads the frozen fixture and never changes its DGP or rules.

.d86_root <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (file.exists(file.path(root, "R", "eva-proto.R"))) return(root)
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Run from the Design 86 worktree or source this runner there.", call. = FALSE)
}

source(file.path(.d86_root(), "R", "eva-proto.R"))

.d86_gate2_fixture_sha256 <- "fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6"
.d86_gate2_seed_array_sha256 <- "9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a"

.eva_gate2_file <- function(path = NULL) {
  if (!is.null(path)) return(normalizePath(path, mustWork = TRUE))
  root <- .d86_root()
  candidate <- file.path(root, "docs", "design", "86-eva-gate2-anchor-parameters.json")
  if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
  stop("Cannot find docs/design/86-eva-gate2-anchor-parameters.json.", call. = FALSE)
}

.eva_read_gate2_parameters <- function(path = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The Design 86 prototype requires jsonlite to read its frozen fixture.", call. = FALSE)
  }
  fixture_path <- .eva_gate2_file(path)
  if (!identical(.d86_sha256_file(fixture_path), .d86_gate2_fixture_sha256)) {
    stop("The Design 86 Gate-2 fixture checksum does not match the approved freeze.", call. = FALSE)
  }
  x <- jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
  if (!identical(x$status, "FROZEN_GATE2_ANCHOR_ONLY") ||
      !identical(x$schema_version, "1.0.0") ||
      !identical(x$gate, "G2") || !isTRUE(x$research_only)) {
    stop("The Design 86 Gate-2 fixture is not the approved frozen schema.", call. = FALSE)
  }
  .d86_validate_gate2_seed_receipt(x)
  x
}

.d86_seed_array_sha256 <- function(seeds) {
  path <- tempfile("design86-seed-receipt-")
  on.exit(unlink(path), add = TRUE)
  writeLines(jsonlite::toJSON(as.integer(unlist(seeds, use.names = FALSE)), auto_unbox = TRUE), path)
  unname(tools::sha256sum(path))
}

.d86_validate_gate2_seed_receipt <- function(parameters) {
  seeds <- parameters$replicates$expanded_data_generation_seeds
  if (!identical(.d86_seed_array_sha256(seeds), .d86_gate2_seed_array_sha256)) {
    stop("The Design 86 Gate-2 seed receipt does not match the approved freeze.", call. = FALSE)
  }
  invisible(parameters)
}

.eva_sha256_object <- function(x) {
  path <- tempfile("design86-sha256-")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 2)
  unname(tools::sha256sum(path))
}

.eva_gate2_truth <- function(path = NULL) {
  p <- .eva_read_gate2_parameters(path)
  d <- p$anchor_dgp
  N <- as.integer(d$N); T <- as.integer(d$T); q <- as.integer(d$q)
  Lambda <- do.call(rbind, lapply(d$lambda_truth, as.numeric))
  theta_rr <- as.numeric(unlist(d$theta_rr_truth, use.names = FALSE))
  beta <- as.numeric(unlist(d$beta_truth, use.names = FALSE))
  if (N < 1L || T < 1L || q < 1L || q > T || nrow(Lambda) != T || ncol(Lambda) != q ||
      length(theta_rr) != .eva_theta_length(T, q) || length(beta) != 1L ||
      max(abs(.eva_unpack_theta(theta_rr, T, q) - Lambda)) > 1e-14 ||
      max(abs(crossprod(Lambda) - diag(6, q))) > 1e-12) {
    stop("The frozen Gate-2 truth does not meet its packed-loading contract.", call. = FALSE)
  }
  list(N = N, T = T, q = q, beta = beta, Lambda = Lambda, theta_rr = theta_rr,
       Sigma_B = tcrossprod(Lambda), parameter_file = .eva_gate2_file(path))
}

.eva_gate2_input <- function(seed, path = NULL) {
  p <- .eva_read_gate2_parameters(path)
  truth <- .eva_gate2_truth(path)
  seed <- as.integer(seed)
  if (length(seed) != 1L || is.na(seed) || !(seed %in% as.integer(unlist(
      p$replicates$expanded_data_generation_seeds, use.names = FALSE)))) {
    stop("seed is not in the approved Gate-2 seed array.", call. = FALSE)
  }
  do.call(RNGkind, as.list(unlist(p$anchor_dgp$rngkind, use.names = FALSE)))
  set.seed(seed)
  U <- matrix(stats::rnorm(truth$N * truth$q), truth$N, truth$q, byrow = TRUE)
  unit_id <- rep(0:(truth$N - 1L), each = truth$T)
  trait_id <- rep(0:(truth$T - 1L), times = truth$N)
  X <- matrix(1, nrow = truth$N * truth$T, ncol = 1L,
              dimnames = list(NULL, p$anchor_dgp$X$column_names[[1L]]))
  eta <- drop(X %*% truth$beta) + rowSums(truth$Lambda[trait_id + 1L, , drop = FALSE] *
    U[unit_id + 1L, , drop = FALSE])
  y <- stats::rbinom(length(eta), size = 1L, prob = stats::plogis(eta))
  I_unit <- vapply(seq_len(truth$N), function(i) {
    rows <- which(unit_id == i - 1L)
    weights <- stats::plogis(eta[rows]) * (1 - stats::plogis(eta[rows]))
    min(eigen(crossprod(truth$Lambda[trait_id[rows] + 1L, , drop = FALSE] * sqrt(weights)),
              symmetric = TRUE, only.values = TRUE)$values)
  }, numeric(1))
  long_data <- data.frame(
    value = as.integer(y),
    unit = factor(unit_id, levels = 0:(truth$N - 1L)),
    trait = factor(trait_id, levels = 0:(truth$T - 1L)),
    stringsAsFactors = FALSE
  )
  ordered_cell_map <- data.frame(unit_id = unit_id, trait_id = trait_id)
  truth_receipt <- list(beta = truth$beta, theta_rr = truth$theta_rr, Lambda = truth$Lambda,
                        Sigma_B = truth$Sigma_B, q = truth$q)
  x <- list(y = as.numeric(y), X = X, unit_id = as.integer(unit_id), trait_id = as.integer(trait_id),
            N = truth$N, T = truth$T, q = truth$q, beta = truth$beta,
            theta_rr = truth$theta_rr, a = matrix(0, truth$N, truth$q),
            log_A_diag = matrix(0, truth$N, truth$q),
            A_off = matrix(0, truth$N, truth$q * (truth$q - 1L) / 2L), gaussian_sd = 1)
  .eva_validate_fixture(x, 1L)
  hashes <- list(ordered_cell_map_sha256 = .eva_sha256_object(ordered_cell_map),
                 truth_sha256 = .eva_sha256_object(truth_receipt),
                 response_sha256 = .eva_sha256_object(y),
                 replicate_input_sha256 = .eva_sha256_object(list(ordered_cell_map, truth_receipt, y)))
  list(seed = seed, x = x, long_data = long_data, U = U, eta = eta, I_unit = I_unit,
       truth = truth_receipt, ordered_cell_map = ordered_cell_map, hashes = hashes)
}

.d86_sha256_file <- function(path) unname(tools::sha256sum(normalizePath(path, mustWork = TRUE)))

.d86_loaded_dll_path <- function(DLL) {
  loaded <- getLoadedDLLs()[[DLL]]
  if (is.null(loaded)) return(NA_character_)
  normalizePath(loaded[["path"]], mustWork = TRUE)
}

.d86_git <- function(root, args) {
  out <- system2("git", c("-C", root, args), stdout = TRUE, stderr = FALSE)
  if (!length(out)) NA_character_ else out[[1L]]
}

.d86_source_receipt <- function(root, runner_path, dll_path = NA_character_) {
  source_path <- file.path(root, "inst", "tmb", "gllvmTMB_eva.cpp")
  driver_path <- file.path(root, "R", "eva-proto.R")
  list(
    source_commit = .d86_git(root, c("rev-parse", "HEAD")),
    source_tree_clean = !length(system2("git", c("-C", root, "status", "--porcelain"), stdout = TRUE, stderr = FALSE)),
    engine_source_sha256 = .d86_sha256_file(source_path),
    driver_source_sha256 = .d86_sha256_file(driver_path),
    runner_source_sha256 = .d86_sha256_file(runner_path),
    dll_sha256 = if (is.na(dll_path)) NA_character_ else .d86_sha256_file(dll_path),
    runtime = list(
      R = R.version$version.string,
      platform = R.version$platform,
      TMB = if (requireNamespace("TMB", quietly = TRUE)) as.character(utils::packageVersion("TMB")) else NA_character_,
      compiler = tryCatch(system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"), stdout = TRUE, stderr = FALSE)[1L],
                            error = function(e) NA_character_)
    )
  )
}

.d86_write_json_once <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  text <- jsonlite::toJSON(x, auto_unbox = TRUE, digits = 16, pretty = TRUE, null = "null", na = "null")
  if (file.exists(path)) {
    old <- paste(readLines(path, warn = FALSE), collapse = "\n")
    if (!identical(sub("[\r\n]+$", "", old), sub("[\r\n]+$", "", as.character(text)))) {
      stop("Refusing to overwrite a non-identical Gate-2 immutable receipt.", call. = FALSE)
    }
  } else {
    writeLines(text, path, useBytes = TRUE)
  }
  invisible(path)
}

.d86_input_manifest <- function(input, root, output_root) {
  p <- .eva_read_gate2_parameters()
  manifest <- list(
    gate = "G2", research_only = TRUE, denominator_id = p$denominator$id,
    seed = input$seed, row_order = p$anchor_dgp$row_order,
    N = input$x$N, T = input$x$T, q = input$x$q,
    hashes = input$hashes
  )
  path <- file.path(output_root, "inputs", "manifest.json")
  .d86_write_json_once(manifest, path)
  list(path = path, sha256 = .d86_sha256_file(path), manifest = manifest)
}

.d86_eva_start <- function(obj, input, start_id) {
  p <- .eva_read_gate2_parameters()$starts$EVA
  stopifnot(start_id %in% seq_len(as.integer(p$n_starts)))
  out <- obj$par
  beta_start <- tryCatch(stats::lm.fit(input$x$X, qlogis((input$x$y + 0.5) / 2))$coefficients,
                         error = function(e) NA_real_)
  out[names(out) == "beta"] <- if (all(is.finite(beta_start))) beta_start else 0
  theta <- numeric(.eva_theta_length(input$x$T, input$x$q))
  if (start_id == 1L) {
    theta[seq_len(input$x$q)] <- 0.10 * c(1, -1)
  } else {
    scale <- c(-0.10, 0.20, -0.20)[start_id - 1L]
    theta[seq_len(input$x$q)] <- scale * c(1, -1)
    lower <- seq.int(input$x$q + 1L, length(theta))
    theta[lower] <- 0.01 * start_id * sin(seq_along(lower))
  }
  out[names(out) == "theta_rr"] <- theta
  if (start_id > 1L) {
    out[names(out) == "a"] <- c(0.01, 0.02, 0.015)[start_id - 1L] *
      sin(seq_along(out[names(out) == "a"]) + start_id)
    out[names(out) == "log_A_diag"] <- c(-0.025, 0.025, -0.04)[start_id - 1L]
    out[names(out) == "A_off"] <- c(0.005, 0.01, 0.0075)[start_id - 1L] *
      cos(seq_along(out[names(out) == "A_off"]) + start_id)
  }
  out
}

.d86_eva_fit_start <- function(obj, start, control) {
  run <- function(par) stats::nlminb(par, obj$fn, obj$gr,
    control = list(eval.max = as.integer(control$nlminb_eval_max),
                   iter.max = as.integer(control$nlminb_iter_max)))
  first <- tryCatch(run(start), error = identity)
  second <- if (inherits(first, "error") || any(!is.finite(first$par))) first else tryCatch(run(first$par), error = identity)
  third <- if (inherits(second, "error") || any(!is.finite(second$par))) second else tryCatch(run(second$par), error = identity)
  fourth <- if (inherits(third, "error") || any(!is.finite(third$par))) third else tryCatch(
    stats::optim(third$par, obj$fn, obj$gr, method = "BFGS",
                 control = list(maxit = as.integer(control$bfgs_maxit), reltol = control$bfgs_reltol)), error = identity)
  if (inherits(fourth, "error")) return(list(code = NA_integer_, par = rep(NA_real_, length(start)),
    objective = NA_real_, gradient = rep(NA_real_, length(start)), error = conditionMessage(fourth)))
  code <- as.integer(fourth$convergence)
  par <- fourth$par
  gr <- tryCatch(obj$gr(par), error = function(e) rep(NA_real_, length(par)))
  list(code = code, par = par, objective = tryCatch(obj$fn(par), error = function(e) NA_real_),
       gradient = gr, error = NA_character_)
}

.d86_eva_interval <- function(obj, par, primary_index = 1L) {
  p <- .eva_read_gate2_parameters()$interval
  H <- tryCatch(obj$he(par), error = function(e) NULL)
  model <- names(par) %in% c("beta", "theta_rr")
  variational <- !model
  fail <- function(reason) list(ok = FALSE, reason = reason, lower = NA_real_, upper = NA_real_, variance = NA_real_)
  if (is.null(H) || any(!is.finite(H))) return(fail("nonfinite_H"))
  H <- (H + t(H)) / 2
  A <- H[model, model, drop = FALSE]; B <- H[model, variational, drop = FALSE]; D <- H[variational, variational, drop = FALSE]
  ch <- tryCatch(chol(D), error = function(e) NULL)
  if (is.null(ch)) return(fail("failed_SPD_D_solve"))
  I <- A - B %*% chol2inv(ch) %*% t(B); I <- (I + t(I)) / 2
  if (min(eigen(I, symmetric = TRUE, only.values = TRUE)$values) < -sqrt(.Machine$double.eps)) return(fail("material_negative_curvature"))
  V <- MASS::ginv(I, tol = p$ginv_tolerance)
  variance <- V[primary_index, primary_index]
  if (!is.finite(variance) || variance <= 0) return(fail("nonpositive_beta_variance"))
  estimate <- par[which(names(par) == "beta")[primary_index]]
  z <- stats::qnorm((1 + p$level) / 2)
  list(ok = TRUE, reason = NA_character_, variance = variance,
       lower = estimate - z * sqrt(variance), upper = estimate + z * sqrt(variance))
}

design86_gate2_eva_run <- function(seed, output_root = NULL, rebuild = FALSE) {
  root <- .d86_root(); runner <- file.path(root, "dev", "design86-gate2-eva-runner.R")
  p <- .eva_read_gate2_parameters(); input <- .eva_gate2_input(seed)
  if (is.null(output_root)) output_root <- file.path(root, p$provenance$output_root)
  manifest <- .d86_input_manifest(input, root, output_root)
  dll <- .eva_load_dll(rebuild = rebuild)
  obj <- TMB::MakeADFun(data = c(input$x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")], family = 1L),
                         parameters = input$x[c("beta", "theta_rr", "a", "log_A_diag", "A_off")],
                         random = NULL, DLL = dll$DLL, silent = TRUE)
  starts <- lapply(seq_len(as.integer(p$starts$EVA$n_starts)), function(id) {
    fit <- .d86_eva_fit_start(obj, .d86_eva_start(obj, input, id), p$starts$EVA)
    healthy <- identical(fit$code, 0L) && is.finite(fit$objective) && all(is.finite(fit$par)) &&
      all(is.finite(fit$gradient)) && max(abs(fit$gradient)) < 1e-4
    list(start_id = id, code = fit$code, negative_EVA = fit$objective,
         max_abs_gradient = if (all(is.finite(fit$gradient))) max(abs(fit$gradient)) else NA_real_,
         healthy = healthy, fit = fit)
  })
  healthy <- which(vapply(starts, `[[`, logical(1), "healthy"))
  candidate_winner <- if (length(healthy)) healthy[which.min(vapply(starts[healthy], `[[`, numeric(1), "negative_EVA"))] else NA_integer_
  best_three_range <- if (length(healthy) >= 3L) diff(range(sort(vapply(starts[healthy], `[[`, numeric(1), "negative_EVA"))[1:3])) else NA_real_
  accepted_starts <- length(healthy) >= 3L && is.finite(best_three_range) && best_three_range <= 1e-6
  interval <- if (is.na(candidate_winner) || !accepted_starts) list(ok = FALSE, reason = "no_accepted_winner",
    lower = NA_real_, upper = NA_real_, variance = NA_real_) else .d86_eva_interval(obj, starts[[candidate_winner]]$fit$par)
  winner <- if (isTRUE(interval$ok)) candidate_winner else NA_integer_
  Lambda <- if (is.na(winner)) matrix(NA_real_, input$x$T, input$x$q) else .eva_unpack_theta(
    starts[[winner]]$fit$par[names(obj$par) == "theta_rr"], input$x$T, input$x$q)
  Sigma_B <- tcrossprod(Lambda)
  collapse <- is.na(winner) || any(!is.finite(Sigma_B)) ||
    sort(eigen(Sigma_B, symmetric = TRUE, only.values = TRUE)$values, decreasing = TRUE)[2L] < p$collapse$absolute_threshold
  result <- list(gate = "G2", arm = "EVA", seed = as.integer(seed), denominator_id = p$denominator$id,
    input_manifest_sha256 = manifest$sha256, hashes = input$hashes,
    I_unit = as.list(unclass(summary(input$I_unit))),
    I_unit_q10_type8 = unname(stats::quantile(input$I_unit, 0.10, type = 8)), starts = lapply(starts, function(z)
      z[c("start_id", "code", "negative_EVA", "max_abs_gradient", "healthy")]),
    accepted_starts = accepted_starts, selected_start = winner, interval = interval,
    beta_hat = if (is.na(winner)) NA_real_ else starts[[winner]]$fit$par[names(obj$par) == "beta"][1L],
    Sigma_B_hat = Sigma_B, collapsed = collapse)
  receipt <- c(list(parameter_file_sha256 = .d86_sha256_file(.eva_gate2_file()),
    inputs_manifest_sha256 = manifest$sha256, output_root_repo_relative = sub(paste0("^", root, "/?"), "", normalizePath(output_root, mustWork = FALSE)),
    denominator_id = p$denominator$id), .d86_source_receipt(root, runner, .d86_loaded_dll_path(dll$DLL)))
  arm_dir <- file.path(output_root, "eva")
  result_path <- file.path(arm_dir, sprintf("seed-%s-result.json", seed)); .d86_write_json_once(result, result_path)
  receipt$output_manifest_sha256 <- .d86_sha256_file(result_path)
  .d86_write_json_once(receipt, file.path(arm_dir, sprintf("seed-%s-receipt.json", seed)))
  invisible(list(result = result, receipt = receipt, input_manifest = manifest, paths = list(result = result_path)))
}
