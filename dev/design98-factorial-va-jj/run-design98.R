#!/usr/bin/env Rscript

# One-shot private Design 98 execution. Every optimizer phase is delegated to
# fit-worker.R; this parent only freezes inputs, supervises, and aggregates.

d98_run_script <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(arg)) stop("run-design98.R requires --file", call. = FALSE)
  normalizePath(sub("^--file=", "", arg[[1L]]))
}

script_path <- d98_run_script()
design_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(design_dir, "..", ".."))
options(d98_design_dir = file.path(design_dir, "R"))
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "oracle.R"))
source(file.path(design_dir, "R", "provenance.R"))
source(file.path(design_dir, "R", "fixture.R"))
source(file.path(design_dir, "R", "task-plan.R"))
source(file.path(design_dir, "R", "supervisor.R"))
source(file.path(design_dir, "R", "fits.R"))
source(file.path(design_dir, "finalize.R"))
d98_require()

args <- commandArgs(trailingOnly = TRUE)
resume <- "--resume" %in% args
results_dir <- file.path(design_dir, "results")
contract <- file.path(
  repo_root, "docs", "design", "98-factorial-va-jj-discriminator.md"
)
fit_worker <- normalizePath(file.path(design_dir, "fit-worker.R"))

d98_toy_fixture_for_gate3 <- function() {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(98016L)
  truth <- list(
    beta = c(-.45, -.10, .30),
    loading = rbind(c(.82, 0), c(.18, .68), c(-.36, .30))
  )
  u <- matrix(stats::rnorm(16L * 2L), 16L, 2L)
  probability <- stats::plogis(sweep(
    u %*% t(truth$loading), 2L, truth$beta, "+"
  ))
  y <- matrix(stats::rbinom(16L * 3L, 1L, as.vector(probability)), 16L, 3L)
  stopifnot(!any(colSums(y) %in% c(0L, 16L)))
  list(label = "toy", y = y, sha256 = d98_hash_object(y), truth = truth)
}

d98_write_dataframe_exclusive <- function(path, value) {
  d98_write_json_exclusive(
    path,
    lapply(seq_len(nrow(value)), function(i) as.list(value[i, , drop = FALSE]))
  )
}

d98_run_task_order <- function(root, task_order) {
  states <- character(length(task_order))
  names(states) <- task_order
  for (task_id in task_order) {
    states[[task_id]] <- d98_launch_task(root, task_id, fit_worker)
  }
  states
}

d98_scalar <- function(x) {
  unlist(x, recursive = TRUE, use.names = FALSE)[[1L]]
}

d98_assert_inventory_record <- function(record, current) {
  if (!is.list(record) || nrow(current) != length(record)) {
    d98_abort("Inventory record has the wrong shape")
  }
  recorded <- data.frame(
    path = vapply(record, function(x) as.character(d98_scalar(x$path)),
                  character(1)),
    exists = vapply(record, function(x) isTRUE(d98_scalar(x$exists)),
                    logical(1)),
    sha256 = vapply(record, function(x) {
      value <- unlist(x$sha256, recursive = TRUE, use.names = FALSE)
      if (!length(value) || is.na(value[[1L]])) NA_character_ else
        as.character(value[[1L]])
    }, character(1)),
    stringsAsFactors = FALSE
  )
  d98_assert_same_inventory(recorded, current)
}

