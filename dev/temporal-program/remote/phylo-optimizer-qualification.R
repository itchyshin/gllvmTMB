## Diagnostic replay for one immutable temporal-phylogenetic recovery fixture.
## It is separate from the frozen campaign runner and never writes to its receipt
## directory. The developer-only diagnostic hook changes no fitting control.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "=|^", name, "="), "", hit)
}
mode <- arg_value("--mode")
if (is.null(mode)) mode <- "plan"
root <- normalizePath(".", mustWork = TRUE)
script_dir <- file.path(root, "dev", "temporal-program", "remote")
sys.source(file.path(script_dir, "phylo-recovery-common.R"), envir = globalenv())

if (identical(mode, "plan")) {
  cat("TEMPORAL_PHYLO_QUALIFICATION_PLAN_PASS fixture=one-retained-cell diagnostics=fresh-state\n")
  quit(save = "no", status = 0L)
}
if (!identical(mode, "run")) {
  stop("usage: Rscript --vanilla phylo-optimizer-qualification.R --mode=plan | --mode=run --phi=NUMERIC --seed=INTEGER --output=PATH", call. = FALSE)
}
phi <- suppressWarnings(as.numeric(arg_value("--phi")))
seed <- suppressWarnings(as.integer(arg_value("--seed")))
output <- arg_value("--output")
if (length(phi) != 1L || !is.finite(phi) || length(seed) != 1L || is.na(seed) ||
    is.null(output) || !nzchar(output)) {
  stop("run mode requires finite --phi, integer --seed, and non-empty --output.", call. = FALSE)
}
output <- normalizePath(output, mustWork = FALSE)
if (file.exists(output)) stop("Refusing to overwrite an existing qualification receipt.", call. = FALSE)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

load_temporal_program_package(root)
data <- simulate_fixture(phi, seed)
control <- gllvmTMBcontrol(
  se = FALSE, optimizer = "optim",
  optArgs = list(method = "BFGS", control = list(maxit = 3000L, reltol = 1e-14)),
  optimizer_passes = 2L
)
control$optimizer_diagnostics <- TRUE
started <- proc.time()[["elapsed"]]
fit <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion, replicate = measurement) +
    phylo_indep(0 + trait | series, vcv = Cphy),
  data = data, unit = "series", cluster = "series", family = gaussian(),
  silent = TRUE, control = control
))
elapsed_seconds <- proc.time()[["elapsed"]] - started
history <- fit$optimizer_pass_history
required <- c(
  "pass", "pass_label", "objective", "convergence", "accepted",
  "outer_gradient_max", "outer_gradient_coordinate",
  "finite_difference_max", "finite_difference_coordinate",
  "finite_difference_error_max", "finite_difference_error_coordinate",
  "finite_difference_n_coordinates", "finite_difference_n_finite",
  "finite_difference_all_finite", "fresh_state_ok", "fresh_objective",
  "fresh_objective_error", "inner_method", "inner_hessian_available",
  "inner_hessian_dimension", "inner_hessian_rcond", "inner_hessian_condition",
  "inner_hessian_message", "outer_hessian_available", "outer_hessian_message",
  "fn_evaluations", "gr_evaluations", "message",
  "warnings", "elapsed_seconds", "start", "end", "gradient", "fresh_gradient"
)
if (!is.data.frame(history) || nrow(history) != 2L ||
    !all(required %in% names(history)) || !identical(history$pass, 1:2) ||
    !all(history$fresh_state_ok) || !all(history$finite_difference_all_finite) ||
    !identical(history$finite_difference_n_coordinates, history$finite_difference_n_finite) ||
    !all(history$inner_hessian_available)) {
  stop("The diagnostic two-pass qualification receipt is incomplete.", call. = FALSE)
}
head <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE),
  error = function(e) NA_character_)
receipt <- list(
  schema = "temporal_phylo_optimizer_qualification_v1",
  source_commit = unname(head[[1L]]),
  phi = phi,
  seed = seed,
  input = list(data = data, Cphy = Cphy, truth = truth),
  control = control,
  final = list(par = fit$opt$par, objective = fit$opt$objective,
    convergence = fit$opt$convergence,
    max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par)))),
  optimizer_pass_history = history,
  elapsed_seconds = elapsed_seconds
)
saveRDS(receipt, output)
cat(sprintf("TEMPORAL_PHYLO_QUALIFICATION_PASS phi=%s seed=%d output=%s\n",
  phi, seed, output))
