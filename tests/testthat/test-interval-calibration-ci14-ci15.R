## CI-14/15 campaign-packet contract.  These tests exercise only pure R
## bookkeeping; they never simulate, fit, compile, or contact remote compute.

source(testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci14-ci15",
  "ci1415-kernels.R"
))
source(testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci14-ci15",
  "smoke-runners.R"
))
source(testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci14-ci15",
  "campaign-shard.R"
))

test_that("CI-15 dependency guard treats missing ape as infrastructure failure", {
  remote_root <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  available <- function(package, quietly = TRUE) package != "ape"
  expect_error(
    interval_assert_runtime_dependencies(available = available),
    "missing campaign runtime dependencies: ape",
    fixed = TRUE
  )
})

test_that("CI-14 freezes separate unique-Psi and total marginal slope targets", {
  spec <- ci1415_campaign_spec("CI14")
  expect_identical(spec$n_sim, 5000L)
  expect_identical(spec$cells$n_ind, c(50L, 100L))
  expect_identical(spec$repeats, 6L)
  expect_identical(spec$interval_method, "wald_log_scale")
  expect_identical(length(spec$targets), 6L)
  expect_true(all(
    vapply(spec$targets, `[[`, character(1), "component") %in%
      c("unique_psi", "total_marginal")
  ))

  truth <- ci1415_truth("CI14")
  expect_true(all(truth$psi_slope > 0))
  expect_equal(
    truth$total_slope_sd,
    sqrt(rowSums(truth$lambda_slope^2) + truth$psi_slope^2)
  )
  expect_false(isTRUE(all.equal(truth$unique_slope_sd, truth$total_slope_sd)))
  expect_silent(ci1415_validate_truth("CI14", truth))
})

test_that("CI-15 retains distinct Cholesky and loadings-only truth contracts", {
  phy <- ci1415_truth("CI15_PHYLO")
  expect_identical(phy$route, "phylo_cholesky")
  expect_identical(phy$slope_positions, c(2L, 4L))
  expect_equal(
    phy$marginal_slope_sd,
    sqrt(diag(phy$L %*% t(phy$L)))[phy$slope_positions]
  )
  expect_silent(ci1415_validate_truth("CI15_PHYLO", phy))

  rr <- ci1415_truth("CI15_LOADINGS")
  expect_identical(rr$route, "ordinary_loadings_only")
  expect_identical(rr$psi_slope, rep(0, 3L))
  expect_equal(rr$marginal_slope_sd, sqrt(rowSums(rr$lambda_slope^2)))
  expect_silent(ci1415_validate_truth("CI15_LOADINGS", rr))

  bad <- ci1415_old_misspecified_loadings_fixture()
  expect_error(
    ci1415_validate_truth("CI15_LOADINGS", bad),
    "requires Psi = 0"
  )
})

test_that("CI-14/15 seed windows and frozen manifests fail closed", {
  ci14 <- ci1415_attempt_manifest(
    "CI14",
    cell_ids = 1:2,
    rep_ids = 1:2,
    source_sha = "test-source-sha"
  )
  ci15 <- ci1415_attempt_manifest(
    "CI15",
    cell_ids = 1:4,
    rep_ids = 1:2,
    source_sha = "test-source-sha"
  )
  expect_identical(ci1415_rep_seed("CI14", 1L, 1L), 140010001L)
  expect_identical(ci1415_rep_seed("CI15", 4L, 5000L), 150045000L)
  expect_length(
    intersect(
      vapply(ci14$expected, `[[`, integer(1), "seed"),
      vapply(ci15$expected, `[[`, integer(1), "seed")
    ),
    0L
  )
  expect_silent(ci1415_validate_manifest(ci14))
  ci14$source_sha <- "tampered"
  expect_error(ci1415_validate_manifest(ci14), "modified after freezing")
})

test_that("full frozen manifests retain every required canonical outer identity", {
  ci14_full <- ci1415_attempt_manifest("CI14", source_sha = "test-source-sha")
  ci15_full <- ci1415_attempt_manifest("CI15", source_sha = "test-source-sha")
  expect_identical(length(ci14_full$expected), 10000L)
  expect_identical(length(ci15_full$expected), 20000L)
  expect_identical(
    length(unique(vapply(
      ci14_full$expected,
      function(x) {
        paste(x$cell_id, x$rep, x$seed, sep = "::")
      },
      character(1)
    ))),
    10000L
  )
  expect_identical(
    length(unique(vapply(
      ci15_full$expected,
      function(x) {
        paste(x$cell_id, x$rep, x$seed, sep = "::")
      },
      character(1)
    ))),
    20000L
  )

  synthetic <- ci1415_synthetic_all_covered_attempts(ci14_full)
  verdict <- ci1415_promote(ci14_full, synthetic)$promotion
  expect_true(isTRUE(verdict$complete_campaign))
  expect_true(isTRUE(verdict$promote))
  expect_true(isTRUE(verdict$availability_is_not_a_gate))

  ci15_synthetic <- ci1415_synthetic_all_covered_attempts(ci15_full)
  ci15_verdict <- ci1415_promote(ci15_full, ci15_synthetic)$promotion
  expect_true(isTRUE(ci15_verdict$complete_campaign))
  expect_true(isTRUE(ci15_verdict$promote))
})

