## Condition classes raised by wide traits(cbind()) input checks and by
## extract_correlations() argument checks. Each class is the contract that
## callers can catch on, so each is pinned here by class, not only by message.
## Refs the untested-by-class audit; test-only, no change to R/ or src/.

.cc_data <- function(n = 20L) {
  set.seed(3L)
  data.frame(
    id = factor(seq_len(n)),
    s1 = rbinom(n, 8L, 0.4), f1 = rbinom(n, 8L, 0.6),
    s2 = rbinom(n, 8L, 0.5), f2 = rbinom(n, 8L, 0.5),
    mass = rnorm(n),
    lab = rep(c("a", "b"), length.out = n),
    stringsAsFactors = FALSE
  )
}
.cc_rewrite <- function(lhs_formula, data) {
  gllvmTMB:::rewrite_traits_lhs(lhs_formula, data = data)
}

## ---- traits(cbind()) evaluation failures ---------------------------------

test_that("cbind argument that errors on evaluation raises traits_cbind_eval", {
  d <- .cc_data()
  err <- expect_error(
    .cc_rewrite(traits(cbind(s1, no_such_col), cbind(s2, f2)) ~ 1 +
                  latent(1 | id, d = 1), d),
    class = "gllvmTMB_traits_cbind_eval"
  )
  expect_match(conditionMessage(err), "could not evaluate")
  expect_match(conditionMessage(err), "no_such_col")
})

test_that("non-numeric cbind argument raises traits_cbind_eval", {
  d <- .cc_data()
  err <- expect_error(
    .cc_rewrite(traits(cbind(s1, lab), cbind(s2, f2)) ~ 1 +
                  latent(1 | id, d = 1), d),
    class = "gllvmTMB_traits_cbind_eval"
  )
  expect_match(conditionMessage(err), "numeric column")
})

test_that("cbind argument of the wrong length raises traits_cbind_eval", {
  d <- .cc_data()
  err <- expect_error(
    .cc_rewrite(traits(cbind(s1, 1), cbind(s2, f2)) ~ 1 +
                  latent(1 | id, d = 1), d),
    class = "gllvmTMB_traits_cbind_eval"
  )
  expect_match(conditionMessage(err), "one value per row")
})

test_that("non-numeric extra trait column beside cbind pairs raises traits_cbind_eval", {
  d <- .cc_data()
  err <- expect_error(
    .cc_rewrite(traits(cbind(s1, f1), lab) ~ 1 + latent(1 | id, d = 1), d),
    class = "gllvmTMB_traits_cbind_eval"
  )
  expect_match(conditionMessage(err), "must be numeric")
  expect_match(conditionMessage(err), "lab")
})

## ---- negative counts ------------------------------------------------------

test_that("negative success or failure counts raise traits_cbind_negative", {
  d <- .cc_data()
  d$s1[4L] <- -1
  err <- expect_error(
    .cc_rewrite(traits(cbind(s1, f1), cbind(s2, f2)) ~ 1 +
                  latent(1 | id, d = 1), d),
    class = "gllvmTMB_traits_cbind_negative"
  )
  expect_match(conditionMessage(err), "non-negative")
  expect_match(conditionMessage(err), "s1")
  expect_match(paste(err$body, collapse = " "), "s > trials")

  ## A negative failure count from cbind(s, trials - s) with s > trials.
  d2 <- .cc_data()
  d2$trials <- 5L
  d2$s1[2L] <- 9L
  err2 <- expect_error(
    .cc_rewrite(traits(cbind(s1, trials - s1), cbind(s2, f2)) ~ 1 +
                  latent(1 | id, d = 1), d2),
    class = "gllvmTMB_traits_cbind_negative"
  )
  expect_match(conditionMessage(err2), "s1")
  expect_false(grepl("s2", conditionMessage(err2)))
})

test_that("exclusion selection beside cbind pairs raises traits_cbind_negative_selection", {
  d <- .cc_data()
  for (f in list(
    quote(traits(cbind(s1, f1), -id) ~ 1 + latent(1 | id, d = 1)),
    quote(traits(cbind(s1, f1), !id) ~ 1 + latent(1 | id, d = 1))
  )) {
    err <- expect_error(.cc_rewrite(eval(f), d),
                        class = "gllvmTMB_traits_cbind_negative_selection")
    expect_match(conditionMessage(err), "positive column selections")
  }
})

## ---- extract_correlations() pair validation -------------------------------

.cc_fit <- local({
  fit <- NULL
  function() {
    if (is.null(fit)) {
      set.seed(42L)
      s <- gllvmTMB::simulate_site_trait(
        n_sites = 80L, n_species = 6L, n_traits = 3L,
        mean_species_per_site = 4L,
        Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
        psi_B = c(0.40, 0.30, 0.50),
        psi_W = c(0.30, 0.40, 0.30),
        beta = matrix(0, 3L, 2L), seed = 42L
      )
      fit <<- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        value ~ 0 + trait +
          latent(0 + trait | site, d = 1) +
          unique(0 + trait | site) +
          unique(0 + trait | site_species),
        data = s$data, silent = TRUE
      )))
    }
    fit
  }
})

test_that("invalid numeric pair raises correlation_invalid_pair (TMB path)", {
  skip_on_cran()
  fit <- .cc_fit()
  for (pair in list(c(NA_real_, 2), c(1.5, 2), c(0, 2), c(1, 4), c(2, 2))) {
    expect_error(
      gllvmTMB::extract_correlations(fit, tier = "unit", pair = pair),
      class = "gllvmTMB_correlation_invalid_pair"
    )
  }
  ## A valid index pair still works.
  expect_no_error(suppressMessages(
    gllvmTMB::extract_correlations(fit, tier = "unit", pair = c(1, 2))
  ))
})

test_that("invalid numeric pair raises correlation_invalid_pair (Julia point path)", {
  helper <- gllvmTMB:::.extract_correlations_julia_point
  env <- new.env(parent = environment(helper))
  env$extract_Sigma <- function(...) {
    list(R = matrix(c(1, .3, .3, 1), 2L, dimnames = list(c("a", "b"), c("a", "b"))))
  }
  environment(helper) <- env
  fit <- structure(list(), class = "gllvmTMB_multi")
  for (pair in list(c(NA_real_, 2), c(1.5, 2), c(0, 2), c(1, 3), c(2, 2))) {
    expect_error(helper(fit, tier = "B", pair = pair),
                 class = "gllvmTMB_correlation_invalid_pair")
  }
})

## ---- method = "wald" alias message ---------------------------------------

test_that("method = 'wald' informs once that it aliases 'fisher-z'", {
  skip_on_cran()
  fit <- .cc_fit()
  withr::local_options(list(gllvmTMB.warned_extract_correlations_wald_alias = NULL))
  expect_message(
    first <- gllvmTMB::extract_correlations(fit, tier = "unit", method = "wald"),
    class = "gllvmTMB_method_alias"
  )
  expect_true(isTRUE(getOption("gllvmTMB.warned_extract_correlations_wald_alias")))
  ## Second call: cached, so no alias message.
  msgs <- character()
  second <- withCallingHandlers(
    gllvmTMB::extract_correlations(fit, tier = "unit", method = "wald"),
    message = function(m) {
      if (inherits(m, "gllvmTMB_method_alias")) msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_length(msgs, 0L)
  ## The output method column keeps the user's label.
  expect_true(all(first$method == "wald"))
  expect_true(all(second$method == "wald"))
})
