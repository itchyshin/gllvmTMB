# Tests for suggest_lambda_constraint(): produces a default rotational-fix
# matrix that users can pass to `gllvmTMB(..., lambda_constraint = ...)`.
#
# Implementation: R/suggest-lambda-constraint.R

test_that("lower_triangular for T = 5, K = 2 pins the upper triangle to 0", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:5), 4)),
    site = factor(rep(paste0("s", 1:4), each = 5)),
    value = rnorm(20)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d
  )
  M <- res$constraint
  expect_equal(dim(M), c(5L, 2L))
  expect_equal(M[1, 2], 0) # upper triangle pinned
  expect_true(is.na(M[2, 1])) # strict lower triangle free
  expect_true(is.na(M[1, 1])) # diagonal free
  expect_true(is.na(M[2, 2])) # diagonal free
  expect_equal(res$n_pins, 1L) # K(K-1)/2 = 1
  expect_equal(res$d, 2L)
  expect_equal(rownames(M), paste0("t", 1:5))
  expect_equal(colnames(M), c("f1", "f2"))
  expect_match(res$usage_hint, "lambda_constraint = list\\(unit =")
})

test_that("lower_triangular for T = 4, K = 3 pins K(K-1)/2 = 3 entries", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 5)),
    site = factor(rep(paste0("s", 1:5), each = 4)),
    value = rnorm(20)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 3),
    data = d
  )
  M <- res$constraint
  expect_equal(dim(M), c(4L, 3L))
  expect_equal(res$n_pins, 3L)
  expect_equal(M[1, 2], 0)
  expect_equal(M[1, 3], 0)
  expect_equal(M[2, 3], 0)
  expect_true(is.na(M[2, 1]))
  expect_true(is.na(M[3, 1]))
  expect_true(is.na(M[3, 3]))
  # Total pins = number of zeros = 3
  expect_equal(sum(!is.na(M) & M == 0), 3L)
})

test_that("K = 1 returns an all-NA matrix with explanatory note", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:3), 4)),
    site = factor(rep(paste0("s", 1:4), each = 3)),
    value = rnorm(12)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = d
  )
  expect_equal(dim(res$constraint), c(3L, 1L))
  expect_true(all(is.na(res$constraint)))
  expect_equal(res$n_pins, 0L)
  expect_match(res$note, "K = 1")
})

test_that("convention = 'pin_top_one' returns M[1, 1] = 1 and rest NA", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    convention = "pin_top_one"
  )
  expect_equal(res$constraint[1, 1], 1)
  expect_equal(sum(!is.na(res$constraint)), 1L)
  expect_equal(res$n_pins, 1L)
  expect_equal(res$convention, "pin_top_one")
})

test_that("convention = 'none' returns an all-NA matrix", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  res <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    convention = "none"
  )
  expect_true(all(is.na(res$constraint)))
  expect_equal(res$n_pins, 0L)
})

test_that("K > T errors", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:2), 4)),
    site = factor(rep(paste0("s", 1:4), each = 2)),
    value = rnorm(8)
  )
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | site, d = 3),
      data = d
    ),
    "exceeds number of traits"
  )
})

test_that("level = 'unit_obs' on a formula without a within-unit latent() term errors", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = d,
      level = "unit_obs"
    ),
    "no .*latent.*term"
  )
})

test_that("wrong object errors name the gllvmTMB constructor", {
  expect_error(
    suggest_lambda_constraint(list()),
    regexp = "fit returned by .*gllvmTMB"
  )
})

test_that("suggest_lambda_constraints() compares several conventions", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:4), 4)),
    site = factor(rep(paste0("s", 1:4), each = 4)),
    value = rnorm(16)
  )
  res <- suggest_lambda_constraints(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    methods = c("none", "pin_top_one", "lower_triangular")
  )

  expect_s3_class(res, "gllvmTMB_lambda_constraint_suggestions")
  expect_named(
    res,
    c(
      "summary",
      "suggestions",
      "recommended_method",
      "recommended"
    )
  )
  expect_equal(
    res$summary$method,
    c("none", "pin_top_one", "lower_triangular")
  )
  expect_equal(res$summary$n_pins, c(0L, 1L, 1L))
  expect_equal(res$summary$n_free, c(8L, 7L, 7L))
  expect_equal(res$recommended_method, "lower_triangular")
  expect_equal(
    res$recommended$constraint,
    res$suggestions$lower_triangular$constraint
  )
})

