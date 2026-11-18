test_that("kernel spectral source matches direct mixtures", {
  fx <- .make_kernel_coef_fixture(seed = 13245L, n_traits = 5L)
  source <- gllvmTMB:::.resolve_kernel_coef_spectral_source(
    K = fx$K, data = fx$long, group = "trait", source_name = "env"
  )
  for (rho in c(0.13, 0.47, 0.91)) {
    s <- (1 - rho) + rho * source$lambda
    Q <- diag(1 / source$d) %*% source$U %*%
      diag(1 / s) %*% t(source$U) %*% diag(1 / source$d)
    K_rho <- rho * fx$K + (1 - rho) * diag(diag(fx$K))
    expect_equal(unname(Q), unname(solve(K_rho)), tolerance = 1e-10)
    expect_equal(2 * sum(log(source$d)) + sum(log(s)),
                 as.numeric(determinant(K_rho, logarithm = TRUE)$modulus),
                 tolerance = 1e-10)
  }
})

test_that("fixed kernel mixtures and coefficient maps are exact", {
  fx <- .make_kernel_coef_fixture(seed = 13246L, n_traits = 5L)
  full <- .fit_kernel_coef(fx, value ~ 1 +
    kernel_coef(1 + x | trait, K = fx$K, name = "env", rho = 0.37))
  diagonal <- .fit_kernel_coef(fx, value ~ 1 +
    kernel_coef(1 + x || trait, K = fx$K, name = "env", rho = 0.37))
  K_rho <- 0.37 * fx$K + 0.63 * diag(diag(fx$K))
  expect_equal(as.matrix(full$tmb_data$Ainv_phy_slope), solve(K_rho),
               tolerance = 1e-10)
  expect_identical(sum(names(full$opt$par) == "theta_dep_chol"), 3L)
  expect_identical(sum(names(diagonal$opt$par) == "theta_dep_chol"), 2L)
  got <- gllvmTMB::extract_Sigma(full, level = "column_coef")
  expect_equal(got$K_rho, K_rho, tolerance = 1e-10)
  expect_identical(got$source$type, "kernel")
  expect_identical(got$source$name, "env")
})

test_that("estimated kernel rho is finite and identity sources are rejected", {
  fx <- .make_kernel_coef_fixture(seed = 13247L, n_traits = 5L, n_unit = 20L)
  fit <- .fit_kernel_coef(fx, value ~ 1 +
    kernel_coef(1 + x | trait, K = fx$K, rho = NULL))
  expect_identical(fit$tmb_data$use_column_coef_estimated_rho, 1L)
  expect_true("eta_column_coef_rho" %in% names(fit$opt$par))
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(got$rho_status, "estimated")
  expect_true(is.finite(got$rho))
  expect_gte(got$rho, 0); expect_lte(got$rho, 1)
  expect_equal(got$K_rho,
               got$rho * fx$K + (1 - got$rho) * diag(diag(fx$K)),
               tolerance = 1e-8)

  I <- diag(length(fx$traits)); dimnames(I) <- list(fx$traits, fx$traits)
  expect_error(.fit_kernel_coef(fx, value ~ 1 +
    kernel_coef(0 + x | trait, K = I, rho = NULL)),
    class = "gllvmTMB_column_coef_rho_unidentified")
})

test_that("kernel coefficient sources are invariant to interior label order", {
  fx <- .make_kernel_coef_fixture(seed = 13249L, n_traits = 5L, n_unit = 18L)
  reversed <- rev(fx$traits)
  K_permuted <- fx$K[reversed, reversed]
  formulas <- list(
    fixed = list(
      original = value ~ 1 + kernel_coef(1 + x | trait, K = fx$K,
                                          name = "env", rho = 0.41),
      permuted = value ~ 1 + kernel_coef(1 + x | trait, K = K_permuted,
                                         name = "env", rho = 0.41)
    ),
    estimated = list(
      original = value ~ 1 + kernel_coef(1 + x || trait, K = fx$K,
                                          name = "env", rho = NULL),
      permuted = value ~ 1 + kernel_coef(1 + x || trait, K = K_permuted,
                                         name = "env", rho = NULL)
    )
  )
  for (pair in formulas) {
    original <- .fit_kernel_coef(fx, pair$original)
    permuted <- .fit_kernel_coef(fx, pair$permuted)
    expect_identical(permuted$tmb_data, original$tmb_data)
    expect_identical(.kernel_map_signature(permuted),
                     .kernel_map_signature(original))
    expect_identical(permuted$opt$objective, original$opt$objective)
    expect_identical(permuted$opt$par, original$opt$par)
  }
})

test_that("full kernel coefficient covariance recovers a small planted DGP", {
  set.seed(13250L)
  n_traits <- 5L
  n_unit <- 30L
  traits <- paste0("t", seq_len(n_traits))
  d <- seq(0.85, 1.15, length.out = n_traits)
  R <- 0.45^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  rho_truth <- 0.55
  K_rho <- rho_truth * K + (1 - rho_truth) * diag(diag(K))
  Sigma_truth <- matrix(c(0.20, 0.07, 0.07, 0.12), 2L, 2L)
  Z <- scale(matrix(stats::rnorm(n_traits * 2L), n_traits, 2L),
             center = TRUE, scale = FALSE)
  Z <- Z %*% solve(chol(stats::cov(Z)))
  B <- t(chol(K_rho)) %*% Z %*% chol(Sigma_truth)
  x <- seq(-1.5, 1.5, length.out = n_unit)
  wide <- data.frame(unit = factor(paste0("u", seq_len(n_unit))), x = x)
  for (j in seq_len(n_traits)) {
    wide[[traits[[j]]]] <- 0.25 + B[j, 1L] + B[j, 2L] * x +
      stats::rnorm(n_unit, sd = 0.025)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(traits), names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + kernel_coef(1 + x | trait, K = K, rho = rho_truth),
    data = long, trait = "trait", unit = "unit", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
  expect_lt(max(abs(unname(got$Sigma) - Sigma_truth)), 0.06)
  expect_gt(got$R[1L, 2L], 0.15)
  expect_lt(abs(unname(stats::coef(fit)[["(Intercept)"]]) - 0.25), 0.15)
})
