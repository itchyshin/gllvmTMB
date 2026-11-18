## Symbolic alignment lives in LOOP/animal-coef-alignment.md.

test_that("animal_coef fixed rho uses the raw-scale covariance mixture", {
  fx <- .make_animal_coef_fixture(seed = 13144L)
  rho <- 0.37
  expect_no_warning(fit <- .fit_animal_coef_test(
    fx,
    value ~ 1 + animal_coef(1 + x || trait, A = fx$A, rho = rho)
  ))

  K_rho <- rho * fx$A + (1 - rho) * diag(diag(fx$A))
  expect_equal(
    unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
    unname(solve(K_rho)),
    tolerance = 1e-12
  )
  ext <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(ext$source$type, "animal")
  expect_identical(ext$rho_status, "fixed")
  expect_identical(ext$rho, rho)
  expect_equal(ext$K_rho, K_rho, tolerance = 1e-12)
  expect_identical(ext$basis, c("(Intercept)", "x"))
  expect_equal(ext$Sigma[1L, 2L], 0, tolerance = 0)
})

test_that("pedigree A and Ainv agree for an interior fixed rho", {
  fx <- .make_animal_coef_pedigree_fixture(seed = 13149L)
  rho <- 0.41
  formulas <- list(
    value ~ 1 + animal_coef(1 + x | trait, pedigree = fx$pedigree, rho = rho),
    value ~ 1 + animal_coef(1 + x | trait, A = fx$A, rho = rho),
    value ~ 1 + animal_coef(1 + x | trait, Ainv = fx$Ainv, rho = rho)
  )
  fits <- lapply(formulas, function(formula) {
    expect_no_warning(.fit_animal_coef_test(fx, formula))
  })
  expected <- rho * fx$A + (1 - rho) * diag(diag(fx$A))

  for (fit in fits) {
    ext <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
    expect_equal(ext$K_rho, expected, tolerance = 1e-10)
    expect_equal(
      unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
      unname(solve(expected)),
      tolerance = 1e-10
    )
  }
  expect_equal(fits[[1L]]$opt$objective, fits[[2L]]$opt$objective, tolerance = 1e-8)
  expect_equal(fits[[2L]]$opt$objective, fits[[3L]]$opt$objective, tolerance = 1e-8)
})

test_that("animal_coef recovers a planted intercept-slope covariance", {
  set.seed(13147L)
  n_traits <- 24L
  n_unit <- 32L
  traits <- paste0("t", seq_len(n_traits))
  rho <- 0.55
  Sigma_true <- matrix(
    c(0.25, 0.06, 0.06, 0.16), 2L, 2L,
    dimnames = list(c("(Intercept)", "x"), c("(Intercept)", "x"))
  )
  d <- seq(0.7, 1.3, length.out = n_traits)
  R <- 0.3^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  A <- outer(d, d) * R
  dimnames(A) <- list(traits, traits)
  K_rho <- rho * A + (1 - rho) * diag(diag(A))
  Z <- matrix(stats::rnorm(n_traits * 2L), n_traits, 2L)
  B <- t(chol(K_rho)) %*% Z %*% chol(Sigma_true)

  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  x_unit <- as.numeric(scale(seq_len(n_unit)))
  data$x <- x_unit[as.integer(data$unit)]
  ti <- as.integer(data$trait)
  data$value <- 0.35 + B[ti, 1L] + B[ti, 2L] * data$x +
    stats::rnorm(nrow(data), sd = 0.15)

  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + animal_coef(1 + x | trait, A = A, rho = rho),
    data = data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
  ext <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_lt(max(abs(ext$Sigma - Sigma_true)), 0.13)
  expect_equal(ext$K_rho, K_rho, tolerance = 1e-12)
})