test_that("suggest_lambda_constraints() rejects unsupported methods", {
  d <- data.frame(
    trait = factor(rep(paste0("t", 1:3), 4)),
    site = factor(rep(paste0("s", 1:4), each = 3)),
    value = rnorm(12)
  )
  expect_error(
    suggest_lambda_constraints(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = d,
      methods = "banana"
    ),
    "unsupported"
  )
})

test_that("profile_retention refits emit no unused-argument or alias notes (#1587)", {
  skip_on_cran()
  set.seed(1587)
  n_s <- 60
  n_t <- 6
  L <- matrix(
    c(.9, .7, .5, .1, 0, 0, 0, .3, .6, .8, .7, .5),
    n_t,
    2
  )
  Y <- matrix(rnorm(n_s * 2), n_s, 2) %*% t(L) +
    matrix(rnorm(n_s * n_t, sd = .5), n_s, n_t)
  d <- data.frame(
    site = factor(rep(seq_len(n_s), each = n_t)),
    trait = factor(rep(paste0("t", 1:n_t), n_s), levels = paste0("t", 1:n_t)),
    value = as.vector(t(Y))
  )
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = d,
    trait = "trait",
    unit = "site",
    silent = TRUE
  )))
  ## The one-shot alias notes would otherwise be spent by earlier tests.
  for (k in c("rr", "diag")) {
    suppressWarnings(rm(list = k, envir = gllvmTMB:::.gllvmTMB_deprecation_seen))
  }
  msgs <- character()
  expect_no_warning(
    res <- withCallingHandlers(
      suggest_lambda_constraint(fit, convention = "profile_retention"),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
  )
  expect_false(any(grepl("deprecated alias", msgs)))
  expect_equal(dim(res$constraint), c(n_t, 2L))
  ## Equality with the result of the pre-fix route (rr() + diag() refits):
  ## t4-t6 are pinned in f1; every other entry stays free. An all-NA matrix
  ## means the refits errored and were skipped silently, so guard that too.
  expected <- matrix(NA_real_, n_t, 2L, dimnames = dimnames(res$constraint))
  expected[4:6, 1L] <- 0
  expect_true(any(res$constraint == 0, na.rm = TRUE))
  expect_equal(res$constraint, expected)
  ## Since #1585 the free entries of the pinned-diagonal axis start off zero,
  ## so the two refits that used to be skipped now converge: all 11 are tested.
  expect_match(res$note, "Tested 11 entries; 0 skipped", fixed = TRUE)
})

test_that("formula path names the within-unit column via unit_obs and the level as written (#1587)", {
  set.seed(1)
  sim <- simulate_unit_trait(
    n_units = 100, n_obs_per_unit = 2, n_traits = 6,
    Lambda_B = cbind(c(.9, .8, .7, 0, 0, 0), c(0, 0, 0, .8, .7, .6)),
    psi_B = .3, sigma2_eps = .3
  )
  form2 <- value ~ 0 + trait +
    latent(0 + trait | unit, d = 1, unique = FALSE) +
    latent(0 + trait | unit_observation, d = 2, unique = FALSE)

  res <- suggest_lambda_constraint(
    form2, data = sim$data, unit = "unit",
    unit_obs = "unit_observation", level = "unit_obs"
  )
  expect_equal(dim(res$constraint), c(6L, 2L))
  expect_equal(res$d, 2L)

  ## The wrapper forwards unit_obs too.
  cmp <- suggest_lambda_constraints(
    form2, data = sim$data, unit = "unit",
    unit_obs = "unit_observation", level = "unit_obs",
    methods = "lower_triangular"
  )
  expect_equal(cmp$suggestions$lower_triangular$constraint, res$constraint)

  ## No-term errors name the level as the user wrote it, not "W" / "B".
  expect_error(
    suggest_lambda_constraint(form2, data = sim$data, unit = "unit",
                              level = "unit_obs"),
    'nothing to constrain at level "unit_obs"'
  )
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | unit_observation, d = 2),
      data = sim$data, unit = "unit", level = "unit"
    ),
    'nothing to constrain at level "unit"'
  )
})
