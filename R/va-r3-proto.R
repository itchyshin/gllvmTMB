## Research-only Gaussian variational approximation prototype (Design 85).
##
## This file deliberately contains no roxygen export tags and creates no
## gllvmTMB class.  The objective is a quadrature-evaluated ELBO, not a
## marginal likelihood.  It is kept separate from fit_multi() and the shipped
## gllvmTMB TMB template so that the R3 falsification experiment cannot become
## an accidental user-facing fitting route.

.va_r3_theta_length <- function(T, q) {
  T <- as.integer(T)
  q <- as.integer(q)
  as.integer(T * q - q * (q - 1L) / 2L)
}

.va_r3_L_off_length <- function(N, q) {
  as.integer(N * q * (q - 1L) / 2L)
}

.va_r3_unpack_theta_rr <- function(theta_rr, T, q) {
  T <- as.integer(T)
  q <- as.integer(q)
  expected <- .va_r3_theta_length(T, q)
  if (!is.numeric(theta_rr) || length(theta_rr) != expected ||
      any(!is.finite(theta_rr))) {
    stop("theta_rr must be a finite numeric vector of length ", expected,
         ".", call. = FALSE)
  }
  Lambda <- matrix(0, nrow = T, ncol = q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- theta_rr[seq_len(q)]
  cursor <- q + 1L
  for (j in seq_len(q)) {
    if (j < T) {
      rows <- seq.int(j + 1L, T)
      take <- length(rows)
      Lambda[rows, j] <- theta_rr[cursor:(cursor + take - 1L)]
      cursor <- cursor + take
    }
  }
  Lambda
}

.va_r3_pack_theta_rr <- function(Lambda, q = ncol(Lambda)) {
  if (!is.matrix(Lambda) || !is.numeric(Lambda) || any(!is.finite(Lambda))) {
    stop("Lambda must be a finite numeric matrix.", call. = FALSE)
  }
  T <- nrow(Lambda)
  q <- as.integer(q)
  if (q < 1L || q > T || ncol(Lambda) != q) {
    stop("Lambda must have T rows and q columns with 1 <= q <= T.",
         call. = FALSE)
  }
  upper <- row(Lambda) < col(Lambda)
  if (any(Lambda[upper] != 0)) {
    stop("Lambda's strict upper triangle must be exactly zero.",
         call. = FALSE)
  }
  out <- diag(Lambda)[seq_len(q)]
  for (j in seq_len(q)) {
    if (j < T) out <- c(out, Lambda[seq.int(j + 1L, T), j])
  }
  unname(out)
}

.va_r3_unpack_variational_chol <- function(log_L_diag, L_off, N, q) {
  N <- as.integer(N)
  q <- as.integer(q)
  if (!is.numeric(log_L_diag) || length(log_L_diag) != N * q ||
      any(!is.finite(log_L_diag))) {
    stop("log_L_diag must contain N*q finite entries.", call. = FALSE)
  }
  expected_off <- .va_r3_L_off_length(N, q)
  if (!is.numeric(L_off) || length(L_off) != expected_off ||
      any(!is.finite(L_off))) {
    stop("L_off has the wrong length or contains non-finite entries.",
         call. = FALSE)
  }
  ans <- array(0, dim = c(q, q, N))
  diag_values <- matrix(exp(log_L_diag), nrow = N, ncol = q)
  off_matrix <- matrix(L_off, nrow = N,
                       ncol = q * (q - 1L) / 2L)
  for (i in seq_len(N)) {
    ans[, , i][cbind(seq_len(q), seq_len(q))] <- diag_values[i, ]
    off_pos <- 1L
    for (j in seq_len(q)) {
      if (j < q) {
        rows <- seq.int(j + 1L, q)
        take <- seq.int(off_pos, length.out = length(rows))
        ans[rows, j, i] <- off_matrix[i, take]
        off_pos <- off_pos + length(rows)
      }
    }
  }
  ans
}

.va_r3_gh_rule <- function(H = 61L) {
  H <- as.integer(H)
  if (length(H) != 1L || is.na(H) || !(H %in% c(15L, 25L, 61L))) {
    stop("The R3 quadrature order must be H = 15, H = 25, or H = 61.",
         call. = FALSE)
  }
  ## Golub--Welsch for the physicists' Hermite weight exp(-x^2).
  J <- matrix(0, H, H)
  if (H > 1L) {
    off <- sqrt(seq_len(H - 1L) / 2)
    J[cbind(seq_len(H - 1L), 2:H)] <- off
    J[cbind(2:H, seq_len(H - 1L))] <- off
  }
  ee <- eigen(J, symmetric = TRUE)
  ord <- order(ee$values)
  nodes <- unname(ee$values[ord])
  ## The first-eigenvector formula loses the extreme H=61 weights to exact
  ## zero in base eigen().  Evaluate the equivalent physicists' Hermite
  ## polynomial formula instead; at the admitted orders it remains finite.
  hm2 <- rep(1, H)
  hm1 <- 2 * nodes
  if (H > 2L) {
    for (k in 2:(H - 1L)) {
      hk <- 2 * nodes * hm1 - 2 * (k - 1) * hm2
      hm2 <- hm1
      hm1 <- hk
    }
  }
  weights <- 2^(H - 1L) * gamma(H + 1) * sqrt(pi) / (H^2 * hm1^2)
  weights <- weights * sqrt(pi) / sum(weights)
  list(
    nodes = nodes,
    weights = unname(weights),
    order = H,
    convention = "physicists"
  )
}

.va_r3_normalise_index <- function(x, size, name) {
  if (!is.numeric(x) || any(!is.finite(x)) || any(x != as.integer(x))) {
    stop(name, " must contain finite integer indices.", call. = FALSE)
  }
  x <- as.integer(x)
  if (all(x >= 1L & x <= size)) return(x - 1L)
  if (all(x >= 0L & x < size)) return(x)
  stop(name, " must use either 1..", size, " or 0..", size - 1L,
       " consistently.", call. = FALSE)
}

.va_r3_validate_data <- function(y, n_trials, X, unit_id, trait_id, q,
                                 N = NULL, T = NULL,
                                 family = "binomial", link = "logit",
                                 unique = FALSE, psi = FALSE,
                                 structured = FALSE, provider = NULL,
                                 lv = FALSE, missing = FALSE,
                                 gaussian_sd = 1) {
  if (length(q) != 1L || !is.numeric(q) || !is.finite(q) ||
      q != as.integer(q) || q < 0L || q > 6L) {
    stop("q must be one integer in 0..6.", call. = FALSE)
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
    stop("R3 requires exactly one complete observation for every unit-trait cell.",
         call. = FALSE)
  }
  if (qr(X)$rank != ncol(X)) {
    stop("X must have full column rank.", call. = FALSE)
  }
  if (!identical(unique, FALSE) || !identical(psi, FALSE) ||
      !identical(structured, FALSE) || !is.null(provider) ||
      !identical(lv, FALSE) || !identical(missing, FALSE)) {
    stop("R3 admits only ordinary latent(..., unique = FALSE) data with no Psi, structured/provider, lv, or missing-data marker.",
         call. = FALSE)
  }

  family <- match.arg(family, c("binomial", "gaussian_anchor"))
  if (family == "binomial") {
    if (!identical(link, "logit")) {
      stop("R3 admits only the binomial logit link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || any(y != as.integer(y)) ||
        !is.numeric(n_trials) || any(!is.finite(n_trials)) ||
        any(n_trials != as.integer(n_trials)) || any(n_trials < 2L) ||
        any(y < 0L) || any(y > n_trials)) {
      stop("Binomial R3 data require integer n_trials >= 2 and integer 0 <= y <= n_trials.",
           call. = FALSE)
    }
    family_code <- 1L
  } else {
    if (!identical(link, "identity")) {
      stop("The Gaussian algebra anchor uses the identity link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || length(gaussian_sd) != 1L ||
        !is.numeric(gaussian_sd) || !is.finite(gaussian_sd) ||
        gaussian_sd <= 0) {
      stop("The Gaussian anchor requires finite y and one positive gaussian_sd.",
           call. = FALSE)
    }
    ## The standalone template declares n_trials for both branches.
    n_trials <- rep.int(1L, length(y))
    family_code <- 0L
  }

  list(
    y = as.numeric(y),
    n_trials = as.integer(n_trials),
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

.va_r3_find_source <- function(source = NULL) {
  if (!is.null(source)) {
    source <- normalizePath(source, mustWork = TRUE)
    return(source)
  }
  installed <- system.file("tmb", "gllvmTMB_va_r3.cpp", package = "gllvmTMB")
  if (nzchar(installed) && file.exists(installed)) return(installed)
  path <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    candidate <- file.path(path, "inst", "tmb", "gllvmTMB_va_r3.cpp")
    if (file.exists(candidate)) return(normalizePath(candidate, mustWork = TRUE))
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  stop("Cannot find inst/tmb/gllvmTMB_va_r3.cpp; supply `source` explicitly.",
       call. = FALSE)
}

.va_r3_load_dll <- function(source = NULL, rebuild = FALSE,
                            compile_flags = "-O2") {
  if (!requireNamespace("TMB", quietly = TRUE)) {
    stop("The research prototype requires TMB.", call. = FALSE)
  }
  source <- .va_r3_find_source(source)
  stamp <- unname(tools::md5sum(source))
  build_dir <- file.path(tempdir(), paste0("gllvmTMB-va-r3-", stamp))
  cpp <- file.path(build_dir, "gllvmTMB_va_r3.cpp")
  if (!dir.exists(build_dir)) dir.create(build_dir, recursive = TRUE)
  if (!file.exists(cpp) || isTRUE(rebuild)) {
    if (!file.copy(source, cpp, overwrite = TRUE)) {
      stop("Failed to copy the R3 TMB source into its temporary build directory.",
           call. = FALSE)
    }
  }
  dll <- TMB::dynlib(tools::file_path_sans_ext(cpp))
  loaded <- vapply(getLoadedDLLs(), function(x) {
    path <- x[["path"]]
    nzchar(path) && identical(normalizePath(path, mustWork = FALSE),
                              normalizePath(dll, mustWork = FALSE))
  }, logical(1))
  if (!file.exists(dll) || isTRUE(rebuild)) {
    if (any(loaded)) dyn.unload(dll)
    old <- getwd()
    on.exit(setwd(old), add = TRUE)
    setwd(build_dir)
    status <- TMB::compile(basename(cpp), flags = compile_flags)
    if (length(status) != 1L || is.na(status) || status != 0 ||
        !file.exists(dll)) {
      stop("Compilation of the standalone R3 TMB template failed.",
           call. = FALSE)
    }
    loaded[] <- FALSE
  }
  if (!any(loaded)) dyn.load(dll)
  list(DLL = "gllvmTMB_va_r3", path = dll, source = source, checksum = stamp)
}

.va_r3_source_commit <- function(source) {
  root <- dirname(dirname(dirname(normalizePath(source, mustWork = FALSE))))
  relative <- tryCatch(
    sub(paste0("^", normalizePath(root, mustWork = FALSE), "/"), "",
        normalizePath(source, mustWork = FALSE)),
    error = function(e) source
  )
  tracked <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "ls-files", "--error-unmatch",
                     shQuote(relative)), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  ))
  clean <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "diff", "--quiet", "HEAD", "--",
                     shQuote(relative)), stdout = FALSE, stderr = FALSE),
    error = function(e) 1L
  ))
  if (!identical(tracked, 0L) || !identical(clean, 0L)) return(NA_character_)
  out <- suppressWarnings(tryCatch(
    system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"),
            stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  ))
  if (length(out) == 1L && grepl("^[0-9a-f]{40}$", out)) out else NA_character_
}

