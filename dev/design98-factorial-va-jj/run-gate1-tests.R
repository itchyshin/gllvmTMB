#!/usr/bin/env Rscript

# Private Design 98 Gate 1 mechanics. Compilation occurs only on temporary
# copies of the private templates, leaving the source tree free of build files.

stopifnot(requireNamespace("TMB", quietly = TRUE))

root <- file.path("dev", "design98-factorial-va-jj")
source(file.path(root, "R", "oracle.R"))

assert_close <- function(x, y, tolerance, label) {
  error <- max(abs(x - y))
  if (!is.finite(error) || error >= tolerance) {
    stop(label, " failed: maximum absolute error ", format(error, digits = 16),
         " is not below ", tolerance)
  }
  invisible(error)
}

assert_true <- function(value, label) {
  if (!isTRUE(value)) stop(label, " failed")
  invisible(TRUE)
}

y <- rbind(
  c(1, 0, 1, 0),
  c(0, 1, 0, 1),
  c(1, 1, 0, 0),
  c(0, 0, 1, 1),
  c(1, 0, 0, 1)
)
n <- nrow(y)
traits <- ncol(y)
beta <- c(-0.30, 0.20, 0.45, -0.10)
loading <- rbind(
  c(0.70, 0),
  c(-0.25, 0.60),
  c(0.30, -0.20),
  c(-0.15, 0.40)
)
loading_free <- d98_loading_to_free(loading)
mean <- cbind(
  c(0.20, -0.10, 0.30, -0.25, 0.05),
  c(-0.15, 0.20, -0.05, 0.10, -0.20)
)
chol_full <- cbind(
  log(c(0.80, 1.10, 0.90, 1.20, 0.95)),
  c(0.12, -0.08, 0.05, 0.11, -0.09),
  log(c(0.90, 1.05, 0.85, 1.10, 1.15))
)
chol_diagonal <- chol_full[, c(1L, 3L), drop = FALSE]
gh31 <- d98_gh(31L)
gh41 <- d98_gh(41L)
gh61 <- d98_gh(61L)

# Normalized standard-normal GH convention.
for (gh in list(gh31, gh41, gh61)) {
  assert_close(sum(gh$w), 1, 1e-14, "GH weight normalization")
  assert_close(sum(gh$w * gh$z), 0, 1e-13, "GH first moment")
  assert_close(sum(gh$w * gh$z^2), 1, 1e-12, "GH second moment")
  assert_close(sum(gh$w * gh$z^4), 3, 1e-11, "GH fourth moment")
  assert_true(all(gh$w > 0), "GH positive weights")
}

# Exact private loading coordinate order and positive leading block.
assert_close(
  d98_loading_from_free(loading_free, traits),
  loading,
  1e-14,
  "loading pack/unpack"
)
assert_true(length(loading_free) == 2L * traits - 1L,
            "loading-free coordinate count")

# Build temporary copies only.
build_dir <- tempfile("design98-gate1-build-")
dir.create(build_dir)
on.exit(unlink(build_dir, recursive = TRUE, force = TRUE), add = TRUE)
for (source_name in c("design98_variational.cpp", "design98_gh.cpp")) {
  copied <- file.copy(
    file.path(root, "src", source_name),
    file.path(build_dir, source_name)
  )
  assert_true(copied, paste("copy", source_name))
}
old_wd <- setwd(build_dir)
on.exit(setwd(old_wd), add = TRUE)
TMB::compile("design98_variational.cpp", flags = "-O0")
TMB::compile("design98_gh.cpp", flags = "-O0")
variational_dll <- normalizePath(TMB::dynlib("design98_variational"))
gh_dll <- normalizePath(TMB::dynlib("design98_gh"))
dyn.load(variational_dll)
dyn.load(gh_dll)
on.exit(try(dyn.unload(gh_dll), silent = TRUE), add = TRUE)
on.exit(try(dyn.unload(variational_dll), silent = TRUE), add = TRUE)
setwd(old_wd)

