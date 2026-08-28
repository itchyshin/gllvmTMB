## IID response-column coefficients.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula term | DGP draw | Engine object | Truth |
## |--------|--------------|----------|---------------|-------|
## | B[,1] | column_coef(1 + x | trait) | response-column intercept deviation | b_phy_aug[,1,1] | Sigma_coef[1,1] |
## | B[,2] | column_coef(1 + x | trait) | response-column slope deviation | b_phy_aug[,2,1] | Sigma_coef[2,2] |
## | Cov(B[,1], B[,2]) | single bar | same IID matrix-normal draw | Sigma_b_dep[1,2] | Sigma_coef[1,2] |
##
## With trait-major b = vec(B^T), the contract is
## Cov(b) = I_trait %x% Sigma_coef and eta[o] gains z[o,] B[trait[o],].

.make_iid_column_coef_fixture <- function(
    seed = 13101L, n_traits = 5L, n_unit = 12L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- stats::rnorm(nrow(data))
  data$z <- stats::rnorm(nrow(data))
  data$value <- 0.2 + stats::rnorm(nrow(data), sd = 0.45)
  list(data = data, traits = traits)
}

.fit_iid_column_coef <- function(fx, formula) {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}

.iid_free_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) {
    if (is.null(x)) NULL else as.integer(x)
  })
}

test_that("IID column_coef reaches the existing matrix-normal engine", {
  fx <- .make_iid_column_coef_fixture()
  fit <- .fit_iid_column_coef(
    fx, value ~ 1 + column_coef(1 + x | trait)
  )

  expect_identical(fit$tmb_data$use_phylo_column_slope, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)
  expect_identical(fit$tmb_data$n_aug_phy_slope, length(fx$traits))
  expect_equal(
    unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
    diag(length(fx$traits))
  )
  expect_identical(
    fit$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$trait) - 1L
  )
  expect_equal(
    fit$tmb_data$Z_phy_aug[, , 1L],
    cbind(`(Intercept)` = 1, x = fx$data$x),
    ignore_attr = TRUE
  )
  expect_true(isTRUE(fit$use$response_column_coef))
  expect_identical(fit$use$response_column_coef_basis, c("(Intercept)", "x"))
  expect_identical(dim(fit$report$Sigma_b_dep), c(2L, 2L))
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
})

test_that("phylo and animal coefficients are public while later helpers remain fenced", {
  fx <- .make_iid_column_coef_fixture()
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)

  phylo_fit <- .fit_iid_column_coef(
    fx,
    value ~ 1 + phylo_coef(0 + x | trait, vcv = K, rho = 1)
  )
  expect_true(isTRUE(phylo_fit$use$response_column_coef))
  expect_identical(phylo_fit$use$response_column_coef_source, "phylo")

  animal_fit <- .fit_iid_column_coef(
    fx,
    value ~ 1 + animal_coef(0 + x | trait, A = K, rho = 1)
  )
  expect_true(isTRUE(animal_fit$use$response_column_coef))
  expect_identical(animal_fit$use$response_column_coef_source, "animal")

  formulas <- list(
    value ~ 1 + kernel_coef(0 + x | trait, K = K, rho = 1),
    value ~ 1 + spatial_coef(0 + x | trait, mesh = K, rho = 1)
  )
  for (formula in formulas) {
    expect_error(
      .fit_iid_column_coef(fx, formula),
      class = "gllvmTMB_column_coef_engine_not_admitted"
    )
  }
})

test_that("IID coefficients fail clearly outside the admitted Gaussian regime", {
  fx <- .make_iid_column_coef_fixture()
  fx$data$value <- stats::rpois(nrow(fx$data), lambda = 2)
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 1 + column_coef(1 + x | trait),
      data = fx$data,
      trait = "trait",
      unit = "unit",
      family = stats::poisson(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
      silent = TRUE
    )),
    "Response-column coefficients are currently available for Gaussian responses only",
    fixed = TRUE
  )
})

test_that("no-intercept IID coefficients are exactly slope-equivalent for both bars", {
  fx <- .make_iid_column_coef_fixture(seed = 13102L, n_traits = 5L, n_unit = 18L)
  expect_no_warning(
    slope_full <- .fit_iid_column_coef(
      fx, value ~ 0 + trait + slope(x + z | trait)
    )
  )
  expect_no_warning(
    coef_full <- .fit_iid_column_coef(
      fx, value ~ 0 + trait + column_coef(0 + x + z | trait)
    )
  )
  expect_no_warning(
    slope_diagonal <- .fit_iid_column_coef(
      fx, value ~ 0 + trait + slope(x + z || trait)
    )
  )
  expect_no_warning(
    coef_diagonal <- .fit_iid_column_coef(
      fx, value ~ 0 + trait + column_coef(0 + x + z || trait)
    )
  )

  for (pair in list(
    list(coef = coef_full, slope = slope_full),
    list(coef = coef_diagonal, slope = slope_diagonal)
  )) {
    expect_identical(names(pair$coef$opt$par), names(pair$slope$opt$par))
    expect_identical(.iid_free_map_signature(pair$coef),
                     .iid_free_map_signature(pair$slope))
    expect_identical(pair$coef$tmb_data, pair$slope$tmb_data)
    expect_identical(pair$coef$opt$objective, pair$slope$opt$objective)
    expect_identical(pair$coef$opt$par, pair$slope$opt$par)
    expect_identical(pair$coef$report$Sigma_b_dep,
                     pair$slope$report$Sigma_b_dep)
    expect_identical(
      suppressMessages(stats::fitted(pair$coef)),
      suppressMessages(stats::fitted(pair$slope))
    )
  }
})