.va_r3_default_parameters <- function(data, start_id = 1L) {
  N <- data$N
  T <- data$T
  q <- data$q
  p <- ncol(data$X)
  start_id <- as.integer(start_id)
  beta <- rep(0, p)
  if (data$family == 1L) {
    prop <- (data$y + 0.5) / (data$n_trials + 1)
    beta_fit <- tryCatch(stats::lm.fit(data$X, stats::qlogis(prop))$coefficients,
                         error = function(e) rep(0, p))
  } else {
    beta_fit <- tryCatch(stats::lm.fit(data$X, data$y)$coefficients,
                         error = function(e) rep(0, p))
  }
  if (length(beta_fit) == p && all(is.finite(beta_fit))) beta <- unname(beta_fit)

  theta_rr <- rep(0, .va_r3_theta_length(T, q))
  diagonal_scale <- c(0.10, -0.10, 0.20)[start_id]
  theta_rr[seq_len(q)] <- diagonal_scale * rep(c(1, -1), length.out = q)
  if (length(theta_rr) > q && start_id > 1L) {
    k <- seq_len(length(theta_rr) - q)
    theta_rr[-seq_len(q)] <- (0.01 * start_id) * sin(k)
  }
  m <- matrix(0, nrow = N, ncol = q)
  log_L_diag <- matrix(0, nrow = N, ncol = q)
  L_off <- matrix(0, nrow = N, ncol = q * (q - 1L) / 2L)
  if (start_id > 1L) {
    m[] <- 0.01 * (start_id - 1L) *
      sin(seq_len(length(m)) + start_id)
    log_L_diag[] <- c(-0.025, 0.025)[start_id - 1L]
    if (length(L_off)) {
      L_off[] <- 0.005 * (start_id - 1L) *
        cos(seq_len(length(L_off)) + start_id)
    }
  }
  list(
    beta = beta,
    theta_rr = theta_rr,
    m = m,
    log_L_diag = log_L_diag,
    L_off = L_off
  )
}

