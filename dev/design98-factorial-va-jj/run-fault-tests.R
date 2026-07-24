#!/usr/bin/env Rscript

d98_fault_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) {
    stop("run-fault-tests.R requires --file", call. = FALSE)
  }
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

script_path <- d98_fault_script()
design_dir <- dirname(script_path)
options(d98_design_dir = file.path(design_dir, "R"))
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "supervisor.R"))
source(file.path(design_dir, "finalize.R"))
d98_require()
if (!requireNamespace("processx", quietly = TRUE)) {
  d98_abort("Missing required package: processx")
}

assert_identical <- function(actual, expected, label) {
  if (!identical(actual, expected)) {
    d98_abort(label, ": expected ", expected, ", got ", actual)
  }
}

make_root <- function(label) {
  d98_create_disposable_root(
    file.path(tempdir(), "design98-fault-tests"),
    label
  )
}
worker <- normalizePath(file.path(design_dir, "worker.R"))
task <- function(
  id,
  action = "success",
  wall = 5,
  sleep = NULL,
  deps = character(),
  dependency_policy = NULL
) {
  x <- list(
    task_id = id,
    action = action,
    wall_time_sec = wall,
    heartbeat_sec = 1,
    dependencies = deps,
    phase = "fault",
    objective = 0
  )
  if (!is.null(sleep)) {
    x$sleep_sec <- sleep
  }
  if (!is.null(dependency_policy)) {
    x$dependency_policy <- dependency_policy
  }
  x
}

results <- list()

# 1. Worker crash.
root <- make_root("crash")
d98_create_task_input(root, task("crash", "crash"))
results$crash <- d98_launch_task(root, "crash", worker)
assert_identical(results$crash, "worker_exit_without_payload", "crash fault")

# 2. Wall-clock timeout while the child heartbeats.
root <- make_root("timeout")
d98_create_task_input(root, task("timeout", "sleep", wall = 1, sleep = 3))
results$timeout <- d98_launch_task(root, "timeout", worker)
assert_identical(results$timeout, "timed_out", "timeout fault")

# 3. Malformed JSON payload.
root <- make_root("malformed")
d98_create_task_input(root, task("malformed", "malformed"))
results$malformed <- d98_launch_task(root, "malformed", worker)
assert_identical(results$malformed, "malformed_payload", "malformed fault")

# 4. Partial payload is also terminally retained as malformed.
root <- make_root("partial")
d98_create_task_input(root, task("partial", "partial"))
results$partial <- d98_launch_task(root, "partial", worker)
assert_identical(results$partial, "malformed_payload", "partial fault")

# 5. A pre-existing payload makes the worker fail; neither payload nor final
# record is overwritten.
root <- make_root("duplicate")
d98_create_task_input(root, task("duplicate"))
d98_write_json_exclusive(
  d98_path(root, "payloads", "duplicate"),
  list(status = "healthy", injected = TRUE)
)
results$duplicate <- d98_launch_task(root, "duplicate", worker)
assert_identical(
  results$duplicate,
  "duplicate_payload",
  "duplicate-output fault"
)

# 6. Simulated parent interruption after phase 2 succeeds: phase 1 and BFGS
# are independent DAG nodes, then the aggregation-only finalizer sees retained
# records and starts no worker or objective.
root <- make_root("parent-interrupt")
d98_create_task_input(root, task("nlminb"))
d98_create_task_input(root, task("bfgs", deps = "nlminb"))
phase_states <- d98_run_ready(root, worker)
assert_identical(unname(phase_states[["nlminb"]]), "healthy", "phase-1 node")
assert_identical(unname(phase_states[["bfgs"]]), "healthy", "phase-2 node")
summary <- d98_finalize(root)
assert_identical(summary$worker_launches, 0L, "finalizer launch count")
assert_identical(
  summary$objective_constructions,
  0L,
  "finalizer objective count"
)
results$parent_interruption <- summary$status

# A pre-existing launch receipt is orphaned evidence, never permission to retry.
root <- make_root("orphan")
d98_create_task_input(root, task("orphan"))
orphan_input <- d98_task_input(root, "orphan")$value
d98_write_launch(root, "orphan", orphan_input)
assert_identical(
  d98_launch_task(root, "orphan", worker),
  "orphaned",
  "resume-only-never-started"
)
results$resume_orphan <- "rejected"

# Evaluation waits for all sibling starts to be terminal, then runs even when
# one failed. Scientific phase nodes retain the default all-healthy policy.
root <- make_root("all-terminal")
d98_create_task_input(root, task("start_a", "success"))
d98_create_task_input(root, task("start_b", "crash"))
d98_create_task_input(
  root,
  task(
    "select",
    deps = c("start_a", "start_b"),
    action = "evaluate",
    wall = 5,
    dependency_policy = "all_terminal"
  )
)
terminal_states <- d98_run_ready(root, worker)
assert_identical(
  unname(terminal_states[["start_a"]]),
  "healthy",
  "healthy sibling"
)
assert_identical(
  unname(terminal_states[["start_b"]]),
  "worker_exit_without_payload",
  "failed sibling"
)
assert_identical(
  unname(terminal_states[["select"]]),
  "healthy",
  "all-terminal evaluation"
)
results$all_terminal_evaluation <- "retained_siblings_adjudicated"

# Design-level lock is separately tested in a disposable parent.
lock_parent <- file.path(tempdir(), "design98-fault-lock")
unlink(lock_parent, recursive = TRUE, force = TRUE)
contract <- tempfile("design98-contract-")
writeLines("fault contract", contract)
invisible(d98_create_real_run(lock_parent, "real-one", "7a725c5e", contract))
duplicate_lock <- tryCatch(
  {
    suppressWarnings(d98_create_real_run(
      lock_parent,
      "real-two",
      "7a725c5e",
      contract
    ))
    FALSE
  },
  error = function(e) TRUE
)
if (!isTRUE(duplicate_lock)) {
  d98_abort("duplicate design-level REAL_RUN lock was accepted")
}
results$duplicate_lock <- "rejected"

cat(
  jsonlite::toJSON(
    list(status = "PASS", faults = results),
    auto_unbox = TRUE,
    pretty = TRUE
  ),
  "\n"
)
