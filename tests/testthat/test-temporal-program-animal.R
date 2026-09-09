.temporal_program_animal_fixture <- function() {
  data <- expand.grid(
    series = paste0("a", 1:3), occasion = 1:3,
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + 0.11 * occasion +
      c(a1 = -0.20, a2 = 0.04, a3 = 0.16)[series])
  A <- matrix(c(
    1.0, 0.40, 0.18,
    0.40, 1.0, 0.28,
    0.18, 0.28, 1.0
  ), 3L, 3L, byrow = TRUE,
  dimnames = list(paste0("a", 1:3), paste0("a", 1:3)))
  list(data = data, A = A)
}

.temporal_program_animal_dense_nll <- function(fit, fixed, A) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  animal_level <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, FUN = "==")
  lag <- abs(outer(pair$time, pair$time, "-"))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_correlation <- phi^lag
  temporal_correlation[!same_series] <- 0
  temporal_variance <- exp(2 * par$theta_temporal_diag)
  animal_loading <- diag(par$theta_rr_phy, nrow = length(temporal_variance))
  covariance <-
    temporal_correlation[state, state] *
      diag(temporal_variance)[trait, trait] +
    A[animal_level, animal_level] *
      tcrossprod(animal_loading)[trait, trait]
  diag(covariance) <- diag(covariance) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  chol_covariance <- chol(covariance)
  0.5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(chol_covariance))) +
    sum(backsolve(chol_covariance, residual, transpose = TRUE)^2))
}

test_that("one temporal source combines additively with animal_indep", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_animal_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      animal_indep(0 + trait | series, A = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_true(isTRUE(fit$use$phylo_rr))
})

test_that("temporal plus animal_indep matches an independent dense likelihood", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_animal_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      animal_indep(0 + trait | series, A = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(0.07, -0.09, 0.16)
  fixed[names(fixed) == "theta_temporal_time"] <-
    atanh(0.40 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(0.30, 0.40, 0.50))
  fixed[names(fixed) == "theta_rr_phy"] <- c(0.22, 0.34, 0.48)
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.27)

  expect_equal(
    as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_program_animal_dense_nll(fit, fixed, fx$A),
    tolerance = 2e-6
  )
  for (index in c(
    match("theta_temporal_time", names(fixed)),
    which(names(fixed) == "theta_rr_phy")[[2L]]
  )) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    dense_gradient <-
      (.temporal_program_animal_dense_nll(fit, plus, fx$A) -
       .temporal_program_animal_dense_nll(fit, minus, fx$A)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], dense_gradient,
      tolerance = 2e-5, info = names(fixed)[[index]])
  }
})

test_that("the admitted temporal-animal cell preserves long, wide, and update identity", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_animal_fixture()
  long_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      animal_indep(0 + trait | series, A = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  wide <- unique(fx$data[c("series", "occasion")])
  for (trait_name in paste0("t", 1:3)) {
    wide[[sub("t", "y", trait_name)]] <-
      fx$data$value[fx$data$trait == trait_name]
  }
  wide_fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 +
      temporal_indep(1 | series, time = occasion) +
      animal_indep(1 | series, A = fx$A),
    data = wide, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  updated <- suppressWarnings(update(long_fit))

  expect_equal(
    unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index))
  )
  expect_true(isTRUE(wide_fit$use$phylo_rr))
  expect_s3_class(updated, "gllvmTMB_multi")
  expect_true(isTRUE(updated$temporal$active))
})

test_that("unvalidated temporal-plus-animal cells remain refused", {
  fx <- .temporal_program_animal_fixture()
  expect_error(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      animal_dep(0 + trait | series, A = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE
  ), "currently supports only.*animal_indep")
})
