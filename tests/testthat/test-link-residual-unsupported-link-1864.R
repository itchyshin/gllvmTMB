## Twin of GLLVModels.jl #1233 / gllvmTMB #1864: unsupported links must error
## in link_residual_per_trait() instead of returning NA or assuming logit/log.

.make_mock_fit_link <- function(family_id, link_id, trait = "y", n_rows = 6L) {
  list(
    trait_col = "trait",
    data = data.frame(
      trait = factor(rep(trait, n_rows), levels = trait)
    ),
    tmb_data = list(
      family_id_vec = rep(family_id, n_rows),
      link_id_vec   = rep(link_id, n_rows),
      trait_id      = rep(0L, n_rows)
    ),
    report = list(
      eta = rep(0, n_rows),
      phi_beta = 5,
      phi_betabinom = 5
    )
  )
}

test_that("link_residual_per_trait() refuses an unknown binomial link (#1864)", {
  fit <- .make_mock_fit_link(family_id = 1L, link_id = 99L)
  err <- expect_error(
    gllvmTMB:::link_residual_per_trait(fit),
    class = "gllvmTMB_link_residual_unsupported_link"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "Binomial", fixed = TRUE)
  expect_match(msg, "link", fixed = TRUE)
})

test_that("link_residual_per_trait() refuses Poisson off the log link (#1864)", {
  fit <- .make_mock_fit_link(family_id = 2L, link_id = 1L)
  err <- expect_error(
    gllvmTMB:::link_residual_per_trait(fit),
    class = "gllvmTMB_link_residual_unsupported_link"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "Poisson", fixed = TRUE)
  expect_match(msg, "probit", fixed = TRUE)
})

test_that("link_residual_per_trait() refuses Beta off the logit link (#1864)", {
  fit <- .make_mock_fit_link(family_id = 7L, link_id = 1L)
  err <- expect_error(
    gllvmTMB:::link_residual_per_trait(fit),
    class = "gllvmTMB_link_residual_unsupported_link"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "Beta", fixed = TRUE)
  expect_match(msg, "probit", fixed = TRUE)
})

test_that("supported binomial and logit Beta links are unchanged (#1864)", {
  fit_bin <- .make_mock_fit_link(family_id = 1L, link_id = 0L)
  expect_equal(
    unname(gllvmTMB:::link_residual_per_trait(fit_bin)),
    pi^2 / 3,
    tolerance = 0
  )
  fit_beta <- .make_mock_fit_link(family_id = 7L, link_id = 0L)
  res <- gllvmTMB:::link_residual_per_trait(fit_beta)
  expect_true(is.finite(res) && res > 0)
})