method_id <- c(QD = 0L, QF = 1L, JD = 2L, JF = 3L)
method_chol <- list(
  QD = chol_diagonal,
  QF = chol_full,
  JD = chol_diagonal,
  JF = chol_full
)
variational_objects <- list()
variational_values <- numeric(length(method_id))
names(variational_values) <- names(method_id)
variational_objective_error <- variational_gradient_error <-
  setNames(numeric(length(method_id)), names(method_id))

for (method in names(method_id)) {
  chol <- method_chol[[method]]
  obj <- TMB::MakeADFun(
    data = list(
      y = y,
      method_id = method_id[[method]],
      gh_nodes = gh31$z,
      gh_weights = gh31$w
    ),
    parameters = list(
      beta = beta,
      loading_free = loading_free,
      mean = mean,
      chol_free = chol
    ),
    DLL = "design98_variational",
    silent = TRUE
  )
  theta <- d98_pack_variational(beta, loading_free, mean, chol)
  full <- method %in% c("QF", "JF")
  r_nll <- function(x) {
    value <- d98_unpack_variational(x, n, traits, full)
    -d98_variational_elbo(
      y = y,
      beta = value$beta,
      loading_free = value$loading_free,
      mean = value$mean,
      chol_free = value$chol_free,
      method = method,
      gh = gh31
    )
  }
  variational_objective_error[[method]] <- assert_close(
    obj$fn(obj$par), r_nll(theta), 1e-10,
    paste(method, "R/C++ objective equality")
  )
  central <- d98_central_gradient(r_nll, theta)
  autodiff <- obj$gr(obj$par)
  relative_error <- d98_relative_gradient_error(central, autodiff)
  variational_gradient_error[[method]] <- relative_error
  assert_true(
    is.finite(relative_error) && relative_error < 1e-5,
    paste(method, "AD/central gradient relative error")
  )
  report <- obj$report(obj$par)
  assert_close(
    report$loading %*% t(report$loading),
    report$Sigma,
    1e-12,
    paste(method, "reported Sigma composition")
  )
  variational_objects[[method]] <- obj
  variational_values[[method]] <- -obj$fn(obj$par)
}

# A diagonal Cholesky represented in the full geometry must be identical.
chol_full_zero <- cbind(
  chol_diagonal[, 1L],
  rep(0, n),
  chol_diagonal[, 2L]
)
for (pair in list(c("QD", "QF"), c("JD", "JF"))) {
  diagonal_value <- d98_variational_elbo(
    y, beta, loading_free, mean, chol_diagonal, pair[1L], gh31
  )
  full_zero_value <- d98_variational_elbo(
    y, beta, loading_free, mean, chol_full_zero, pair[2L], gh31
  )
  assert_close(
    diagonal_value, full_zero_value, 1e-12,
    paste(pair, collapse = "/")
  )
}

# Tensor-GH marginal R/C++ equality and gradient agreement.
gh_obj <- TMB::MakeADFun(
  data = list(y = y, gh_nodes = gh31$z, gh_weights = gh31$w),
  parameters = list(beta = beta, loading_free = loading_free),
  DLL = "design98_gh",
  silent = TRUE
)
global_theta <- d98_pack_global(beta, loading_free)
gh_r_nll <- function(x) {
  value <- d98_unpack_global(x, traits)
  -d98_gh_log_marginal(
    y, value$beta, value$loading_free, gh31
  )
}
gh_objective_error <- assert_close(
  gh_obj$fn(gh_obj$par),
  gh_r_nll(global_theta),
  1e-10,
  "GH R/C++ objective equality"
)
gh_central <- d98_central_gradient(gh_r_nll, global_theta)
gh_ad <- gh_obj$gr(gh_obj$par)
gh_relative_error <- d98_relative_gradient_error(gh_central, gh_ad)
assert_true(
  is.finite(gh_relative_error) && gh_relative_error < 1e-5,
  "GH AD/central gradient relative error"
)