d98_assert_resume_provenance <- function(root, lock, manifest) {
  status <- d98_git_value(c("status", "--porcelain"), root = repo_root)
  status_lines <- if (nzchar(status)) strsplit(status, "\n", fixed = TRUE)[[1L]]
    else character()
  allowed <- paste0("?? ", d98_rel_path(results_dir, repo_root), "/")
  if (length(status_lines) &&
      any(!startsWith(status_lines, allowed))) {
    d98_abort("Resume refused: source worktree has non-result changes")
  }
  if (!identical(as.character(lock$uuid), basename(root)) ||
      !identical(as.character(lock$contract_sha256),
                 d98_hash_file(contract)) ||
      !identical(as.character(manifest$source_head),
                 d98_git_value(c("rev-parse", "HEAD"), repo_root)) ||
      !identical(as.character(manifest$oracle_sha256),
                 d98_hash_file(file.path(design_dir, "R", "oracle.R"))) ||
      !identical(as.character(manifest$worker_sha256),
                 d98_hash_file(fit_worker)) ||
      !identical(as.character(manifest$worker_executable_sha256),
                 d98_hash_file(file.path(R.home("bin"), "Rscript")))) {
    d98_abort("Resume refused: frozen source/lock hash mismatch")
  }
  cpp_hashes <- vapply(
    c("design98_gh.cpp", "design98_variational.cpp"),
    function(name) d98_hash_file(file.path(design_dir, "src", name)),
    character(1)
  )
  if (!identical(
    as.character(manifest$cpp_sha256),
    d98_hash_object(as.list(cpp_hashes))
  )) {
    d98_abort("Resume refused: frozen C++ hash mismatch")
  }
  d98_assert_inventory_record(
    manifest$source_inventory,
    d98_file_inventory(
      file.path(repo_root, d98_design98_source_paths(repo_root)),
      root = repo_root
    )
  )
  baseline <- d98_read_json(file.path(root, "prior-baseline.json"))
  if (!baseline$ok) d98_abort("Resume refused: prior baseline is unreadable")
  d98_assert_inventory_record(
    baseline$value, d98_prior_design_inventory(repo_root)
  )
  ready <- d98_read_json(file.path(root, "real-inputs-ready.json"))
  if (!ready$ok) {
    d98_abort("Resume refused: immutable real-input freeze was incomplete")
  }
  task_ids <- unlist(
    ready$value$task_order, recursive = TRUE, use.names = FALSE
  )
  recorded_hashes <- unlist(
    ready$value$input_sha256, recursive = TRUE, use.names = FALSE
  )
  current_hashes <- vapply(task_ids, function(task_id) {
    d98_hash_file(d98_path(root, "inputs", task_id))
  }, character(1))
  if (!identical(as.character(recorded_hashes), unname(current_hashes))) {
    d98_abort("Resume refused: immutable task-input hash mismatch")
  }
  expected_fixture_hashes <- d98_expected_fixture_hashes()
  for (label in c("low", "high")) {
    reference <- list(fixture = list(
      label = label,
      n = if (label == "low") 160L else 640L,
      traits = 6L,
      sha256 = unname(expected_fixture_hashes[[label]])
    ))
    invisible(d98_fit_y(reference, root))
  }
  invisible(TRUE)
}

