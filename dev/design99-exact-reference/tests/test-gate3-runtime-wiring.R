library(testthat)

d99_runtime_root <- {
  wd <- normalizePath(getwd(), mustWork = TRUE)
  candidates <- c(wd, file.path(wd, ".."), file.path(wd, "dev", "design99-exact-reference"))
  hit <- candidates[file.exists(file.path(candidates, "R", "records.R"))][1L]
  normalizePath(hit, mustWork = TRUE)
}
d99_runtime_file <- function(...) file.path(d99_runtime_root, ...)
d99_run_script <- function(script, args) {
  out <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", d99_runtime_file("scripts", script), args), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) cat(paste(out, collapse = "\n"), "\n")
  out
}

source(d99_runtime_file("R", "records.R"))
source(d99_runtime_file("R", "task-graph.R"))
source(d99_runtime_file("R", "numerics.R"))
source(d99_runtime_file("R", "charts.R"))
source(d99_runtime_file("R", "fixture.R"))

d99_wiring_input <- function(root, task, counts, rules) {
  fixture <- list(
    prefix_hashes = setNames(as.list(rep("NON_EVIDENCE", 3L)), c("N128", "N512", "N2048")),
    pattern_count_hashes = setNames(lapply(rep(list(counts), 3L), d99_sha256_object), c("N128", "N512", "N2048")),
    counts = setNames(rep(list(counts), 3L), c("N128", "N512", "N2048"))
  )
  input <- d99_input_for_task(task, "NON_EVIDENCE", list(runtime = "wiring"), list(rules = rules), fixture)
  input$mode <- "NON_EVIDENCE"
  d99_write_task_input(root, input)
}

d99_wiring_endpoint <- function(task, theta, beta, Lambda) {
  list(theta = theta, beta = beta, Lambda = Lambda, task = task[c("n", "route", "chart", "start", "guard")],
    invariants = list(beta = beta, Sigma = tcrossprod(Lambda), eig_positive = c(1, .1), population_probability = rep(.5, 6L)),
    health = list(ok = TRUE, metrics = list(objective_h31 = -1)))
}

