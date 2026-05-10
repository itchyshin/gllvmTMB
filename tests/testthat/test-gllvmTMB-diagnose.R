## Tests for gllvmTMB_diagnose() — the user-facing one-call diagnostic

make_basic_fit <- function(n_ind = 80, seed = 42) {
  set.seed(seed)
  Tn <- 4
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  Y <- u %*% t(Lambda) + matrix(rnorm(n_ind * Tn, sd = sqrt(0.1)), n_ind, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b", "c", "d"), n_ind),
                        levels = c("a", "b", "c", "d")),
    value      = as.vector(t(Y))
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual"
  )))
}

test_that("gllvmTMB_diagnose returns the structured list", {
  fit <- make_basic_fit()
  res <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_type(res, "list")
  expect_named(res, c("sanity", "rotation", "Sigma_B", "Sigma_W",
                      "ICC_site", "communality_B", "communality_W", "hints"))
  expect_true(isTRUE(res$sanity$converged))
  expect_true(isTRUE(res$sanity$pd_hessian))
})

test_that("rotation advisory hint appears for unconstrained rr fit", {
  fit <- make_basic_fit()
  res <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_true(any(grepl("rotation", res$hints, ignore.case = TRUE)))
  expect_true(isTRUE(res$rotation$B))
})

test_that("rotation hint is silenced when lambda_constraint is supplied", {
  set.seed(42)
  Tn <- 4; n_ind <- 80
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  Y <- u %*% t(Lambda) + matrix(rnorm(n_ind * Tn, sd = sqrt(0.1)), n_ind, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b", "c", "d"), n_ind),
                        levels = c("a", "b", "c", "d")),
    value      = as.vector(t(Y))
  )
  cnst <- matrix(NA_real_, Tn, 2); diag(cnst) <- 1
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual",
    lambda_constraint = list(B = cnst)
  )))
  res <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_false(isTRUE(res$rotation$B))
  expect_false(any(grepl("rotation", res$hints, ignore.case = TRUE)))
})

test_that("verbose = TRUE produces output (printed via cli + cat)", {
  fit <- make_basic_fit()
  ## sanity_multi() uses cat() to stdout; cli messages go to stderr.
  ## Capture both streams.
  stdout_capture <- capture.output(
    msg_capture <- capture.output(
      gllvmTMB_diagnose(fit, verbose = TRUE),
      type = "message"
    )
  )
  expect_true(length(stdout_capture) + length(msg_capture) > 0)
})

test_that("non-fit input errors gracefully", {
  expect_error(gllvmTMB_diagnose(42), regexp = "gllvmTMB_multi")
})
