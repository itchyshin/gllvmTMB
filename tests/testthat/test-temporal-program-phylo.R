.temporal_program_phylo_fixture <- function() {
  data <- expand.grid(
    series = paste0("p", 1:3), occasion = 1:3,
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data,
    as.numeric(factor(trait)) + 0.12 * occasion +
      c(p1 = -0.25, p2 = 0.05, p3 = 0.20)[series])
  A <- matrix(c(
    1.0, 0.45, 0.20,
    0.45, 1.0, 0.30,
    0.20, 0.30, 1.0
  ), 3L, 3L, byrow = TRUE,
  dimnames = list(paste0("p", 1:3), paste0("p", 1:3)))
  list(data = data, A = A)
}

.temporal_program_phylo_dense_nll <- function(fit, fixed, A) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  phylo_level <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  same_series <- outer(pair$series, pair$series, FUN = "==")
  lag <- abs(outer(pair$time, pair$time, "-"))
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  temporal_correlation <- phi^lag
  temporal_correlation[!same_series] <- 0
  temporal_variance <- exp(2 * par$theta_temporal_diag)
  phylo_loading <- diag(par$theta_rr_phy, nrow = length(temporal_variance))
  covariance <-
    temporal_correlation[state, state] *
      diag(temporal_variance)[trait, trait] +
    A[phylo_level, phylo_level] *
      tcrossprod(phylo_loading)[trait, trait]
  diag(covariance) <- diag(covariance) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  chol_covariance <- chol(covariance)
  0.5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(chol_covariance))) +
    sum(backsolve(chol_covariance, residual, transpose = TRUE)^2))
}

test_that("one temporal source combines additively with phylo_indep", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_phylo_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      phylo_indep(0 + trait | series, vcv = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_true(isTRUE(fit$use$phylo_rr))
})

test_that("temporal plus phylo_indep matches an independent dense likelihood", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_phylo_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      phylo_indep(0 + trait | series, vcv = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(0.08, -0.10, 0.18)
  fixed[names(fixed) == "theta_temporal_time"] <-
    atanh(-0.45 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(0.32, 0.42, 0.52))
  fixed[names(fixed) == "theta_rr_phy"] <- c(0.20, 0.35, 0.50)
  fixed[names(fixed) == "log_sigma_eps"] <- log(0.28)

  expect_equal(
    as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_program_phylo_dense_nll(fit, fixed, fx$A),
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
      (.temporal_program_phylo_dense_nll(fit, plus, fx$A) -
       .temporal_program_phylo_dense_nll(fit, minus, fx$A)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], dense_gradient,
      tolerance = 2e-5, info = names(fixed)[[index]])
  }
})

test_that("the admitted temporal-phylo cell preserves long and wide identity", {
  testthat::skip_if_not_installed("TMB")
  fx <- .temporal_program_phylo_fixture()
  long_fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      phylo_indep(0 + trait | series, vcv = fx$A),
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
      phylo_indep(1 | series, vcv = fx$A),
    data = wide, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_equal(
    unname(as.matrix(extract_temporal(long_fit)$pair_index)),
    unname(as.matrix(extract_temporal(wide_fit)$pair_index))
  )
  expect_true(isTRUE(wide_fit$use$phylo_rr))
})

test_that("unvalidated temporal-plus-phylo cells remain refused", {
  fx <- .temporal_program_phylo_fixture()
  expect_error(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      phylo_dep(0 + trait | series, vcv = fx$A),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE
  ), "currently supports only.*phylo_indep")
})