test_that("eligible rows require complete ordered targets and retain all attempts", {
  manifest <- ci1415_attempt_manifest(
    "CI14",
    cell_ids = 1L,
    rep_ids = 1:2,
    source_sha = "test-source-sha"
  )
  targets <- ci1415_target_results(manifest, "CI14", outcome = "covered")
  expect_length(targets, 6L)
  expect_error(
    ci1415_outer_attempt(manifest, 1L, 1L, "eligible", targets[-1L]),
    "complete target payload"
  )
  wrong_order <- rev(targets)
  expect_error(
    ci1415_outer_attempt(manifest, 1L, 1L, "eligible", wrong_order),
    "target order"
  )
  attempts <- list(
    ci1415_outer_attempt(manifest, 1L, 1L, "infrastructure_failure"),
    ci1415_outer_attempt(
      manifest,
      1L,
      1L,
      "eligible",
      targets,
      attempt_version = 2L
    ),
    ci1415_outer_attempt(manifest, 1L, 2L, "base_fit_failed")
  )
  merged <- ci1415_merge_attempts(manifest, attempts)
  expect_identical(nrow(merged$attempt_table), 3L)
  expect_identical(nrow(merged$canonical), 2L)
  expect_identical(merged$canonical$outcome, c("eligible", "base_fit_failed"))
  expect_error(
    ci1415_merge_attempts(manifest, attempts[-3L]),
    "missing canonical outer attempt"
  )
})

test_that("CI failures are misses and promotion is target-by-target only", {
  manifest <- ci1415_attempt_manifest(
    "CI15",
    cell_ids = 1L,
    rep_ids = 1:3,
    source_sha = "test-source-sha"
  )
  good <- ci1415_target_results(manifest, "CI15_PHYLO", outcome = "covered")
  failed_ci <- good
  failed_ci[[1L]]$outcome <- "ci_failed"
  attempts <- list(
    ci1415_outer_attempt(manifest, 1L, 1L, "eligible", good),
    ci1415_outer_attempt(manifest, 1L, 2L, "eligible", failed_ci),
    ci1415_outer_attempt(manifest, 1L, 3L, "base_fit_failed")
  )
  summary <- ci1415_summarise(ci1415_merge_attempts(manifest, attempts))
  first <- summary[summary$target_id == good[[1L]]$target_id, , drop = FALSE]
  expect_identical(first$eligible, 2L)
  expect_identical(first$ci_failed, 1L)
  expect_equal(first$coverage, 0.5)
  expect_false(isTRUE(ci1415_promote(manifest, attempts)$promotion$promote))
  expect_false(isTRUE(
    ci1415_promote(manifest, attempts)$promotion$complete_campaign
  ))
})

test_that("CI-14/15 promotion cannot accept a detached favourable summary", {
  manifest <- ci1415_attempt_manifest(
    "CI14",
    cell_ids = 1L,
    rep_ids = 1:2,
    source_sha = "test-source-sha"
  )
  detached <- ci1415_synthetic_all_covered_summary(manifest)
  expect_error(
    ci1415_promote(detached, manifest),
    "manifest"
  )
})

test_that("alignment table is complete and packet verifier stays pure", {
  alignment <- ci1415_alignment_table()
  expect_true(all(
    c("symbol", "covstruct", "dgp", "extractor", "truth") %in% names(alignment)
  ))
  expect_true(all(vapply(alignment, function(x) all(nzchar(x)), logical(1))))
  smoke <- ci1415_smoke_plan()
  expect_identical(smoke$execution, "not_run")
  expect_false(isTRUE(smoke$would_fit))
})

