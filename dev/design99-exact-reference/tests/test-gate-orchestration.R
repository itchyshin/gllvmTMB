library(testthat)

d99_orchestration_root <- {
  wd <- normalizePath(getwd(), mustWork = TRUE)
  candidates <- c(
    wd,
    file.path(wd, ".."),
    file.path(wd, "..", ".."),
    file.path(wd, "..", "..", ".."),
    file.path(wd, "dev", "design99-exact-reference")
  )
  hit <- candidates[file.exists(file.path(candidates, "scripts", "run-mechanical-gates.R"))][1L]
  normalizePath(hit, mustWork = TRUE)
}
d99_orchestration_script <- function(name) file.path(d99_orchestration_root, "scripts", name)
d99_orchestration_file <- function(...) file.path(d99_orchestration_root, ...)
d99_orchestration_run <- function(name, args) {
  suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", d99_orchestration_script(name), args), stdout = TRUE, stderr = TRUE))
}

test_that("mechanical and benchmark control paths write only NON_EVIDENCE temporary receipts", {
  root <- tempfile("d99-orchestration-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  out <- d99_orchestration_run("run-mechanical-gates.R", c("--output-root", root, "--mock-pass"))
  expect_null(attr(out, "status"), info = paste(out, collapse = "\n"))
  mechanical <- jsonlite::fromJSON(file.path(root, "mechanical-gates.json"))
  expect_identical(mechanical$mode, "NON_EVIDENCE")
  expect_true(mechanical$test_mode)
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
  out <- d99_orchestration_run("benchmark-non-evidence.R", c("--output-root", root, "--mock-elapsed-s", "0.01"))
  expect_null(attr(out, "status"))
  route <- jsonlite::fromJSON(file.path(root, "compute-route.json"))
  expect_identical(route$mode, "NON_EVIDENCE")
  expect_false(route$approved_fixture_seed_used)
  expect_false(route$real_uuid_used)
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
})

test_that("fixed-coordinate certified-interval failure sentinel stops before a receipt", {
  root <- tempfile("d99-orchestration-sentinel-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  out <- d99_orchestration_run("run-mechanical-gates.R", c(
    "--output-root", root, "--mock-pass", "--inject-fixed-coordinate-failure"
  ))
  expect_false(is.null(attr(out, "status")))
  expect_match(paste(out, collapse = "\n"), "certified-interval failure sentinel")
  expect_false(file.exists(file.path(root, "mechanical-gates.json")))
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
  expect_false(file.exists(file.path(root, "frozen-fixture.json")))
})

