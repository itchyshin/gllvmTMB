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
  ## Installed-package fallback. The walk above only finds the file inside a
  ## source checkout, because `docs/` is excluded from the build
  ## (.Rbuildignore). Under `R CMD check` the tests run from a temp directory
  ## against the INSTALLED package, so the walk ran to the filesystem root and
  ## stopped -- surfacing as 7 test failures and the check's only ERROR, while
  ## `devtools::load_all()` stayed green. A copy of the same 3.3 KB fixture is
  ## shipped in inst/extdata/ so the gate tests run from an installed package
  ## too, rather than being skipped.
  installed <- system.file(
    "extdata", "86-eva-gate1-parameters.json",
    package = "gllvmTMB"
  )
  if (nzchar(installed) && file.exists(installed)) {
    return(normalizePath(installed, mustWork = TRUE))
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
    data = c(x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")],
             family = family, n_trials = list(rep(1, length(x$y)))),
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

## Design 86 data-accepting fitting path (Curie). This is the EVA analogue of
## .va_r3_validate_data() / .va_r3_default_parameters() / .va_r3_make_objective()
## / .va_r3_fit() in R/va-r3-proto.R: it lets EVA construct and optimise an
## objective from caller-supplied data, instead of only evaluating a frozen
## Gate-1 fixture by name at a single fixed coordinate. It reuses
## .va_r3_normalise_index() (index normalisation is identical for both
## engines) exactly as this file already reuses .va_r3_gh_rule() in
## .eva_aghq_marginal_q1() above.

.eva_validate_data <- function(y, n_trials, X, unit_id, trait_id, q,
                               N = NULL, T = NULL,
                               family = c("binomial", "poisson", "gaussian_anchor"),
                               link = switch(family[1L],
                                 gaussian_anchor = "identity",
                                 poisson = "log",
                                 "logit"),
                               unique = FALSE, gaussian_sd = 1) {
  if (length(q) != 1L || !is.numeric(q) || !is.finite(q) ||
      q != as.integer(q) || q < 1L || q > 6L) {
    stop("q must be one integer in 1..6.", call. = FALSE)
  }
  q <- as.integer(q)
  if (!is.matrix(X) || !is.numeric(X) || nrow(X) != length(y) ||
      ncol(X) < 1L || any(!is.finite(X))) {
    stop("X must be a finite numeric matrix with one row per response and at least one column.",
         call. = FALSE)
  }
  if (length(unit_id) != length(y) || length(trait_id) != length(y) ||
      length(n_trials) != length(y)) {
    stop("y, n_trials, unit_id, trait_id, and the rows of X must have equal length.",
         call. = FALSE)
  }
  if (is.null(N)) N <- length(unique(unit_id))
  if (is.null(T)) T <- length(unique(trait_id))
  if (length(N) != 1L || length(T) != 1L || !is.finite(N) || !is.finite(T) ||
      N != as.integer(N) || T != as.integer(T) || N < 1L || T < 1L) {
    stop("N and T must be positive integers.", call. = FALSE)
  }
  N <- as.integer(N)
  T <- as.integer(T)
  if (q > T) stop("q must not exceed T.", call. = FALSE)

  uid <- .va_r3_normalise_index(unit_id, N, "unit_id")
  tid <- .va_r3_normalise_index(trait_id, T, "trait_id")
  cell <- uid * T + tid
  if (length(y) != N * T || length(unique(cell)) != N * T ||
      !identical(sort(cell), 0:(N * T - 1L))) {
    stop("EVA requires exactly one complete observation for every unit-trait cell.",
         call. = FALSE)
  }
  if (qr(X)$rank != ncol(X)) {
    stop("X must have full column rank.", call. = FALSE)
  }
  if (!identical(unique, FALSE)) {
    stop("EVA admits only ordinary latent(..., unique = FALSE) data.", call. = FALSE)
  }

  family <- match.arg(family, c("binomial", "poisson", "gaussian_anchor"))
  if (family == "binomial") {
    if (!identical(link, "logit")) {
      stop("EVA admits only the binomial logit link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || any(y != as.integer(y)) ||
        !is.numeric(n_trials) || any(!is.finite(n_trials)) ||
        any(n_trials != as.integer(n_trials)) || any(n_trials < 1L) ||
        any(y < 0L) || any(y > n_trials)) {
      stop("Binomial EVA data require integer n_trials >= 1 and integer 0 <= y <= n_trials.",
           call. = FALSE)
    }
    family_code <- 1L
  } else if (family == "poisson") {
    if (!identical(link, "log")) {
      stop("EVA admits only the Poisson log link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || any(y != as.integer(y)) ||
        any(y < 0L)) {
      stop("Poisson EVA data require finite non-negative integer y.", call. = FALSE)
    }
    ## The standalone template declares n_trials for every branch; the Poisson
    ## algebra does not use it, but it must be finite and correctly sized.
    n_trials <- rep.int(1L, length(y))
    family_code <- 2L
  } else {
    if (!identical(link, "identity")) {
      stop("The Gaussian EVA anchor uses the identity link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || length(gaussian_sd) != 1L ||
        !is.numeric(gaussian_sd) || !is.finite(gaussian_sd) || gaussian_sd <= 0) {
      stop("The Gaussian EVA anchor requires finite y and one positive gaussian_sd.",
           call. = FALSE)
    }
    ## The standalone template declares n_trials for both branches.
    n_trials <- rep.int(1L, length(y))
    family_code <- 0L
  }

  list(
    y = as.numeric(y),
    n_trials = as.numeric(n_trials),
    X = unname(X),
    unit_id = uid,
    trait_id = tid,
    N = N,
    T = T,
    q = q,
    family = family_code,
    family_name = family,
    link = link,
    gaussian_sd = as.numeric(gaussian_sd)
  )
}

.eva_default_parameters <- function(data) {
  N <- data$N
  T <- data$T
  q <- data$q
  p <- ncol(data$X)
  beta <- rep(0, p)
  if (data$family == 1L) {
    prop <- (data$y + 0.5) / (data$n_trials + 1)
    beta_fit <- tryCatch(stats::lm.fit(data$X, stats::qlogis(prop))$coefficients,
                         error = function(e) rep(0, p))
  } else if (data$family == 2L) {
    ## Poisson uses a log link, so start beta on the log scale; the 0.5
    ## offset keeps zero counts finite.
    beta_fit <- tryCatch(stats::lm.fit(data$X, log(data$y + 0.5))$coefficients,
                         error = function(e) rep(0, p))
  } else {
    beta_fit <- tryCatch(stats::lm.fit(data$X, data$y)$coefficients,
                         error = function(e) rep(0, p))
  }
  if (length(beta_fit) == p && all(is.finite(beta_fit))) beta <- unname(beta_fit)

  theta_rr <- rep(0, .eva_theta_length(T, q))
  diagonal_scale <- 0.10
  theta_rr[seq_len(q)] <- diagonal_scale * rep(c(1, -1), length.out = q)

  list(
    beta = beta,
    theta_rr = theta_rr,
    a = matrix(0, nrow = N, ncol = q),
    log_A_diag = matrix(0, nrow = N, ncol = q),
    A_off = matrix(0, nrow = N, ncol = q * (q - 1L) / 2L)
  )
}

.eva_make_objective_data <- function(validated, source = NULL, rebuild = FALSE,
                                     parameters = NULL, silent = TRUE) {
  dll <- .eva_load_dll(source, rebuild)
  if (is.null(parameters)) parameters <- .eva_default_parameters(validated)
  tmb_data <- validated[c("y", "n_trials", "X", "unit_id", "trait_id",
                          "N", "T", "q", "family", "gaussian_sd")]
  obj <- TMB::MakeADFun(
    data = tmb_data,
    parameters = parameters,
    random = NULL, DLL = dll$DLL, silent = silent
  )
  attr(obj, "eva_dll") <- dll
  obj
}

.eva_fit <- function(y, n_trials, X, unit_id, trait_id, q,
                     N = NULL, T = NULL,
                     family = c("binomial", "poisson", "gaussian_anchor"),
                     link = switch(family[1L],
                       gaussian_anchor = "identity",
                       poisson = "log",
                       "logit"),
                     unique = FALSE, gaussian_sd = 1,
                     source = NULL, rebuild = FALSE,
                     control = list(eval.max = 2000L, iter.max = 2000L),
                     silent = TRUE) {
  family <- match.arg(family)
  validated <- .eva_validate_data(y, n_trials, X, unit_id, trait_id, q, N, T,
                                  family, link, unique, gaussian_sd)
  parameters <- .eva_default_parameters(validated)
  obj <- .eva_make_objective_data(validated, source = source, rebuild = rebuild,
                                  parameters = parameters, silent = silent)
  dll <- attr(obj, "eva_dll")

  opt <- tryCatch(
    stats::nlminb(obj$par, obj$fn, obj$gr, control = control),
    error = function(e) structure(list(message = conditionMessage(e)),
                                  class = "eva_optimizer_error")
  )
  if (inherits(opt, "eva_optimizer_error")) {
    return(list(
      status = "failed_optimizer_error",
      research_only = TRUE,
      objective_type = "EVA_TAYLOR2",
      family = switch(family, gaussian_anchor = "gaussian", poisson = "poisson", "binomial"),
      link = link,
      unique = FALSE,
      q = validated$q,
      source_commit = .eva_source_commit(dll$source),
      source_checksum = dll$checksum,
      optimizer = "nlminb",
      best = list(convergence = NA_integer_, objective = NA_real_,
                  max_abs_gradient = Inf, finite_parameters = FALSE,
                  healthy = FALSE, message = opt$message),
      report = NULL,
      objective = obj
    ))
  }

  ## Mirror .va_r3_fit()'s polish loop exactly: up to two additional nlminb
  ## passes while the gradient has not yet cleared the 1e-4 tolerance, then a
  ## BFGS polish if nlminb alone did not get there. No other optimiser
  ## strategy is introduced.
  polish_passes <- 0L
  polish_optimizer <- "nlminb_only"
  for (polish in seq_len(2L)) {
    current_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
    if (all(is.finite(current_gradient)) && max(abs(current_gradient)) < 1e-4) break
    candidate <- tryCatch(
      stats::nlminb(opt$par, obj$fn, obj$gr, control = control),
      error = function(e) NULL
    )
    if (is.null(candidate) || !is.finite(candidate$objective) ||
        candidate$objective > opt$objective + 1e-8) break
    opt <- candidate
    polish_passes <- polish
  }
  post_nlminb_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
  if (!all(is.finite(post_nlminb_gradient)) ||
      max(abs(post_nlminb_gradient)) >= 1e-4) {
    bfgs <- tryCatch(
      stats::optim(opt$par, obj$fn, obj$gr, method = "BFGS",
                   control = list(maxit = 500L, reltol = 1e-12)),
      error = function(e) NULL
    )
    if (!is.null(bfgs) && identical(bfgs$convergence, 0L) &&
        is.finite(bfgs$value) && bfgs$value <= opt$objective + 1e-8) {
      opt <- list(
        par = bfgs$par, objective = bfgs$value,
        convergence = bfgs$convergence, message = bfgs$message,
        evaluations = bfgs$counts, iterations = NA_integer_
      )
      polish_optimizer <- "nlminb_then_bfgs"
    }
  }

  gradient <- tryCatch(obj$gr(opt$par), error = function(e) rep(NA_real_, length(opt$par)))
  finite_parameters <- all(is.finite(opt$par))
  max_abs_gradient <- if (length(gradient) && all(is.finite(gradient))) {
    max(abs(gradient))
  } else Inf
  healthy <- identical(opt$convergence, 0L) && is.finite(opt$objective) &&
    finite_parameters && max_abs_gradient < 1e-4
  best <- list(
    convergence = opt$convergence,
    objective = unname(opt$objective),
    max_abs_gradient = max_abs_gradient,
    finite_parameters = finite_parameters,
    healthy = healthy,
    message = opt$message,
    par = opt$par,
    evaluations = opt$evaluations,
    iterations = opt$iterations,
    polish_passes = polish_passes,
    polish_optimizer = polish_optimizer
  )
  report <- tryCatch(obj$report(opt$par), error = function(e) {
    list(report_error = conditionMessage(e))
  })

  list(
    status = if (healthy) "healthy" else "failed_health_gate",
    research_only = TRUE,
    objective_type = "EVA_TAYLOR2",
    family = switch(family, gaussian_anchor = "gaussian", poisson = "poisson", "binomial"),
    link = link,
    unique = FALSE,
    q = validated$q,
    source_commit = .eva_source_commit(dll$source),
    source_checksum = dll$checksum,
    optimizer = "nlminb",
    best = best,
    report = report,
    objective = obj
  )
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
