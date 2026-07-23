## Design 86 Gate-1 EVA prototype.  This is deliberately unexported and
## separate from the shipped Laplace template and fitting API.

.eva_gate1_file <- function(path = NULL) {
  if (!is.null(path)) return(normalizePath(path, mustWork = TRUE))
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    candidate <- file.path(root, "docs", "design", "86-eva-gate1-parameters.json")
    if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Cannot find docs/design/86-eva-gate1-parameters.json.", call. = FALSE)
}

.eva_gate2_file <- function(path = NULL) {
  if (!is.null(path)) return(normalizePath(path, mustWork = TRUE))
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    candidate <- file.path(root, "docs", "design", "86-eva-gate2-anchor-parameters.json")
    if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Cannot find docs/design/86-eva-gate2-anchor-parameters.json.", call. = FALSE)
}

.eva_read_gate2_parameters <- function(path = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The Design 86 prototype requires jsonlite to read its frozen fixture.", call. = FALSE)
  }
  x <- jsonlite::fromJSON(.eva_gate2_file(path), simplifyVector = FALSE)
  if (!identical(x$status, "FROZEN_GATE2_ANCHOR_ONLY") ||
      !identical(x$schema_version, "1.0.0") ||
      !identical(x$gate, "G2") || !isTRUE(x$research_only)) {
    stop("The Design 86 Gate-2 fixture is not the approved frozen schema.", call. = FALSE)
  }
  x
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

.eva_read_gate1_parameters <- function(path = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The Design 86 prototype requires jsonlite to read its frozen fixture.", call. = FALSE)
  }
  x <- jsonlite::fromJSON(.eva_gate1_file(path), simplifyVector = FALSE)
  if (!identical(x$status, "FROZEN_GATE1_ONLY") || !identical(x$schema_version, "1.0.0")) {
    stop("The Design 86 Gate-1 fixture has an unsupported schema or status.", call. = FALSE)
  }
  x
}

.eva_theta_length <- function(T, q) as.integer(T * q - q * (q - 1L) / 2L)

