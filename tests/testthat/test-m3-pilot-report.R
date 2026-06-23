source_power_pilot_report <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- list(
    root = ".",
    package = file.path("..", ".."),
    workspace = workspace
  )
  roots <- unique(unlist(candidates, use.names = FALSE))
  roots <- roots[nzchar(roots)]
  roots <- roots[dir.exists(roots)]
  files <- lapply(roots, function(root) {
    file.path(root, "dev", c(
      "m3-grid.R",
      "m3-pilot-launch.R",
      "m3-pilot-report.R"
    ))
  })
  hit <- files[vapply(files, function(paths) all(file.exists(paths)), logical(1))]
  testthat::skip_if(
    !length(hit),
    "dev power-pilot helpers are unavailable in this source-tarball context"
  )
  paths <- hit[[1]]
  source(paths[1], local = parent.frame())
  source(paths[2], local = parent.frame())
  source(paths[3], local = parent.frame())
}

test_that("power pilot report carries denominators, MCSEs, and evidence labels", {
  source_power_pilot_report()

  g <- data.frame(
    cell = "binomial_probit-d1-n50-sig0p2",
    family = "binomial",
    d = 1L,
    rep = c(1L, 1L, 2L, 2L),
    rep_seed = c(101L, 101L, 102L, 102L),
    trait_id = c(1L, 2L, 1L, 2L),
    target = "Sigma_unit_diag",
    ci_method = "bootstrap",
    fit_converged = TRUE,
    converged = TRUE,
    fit_convergence_code = c(0L, 0L, 1L, 1L),
    pd_hessian = c(TRUE, TRUE, FALSE, FALSE),
    sdreport_ok = c(TRUE, TRUE, FALSE, FALSE),
    ci_available = TRUE,
    covered = c(TRUE, TRUE, FALSE, TRUE),
    miss_side = c(
      "covered",
      "covered",
      "truth_above_upper",
      "covered"
    ),
    truth = c(1, 1, 2, 2),
    estimate = c(1, 1, 1, 2),
    ci_lo = c(0.2, 0.2, 0.2, 0.2),
    ci_hi = c(1.2, 1.2, 1.2, 2.2),
    n_boot_failed = c(1L, 1L, 0L, 0L),
    n_boot = 5L,
    runtime_s = c(1, 1, 2, 2),
    n_units = 50L,
    n_traits = 5L,
    lambda_scale = 0.5,
    stringsAsFactors = FALSE
  )

  row <- pilot_collect_cell(
    g,
    "binomial_probit-d1-n50-sig0p2",
    pilot_grid(),
    PILOT_GATE_94,
    PILOT_GATE_95
  )

  expect_equal(row$evidence_family, "binomial_logit_harness")
  expect_equal(row$link_intended, "probit")
  expect_equal(row$link_harness, "logit")

  expect_equal(row$n_attempted_fits, 2L)
  expect_equal(row$n_converged_fits, 2L)
  expect_equal(row$n_optimizer_converged, 1L)
  expect_equal(row$n_pd_hessian, 1L)
  expect_equal(row$n_sdreport_ok, 1L)
  expect_equal(row$n_boot_attempted, 10L)
  expect_equal(row$n_boot_failed, 1L)
  expect_equal(row$coverage_eligible_n, 4L)
  expect_equal(row$zero_exclusion_n, 4L)

  expect_equal(row$coverage_primary, 0.75)
  expect_equal(row$coverage_mcse, sqrt(0.75 * 0.25 / 2))
  expect_equal(row$zero_exclusion_rate, 1)
  expect_equal(row$fit_failure_rate, 0)
  expect_equal(row$nonpd_rate, 0.5)
  expect_equal(row$conv_failure_rate, 0.5)
  expect_equal(row$boot_fail_rate, 0.1)
  expect_equal(row$boot_fail_mcse, sqrt(0.1 * 0.9 / 10))

  lines <- pilot_record_lines(row)
  expect_true(any(grepl("binomial_logit_harness", lines, fixed = TRUE)))
  expect_true(any(grepl("cov_mcse", lines, fixed = TRUE)))
  expect_true(any(grepl("sdreport", lines, fixed = TRUE)))
})
