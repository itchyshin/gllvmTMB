## #1791: predict(newdata) with every species/cluster level unseen must not
## claim phylo_rr/phylo_diag/propto/diag_species were re-added.

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

test_that("#1791 all-unseen species do not appear in the re-added message", {
  skip_on_cran()
  fit <- .fit_1791()
  nd <- fit$data[1, , drop = FALSE]
  nd$group <- "g9"
  nd$obs <- paste0("newobs_", nd$obs)

  msgs <- capture_messages(suppressWarnings(predict(fit, newdata = nd)))
  msg <- paste(msgs, collapse = " ")
  expect_false(grepl("phylo_rr|phylo_diag", msg))
  expect_equal(
    predict(fit, newdata = nd)$est,
    predict(fit, newdata = nd, re_form = ~0)$est
  )
})