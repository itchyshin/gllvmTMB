## Coverage pins for global rank 7–9 R files (cursor/1127cov-gllvmTMB-w4).
## Tests only — fast unit paths, no package source edits.

# ---- R/profile-route-matrix.R -----------------------------------------------

test_that(".profile_abort_point_only_rho() names tier and optional parm", {
  expect_error(
  gllvmTMB:::.profile_abort_point_only_rho("cluster", parm = "psi_1"),
  regexp = "Profile correlation intervals are not available for psi_1"
  )
  expect_error(
    gllvmTMB:::.profile_abort_point_only_rho("cluster"),
    regexp = "cluster"
  )
})

test_that(".profile_nonlinear_release_gate() records the maintainer promotion fence", {
  gate <- gllvmTMB:::.profile_nonlinear_release_gate()
  expect_type(gate, "character")
  expect_match(gate, "constraint solver")
  expect_match(gate, "maintainer promotion")
})

test_that(".validate_profile_route_matrix() rejects malformed route tables", {
  routes <- gllvmTMB:::.profile_route_matrix()
  bad <- routes
  bad$status[1L] <- "not_a_status"
  expect_error(
    gllvmTMB:::.validate_profile_route_matrix(bad),
    regexp = "Invalid profile route status"
  )

  bad2 <- routes
  bad2$level[1L] <- "not_a_level"
  expect_error(
    gllvmTMB:::.validate_profile_route_matrix(bad2),
    regexp = "Invalid profile route level"
  )

  bad3 <- rbind(routes, routes[1L, , drop = FALSE])
  expect_error(
    gllvmTMB:::.validate_profile_route_matrix(bad3),
    regexp = "Duplicate profile route keys"
  )
})

test_that(".validate_profile_augmented_target_table() rejects bad split keys", {
  targets <- gllvmTMB:::.profile_augmented_target_table()
  bad <- targets
  bad$level[1L] <- "not_split"
  expect_error(
    gllvmTMB:::.validate_profile_augmented_target_table(bad),
    regexp = "Invalid augmented target level"
  )
})

test_that(".profile_route_status() errors when the lookup is ambiguous", {
  routes <- gllvmTMB:::.profile_route_matrix()
  hit <- routes[
    routes$estimand == "Sigma" &
      routes$level == "unit" &
      routes$method == "profile",
    ,
    drop = FALSE
  ]
  routes_dup <- rbind(routes, hit)
  expect_error(
    gllvmTMB:::.profile_route_status("Sigma", "unit", routes = routes_dup),
    regexp = "Expected one profile route"
  )
})

# ---- R/plot-gllvmTMB.R ------------------------------------------------------

make_small_plot_fit <- function(seed = 1L) {
  set.seed(seed)
  Tn <- 4L
  Lambda_B <- matrix(c(1.0, 0.5, -0.4, 0.3, 0.0, 0.8, 0.4, -0.2), Tn, 2)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 20L,
    n_species = 4L,
    n_traits = Tn,
    mean_species_per_site = 3L,
    Lambda_B = Lambda_B,
    psi_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W,
    psi_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site) +
      latent(0 + trait | site_species, d = 1) +
      unique(0 + trait | site_species),
    data = s$data
  )))
}

test_that("plot.gllvmTMB_multi collapses legacy level aliases with canonical names", {
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  fit <- make_small_plot_fit()
  p <- suppressMessages(plot(
    fit,
    type = "loadings",
    level = c("unit", "B")
  ))
  expect_s3_class(p, "ggplot")
})

test_that("plot.gllvmTMB_multi errors when ggplot2 is absent", {
  local_mocked_bindings(
    requireNamespace = function(pkg, quietly = TRUE) {
      if (identical(pkg, "ggplot2")) {
        return(FALSE)
      }
      base::requireNamespace(pkg, quietly = quietly)
    },
    .package = "base"
  )
  fit <- structure(list(mspl = FALSE), class = "gllvmTMB_multi")
  expect_error(
    plot(fit, type = "correlation"),
    regexp = "Install ggplot2"
  )
})

# ---- R/methods-gllvmTMB.R --------------------------------------------------

test_that(".covstruct_label() maps engine slots to printed keywords", {
  expect_equal(gllvmTMB:::.covstruct_label("rr_B"), "latent_unit")
  expect_equal(
    gllvmTMB:::.covstruct_label("diag_species", cluster_col = "population"),
    "indep_population"
  )
  expect_equal(gllvmTMB:::.covstruct_label("custom_flag"), "custom_flag")
})

test_that(".resolve_covstruct_labels() respects phylo_unique and spatial_latent", {
  use <- list(
    rr_B = TRUE,
    diag_B = TRUE,
    phylo_rr = TRUE,
    phylo_unique = TRUE,
    spde = FALSE,
    spatial_latent = FALSE
  )
  labs <- gllvmTMB:::.resolve_covstruct_labels(use, cluster_col = "species")
  expect_false("indep_unit" %in% labs)
  expect_true("latent_unit" %in% labs)
  expect_true("phylo_indep" %in% labs)

  use2 <- list(
    rr_B = FALSE,
    diag_B = FALSE,
    phylo_rr = FALSE,
    spde = TRUE,
    spatial_latent = TRUE
  )
  labs2 <- gllvmTMB:::.resolve_covstruct_labels(use2)
  expect_equal(unname(labs2), "spatial_latent")
})

test_that(".gllvmTMB_wald_unusable_reason() names sdreport and Hessian failures", {
  no_sdr <- list(sd_report = NULL)
  expect_equal(gllvmTMB:::.gllvmTMB_wald_unusable_reason(no_sdr), "sdreport_unavailable")
  bad_hess <- list(sd_report = list(pdHess = FALSE))
  expect_equal(
    gllvmTMB:::.gllvmTMB_wald_unusable_reason(bad_hess),
    "non_positive_definite_hessian"
  )
  ok <- list(sd_report = list(pdHess = TRUE))
  expect_null(gllvmTMB:::.gllvmTMB_wald_unusable_reason(ok))
})

test_that(".gllvmTMB_b_fix_table() returns an empty frame when there are no fixed names", {
  fit <- list(
    X_fix_names = character(0),
    tmb_obj = list(env = list(last.par.best = numeric(0))),
    sd_report = list(pdHess = TRUE)
  )
  tab <- gllvmTMB:::.gllvmTMB_b_fix_table(fit)
  expect_s3_class(tab, "data.frame")
  expect_identical(nrow(tab), 0L)
  expect_true(all(c("term", "Estimate", "Std.Err") %in% names(tab)))
})