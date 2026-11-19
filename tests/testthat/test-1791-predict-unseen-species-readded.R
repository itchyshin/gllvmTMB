## #1791: with every species level unseen, predict() must not claim phylo tiers
## were re-added when they contributed nothing.

.fit_1791 <- function() {
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

test_that("#1791 all-unseen species levels do not list phylo tiers as re-added", {
  fit <- .fit_1791()
  expect_true(isTRUE(fit$use$phylo_diag) || isTRUE(fit$use$phylo_rr))

  nd <- fit$data
  nd$group <- paste0("unseen_sp_", seq_len(nrow(nd)))

  msgs <- capture_messages(suppressWarnings(predict(fit, newdata = nd)))
  if (length(msgs)) {
    expect_false(any(grepl("phylo_rr", msgs, fixed = TRUE)))
    expect_false(any(grepl("phylo_diag", msgs, fixed = TRUE)))
  }

  nd_all_unseen <- fit$data[1, , drop = FALSE]
  nd_all_unseen$group <- "g9"
  nd_all_unseen$obs <- paste0("newobs_", nd_all_unseen$obs)
  p <- suppressMessages(predict(fit, newdata = nd_all_unseen))
  p0 <- predict(fit, newdata = nd_all_unseen, re_form = ~0)
  expect_equal(p$est, p0$est, tolerance = 1e-8)
})