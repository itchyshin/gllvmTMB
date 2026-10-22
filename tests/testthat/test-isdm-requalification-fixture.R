fixture_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "fixture.R"
)
if (!file.exists(fixture_path)) {
  test_that("developer-only iSDM fixture source is available", {
    skip("dev/isdm-requalification is absent from the built package")
  })
} else {
source(fixture_path, local = TRUE)

test_that("nonspatial fixture freezes mixed laws and source-masked bias", {
  fixture <- isdm_nonspatial_fixture(
    seed = 11L, n_sources = 3L, overlap = "full", n_cells = 30L
  )
  expect_identical(names(fixture$families), c("source1", "source2", "source3"))
  expect_identical(unname(vapply(fixture$families, `[[`, character(1L), "family")),
                   c("poisson", "poisson", "binomial"))
  expect_identical(unname(vapply(fixture$families, `[[`, character(1L), "link")),
                   c("log", "log", "cloglog"))
  observations <- attr(fixture$families, "isdm_observation", exact = TRUE)
  expect_true(all(vapply(observations, inherits, logical(1L), "formula")))
  expect_true(all(c("eta_ecological", "Sigma", "Psi", "beta", "delta") %in%
                  names(fixture$truth)))
  expect_equal(fixture$data$log_support, log(fixture$data$support))
})

test_that("weak overlap remains connected and disconnected attack does not", {
  weak <- isdm_nonspatial_fixture(12L, 3L, "weak", 60L)
  attack <- isdm_nonspatial_fixture(12L, 3L, "disconnected", 60L)
  expect_true(isdm_source_support_connected(weak$data))
  expect_false(isdm_source_support_connected(attack$data))
})

test_that("full and weak attempts can share structural truth without sharing attempt seeds", {
  full <- isdm_nonspatial_fixture(100L, 2L, "full", 30L,
                                  observation_seed = 101L)
  weak <- isdm_nonspatial_fixture(100L, 2L, "weak", 30L,
                                  observation_seed = 102L)
  expect_identical(full$truth$eta_ecological, weak$truth$eta_ecological)
  expect_identical(full$truth$Sigma, weak$truth$Sigma)
  expect_false(identical(full$data$value, weak$data$value))
})

test_that("all-NA source arms are refused by the retained harness preflight", {
  fixture <- isdm_nonspatial_fixture(13L, 2L, "full", 30L)
  bad <- fixture$data
  bad$value[bad$isdm_source == "source2" & bad$trait == "sp1"] <- NA_real_
  expect_error(
    isdm_assert_observed_source_completeness(bad),
    class = "gllvmTMB_isdm_observed_source_incomplete"
  )
  absent <- fixture$data[!(fixture$data$isdm_source == "source2" &
                             fixture$data$trait == "sp1"), ]
  expect_error(
    isdm_assert_observed_source_completeness(absent),
    class = "gllvmTMB_isdm_observed_source_incomplete"
  )
})

test_that("zero support offset means effort-free relative intensity", {
  eta <- c(-1, 0, 1)
  expect_equal(isdm_inverse_link(eta, "poisson", log_support = 0), exp(eta))
  expect_equal(isdm_inverse_link(eta, "cloglog", log_support = 0),
               -expm1(-exp(eta)))
})

test_that("covariance packing is rotation invariant", {
  lambda <- matrix(c(0.8, -0.4, 0.5), ncol = 1L)
  psi <- c(0.2, 0.3, 0.4)
  out <- isdm_pack_covariance(lambda, psi)
  rotated <- isdm_pack_covariance(-lambda, psi)
  expect_equal(unname(out$Sigma), unname(tcrossprod(lambda) + diag(psi)))
  expect_equal(unname(out$Psi), unname(diag(psi)))
  expect_equal(out, rotated)
})

test_that("held-out geometry is deterministic, interior, and exactly twenty percent", {
  geometry <- isdm_spatial_geometry(n_cells = 100L, seed = 14L)
  expect_equal(sum(geometry$held_out), 20L)
  expect_true(all(geometry$x[geometry$held_out] > min(geometry$x)))
  expect_true(all(geometry$x[geometry$held_out] < max(geometry$x)))
  expect_true(all(geometry$y[geometry$held_out] > min(geometry$y)))
  expect_true(all(geometry$y[geometry$held_out] < max(geometry$y)))
  expect_identical(geometry, isdm_spatial_geometry(n_cells = 100L, seed = 14L))
})

test_that("spatial fixture withholds whole coordinates and uses effort-free newdata", {
  skip_if_not_installed("fmesher")
  fixture <- isdm_spatial_fixture(
    seed = 15L, n_sources = 2L, overlap = "full", n_cells = 64L,
    cutoff = 0.15
  )
  training_cells <- unique(as.character(fixture$data$cell_id))
  heldout_cells <- unique(as.character(fixture$heldout$cell_id))
  expect_length(intersect(training_cells, heldout_cells), 0L)
  expect_equal(length(heldout_cells), floor(0.20 * 64L))
  expect_equal(nrow(fixture$heldout), length(heldout_cells) * 3L * 2L)
  expect_true(all(fixture$heldout$log_support == 0))
  expect_true(all(is.na(fixture$heldout$value)))
  expect_equal(nrow(fixture$map_newdata), length(heldout_cells) * 3L)
  expect_true(all(fixture$map_newdata$bias_x == 0))
  expect_true(all(fixture$map_newdata$log_support == 0))
  expect_length(unique(fixture$map_newdata$isdm_source), 1L)
  expect_equal(nrow(fixture$mesh$A_st), nrow(fixture$data))
  expect_identical(fixture$design$mesh_domain, "training coordinates only")
})
}
