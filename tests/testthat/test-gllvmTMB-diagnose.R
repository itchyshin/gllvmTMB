## Tests for gllvmTMB_diagnose() — the user-facing one-call diagnostic

make_basic_fit <- function(n_ind = 80, seed = 42) {
  set.seed(seed)
  Tn <- 4
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  Y <- u %*% t(Lambda) + matrix(rnorm(n_ind * Tn, sd = sqrt(0.1)), n_ind, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(
      rep(c("a", "b", "c", "d"), n_ind),
      levels = c("a", "b", "c", "d")
    ),
    value = as.vector(t(Y))
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2, unique = FALSE),
    data = df,
    site = "individual"
  )))
}

test_that("gllvmTMB_diagnose returns the structured list", {
  fit <- make_basic_fit()
  res <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_type(res, "list")
  expect_named(
    res,
    c(
      "sanity",
      "rotation",
      "Sigma_B",
      "Sigma_W",
      "ICC_site",
      "communality_B",
      "communality_W",
      "hints"
    )
  )
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
  Tn <- 4
  n_ind <- 80
  Lambda <- matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), Tn, 2)
  u <- matrix(rnorm(n_ind * 2), n_ind, 2)
  Y <- u %*% t(Lambda) + matrix(rnorm(n_ind * Tn, sd = sqrt(0.1)), n_ind, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(
      rep(c("a", "b", "c", "d"), n_ind),
      levels = c("a", "b", "c", "d")
    ),
    value = as.vector(t(Y))
  )
  cnst <- matrix(NA_real_, Tn, 2)
  diag(cnst) <- 1
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2, unique = FALSE),
    data = df,
    site = "individual",
    lambda_constraint = list(unit = cnst)
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
  expect_error(
    gllvmTMB_diagnose(42),
    regexp = "fit returned by `gllvmTMB\\(\\)`"
  )
})

## Issue #1401: boundary and near-zero psi WARN rows from check_gllvmTMB() must
## surface in diagnose hints and block the unconditional healthy message.
test_that("gllvmTMB_diagnose respects check_gllvmTMB boundary and psi WARN rows (#1401)", {
  set.seed(2028)
  sim <- simulate_site_trait(
    n_sites = 40,
    n_species = 10,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.2, -0.4, 0.6), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2028
  )
  cnst <- matrix(NA_real_, 3, 2)
  diag(cnst) <- 1
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
    data = sim$data,
    lambda_constraint = list(unit = cnst)
  )))
  fit$report$sd_B[1L] <- 1e-8
  fit$fit_health <- NULL

  chk <- check_gllvmTMB(fit, psi_thresh = 1e-4, sigma_eps_thresh = 1e-4)
  expect_equal(chk$status[chk$component == "near_zero_psi_unit"], "WARN")
  expect_true(any(chk$component == "boundary_flags" & chk$status == "WARN"))

  res <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_true(length(res$hints) > 0)
  expect_true(
    any(grepl("near-boundary|psi|variance component", res$hints, ignore.case = TRUE))
  )

  msgs <- capture.output(
    suppressMessages(gllvmTMB_diagnose(fit, verbose = TRUE)),
    type = "message"
  )
  expect_false(any(grepl("Fit looks healthy", msgs, fixed = TRUE)))
})
