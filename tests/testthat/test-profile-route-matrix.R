test_that("profile route levels cover peer, source, and augmented split tiers", {
  levels <- gllvmTMB:::.profile_route_levels()

  expect_s3_class(levels, "data.frame")
  expect_equal(anyDuplicated(levels$level), 0L)
  expect_true(all(
    c(
      "unit",
      "unit_obs",
      "cluster",
      "cluster2",
      "phy",
      "spatial"
    ) %in%
      levels$level
  ))
  expect_true("kernel_named" %in% levels$level)
  expect_true(all(
    c(
      "unit_slope",
      "phy_unique_slope",
      "phy_dep",
      "phy_slope",
      "spde_base_slope",
      "spde_dep",
      "spde_slope"
    ) %in%
      levels$level
  ))
})

test_that("profile route matrix has controlled keys and statuses", {
  routes <- gllvmTMB:::.profile_route_matrix()

  expect_s3_class(routes, "data.frame")
  expect_true(all(
    c(
      "estimand",
      "level",
      "method",
      "status",
      "route",
      "validation_row",
      "claim",
      "next_gate"
    ) %in%
      names(routes)
  ))
  expect_equal(
    anyDuplicated(paste(routes$estimand, routes$level, routes$method)),
    0L
  )
  expect_true(all(
    routes$status %in%
      c(
        "covered",
        "partial",
        "fallback",
        "planned",
        "blocked",
        "point_only",
        "not_applicable"
      )
  ))
  expect_no_error(gllvmTMB:::.validate_profile_route_matrix(routes))
})

test_that("profile route matrix records current cluster and cluster2 boundaries", {
  routes <- gllvmTMB:::.profile_route_matrix()

  cluster_sd <- gllvmTMB:::.profile_route_status(
    "direct_sd",
    "cluster",
    routes = routes
  )
  c2_sd <- gllvmTMB:::.profile_route_status(
    "direct_sd",
    "cluster2",
    routes = routes
  )
  expect_equal(cluster_sd$status, "covered")
  expect_equal(c2_sd$status, "covered")
  expect_match(cluster_sd$route, "theta_diag_species")
  expect_match(c2_sd$route, "theta_diag_cluster2")

  cluster_sigma <- gllvmTMB:::.profile_route_status(
    "Sigma",
    "cluster",
    routes = routes
  )
  c2_sigma <- gllvmTMB:::.profile_route_status(
    "Sigma",
    "cluster2",
    routes = routes
  )
  expect_equal(cluster_sigma$status, "partial")
  expect_equal(c2_sigma$status, "partial")
  expect_match(cluster_sigma$route, "theta_diag_species")
  expect_match(c2_sigma$route, "theta_diag_cluster2")

  cluster_rho <- gllvmTMB:::.profile_route_status(
    "rho",
    "cluster",
    routes = routes
  )
  c2_rho <- gllvmTMB:::.profile_route_status("rho", "cluster2", routes = routes)
  expect_equal(cluster_rho$status, "point_only")
  expect_equal(c2_rho$status, "point_only")

  cluster_prop <- gllvmTMB:::.profile_route_status(
    "proportion",
    "cluster",
    routes = routes
  )
  c2_prop <- gllvmTMB:::.profile_route_status(
    "proportion",
    "cluster2",
    routes = routes
  )
  spatial_prop <- gllvmTMB:::.profile_route_status(
    "proportion",
    "spatial",
    routes = routes
  )
  expect_equal(cluster_prop$status, "partial")
  expect_equal(c2_prop$status, "partial")
  expect_match(cluster_prop$route, "unique_cluster")
  expect_match(c2_prop$route, "unique_cluster2")
  expect_equal(spatial_prop$status, "planned")
})

