.temporal_dep_kernel_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$value <- with(data, as.numeric(factor(trait)) + .08 * occasion +
    c(s1 = -.2, s2 = .1, s3 = .25)[series] + c(m1 = -.03, m2 = .03)[measurement])
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = data, K = K)
}

.temporal_dep_kernel_unpack <- function(theta, n_trait) {
  out <- matrix(0, n_trait, n_trait)
  cursor <- 1L
  for (column in seq_len(n_trait)) {
    out[column, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) {
    for (row in (column + 1L):n_trait) {
      out[row, column] <- theta[[cursor]]
      cursor <- cursor + 1L
    }
  }
  stopifnot(cursor == length(theta) + 1L)
  out
}

.temporal_dep_kernel_dense_nll <- function(fit, fixed, K, product = FALSE) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  correlation <- ((1 - 1e-6) * tanh(par$theta_temporal_time))^
    abs(outer(pair$time, pair$time, `-`))
  correlation[outer(pair$series, pair$series, `!=`)] <- 0
  temporal <- tcrossprod(.temporal_dep_kernel_unpack(
    par$theta_temporal_rr, td$n_traits))
  kernel <- diag(par$theta_rr_phy, nrow = td$n_traits)
  kernel <- tcrossprod(kernel)
  V <- if (product) {
    correlation[state, state] * K[source, source] * temporal[trait, trait]
  } else {
    correlation[state, state] * temporal[trait, trait] +
      K[source, source] * kernel[trait, trait]
  }
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

test_that("replicated temporal_dep plus one labelled kernel_indep is admitted", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion, replicate = measurement) +
      kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_identical(fit$temporal$mode, "dep")
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$kernel_levels$name, "fixed_kernel")
})

test_that("replicated temporal_dep-kernel likelihood and gradients equal an independent additive oracle", {
  skip_if_not_installed("TMB")
  fx <- .temporal_dep_kernel_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + kernel_indep(series, K = fx$K, name = "fixed_kernel"),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  ))
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(.45 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_rr"] <- c(.55, .45, .5, .08, -.12, .1)
  fixed[names(fixed) == "theta_rr_phy"] <- c(.3, .4, .5)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.25)

  expect_equal(as.numeric(fit$tmb_obj$fn(fixed)),
    .temporal_dep_kernel_dense_nll(fit, fixed, fx$K), tolerance = 2e-6)
  expect_gt(abs(.temporal_dep_kernel_dense_nll(fit, fixed, fx$K) -
    .temporal_dep_kernel_dense_nll(fit, fixed, fx$K, product = TRUE)), 1e-3)
  for (index in c(match("theta_temporal_time", names(fixed)),
                  which(names(fixed) == "theta_temporal_rr")[[5L]],
                  which(names(fixed) == "theta_rr_phy")[[2L]])) {
    h <- 1e-5
    plus <- fixed; plus[[index]] <- plus[[index]] + h
    minus <- fixed; minus[[index]] <- minus[[index]] - h
    gradient <- (.temporal_dep_kernel_dense_nll(fit, plus, fx$K) -
      .temporal_dep_kernel_dense_nll(fit, minus, fx$K)) / (2 * h)
    expect_equal(fit$tmb_obj$gr(fixed)[[index]], gradient,
      tolerance = 3e-5, info = names(fixed)[[index]])
  }
})
