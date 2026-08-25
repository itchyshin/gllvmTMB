ci10_kernel <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci10",
  "ci10-kernels.R"
)
source(ci10_kernel, local = TRUE)
.ci10_source_sha <- "TEST-SOURCE-SHA"

.ci10_all_covered <- function(manifest) {
  ci10_target_results(
    manifest,
    c(
      multiple_r = "covered",
      `contrast_r:cat:2` = "covered",
      `contrast_r:cat:3` = "covered"
    )
  )
}

test_that("CI-10 freezes 18 cells and exactly 90000 canonical outer identities", {
  spec <- ci10_campaign_spec()
  expect_equal(nrow(spec$cells), 18L)
  expect_equal(spec$n_sim, 5000L)
  expect_equal(spec$n_boot, 499L)
  expect_equal(sort(unique(spec$cells$partner)), c("binomial", "gaussian"))
  expect_equal(sort(unique(spec$cells$N)), c(50L, 150L, 500L))
  expect_equal(sort(unique(spec$cells$target_multiple_r)), c(0.2, 0.5, 0.8))
  expect_equal(
    vapply(spec$targets, `[[`, character(1), "method"),
    c("bootstrap", "profile", "profile")
  )
  expect_error(ci10_attempt_manifest(spec), "source_sha")
  full <- ci10_attempt_manifest(spec, source_sha = .ci10_source_sha)
  expect_equal(length(full$expected), 90000L)
  expect_equal(full$expected[[1L]]$seed, ci10_rep_seed(20260718L, 1L, 1L))
  expect_equal(
    full$historical_seed_exception$seed,
    ci10_rep_seed(20260718L, 18L, 4381L)
  )
  tampered <- full
  tampered$source_sha <- "OTHER-SOURCE-SHA"
  expect_error(ci10_validate_manifest(tampered), "modified after freezing")
  expect_error(
    ci10_validate_method_estimand("multiple_r", "profile"),
    "must use bootstrap"
  )
})

test_that("CI-10 outer attempts require one base state and complete eligible target payload", {
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = .ci10_source_sha
  )
  payload <- .ci10_all_covered(manifest)
  expect_error(
    ci10_outer_attempt(manifest, 1L, 1L, "eligible", payload[-1L]),
    "complete target payload"
  )
  expect_error(
    ci10_outer_attempt(
      manifest,
      1L,
      1L,
      "eligible",
      list(payload[[1L]], payload[[1L]], payload[[3L]])
    ),
    "each frozen target"
  )
  expect_error(
    ci10_outer_attempt(manifest, 1L, 1L, "base_fit_failed", payload),
    "cannot carry target results"
  )
  expect_error(
    ci10_outer_attempt(manifest, 1L, 1L, "eligible", NULL),
    "complete target payload"
  )
})

test_that("CI-10 merger rejects missing duplicate and conflicting canonical outer rows", {
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1:2,
    source_sha = .ci10_source_sha
  )
  good <- list(
    ci10_outer_attempt(
      manifest,
      1L,
      1L,
      "eligible",
      .ci10_all_covered(manifest)
    ),
    ci10_outer_attempt(
      manifest,
      1L,
      2L,
      "eligible",
      .ci10_all_covered(manifest)
    )
  )
  expect_error(ci10_merge_attempts(manifest, good[-1L]), "missing canonical")
  expect_error(
    ci10_merge_attempts(manifest, c(good, list(good[[1L]]))),
    "duplicate canonical"
  )
  conflict <- good[[1L]]
  conflict$target_results[[1L]]$outcome <- "miss"
  expect_error(
    ci10_merge_attempts(manifest, c(good, list(conflict))),
    "conflicting canonical"
  )
  seed_conflict <- good[[1L]]
  seed_conflict$seed <- seed_conflict$seed + 1L
  expect_error(
    ci10_merge_attempts(manifest, list(seed_conflict, good[[2L]])),
    "seed conflicts"
  )
})