test_that("profile route matrix records named kernel interval boundaries", {
  routes <- gllvmTMB:::.profile_route_matrix()

  kernel_sd <- gllvmTMB:::.profile_route_status(
    "direct_sd",
    "kernel_named",
    routes = routes
  )
  kernel_sigma <- gllvmTMB:::.profile_route_status(
    "Sigma",
    "kernel_named",
    routes = routes
  )
  kernel_comm <- gllvmTMB:::.profile_route_status(
    "communality",
    "kernel_named",
    routes = routes
  )
  kernel_rho <- gllvmTMB:::.profile_route_status(
    "rho",
    "kernel_named",
    routes = routes
  )
  kernel_prop <- gllvmTMB:::.profile_route_status(
    "proportion",
    "kernel_named",
    routes = routes
  )

  expect_true(all(
    c(
      kernel_sd$status,
      kernel_sigma$status,
      kernel_comm$status,
      kernel_rho$status,
      kernel_prop$status
    ) ==
      "blocked"
  ))
  expect_match(kernel_sigma$route, "extract_Sigma_point_only", fixed = TRUE)
  expect_match(kernel_rho$route, "extract_Sigma_table", fixed = TRUE)
  expect_match(
    kernel_prop$claim,
    "not part of the current variance-proportion denominator",
    fixed = TRUE
  )
})

test_that("profile route matrix keeps augmented split profile routes blocked", {
  routes <- gllvmTMB:::.profile_route_matrix()
  split_levels <- c(
    "unit_slope",
    "phy_unique_slope",
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
    "spde_dep",
    "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")

  for (lvl in split_levels) {
    for (estimand in split_estimands) {
      route <- gllvmTMB:::.profile_route_status(estimand, lvl, routes = routes)
      if (identical(lvl, "unit_slope") && identical(estimand, "rho")) {
        expect_equal(route$status, "partial", label = paste(estimand, lvl))
        expect_match(route$route, "unit_slope_selected_entry", fixed = TRUE)
        expect_match(route$claim, "canary", fixed = TRUE)
      } else {
        expect_equal(route$status, "blocked", label = paste(estimand, lvl))
        expect_match(route$route, "augmented_split_target_table", fixed = TRUE)
        expect_match(route$claim, "Design 74", fixed = TRUE)
        expect_true(nzchar(route$next_gate))
        expect_false(grepl(
          "symbolic target table required",
          route$next_gate,
          fixed = TRUE
        ))
      }
    }
  }
})

test_that("profile route matrix marks only unit_slope rho as the augmented canary", {
  routes <- gllvmTMB:::.profile_route_matrix()
  augmented <- routes[
    routes$level %in%
      c(
        "unit_slope",
        "phy_unique_slope",
        "phy_dep",
        "phy_slope",
        "spde_base_slope",
        "spde_dep",
        "spde_slope"
      ) &
      routes$estimand %in% c("Sigma", "communality", "rho", "proportion"),
    ,
    drop = FALSE
  ]
  partial <- augmented[augmented$status == "partial", , drop = FALSE]

  expect_equal(nrow(partial), 1L)
  expect_equal(partial$level, "unit_slope")
  expect_equal(partial$estimand, "rho")
  expect_match(partial$route, "profile_ci_correlation", fixed = TRUE)
})

test_that("augmented profile target table covers every split level and estimand", {
  targets <- gllvmTMB:::.profile_augmented_target_table()
  split_levels <- c(
    "unit_slope",
    "phy_unique_slope",
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
    "spde_dep",
    "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")

  expect_s3_class(targets, "data.frame")
  expect_true(all(
    c(
      "level",
      "estimand",
      "target_state",
      "point_route",
      "target_shape",
      "flatten_order",
      "numerator",
      "denominator",
      "validation_row",
      "profile_gate"
    ) %in%
      names(targets)
  ))
  expect_equal(nrow(targets), length(split_levels) * length(split_estimands))
  expect_equal(
    anyDuplicated(paste(targets$level, targets$estimand)),
    0L
  )
  expect_true(all(split_levels %in% targets$level))
  expect_true(all(split_estimands %in% targets$estimand))
  expect_true(all(grepl("blocked", targets$target_state, fixed = TRUE)))
  expect_no_error(gllvmTMB:::.validate_profile_augmented_target_table(targets))
})

