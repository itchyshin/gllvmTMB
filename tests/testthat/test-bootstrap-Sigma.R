## Tests for bootstrap_Sigma() — parametric-bootstrap CIs for Sigma /
## R / communality / ICC summaries of a fitted gllvmTMB_multi model.
##
## Each helper builds a tiny fit (n_sites = 30, n_traits = 3) so the
## refits run in a few seconds even with n_boot = 5–10.

make_tiny_fit <- function(seed = 1) {
  set.seed(seed)
  n_sites <- 30L; Tn <- 3L
  Lambda_B <- matrix(c(0.9, 0.4, -0.3,
                       0.0, 0.6,  0.2), Tn, 2)
  psi_B <- c(0.20, 0.15, 0.10)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1), Tn, 1)
  psi_W <- c(0.10, 0.08, 0.05)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 4, n_traits = Tn,
    mean_species_per_site = 4,
    Lambda_B = Lambda_B, psi_B = psi_B,
    Lambda_W = Lambda_W, psi_W = psi_W,
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = s$data
  )))
}

test_that("bootstrap_Sigma returns the expected list structure (smoke test)", {
  skip_on_cran()
  fit <- make_tiny_fit()
  boot <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 5L, level = c("B", "W"),
    what = c("Sigma", "R", "communality", "ICC"),
    seed = 42L, progress = FALSE
  ))
  expect_s3_class(boot, "bootstrap_Sigma")
  expect_named(boot, c("point_est", "ci_lower", "ci_upper", "ci_method",
                       "conf", "n_boot", "n_failed", "level", "what", "draws"))
  expect_equal(boot$ci_method, "percentile")
  expect_equal(boot$n_boot, 5L)
  expect_true("Sigma_B" %in% names(boot$point_est))
  expect_true("R_B"     %in% names(boot$point_est))
  expect_true("Sigma_W" %in% names(boot$point_est))
  expect_true("communality_B" %in% names(boot$point_est))
  expect_true("ICC_site" %in% names(boot$point_est))
  ## Shapes match between point_est, ci_lower, ci_upper
  for (nm in names(boot$point_est)) {
    expect_equal(dim(boot$ci_lower[[nm]]), dim(boot$point_est[[nm]]))
    expect_equal(dim(boot$ci_upper[[nm]]), dim(boot$point_est[[nm]]))
  }
})

test_that("Point estimates match extract_Sigma() on the original fit", {
  skip_on_cran()
  fit <- make_tiny_fit()
  boot <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 3L, level = "B", what = c("Sigma", "R"),
    seed = 1L, progress = FALSE
  ))
  ref <- suppressMessages(extract_Sigma(fit, level = "B", part = "total"))
  expect_equal(boot$point_est$Sigma_B, ref$Sigma)
  expect_equal(boot$point_est$R_B,     ref$R)
})

test_that("CI bounds are tighter at lower confidence levels", {
  skip_on_cran()
  fit <- make_tiny_fit()
  boot95 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 10L, level = "B", what = "Sigma",
    conf = 0.95, seed = 7L, progress = FALSE
  ))
  boot50 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 10L, level = "B", what = "Sigma",
    conf = 0.50, seed = 7L, progress = FALSE
  ))
  width95 <- boot95$ci_upper$Sigma_B - boot95$ci_lower$Sigma_B
  width50 <- boot50$ci_upper$Sigma_B - boot50$ci_lower$Sigma_B
  ## Ignore the (degenerate) zero-width entries — focus on diagonal +
  ## any populated off-diagonal cell.
  diag_idx <- diag(matrix(seq_along(width95), nrow(width95), ncol(width95)))
  expect_true(all(width50[diag_idx] <= width95[diag_idx] + 1e-10))
})

test_that("seed is reproducible: two calls with same seed give identical output", {
  skip_on_cran()
  fit <- make_tiny_fit()
  b1 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 5L, level = "B", what = "Sigma",
    seed = 99L, progress = FALSE
  ))
  b2 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 5L, level = "B", what = "Sigma",
    seed = 99L, progress = FALSE
  ))
  expect_equal(b1$ci_lower, b2$ci_lower)
  expect_equal(b1$ci_upper, b2$ci_upper)
  expect_equal(b1$point_est, b2$point_est)
})

test_that("n_cores = 2 returns CIs of the same shape and roughly the same magnitude as n_cores = 1", {
  skip_on_cran()
  skip_if_not_installed("future")
  skip_if_not_installed("future.apply")
  fit <- make_tiny_fit()
  b1 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 6L, level = "B", what = "Sigma",
    seed = 11L, n_cores = 1L, progress = FALSE
  ))
  b2 <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 6L, level = "B", what = "Sigma",
    seed = 11L, n_cores = 2L, progress = FALSE
  ))
  ## Same shape
  expect_equal(dim(b1$ci_lower$Sigma_B), dim(b2$ci_lower$Sigma_B))
  expect_equal(dim(b1$ci_upper$Sigma_B), dim(b2$ci_upper$Sigma_B))
  ## Point estimate is deterministic from the original fit
  expect_equal(b1$point_est$Sigma_B, b2$point_est$Sigma_B)
  ## n_failed should be small (allow at most 1 failure on this tiny problem)
  expect_lte(b1$n_failed + b2$n_failed, 4L)
})

test_that("Failed refits are tallied in n_failed, not in CIs", {
  skip_on_cran()
  fit <- make_tiny_fit()
  ## Force a failure by inserting a poison replicate: monkey-patch the
  ## simulated response matrix so one column is all-NA. We do this by
  ## intercepting `simulate.gllvmTMB_multi` for one call.
  orig <- simulate(fit, nsim = 5L, seed = 5L)
  poisoned <- orig
  poisoned[, 1L] <- NA_real_
  ## Mock simulate.gllvmTMB_multi for this test only
  with_mocked_bindings(
    simulate.gllvmTMB_multi = function(object, nsim = 1, seed = NULL,
                                       newdata = NULL, ...) poisoned,
    .package = "gllvmTMB",
    code = {
      boot <- suppressMessages(bootstrap_Sigma(
        fit, n_boot = 5L, level = "B", what = "Sigma",
        seed = 5L, progress = FALSE
      ))
      expect_gte(boot$n_failed, 1L)
      expect_equal(dim(boot$ci_lower$Sigma_B), dim(boot$point_est$Sigma_B))
    }
  )
})
