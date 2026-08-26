ci13_kernel <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci13",
  "ci13-kernels.R"
)
.ci13_dev_sources_available <- file.exists(ci13_kernel)

if (.ci13_dev_sources_available) {
  source(ci13_kernel, local = TRUE)

test_that("CI-13 freezes the four pinned, unrotated Gaussian cells", {
  spec <- ci13_campaign_spec()
  expect_equal(nrow(spec$cells), 4L)
  expect_equal(spec$n_sim, 5000L)
  expect_equal(sort(unique(spec$cells$n_units)), c(150L, 400L))
  expect_equal(sort(unique(spec$cells$d)), c(1L, 2L))
  expect_identical(spec$rotation, "native-pinned-unrotated")
  expect_identical(
    spec$confirmatory_map,
    "diagonal anchors pinned; strict-lower entries promotional"
  )
  expect_equal(ci13_rep_seed(1L, 1L), 130010001L)
  expect_equal(ci13_rep_seed(4L, 5000L), 130045000L)
  expect_false(ci13_seed_sets_intersect(1L, 1:2, 2L, 1:2))
})

test_that("CI-13 reconstructs only lower-triangular loadings and psi squared", {
  lambda <- ci13_reconstruct_lambda(c(1, 2, 3, 4, 5), n_traits = 3L, d = 2L)
  ## Engine contract: diagonal first, then strict lower triangle column-wise.
  expect_equal(lambda, rbind(c(1, 0), c(3, 2), c(4, 5)))
  expect_error(ci13_reconstruct_lambda(1:6, 3L, 2L), "length")
  expect_equal(ci13_psi_sq(log(c(2, 3))), c(4, 9))
  expect_equal(diag(ci13_sigma(lambda, log(c(2, 3, 4)))), c(5, 22, 57))
  expect_equal(
    ci13_structurally_free_targets(n_traits = 3L, d = 2L)$target_id,
    c("rho_t2_k1", "rho_t3_k1", "rho_t3_k2")
  )
  expect_equal(
    ci13_structurally_free_targets(n_traits = 3L, d = 1L)$target_id,
    c("rho_t2_k1", "rho_t3_k1")
  )
  expect_equal(
    ci13_pinned_diagnostic_targets(n_traits = 3L, d = 2L)$target_id,
    c("rho_t1_k1", "rho_t2_k2")
  )
  constraint <- ci13_native_confirmatory_constraint(
    c(0.8, 0.7),
    n_traits = 3L,
    d = 2L
  )
  expect_equal(diag(constraint)[1:2], c(0.8, 0.7))
  expect_true(
    is.na(constraint[2L, 1L]) &&
      is.na(constraint[3L, 1L]) &&
      is.na(constraint[3L, 2L])
  )
  expect_true(is.na(constraint[1L, 2L]))
})

test_that("CI-13 standardized target and analytic gradient agree with finite differences", {
  theta <- c(1.2, -0.3, 0.8, 0.5, -0.2, log(0.7), log(0.8), log(1.1))
  for (d in 1:2) {
    for (target in seq_len(nrow(ci13_structurally_free_targets(3L, d)))) {
      target_row <- ci13_structurally_free_targets(3L, d)[
        target,
        ,
        drop = FALSE
      ]
      theta_d <- c(
        theta[seq_len(nrow(ci13_lower_tri_index(3L, d)))],
        theta[6:8]
      )
      analytic <- ci13_standardized_loading_gradient(
        theta_d,
        target_row$trait,
        target_row$factor,
        n_traits = 3L,
        d = d
      )
      numeric <- ci13_standardized_loading_gradient_fd(
        theta_d,
        target_row$trait,
        target_row$factor,
        n_traits = 3L,
        d = d
      )
      expect_equal(analytic, numeric, tolerance = 1e-6)
    }
  }
  expect_equal(
    ci13_standardized_loading(theta, 2L, 2L, 3L, 2L),
    -0.3 / sqrt(0.8^2 + (-0.3)^2 + 0.8^2),
    tolerance = 1e-12
  )
  expect_error(ci13_validate_target_scale("raw-loading"), "standardized")
  expect_error(
    ci13_validate_target_scale("varimax-standardized"),
    "standardized"
  )
  expect_error(
    ci13_standardized_loading(theta, 1L, 2L, 3L, 2L),
    "structurally fixed"
  )
})

test_that("CI-13 joint delta includes denominator and same-trait covariance", {
  theta <- c(1.2, -0.3, 0.8, 0.5, -0.2, log(0.7), log(0.8), log(1.1))
  covariance <- diag(length(theta)) * 0.04
  covariance[2L, 3L] <- covariance[3L, 2L] <- 0.01
  interval <- ci13_joint_delta_interval(
    theta,
    covariance,
    trait = 2L,
    factor = 2L,
    n_traits = 3L,
    d = 2L
  )
  expect_true(interval$se > 0)
  expect_true(interval$gradient[2L] != 0)
  expect_true(interval$gradient[3L] != 0)
  expect_true(interval$gradient[7L] != 0)
  expect_error(
    ci13_joint_delta_interval(theta, diag(7), 2L, 2L, 3L, 2L),
    "dimension"
  )
})

test_that("CI-13 manifest and all-attempt ledger fail closed", {
  full_manifest <- ci13_attempt_manifest(source_sha = "TEST-SHA")
  expect_length(full_manifest$expected, 4L * 5000L)
  expect_length(
    unique(vapply(
      full_manifest$expected,
      function(x) {
        paste(x$cell_id, x$rep, x$seed, sep = "::")
      },
      character(1)
    )),
    4L * 5000L
  )
  manifest <- ci13_attempt_manifest(
    cell_ids = 2L,
    rep_ids = 1:2,
    source_sha = "TEST-SHA"
  )
  targets <- ci13_target_results(
    manifest,
    2L,
    setNames(
      rep("covered", nrow(ci13_cell_targets(manifest$spec, 2L))),
      ci13_cell_targets(manifest$spec, 2L)$target_id
    )
  )
  a1 <- ci13_outer_attempt(manifest, 2L, 1L, "eligible", targets)
  a2 <- ci13_outer_attempt(manifest, 2L, 2L, "base_fit_failed")
  merged <- ci13_merge_attempts(manifest, list(a1, a2))
  expect_equal(nrow(merged$canonical), 2L)
  expect_equal(nrow(merged$operational), 2L)
  expect_error(ci13_merge_attempts(manifest, list(a1)), "missing canonical")
  expect_error(
    ci13_target_results(manifest, 2L, list(rho_t2_k2 = "covered")),
    "complete"
  )
  duplicate <- targets
  duplicate[[2L]]$target_id <- duplicate[[1L]]$target_id
  expect_error(
    ci13_outer_attempt(manifest, 2L, 1L, "eligible", duplicate),
    "exactly once"
  )
  raw <- targets
  raw[[1L]]$scale <- "raw-loading"
  expect_error(
    ci13_outer_attempt(manifest, 2L, 1L, "eligible", raw),
    "raw, rotated"
  )
  bad_seed <- a1
  bad_seed$seed <- bad_seed$seed + 1L
  expect_error(ci13_merge_attempts(manifest, list(bad_seed, a2)), "seed")
  expect_error(
    ci13_attempt_manifest(
      cell_ids = 2L,
      rep_ids = 1L,
      source_sha = "TEST-SHA",
      historical_seeds = ci13_rep_seed(2L, 1L)
    ),
    "historical"
  )
  expect_error(ci13_attempt_manifest(), "source SHA")
})

test_that("CI-13 preserves infrastructure retry provenance and treats CI failures as misses", {
  manifest <- ci13_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1:100,
    source_sha = "TEST-SHA"
  )
  covered <- function(cell_id) {
    ci13_target_results(
      manifest,
      cell_id,
      setNames(
        rep(
          "covered",
          length(ci13_cell_targets(manifest$spec, cell_id)$target_id)
        ),
        ci13_cell_targets(manifest$spec, cell_id)$target_id
      )
    )
  }
  attempts <- lapply(manifest$expected, function(x) {
    ci13_outer_attempt(
      manifest,
      x$cell_id,
      x$rep,
      "eligible",
      covered(x$cell_id)
    )
  })
  for (i in seq_len(10L)) {
    attempts[[i]]$target_results[[1L]]$outcome <- "ci_failed"
  }
  result <- ci13_promote(manifest, attempts)
  expect_equal(result$targets$n_ci_failed[1L], 10L)
  expect_equal(result$targets$coverage[1L], 0.9)
  expect_false(result$promotion$promote)
  expect_false(result$promotion$campaign_complete)
  expect_match(result$promotion$availability_note, "not a promotion criterion")

  one <- ci13_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = "TEST-SHA"
  )
  infra <- ci13_outer_attempt(one, 1L, 1L, "infrastructure_failure")
  retry <- ci13_outer_attempt(
    one,
    1L,
    1L,
    "eligible",
    covered(1L),
    attempt_version = 2L
  )
  expect_silent(ci13_merge_attempts(one, list(infra, retry)))
  science <- ci13_outer_attempt(one, 1L, 1L, "scientific_base_failure")
  expect_error(
    ci13_merge_attempts(one, list(science, retry)),
    "scientific failure"
  )

  all_covered <- lapply(manifest$expected, function(x) {
    ci13_outer_attempt(
      manifest,
      x$cell_id,
      x$rep,
      "eligible",
      covered(x$cell_id)
    )
  })
  all_covered[[1L]] <- ci13_outer_attempt(
    manifest,
    1L,
    1L,
    "scientific_base_failure"
  )
  science_report <- ci13_promote(manifest, all_covered)
  expect_false(science_report$promotion$promote)
  expect_equal(science_report$targets$scientific_failures[1L], 1L)
})

