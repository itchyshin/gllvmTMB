cross_family_recovery_files <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  roots <- c(".", file.path("..", ".."), workspace)
  root <- roots[vapply(roots, function(x) {
    !is.na(x) && file.exists(file.path(
      x, "dev", "cross-family-lv-predictor", "recovery-campaign.R"
    ))
  }, logical(1L))][1L]
  testthat::skip_if(
    is.na(root),
    "cross-family LV recovery harness unavailable in source tarball"
  )
  c(
    campaign = file.path(
      root, "dev", "cross-family-lv-predictor", "recovery-campaign.R"
    ),
    summary = file.path(
      root, "dev", "cross-family-lv-predictor", "summarise-recovery.R"
    )
  )
}

source_cross_family_recovery <- function(env, include_summary = FALSE) {
  files <- cross_family_recovery_files()
  sys.source(files[["campaign"]], envir = env)
  if (isTRUE(include_summary)) {
    sys.source(files[["summary"]], envir = env)
  }
}

test_that("cross-family recovery plan freezes two r200 denominators", {
  env <- new.env(parent = globalenv())
  source_cross_family_recovery(env)
  plan <- env$cross_family_lv_plan()

  expect_equal(nrow(plan), 400L)
  expect_identical(unique(plan$cell_id), c(
    "continuous-unequal-scale-d2", "five-family-d3"
  ))
  expect_equal(as.integer(table(plan$cell_id)), c(200L, 200L))
  expect_identical(plan$task_id, seq_len(400L))
  expect_false(anyDuplicated(plan$seed) > 0L)
})

test_that("continuous fixture plants unequal family scales and valid targets", {
  env <- new.env(parent = globalenv())
  source_cross_family_recovery(env)
  fixture <- env$cross_family_lv_continuous_fixture(
    seed = 11L, n_units = 20L, reps = 2L
  )

  expect_identical(unname(fixture$truth$sigma_eps), c(0.25, 0.65))
  expect_length(fixture$truth$B_lv, 4L)
  expect_equal(dim(fixture$truth$Sigma_shared), c(4L, 4L))
  expect_equal(dim(fixture$truth$R_shared), c(4L, 4L))
  expect_true(all(is.finite(fixture$data$value)))
  expect_true(all(fixture$data$value[fixture$data$family == "l"] > 0))
})

test_that("retained attempt writes are immutable", {
  env <- new.env(parent = globalenv())
  source_cross_family_recovery(env)
  path <- tempfile("cross-family-attempt-", fileext = ".rds")

  expect_invisible(env$cross_family_lv_atomic_save(list(ok = TRUE), path))
  expect_error(
    env$cross_family_lv_atomic_save(list(ok = FALSE), path),
    "refusing to overwrite"
  )
})

test_that("retained r200 tasks require an exact source pin before fitting", {
  env <- new.env(parent = globalenv())
  source_cross_family_recovery(env)
  withr::local_envvar(CROSS_FAMILY_LV_PINNED_SHA = NA_character_)

  expect_error(
    env$cross_family_lv_run_task(
      1L, tempfile("cross-family-unpinned-"), n_reps = 200L
    ),
    "PINNED_SHA is required"
  )
})

test_that("reconciliation preserves planned and started denominators", {
  env <- new.env(parent = globalenv())
  source_cross_family_recovery(env, include_summary = TRUE)
  out <- tempfile("cross-family-ledger-")
  dir.create(file.path(out, "started"), recursive = TRUE)
  saveRDS(
    list(task_id = 1L),
    file.path(out, "started", "task-000001.rds")
  )

  result <- env$cross_family_lv_summarise(out, n_reps = 2L)
  expect_equal(nrow(result$ledger), 4L)
  expect_identical(result$ledger$status, c(
    "interrupted_missing_final", "planned_not_started",
    "planned_not_started", "planned_not_started"
  ))
  expect_identical(result$cell_summary$planned, c(2L, 2L))
  expect_identical(result$cell_summary$attempted, c(1L, 0L))
  expect_false(any(result$gates$denominator_pass))
})