test_that("augmented profile target table preserves shape distinctions", {
  targets <- gllvmTMB:::.profile_augmented_target_table()
  row <- function(level, estimand = "Sigma") {
    out <- targets[targets$level == level & targets$estimand == estimand, ]
    expect_equal(nrow(out), 1L)
    out
  }

  expect_match(row("unit_slope")$target_shape, "2T_by_2T", fixed = TRUE)
  expect_match(row("unit_slope")$flatten_order, "interleaved", fixed = TRUE)
  expect_match(row("unit_slope")$denominator, "no intercept-only", fixed = TRUE)

  expect_match(row("phy_unique_slope")$target_shape, "2_by_2", fixed = TRUE)
  expect_match(
    row("phy_unique_slope")$flatten_order,
    "block-local",
    fixed = TRUE
  )

  expect_match(row("phy_dep")$target_shape, "(1+s)T", fixed = TRUE)
  expect_match(row("phy_dep")$flatten_order, "interleaved", fixed = TRUE)

  expect_match(row("phy_slope")$target_shape, "list_of_T_by_T", fixed = TRUE)
  expect_match(row("phy_slope")$denominator, "block-diagonal", fixed = TRUE)

  expect_match(row("spde_base_slope")$denominator, "kappa_s", fixed = TRUE)
  expect_match(row("spde_dep")$target_shape, "2T_by_2T", fixed = TRUE)
  expect_match(row("spde_dep")$denominator, "4*pi*kappa^2", fixed = TRUE)
  expect_match(row("spde_slope")$target_shape, "list_of_T_by_T", fixed = TRUE)
})

test_that("augmented communality table blocks non-loading structural modes", {
  targets <- gllvmTMB:::.profile_augmented_target_table()
  non_loading <- targets[
    targets$estimand == "communality" &
      targets$level %in%
        c("phy_unique_slope", "phy_dep", "spde_base_slope", "spde_dep"),
    ,
    drop = FALSE
  ]

  expect_equal(nrow(non_loading), 4L)
  expect_true(all(non_loading$target_state == "not_applicable_blocked"))
  expect_true(all(non_loading$numerator == "none"))
  expect_true(all(non_loading$denominator == "none"))
})

test_that("rho parser accepts unit_slope augmented coefficient indices", {
  trait_names <- c("t1", "t2")

  parsed <- gllvmTMB:::.parse_rho_parm("rho:unit_slope:1,4", trait_names)
  expect_equal(parsed$tier, "unit_slope")
  expect_equal(parsed$pairs, matrix(c(1L, 4L), nrow = 1L))

  expect_error(
    gllvmTMB:::.parse_rho_parm("rho:unit:1,4", trait_names),
    "out of range"
  )
  expect_error(
    gllvmTMB:::.parse_rho_parm("rho:unit_slope:1,5", trait_names),
    "out of range"
  )
})

