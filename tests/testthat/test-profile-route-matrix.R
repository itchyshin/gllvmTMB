test_that("profile route levels cover peer, source, and augmented split tiers", {
  levels <- gllvmTMB:::.profile_route_levels()

  expect_s3_class(levels, "data.frame")
  expect_equal(anyDuplicated(levels$level), 0L)
  expect_true(all(c(
    "unit", "unit_obs", "cluster", "cluster2", "phy", "spatial"
  ) %in% levels$level))
  expect_true(all(c(
    "unit_slope", "phy_unique_slope", "phy_dep", "phy_slope",
    "spde_base_slope", "spde_dep", "spde_slope"
  ) %in% levels$level))
})

test_that("profile route matrix has controlled keys and statuses", {
  routes <- gllvmTMB:::.profile_route_matrix()

  expect_s3_class(routes, "data.frame")
  expect_true(all(c(
    "estimand", "level", "method", "status", "route",
    "validation_row", "claim", "next_gate"
  ) %in% names(routes)))
  expect_equal(
    anyDuplicated(paste(routes$estimand, routes$level, routes$method)),
    0L
  )
  expect_true(all(routes$status %in% c(
    "covered", "partial", "fallback", "planned",
    "blocked", "point_only", "not_applicable"
  )))
  expect_no_error(gllvmTMB:::.validate_profile_route_matrix(routes))
})

test_that("profile route matrix records current cluster and cluster2 boundaries", {
  routes <- gllvmTMB:::.profile_route_matrix()

  cluster_sd <- gllvmTMB:::.profile_route_status("direct_sd", "cluster", routes = routes)
  c2_sd <- gllvmTMB:::.profile_route_status("direct_sd", "cluster2", routes = routes)
  expect_equal(cluster_sd$status, "covered")
  expect_equal(c2_sd$status, "covered")
  expect_match(cluster_sd$route, "theta_diag_species")
  expect_match(c2_sd$route, "theta_diag_cluster2")

  cluster_sigma <- gllvmTMB:::.profile_route_status("Sigma", "cluster", routes = routes)
  c2_sigma <- gllvmTMB:::.profile_route_status("Sigma", "cluster2", routes = routes)
  expect_equal(cluster_sigma$status, "partial")
  expect_equal(c2_sigma$status, "partial")
  expect_match(cluster_sigma$route, "theta_diag_species")
  expect_match(c2_sigma$route, "theta_diag_cluster2")

  cluster_rho <- gllvmTMB:::.profile_route_status("rho", "cluster", routes = routes)
  c2_rho <- gllvmTMB:::.profile_route_status("rho", "cluster2", routes = routes)
  expect_equal(cluster_rho$status, "point_only")
  expect_equal(c2_rho$status, "point_only")
})

test_that("profile route matrix keeps augmented split profile routes blocked", {
  routes <- gllvmTMB:::.profile_route_matrix()
  split_levels <- c(
    "unit_slope", "phy_unique_slope", "phy_dep", "phy_slope",
    "spde_base_slope", "spde_dep", "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")

  for (lvl in split_levels) {
    for (estimand in split_estimands) {
      route <- gllvmTMB:::.profile_route_status(estimand, lvl, routes = routes)
      expect_equal(route$status, "blocked", label = paste(estimand, lvl))
      expect_match(route$next_gate, "symbolic target", fixed = TRUE)
    }
  }
})

test_that("profile_targets exposes cluster and cluster2 direct SD aliases", {
  fake <- structure(
    list(
      opt = list(
        par = c(
          theta_diag_species = log(0.4),
          theta_diag_species = log(0.5),
          theta_diag_cluster2 = log(0.6),
          theta_diag_cluster2 = log(0.7)
        )
      ),
      tmb_obj = NULL
    ),
    class = "gllvmTMB_multi"
  )

  targets <- gllvmTMB::profile_targets(fake)
  expect_true(all(c(
    "sd_cluster[1]", "sd_cluster[2]",
    "sd_cluster2[1]", "sd_cluster2[2]"
  ) %in% targets$parm))
  expect_true(all(c(
    "sd_phy_unique[1]", "sd_phy_unique[2]"
  ) %in% targets$parm))
  direct <- targets[targets$parm %in% c("sd_cluster[1]", "sd_cluster2[1]"), ]
  expect_equal(direct$profile_note, rep("tmb_object_required", 2L))
})

