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
  expect_equal(cluster_sigma$status, "planned")
  expect_equal(c2_sigma$status, "planned")

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

  for (lvl in split_levels) {
    sigma_route <- gllvmTMB:::.profile_route_status("Sigma", lvl, routes = routes)
    rho_route <- gllvmTMB:::.profile_route_status("rho", lvl, routes = routes)
    expect_equal(sigma_route$status, "blocked", label = lvl)
    expect_equal(rho_route$status, "blocked", label = lvl)
    expect_match(sigma_route$next_gate, "symbolic target", fixed = TRUE)
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
