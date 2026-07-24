#!/usr/bin/env Rscript

# Private Design 98 integration mechanics. Scientific convergence belongs to
# the separately retained N=16 smoke and real fixtures, not this tiny schema
# probe.

design_dir <- normalizePath(file.path("dev", "design98-factorial-va-jj"))
options(d98_design_dir = design_dir)
source(file.path(design_dir, "R", "records.R"))
source(file.path(design_dir, "R", "oracle.R"))
source(file.path(design_dir, "R", "fits.R"))
d98_require()
on.exit(d98_cleanup_fit_cache(), add = TRUE)

assert_true <- function(value, label) {
  if (!isTRUE(value)) stop(label, " failed")
  invisible(TRUE)
}

y <- rbind(
  c(1, 0, 1), c(0, 1, 0), c(1, 1, 0), c(0, 0, 1),
  c(1, 0, 0), c(0, 1, 1), c(1, 0, 1), c(0, 1, 0)
)
truth <- list(
  beta = c(-0.30, 0.20, 0.35),
  loading = rbind(c(0.70, 0), c(0.10, 0.60), c(-0.30, 0.25))
)
starts <- d98_declared_global_starts(y, truth)
assert_true(identical(names(starts), c("A", "B", "C")),
            "declared start names")
assert_true(all(vapply(
  starts,
  function(start) length(start$loading_free) == 2L * ncol(y) - 1L,
  logical(1)
)), "declared start coordinate lengths")

# Both private TMB objective builders accept the exact frozen coordinate maps.
gh31 <- d98_gh(31L)
gh_objective <- d98_build_gh_objective(
  y, starts$B$beta, starts$B$loading_free, gh31
)
local_d <- d98_declared_local_start(nrow(y), FALSE)
va_objective <- d98_build_va_objective(
  y, starts$B$beta, starts$B$loading_free,
  local_d$mean, local_d$chol_free, "QD", gh31
)
assert_true(
  is.finite(gh_objective$fn(gh_objective$par)) &&
    all(is.finite(gh_objective$gr(gh_objective$par))),
  "GH objective construction"
)
assert_true(
  is.finite(va_objective$fn(va_objective$par)) &&
    all(is.finite(va_objective$gr(va_objective$par))),
  "variational objective construction"
)

# Representative selection is deterministic and uses every healthy start.
synthetic <- lapply(c("A", "B", "C"), function(id) {
  transformed <- d98_transform_global(
    truth$beta, d98_loading_to_free(truth$loading)
  )
  list(
    status = "healthy",
    estimator_kind = "variational",
    method = "QF",
    start_id = id,
    objective = 10,
    transformed_parameters = transformed,
    metrics = list(optimized_objective = 10)
  )
})
selection <- d98_select_representative(synthetic, "variational")
assert_true(
  isTRUE(selection$comparable) &&
    identical(selection$selected_start_id, "A") &&
    identical(selection$healthy_start_order, c("A", "B", "C")),
  "deterministic representative selection"
)

# The heartbeat advances while its parent is blocked.
heartbeat_root <- tempfile("design98-heartbeat-test-")
d98_make_directories(heartbeat_root)
on.exit(unlink(heartbeat_root, recursive = TRUE, force = TRUE), add = TRUE)
heartbeat <- d98_start_concurrent_heartbeat(
  heartbeat_root, "heartbeat_test", 0.20
)
Sys.sleep(0.35)
heartbeat_path <- file.path(
  heartbeat_root, "heartbeats", "heartbeat_test.json"
)
first_mtime <- file.info(heartbeat_path)$mtime
Sys.sleep(0.45)
second_mtime <- file.info(heartbeat_path)$mtime
d98_stop_concurrent_heartbeat(heartbeat)
assert_true(
  file.exists(heartbeat_path) && isTRUE(second_mtime > first_mtime),
  "concurrent heartbeat liveness"
)

# One isolated CLI invocation must publish a complete immutable payload even
# when the deliberately tiny optimizer probe is scientifically unhealthy.
cli_parent <- tempfile("design98-fit-worker-cli-")
dir.create(cli_parent)
on.exit(unlink(cli_parent, recursive = TRUE, force = TRUE), add = TRUE)
cli_root <- d98_create_disposable_root(cli_parent, "fit-worker-test")
input <- list(
  task_id = "gh_cli_phase1",
  action = "gh_phase1",
  dependencies = character(),
  dependency_policy = "all_healthy",
  y = y,
  truth = truth,
  start_id = "B",
  wall_time_sec = 120,
  heartbeat_sec = 0.25,
  nlminb_iter_max = 80L,
  nlminb_eval_max = 120L
)
d98_create_task_input(cli_root, input)
output <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(
    file.path(design_dir, "fit-worker.R"),
    "--root", cli_root,
    "--task-id", "gh_cli_phase1"
  ),
  stdout = TRUE,
  stderr = TRUE
)
exit_status <- attr(output, "status") %||% 0L
payload <- d98_task_payload(cli_root, "gh_cli_phase1")
assert_true(exit_status == 0L, "fit-worker CLI exit")
assert_true(
  payload$ok &&
    payload$value$status %in% c("healthy", "unhealthy") &&
    identical(payload$value$action, "gh_phase1") &&
    length(payload$value$raw_coordinates) == 3L * ncol(y) - 1L &&
    is.finite(as.numeric(payload$value$objective)) &&
    !is.null(payload$value$input_sha256) &&
    !is.null(payload$value$realised_inputs),
  "fit-worker immutable payload schema"
)
assert_true(
  !file.exists(file.path(cli_parent, "REAL_RUN.json")) &&
    !file.exists(file.path(cli_root, "REAL_RUN.json")),
  "integration test created no real-run lock"
)

cat("Design 98 scientific fit-worker mechanics: PASS\n")
