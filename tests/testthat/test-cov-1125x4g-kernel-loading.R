## Coverage (cursor-cloud-1125x4g): R/kernel-psi-sd-priors.R and R/loading-profile.R guards.

.cov1125x4g_gauss <- function() {
  set.seed(112543)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rnorm(n)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that(".gllvmTMB_resolve_kernel_psi_sd_prior() validates table shape", {
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_kernel_psi_sd_prior(
      data.frame(wrong = 1),
      kernel_names = "k1",
      kernel_has_psi = 1L,
      trait_names = c("a", "b"),
      multi_kernel = FALSE
    ),
    "kernel, trait, and scale"
  )
  tbl <- data.frame(kernel = "k1", trait = "a", scale = 0)
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_kernel_psi_sd_prior(
      tbl, kernel_names = "k1", kernel_has_psi = 1L,
      trait_names = c("a", "b"), multi_kernel = FALSE
    ),
    "finite positive"
  )
})

test_that(".gllvmTMB_resolve_kernel_psi_sd_prior() rejects unknown targets", {
  tbl <- data.frame(kernel = "missing", trait = "a", scale = 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_kernel_psi_sd_prior(
      tbl, kernel_names = "k1", kernel_has_psi = 1L,
      trait_names = c("a", "b"), multi_kernel = FALSE
    ),
    class = "gllvmTMB_kernel_psi_prior_target_unknown"
  )
})

test_that(".gllvmTMB_kernel_psi_sd_prior_route() refuses MSPL engine", {
  pri <- data.frame(kernel = "k1", trait = "a", scale = 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_kernel_psi_sd_prior_route(
      pri, engine = "tmb", estimator = "mspl", REML = FALSE,
      control = gllvmTMBcontrol()
    ),
    class = "gllvmTMB_kernel_psi_prior_unsupported"
  )
})

test_that("loading_profile() refuses wrong object class", {
  expect_error(loading_profile(list()), "multi-trait")
})

test_that("loading_profile() errors on bad entry matrix", {
  fit <- .cov1125x4g_gauss()
  expect_error(loading_profile(fit, entries = c(1, 2, 3)), "2-column")
})

test_that("loading_profile() rejects legacy level B with deprecation", {
  fit <- .cov1125x4g_gauss()
  withr::local_options(list(lifecycle_verbosity = "quiet"))
  expect_warning(
    pf <- loading_profile(fit, level = "B", entries = matrix(c(1L, 1L), ncol = 2L), n_grid = 3L),
    class = "lifecycle_warning_deprecated"
  )
  expect_s3_class(pf, "profile_loadings")
  expect_gt(nrow(pf), 0L)
})