test_that("real controls fail closed before fixture materialization or worker launch", {
  root <- tempfile("d99-orchestration-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  out <- d99_orchestration_run("freeze-fixture.R", c("--output-root", root, "--gate-receipt", file.path(root, "missing.json")))
  expect_false(is.null(attr(out, "status")))
  expect_false(file.exists(file.path(root, "frozen-fixture.json")))
  out <- d99_orchestration_run("prepare-real-run.R", c("--output-root", root, "--fixture-root", root, "--compute-route", file.path(root, "missing.json")))
  expect_false(is.null(attr(out, "status")))
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
  out <- d99_orchestration_run("run-real-graph.R", c("--output-root", root))
  expect_false(is.null(attr(out, "status")))
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
})

test_that("test-only dry-run prepares 208 valid immutable inputs in a temporary git root", {
  repo <- tempfile("d99-prepare-repo-")
  fixture_root <- tempfile("d99-prepare-fixture-")
  output_root <- tempfile("d99-prepare-output-")
  unlink(output_root, recursive = TRUE)
  on.exit(unlink(c(repo, fixture_root, output_root), recursive = TRUE), add = TRUE)
  dir.create(file.path(repo, "docs", "design"), recursive = TRUE)
  dir.create(fixture_root, recursive = TRUE)
  writeLines("temporary contract", file.path(repo, "docs", "design", "99-exact-q2-reference-stabilization.md"))
  suppressWarnings(system2("git", c("init", repo), stdout = TRUE, stderr = TRUE))
  suppressWarnings(system2("git", c("-C", repo, "config", "user.email", "test@example.invalid"), stdout = TRUE, stderr = TRUE))
  suppressWarnings(system2("git", c("-C", repo, "config", "user.name", "d99test"), stdout = TRUE, stderr = TRUE))
  suppressWarnings(system2("git", c("-C", repo, "add", "."), stdout = TRUE, stderr = TRUE))
  commit <- suppressWarnings(system2("git", c("-C", repo, "commit", "--no-gpg-sign", "-m", "temporary-contract"), stdout = TRUE, stderr = TRUE))
  expect_null(attr(commit, "status"), info = paste(commit, collapse = "\n"))
  expect_identical(system2("git", c("-C", repo, "status", "--porcelain"), stdout = TRUE, stderr = TRUE), character())

  starts <- setNames(lapply(c("C12", "C34"), function(chart) {
    setNames(lapply(c("cap4", "cap8"), function(cap) {
      setNames(lapply(c("fixed", "spectral", "truth"), function(start) as.list(rep(0, 17L))), c("fixed", "spectral", "truth"))
    }), c("cap4", "cap8"))
  }), c("C12", "C34"))
  counts <- as.list(c(1L, rep.int(0L, 63L)))
  prefixes <- setNames(lapply(c("N128", "N512", "N2048"), function(key) {
    list(pattern_counts = counts, starts = starts)
  }), c("N128", "N512", "N2048"))
  fixture <- list(schema = "d99-frozen-fixture-v1", status = "FROZEN", seed = 9902401L,
    response_hash = "temporary-fixture", prefix_hashes = as.list(setNames(rep("temporary", 3L), names(prefixes))),
    pattern_count_hashes = as.list(setNames(rep("temporary", 3L), names(prefixes))), prefixes = prefixes)
  route <- list(schema = "d99-compute-route-v1", status = "PASS", mode = "NON_EVIDENCE",
    approved_fixture_seed_used = FALSE, real_uuid_used = FALSE, mock_elapsed = FALSE, route = "LOCAL")
  jsonlite::write_json(fixture, file.path(fixture_root, "frozen-fixture.json"), auto_unbox = TRUE)
  jsonlite::write_json(route, file.path(fixture_root, "compute-route.json"), auto_unbox = TRUE)
  writeLines("temporary prelock receipt", file.path(fixture_root, "prelock.txt"))

  out <- d99_orchestration_run("prepare-real-run.R", c(
    "--test-mode", "--dry-run", "--repo-root", repo, "--output-root", output_root,
    "--fixture-root", fixture_root, "--compute-route", file.path(fixture_root, "compute-route.json"),
    "--mock-prelock-receipt", file.path(fixture_root, "prelock.txt")
  ))
  expect_null(attr(out, "status"), info = paste(out, collapse = "\n"))
  expect_false(file.exists(file.path(output_root, "REAL_RUN.json")))
  expect_true(file.exists(file.path(output_root, "preflight.json")))
  source(d99_orchestration_file("R", "records.R"))
  source(d99_orchestration_file("R", "task-graph.R"))
  manifest <- d99_read_json(file.path(output_root, "preflight.json"))
  graph <- d99_build_task_graph(manifest$run_id)
  inputs <- lapply(graph, function(task) d99_read_json(d99_input_path(output_root, task$task_id)))
  expect_length(inputs, 208L)
  expect_true(all(mapply(d99_validate_input, inputs)))
  optimizer <- vapply(graph, function(task) task$task_class %in% c("A-H9", "A-H15", "A-H31", "B-H15", "B-H31"), logical(1))
  expect_true(all(vapply(inputs[optimizer], function(input) length(input$start_coordinates) == 3L, logical(1))))
  expect_true(all(vapply(inputs[!optimizer], function(input) length(input$start_coordinates) == 0L, logical(1))))
})

test_that("orchestrators preserve the freeze and aggregation boundaries", {
  freeze <- paste(readLines(d99_orchestration_script("freeze-fixture.R"), warn = FALSE), collapse = "\n")
  prepare <- paste(readLines(d99_orchestration_script("prepare-real-run.R"), warn = FALSE), collapse = "\n")
  runner <- paste(readLines(d99_orchestration_script("run-real-graph.R"), warn = FALSE), collapse = "\n")
  expect_match(freeze, "9902401")
  expect_match(freeze, "test_mode")
  expect_match(prepare, "d99_create_real_run")
  expect_match(prepare, "prelock")
  expect_match(prepare, "208 immutable inputs")
  mechanical <- paste(readLines(d99_orchestration_script("run-mechanical-gates.R"), warn = FALSE), collapse = "\n")
  expect_match(mechanical, "identical\\(dim\\(J\\), c\\(18L, 17L\\)\\)")
  expect_match(mechanical, "d99_oracle_fixed_coordinate_comparator")
  expect_match(mechanical, "backend_success")
  expect_match(mechanical, "tail_error_bounds")
  expect_match(mechanical, "agh_inside_nested")
  expect_match(mechanical, "agh_inside_cubature")
  expect_match(mechanical, "intervals_overlap")
  expect_match(runner, "scientific <- setdiff")
  expect_match(runner, "--exclude-finalizer")
  expect_match(runner, "finalize.R")
  expect_false(grepl("fixture.R", runner, fixed = TRUE))
})