test_that("unit_slope rho confint dispatch is profile-only", {
  fake <- structure(
    list(
      data = data.frame(trait = factor(c("t1", "t2"))),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )

  expect_error(
    gllvmTMB:::.confint_rho(
      fake,
      parm = "rho:unit_slope:1,2",
      level = 0.95,
      method = "wald",
      nsim = 10L,
      seed = 1L
    ),
    "method = \"profile\""
  )

  testthat::local_mocked_bindings(
    profile_ci_correlation = function(fit, tier, i, j, level) {
      expect_equal(tier, "unit_slope")
      expect_equal(c(i, j), c(1L, 2L))
      expect_equal(level, 0.95)
      c(estimate = 0.2, lower = -0.1, upper = 0.5)
    },
    .package = "gllvmTMB"
  )
  ci <- gllvmTMB:::.confint_rho(
    fake,
    parm = "rho:unit_slope:1,2",
    level = 0.95,
    method = "profile",
    nsim = 10L,
    seed = 1L
  )
  expect_equal(rownames(ci), "rho:unit_slope:1,2")
  expect_equal(unname(ci[1, ]), c(-0.1, 0.5))
})

test_that("profile_ci_correlation targets augmented unit_slope parameters", {
  par <- c(
    theta_rr_B_slope = 0.7,
    theta_rr_B_slope = 0.2,
    theta_rr_B_slope = -0.1,
    theta_rr_B_slope = 0.3,
    theta_diag_B_slope = log(0.4),
    theta_diag_B_slope = log(0.5),
    theta_diag_B_slope = log(0.6),
    theta_diag_B_slope = log(0.7)
  )
  fake <- structure(
    list(
      opt = list(par = par),
      tmb_data = list(family_id_vec = 0L),
      use = list(rr_B_slope = TRUE, diag_B_slope = TRUE),
      d_B_slope = 1L,
      n_traits = 2L,
      data = data.frame(trait = factor(c("t1", "t2"))),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )
  R <- diag(4L)
  R[1L, 2L] <- R[2L, 1L] <- 0.25

  testthat::local_mocked_bindings(
    extract_Sigma = function(fit, level, part, link_residual, .skip_warn) {
      expect_equal(level, "B_slope")
      expect_equal(part, "total")
      expect_equal(link_residual, "none")
      list(R = R, Sigma = R)
    },
    .profile_ci_via_refit = function(fit, target_fn, q_hat, ...) {
      expect_equal(q_hat, 0.25)
      target <- target_fn(fit$opt$par, fit)
      expect_true(is.finite(target))
      expect_true(abs(target) <= 1)
      list(lower = -0.2, upper = 0.6, estimate = q_hat)
    },
    .package = "gllvmTMB"
  )

  ci <- gllvmTMB::profile_ci_correlation(
    fake,
    tier = "unit_slope",
    i = 1L,
    j = 2L
  )
  expect_equal(unname(ci), c(0.25, -0.2, 0.6))
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
  expect_true(all(
    c(
      "sd_cluster[1]",
      "sd_cluster[2]",
      "sd_cluster2[1]",
      "sd_cluster2[2]"
    ) %in%
      targets$parm
  ))
  expect_true(all(
    c(
      "sd_phy_unique[1]",
      "sd_phy_unique[2]"
    ) %in%
      targets$parm
  ))
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
      expect_true(
        parameter %in%
          c(
            "theta_diag_species",
            "theta_diag_cluster2"
          )
      )
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

  expect_equal(
    ci_cluster$parameter,
    c(
      "Sigma_cluster[a,a]",
      "Sigma_cluster[a,b]",
      "Sigma_cluster[b,b]"
    )
  )
  expect_equal(ci_cluster$estimate, c(0.16, 0, 0.25))
  expect_equal(ci_cluster$lower, c(0.08, 0, 0.12))
  expect_equal(ci_cluster$upper, c(0.40, 0, 0.55))
  expect_equal(
    ci_cluster$method,
    c("profile", "structural_zero", "profile")
  )

  expect_equal(
    ci_cluster2$parameter,
    c(
      "Sigma_cluster2[a,a]",
      "Sigma_cluster2[a,b]",
      "Sigma_cluster2[b,b]"
    )
  )
  expect_equal(
    ci_cluster2$method,
    c("profile", "structural_zero", "profile")
  )

  ci_wald <- gllvmTMB:::.confint_sigma_wald(
    fake_fit,
    parm = "Sigma_cluster",
    level = 0.95
  )
  expect_equal(ci_wald$parameter, ci_cluster$parameter)
  expect_true(all(is.finite(ci_wald$lower[c(1L, 3L)])))
  expect_equal(ci_wald$lower[2L], 0)
  expect_equal(ci_wald$upper[2L], 0)
  expect_equal(ci_wald$method[2L], "structural_zero")
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
