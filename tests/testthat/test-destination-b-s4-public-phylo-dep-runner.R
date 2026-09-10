test_that("S4 public phylo_dep receipt runner is present", {
  expect_true(file.exists(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R")))
})

test_that("S4 runner selects its own immutable build seal", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  repository <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  expect_true(is.function(environment$s4_public_phylo_dep_s4_seal_path))
  expect_true(is.function(environment$s4_public_phylo_dep_read_s4_seal))
  expect_match(
    environment$s4_public_phylo_dep_s4_seal_path(repository),
    "destination-b-s4-phylo-dep-build-seal.json$"
  )
  seal <- environment$s4_public_phylo_dep_read_s4_seal(repository)
  expect_identical(seal$binary_identity$source_dll$sha256,
                   "eba1d3c5d5c26303f0e730a87ee70a627eb508c35f9419610fad08e37ccbb2f8")
  forged <- tempfile(fileext = ".json")
  withr::defer(unlink(forged))
  payload <- jsonlite::read_json(environment$s4_public_phylo_dep_s4_seal_path(repository), simplifyVector = FALSE)
  payload$source_snapshot$archive$sha256 <- paste(rep("0", 64), collapse = "")
  jsonlite::write_json(payload, forged, auto_unbox = TRUE)
  expect_error(environment$s4_public_phylo_dep_read_s4_seal(repository, forged), "source archive identity mismatch")
  payload <- jsonlite::read_json(environment$s4_public_phylo_dep_s4_seal_path(repository), simplifyVector = FALSE)
  payload$binary_identity$source_dll$uuid <- "00000000-0000-0000-0000-000000000000"
  jsonlite::write_json(payload, forged, auto_unbox = TRUE)
  expect_error(environment$s4_public_phylo_dep_read_s4_seal(repository, forged), "source DLL identity mismatch")
})

test_that("S4 public phylo_dep receipt runner uses ASCII Julia string literals", {
  environment <- new.env(parent = baseenv())
  withr::local_envvar(GLLVM_S4_PUBLIC_PHYLO_DEP_DEFINE_ONLY = "1")
  withr::local_options(useFancyQuotes = TRUE)
  source(testthat::test_path("run-destination-b-s4-public-phylo-dep-isolated.R"), local = environment)
  literal <- environment$s4_public_phylo_dep_julia_literal(tempdir())
  expect_identical(literal, paste0('"', normalizePath(tempdir()), '"'))
  expect_false(grepl("[\u201c\u201d]", literal))
  code <- paste0("import Pkg; Pkg.activate(", literal, "); println(\"ok\")")
  args <- environment$s4_public_phylo_dep_julia_args(code)
  expect_identical(args[1:3], c("--startup-file=no", "--project", "-e"))
  expect_identical(args[[4L]], shQuote(code))
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
  expect_true(is.function(environment$s4_public_phylo_dep_validate_embedded_julia_runtime))
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