if (resume) {
  lock_read <- d98_read_json(file.path(results_dir, "REAL_RUN.json"))
  if (!lock_read$ok) d98_abort("Cannot resume without a valid REAL_RUN lock")
  root <- file.path(results_dir, as.character(lock_read$value$uuid))
  manifest <- d98_read_json(file.path(root, "manifest.json"))
  if (!manifest$ok) d98_abort("Cannot resume without a valid manifest")
  if (file.exists(file.path(root, "scientific-summary.json"))) {
    completed <- d98_read_json(file.path(root, "scientific-summary.json"))
    if (!completed$ok) d98_abort("Completed summary is malformed")
    cat(jsonlite::toJSON(completed$value, auto_unbox = TRUE, pretty = TRUE), "\n")
    quit(save = "no", status = 0L)
  }
  d98_assert_resume_provenance(
    root, lock_read$value, manifest$value
  )
  task_order <- unlist(
    manifest$value$task_order,
    recursive = TRUE,
    use.names = FALSE
  )
  if (!length(task_order)) d98_abort("Manifest lacks task order")
} else {
  if (file.exists(file.path(results_dir, "REAL_RUN.json"))) {
    d98_abort("Design 98 REAL_RUN already exists; use --resume only")
  }
  if (nzchar(d98_git_value(c("status", "--porcelain"), root = repo_root))) {
    d98_abort("Design 98 source worktree must be clean before REAL_RUN")
  }
  fixture <- d98_nested_fixture()
  d98_assert_fixture_hashes(fixture)
  prior_baseline <- d98_prior_design_inventory(repo_root)
  uuid <- d98_uuid()
  reserved <- d98_create_real_run(
    results_dir, uuid, "7a725c5e", contract
  )
  root <- reserved$root

  # Freeze scientific task order before any child is launched.
  tasks <- d98_task_plan(
    fixture$low, fixture$high, fixture$truth, toy = FALSE
  )
  task_order <- names(tasks)
  gh_checksums <- d98_gh_checksums(gh_rule = d98_gh)
  metadata <- d98_manifest_metadata(
    uuid = uuid,
    source_paths = d98_design98_source_paths(repo_root),
    gh_checksums = gh_checksums,
    root = repo_root
  )
  cpp_hashes <- vapply(
    c("design98_gh.cpp", "design98_variational.cpp"),
    function(name) d98_hash_file(file.path(design_dir, "src", name)),
    character(1)
  )
  manifest_fields <- c(metadata, list(
    oracle_sha256 = d98_hash_file(file.path(design_dir, "R", "oracle.R")),
    cpp_sha256 = d98_hash_object(as.list(cpp_hashes)),
    cpp_file_sha256 = as.list(cpp_hashes),
    worker_sha256 = d98_hash_file(fit_worker),
    worker_executable_sha256 = d98_hash_file(file.path(R.home("bin"), "Rscript")),
    task_order = as.list(task_order),
    benchmark_command = paste(
      "Rscript --vanilla dev/design98-factorial-va-jj/run-design98.R",
      "(local staged task supervision; high GH remote only if a separately",
      "recorded pre-run benchmark exceeds 600 seconds)"
    )
  ))
  d98_create_manifest(root, manifest_fields)
  d98_write_dataframe_exclusive(
    file.path(root, "prior-baseline.json"), prior_baseline
  )

  # Gate 3: retain one non-evidential canonical invocation smoke inside the
  # registered packet. It has its own fault-injection manifest and task root.
  toy <- d98_toy_fixture_for_gate3()
  toy_root <- d98_create_disposable_root(
    file.path(root, "non-evidence"), "toy-smoke"
  )
  toy_low <- toy_high <- toy
  toy_low$label <- "low"
  toy_high$label <- "high"
  toy_plan <- d98_build_task_plan(
    toy_root, toy_low, toy_high, toy$truth, toy = TRUE
  )
  toy_states <- d98_run_task_order(toy_root, toy_plan$task_ids)
  toy_summary <- d98_finalize(toy_root)
  toy_expected <- toy_plan$task_ids
  infrastructure_failure <- !toy_states %in% c(
    "healthy", "worker_reported_unhealthy", "blocked_dependency"
  )
  toy_phase_ids <- toy_expected[grepl("phase[12]$", toy_expected)]
  toy_final_record <- d98_task_record(toy_root, "evaluate_all")
  toy_final_payload <- d98_task_payload(toy_root, "evaluate_all")
  toy_pass <- length(toy_states) == 52L &&
    identical(names(toy_states), toy_expected) &&
    !any(infrastructure_failure) &&
    sum(toy_states[toy_phase_ids] == "healthy") >= 2L &&
    toy_final_record$ok &&
    identical(toy_final_record$value$status, "healthy") &&
    toy_final_payload$ok &&
    identical(toy_final_payload$value$status, "healthy") &&
    !is.null(toy_final_payload$value$decision_status) &&
    identical(toy_summary$status, "AGGREGATED_ONLY")
  d98_write_json_exclusive(
    file.path(root, "gate3-toy-smoke.json"),
    list(
      status = if (toy_pass) "PASS" else "FAIL",
      evidence = FALSE,
      root = toy_root,
      fixture_sha256 = toy$sha256,
      task_states = as.list(toy_states),
      infrastructure_failure_count = sum(infrastructure_failure),
      healthy_scientific_phase_count =
        sum(toy_states[toy_phase_ids] == "healthy"),
      final_decision_status = if (toy_final_payload$ok) {
        toy_final_payload$value$decision_status
      } else {
        NULL
      },
      terminal_count = sum(toy_states != "PENDING"),
      created_utc = d98_now()
    )
  )
  if (!toy_pass) {
    d98_write_json_exclusive(
      file.path(root, "root-stop.json"),
      list(
        status = "STOP",
        reason = "GATE3_TOY_INVOCATION_FAILED",
        created_utc = d98_now()
      )
    )
    d98_abort("Gate 3 toy invocation failed; no real estimator launched")
  }

  # Freeze real fixtures and every task input only after the smoke passes.
  real_plan <- d98_build_task_plan(
    root, fixture$low, fixture$high, fixture$truth, toy = FALSE
  )
  input_hashes <- vapply(real_plan$task_ids, function(task_id) {
    d98_hash_file(d98_path(root, "inputs", task_id))
  }, character(1))
  d98_write_json_exclusive(
    file.path(root, "real-inputs-ready.json"),
    list(
      status = "READY",
      task_count = real_plan$task_count,
      task_order = as.list(real_plan$task_ids),
      input_sha256 = as.list(input_hashes),
      low_fixture_sha256 = fixture$low$sha256,
      high_fixture_sha256 = fixture$high$sha256,
      created_utc = d98_now()
    )
  )
}