test_that("CI-10 keeps every outer row while CI failures are target misses", {
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1:3,
    source_sha = .ci10_source_sha
  )
  attempts <- list(
    ci10_outer_attempt(
      manifest,
      1L,
      1L,
      "eligible",
      .ci10_all_covered(manifest)
    ),
    ci10_outer_attempt(manifest, 1L, 2L, "base_fit_failed"),
    ci10_outer_attempt(
      manifest,
      1L,
      3L,
      "eligible",
      ci10_target_results(
        manifest,
        c(
          multiple_r = "ci_failed",
          `contrast_r:cat:2` = "covered",
          `contrast_r:cat:3` = "miss"
        )
      )
    )
  )
  summary <- ci10_summarise(ci10_merge_attempts(manifest, attempts))
  mr <- summary$targets[summary$targets$target_id == "multiple_r", ]
  expect_equal(mr$n_outer, 3L)
  expect_equal(mr$n_eligible, 2L)
  expect_equal(mr$n_ci_failed, 1L)
  expect_equal(mr$coverage, 1 / 2)
  expect_equal(mr$base_fit_failed, 1L)
  expect_equal(mr$availability_rate, 2 / 3)
  expect_equal(mr$mcse, sqrt(stats::var(c(1, 0)) / 2))
})

test_that("CI-10 retries only infrastructure outer failures and scientific base failures are terminal", {
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = .ci10_source_sha
  )
  first <- ci10_outer_attempt(manifest, 1L, 1L, "infrastructure_failure")
  retry <- ci10_outer_attempt(
    manifest,
    1L,
    1L,
    "eligible",
    .ci10_all_covered(manifest),
    attempt_version = 2L
  )
  expect_silent(ci10_validate_retry_history(list(first, retry)))
  scientific <- ci10_outer_attempt(manifest, 1L, 1L, "scientific_base_failure")
  expect_error(
    ci10_validate_retry_history(list(scientific, retry)),
    "scientific failure is terminal"
  )
})

test_that("CI-10 promotion is fail-closed per target and availability is report-only", {
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1:100,
    source_sha = .ci10_source_sha
  )
  covered <- lapply(manifest$expected, function(x) {
    ci10_outer_attempt(
      manifest,
      x$cell_id,
      x$rep,
      "eligible",
      .ci10_all_covered(manifest)
    )
  })
  pass <- ci10_promote(manifest, covered)
  expect_false(pass$promotion$promote)
  expect_false(pass$promotion$complete_campaign)
  expect_true(pass$promotion$target_gates_pass)
  expect_true(all(pass$targets$coverage >= 0.94))
  expect_true(all(pass$targets$coverage - 2 * pass$targets$mcse >= 0.94))

  misses <- covered
  for (i in seq_len(10L)) {
    misses[[i]]$target_results[[1L]]$outcome <- "miss"
  }
  fail <- ci10_promote(manifest, misses)
  expect_false(fail$promotion$promote)
  expect_match(fail$promotion$reason, "coverage gate")

  unavailable <- covered
  unavailable[[1L]] <- ci10_outer_attempt(manifest, 1L, 1L, "base_fit_failed")
  availability_only <- ci10_promote(manifest, unavailable)
  expect_false(availability_only$promotion$promote)
  expect_true(availability_only$promotion$target_gates_pass)
  expect_equal(availability_only$targets$availability_rate[1L], 0.99)

  scientific <- covered
  scientific[[1L]] <- ci10_outer_attempt(
    manifest,
    1L,
    1L,
    "scientific_base_failure"
  )
  scientific_report <- ci10_promote(manifest, scientific)
  expect_false(scientific_report$promotion$promote)
  expect_true(scientific_report$promotion$target_gates_pass)
  expect_equal(scientific_report$targets$scientific_failures[1L], 1L)
})

test_that("CI-10 exact full manifest is the only promotable campaign shape", {
  full <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    source_sha = .ci10_source_sha
  )
  expect_true(ci10_manifest_is_complete_campaign(full))
  subset <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = 1L,
    rep_ids = 1:100,
    source_sha = .ci10_source_sha
  )
  expect_false(ci10_manifest_is_complete_campaign(subset))
})

test_that("CI-10's one-replicate preflight wrapper is parse-only under test", {
  smoke <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "ci10",
    "one-replicate-smoke.R"
  )
  expect_silent(parse(smoke))
  text <- paste(readLines(smoke, warn = FALSE), collapse = "\n")
  expect_match(text, "cross-family-coverage.R", fixed = TRUE)
  expect_match(text, ".xfc_one_rep", fixed = TRUE)
  expect_match(text, "n_boot", fixed = TRUE)
  expect_match(text, "outer-attempt.rds", fixed = TRUE)
})

