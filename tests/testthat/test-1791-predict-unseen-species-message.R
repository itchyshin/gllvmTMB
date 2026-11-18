## #1791. With the species column present and every species level unseen,
## predict() still told the user that phylo_rr / phylo_diag had been re-added.
## The same all-out-of-range path listed propto, diag_species, rr_B and diag_B.

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

.msgs_1791 <- function(expr) {
  msgs <- character(0)
  withCallingHandlers(
    force(expr),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  msgs
}

test_that("#1791 an unseen species is not reported as a re-added phylogenetic tier", {
  fit <- .fit_1791()
  expect_true(isTRUE(fit$use$phylo_diag) || isTRUE(fit$use$phylo_rr))
  nd <- fit$data[1, , drop = FALSE]
  nd$group <- "g9"

  msgs <- .msgs_1791(p <- predict(fit, newdata = nd))
  readded <- msgs[grepl("re-added", msgs)]
  expect_length(readded, 1L)
  expect_false(grepl("phylo_", readded))
  expect_true(grepl("diag_B", readded))

  p0 <- predict(fit, newdata = nd, re_form = ~0)
  expect_true(all(is.finite(p$est)))
  expect_false(isTRUE(all.equal(p$est, p0$est)))
})

test_that("#1791 every grouping level unseen matches the fixed-effects prediction", {
  fit <- .fit_1791()
  nd <- fit$data[1, , drop = FALSE]
  nd$group <- "g9"
  nd$obs <- paste0("newobs_", nd$obs)

  msgs <- .msgs_1791(p <- predict(fit, newdata = nd))
  expect_false(any(grepl("re-added", msgs)))
  expect_equal(p$est, predict(fit, newdata = nd, re_form = ~0)$est)
})