.eva_unpack_theta <- function(theta_rr, T, q) {
  if (length(theta_rr) != .eva_theta_length(T, q) || any(!is.finite(theta_rr))) {
    stop("theta_rr has the wrong length or non-finite values.", call. = FALSE)
  }
  Lambda <- matrix(0, T, q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- theta_rr[seq_len(q)]
  cursor <- q + 1L
  for (j in seq_len(q)) {
    if (j < T) {
      rows <- seq.int(j + 1L, T)
      Lambda[rows, j] <- theta_rr[cursor:(cursor + length(rows) - 1L)]
      cursor <- cursor + length(rows)
    }
  }
  Lambda
}

.eva_fixture <- function(name = c("bernoulli", "bernoulli_q2", "gaussian", "d3_marginal_probe"), path = NULL) {
  name <- match.arg(name)
  x <- .eva_read_gate1_parameters(path)$gate1[[name]]
  N <- as.integer(x$N); T <- as.integer(x$T); q <- as.integer(x$q)
  if (N < 1L || T < 1L || q < 1L || q > T) stop("Invalid frozen fixture dimensions.", call. = FALSE)
  ans <- list(
    y = as.numeric(unlist(x$y, use.names = FALSE)),
    X = matrix(as.numeric(unlist(x$X, use.names = FALSE)), nrow = N * T, byrow = TRUE),
    unit_id = as.integer(unlist(x$unit_id, use.names = FALSE)),
    trait_id = as.integer(unlist(x$trait_id, use.names = FALSE)),
    N = N, T = T, q = q,
    beta = as.numeric(unlist(x$beta, use.names = FALSE)),
    theta_rr = as.numeric(unlist(x$theta_rr, use.names = FALSE)),
    a = matrix(as.numeric(unlist(x$a, use.names = FALSE)), nrow = N, byrow = TRUE),
    log_A_diag = matrix(as.numeric(unlist(x$log_A_diag, use.names = FALSE)), nrow = N, byrow = TRUE),
    A_off = matrix(as.numeric(unlist(x$A_off, use.names = FALSE)), nrow = N,
                   ncol = q * (q - 1L) / 2L),
    gaussian_sd = if (is.null(x$gaussian_sd)) 1 else as.numeric(x$gaussian_sd)
  )
  if (length(ans$y) != N * T || nrow(ans$X) != N * T || length(ans$unit_id) != N * T ||
      length(ans$trait_id) != N * T || ncol(ans$X) != length(ans$beta) ||
      length(ans$theta_rr) != .eva_theta_length(T, q) || ncol(ans$a) != q ||
      ncol(ans$log_A_diag) != q || any(ans$unit_id < 0L | ans$unit_id >= N) ||
      any(ans$trait_id < 0L | ans$trait_id >= T)) {
    stop("Frozen fixture fields are inconsistent.", call. = FALSE)
  }
  ans
}

.eva_find_source <- function(source = NULL) {
  if (!is.null(source)) return(normalizePath(source, mustWork = TRUE))
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    candidate <- file.path(root, "inst", "tmb", "gllvmTMB_eva.cpp")
    if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Cannot find inst/tmb/gllvmTMB_eva.cpp.", call. = FALSE)
}

.eva_validate_fixture <- function(x, family) {
  if (!is.list(x) || !identical(sort(names(x)), sort(c(
    "y", "X", "unit_id", "trait_id", "N", "T", "q", "beta", "theta_rr",
    "a", "log_A_diag", "A_off", "gaussian_sd"
  )))) stop("Fixture has unsupported fields.", call. = FALSE)
  if (x$N < 1L || x$T < 1L || x$q < 1L || x$q > x$T ||
      any(!is.finite(x$y)) || any(!is.finite(x$X)) || any(!is.finite(x$beta)) ||
      any(!is.finite(x$theta_rr)) || any(!is.finite(x$a)) || any(!is.finite(x$log_A_diag)) ||
      any(!is.finite(x$A_off)) || length(x$y) != x$N * x$T ||
      nrow(x$X) != x$N * x$T || ncol(x$X) != length(x$beta) ||
      length(x$theta_rr) != .eva_theta_length(x$T, x$q) ||
      any(x$unit_id < 0L | x$unit_id >= x$N) || any(x$trait_id < 0L | x$trait_id >= x$T) ||
      any(tabulate(x$unit_id * x$T + x$trait_id + 1L, nbins = x$N * x$T) != 1L)) {
    stop("Fixture is not a finite complete Gate-1 design.", call. = FALSE)
  }
  if (identical(family, 1L) && any(!(x$y %in% c(0, 1)))) {
    stop("Bernoulli Gate-1 fixtures require n_it = 1 and y in {0, 1}.", call. = FALSE)
  }
  if (identical(family, 0L) && (!is.finite(x$gaussian_sd) || x$gaussian_sd <= 0)) {
    stop("Gaussian test fixture requires a positive fixed standard deviation.", call. = FALSE)
  }
  invisible(x)
}

.eva_load_dll <- function(source = NULL, rebuild = FALSE, compile_flags = "-O2") {
  if (!requireNamespace("TMB", quietly = TRUE)) stop("TMB is required.", call. = FALSE)
  source <- .eva_find_source(source)
  stamp <- unname(tools::md5sum(source))
  build_dir <- file.path(tempdir(), paste0("gllvmTMB-eva-", stamp))
  cpp <- file.path(build_dir, "gllvmTMB_eva.cpp")
  if (!dir.exists(build_dir)) dir.create(build_dir, recursive = TRUE)
  if (!file.exists(cpp) || isTRUE(rebuild)) file.copy(source, cpp, overwrite = TRUE)
  dll <- TMB::dynlib(tools::file_path_sans_ext(cpp))
  loaded <- vapply(getLoadedDLLs(), function(x) identical(normalizePath(x[["path"]], mustWork = FALSE),
                                                           normalizePath(dll, mustWork = FALSE)), logical(1))
  if (!file.exists(dll) || isTRUE(rebuild)) {
    if (any(loaded)) dyn.unload(dll)
    old <- getwd(); on.exit(setwd(old), add = TRUE); setwd(build_dir)
    status <- TMB::compile(basename(cpp), flags = compile_flags)
    if (!identical(status, 0L) || !file.exists(dll)) stop("EVA prototype compilation failed.", call. = FALSE)
    loaded[] <- FALSE
  }
  if (!any(loaded)) dyn.load(dll)
  list(DLL = "gllvmTMB_eva", source = source, checksum = stamp, dll_path = dll)
}

.eva_source_commit <- function(source) {
  root <- dirname(dirname(dirname(normalizePath(source, mustWork = TRUE))))
  relative <- file.path("inst", "tmb", basename(source))
  tracked <- tryCatch(system2("git", c("-C", root, "ls-files", "--error-unmatch", relative),
                              stdout = FALSE, stderr = FALSE), error = function(e) 1L)
  clean <- tryCatch(system2("git", c("-C", root, "diff", "--quiet", "HEAD", "--", relative),
                            stdout = FALSE, stderr = FALSE), error = function(e) 1L)
  if (!identical(tracked, 0L) || !identical(clean, 0L)) return(NA_character_)
  out <- tryCatch(system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
                  error = function(e) character())
  if (length(out) == 1L && grepl("^[0-9a-f]{40}$", out)) out else NA_character_
}

.eva_make_objective <- function(fixture = c("bernoulli", "bernoulli_q2", "gaussian", "d3_marginal_probe"),
                                path = NULL, source = NULL, rebuild = FALSE, silent = TRUE) {
  fixture <- match.arg(fixture)
  x <- .eva_fixture(fixture, path)
  dll <- .eva_load_dll(source, rebuild)
  family <- if (identical(fixture, "gaussian")) 0L else 1L
  .eva_validate_fixture(x, family)
  obj <- TMB::MakeADFun(
    data = c(x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")], family = family),
    parameters = x[c("beta", "theta_rr", "a", "log_A_diag", "A_off")],
    random = NULL, DLL = dll$DLL, silent = silent
  )
  attr(obj, "eva_fixture") <- x
  attr(obj, "eva_dll") <- dll
  attr(obj, "eva_provenance") <- list(
    research_only = TRUE,
    objective_type = "EVA_TAYLOR2",
    family = if (family == 0L) "gaussian_test_only" else "bernoulli_logit",
    link = if (family == 0L) "identity" else "logit",
    unique = FALSE,
    q = x$q,
    realised_z = mean(x$y == 0),
    parameter_file_sha256 = unname(tools::sha256sum(.eva_gate1_file(path))),
    source_commit = .eva_source_commit(dll$source)
  )
  obj
}

.eva_evaluate <- function(objective, par = objective$par, gradient = FALSE) {
  if (!is.numeric(par) || length(par) != length(objective$par) || any(!is.finite(par))) {
    stop("EVA evaluation received non-finite or malformed coordinates.", call. = FALSE)
  }
  rho <- par[names(par) == "log_A_diag"]
  if (any(rho < -700 | rho > 700)) {
    stop("EVA evaluation rejected a log-Cholesky diagonal outside the finite exponential domain.", call. = FALSE)
  }
  value <- objective$fn(par)
  if (!is.finite(value)) stop("EVA evaluation produced a non-finite objective.", call. = FALSE)
  if (!isTRUE(gradient)) return(value)
  gr <- objective$gr(par)
  if (any(!is.finite(gr))) stop("EVA evaluation produced a non-finite gradient.", call. = FALSE)
  list(value = value, gradient = gr)
}

.eva_softplus_R <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

.eva_scalar_bernoulli <- function(x) {
  Lambda <- .eva_unpack_theta(x$theta_rr, x$T, x$q)
  total <- 0
  for (i in seq_len(x$N)) {
    L <- diag(exp(x$log_A_diag[i, ]), x$q)
    if (x$q > 1L) L[lower.tri(L)] <- x$A_off[i, ]
    A <- tcrossprod(L)
    kl <- 0.5 * (sum(diag(A)) + sum(x$a[i, ]^2) - 2 * sum(x$log_A_diag[i, ]) - x$q)
    rows <- which(x$unit_id == i - 1L)
    for (r in rows) {
      lambda <- Lambda[x$trait_id[r] + 1L, ]
      eta <- sum(x$X[r, ] * x$beta) + sum(lambda * x$a[i, ])
      v <- drop(crossprod(lambda, A %*% lambda))
      p <- plogis(eta)
      total <- total + x$y[r] * eta - .eva_softplus_R(eta) - 0.5 * p * (1 - p) * v
    }
    total <- total - kl
  }
  total
}

.eva_scalar_gaussian <- function(x) {
  Lambda <- .eva_unpack_theta(x$theta_rr, x$T, x$q)
  total <- 0
  for (i in seq_len(x$N)) {
    L <- diag(exp(x$log_A_diag[i, ]), x$q)
    if (x$q > 1L) L[lower.tri(L)] <- x$A_off[i, ]
    A <- tcrossprod(L)
    kl <- 0.5 * (sum(diag(A)) + sum(x$a[i, ]^2) - 2 * sum(x$log_A_diag[i, ]) - x$q)
    rows <- which(x$unit_id == i - 1L)
    for (r in rows) {
      lambda <- Lambda[x$trait_id[r] + 1L, ]
      mu <- sum(x$X[r, ] * x$beta) + sum(lambda * x$a[i, ])
      v <- drop(crossprod(lambda, A %*% lambda))
      total <- total - 0.5 * (log(2 * pi) + 2 * log(x$gaussian_sd) +
        ((x$y[r] - mu)^2 + v) / x$gaussian_sd^2)
    }
    total <- total - kl
  }
  total
}

.eva_aghq_marginal_q1 <- function(x, H) {
  stopifnot(x$q == 1L, x$N == 1L)
  rule <- .va_r3_gh_rule(H)
  lambda <- .eva_unpack_theta(x$theta_rr, x$T, x$q)[, 1L]
  log_joint <- function(u) {
    eta <- drop(x$X %*% x$beta) + lambda * u
    sum(x$y * eta - .eva_softplus_R(eta)) + stats::dnorm(u, log = TRUE)
  }
  mode <- stats::optimize(function(u) -log_joint(u), interval = c(-12, 12), tol = 1e-13)$minimum
  eta_mode <- drop(x$X %*% x$beta) + lambda * mode
  hessian <- 1 + sum(lambda^2 * stats::plogis(eta_mode) * (1 - stats::plogis(eta_mode)))
  tau <- 1 / sqrt(hessian)
  u <- mode + sqrt(2) * tau * rule$nodes
  log_terms <- vapply(u, log_joint, numeric(1)) + log(rule$weights) + rule$nodes^2
  top <- max(log_terms)
  log(sqrt(2) * tau) + top + log(sum(exp(log_terms - top)))
}

.eva_d4_remainder <- function(path = NULL) {
  d <- .eva_read_gate1_parameters(path)$gate1$d4_remainder
  mu <- as.numeric(d$mu); v <- as.numeric(d$variance); y <- as.numeric(d$y)
  set.seed(as.integer(d$seed)); u <- stats::rnorm(as.integer(d$draws), mu, sqrt(v)); delta <- u - mu
  ell <- function(z) y * z - .eva_softplus_R(z)
  p <- stats::plogis(mu)
  R <- ell(u) - ell(mu) - (y - p) * delta + 0.5 * p * (1 - p) * delta^2
  list(mean_R = mean(R), se_R = stats::sd(R) / sqrt(length(R)), draws = length(R),
       upper_3se = mean(R) + 3 * stats::sd(R) / sqrt(length(R)))
}