test_that("CI-10 production wrapper is cost-array only and binds adjacent provenance", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  runner <- paste(
    readLines(file.path(remote_root, "run-shard.R"), warn = FALSE),
    collapse = "\n"
  )
  batch <- paste(
    readLines(file.path(remote_root, "ci10-cost-array.sbatch"), warn = FALSE),
    collapse = "\n"
  )
  prepare <- paste(
    readLines(
      file.path(remote_root, "prepare-ci10-cost-array.sh"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(runner, "rep != 3L", fixed = TRUE)
  expect_match(runner, "n_boot = 499L", fixed = TRUE)
  expect_match(runner, "reps = 5L", fixed = TRUE)
  expect_match(runner, "adjacent runtime/provenance checks", fixed = TRUE)
  expect_match(batch, "#SBATCH --array=1-18%18", fixed = TRUE)
  expect_match(batch, "#SBATCH --time=00:30:00", fixed = TRUE)
  expect_match(batch, "#SBATCH --account=def-snakagaw", fixed = TRUE)
  expect_match(batch, "timeout --signal=TERM --kill-after=30s 28m", fixed = TRUE)
  expect_match(batch, 'cell_id" -ne "$SLURM_ARRAY_TASK_ID', fixed = TRUE)
  expect_match(batch, "attempt\" -ne 1", fixed = TRUE)
  expect_match(batch, "328d8abc9125ce1e7edbcdcdcb1a41f043488431", fixed = TRUE)
  expect_match(batch, "record-operational-timeout.R", fixed = TRUE)
  expect_match(batch, "INTERVAL_SESSION_RECEIPT", fixed = TRUE)
  expect_match(prepare, "sbatch --parsable", fixed = TRUE)
  expect_match(prepare, "INTERVAL_CALIBRATION_CI10_SUBMITTED_V1", fixed = TRUE)
  expect_match(
    prepare,
    "INTERVAL_CALIBRATION_CI10_SUBMISSION_FAILED_V1",
    fixed = TRUE
  )
  expect_match(
    prepare,
    "INTERVAL_CALIBRATION_CI10_SUBMISSION_AMBIGUOUS_V1",
    fixed = TRUE
  )
  expect_match(prepare, "task_manifest_sha256", fixed = TRUE)
  expect_match(prepare, "immutable root retained for review", fixed = TRUE)
  aggregate <- paste(
    readLines(
      file.path(remote_root, "aggregate-campaign.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(aggregate, "ci10-cost-array-submitted.tsv", fixed = TRUE)
  expect_match(aggregate, "submission-failed.tsv", fixed = TRUE)
  expect_match(aggregate, "submission-ambiguous.tsv", fixed = TRUE)
  expect_match(
    aggregate,
    "INTERVAL_CALIBRATION_CI10_SUBMITTED_V1",
    fixed = TRUE
  )
})

test_that("CI-10 Fir dispatch uses the backed-up home root when project file quota is full", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  scripts <- c(
    "deploy-approved-envelope.sh",
    "prepare-remote-host.sh",
    "prepare-ci10-cost-array.sh",
    "ci10-cost-array.sbatch"
  )
  text <- vapply(
    file.path(remote_root, scripts),
    function(path) paste(readLines(path, warn = FALSE), collapse = "\n"),
    character(1)
  )
  fir_root <- "/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25"

  expect_true(all(grepl(fir_root, text, fixed = TRUE)))
  expect_false(any(grepl("/project/def-snakagaw", text, fixed = TRUE)))
})

test_that("CI-10 Fir guards accept canonical numbered login hosts", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  prepare_host <- paste(
    readLines(file.path(remote_root, "prepare-remote-host.sh"), warn = FALSE),
    collapse = "\n"
  )
  prepare_array <- paste(
    readLines(
      file.path(remote_root, "prepare-ci10-cost-array.sh"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  expect_match(
    prepare_host,
    "fir:login[0-9]*.int.fir.alliancecan.ca",
    fixed = TRUE
  )
  expect_match(
    prepare_array,
    "login[0-9]*.int.fir.alliancecan.ca",
    fixed = TRUE
  )
})
