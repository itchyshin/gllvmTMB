.temporal_phylo_optimizer_qualification_fixture <- function() {
  data <- expand.grid(
    series = paste0("sp", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  beta <- c(t1 = .2, t2 = -.3, t3 = .1)
  data$value <- beta[data$trait] + .08 * data$occasion +
    c(sp1 = -.18, sp2 = .12, sp3 = .04, sp4 = .22)[data$series] +
    c(m1 = -.03, m2 = .03)[data$measurement]
  Cphy <- matrix(c(
    1, .55, .20, .10,
    .55, 1, .30, .15,
    .20, .30, 1, .40,
    .10, .15, .40, 1
  ), 4L, 4L, byrow = TRUE,
  dimnames = list(paste0("sp", 1:4), paste0("sp", 1:4)))
  list(data = data, Cphy = Cphy)
}

.temporal_phylo_optimizer_qualification_fit <- function(fx, diagnostics = TRUE) {
  control <- gllvmTMBcontrol(
    se = FALSE, optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
    optimizer_passes = 2L
  )
  ## Developer-only qualification hook: it changes no optimisation setting.
  control$optimizer_diagnostics <- isTRUE(diagnostics)
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement, structure = "ar1") +
      phylo_indep(0 + trait | series, vcv = fx$Cphy),
    data = fx$data, unit = "series", cluster = "series",
    family = gaussian(), silent = TRUE, control = control
  ))
}

test_that("optimizer qualification is observationally inert for the two-pass fit", {
  skip_if_not_installed("TMB")
  fx <- .temporal_phylo_optimizer_qualification_fixture()
  ordinary <- .temporal_phylo_optimizer_qualification_fit(fx, diagnostics = FALSE)
  qualified <- .temporal_phylo_optimizer_qualification_fit(fx, diagnostics = TRUE)
  expect_equal(qualified$opt$par, ordinary$opt$par, tolerance = 1e-10)
  expect_equal(qualified$opt$objective, ordinary$opt$objective, tolerance = 1e-10)
  expect_identical(qualified$optimizer_pass_history$accepted,
    ordinary$optimizer_pass_history$accepted)
})

test_that("temporal-phylo optimizer passes retain labelled qualification diagnostics", {
  skip_if_not_installed("TMB")
  fit <- .temporal_phylo_optimizer_qualification_fit(
    .temporal_phylo_optimizer_qualification_fixture()
  )
  history <- fit$optimizer_pass_history
  required <- c(
    "pass", "pass_label", "objective", "convergence", "accepted",
    "outer_gradient_max", "outer_gradient_coordinate",
    "finite_difference_max", "finite_difference_coordinate",
    "finite_difference_error_max", "finite_difference_error_coordinate",
    "finite_difference_n_coordinates", "finite_difference_n_finite",
    "finite_difference_all_finite", "fresh_state_ok", "fresh_objective",
    "fresh_objective_error", "inner_method", "inner_hessian_available",
    "inner_hessian_dimension", "inner_hessian_rcond", "inner_hessian_condition",
    "inner_hessian_message", "outer_hessian_available", "outer_hessian_message",
    "fn_evaluations", "gr_evaluations", "message",
    "warnings", "elapsed_seconds", "start", "end", "gradient", "fresh_gradient"
  )
  expect_true(all(required %in% names(history)),
    info = paste("missing:", paste(setdiff(required, names(history)), collapse = ", ")))
  expect_identical(history$pass, 1:2)
  expect_identical(history$pass_label, c("pass_1", "pass_2"))
  expect_true(all(is.finite(history$outer_gradient_max)))
  expect_true(all(nzchar(history$outer_gradient_coordinate)))
  expect_lt(max(history$finite_difference_error_max), 1e-4)
  expect_true(all(history$finite_difference_all_finite))
  expect_identical(history$finite_difference_n_coordinates,
    history$finite_difference_n_finite)
  expect_true(all(history$fresh_state_ok))
  expect_true(all(is.finite(history$fresh_objective)))
  expect_true(all(is.finite(history$fresh_objective_error)))
  expect_true(all(history$inner_hessian_available))
  expect_true(all(history$inner_hessian_dimension > 0L))
})

.temporal_phylo_optimizer_qualification_dense_nll <- function(fit, fixed, Cphy) {
  par <- fit$tmb_obj$env$parList(fixed)
  td <- fit$tmb_data
  state <- td$temporal_state_id + 1L
  trait <- td$trait_id + 1L
  source <- td$species_id + 1L
  pair <- fit$temporal$pair_table
  phi <- (1 - 1e-6) * tanh(par$theta_temporal_time)
  Ktime <- phi^abs(outer(pair$time, pair$time, `-`))
  Ktime[outer(pair$series, pair$series, `!=`)] <- 0
  temporal_var <- diag(exp(2 * par$theta_temporal_diag), td$n_traits)
  phylo_var <- diag(par$theta_rr_phy^2, td$n_traits)
  V <- Ktime[state, state] * temporal_var[trait, trait] +
    Cphy[source, source] * phylo_var[trait, trait]
  diag(V) <- diag(V) + exp(2 * par$log_sigma_eps[[1L]])
  residual <- td$y - drop(td$X_fix %*% par$b_fix)
  L <- chol(V)
  .5 * (length(residual) * log(2 * pi) +
    2 * sum(log(diag(L))) +
    sum(backsolve(L, residual, transpose = TRUE)^2))
}

