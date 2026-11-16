## #1787: predict(newdata) without the species column returned the fixed-effects
## prediction and still informed that phylo_rr and/or phylo_diag had been re-added.
## This test fails on main because that call succeeds.

.fit_1787 <- function() {
  fx <- .rho_fixed_fixture(3L)
  d <- fx$data
  suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait +
      phylo_indep(0 + trait | group, A = fx$K, rho = 0.35) +
      indep(0 + trait | obs),
    data = d, trait = "trait", unit = "obs", cluster = "group",
    family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE),
    silent = TRUE
  )))
}

test_that("#1787 predict() stops when newdata omits the species column", {
  fit <- .fit_1787()
  d <- fit$data
  expect_true(isTRUE(fit$use$phylo_diag) || isTRUE(fit$use$phylo_rr))
  nd_miss <- d[, c("trait", "obs", "y"), drop = FALSE]

  expect_error(
    predict(fit, newdata = nd_miss),
    regexp = "species column[[:print:][:space:]]*re_form",
    class = "gllvmTMB_predict_newdata_species_missing"
  )

  p0 <- predict(fit, newdata = nd_miss, re_form = ~0)
  p_fx <- predict(fit, newdata = d, re_form = ~0)
  expect_equal(p0$est, p_fx$est, tolerance = 1e-8)

  p_nd <- suppressMessages(predict(fit, newdata = d))
  expect_true(max(abs(p_nd$est - p_fx$est)) > 1e-6)
})

test_that("#1787 an unseen species level is not the missing-column error", {
  fit <- .fit_1787()
  nd_unseen <- fit$data[1, , drop = FALSE]
  nd_unseen$group <- "g9"
  # If obs stays seen, predict() correctly re-adds per-tier diag_B obs effects; only all-unseen matches re_form = ~0.
  nd_unseen$obs <- paste0("newobs_", nd_unseen$obs)
  p_unseen <- suppressMessages(predict(fit, newdata = nd_unseen))
  expect_equal(p_unseen$est, predict(fit, newdata = nd_unseen, re_form = ~0)$est)
})

test_that("#1787 species-only-unseen still applies other random-effect tiers", {
  fit <- .fit_1787()
  nd_species_unseen <- fit$data[1, , drop = FALSE]
  nd_species_unseen$group <- "g9"
  p <- suppressMessages(predict(fit, newdata = nd_species_unseen))
  p0 <- predict(fit, newdata = nd_species_unseen, re_form = ~0)
  expect_true(all(is.finite(p$est)))
  expect_false(isTRUE(all.equal(p$est, p0$est)))
})