# Bound chain at identical global and local coordinates.
for (geometry in c("D", "F")) {
  chol <- if (geometry == "D") chol_diagonal else chol_full
  q_value <- d98_variational_elbo(
    y, beta, loading_free, mean, chol, paste0("Q", geometry), gh61
  )
  j_value <- d98_variational_elbo(
    y, beta, loading_free, mean, chol, paste0("J", geometry), gh61
  )
  marginal31 <- d98_gh_log_marginal(y, beta, loading_free, gh31)
  marginal41 <- d98_gh_log_marginal(y, beta, loading_free, gh41)
  marginal61 <- d98_gh_log_marginal(y, beta, loading_free, gh61)
  allowance <- max(
    abs(marginal31 - marginal41),
    abs(marginal41 - marginal61)
  ) + 1e-8
  assert_true(j_value <= q_value + 1e-10,
              paste(geometry, "JJ <= direct ELBO"))
  assert_true(q_value <= marginal61 + allowance,
              paste(geometry, "direct ELBO <= marginal"))
}

# Posterior moments use the same normalized 2D weights as the marginal.
posterior <- d98_posterior_moments(
  y, beta, loading_free, gh61
)
assert_close(
  sum(posterior$log_normalizer),
  d98_gh_log_marginal(y, beta, loading_free, gh61),
  1e-10,
  "posterior normalizers/marginal identity"
)
for (i in seq_len(n)) {
  covariance_i <- posterior$covariance[i, , ]
  assert_close(
    covariance_i,
    t(covariance_i),
    1e-12,
    paste("posterior covariance symmetry unit", i)
  )
  assert_true(
    min(eigen(covariance_i, symmetric = TRUE, only.values = TRUE)$values) >
      -1e-12,
    paste("posterior covariance PSD unit", i)
  )
}
probability <- d98_marginal_probability(beta, loading_free, gh61)
assert_true(all(is.finite(probability) & probability > 0 & probability < 1),
            "population-marginal probabilities")

# Row permutation and latent-axis sign invariance.
permutation <- c(5L, 2L, 4L, 1L, 3L)
for (method in names(method_id)) {
  chol <- method_chol[[method]]
  permuted <- d98_variational_elbo(
    y[permutation, , drop = FALSE],
    beta,
    loading_free,
    mean[permutation, , drop = FALSE],
    chol[permutation, , drop = FALSE],
    method,
    gh31
  )
  assert_close(
    permuted,
    variational_values[[method]],
    1e-12,
    paste(method, "row permutation")
  )
}
assert_close(
  d98_gh_log_marginal_matrix(y, beta, loading, gh61),
  d98_gh_log_marginal_matrix(
    y, beta, sweep(loading, 2L, c(1, -1), "*"), gh61
  ),
  1e-10,
  "GH latent-axis sign invariance"
)

# Small-r/v branches: correct derivatives at zero and finite C++ AD.
h <- 1e-7
jj_zero_derivative <- (d98_jj_smooth_r(h) - d98_jj_smooth_r(0)) / h
assert_close(jj_zero_derivative, -1 / 8, 1e-7,
             "JJ zero-r derivative")
mu_zero <- matrix(0, 1L, 1L)
variance_zero <- matrix(0, 1L, 1L)
variance_h <- matrix(h, 1L, 1L)
direct_zero_derivative <- (
  d98_expected_softplus(mu_zero, variance_h, gh61) -
    d98_expected_softplus(mu_zero, variance_zero, gh61)
) / h
assert_close(direct_zero_derivative, 1 / 8, 1e-7,
             "direct-ELBO zero-v derivative")

zero_loading <- c(log(0.4), 0, log(0.4), rep(0, 2L * traits - 4L))
zero_mean <- matrix(0, n, 2L)
zero_diagonal <- matrix(0, n, 2L)
zero_full <- matrix(0, n, 3L)
for (method in names(method_id)) {
  chol <- if (method %in% c("QF", "JF")) zero_full else zero_diagonal
  zero_obj <- TMB::MakeADFun(
    data = list(
      y = y,
      method_id = method_id[[method]],
      gh_nodes = gh31$z,
      gh_weights = gh31$w
    ),
    parameters = list(
      beta = rep(0, traits),
      loading_free = zero_loading,
      mean = zero_mean,
      chol_free = chol
    ),
    DLL = "design98_variational",
    silent = TRUE
  )
  assert_true(
    is.finite(zero_obj$fn(zero_obj$par)) &&
      all(is.finite(zero_obj$gr(zero_obj$par))),
    paste(method, "zero-branch AD finiteness")
  )
}

