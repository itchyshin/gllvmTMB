# Exactly one retained estimator invocation. No retry or truth initialization.
args <- commandArgs(TRUE)
root <- normalizePath(args[[1L]])
id <- args[[2L]]
out <- args[[3L]]
.libPaths(c(file.path(root, "library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
source(file.path(root, "dev/structured-rho/spatial-recovery/study-metrics.R"))
fixture_dir <- if (length(args) >= 4L) normalizePath(args[[4L]]) else
  file.path(root, "dev/structured-rho/spatial-recovery/fixtures")
jobs <- read.csv(file.path(fixture_dir, "jobs.csv"), stringsAsFactors = FALSE)
job <- jobs[jobs$attempt_id == id, , drop = FALSE]
stopifnot(nrow(job) == 1L)
all_fixtures <- readRDS(file.path(fixture_dir, "sources.rds"))
fixture <- all_fixtures$regimes[[job$regime]]
data <- readRDS(file.path(fixture_dir, job$dataset))
mesh <- fixture$mesh
rho_request <- if (job$method == "estimated") NULL else job$rho
mode <- if (job$mode == "latent_psi") "latent" else job$mode
extra <- if (job$mode == "latent_psi") ",d=1,unique=TRUE" else
  if (mode == "latent") ",d=1,unique=FALSE" else ""
formula <- as.formula(paste0(
  "y~0+trait+spatial_", mode,
  "(0+trait|group,mesh=mesh", extra, ",rho=rho_request)"
), env = environment())

.spatial_recovery_entries <- 0L
.spatial_recovery_count <- function(name) {
  requested <- .spatial_recovery_entries + 1L
  cat(sprintf("%s,%s,%d\n", format(Sys.time(), tz = "UTC", usetz = TRUE),
              name, requested), file = file.path(out, "optimizer-entries.csv"),
      append = TRUE)
  if (requested > 1L) stop("Second optimizer invocation prohibited")
  .spatial_recovery_entries <<- requested
}
trace("nlminb", where = asNamespace("stats"),
      tracer = quote(.spatial_recovery_count("nlminb")), print = FALSE)
trace("optim", where = asNamespace("stats"),
      tracer = quote(.spatial_recovery_count("optim")), print = FALSE)

ctl <- gllvmTMBcontrol(se = TRUE, n_init = 1L)
ctl$.internal_continuation <- FALSE
set.seed(job$fit_seed)
warnings <- character()
started <- proc.time()[["elapsed"]]
result <- tryCatch(withCallingHandlers({
  fit <- gllvmTMB(formula, data = data, trait = "trait", unit = "obs",
                  cluster = "group", family = gaussian(), control = ctl)
  S <- extract_Sigma(fit, level = "spatial", link_residual = "none")$Sigma
  rho_hat <- fit$source_strength$value
  kappa_hat <- as.numeric(fit$report$kappa)
  td <- fit$tmb_data
  fitted_source <- spatial_rho_source_covariance(
    td$spatial_rho_A, td$spde_M0, td$spde_M1, td$spde_M2,
    kappa_hat, rho_hat
  )
  truth_source <- spatial_rho_source_covariance(
    fixture$A, fixture$M0, fixture$M1, fixture$M2,
    fixture$kappa, job$rho
  )
  truth_form <- fixture$forms[[job$mode]]
  St <- tcrossprod(truth_form$L) + diag(truth_form$Psi)
  residual_sd <- as.numeric(fit$report$sigma_eps)
  stopifnot(length(residual_sd) == 1L, is.finite(residual_sd), residual_sd > 0)
  errors <- spatial_rho_covariance_errors(
    fitted_source$Kr, S, truth_source$Kr, St, residual_sd^2,
    all_fixtures$sigma_eps^2
  )
  gradient <- fit$tmb_obj$gr(fit$opt$par)
  numerical_success <- .spatial_recovery_entries == 1L &&
    isTRUE(fit$opt$convergence == 0L) && isTRUE(fit$sd_report$pdHess) &&
    all(is.finite(c(fit$opt$objective, fit$opt$par, S, gradient,
                    rho_hat, kappa_hat))) && max(abs(gradient)) <= .01
  list(
    status = "returned", numerical_success = numerical_success,
    rho = rho_hat, rho_truth = job$rho,
    kappa = kappa_hat, kappa_truth = fixture$kappa,
    kappa_relative_error = (kappa_hat - fixture$kappa) / fixture$kappa,
    objective = fit$opt$objective, convergence = fit$opt$convergence,
    pd_hessian = isTRUE(fit$sd_report$pdHess),
    max_gradient = max(abs(gradient)),
    boundary = rho_hat <= 1e-4 || rho_hat >= 1 - 1e-4,
    source_covariance_relative_error = unname(errors[["source"]]),
    total_covariance_relative_error = unname(errors[["total"]]),
    residual_variance = residual_sd^2, trait_covariance = S,
    source_strength = fit$source_strength,
    range_strength_geometry = if (!is.null(fit$diagnostics))
      fit$diagnostics$range_strength_geometry else NULL,
    initialization = fit$start_provenance, parameters = fit$opt$par,
    gradient = gradient
  )
}, warning = function(w) {
  warnings <<- c(warnings, conditionMessage(w))
  invokeRestart("muffleWarning")
}), error = function(e) {
  list(status = "error", numerical_success = FALSE,
       error = conditionMessage(e), classes = class(e))
})
result$attempt_id <- id
result$job <- job
result$warnings <- warnings
result$optimizer_entries <- .spatial_recovery_entries
result$elapsed_seconds <- proc.time()[["elapsed"]] - started
saveRDS(result, file.path(out, "result.rds"), version = 3)
summary <- result[setdiff(names(result), c(
  "trait_covariance", "source_strength", "range_strength_geometry",
  "initialization", "parameters", "gradient"
))]
jsonlite::write_json(summary, file.path(out, "result.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA,
                     null = "null", na = "null")
if (result$status == "error") quit(status = 1L)
if (!isTRUE(result$numerical_success) || result$optimizer_entries != 1L)
  quit(status = 2L)
cat("SPATIAL_RETAINED_FIT_RETURNED\n")
