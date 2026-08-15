spde_slope_gauge_tr_adapter_env <- function() {
  env <- new.env(parent = baseenv())
  for (path in c(
    "spde-slope-gauge-contract.R",
    "spde-slope-gauge-trust-region-contract.R",
    "spde-slope-gauge-trust-region-adapter.R"
  )) {
    source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", path), local = env)
  }
  env
}

spde_slope_gauge_tr_adapter_fixture <- function(contract, named_gradient = FALSE) {
  raw_order <- contract$spde_slope_gauge_raw_order()
  theta <- stats::setNames(seq(-0.8, 0.8, length.out = 22L), raw_order)
  theta[20:22] <- c(0.2, -0.1, 0.3)
  list(
    fn = function(raw_theta) structure(sum(raw_theta * raw_theta), logarithm = TRUE),
    gr = function(raw_theta) {
      value <- 2 * raw_theta
      if (named_gradient) stats::setNames(value, raw_order) else unname(value)
    },
    par = theta
  )
}

test_that("the adapter retains unnamed positional gradient evidence before naming", {
  contract <- spde_slope_gauge_tr_adapter_env()
  object <- spde_slope_gauge_tr_adapter_fixture(contract)
  adapter <- contract$spde_slope_gauge_trust_region_callback_adapter(
    object = object,
    object_id = 7L,
    dll_path = "/sealed/gllvmTMB.so",
    dll_md5 = "7797c4674e4758fca2da27151e5c2508",
    sdreport_fn = function(object, raw_theta) {
      raw_order <- contract$spde_slope_gauge_raw_order()
      covariance <- diag(22L)
      dimnames(covariance) <- list(raw_order, raw_order)
      list(par.fixed = stats::setNames(raw_theta, raw_order), cov.fixed = covariance, pdHess = TRUE)
    }
  )
  phi <- contract$spde_slope_gauge_phi_from_theta(object$par)
  result <- adapter$evaluate(phi)
  covariance <- adapter$covariance(result$raw_theta)
  audit <- adapter$audit()

  expect_identical(names(result$raw_theta), contract$spde_slope_gauge_raw_order())
  expect_identical(names(result$raw_gradient), contract$spde_slope_gauge_raw_order())
  expect_null(attributes(result$objective))
  expect_identical(covariance$par.fixed, result$raw_theta)
  expect_length(audit$objective, 1L)
  expect_length(audit$gradient, 1L)
  expect_length(audit$covariance, 1L)
  expect_null(audit$gradient[[1L]]$supplied_names)
  expect_identical(audit$gradient[[1L]]$raw_values, unname(result$raw_gradient))
  expect_identical(audit$gradient[[1L]]$named_gradient, result$raw_gradient)
  expect_identical(audit$gradient[[1L]]$object_id, 7L)
  expect_identical(audit$gradient[[1L]]$dll_md5, "7797c4674e4758fca2da27151e5c2508")
})

test_that("the adapter rejects a supplied noncanonical gradient order", {
  contract <- spde_slope_gauge_tr_adapter_env()
  object <- spde_slope_gauge_tr_adapter_fixture(contract, named_gradient = TRUE)
  original_gr <- object$gr
  object$gr <- function(raw_theta) {
    value <- original_gr(raw_theta)
    stats::setNames(value, rev(names(value)))
  }
  adapter <- contract$spde_slope_gauge_trust_region_callback_adapter(
    object, 1L, "/sealed/gllvmTMB.so", "7797c4674e4758fca2da27151e5c2508",
    function(object, raw_theta) list()
  )
  phi <- contract$spde_slope_gauge_phi_from_theta(object$par)

  expect_error(adapter$evaluate(phi), "noncanonical positional order")
})

test_that("the adapter cannot be created with unverified object order", {
  contract <- spde_slope_gauge_tr_adapter_env()
  object <- spde_slope_gauge_tr_adapter_fixture(contract)
  object$par <- unname(object$par)
  raw_order <- contract$spde_slope_gauge_raw_order()
  blocks <- c(rep("b_fix", 12L), rep("theta_diag_B", 3L), "log_kappa_spde",
    rep("theta_rr_spde_slope", 6L))

  bound <- contract$spde_slope_gauge_trust_region_bind_object_order(
    object, raw_order, blocks
  )
  expect_identical(names(bound$object$par), raw_order)
  expect_null(bound$mapping$supplied_names)
  expect_error(
    contract$spde_slope_gauge_trust_region_bind_object_order(
      object, rev(raw_order), blocks
    ),
    "sealed 22-coordinate order"
  )
  object$par <- stats::setNames(object$par, rev(raw_order))
  expect_error(
    contract$spde_slope_gauge_trust_region_bind_object_order(
      object, raw_order, blocks
    ),
    "noncanonical fixed-parameter order"
  )
})

test_that("a retained callback audit replays the exact callback sequence without an object", {
  contract <- spde_slope_gauge_tr_adapter_env()
  object <- spde_slope_gauge_tr_adapter_fixture(contract)
  adapter <- contract$spde_slope_gauge_trust_region_callback_adapter(
    object, 7L, "/sealed/gllvmTMB.so", "7797c4674e4758fca2da27151e5c2508",
    function(object, raw_theta) {
      raw_order <- contract$spde_slope_gauge_raw_order()
      covariance <- diag(22L)
      dimnames(covariance) <- list(raw_order, raw_order)
      list(par.fixed = stats::setNames(raw_theta, raw_order), cov.fixed = covariance, pdHess = TRUE)
    }
  )
  phi <- contract$spde_slope_gauge_phi_from_theta(object$par)
  first <- adapter$evaluate(phi)
  second <- adapter$evaluate(phi)
  covariance <- adapter$covariance(second$raw_theta)
  audit <- adapter$audit()
  replay <- contract$spde_slope_gauge_trust_region_callbacks_from_audit(
    audit, 7L, "/sealed/gllvmTMB.so", "7797c4674e4758fca2da27151e5c2508"
  )

  expect_identical(replay$evaluate(phi), first)
  expect_identical(replay$evaluate(phi), second)
  expect_identical(replay$covariance(second$raw_theta), covariance)
  expect_true(replay$complete())

  audit$gradient[[2L]]$call_index <- 99L
  tampered <- contract$spde_slope_gauge_trust_region_callbacks_from_audit(
    audit, 7L, "/sealed/gllvmTMB.so", "7797c4674e4758fca2da27151e5c2508"
  )
  tampered$evaluate(phi)
  expect_error(tampered$evaluate(phi), "retained callback audit")
})
