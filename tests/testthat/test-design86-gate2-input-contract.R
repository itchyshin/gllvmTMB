test_that("Design 86 Gate-2R blocks input construction before Gate B", {
  skip_if_not_installed("jsonlite")
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  expect_error(.eva_gate2_input(86200002L), "not signed for runner invocation")
})

test_that("Design 86 Gate-2 private receipt checks reject drift and write JSON null", {
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  fixture <- .eva_gate2_file()
  altered <- tempfile(fileext = ".json")
  writeLines(sub("G2R_V1_UNSIGNED_CANDIDATE", "MUTATED", readLines(fixture, warn = FALSE)), altered)
  expect_error(.eva_read_gate2_parameters(altered), "candidate schema")
  p <- .eva_read_gate2_parameters()
  p$replicates$expanded_data_generation_seeds[[1L]] <- 1L
  expect_error(.d86_validate_gate2_seed_receipt(p), "seed receipt")
  receipt <- tempfile(fileext = ".json")
  .d86_write_json_once(list(missing = NA_real_), receipt)
  expect_match(paste(readLines(receipt, warn = FALSE), collapse = "\n"), '"missing": null', fixed = TRUE)
  expect_false(grepl('"NA"', paste(readLines(receipt, warn = FALSE), collapse = "\n"), fixed = TRUE))
})

test_that("Design 86 Gate-2 runner retains all optimizer stages without a DGP", {
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  obj <- list(
    par = c(alpha = 0, beta = 0),
    fn = function(parameter) sum(parameter ^ 2),
    gr = function(parameter) 2 * parameter
  )
  control <- list(nlminb_eval_max = 20L, nlminb_iter_max = 20L,
                  bfgs_maxit = 20L, bfgs_reltol = 1e-12)
  fit <- .d86_eva_fit_start(obj, c(alpha = 1, beta = -1), control)
  expect_length(fit$stages, 4L)
  required <- c("stage", "optimizer", "state", "parameter", "objective", "max_abs_gradient",
                "convergence", "message", "counts")
  expect_equal(vapply(fit$stages, `[[`, character(1), "stage"),
               c("nlminb_1", "nlminb_2", "nlminb_3", "bfgs"))
  for (stage in fit$stages) {
    expect_named(stage, required)
    expect_true(stage$state %in% c("attempted", "error", "skipped_after_failure"))
    expect_named(stage$counts, c("function", "gradient"))
  }
  expect_true(all(vapply(fit$stages, function(x) is.finite(x$objective), logical(1))))
})

test_that("Design 86 Gate-2 runner marks later stages skipped after an error", {
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  obj <- list(par = c(alpha = 0), fn = function(parameter) stop("controlled failure"),
              gr = function(parameter) 0)
  control <- list(nlminb_eval_max = 2L, nlminb_iter_max = 2L,
                  bfgs_maxit = 2L, bfgs_reltol = 1e-12)
  fit <- .d86_eva_fit_start(obj, 0, control)
  expect_equal(vapply(fit$stages, `[[`, character(1), "state"),
               c("error", "skipped_after_failure", "skipped_after_failure", "skipped_after_failure"))
})

test_that("Design 86 Gate-2 clean-tree guard rejects dirty provenance before a run", {
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  original <- .d86_git_status_porcelain
  assign(".d86_git_status_porcelain", function(root) " M dirty", envir = environment(.d86_assert_clean_tree))
  on.exit(assign(".d86_git_status_porcelain", original, envir = environment(.d86_assert_clean_tree)), add = TRUE)
  expect_error(.d86_assert_clean_tree(getwd()), "dirty source tree")
})

test_that("Design 86 Gate-2 provenance snapshot is stable before output writes", {
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  original <- .d86_git_status_porcelain
  env <- environment(.d86_assert_clean_tree)
  assign(".d86_git_status_porcelain", function(root) character(), envir = env)
  on.exit(assign(".d86_git_status_porcelain", original, envir = env), add = TRUE)
  snapshot <- .d86_source_receipt(.d86_root(), test_path("..", "..", "dev", "design86-gate2-eva-runner.R"))
  assign(".d86_git_status_porcelain", function(root) "?? later-output", envir = env)
  expect_true(snapshot$source_tree_clean)
  expect_error(.d86_assert_clean_tree(getwd()), "dirty source tree")
})

test_that("Design 86 Gate-2 Laplace provenance hashes its live sources", {
  source(test_path("..", "..", "dev", "design86-gate2-laplace-runner.R"), local = TRUE)
  root <- .d86_laplace_root()
  receipt <- .d86_source_receipt(
    root, test_path("..", "..", "dev", "design86-gate2-laplace-runner.R"),
    engine_source_path = file.path(root, "src", "gllvmTMB.cpp"),
    driver_source_path = file.path(root, "R", "fit-multi.R")
  )
  expect_identical(receipt$engine_source_sha256, .d86_sha256_file(file.path(root, "src", "gllvmTMB.cpp")))
  expect_identical(receipt$driver_source_sha256, .d86_sha256_file(file.path(root, "R", "fit-multi.R")))
})
