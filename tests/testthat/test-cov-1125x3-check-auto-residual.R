.cov1125x3_small_poisson_fit <- function() {
  set.seed(11253)
  n <- 16L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rpois(n, 2)
  )
  gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE)
  )
}

test_that("check_auto_residual() returns ok for a coherent poisson fit", {
  fit <- .cov1125x3_small_poisson_fit()
  out <- check_auto_residual(fit)
  expect_equal(out$status, "ok")
  expect_length(out$messages, 0L)
})

test_that("check_auto_residual() is ok when family vectors are absent", {
  fit <- .cov1125x3_small_poisson_fit()
  fit$tmb_data$family_id_vec <- NULL
  fit$tmb_data$trait_id <- NULL
  out <- check_auto_residual(fit)
  expect_equal(out$status, "ok")
})

test_that("check_auto_residual() errors on within-trait family mixing", {
  fit <- structure(
    list(
      data = data.frame(trait = factor(c("a", "a", "b"))),
      trait_col = "trait",
      tmb_data = list(
        family_id_vec = c(1L, 2L, 1L),
        trait_id = c(0L, 0L, 1L)
      )
    ),
    class = "gllvmTMB_multi"
  )
  expect_error(
    check_auto_residual(fit),
    class = "gllvmTMB_auto_residual_incoherent"
  )
})

test_that("check_auto_residual() refuses non-multi objects", {
  expect_error(check_auto_residual(list()), "gllvmTMB")
})

test_that(".family_name_from_id() maps known engine ids", {
  nm <- gllvmTMB:::.family_name_from_id(c(0L, 1L, 14L, 20L))
  expect_equal(nm, c("gaussian", "binomial", "ordinal_probit", "ordinal_logit"))
})