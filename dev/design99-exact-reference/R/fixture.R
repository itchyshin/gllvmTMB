d99_truth <- function() {
  list(
    beta = c(-0.70, -0.35, -0.10, 0.20, 0.45, 0.70),
    Lambda = rbind(
      c(0.80, 0.00),
      c(0.20, 0.70),
      c(-0.60, 0.25),
      c(0.20, -0.75),
      c(0.25, 0.60),
      c(-0.35, -0.45)
    )
  )
}

d99_sha256_serialized <- function(x) {
  raw <- serialize(x, NULL, version = 2)
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(raw, algo = "sha256", serialize = FALSE))
  }
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::sha256(raw)))
  }
  stop(
    "Design 99 requires digest or openssl for SHA-256 fixture hashes.",
    call. = FALSE
  )
}

d99_fixture <- function() {
  truth <- d99_truth()
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(9902401)
  u_truth <- matrix(rnorm(2048L * 2L), nrow = 2048L, ncol = 2L)
  eta_truth <- sweep(u_truth %*% t(truth$Lambda), 2L, truth$beta, "+")
  p_truth <- plogis(eta_truth)
  y_full <- matrix(
    as.integer(rbinom(2048L * 6L, size = 1L, prob = as.vector(p_truth))),
    nrow = 2048L,
    ncol = 6L
  )
  prefixes <- list(
    N128 = y_full[seq_len(128L), , drop = FALSE],
    N512 = y_full[seq_len(512L), , drop = FALSE],
    N2048 = y_full
  )
  diagnostics <- lapply(prefixes, d99_fixture_diagnostics)
  if (!all(vapply(diagnostics, `[[`, logical(1), "healthy"))) {
    stop(
      "Frozen Design-99 fixture violates a mechanical response condition.",
      call. = FALSE
    )
  }
  list(
    seed = 9902401L,
    rng = c("L'Ecuyer-CMRG", "Inversion", "Rejection"),
    truth = truth,
    y_full = y_full,
    prefixes = prefixes,
    diagnostics = diagnostics,
    prefix_hashes = vapply(diagnostics, `[[`, character(1), "pattern_hash"),
    pattern_count_hashes = vapply(
      diagnostics,
      function(x) d99_sha256_serialized(x$counts),
      character(1)
    ),
    latent_hash = d99_sha256_serialized(u_truth),
    response_hash = d99_sha256_serialized(y_full)
  )
}

d99_fixture_pattern_code <- function(y) {
  raw_y <- as.matrix(y)
  if (ncol(raw_y) != 6L || any(!is.finite(raw_y)) || any(raw_y != 0 & raw_y != 1)) {
    stop("Responses must be a finite binary N by 6 matrix.", call. = FALSE)
  }
  y <- matrix(as.integer(raw_y), nrow = nrow(raw_y), ncol = 6L)
  as.integer(y %*% (2L^(5L:0L)))
}

d99_fixture_decode_pattern <- function(code) {
  code <- as.integer(code)
  if (any(is.na(code) | code < 0L | code > 63L)) {
    stop("Pattern codes must be integers from 0 through 63.", call. = FALSE)
  }
  matrix(as.integer(sapply(5L:0L, function(bit) bitwAnd(bitwShiftR(code, bit), 1L))), nrow = length(code), ncol = 6L)
}

d99_fixture_pattern_counts <- function(y) {
  as.integer(tabulate(d99_fixture_pattern_code(y) + 1L, nbins = 64L))
}

d99_fixture_diagnostics <- function(y) {
  raw_y <- as.matrix(y)
  if (ncol(raw_y) != 6L || any(!is.finite(raw_y)) || any(raw_y != 0 & raw_y != 1)) stop("Responses must be a finite binary N by 6 matrix.", call. = FALSE)
  y <- matrix(as.integer(raw_y), nrow = nrow(raw_y), ncol = 6L)
  counts <- d99_fixture_pattern_counts(y)
  codes <- d99_fixture_pattern_code(y)
  decoded <- d99_fixture_decode_pattern(codes)
  list(
    n = nrow(y),
    counts = counts,
    pattern_hash = d99_sha256_serialized(y),
    prevalences = colMeans(y),
    code_roundtrip = identical(unname(decoded), unname(y)),
    every_trait_has_both = all(colSums(y) > 0L & colSums(y) < nrow(y)),
    healthy = all(is.finite(y)) &&
      all(y %in% 0:1) &&
      sum(counts) == nrow(y) &&
      identical(unname(decoded), unname(y)) &&
      all(colSums(y) > 0L & colSums(y) < nrow(y))
  )
}