test_that("timing smokes are real routes but require explicit provenance and remain unrun", {
  expect_error(ci1415_smoke_request("CI14", cell_id = 1L), "source_sha")
  requests <- list(
    ci1415_smoke_request("CI14", cell_id = 1L, source_sha = "test-source-sha"),
    ci1415_smoke_request("CI15", cell_id = 1L, source_sha = "test-source-sha"),
    ci1415_smoke_request("CI15", cell_id = 3L, source_sha = "test-source-sha")
  )
  expect_identical(
    vapply(requests, `[[`, character(1), "route"),
    c("CI14", "CI15_PHYLO", "CI15_LOADINGS")
  )
  expect_true(all(vapply(
    requests,
    function(x) identical(x$execution, "not_run"),
    logical(1)
  )))
  expect_true(all(vapply(
    requests,
    function(x) is.function(x$runner),
    logical(1)
  )))
  expect_true(all(vapply(
    requests,
    function(x) is.character(x$source_sha) && nzchar(x$source_sha),
    logical(1)
  )))
  expect_true(all(vapply(requests, function(x) is.integer(x$seed), logical(1))))
  expect_true(all(vapply(
    requests,
    function(x) grepl("slope_sd_ci", x$fit_formula, fixed = TRUE),
    logical(1)
  )))
  expect_match(requests[[2L]]$fit_formula, "tree = phy$tree", fixed = TRUE)
  failed_attempt <- ci1415_outer_attempt(
    requests[[2L]]$manifest,
    requests[[2L]]$cell_id,
    requests[[2L]]$rep,
    "base_fit_failed"
  )
  retained_result <- .ci1415_smoke_result(
    requests[[2L]],
    failed_attempt,
    runtime_seconds = 0,
    fit_health = FALSE
  )
  expect_identical(retained_result$fit_formula, requests[[2L]]$fit_formula)
  expect_identical(
    retained_result$provenance$fit_formula,
    requests[[2L]]$fit_formula
  )
  fit_runner_source <- gsub(
    "[[:space:]]+",
    " ",
    paste(deparse(body(.ci1415_fit_smoke)), collapse = " ")
  )
  expect_false(grepl("unit_obs =", fit_runner_source, fixed = TRUE))
  expect_false(grepl("phylo_tree =", fit_runner_source, fixed = TRUE))
  expect_match(
    fit_runner_source,
    "phylo_dep(0 + trait + (0 + trait):x | species, tree = phy$tree)",
    fixed = TRUE
  )

  unhealthy <- structure(
    list(
      opt = list(convergence = 1L),
      fit_health = list(converged = FALSE),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  expect_false(.ci1415_fit_is_healthy(unhealthy))
})

test_that("campaign shard parses one frozen identity and writes it immutably", {
  parsed <- ci1415_parse_shard_args(c(
    "CI14", "1", "1", "test-source-sha",
    file.path(tempdir(), "ci1415-shard-test.rds")
  ))
  expect_identical(parsed$packet, "CI14")
  expect_identical(parsed$cell_id, 1L)
  expect_identical(parsed$rep, 1L)
  expect_error(ci1415_parse_shard_args(c("CI14", "1")), "exactly five")

  request <- ci1415_smoke_request("CI14", 1L, 1L, "test-source-sha")
  fake_runner <- function(cell_id, rep, source_sha) {
    run_request <- ci1415_smoke_request("CI14", cell_id, rep, source_sha)
    list(
      outer_attempt = ci1415_outer_attempt(
        run_request$manifest, cell_id, rep, "base_fit_failed"
      ),
      runtime_seconds = 0.25,
      source_sha = source_sha,
      seed = run_request$seed,
      truth_fingerprint = run_request$truth_fingerprint,
      provenance = run_request$provenance,
      fit_health = FALSE,
      failure = "synthetic test failure"
    )
  }
  out_path <- tempfile("ci1415-shard-", fileext = ".rds")
  result <- ci1415_run_campaign_shard(
    "CI14", 1L, 1L, "test-source-sha", out_path, runner = fake_runner
  )
  expect_identical(result$status, "written")
  expect_true(file.exists(out_path))
  shard <- readRDS(out_path)
  expect_identical(shard$identity$seed, request$seed)
  expect_identical(shard$outer_attempt$outcome, "base_fit_failed")
  expect_identical(shard$source_sha, "test-source-sha")
  expect_true(is.finite(shard$runtime_seconds))
  expect_identical(
    ci1415_run_campaign_shard(
      "CI14", 1L, 1L, "test-source-sha", out_path, runner = fake_runner
    )$status,
    "already_present"
  )
  expect_error(
    ci1415_run_campaign_shard(
      "CI14", 1L, 1L, "different-source-sha", out_path, runner = fake_runner
    ),
    "conflicting shard"
  )
})

test_that("generic production path delegates CI-14/15 to the validated adapter", {
  production <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote", "run-shard.R"
  )
  text <- paste(readLines(production, warn = FALSE), collapse = "\n")
  expect_match(text, "source(\"dev/interval-calibration/ci14-ci15/campaign-shard.R\")", fixed = TRUE)
  expect_match(text, "ci1415_run_campaign_shard", fixed = TRUE)
  expect_match(text, "inner$shard$outer_attempt", fixed = TRUE)
  expect_match(text, "ci1415_adapter_schema", fixed = TRUE)
  expect_match(text, "ci1415_failure", fixed = TRUE)
  expect_match(text, "ci1415_fit_health", fixed = TRUE)
})

test_that("CI-14/15 empty eligible denominators are not reported as zero MCSE", {
  manifest <- ci1415_attempt_manifest(
    "CI14", source_sha = "test-source-sha", rep_ids = 1L
  )
  attempts <- lapply(manifest$expected, function(identity) {
    ci1415_outer_attempt(
      manifest,
      identity$cell_id,
      identity$rep,
      "base_fit_failed"
    )
  })
  summary <- ci1415_summarise(ci1415_merge_attempts(manifest, attempts))
  expect_true(all(is.na(summary$coverage)))
  expect_true(all(is.na(summary$mcse)))
})