test_that("sigma parm metadata includes diagonal cluster matrix tokens", {
  tokens <- gllvmTMB:::.sigma_parm_tokens()
  expect_true(all(c("Sigma_cluster", "Sigma_cluster2") %in% tokens))

  cluster <- gllvmTMB:::.sigma_parm_info("Sigma_cluster")
  expect_equal(cluster$display, "Sigma_cluster")
  expect_equal(cluster$level, "cluster")
  expect_equal(cluster$internal, "cluster")
  expect_equal(cluster$diag_param, "theta_diag_species")
  expect_equal(cluster$diag_flag, "diag_species")
  expect_null(cluster$rr_flag)

  cluster2 <- gllvmTMB:::.sigma_parm_info("Sigma_cluster2")
  expect_equal(cluster2$display, "Sigma_cluster2")
  expect_equal(cluster2$level, "cluster2")
  expect_equal(cluster2$internal, "cluster2")
  expect_equal(cluster2$diag_param, "theta_diag_cluster2")
  expect_equal(cluster2$diag_flag, "diag_cluster2")
  expect_null(cluster2$rr_flag)
})

test_that("Sigma_cluster and Sigma_cluster2 routes use diagonal-only interval blocks", {
  fake_fit <- structure(
    list(
      use = list(
        diag_species = TRUE,
        diag_cluster2 = TRUE
      ),
      opt = list(
        par = c(
          theta_diag_species = log(0.4),
          theta_diag_species = log(0.5),
          theta_diag_cluster2 = log(0.6),
          theta_diag_cluster2 = log(0.7)
        )
      ),
      sd_report = list(
        cov.fixed = diag(c(0.01, 0.04, 0.01, 0.04))
      )
    ),
    class = "gllvmTMB_multi"
  )
  sigma_cluster <- diag(c(0.16, 0.25))
  dimnames(sigma_cluster) <- list(c("a", "b"), c("a", "b"))

  testthat::local_mocked_bindings(
    extract_Sigma = function(object, level, part, link_residual, ...) {
      expect_true(level %in% c("cluster", "cluster2"))
      expect_equal(part, "total")
      expect_equal(link_residual, "none")
      list(Sigma = sigma_cluster)
    },
    .tmbprofile_block = function(object, parameter, level, transform, ...) {
      expect_true(parameter %in% c(
        "theta_diag_species", "theta_diag_cluster2"
      ))
      data.frame(
        parameter = paste0(parameter, "[", 1:2, "]"),
        estimate = c(0.16, 0.25),
        lower = c(0.08, 0.12),
        upper = c(0.40, 0.55),
        method = "profile"
      )
    },
    .package = "gllvmTMB"
  )

  ci_cluster <- gllvmTMB:::.confint_sigma_profile(
    fake_fit,
    parm = "Sigma_cluster",
    level = 0.95,
    nsim = 10L,
    seed = 1L
  )
  ci_cluster2 <- gllvmTMB:::.confint_sigma_profile(
    fake_fit,
    parm = "Sigma_cluster2",
    level = 0.95,
    nsim = 10L,
    seed = 1L
  )

  expect_equal(ci_cluster$parameter, c(
    "Sigma_cluster[a,a]",
    "Sigma_cluster[a,b]",
    "Sigma_cluster[b,b]"
  ))
  expect_equal(ci_cluster$estimate, c(0.16, 0, 0.25))
  expect_equal(ci_cluster$lower, c(0.08, 0, 0.12))
  expect_equal(ci_cluster$upper, c(0.40, 0, 0.55))
  expect_true(all(ci_cluster$method == "profile"))

  expect_equal(ci_cluster2$parameter, c(
    "Sigma_cluster2[a,a]",
    "Sigma_cluster2[a,b]",
    "Sigma_cluster2[b,b]"
  ))

  ci_wald <- gllvmTMB:::.confint_sigma_wald(
    fake_fit,
    parm = "Sigma_cluster",
    level = 0.95
  )
  expect_equal(ci_wald$parameter, ci_cluster$parameter)
  expect_true(all(is.finite(ci_wald$lower[c(1L, 3L)])))
  expect_true(all(is.na(ci_wald$lower[2L])))
  expect_error(
    gllvmTMB:::.confint_sigma_bootstrap(
      fake_fit,
      parm = "Sigma_cluster",
      level = 0.95,
      nsim = 5L,
      seed = 1L
    ),
    "not wired for diagonal cluster Sigma tiers"
  )
})
