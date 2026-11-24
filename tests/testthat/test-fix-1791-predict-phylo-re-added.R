## #1791: all-unseen species levels must not claim phylo tiers were re-added.

test_that("all-unseen species levels omit phylo tiers from the re-added message (#1791)", {
  fit <- local({
    fx <- .rho_fixed_fixture(3L)
    suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
      y ~ 0 + trait +
        phylo_indep(0 + trait | group, A = fx$K, rho = 0.35) +
        indep(0 + trait | obs),
      data = fx$data, trait = "trait", unit = "obs", cluster = "group",
      family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(
        se = FALSE, n_init = 1L, laplace_auto_refit = FALSE
      ),
      silent = TRUE
    )))
  })
  nd <- fit$data[1, , drop = FALSE]
  nd$group <- "g9"
  nd$obs <- paste0("newobs_", nd$obs)

  msg <- paste(capture_messages(suppressMessages(predict(fit, newdata = nd))),
               collapse = " ")
  expect_false(grepl("phylo_rr", msg, fixed = TRUE))
  expect_false(grepl("phylo_diag", msg, fixed = TRUE))
  expect_equal(
    predict(fit, newdata = nd, re_form = ~0)$est,
    suppressMessages(predict(fit, newdata = nd))$est
  )
})