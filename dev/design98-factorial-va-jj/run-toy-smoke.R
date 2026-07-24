#!/usr/bin/env Rscript

d98_toy_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) {
    stop("run-toy-smoke.R requires --file", call. = FALSE)
  }
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

d98_parse_toy_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  list(
    execute = "--execute" %in% args,
    fit_worker = if ("--fit-worker" %in% args) {
      args[[match("--fit-worker", args) + 1L]]
    } else {
      NULL
    }
  )
}

script_path <- d98_toy_script()
design_dir <- dirname(script_path)
options(d98_design_dir = file.path(design_dir, "R"))
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "task-plan.R"))
d98_require()

d98_toy_fixture <- function() {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    {
      do.call(RNGkind, as.list(old_kind))
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(98016L)
  truth <- list(
    beta = c(-.45, -.10, .30),
    loading = rbind(c(.82, 0), c(.18, .68), c(-.36, .30))
  )
  u <- matrix(stats::rnorm(16L * 2L), 16L, 2L)
  probability <- stats::plogis(sweep(
    u %*% t(truth$loading),
    2L,
    truth$beta,
    "+"
  ))
  y <- matrix(stats::rbinom(16L * 3L, 1L, as.vector(probability)), 16L, 3L)
  if (any(colSums(y) %in% c(0L, 16L))) {
    d98_abort("Toy fixture unexpectedly lacks both outcomes")
  }
  list(label = "toy", y = y, sha256 = d98_hash_object(y), truth = truth)
}

toy_args <- d98_parse_toy_args()
if (
  isTRUE(toy_args$execute) &&
    (is.null(toy_args$fit_worker) || !file.exists(toy_args$fit_worker))
) {
  d98_abort("--execute requires the forthcoming existing --fit-worker path")
}

root <- d98_create_disposable_root(
  file.path(tempdir(), "design98-toy-smoke"),
  "toy-smoke"
)
if (file.exists(file.path(dirname(root), "REAL_RUN.json"))) {
  d98_abort("Toy smoke must never share a REAL_RUN parent")
}
fixture <- d98_toy_fixture()
toy_low <- fixture
toy_high <- fixture
toy_low$label <- "low"
toy_high$label <- "high"
plan <- d98_build_task_plan(root, toy_low, toy_high, fixture$truth, toy = TRUE)
task_inputs <- lapply(plan$task_ids, function(task_id) {
  d98_task_input(root, task_id)$value
})
task_actions <- vapply(task_inputs, `[[`, character(1), "action")
evaluation_policies <- vapply(
  task_inputs[task_actions == "evaluate"],
  `[[`,
  character(1),
  "dependency_policy"
)
if (!identical(plan$task_count, 52L)) {
  d98_abort("Toy DAG task count is not 52")
}
if (
  !setequal(
    unique(task_actions),
    c(
      "gh_phase1",
      "gh_phase2",
      "va_phase1",
      "va_phase2",
      "fixed_local_phase1",
      "fixed_local_phase2",
      "evaluate"
    )
  )
) {
  d98_abort("Toy DAG action set is incomplete")
}
if (
  length(evaluation_policies) == 0L ||
    !all(evaluation_policies == "all_terminal")
) {
  d98_abort("Toy DAG evaluation tasks must retain failed sibling evidence")
}
d98_write_json_exclusive(
  file.path(root, "toy-smoke.json"),
  list(
    design = 98L,
    fault_injection = TRUE,
    evidence = FALSE,
    n = 16L,
    traits = 3L,
    fixture_sha256 = fixture$sha256,
    task_count = plan$task_count,
    fit_execution = isTRUE(toy_args$execute),
    created_utc = d98_now()
  )
)

if (isTRUE(toy_args$execute)) {
  source(file.path(design_dir, "R", "supervisor.R"))
  source(file.path(design_dir, "finalize.R"))
  d98_run_ready(root, normalizePath(toy_args$fit_worker))
  summary <- d98_finalize(root)
  status <- summary$status
} else {
  status <- "PLANNED_NO_FIT_WORKER"
}

cat(
  jsonlite::toJSON(
    list(
      status = status,
      root = root,
      fault_injection = TRUE,
      evidence = FALSE,
      n = 16L,
      traits = 3L,
      task_count = plan$task_count
    ),
    auto_unbox = TRUE,
    pretty = TRUE
  ),
  "\n"
)