states <- d98_run_task_order(root, task_order)
aggregation <- d98_finalize(root)
scientific <- d98_task_payload(root, "evaluate_all")
scientific_terminal <- d98_task_record(root, "evaluate_all")
scientific_valid <- scientific$ok &&
  scientific_terminal$ok &&
  identical(scientific_terminal$value$status, "healthy") &&
  identical(scientific$value$status, "healthy")
prior_final <- d98_prior_design_inventory(repo_root)
prior_baseline_read <- d98_read_json(file.path(root, "prior-baseline.json"))

if (!resume) {
  d98_assert_same_inventory(prior_baseline, prior_final)
} else {
  if (!prior_baseline_read$ok) d98_abort("Prior baseline is unreadable")
  d98_assert_inventory_record(prior_baseline_read$value, prior_final)
}
if (!file.exists(file.path(root, "prior-final.json"))) {
  d98_write_dataframe_exclusive(
    file.path(root, "prior-final.json"), prior_final
  )
} else {
  retained_final <- d98_read_json(file.path(root, "prior-final.json"))
  if (!retained_final$ok) d98_abort("Retained prior-final inventory malformed")
  d98_assert_inventory_record(retained_final$value, prior_final)
}
d98_write_json_exclusive(
  file.path(root, "scientific-summary.json"),
  list(
    design = 98L,
    aggregation_status = aggregation$status,
    task_states = as.list(states),
    scientific_payload_available = scientific_valid,
    scientific_terminal_status = if (scientific_terminal$ok) {
      scientific_terminal$value$status
    } else {
      NULL
    },
    scientific = if (scientific_valid) scientific$value else NULL,
    prior_baseline_record_readable = prior_baseline_read$ok,
    completed_utc = d98_now()
  )
)

cat(jsonlite::toJSON(
  list(
    design = 98L,
    root = root,
    aggregation_status = aggregation$status,
    scientific_payload_available = scientific_valid,
    decision_status = if (scientific_valid) {
      scientific$value$decision_status
    } else {
      "TECHNICAL_INCOMPLETE"
    },
    task_states = as.list(states)
  ),
  auto_unbox = TRUE,
  pretty = TRUE
), "\n")