test_that("double-bar IID coefficients pin the coefficient covariance diagonal", {
  fx <- .make_iid_column_coef_fixture(seed = 13103L, n_traits = 8L, n_unit = 18L)
  full <- .fit_iid_column_coef(
    fx, value ~ 1 + column_coef(1 + x | trait)
  )
  diagonal <- .fit_iid_column_coef(
    fx, value ~ 1 + column_coef(1 + x || trait)
  )

  Sigma_full <- as.matrix(full$report$Sigma_b_dep)
  Sigma_diagonal <- as.matrix(diagonal$report$Sigma_b_dep)
  expect_true(all(eigen(Sigma_full, symmetric = TRUE, only.values = TRUE)$values > 0))
  expect_true(all(eigen(Sigma_diagonal, symmetric = TRUE, only.values = TRUE)$values > 0))
  expect_equal(Sigma_diagonal[1L, 2L], 0, tolerance = 0)
  map <- diagonal$tmb_obj$env$map$theta_dep_chol
  expect_true(is.na(as.integer(map)[3L]))
  full_map <- full$tmb_obj$env$map$theta_dep_chol
  expect_true(is.null(full_map) || !is.na(as.integer(full_map)[3L]))
})

test_that("wide and long IID coefficient routes are fit-identical", {
  skip_if_not_installed("tidyr")
  set.seed(13104L)
  traits <- paste0("t", 1:4)
  wide <- data.frame(unit = factor(paste0("u", 1:14)))
  wide$x <- stats::rnorm(nrow(wide))
  for (trait_name in traits) {
    wide[[trait_name]] <- 0.2 + stats::rnorm(nrow(wide), sd = 0.45)
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(traits),
    names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  rownames(long) <- NULL

  long_fit <- .fit_iid_column_coef(
    list(data = long),
    value ~ 0 + trait + column_coef(0 + x | trait)
  )
  wide_fit <- suppressMessages(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3, t4) ~ 1 + column_coef(0 + x | trait),
    data = wide,
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))

  expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
  expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
  expect_identical(wide_fit$opt$par, long_fit$opt$par)
  expect_identical(wide_fit$report$Sigma_b_dep,
                   long_fit$report$Sigma_b_dep)
  expect_identical(
    suppressMessages(stats::fitted(wide_fit)),
    suppressMessages(stats::fitted(long_fit))
  )
})

test_that("IID intercept-slope coefficients recover a known covariance", {
  set.seed(13105L)
  n_traits <- 24L
  n_unit <- 36L
  traits <- paste0("t", seq_len(n_traits))
  Sigma_true <- matrix(
    c(0.36, 0.09, 0.09, 0.16), 2L, 2L,
    dimnames = list(c("(Intercept)", "x"), c("(Intercept)", "x"))
  )
  ## Whiten the finite response-column draw so its realised sample covariance
  ## is exactly I before applying the planted Cholesky factor. This keeps the
  ## recovery gate about the fitted engine rather than an unlucky 24-row draw.
  Z <- scale(
    matrix(stats::rnorm(n_traits * 2L), n_traits, 2L),
    center = TRUE, scale = FALSE
  )
  Z <- Z %*% solve(chol(stats::cov(Z)))
  B <- Z %*% chol(Sigma_true)
  expect_equal(stats::cov(B), Sigma_true, tolerance = 1e-12)
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- stats::rnorm(nrow(data))
  trait_id <- as.integer(data$trait)
  data$value <- 0.35 + B[trait_id, 1L] + B[trait_id, 2L] * data$x +
    stats::rnorm(nrow(data), sd = 0.18)

  fit <- .fit_iid_column_coef(
    list(data = data),
    value ~ 1 + column_coef(1 + x | trait)
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))

  truth_par <- fit$opt$par
  L_true <- t(chol(Sigma_true))
  truth_par[names(truth_par) == "b_fix"] <- 0.35
  truth_par[names(truth_par) == "theta_dep_chol"] <-
    c(log(diag(L_true)), L_true[2L, 1L])
  truth_par[names(truth_par) == "log_sigma_eps"] <- log(0.18)
  expect_true(all(is.finite(fit$tmb_obj$gr(truth_par))))

  Sigma_hat <- as.matrix(fit$report$Sigma_b_dep)
  dimnames(Sigma_hat) <- dimnames(Sigma_true)
  expect_lt(max(abs(Sigma_hat - Sigma_true)), 0.14)
  expect_true(all(eigen(Sigma_hat, symmetric = TRUE, only.values = TRUE)$values > 0))
})
