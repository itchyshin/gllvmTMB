ci09_kernel <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci09",
  "ci09-kernels.R"
)
source(ci09_kernel, local = TRUE)

ci09_smoke <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci09",
  "smoke.R"
)
source(ci09_smoke, local = TRUE)

test_that("CI-09 smoke health requires convergence and a positive Hessian", {
  healthy <- structure(
    list(
      opt = list(convergence = 0L),
      fit_health = list(converged = TRUE),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  expect_true(ci09_smoke_fit_healthy(healthy))
  healthy$sd_report$pdHess <- FALSE
  expect_false(ci09_smoke_fit_healthy(healthy))
})

test_that("CI-09 freezes six Gaussian Fisher-z cells and seed windows", {
  spec <- ci09_campaign_spec()
  expect_equal(nrow(spec$cells), 6L)
  expect_equal(spec$n_sim, 5000L)
  expect_equal(sort(unique(spec$cells$n_units)), c(150L, 400L))
  expect_equal(sort(unique(spec$cells$rho)), c(-0.5, 0, 0.5))
  expect_equal(ci09_rep_seed(1L, 1L), 90010001L)
  expect_equal(ci09_rep_seed(6L, 5000L), 90065000L)
  expect_false(ci09_seed_sets_intersect(1L, 1:2, 2L, 1:2))
  expect_error(ci09_attempt_manifest(), "source SHA")
  full_manifest <- ci09_attempt_manifest(source_sha = "0123456789abcdef")
  expect_equal(full_manifest$n_outer, 30000L)
  expect_length(full_manifest$expected, 30000L)
  tampered <- full_manifest
  tampered$source_sha <- "different-source"
  expect_error(ci09_validate_manifest(tampered), "modified after freezing")
})

test_that("CI-09 Fisher-z bounds retain realised n_eff and refuse unavailable intervals", {
  interval <- ci09_fisher_interval(rho = 0.5, n_eff = 150L)
  expect_equal(interval$n_eff, 150L)
  expect_true(interval$lower < 0.5)
  expect_true(interval$upper > 0.5)
  expect_true(is.na(ci09_fisher_interval(0.2, n_eff = NA_integer_)$lower))
  expect_true(is.na(ci09_fisher_interval(0.2, n_eff = 3L)$upper))
})

test_that("CI-09 retains all attempts but allows one canonical scientific row only", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1:2,
    source_sha = "test-attempts"
  )
  covered <- ci09_attempt(manifest, 1L, 1L, "rho_1_2", "covered", n_eff = 150L)
  missing_neff <- ci09_attempt(
    manifest,
    1L,
    2L,
    "rho_1_2",
    "interval_unavailable",
    n_eff = NA_integer_
  )
  merged <- ci09_merge_attempts(manifest, list(covered, missing_neff))
  expect_equal(nrow(merged$canonical), 2L)
  expect_equal(nrow(merged$operational), 2L)
  expect_equal(merged$canonical$outcome[2L], "interval_unavailable")
  interval_summary <- ci09_summarise(merged)$targets
  expect_equal(interval_summary$n_eligible, 2L)
  expect_equal(interval_summary$coverage, 0.5)
  expect_equal(interval_summary$interval_available_rate, 0.5)
  expect_error(
    ci09_merge_attempts(manifest, list(covered)),
    "missing canonical"
  )
  expect_error(
    ci09_merge_attempts(manifest, list(covered, covered, missing_neff)),
    "duplicate"
  )
  wrong_seed <- covered
  wrong_seed$seed <- wrong_seed$seed + 1L
  expect_error(
    ci09_merge_attempts(manifest, list(wrong_seed, missing_neff)),
    "seed collision"
  )
})

test_that("CI-09 treats eligible CI failure as a miss and promotes every target fail-closed", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1:100,
    source_sha = "test-promotion"
  )
  attempts <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  for (i in seq_len(10L)) {
    attempts[[i]] <- ci09_attempt(
      manifest,
      1L,
      i,
      "rho_1_2",
      "ci_failed",
      n_eff = 150L
    )
  }
  summary <- ci09_summarise(ci09_merge_attempts(manifest, attempts))
  expect_equal(summary$targets$n_ci_failed, 10L)
  expect_equal(summary$targets$coverage, 0.9)
  expect_false(ci09_promote(summary)$promotion$promote)

  all_covered <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  passing_summary <- ci09_summarise(ci09_merge_attempts(manifest, all_covered))
  expect_false(ci09_promote(passing_summary)$promotion$promote)
  expect_match(ci09_promote(passing_summary)$promotion$reason, "full")
  extra_target <- passing_summary$targets
  extra_target$target_id <- "second_required_target"
  extra_target$coverage <- 0.93
  extra_target$lower <- 0.93
  multi_target_summary <- passing_summary
  multi_target_summary$targets <- rbind(passing_summary$targets, extra_target)
  expect_false(ci09_promote(multi_target_summary)$promotion$promote)
})

test_that("CI-09 promotion is exact-cell rather than pooled across cells", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1:2,
    rep_ids = 1:100,
    source_sha = "test-cells"
  )
  attempts <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  ## Cell 1 has 94% coverage and fails its lower-band gate. Pooled across both
  ## cells it would appear to pass, which is precisely the forbidden shortcut.
  for (i in seq_len(6L)) {
    attempts[[i]] <- ci09_attempt(
      manifest,
      1L,
      i,
      "rho_1_2",
      "ci_failed",
      n_eff = 150L
    )
  }
  summary <- ci09_summarise(ci09_merge_attempts(manifest, attempts))
  expect_equal(nrow(summary$targets), 2L)
  expect_equal(summary$targets$coverage[summary$targets$cell_id == 1L], 0.94)
  pooled_coverage <- mean(summary$canonical$outcome == "covered")
  pooled_mcse <- stats::sd(as.numeric(summary$canonical$outcome == "covered")) /
    sqrt(nrow(summary$canonical))
  expect_gt(pooled_coverage - 2 * pooled_mcse, 0.94)
  expect_false(ci09_promote(summary)$promotion$promote)
})

test_that("CI-09 retry history preserves infrastructure provenance and rejects scientific reruns", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = "test-retry"
  )
  infra <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "infrastructure_failure",
    n_eff = NA_integer_
  )
  retry <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "covered",
    n_eff = 150L,
    attempt_version = 2L
  )
  expect_silent(ci09_merge_attempts(manifest, list(infra, retry)))
  science <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "scientific_failure",
    n_eff = NA_integer_
  )
  expect_identical(science$base_fit, "failed")
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "scientific_failure",
      n_eff = 150L,
      base_fit = "eligible"
    ),
    "base-fit state"
  )
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "base_fit_failed",
      n_eff = NA_integer_,
      base_fit = "unknown"
    ),
    "base-fit state"
  )
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "scientific_failure",
      n_eff = 150L
    ),
    "n_eff"
  )
  expect_error(
    ci09_merge_attempts(manifest, list(science, retry)),
    "scientific failure is terminal"
  )

  unknown <- retry
  unknown$outcome <- "unknown_outcome"
  unknown$attempt_version <- 1L
  expect_error(
    ci09_merge_attempts(manifest, list(unknown)),
    "deserialised outcome"
  )
  mismatched_base <- retry
  mismatched_base$outcome <- "base_fit_failed"
  mismatched_base$attempt_version <- 1L
  expect_error(
    ci09_merge_attempts(manifest, list(mismatched_base)),
    "base-fit state"
  )
})