.va_r3_make_objective <- function(validated, H = 61L, source = NULL,
                                  rebuild = FALSE, parameters = NULL,
                                  fixed_global = NULL, silent = TRUE) {
  if (validated$q == 0L) {
    stop("q = 0 is not applicable and must not construct an R3 objective.",
         call. = FALSE)
  }
  rule <- .va_r3_gh_rule(H)
  dll <- .va_r3_load_dll(source, rebuild = rebuild)
  if (is.null(parameters)) parameters <- .va_r3_default_parameters(validated, 1L)
  tmb_data <- validated[c("y", "n_trials", "X", "unit_id", "trait_id",
                          "N", "T", "q", "family", "gaussian_sd")]
  tmb_data$gh_nodes <- rule$nodes
  tmb_data$gh_weights <- rule$weights
  map <- NULL
  if (!is.null(fixed_global)) {
    if (!is.list(fixed_global) ||
        !identical(sort(names(fixed_global)), c("beta", "theta_rr"))) {
      stop("fixed_global must be a named list containing exactly beta and theta_rr.",
           call. = FALSE)
    }
    if (length(fixed_global$beta) != ncol(validated$X) ||
        any(!is.finite(fixed_global$beta))) {
      stop("fixed_global$beta has the wrong length or non-finite entries.",
           call. = FALSE)
    }
    ## Unpacking is also an exact validation of the live theta length.
    .va_r3_unpack_theta_rr(fixed_global$theta_rr, validated$T, validated$q)
    parameters$beta <- as.numeric(fixed_global$beta)
    parameters$theta_rr <- as.numeric(fixed_global$theta_rr)
    map <- list(
      beta = factor(rep(NA_integer_, length(parameters$beta))),
      theta_rr = factor(rep(NA_integer_, length(parameters$theta_rr)))
    )
  }
  obj <- TMB::MakeADFun(
    data = tmb_data,
    parameters = parameters,
    map = map,
    random = NULL,
    DLL = dll$DLL,
    silent = silent
  )
  attr(obj, "va_r3_dll") <- dll
  attr(obj, "va_r3_quadrature") <- rule
  obj
}