test_that("NON_EVIDENCE cell, oracle, N evaluator, finalizer, and supervisor wire immutable records", {
  root <- tempfile("d99-runtime-non-evidence-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_false(file.exists(file.path(root, "REAL_RUN.json")))
  graph <- d99_build_task_graph("NON_EVIDENCE")
  rules <- lapply(c(9L, 15L, 21L, 31L), d99_gh_rule); names(rules) <- paste0("H", c(9L, 15L, 21L, 31L))
  counts <- c(1L, rep.int(0L, 63L))
  beta <- c(-.4, -.15, .05, .2, .35, .5)
  Lambda <- rbind(c(.5, 0), c(.1, .4), c(-.3, .2), c(.2, -.5), c(.25, .3), c(-.2, -.25))
  theta <- d99_chart_pack(beta, Lambda, "C12", 4)
  cell <- graph[["cell-128-A-C12"]]
  for (id in cell$dependencies) {
    endpoint_task <- graph[[id]]
    endpoint_input_hash <- d99_wiring_input(root, endpoint_task, counts, rules)
    endpoint_payload_hash <- d99_write_payload(root, id, d99_wiring_endpoint(endpoint_task, theta, beta, Lambda))
    d99_write_terminal(root, endpoint_task, "PASS", endpoint_input_hash, list(payload_hash = endpoint_payload_hash))
  }
  cell_input <- d99_wiring_input(root, cell, counts, rules)
  d99_run_script("cell-evaluator.R", c("--input", d99_input_path(root, cell$task_id), "--output-root", root))
  expect_identical(d99_read_terminal(root, cell)$status, "PASS")
  selected <- d99_read_json(d99_payload_path(root, cell$task_id))
  expect_true(is.character(selected$selected_task_id))

  oracle <- graph[["oracle-128-A-C12"]]
  d99_wiring_input(root, oracle, counts, rules)
  d99_run_script("oracle-worker.R", c("--input", d99_input_path(root, oracle$task_id), "--output-root", root))
  expect_true(d99_read_terminal(root, oracle)$status %in% c("PASS", "QUADRATURE_STABILITY_STOP"))
  if (identical(d99_read_terminal(root, oracle)$status, "PASS")) {
    expect_true(is.list(d99_read_json(d99_payload_path(root, oracle$task_id))$metrics))
  }

  n_root <- tempfile("d99-n-runtime-non-evidence-"); on.exit(unlink(n_root, recursive = TRUE), add = TRUE)
  n_task <- graph[["N-128"]]
  for (id in n_task$dependencies) {
    oracle_input_hash <- d99_wiring_input(n_root, graph[[id]], counts, rules)
    oracle_payload_hash <- d99_write_payload(n_root, id, list(ok = TRUE, selected_task_id = cell$dependencies[[1L]], endpoint = d99_wiring_endpoint(graph[[cell$dependencies[[1L]]]], theta, beta, Lambda)))
    d99_write_terminal(n_root, graph[[id]], "PASS", oracle_input_hash, list(payload_hash = oracle_payload_hash))
  }
  d99_wiring_input(n_root, n_task, counts, rules)
  d99_run_script("n-evaluator.R", c("--input", d99_input_path(n_root, n_task$task_id), "--output-root", n_root))
  expect_identical(d99_read_terminal(n_root, n_task)$status, "PASS")

  # A diagnostic N128 cell makes its dependent oracle block explicitly and
  # remains the sole exception accepted by the ordered final classifier.
  diag_root <- tempfile("d99-runtime-diagnostic-"); on.exit(unlink(diag_root, recursive = TRUE), add = TRUE)
  diagnostic_ids <- c("A-128-C12-fixed-cap4-H31", "cell-128-A-C12", "oracle-128-A-C12", "N-128")
  for (id in setdiff(setdiff(names(graph), "finalizer"), diagnostic_ids)) d99_write_terminal(diag_root, graph[[id]], "PASS", "NON_EVIDENCE")
  d99_write_terminal(diag_root, graph[["A-128-C12-fixed-cap4-H31"]], "OPTIMIZER_HEALTH_STOP", "NON_EVIDENCE")
  d99_write_terminal(diag_root, graph[["cell-128-A-C12"]], "DIAGNOSTIC_N128_NONINTERIOR", "NON_EVIDENCE")
  d99_write_terminal(diag_root, graph[["oracle-128-A-C12"]], "DEPENDENCY_BLOCKED", "NON_EVIDENCE")
  d99_write_terminal(diag_root, graph[["N-128"]], "DIAGNOSTIC_N128_NONINTERIOR", "NON_EVIDENCE")
  expect_identical(d99_classify_terminals(diag_root, graph), "BOUNDED_ORACLE_PASS")
  final <- graph[["finalizer"]]; d99_wiring_input(diag_root, final, counts, rules)
  d99_run_script("finalize.R", c("--input", d99_input_path(diag_root, final$task_id), "--output-root", diag_root, "--run-id", "NON_EVIDENCE"))
  expect_identical(d99_read_terminal(diag_root, final)$status, "BOUNDED_ORACLE_PASS")

  launch_root <- tempfile("d99-supervisor-non-evidence-"); on.exit(unlink(launch_root, recursive = TRUE), add = TRUE)
  # This supervisor pass uses only its aggregation-only finalizer: no fixture
  # draw, optimizer, or scientific objective is reachable from the test.
  d99_wiring_input(launch_root, graph[["finalizer"]], counts, rules)
  d99_run_script("supervise.R", c("--output-root", launch_root, "--run-id", "NON_EVIDENCE", "--mode", "NON_EVIDENCE"))
  launch <- d99_read_json(d99_launch_path(launch_root, "finalizer"))
  expect_true(d99_validate_launch(launch, graph[["finalizer"]]))
  expect_true(file.exists(d99_terminal_path(launch_root, "finalizer")))
  expect_false(file.exists(file.path(launch_root, "REAL_RUN.json")))
})

test_that("certified oracle intervals and N2048 identification fail closed", {
  nested <- list(chart_score_lower = c(-1e-3, -1e-3), chart_score_upper = c(1e-3, 1e-3))
  cubature <- nested
  interval <- d99_oracle_interval_gate(c(0, 0), nested, cubature, n = 1, scale = c(1, 1))
  expect_false(interval$ok)
  expect_gte(interval$nested_error, 5e-7)

  identification <- list(
    richardson_relative_error = 1e-7, rank = c(17L, 16L, 17L),
    reciprocal_condition = 1e-9,
    profile = lapply(c(0, -.25, .25, -.5, .5, -1, 1, -2, 2), function(x)
      list(valid = TRUE, displacement = x, delta_per_unit = 0))
  )
  information <- list(scaled_matrix = diag(17L), eigenvalues = rep(1, 17L), condition = 2)
  gate <- d99_identification_gate(identification, information)
  expect_false(gate$ok)
  expect_true(all(c("rank_1e8", "reciprocal_condition", "profile_nonflat") %in% gate$failed_checks))
})

test_that("supervisor kills timed-out workers, emits heartbeats, and excludes finalizer", {
  graph <- d99_build_task_graph("NON_EVIDENCE")
  rules <- lapply(c(9L, 15L, 21L, 31L), d99_gh_rule); names(rules) <- paste0("H", c(9L, 15L, 21L, 31L))
  counts <- as.integer(c(1L, rep.int(0L, 63L)))
  root <- tempfile("d99-timeout-non-evidence-"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  task <- graph[["A-128-C12-fixed-cap4-H9"]]
  d99_wiring_input(root, task, counts, rules)
  sleeper <- tempfile("d99-sleeper-", fileext = ".R"); on.exit(unlink(sleeper), add = TRUE)
  writeLines("Sys.sleep(2)", sleeper)
  d99_run_script("supervise.R", c(
    "--output-root", root, "--run-id", "NON_EVIDENCE", "--mode", "NON_EVIDENCE",
    "--test-task-id", task$task_id, "--test-worker-script", sleeper,
    "--timeout-override-s", "0.3", "--heartbeat-interval-s", "0.05"
  ))
  expect_identical(d99_read_terminal(root, task)$status, "TIMEOUT")
  expect_gt(length(list.files(file.path(root, "heartbeats", task$task_id), pattern = "\\.json$")), 0L)

  excluded <- tempfile("d99-exclude-finalizer-"); on.exit(unlink(excluded, recursive = TRUE), add = TRUE)
  d99_run_script("supervise.R", c("--exclude-finalizer", "--output-root", excluded, "--run-id", "NON_EVIDENCE", "--mode", "NON_EVIDENCE"))
  expect_false(file.exists(d99_launch_path(excluded, "finalizer")))
  expect_false(file.exists(d99_terminal_path(excluded, "finalizer")))
})

test_that("approved fixture is canonical integer in memory only", {
  fixture <- d99_fixture()
  expect_type(fixture$y_full, "integer")
  expect_true(all(vapply(fixture$prefixes, typeof, character(1)) == "integer"))
  expect_true(all(vapply(fixture$diagnostics, function(x) typeof(x$counts) == "integer", logical(1))))
  expect_true(all(vapply(names(fixture$prefixes), function(key)
    identical(d99_sha256_serialized(fixture$diagnostics[[key]]$counts), fixture$pattern_count_hashes[[key]]), logical(1))))
})
