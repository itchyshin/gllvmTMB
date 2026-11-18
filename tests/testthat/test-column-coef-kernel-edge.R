# Alignment for the bounded Gaussian edge cells:
# symbol       keyword                         DGP draw           extractor       truth
# Sigma scale  kernel_coef(1 || trait)         MN intercept       extract_Sigma() 0.01 / 100
# correlation  kernel_coef(1 + x | trait)      MN intercept/slope extract_Sigma() 0 / +/-0.8
# missing y    kernel_coef(1 + x | trait)      one NA response    fitted()/opt    accepted
# rare pathway fixed pathway + kernel_coef()   4:1 pathway split  coef()/opt      accepted

.make_kernel_edge_fit <- function(Sigma, seed, missing = FALSE) {
  set.seed(seed)
  n_traits <- 5L
  n_unit <- 30L
  traits <- paste0("t", seq_len(n_traits))
  d <- seq(0.9, 1.1, length.out = n_traits)
  R <- 0.35^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  rho <- 0.55
  K_rho <- rho * K + (1 - rho) * diag(diag(K))
  p <- nrow(Sigma)
  Z <- scale(matrix(stats::rnorm(n_traits * p), n_traits, p),
             center = TRUE, scale = FALSE)
  Z <- Z %*% solve(chol(stats::cov(Z)))
  B <- t(chol(K_rho)) %*% Z %*% chol(Sigma)
  x <- seq(-1.5, 1.5, length.out = n_unit)
  wide <- data.frame(unit = factor(paste0("u", seq_len(n_unit))), x = x)
  for (j in seq_len(n_traits)) {
    eta <- 0.2 + B[j, 1L]
    if (p == 2L) eta <- eta + B[j, 2L] * x
    wide[[traits[[j]]]] <- eta + stats::rnorm(n_unit, sd = 0.02)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(traits), names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  if (missing) long$value[long$trait == traits[[2L]] & long$unit == "u3"] <- NA_real_
  basis <- if (p == 1L) quote(1 || trait) else quote(1 + x | trait)
  formula <- call("~", quote(value), call("+", 1,
    as.call(list(as.name("kernel_coef"), basis, K = quote(K), rho = rho))))
  formula <- stats::as.formula(formula, env = environment())
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    formula, data = long, trait = "trait", unit = "unit",
    family = stats::gaussian(), control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  list(fit = fit, Sigma = gllvmTMB::extract_Sigma(fit, level = "column_coef")$Sigma,
       long = long, K = K)
}

test_that("kernel coefficient variance-scale edges remain estimable", {
  small <- .make_kernel_edge_fit(matrix(0.01, 1L, 1L), seed = 13251L)
  large <- .make_kernel_edge_fit(matrix(100, 1L, 1L), seed = 13252L)
  expect_identical(small$fit$opt$convergence, 0L)
  expect_identical(large$fit$opt$convergence, 0L)
  expect_true(all(is.finite(small$fit$tmb_obj$gr(small$fit$opt$par))))
  expect_true(all(is.finite(large$fit$tmb_obj$gr(large$fit$opt$par))))
  expect_gt(small$Sigma[1L, 1L], 0.002)
  expect_lt(small$Sigma[1L, 1L], 0.03)
  expect_gt(large$Sigma[1L, 1L], 30)
  expect_lt(large$Sigma[1L, 1L], 180)
})

test_that("kernel coefficient correlation edges retain sign and magnitude", {
  for (rho_coef in c(0, 0.8, -0.8)) {
    Sigma <- outer(c(0.45, 0.35), c(0.45, 0.35)) *
      matrix(c(1, rho_coef, rho_coef, 1), 2L, 2L)
    out <- .make_kernel_edge_fit(Sigma, seed = 13260L + round(10 * rho_coef))
    got <- stats::cov2cor(out$Sigma)[1L, 2L]
    expect_identical(out$fit$opt$convergence, 0L)
    expect_true(is.finite(got))
    if (rho_coef == 0) expect_lt(abs(got), 0.35)
    if (rho_coef > 0) expect_gt(got, 0.5)
    if (rho_coef < 0) expect_lt(got, -0.5)
  }
})

test_that("kernel coefficients accept a missing response and rare fixed pathway", {
  missing <- .make_kernel_edge_fit(
    matrix(c(0.20, 0.05, 0.05, 0.12), 2L, 2L), seed = 13253L,
    missing = TRUE
  )
  expect_identical(missing$fit$opt$convergence, 0L)
  expect_true(all(is.finite(missing$fit$opt$par)))

  fx <- .make_kernel_coef_fixture(seed = 13254L, n_traits = 5L, n_unit = 24L)
  column_data <- data.frame(
    trait = fx$traits,
    pathway = factor(c("C3", "C3", "C3", "C3", "C4"),
                     levels = c("C3", "C4"))
  )
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + pathway + x:pathway +
      kernel_coef(1 + x | trait, K = fx$K, rho = 0.5),
    data = fx$long, column_data = column_data, trait = "trait", unit = "unit",
    family = stats::gaussian(), control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(stats::coef(fit))))
})