# Gaussian exactness anchor for the full Gaussian variational family.
gaussian_loading <- rbind(c(0.8, 0.1), c(-0.2, 0.7), c(0.4, -0.3))
gaussian_beta <- c(-0.1, 0.2, 0.35)
gaussian_variance <- c(0.7, 1.1, 0.9)
gaussian_y <- rbind(
  c(0.4, -0.3, 0.8),
  c(-0.2, 0.5, 0.1)
)
precision <- diag(2) +
  crossprod(gaussian_loading, gaussian_loading / gaussian_variance)
posterior_cov <- solve(precision)
posterior_chol <- t(chol(posterior_cov))
gaussian_elbo <- 0
gaussian_marginal <- 0
marginal_cov <- gaussian_loading %*% t(gaussian_loading) +
  diag(gaussian_variance)
marginal_logdet <- as.numeric(determinant(
  marginal_cov, logarithm = TRUE
)$modulus)
for (i in seq_len(nrow(gaussian_y))) {
  residual <- gaussian_y[i, ] - gaussian_beta
  posterior_mean <- posterior_cov %*%
    crossprod(gaussian_loading, residual / gaussian_variance)
  fitted_residual <- residual -
    as.vector(gaussian_loading %*% posterior_mean)
  projected_variance <- rowSums(
    (gaussian_loading %*% posterior_cov) * gaussian_loading
  )
  expected_loglik <- -0.5 * sum(
    log(2 * pi * gaussian_variance) +
      (fitted_residual^2 + projected_variance) / gaussian_variance
  )
  posterior_logdet <- as.numeric(determinant(
    posterior_cov, logarithm = TRUE
  )$modulus)
  kl <- 0.5 * (
    sum(diag(posterior_cov)) +
      sum(posterior_mean^2) -
      posterior_logdet - 2
  )
  gaussian_elbo <- gaussian_elbo + expected_loglik - kl
  gaussian_marginal <- gaussian_marginal - 0.5 * (
    3 * log(2 * pi) + marginal_logdet +
      sum(residual * solve(marginal_cov, residual))
  )
}
assert_true(
  posterior_chol[1L, 1L] > 0 && posterior_chol[2L, 2L] > 0,
  "Gaussian posterior Cholesky identification"
)
assert_close(
  gaussian_elbo,
  gaussian_marginal,
  1e-10,
  "Gaussian full-family exactness"
)

gh31_posterior <- d98_posterior_moments(
  y, beta, loading_free, gh31
)
gh_report <- gh_obj$report(gh_obj$par)
assert_close(
  gh_report$posterior_mean,
  gh31_posterior$mean,
  1e-10,
  "GH posterior-mean R/C++ equality"
)
gh31_covariance_compact <- cbind(
  gh31_posterior$covariance[, 1L, 1L],
  gh31_posterior$covariance[, 1L, 2L],
  gh31_posterior$covariance[, 2L, 2L]
)
assert_close(
  gh_report$posterior_covariance,
  gh31_covariance_compact,
  1e-10,
  "GH posterior-covariance R/C++ equality"
)

cat(
  "Variational objective max abs errors:",
  paste(
    names(variational_objective_error),
    format(variational_objective_error, scientific = TRUE, digits = 6),
    sep = "=",
    collapse = ", "
  ),
  "\n"
)
cat(
  "Variational gradient max relative errors:",
  paste(
    names(variational_gradient_error),
    format(variational_gradient_error, scientific = TRUE, digits = 6),
    sep = "=",
    collapse = ", "
  ),
  "\n"
)
cat(
  "GH objective max abs error:",
  format(gh_objective_error, scientific = TRUE, digits = 6),
  "\n"
)
cat(
  "GH gradient max relative error:",
  format(gh_relative_error, scientific = TRUE, digits = 6),
  "\n"
)
cat("Design 98 Gate 1 numerical-core tests: PASS\n")
