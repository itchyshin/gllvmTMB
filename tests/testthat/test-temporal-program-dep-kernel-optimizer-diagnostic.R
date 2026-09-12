.temporal_dep_kernel_optimizer_dev_path <- function(...) {
  testthat::test_path("..", "..", "dev", "temporal-program", ...)
}

test_that("dep-kernel optimizer diagnostic preserves the failed qualification boundary", {
  script <- .temporal_dep_kernel_optimizer_dev_path(
    "diagnose-dep-kernel-occasion-optimizer.R"
  )
  skip_if_not(file.exists(script), "developer-only optimizer diagnostic is unavailable")
  source(script, local = environment())
  expect_equal(.temporal_dep_kernel_optimizer_target(),
    list(phi = 0, seed = 2609373L, n_series = 80L, n_time = 32L))
  provenance <- .temporal_dep_kernel_optimizer_provenance()
  expect_named(provenance, c("schema", "source_commit", "r_version", "platform", "tmb_version", "source_tree_clean"))
  expect_error(.temporal_dep_kernel_optimizer_output(tempfile()),
    "new RDS")
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_false(grepl("simulate\\.gllvmTMB", source_text))
  expect_match(source_text, "hessian_error_message")
  expect_match(source_text, "native_gradient")
  expect_match(source_text, "independent_block_gradient")
  expect_match(source_text, "cannot replace the failed qualification")
})
