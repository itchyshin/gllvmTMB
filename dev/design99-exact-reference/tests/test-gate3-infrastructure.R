library(testthat)

d99_test_repo <- {
  wd <- normalizePath(getwd(), mustWork = TRUE)
  candidates <- c(wd, file.path(wd, "..", "..", ".."))
  hit <- candidates[file.exists(file.path(
    candidates, "dev", "design99-exact-reference", "R", "records.R"
  ))][1L]
  normalizePath(hit, mustWork = TRUE)
}
d99_test_file <- function(...) file.path(d99_test_repo, ...)

test_that("Design-99 frozen graph has the exact declared dependency structure", {
  source(d99_test_file("dev/design99-exact-reference/R/records.R"))
  source(d99_test_file("dev/design99-exact-reference/R/task-graph.R"))
  graph <- d99_build_task_graph("NON_EVIDENCE")
  expect_length(graph, 208L)
  expect_equal(sum(vapply(graph, `[[`, character(1), "task_class") == "cell-evaluator"), 12L)
  expect_equal(sum(vapply(graph, `[[`, character(1), "task_class") == "oracle"), 12L)
  expect_equal(sum(vapply(graph, `[[`, character(1), "task_class") == "n-evaluator"), 3L)
  expect_identical(graph[["finalizer"]]$dependencies, c("N-128", "N-512", "N-2048"))
  expect_equal(graph[["A-128-C12-fixed-cap4-H9"]]$timeout_s, 1800L)
  expect_equal(graph[["B-2048-C34-truth-cap8-H31"]]$timeout_s, 14400L)
  input <- d99_input_for_task(
    graph[["A-128-C12-fixed-cap4-H9"]], "contract", list(worker = "hash"),
    list(rules = list(H9 = list(nodes = c(-1, 1), weights = c(.5, .5), node_hash = "n", weight_hash = "w"))),
    list(prefix_hashes = list(N128 = "fixture-hash"), pattern_count_hashes = list(N128 = "count-hash"))
  )
  expect_true(d99_validate_input(input))
})

test_that("immutable artefacts reject duplicate and partial terminals", {
  source(d99_test_file("dev/design99-exact-reference/R/records.R"))
  root <- tempfile("d99-non-evidence-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  path <- file.path(root, "records", "x.json")
  d99_write_exclusive_json(path, list(a = 1L))
  expect_error(d99_write_exclusive_json(path, list(a = 2L)), "Refusing to overwrite")
  d99_write_exclusive_text(file.path(root, "records", "partial.json"), "{")
  expect_null(d99_read_json(file.path(root, "records", "partial.json")))
  expect_false(d99_validate_terminal(d99_read_json(file.path(root, "records", "partial.json"))))
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
})

test_that("supervision preserves crash timeout interruption orphan and sibling failure as non-evidence", {
  source(d99_test_file("dev/design99-exact-reference/R/records.R"))
  source(d99_test_file("dev/design99-exact-reference/R/task-graph.R"))
  root <- tempfile("d99-non-evidence-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  graph <- d99_build_task_graph("NON_EVIDENCE")
  task <- graph[["A-128-C12-fixed-cap4-H9"]]
  for (status in c("CRASH", "TIMEOUT", "INTERRUPTED", "ORPHAN", "INFRASTRUCTURE_FAILURE")) {
    p <- tempfile("d99-status-")
    d99_write_terminal(p, task, status, "NON_EVIDENCE")
    for (id in setdiff(names(graph), task$task_id)) d99_write_terminal(p, graph[[id]], "PASS", "NON_EVIDENCE")
    expect_identical(d99_classify_terminals(p, graph), "INFRASTRUCTURE_INCOMPLETE")
  }
  cell <- graph[["cell-128-A-C12"]]
  for (id in cell$dependencies) d99_write_terminal(root, graph[[id]], "PASS", "NON_EVIDENCE")
  cell2 <- graph[["cell-128-B-C12"]]
  failed <- graph[[cell2$dependencies[[1L]]]]
  d99_write_terminal(root, failed, "INFRASTRUCTURE_FAILURE", "NON_EVIDENCE")
  for (id in cell2$dependencies[-1L]) d99_write_terminal(root, graph[[id]], "PASS", "NON_EVIDENCE")
  expect_identical(d99_dependency_state(root, cell2, graph)$state, "blocked")
  d99_write_exclusive_json(d99_launch_path(root, task$task_id), list(schema = "d99-launch-v1"))
  d99_reconcile_unfinished_launches(root, graph)
  expect_identical(d99_read_terminal(root, task)$status, "ORPHAN")
  expect_true(file.exists(d99_launch_path(root, task$task_id)))
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
})

test_that("finalizer stays aggregation-only and N128 blocks are representable", {
  finalize <- paste(readLines(d99_test_file("dev/design99-exact-reference/scripts/finalize.R"), warn = FALSE), collapse = "\n")
  expect_false(grepl("source\\([^)]*(fit-worker|objective|fixture)", finalize, ignore.case = TRUE))
  source(d99_test_file("dev/design99-exact-reference/R/records.R"))
  source(d99_test_file("dev/design99-exact-reference/R/task-graph.R"))
  root <- tempfile("d99-non-evidence-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  graph <- d99_build_task_graph("NON_EVIDENCE")
  cell <- graph[["cell-128-A-C12"]]
  d99_write_terminal(root, cell, "DIAGNOSTIC_N128_NONINTERIOR", "NON_EVIDENCE")
  oracle <- graph[["oracle-128-A-C12"]]
  expect_identical(d99_dependency_state(root, oracle, graph)$state, "blocked")
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
})