.va_r3_fit <- function(y, n_trials, X, unit_id, trait_id, q,
                       N = NULL, T = NULL,
                       family = c("binomial", "gaussian_anchor"),
                       link = if (identical(family[1L], "gaussian_anchor"))
                         "identity" else "logit",
                       unique = FALSE, psi = FALSE, structured = FALSE,
                       provider = NULL, lv = FALSE, missing = FALSE,
                       gaussian_sd = 1, H = 61L,
                       rank_source = c("fixed_fixture", "ml_bic"),
                       fixed_global = NULL, source = NULL, rebuild = FALSE,
                       control = list(eval.max = 2000L, iter.max = 2000L),
                       silent = TRUE) {
  family <- match.arg(family)
  rank_source <- match.arg(rank_source)
  validated <- .va_r3_validate_data(
    y, n_trials, X, unit_id, trait_id, q, N, T, family, link,
    unique, psi, structured, provider, lv, missing, gaussian_sd
  )
  if (validated$q == 0L) {
    return(list(
      status = "not_applicable_rank_zero",
      reason = if (rank_source == "ml_bic") {
        "ML/BIC selected rank zero; there is no latent posterior to approximate."
      } else {
        "The fixed research fixture has rank zero; there is no latent posterior to approximate."
      },
      research_only = TRUE,
      objective_type = "ELBO_GH",
      rank_source = rank_source,
      family = if (family == "gaussian_anchor") "gaussian" else "binomial",
      link = link,
      unique = FALSE,
      quadrature = NULL,
      source_commit = NA_character_,
      objective_constructed = FALSE
    ))
  }
  rule <- .va_r3_gh_rule(H)
  starts <- lapply(1:3, function(k) .va_r3_default_parameters(validated, k))
  if (!is.null(fixed_global)) {
    if (!is.list(fixed_global) ||
        !identical(sort(names(fixed_global)), c("beta", "theta_rr"))) {
      stop("fixed_global must be a named list containing exactly beta and theta_rr.",
           call. = FALSE)
    }
    if (length(fixed_global$beta) != ncol(validated$X) ||
        any(!is.finite(fixed_global$beta))) {
      stop("fixed_global$beta has the wrong length or non-finite entries.",
           call. = FALSE)
    }
    .va_r3_unpack_theta_rr(fixed_global$theta_rr, validated$T, validated$q)
    for (k in seq_along(starts)) {
      starts[[k]]$beta <- as.numeric(fixed_global$beta)
      starts[[k]]$theta_rr <- as.numeric(fixed_global$theta_rr)
    }
  }
  fits <- vector("list", 3L)
  objects <- vector("list", 3L)
  for (k in seq_len(3L)) {
    obj <- .va_r3_make_objective(
      validated, H = H, source = source, rebuild = rebuild && k == 1L,
      parameters = starts[[k]], fixed_global = fixed_global, silent = silent
    )
    objects[[k]] <- obj
    opt <- tryCatch(
      stats::nlminb(obj$par, obj$fn, obj$gr, control = control),
      error = function(e) structure(list(message = conditionMessage(e)),
                                    class = "va_r3_optimizer_error")
    )
    if (inherits(opt, "va_r3_optimizer_error")) {
      fits[[k]] <- list(start = k, convergence = NA_integer_,
                        objective = NA_real_, max_abs_gradient = Inf,
                        finite_parameters = FALSE, healthy = FALSE,
                        message = opt$message)
      next
    }
    gradient <- tryCatch(obj$gr(opt$par), error = function(e) rep(NA_real_, length(opt$par)))
    finite_parameters <- all(is.finite(opt$par))
    max_abs_gradient <- if (length(gradient) && all(is.finite(gradient))) {
      max(abs(gradient))
    } else Inf
    healthy <- identical(opt$convergence, 0L) && is.finite(opt$objective) &&
      finite_parameters && max_abs_gradient < 1e-4
    fits[[k]] <- list(
      start = k,
      convergence = opt$convergence,
      objective = unname(opt$objective),
      max_abs_gradient = max_abs_gradient,
      finite_parameters = finite_parameters,
      healthy = healthy,
      message = opt$message,
      par = opt$par,
      evaluations = opt$evaluations,
      iterations = opt$iterations
    )
  }
  healthy_id <- which(vapply(fits, `[[`, logical(1), "healthy"))
  objectives <- vapply(fits, `[[`, numeric(1), "objective")
  agreement <- length(healthy_id) == 3L &&
    diff(range(objectives[healthy_id])) <= 1e-6
  admitted <- length(healthy_id) == 3L && agreement
  best_id <- if (any(is.finite(objectives))) which.min(objectives) else NA_integer_
  best <- if (!is.na(best_id)) fits[[best_id]] else NULL
  best_report <- if (!is.na(best_id)) {
    tryCatch(objects[[best_id]]$report(best$par), error = function(e) {
      list(report_error = conditionMessage(e))
    })
  } else NULL
  max_projected_variance <- if (is.list(best_report) &&
      !is.null(best_report$v_by_obs) &&
      all(is.finite(best_report$v_by_obs))) {
    max(best_report$v_by_obs)
  } else Inf
  variance_domain_ok <- max_projected_variance <= 4
  admitted <- admitted && variance_domain_ok
  dll <- attr(objects[[1L]], "va_r3_dll")

  list(
    status = if (admitted) {
      "healthy"
    } else if (!variance_domain_ok) {
      "failed_variance_domain"
    } else {
      "failed_health_gate"
    },
    research_only = TRUE,
    objective_type = "ELBO_GH",
    rank_source = rank_source,
    family = if (family == "gaussian_anchor") "gaussian" else "binomial",
    link = link,
    unique = FALSE,
    q = validated$q,
    quadrature = list(order = rule$order, convention = rule$convention,
                      nodes = rule$nodes, weights = rule$weights),
    source_commit = .va_r3_source_commit(dll$source),
    source_checksum = dll$checksum,
    fixed_global = !is.null(fixed_global),
    optimizer = "nlminb",
    starts = fits,
    health = list(
      admitted = admitted,
      healthy_starts = length(healthy_id),
      all_three_healthy = length(healthy_id) == 3L,
      objective_agreement = agreement,
      objective_range = if (length(healthy_id)) diff(range(objectives[healthy_id])) else Inf,
      gradient_tolerance = 1e-4,
      agreement_tolerance = 1e-6,
      max_projected_variance = max_projected_variance,
      projected_variance_limit = 4,
      variance_domain_ok = variance_domain_ok
    ),
    best = best,
    report = best_report,
    objective = if (!is.na(best_id)) objects[[best_id]] else NULL
  )
}
