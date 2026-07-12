test_that("extract_proportions includes diagonal cluster components", {
  fake <- structure(
    list(
      use = list(
        diag_species = TRUE,
        diag_cluster2 = TRUE
      ),
      data = data.frame(trait = factor(c("a", "b"), levels = c("a", "b"))),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )

  testthat::local_mocked_bindings(
    extract_Sigma = function(fit, level, part, ...) {
      expect_equal(part, "unique")
      switch(
        level,
        cluster = list(s = c(a = 4, b = 9)),
        cluster2 = list(s = c(a = 16, b = 25)),
        stop("unexpected level")
      )
    },
    .package = "gllvmTMB"
  )

  out <- gllvmTMB::extract_proportions(
    fake,
    link_residual = "none",
    format = "long"
  )
  expect_setequal(
    as.character(out$component),
    c("unique_cluster", "unique_cluster2")
  )
  a_rows <- out[as.character(out$trait) == "a", ]
  expect_equal(sum(a_rows$variance), 20)
  expect_equal(
    a_rows$proportion[as.character(a_rows$component) == "unique_cluster"],
    4 / 20
  )
  expect_equal(
    a_rows$proportion[as.character(a_rows$component) == "unique_cluster2"],
    16 / 20
  )
})

test_that("proportion parser accepts diagonal cluster component tokens", {
  expect_true(all(c(
    "unique_cluster", "unique_cluster2"
  ) %in% gllvmTMB:::.proportion_components()))

  parsed <- gllvmTMB:::.parse_proportion_parm(
    "proportion:unique_cluster;unique_cluster2:[1,2]",
    trait_names = c("a", "b")
  )
  expect_equal(parsed$components, c("unique_cluster", "unique_cluster2"))
  expect_equal(parsed$trait_idx, c(1L, 2L))
})

test_that("cluster proportion target functions use the full all-tier denominator", {
  fake <- structure(
    list(
      n_traits = 2L,
      data = data.frame(trait = factor(c("a", "b"), levels = c("a", "b"))),
      trait_col = "trait",
      tmb_data = list(
        family_id_vec = c(0L, 0L),
        link_id_vec = c(0L, 0L),
        trait_id = 0:1
      ),
      report = list(
        eta = c(0, 0),
        sigma_eps = 1
      ),
      use = list(
        diag_species = TRUE,
        diag_cluster2 = TRUE
      ),
      opt = list(
        par = c(
          theta_diag_species = log(2),
          theta_diag_species = log(3),
          theta_diag_cluster2 = log(4),
          theta_diag_cluster2 = log(5)
        )
      )
    ),
    class = "gllvmTMB_multi"
  )

  prop_cluster_a <- gllvmTMB:::.proportion_target_fn(
    fake,
    component = "unique_cluster",
    trait_idx = 1L
  )
  prop_cluster2_a <- gllvmTMB:::.proportion_target_fn(
    fake,
    component = "unique_cluster2",
    trait_idx = 1L
  )
  prop_cluster_b <- gllvmTMB:::.proportion_target_fn(
    fake,
    component = "unique_cluster",
    trait_idx = 2L
  )

  expect_equal(prop_cluster_a(fake$opt$par, fake), 4 / (4 + 16))
  expect_equal(prop_cluster2_a(fake$opt$par, fake), 16 / (4 + 16))
  expect_equal(prop_cluster_b(fake$opt$par, fake), 9 / (9 + 25))
})

test_that("Wald proportion reconstruction reads cluster report slots", {
  fake <- structure(
    list(
      tmb_obj = list(
        report = function(par) {
          list(
            sd_q = c(2, 3),
            sd_c2 = c(4, 5)
          )
        }
      )
    ),
    class = "gllvmTMB_multi"
  )
  comp <- gllvmTMB:::.proportions_components_at(
    fake,
    par_full = numeric(),
    comps_present = c("unique_cluster", "unique_cluster2"),
    T = 2L
  )

  expect_equal(comp$num[, "unique_cluster"], c(4, 9))
  expect_equal(comp$num[, "unique_cluster2"], c(16, 25))
  expect_equal(comp$den, c(20, 34))
})