.temporal_phylo_optimizer_qualification_labels <- function(par) {
  paste0(names(par), "[", ave(seq_along(par), names(par), FUN = seq_along), "]")
}

test_that("temporal-phylo qualification independently audits every outer coordinate", {
  skip_if_not_installed("TMB")
  fx <- .temporal_phylo_optimizer_qualification_fixture()
  fit <- .temporal_phylo_optimizer_qualification_fit(fx)
  fixed <- fit$opt$par
  fixed[names(fixed) == "b_fix"] <- c(.1, -.15, .2)
  fixed[names(fixed) == "log_sigma_eps"] <- log(.3)
  fixed[names(fixed) == "theta_temporal_time"] <- atanh(-.5 / (1 - 1e-6))
  fixed[names(fixed) == "theta_temporal_diag"] <- log(c(.35, .45, .55))
  fixed[names(fixed) == "theta_rr_phy"] <- c(.25, .4, .6)

  native <- as.numeric(fit$tmb_obj$fn(fixed))
  dense <- .temporal_phylo_optimizer_qualification_dense_nll(fit, fixed, fx$Cphy)
  expect_equal(native, dense, tolerance = 2e-6)

  h <- 1e-5
  central <- vapply(seq_along(fixed), function(i) {
    plus <- fixed; minus <- fixed
    plus[[i]] <- plus[[i]] + h
    minus[[i]] <- minus[[i]] - h
    (.temporal_phylo_optimizer_qualification_dense_nll(fit, plus, fx$Cphy) -
      .temporal_phylo_optimizer_qualification_dense_nll(fit, minus, fx$Cphy)) / (2 * h)
  }, numeric(1))
  native_gradient <- fit$tmb_obj$gr(fixed)
  labels <- .temporal_phylo_optimizer_qualification_labels(fixed)
  names(central) <- names(native_gradient) <- labels
  expect_length(central, 11L)
  expect_identical(labels, c(
    "b_fix[1]", "b_fix[2]", "b_fix[3]", "log_sigma_eps[1]",
    "theta_temporal_time[1]", "theta_temporal_diag[1]",
    "theta_temporal_diag[2]", "theta_temporal_diag[3]",
    "theta_rr_phy[1]", "theta_rr_phy[2]", "theta_rr_phy[3]"
  ))
  expect_equal(native_gradient, central, tolerance = 2e-5)
})

test_that("optimizer finite-difference audit fails closed on a missing coordinate", {
  par <- c(alpha = .2, beta = -.3)
  gradient <- c(alpha = .4, beta = -.6)
  quadratic <- function(x) sum(x^2)
  complete <- gllvmTMB:::.gllvmTMB_optimizer_finite_difference_audit(
    par, gradient, quadratic
  )
  expect_true(complete$all_finite)
  expect_identical(complete$n_coordinates, 2L)
  expect_identical(complete$n_finite, 2L)
  expect_equal(unname(complete$error), c(0, 0), tolerance = 1e-7)

  missing <- gllvmTMB:::.gllvmTMB_optimizer_finite_difference_audit(
    par, gradient, function(x) if (x[[2L]] > -.3) NA_real_ else quadratic(x)
  )
  expect_false(missing$all_finite)
  expect_lt(missing$n_finite, missing$n_coordinates)
  expect_true(is.na(missing$error_maximum))
})

source(testthat::test_path(
  "fixtures", "temporal-phylo-optimizer-qualification-controls.R"
))

test_that("qualification controls retain the failed campaign and localize an injected derivative fault", {
  controls <- .temporal_phylo_optimizer_qualification_controls()
  expect_true(.temporal_phylo_optimizer_qualification_validate_controls(controls))
  controls$retained_summary <- "DESCRIPTION"
  expect_false(.temporal_phylo_optimizer_qualification_validate_controls(controls))

  summary_path <- testthat::test_path("..", "..", "dev", "temporal-program", "results", "failed",
    "phylo-recovery-160-fir-59096255-20260910",
    "phylo-recovery-160-summary-20260909.csv")
  copied <- tempfile(fileext = ".csv")
  expect_true(file.copy(summary_path, copied, overwrite = TRUE))
  expect_true(.temporal_phylo_optimizer_qualification_validate_summary(
    copied, unname(tools::md5sum(copied))
  ))
  changed <- utils::read.csv(copied, check.names = FALSE)
  changed$strict_successes[[2L]] <- 10L
  utils::write.csv(changed, copied, row.names = FALSE)
  expect_false(.temporal_phylo_optimizer_qualification_validate_summary(
    copied, unname(tools::md5sum(summary_path))
  ))

  labels <- c("b_fix[1]", "theta_rr_phy[1]", "theta_rr_phy[2]")
  exact <- c(1, -.5, .25)
  numerical <- exact
  altered <- exact
  altered[[match("theta_rr_phy[2]", labels)]] <- altered[[match("theta_rr_phy[2]", labels)]] + .01
  err <- abs(altered - numerical)
  expect_gt(max(err), .temporal_phylo_optimizer_qualification_controls()$derivative_tolerance)
  expect_identical(labels[[which.max(err)]], .temporal_phylo_optimizer_qualification_controls()$injected_coordinate)
})