test_that("CI-13 promotes only a complete 20,000-row campaign", {
  manifest <- ci13_attempt_manifest(source_sha = "FULL-TEST-SHA")
  attempts <- ci13_synthetic_all_covered_attempts(manifest)
  result <- ci13_promote(manifest, attempts)
  expect_true(result$promotion$campaign_complete)
  expect_true(result$promotion$promote)
})

test_that("CI-13 merge revalidates deserialised outcomes and payload state", {
  manifest <- ci13_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = "deserialised-state-sha"
  )
  good <- ci13_synthetic_all_covered_attempts(manifest)[[1L]]
  unknown <- good
  unknown$outcome <- "unknown_outcome"
  unknown$target_results <- list()
  expect_error(ci13_merge_attempts(manifest, list(unknown)), "outer outcome")

  hidden_payload <- ci13_outer_attempt(
    manifest,
    1L,
    1L,
    "base_fit_failed"
  )
  hidden_payload$target_results <- good$target_results
  expect_error(
    ci13_merge_attempts(manifest, list(hidden_payload)),
    "non-eligible"
  )
})

test_that("CI-13 smoke helper only accepts native pinned Lambda_B semantics", {
  ci13_smoke <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "ci13",
    "smoke.R"
  )
  source(ci13_smoke, local = TRUE)
  native <- list(
    report = list(Lambda_B = matrix(c(1, 2, 3, 0, 4, 5), nrow = 3L, ncol = 2L))
  )
  rotated <- list(
    report = list(
      Lambda_B = matrix(c(1, 2, 3, 0.1, 4, 5), nrow = 3L, ncol = 2L)
    )
  )
  expect_silent(ci13_extract_native_pinned_loadings(native))
  expect_error(ci13_extract_native_pinned_loadings(rotated), "rotated")
  expect_true(is.function(ci13_smoke_one_replicate))
  expect_true("source_sha" %in% names(formals(ci13_smoke_one_replicate)))
  runner_source <- paste(deparse(body(ci13_smoke_one_replicate)), collapse = " ")
  expect_match(runner_source, 'unit = "unit"', fixed = TRUE)

  unhealthy <- structure(
    list(
      opt = list(convergence = 1L),
      fit_health = list(converged = FALSE, pd_hessian = TRUE),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  expect_false(ci13_smoke_fit_healthy(unhealthy))

  manifest <- ci13_attempt_manifest(
    cell_ids = 2L,
    rep_ids = 1L,
    source_sha = "smoke-ci-failure-sha"
  )
  failed <- ci13_smoke_ci_failure_attempt(manifest, 2L, 1L)
  expect_identical(failed$outcome, "eligible")
  expect_true(all(vapply(
    failed$target_results,
    function(x) identical(x$outcome, "ci_failed"),
    logical(1)
  )))
})
} else {
  test_that("CI-13 developer calibration contract is source-checkout only", {
    skip("dev/interval-calibration is absent from the built package")
  })
}
