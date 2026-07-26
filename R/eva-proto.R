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
  list(DLL = "gllvmTMB_eva", source = source, checksum = stamp)
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
