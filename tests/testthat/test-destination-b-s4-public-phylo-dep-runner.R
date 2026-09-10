test_that("S4 public phylo_dep receipt runner is present", {
  expect_true(file.exists(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R")))
})

test_that("S4 public phylo_dep receipt refuses malformed endpoints and duplicate output", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  targets <- environment$s4_public_phylo_dep_targets()
  payload <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_identical(environment$s4_public_phylo_dep_validate_endpoints(payload)$target_names, targets)
  payload$target_names[7] <- "wrong"
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(payload), "target/order mismatch")
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(list(target_names = targets)), "dangling endpoint output")
  ordered <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  ordered$native_upper[1] <- ordered$native_lower[1]
  ordered$julia_upper[1] <- ordered$julia_lower[1]
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(ordered), "ordered endpoints")
  expect_true(is.function(environment$s4_public_phylo_dep_validate_frozen_manifest))
  malformed <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  malformed$target_names[2] <- malformed$target_names[1]
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = seq_along(targets)[-1], native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = c(NA_real_, 2:7), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets), julia_upper = seq_along(targets) + 1)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "target/order mismatch")
  malformed <- list(target_names = targets, native_lower = seq_along(targets), native_upper = seq_along(targets) + 1, julia_lower = seq_along(targets) + 1, julia_upper = seq_along(targets) + 2)
  expect_error(environment$s4_public_phylo_dep_validate_endpoints(malformed), "tolerance exceeded")
  path <- tempfile(fileext = ".json")
  withr::defer(unlink(path))
  expect_identical(environment$s4_public_phylo_dep_write_once(list(ok = TRUE), path), path)
  expect_error(environment$s4_public_phylo_dep_write_once(list(ok = FALSE), path), "refusing to overwrite")
  cat("S4_PUBLIC_PHYLO_DEP_RUNNER_CONTRACT_PASS\n")
})
