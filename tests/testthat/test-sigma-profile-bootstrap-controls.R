## Regression coverage for issue #606:
## profile-on-Sigma fallback to bootstrap must preserve caller controls.

make_sigma_profile_control_fit <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80L,
    n_species = 6L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B = c(0.40, 0.30, 0.50),
    psi_W = c(0.30, 0.40, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site) +
      unique(0 + trait | site_species),
    data = s$data,
    silent = TRUE
  )))
}

test_that("Profile-to-bootstrap Sigma fallback forwards nsim and seed", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_sigma_profile_control_fit()
  seen <- new.env(parent = emptyenv())

  with_mocked_bindings(
    bootstrap_Sigma = function(fit,
                               n_boot,
                               level,
                               what,
                               conf,
                               seed = NULL,
                               progress = TRUE,
                               ...) {
      seen$n_boot <- n_boot
      seen$seed <- seed
      mat <- diag(3L)
      dimnames(mat) <- list(paste0("trait_", 1:3), paste0("trait_", 1:3))
      structure(
        list(
          point_est = list(Sigma_B = mat),
          ci_lower = list(Sigma_B = mat * 0.5),
          ci_upper = list(Sigma_B = mat * 1.5)
        ),
        class = "bootstrap_Sigma"
      )
    },
    .package = "gllvmTMB",
    code = {
      ci <- suppressMessages(confint(
        fit,
        parm = "Sigma_unit",
        method = "profile",
        nsim = 7L,
        seed = 123L
      ))
    }
  )

  expect_s3_class(ci, "data.frame")
  expect_equal(seen$n_boot, 7L)
  expect_equal(seen$seed, 123L)
  expect_true(all(ci$method == "bootstrap"))
})
