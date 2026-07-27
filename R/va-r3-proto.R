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

.va_r3_best_three_range <- function(objectives) {
  objectives <- sort(as.numeric(objectives))
  if (length(objectives) < 3L || any(!is.finite(objectives))) return(Inf)
  min(vapply(seq_len(length(objectives) - 2L), function(i) {
    objectives[i + 2L] - objectives[i]
  }, numeric(1)))
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

  family <- match.arg(family, c("binomial", "poisson", "gaussian_anchor"))
  if (family == "binomial") {
    if (!identical(link, "logit")) {
      stop("R3 admits only the binomial logit link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || any(y != as.integer(y)) ||
        !is.numeric(n_trials) || any(!is.finite(n_trials)) ||
        any(n_trials != as.integer(n_trials)) || any(n_trials < 1L) ||
        any(y < 0L) || any(y > n_trials)) {
      stop("Binomial R3 data require integer n_trials >= 1 and integer 0 <= y <= n_trials.",
           call. = FALSE)
    }
    family_code <- 1L
  } else if (family == "poisson") {
    if (!identical(link, "log")) {
      stop("R3 admits only the Poisson log link.", call. = FALSE)
    }
    if (!is.numeric(y) || any(!is.finite(y)) || any(y != as.integer(y)) ||
        any(y < 0L)) {
      stop("Poisson R3 data require finite non-negative integer y.", call. = FALSE)
    }
    ## The standalone template declares n_trials for every branch; the Poisson
    ## algebra does not use it, but it must be finite and correctly sized.
    n_trials <- rep.int(1L, length(y))
    family_code <- 2L
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

## Rotate a T x q loadings matrix Lambda (from an eigendecomposition, hence
## generally dense) into the lower-triangular form .va_r3_pack_theta_rr()
## requires, without changing Lambda %*% t(Lambda).  Factor loadings are only
## identified up to a right-orthogonal rotation, so this picks the rotation Q
## (q x q) that makes the top q x q block lower triangular: an LQ
## decomposition of that block, obtained via the QR decomposition of its
## transpose (t(L1) = Q1 R1 => L1 = t(R1) %*% t(Q1) => L1 %*% Q1 = t(R1),
## lower triangular; Q1 is a legitimate rotation because it is orthogonal).
## Below-block rows automatically satisfy the packer's zero-pattern
## regardless of rotation.  QR leaves a strict-upper block that is
## numerically ~0 rather than exactly 0, so it is hard-zeroed afterwards
## (after checking it really is negligible).
.va_r3_rotate_to_lower_triangular <- function(Lambda, q) {
  L1 <- Lambda[seq_len(q), seq_len(q), drop = FALSE]
  Q1 <- qr.Q(qr(t(L1)))
  rotated <- Lambda %*% Q1
  upper <- row(rotated) < col(rotated)
  if (any(upper) && max(abs(rotated[upper])) > 1e-6) return(NULL)
  rotated[upper] <- 0
  rotated
}

## Factor-analytic warm start for the loadings: eigendecompose the
## correlation of the link-scale residuals (response pseudo-data minus the
## fixed-effect contribution already estimated in beta) and take the first q
## eigenvectors, scaled by sqrt(eigenvalue), as Lambda.  This mirrors gllvm's
## starting.val = "res".  Returns NULL (caller falls back to the constant
## start) on any degeneracy: too few units, non-finite correlations, a
## non-finite eigendecomposition, or a rotation that fails the lower-triangle
## check above.
.va_r3_warm_theta_rr <- function(data, beta) {
  N <- data$N
  T <- data$T
  q <- data$q
  if (N < 2L) return(NULL)
  eta_fixed <- as.numeric(data$X %*% beta)
  pseudo <- if (data$family == 1L) {
    prop <- pmin(pmax((data$y + 0.5) / (data$n_trials + 1), 1e-6), 1 - 1e-6)
    stats::qlogis(prop)
  } else if (data$family == 2L) {
    log(data$y + 0.5)
  } else {
    data$y
  }
  resid <- pseudo - eta_fixed
  Z <- matrix(NA_real_, nrow = N, ncol = T)
  Z[cbind(data$unit_id + 1L, data$trait_id + 1L)] <- resid
  if (anyNA(Z) || !all(is.finite(Z))) return(NULL)
  cor_Z <- tryCatch(stats::cor(Z), error = function(e) NULL)
  if (is.null(cor_Z) || !all(is.finite(cor_Z))) return(NULL)
  eig <- tryCatch(eigen(cor_Z, symmetric = TRUE), error = function(e) NULL)
  if (is.null(eig) || !all(is.finite(eig$values)) || !all(is.finite(eig$vectors))) {
    return(NULL)
  }
  Lambda <- eig$vectors[, seq_len(q), drop = FALSE] %*%
    diag(sqrt(pmax(eig$values[seq_len(q)], 0)), nrow = q, ncol = q)
  Lambda <- tryCatch(.va_r3_rotate_to_lower_triangular(Lambda, q),
                     error = function(e) NULL)
  if (is.null(Lambda) || !all(is.finite(Lambda))) return(NULL)
  theta_rr <- tryCatch(.va_r3_pack_theta_rr(Lambda, q), error = function(e) NULL)
  if (is.null(theta_rr) ||
      length(theta_rr) != .va_r3_theta_length(T, q) ||
      !all(is.finite(theta_rr))) {
    return(NULL)
  }
  theta_rr
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

  ## Start 1 = the factor-analytic warm start (data-driven loadings).  Starts
  ## 2-4 add the pre-existing jitter pattern on top of that same warm base,
  ## rather than replacing it, so the 4-start agreement gate still probes
  ## genuinely different starting points.  A degenerate/non-finite warm start
  ## falls back to the original constant-diagonal start for all four starts.
  theta_rr <- .va_r3_warm_theta_rr(data, beta)
  if (is.null(theta_rr)) {
    theta_rr <- rep(0, .va_r3_theta_length(T, q))
    theta_rr[seq_len(q)] <- c(0.10, -0.10, 0.20, -0.20)[1L] *
      rep(c(1, -1), length.out = q)
  }
  if (start_id > 1L) {
    diagonal_scale <- c(0.10, -0.10, 0.20, -0.20)[start_id]
    theta_rr[seq_len(q)] <- theta_rr[seq_len(q)] +
      diagonal_scale * rep(c(1, -1), length.out = q)
    if (length(theta_rr) > q) {
      k <- seq_len(length(theta_rr) - q)
      theta_rr[-seq_len(q)] <- theta_rr[-seq_len(q)] + (0.01 * start_id) * sin(k)
    }
  }
  m <- matrix(0, nrow = N, ncol = q)
  log_L_diag <- matrix(0, nrow = N, ncol = q)
  L_off <- matrix(0, nrow = N, ncol = q * (q - 1L) / 2L)
  if (start_id > 1L) {
    m[] <- c(0.01, 0.02, 0.015)[start_id - 1L] *
      sin(seq_len(length(m)) + start_id)
    log_L_diag[] <- c(-0.025, 0.025, -0.04)[start_id - 1L]
    if (length(L_off)) {
      L_off[] <- c(0.005, 0.01, 0.0075)[start_id - 1L] *
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

## Per-family evaluation contract for the VA-R3 engine.
##
## The VA objective needs E[log p(y | eta)] with eta ~ N(mu, v). For every
## family whose likelihood enters through a SCALAR linear predictor that is a
## one-dimensional integral, so a family is specified here by which evaluation
## tiers the template implements for it and which one `eval_method = "auto"`
## resolves to. Adding a family is a registry entry plus a template branch,
## not a new dispatch rule.
##
## Fields
##   family       : R-side name accepted by .va_r3_validate_data()
##   family_code  : integer passed to the template as DATA_INTEGER(family)
##   link         : the single link this family admits
##   tiers        : evaluation tiers the template implements for it
##   default_tier : what eval_method = "auto" resolves to
##   expectation  : how E[log p(y|eta)] is obtained under default_tier --
##                  "exact" (closed form), "quadrature" (Gauss-Hermite), or
##                  "bound" (a variational bound, deliberately not an equality)
.va_r3_family_registry <- list(
  ## Gaussian anchor -- E[(y - eta)^2] = (y - mu)^2 + v in closed form, so the
  ## quadrature nodes are never touched and no bound is needed.
  list(
    family = "gaussian_anchor",
    family_code = 0L,
    link = "identity",
    tiers = "gh",
    default_tier = "gh",
    expectation = "exact"
  ),

  ## Binomial-logit -- the only family with a genuine choice. Gauss-Hermite
  ## evaluates E[softplus(eta)] to quadrature accuracy; the Jaakkola-Jordan/PG
  ## bound over-estimates it in closed form, which is what keeps the ELBO a
  ## valid lower bound. "auto" takes the bound: measured 1.9-4.0x faster
  ## (n = 200/400/800, interleaved) with better Sigma_B recovery on 20/20
  ## paired seeds. Ask for "gh" to force quadrature -- the controlled bound
  ## comparisons in dev/ do exactly that.
  list(
    family = "binomial",
    family_code = 1L,
    link = "logit",
    tiers = c("gh", "jj"),
    default_tier = "jj",
    expectation = "bound"
  ),

  ## Poisson-log -- E[exp(eta)] = exp(mu + v/2) is the log-normal mean, exact.
  list(
    family = "poisson",
    family_code = 2L,
    link = "log",
    tiers = "gh",
    default_tier = "gh",
    expectation = "exact"
  )
)

.va_r3_family_entry <- function(family_code) {
  for (entry in .va_r3_family_registry) {
    if (identical(entry$family_code, family_code)) return(entry)
  }
  stop("VA-R3 has no registry entry for family code ", family_code, ".",
       call. = FALSE)
}

.va_r3_resolve_eval_method <- function(eval_method = c("auto", "jj", "gh"), family) {
  eval_method <- match.arg(eval_method)
  entry <- .va_r3_family_entry(family)
  if (identical(eval_method, "auto")) return(entry$default_tier)
  if (!eval_method %in% entry$tiers) {
    stop(sprintf(
      "eval_method = \"%s\" is not implemented for the %s family; available: %s.",
      eval_method, entry$family, paste(entry$tiers, collapse = ", ")),
      call. = FALSE)
  }
  eval_method
}

.va_r3_eval_method_code <- function(eval_method = c("auto", "jj", "gh"), family) {
  if (identical(.va_r3_resolve_eval_method(eval_method, family), "jj")) 1L else 0L
}

.va_r3_objective_type <- function(resolved_eval_method) {
  if (identical(resolved_eval_method, "jj")) "ELBO_JJ" else "ELBO_GH"
}

## Latent-variable posterior summary from a fitted parameter vector.
##
## The variational posterior q(z_i) = N(m_i, L_i L_i') is ESTIMATED, so its
## per-unit spread is already computed at the optimum and needs only to be
## read out -- unlike beta and the loadings, which are point-estimated and
## carry no variational distribution at all.
##
## Two honesty constraints are baked into the return value:
##   * `uncertainty_basis` records that these are VARIATIONAL posterior SDs,
##     conditional on the point estimates of beta and theta_rr. They are not
##     Wald standard errors and they do not propagate loading uncertainty.
##   * `calibrated = FALSE` until a coverage study says otherwise. Variational
##     posteriors are known to understate spread; the size of that understatement
##     here is unmeasured, so nothing downstream may quote these as intervals.
## The list(scores=, se=) shape matches the existing getLV(se = TRUE) contract
## in R/output-methods.R so this can be wired to that surface without a new API.
.va_r3_latent_posterior <- function(par, N, q) {
  N <- as.integer(N)
  q <- as.integer(q)
  nm <- names(par)
  if (is.null(nm)) {
    stop("par must carry TMB parameter names to read the variational block.",
         call. = FALSE)
  }
  take <- function(what) unname(par[nm == what])
  scores <- matrix(take("m"), nrow = N, ncol = q)
  chol_factors <- .va_r3_unpack_variational_chol(
    take("log_L_diag"), take("L_off"), N, q
  )
  se <- matrix(NA_real_, nrow = N, ncol = q)
  for (i in seq_len(N)) {
    L_i <- matrix(chol_factors[, , i], nrow = q, ncol = q)
    ## pmax(., 0) mirrors .getLV_se(); a Cholesky product cannot be negative
    ## on the diagonal except through floating-point error.
    se[i, ] <- sqrt(pmax(diag(L_i %*% t(L_i)), 0))
  }
  list(
    scores = scores,
    se = se,
    uncertainty_basis = "variational posterior, conditional on point estimates of beta and theta_rr",
    calibrated = FALSE
  )
}

## Observed information for the FIXED parameters (beta, theta_rr).
##
## Unlike the latent block above, beta and theta_rr have no variational
## distribution -- they are maximised, so an SE has to come from curvature.
## Two are computed, and the difference between them matters:
##
##   se_conditional : from H_ff alone, holding the variational coordinates at
##                    their optimum. This is what a naive optimHess over the
##                    fixed block gives. It IGNORES the fact that m and the
##                    Cholesky would re-optimise as beta and theta_rr move, so
##                    it overstates curvature and is expected ANTI-CONSERVATIVE.
##   se_profile     : the Schur complement H_ff - H_fv H_vv^-1 H_vf, i.e. the
##                    curvature of the objective with the variational block
##                    profiled out. This is the correct observed information
##                    for the fixed parameters and is the one to prefer.
##
## Conventions follow the package (R/extractors.R returns a status code; the
## confint surface carries a pd_hessian column) and GLLVM.jl/src/confint.jl
## (PD check, NA rather than a number when the Hessian is not usable).
##
## Neither SE is calibrated. Variational posteriors understate spread, and the
## size of that understatement here is unmeasured, so `calibrated` stays FALSE
## until a coverage study fills it in.
.va_r3_fixed_information <- function(objective, par,
                                     max_variational = 6000L) {
  fail <- function(status) {
    list(se_conditional = NULL, se_profile = NULL, pd_hessian = FALSE,
         calibrated = FALSE, status = status)
  }
  nm <- names(par)
  if (is.null(nm)) return(fail("va_unnamed_par_no_fixed_se"))
  fixed_idx <- which(nm %in% c("beta", "theta_rr"))
  var_idx <- which(nm %in% c("m", "log_L_diag", "L_off"))
  if (!length(fixed_idx)) return(fail("va_no_fixed_block_no_fixed_se"))

  hessian <- tryCatch(objective$he(par), error = function(e) NULL)
  if (is.null(hessian) || !all(is.finite(hessian))) {
    return(fail("va_hessian_error_no_fixed_se"))
  }

  ## sqrt of the diagonal of the inverse, guarded on positive-definiteness.
  se_from <- function(info) {
    ok <- tryCatch({
      chol(info)
      TRUE
    }, error = function(e) FALSE)
    if (!ok) return(NULL)
    covariance <- tryCatch(solve(info), error = function(e) NULL)
    if (is.null(covariance)) return(NULL)
    diagonal <- diag(covariance)
    if (any(!is.finite(diagonal)) || any(diagonal < 0)) return(NULL)
    stats::setNames(sqrt(diagonal), nm[fixed_idx])
  }

  H_ff <- hessian[fixed_idx, fixed_idx, drop = FALSE]
  se_conditional <- se_from(H_ff)

  ## The Schur complement needs H_vv inverted. H_vv is block diagonal by unit,
  ## so this is far cheaper than it looks -- but the dense solve below is not,
  ## which is why it is size-guarded. Exploiting the block structure is the
  ## scaling path when this is needed at large n.
  se_profile <- NULL
  profile_status <- "ok"
  if (!length(var_idx)) {
    profile_status <- "va_no_variational_block"
  } else if (length(var_idx) > max_variational) {
    profile_status <- "va_variational_block_too_large_for_dense_schur"
  } else {
    H_fv <- hessian[fixed_idx, var_idx, drop = FALSE]
    H_vv <- hessian[var_idx, var_idx, drop = FALSE]
    schur <- tryCatch(H_ff - H_fv %*% solve(H_vv, t(H_fv)),
                      error = function(e) NULL)
    if (is.null(schur)) {
      profile_status <- "va_singular_variational_block"
    } else {
      se_profile <- se_from(schur)
      if (is.null(se_profile)) profile_status <- "va_non_pd_profile_information"
    }
  }

  list(
    se_conditional = se_conditional,
    se_profile = se_profile,
    pd_hessian = !is.null(se_profile),
    calibrated = FALSE,
    status = if (is.null(se_conditional)) {
      "va_non_pd_fixed_information_no_fixed_se"
    } else profile_status,
    basis = paste(
      "observed information of the negative ELBO;",
      "se_profile marginalises the variational block, se_conditional does not"
    )
  )
}

.va_r3_make_objective <- function(validated, H = 61L, source = NULL,
                                  rebuild = FALSE, parameters = NULL,
                                  fixed_global = NULL, silent = TRUE,
                                  eval_method = c("auto", "jj", "gh")) {
  if (validated$q == 0L) {
    stop("q = 0 is not applicable and must not construct an R3 objective.",
         call. = FALSE)
  }
  eval_method <- match.arg(eval_method)
  eval_method_code <- .va_r3_eval_method_code(eval_method, validated$family)
  rule <- .va_r3_gh_rule(H)
  dll <- .va_r3_load_dll(source, rebuild = rebuild)
  if (is.null(parameters)) parameters <- .va_r3_default_parameters(validated, 1L)
  tmb_data <- validated[c("y", "n_trials", "X", "unit_id", "trait_id",
                          "N", "T", "q", "family", "gaussian_sd")]
  tmb_data$gh_nodes <- rule$nodes
  tmb_data$gh_weights <- rule$weights
  tmb_data$eval_method <- eval_method_code
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
                       family = c("binomial", "poisson", "gaussian_anchor"),
                       link = switch(family[1L],
                         gaussian_anchor = "identity",
                         poisson = "log",
                         "logit"),
                       unique = FALSE, psi = FALSE, structured = FALSE,
                       provider = NULL, lv = FALSE, missing = FALSE,
                       gaussian_sd = 1, H = 61L,
                       rank_source = c("fixed_fixture", "ml_bic"),
                       fixed_global = NULL, source = NULL, rebuild = FALSE,
                       control = list(eval.max = 2000L, iter.max = 2000L),
                       silent = TRUE, eval_method = c("auto", "jj", "gh")) {
  family <- match.arg(family)
  rank_source <- match.arg(rank_source)
  eval_method <- match.arg(eval_method)
  validated <- .va_r3_validate_data(
    y, n_trials, X, unit_id, trait_id, q, N, T, family, link,
    unique, psi, structured, provider, lv, missing, gaussian_sd
  )
  ## Validate and resolve eval_method against the family up front, before any
  ## objective is constructed, so a mismatched request fails closed for every
  ## start. Everything downstream reports the RESOLVED bound, not the request,
  ## so an "auto" fit never mislabels which bound it actually evaluated.
  resolved_eval_method <- .va_r3_resolve_eval_method(eval_method, validated$family)
  if (validated$q == 0L) {
    return(list(
      status = "not_applicable_rank_zero",
      reason = if (rank_source == "ml_bic") {
        "ML/BIC selected rank zero; there is no latent posterior to approximate."
      } else {
        "The fixed research fixture has rank zero; there is no latent posterior to approximate."
      },
      research_only = TRUE,
      objective_type = .va_r3_objective_type(resolved_eval_method),
      rank_source = rank_source,
      family = switch(family, gaussian_anchor = "gaussian", poisson = "poisson",
                      "binomial"),
      link = link,
      unique = FALSE,
      eval_method = resolved_eval_method,
      quadrature = NULL,
      source_commit = NA_character_,
      objective_constructed = FALSE
    ))
  }
  rule <- .va_r3_gh_rule(H)
  starts <- lapply(1:4, function(k) .va_r3_default_parameters(validated, k))
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
  fits <- vector("list", length(starts))
  objects <- vector("list", length(starts))
  for (k in seq_along(starts)) {
    obj <- .va_r3_make_objective(
      validated, H = H, source = source, rebuild = rebuild && k == 1L,
      parameters = starts[[k]], fixed_global = fixed_global, silent = silent,
      eval_method = eval_method
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
    polish_passes <- 0L
    for (polish in seq_len(2L)) {
      current_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
      if (all(is.finite(current_gradient)) &&
          max(abs(current_gradient)) < 1e-4) break
      candidate <- tryCatch(
        stats::nlminb(opt$par, obj$fn, obj$gr, control = control),
        error = function(e) NULL
      )
      if (is.null(candidate) || !is.finite(candidate$objective) ||
          candidate$objective > opt$objective + 1e-8) break
      opt <- candidate
      polish_passes <- polish
    }
    polish_optimizer <- "nlminb_only"
    post_nlminb_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
    if (!all(is.finite(post_nlminb_gradient)) ||
        max(abs(post_nlminb_gradient)) >= 1e-4) {
      ## L-BFGS-B, not BFGS: BFGS carries a dense inverse-Hessian over the whole
      ## parameter vector, which here includes N*(2q + q(q-1)/2) variational
      ## coordinates, so its cost grows with n while L-BFGS-B's limited memory
      ## stays flat. factr is L-BFGS-B's relative-tolerance control and
      ## 1e-12 / .Machine$double.eps is the translation of BFGS's reltol = 1e-12.
      lbfgsb <- tryCatch(
        stats::optim(opt$par, obj$fn, obj$gr, method = "L-BFGS-B",
                     control = list(maxit = 500L,
                                    factr = 1e-12 / .Machine$double.eps)),
        error = function(e) NULL
      )
      if (!is.null(lbfgsb) && identical(lbfgsb$convergence, 0L) &&
          is.finite(lbfgsb$value) && lbfgsb$value <= opt$objective + 1e-8) {
        opt <- list(
          par = lbfgsb$par, objective = lbfgsb$value,
          convergence = lbfgsb$convergence, message = lbfgsb$message,
          evaluations = lbfgsb$counts, iterations = NA_integer_
        )
        polish_optimizer <- "nlminb_then_lbfgsb"
      }
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
      iterations = opt$iterations,
      polish_passes = polish_passes,
      polish_optimizer = polish_optimizer
    )
  }
  healthy_id <- which(vapply(fits, `[[`, logical(1), "healthy"))
  objectives <- vapply(fits, `[[`, numeric(1), "objective")
  agreement_range <- Inf
  if (length(healthy_id) >= 3L) {
    agreement_range <- .va_r3_best_three_range(objectives[healthy_id])
  }
  agreement <- length(healthy_id) >= 3L && agreement_range <= 1e-6
  admitted <- length(healthy_id) >= 3L && agreement
  best_id <- if (length(healthy_id)) {
    healthy_id[which.min(objectives[healthy_id])]
  } else if (any(is.finite(objectives))) {
    which.min(objectives)
  } else {
    NA_integer_
  }
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
  ## The variational block is already in best$par -- read it out rather than
  ## discarding per-unit posterior spread the fit has genuinely estimated.
  latent <- if (!is.null(best) && !is.null(best$par)) {
    tryCatch(
      .va_r3_latent_posterior(best$par, validated$N, validated$q),
      error = function(e) list(scores = NULL, se = NULL,
                               error = conditionMessage(e))
    )
  } else NULL

  list(
    status = if (admitted) {
      "healthy"
    } else if (!variance_domain_ok) {
      "failed_variance_domain"
    } else {
      "failed_health_gate"
    },
    research_only = TRUE,
    objective_type = .va_r3_objective_type(resolved_eval_method),
    rank_source = rank_source,
    family = switch(family, gaussian_anchor = "gaussian", poisson = "poisson",
                    "binomial"),
    link = link,
    unique = FALSE,
    q = validated$q,
    eval_method = resolved_eval_method,
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
      attempted_starts = length(starts),
      minimum_healthy_starts = 3L,
      all_starts_healthy = length(healthy_id) == length(starts),
      objective_agreement = agreement,
      best_three_objective_range = agreement_range,
      gradient_tolerance = 1e-4,
      agreement_tolerance = 1e-6,
      max_projected_variance = max_projected_variance,
      projected_variance_limit = 4,
      variance_domain_ok = variance_domain_ok
    ),
    best = best,
    latent = latent,
    report = best_report,
    objective = if (!is.na(best_id)) objects[[best_id]] else NULL
  )
}