d99_empirical_beta <- function(y) {
  p <- pmin(0.98, pmax(0.02, colMeans(y)))
  d99_logit(p)
}

d99_fixed_loading <- function() {
  rbind(
    c(.45, 0),
    c(.10, .40),
    c(-.20, .15),
    c(.20, -.10),
    c(-.12, -.25),
    c(.15, .18)
  )
}

d99_spectral_details <- function(y) {
  y <- as.matrix(y)
  R <- suppressWarnings(stats::cor(y))
  R[!is.finite(R)] <- 0
  diag(R) <- 1
  R <- (R + t(R)) / 2
  ee <- eigen(R, symmetric = TRUE)
  ord <- order(-ee$values, seq_along(ee$values), method = "radix")
  values <- pmax(ee$values[ord], 0)
  vectors <- ee$vectors[, ord, drop = FALSE]
  signs <- rep.int(1, ncol(vectors))
  for (j in seq_len(ncol(vectors))) {
    first <- which(abs(vectors[, j]) > 0)[1L]
    if (!is.na(first) && vectors[first, j] < 0) {
      vectors[, j] <- -vectors[, j]
      signs[j] <- -1
    }
  }
  list(
    correlation = R,
    eigenvalues = values,
    eigenvectors = vectors,
    signs = signs,
    loading = vectors[, 1:2, drop = FALSE] %*%
      diag(sqrt(values[1:2]), nrow = 2L) *
      0.45
  )
}

d99_spectral_loading <- function(y) d99_spectral_details(y)$loading

d99_truth_start <- function() {
  truth <- d99_truth()
  list(
    beta = 0.9 * truth$beta + c(0.05, -0.04, 0.03, -0.02, 0.01, -0.05),
    Lambda = 0.9 *
      truth$Lambda +
      rbind(
        c(.02, 0),
        c(-.01, .015),
        c(.01, -.01),
        c(-.015, .02),
        c(.01, .015),
        c(-.02, -.01)
      )
  )
}

d99_starts <- function(y) {
  beta <- d99_empirical_beta(y)
  spectral <- d99_spectral_details(y)
  list(
    fixed = list(beta = beta, Lambda = d99_fixed_loading()),
    spectral = list(
      beta = beta,
      Lambda = spectral$loading,
      diagnostics = spectral
    ),
    truth = d99_truth_start()
  )
}

d99_start_coordinates <- function(y, chart = c("C12", "C34"), cap = c(4, 8)) {
  starts <- d99_starts(y)
  lapply(starts, function(s) d99_chart_pack(s$beta, s$Lambda, chart, cap))
}

d99_start_hashes <- function(y) {
  starts <- d99_starts(y)
  vapply(
    starts,
    function(s) d99_sha256_serialized(list(beta = s$beta, Lambda = s$Lambda)),
    character(1)
  )
}

d99_stress_coordinates <- function(
  chart = c("C12", "C34"),
  cap = c(4, 8),
  base = d99_truth()
) {
  # Fixed Design-99 perturbations; they are new local coordinates, not prior-design inputs.
  if (!is.list(base) || !all(c("beta", "Lambda") %in% names(base))) {
    stop("`base` must contain beta and Lambda.", call. = FALSE)
  }
  perturb_beta <- c(0.13, -0.09, 0.07, -0.11, 0.05, -0.08)
  perturb_lambda <- rbind(
    c(.09, -.04),
    c(-.06, .08),
    c(.05, .07),
    c(-.08, -.06),
    c(.07, -.05),
    c(-.04, .09)
  )
  d99_chart_pack(
    base$beta + perturb_beta,
    base$Lambda + perturb_lambda,
    chart,
    cap
  )
}
