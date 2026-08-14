test_that("historical MSPL uncertainty runner keeps only its Hessian routes", {
  runner <- paste(
    readLines(test_path("..", "..", "inst", "sim", "lane-b-uncertainty",
                        "run-mspl-uncertainty.R")),
    collapse = "\n"
  )

  expect_match(runner, 'c\\("both", "hessian_only"\\)')
  expect_match(runner, 'profile_lower_status = "not_run"')
  expect_match(runner, "file.rename\\(tmp, out\\)")
  expect_match(runner, "Receipt set does not exactly match the frozen manifest")
  expect_match(runner, "not_run_fit_error")
})

test_that("historical Hessian runner retains failures and rejects stale provenance", {
  runner_path <- test_path("..", "..", "inst", "sim", "lane-b-uncertainty",
                           "run-mspl-uncertainty.R")
  root <- tempfile("mspl-hessian-runner-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(file.path(root, "raw"), recursive = TRUE)
  manifest <- data.frame(
    cell_id = "U001", link = "logit", regime = "baseline", beta_shift = 0,
    n_rep = 1L, manifest_version = "test", seed_base = 1L,
    procedure = "hessian_only", campaign_id = "campaign-a", source_sha = "source-a"
  )
  utils::write.csv(manifest, file.path(root, "manifest.csv"), row.names = FALSE)
  receipt <- data.frame(
    cell_id = rep("U001", 3L), replicate_id = 1L, target = 1:3,
    truth = c(-0.5, 0.1, 0.55), estimate = c(-0.5, 0.1, 0.55),
    fit_status = "ok", hessian_status = "hessian_non_pd",
    objective_source = "fit$tmb_obj (penalised LA-MSPL)",
    hessian_method = NA_character_, hessian_rank = NA_integer_,
    minimum_eigenvalue = NA_real_, profile_lower_status = "not_run",
    profile_upper_status = "not_run", hessian_se = NA_real_,
    hessian_covers = FALSE, profile_covers = FALSE,
    procedure = "hessian_only", campaign_id = "campaign-a", source_sha = "source-a",
    message = "forced failure"
  )
  utils::write.csv(receipt, file.path(root, "raw", "U001-0001.csv"), row.names = FALSE)
  cmd <- c("--vanilla", runner_path, "summarise", "--root", root)
  expect_silent(system2(file.path(R.home("bin"), "Rscript"), cmd))
  summary <- utils::read.csv(file.path(root, "summary.csv"), stringsAsFactors = FALSE)
  expect_true(all(summary$hessian_available == 0))
  expect_true(all(summary$hessian_coverage_unconditional == 0))

  receipt$source_sha <- "stale-source"
  utils::write.csv(receipt, file.path(root, "raw", "U001-0001.csv"), row.names = FALSE)
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), cmd, stdout = TRUE, stderr = TRUE
  ))
  expect_identical(attr(output, "status"), 1L)
  expect_match(paste(output, collapse = "\n"), "Receipt provenance does not match")
})
