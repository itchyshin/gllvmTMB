#!/usr/bin/env Rscript
## Run exactly one retained tree-axis fit.  Call through the parent's bounded
## process wrapper; R cannot reliably interrupt compiled TMB optimisation.
##
## Example:
##   GLLVM_TREE_AXIS_RESULTS=/private/tmp/.../results \
##   /private/tmp/.../bounded.py 300 /private/tmp/.../fit-C1.log \
##   Rscript --vanilla dev/tree-axis-latent/run-fit.R C1

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: Rscript --vanilla dev/tree-axis-latent/run-fit.R <fit-id>")
}

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]))
source(file.path(dirname(script_path), "fixture.R"))
library(gllvmTMB)

FIT_PLAN <- list(
  C1 = list(model = "morphology", shape = "long", size = "canary", start = 1L),
  C2 = list(model = "community_phylo", shape = "long", size = "canary", start = 1L),
  M1 = list(model = "morphology", shape = "long", size = "target", starts = 3L),
  M2 = list(model = "community_iid", shape = "long", size = "target", starts = 3L),
  M3 = list(model = "community_phylo", shape = "long", size = "target", starts = 3L),
  S1 = list(alias_of = "M1", restart = 2L),
  S2 = list(alias_of = "M1", restart = 3L),
  S3 = list(alias_of = "M2", restart = 2L),
  S4 = list(alias_of = "M2", restart = 3L),
  S5 = list(alias_of = "M3", restart = 2L),
  S6 = list(alias_of = "M3", restart = 3L),
  W1 = list(model = "morphology", shape = "wide", size = "target", start = 1L),
  W2 = list(model = "community_iid", shape = "wide", size = "target", start = 1L, optimizer = "optim"),
  W3 = list(model = "community_phylo", shape = "wide", size = "target", start = 1L, optimizer = "optim"),
  B2 = list(model = "community_iid", shape = "long", size = "target", starts = 3L, optimizer = "optim"),
  B3 = list(model = "community_phylo", shape = "long", size = "target", starts = 3L, optimizer = "optim")
)

fit_id <- args[[1L]]
if (!fit_id %in% names(FIT_PLAN)) {
  stop("Unknown fit ID. Use one of: ", paste(names(FIT_PLAN), collapse = ", "))
}
spec <- FIT_PLAN[[fit_id]]
start_spec <- list(seed = 202608501L, init_jitter = 0.15)

.tree_axis_formula_env <- function(tree, values = list()) {
  env <- list2env(c(list(tree = tree, all_of = tidyselect::all_of), values),
                  parent = globalenv())
  env
}

.tree_axis_fit_call <- function(fx, spec, start_spec) {
  formulas <- tree_axis_formulae(fx)
  n_starts <- if (is.null(spec$starts)) 1L else as.integer(spec$starts)
  control <- gllvmTMBcontrol(
    se = FALSE, n_init = n_starts,
    optimizer = if (is.null(spec$optimizer)) "nlminb" else spec$optimizer,
    optArgs = if (identical(spec$optimizer, "optim")) list(method = "BFGS") else list(),
    init_jitter = if (n_starts > 1L) start_spec$init_jitter else 0,
    start_method = list(method = NULL, jitter.sd = 0)
  )
  set.seed(start_spec$seed)
  if (identical(spec$model, "morphology")) {
    dat <- if (identical(spec$shape, "long")) fx$morphology$long else fx$morphology$wide
    key <- paste0("morphology_", spec$shape)
    formula <- formulas[[key]]
    environment(formula) <- .tree_axis_formula_env(
      fx$morphology$tree,
      list(morph_traits = fx$morphology$traits)
    )
    fit_args <- list(
      formula = formula, data = dat, unit = "species", cluster = "species",
      family = gaussian(), control = control, silent = TRUE
    )
    if (identical(spec$shape, "long")) fit_args$trait <- "trait"
    return(do.call(gllvmTMB, fit_args))
  }

  is_phylo <- identical(spec$model, "community_phylo")
  key <- paste0("community_", if (is_phylo) "phylo" else "iid", "_", spec$shape)
  formula <- formulas[[key]]
  environment(formula) <- .tree_axis_formula_env(
    fx$community$tree,
    list(community_species = fx$community$species)
  )
  if (identical(spec$shape, "long")) {
    return(gllvmTMB(
      formula, data = fx$community$long, trait = "trait", unit = "site_id",
      family = gaussian(), control = control, silent = TRUE
    ))
  }
  gllvmTMB(
    formula, data = fx$community$wide, column_data = fx$community$column_data,
    unit = "site_id", family = gaussian(), control = control, silent = TRUE
  )
}

.tree_axis_gaussian_map <- function(fit, expected_fixed_value) {
  map <- fit$tmb_obj$env$map$log_sigma_eps
  value <- tryCatch({
    fit$tmb_obj$env$parList()$log_sigma_eps
  }, error = function(e) NA_real_)
  list(
    mapped = !is.null(map),
    all_na = !is.null(map) && all(is.na(map)),
    map = if (is.null(map)) NULL else as.integer(map),
    fixed_value = value,
    expected_fixed_value = expected_fixed_value,
    fixed_value_ok = is.numeric(value) && all(is.finite(value)) &&
      max(abs(value - expected_fixed_value)) <= 1e-12
  )
}

.tree_axis_gradient <- function(fit) {
  tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
}

.tree_axis_sigma_public <- function(fit, level) {
  shared <- suppressMessages(extract_Sigma(
    fit, level = level, part = "shared", link_residual = "none"
  )$Sigma)
  unique <- suppressMessages(extract_Sigma(
    fit, level = level, part = "unique", link_residual = "none"
  )$s)
  total <- suppressMessages(extract_Sigma(
    fit, level = level, part = "total", link_residual = "none"
  )$Sigma)
  list(shared = shared, unique = unique, total = total)
}

.tree_axis_public_result <- function(fit, model) {
  fitted_out <- stats::fitted(fit)
  if (!is.data.frame(fitted_out) || !"est" %in% names(fitted_out) || ncol(fitted_out) < 3L) {
    stop("fitted() did not return the documented training-row data frame.")
  }
  ## Positions are intentional: predict.gllvmTMB_multi() constructs unit,
  ## species, trait, est in that order.  Names can repeat when unit and species
  ## are both called `species`, so name matching is unsafe here.
  out <- list(
    fitted = as.numeric(fitted_out$est),
    fitted_keys = paste(fitted_out[[1L]], fitted_out[[3L]], sep = "::")
  )
  if (identical(model, "morphology")) {
    out$phy <- .tree_axis_sigma_public(fit, "phy")
    out$unit <- .tree_axis_sigma_public(fit, "unit")
  } else {
    out$unit <- .tree_axis_sigma_public(fit, "unit")
    out$column_coef <- suppressMessages(extract_Sigma(fit, level = "column_coef"))
  }
  out
}

## Private instrumentation is confined to this developer runner. It does not
## alter the likelihood, optimizer, starts, or installed source. Capture actual
## optimizer attempts; no restart may disappear behind the selected fit.
.tree_axis_calls <- list()
.tree_axis_call_entries <- 0L
.tree_axis_attempt_limit <- if (is.null(spec$starts)) 1L else spec$starts
.tree_axis_restart_snapshots <- function(fit, calls, model, original_public) {
  obj <- fit$tmb_obj
  state <- list(last.par = obj$env$last.par,
                last.par.best = obj$env$last.par.best,
                value.best = obj$env$value.best)
  on.exit({
    obj$env$last.par <- state$last.par
    obj$env$last.par.best <- state$last.par.best
    obj$env$value.best <- state$value.best
  }, add = TRUE)
  stopifnot(length(calls) == .tree_axis_attempt_limit,
            !isTRUE(fit$warm_restart_provenance$warm_restart_attempted))
  objectives <- vapply(calls, function(x) x$result$objective, numeric(1))
  selected <- which.min(objectives)
  stopifnot(isTRUE(all.equal(fit$opt$par, calls[[selected]]$result$par,
                            tolerance = 1e-10)),
            abs(fit$opt$objective - objectives[selected]) <= 1e-8)
  attempts <- lapply(calls, function(call) {
    opt <- call$result
    obj$fn(opt$par)
    obj$env$last.par.best <- obj$env$last.par
    transient <- fit
    transient$opt <- opt
    transient$report <- obj$report()
    ## Materialize immediately: these transient objects share mutable TMB state.
    covariance <- list(unit = .tree_axis_sigma_public(transient, "unit"))
    if (identical(model, "morphology")) {
      covariance$phy <- .tree_axis_sigma_public(transient, "phy")
    } else {
      covariance$column_coef <- extract_Sigma(transient, level = "column_coef")
    }
    list(start = call$start, par = opt$par, objective = opt$objective,
         convergence = opt$convergence, max_gradient = max(abs(obj$gr(opt$par))),
         covariance = covariance)
  })
  reference <- original_public[intersect(c("unit", "phy", "column_coef"),
                                        names(original_public))]
  comparison <- isTRUE(all.equal(attempts[[selected]]$covariance, reference,
                                tolerance = 1e-8, check.attributes = TRUE))
  ## List order is irrelevant to the source-wise identity gate.
  comparison <- all(vapply(names(reference), function(n) {
    isTRUE(all.equal(attempts[[selected]]$covariance[[n]], reference[[n]],
                    tolerance = 1e-8, check.attributes = TRUE))
  }, logical(1)))
  starts_distinct <- length(calls) == 1L || all(vapply(calls[-1L], function(x) {
    max(abs(x$start - calls[[1L]]$start)) > 0
  }, logical(1)))
  list(attempts = attempts, selected = selected,
       selected_reconstruction_ok = comparison, starts_distinct = starts_distinct,
       optimizer_calls = length(calls), optimizer_entries = .tree_axis_call_entries,
       warm_restart_attempted = isTRUE(fit$warm_restart_provenance$warm_restart_attempted))
}

result_dir <- Sys.getenv(
  "GLLVM_TREE_AXIS_RESULTS",
  unset = file.path(tempdir(), "gllvmTMB-tree-axis-latent-results")
)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(result_dir, paste0("fit-", fit_id, ".rds"))
if (file.exists(out)) stop("Refusing to overwrite retained receipt: ", out)
if (!is.null(spec$alias_of)) {
  parent_path <- file.path(result_dir, paste0("fit-", spec$alias_of, ".rds"))
  if (!file.exists(parent_path)) {
    stop("Alias ", fit_id, " requires retained parent receipt ", parent_path)
  }
  parent_receipt <- readRDS(parent_path)
  row <- parent_receipt$restart_history
  if (is.null(row) || nrow(row) < spec$restart) {
    stop("Parent receipt has no retained restart row for alias ", fit_id)
  }
  saveRDS(list(
    schema = "tree-axis-latent-restart-alias-v1", id = fit_id,
    alias_of = spec$alias_of, restart = row[spec$restart, , drop = FALSE],
    fixture_checksum = parent_receipt$fixture_checksum,
    source_sha = parent_receipt$source_sha,
    snapshot = parent_receipt$restart_snapshots$attempts[[spec$restart]],
    parent_md5 = unname(tools::md5sum(parent_path)),
    note = "Alias receipt only: it is one optimizer attempt within the parent call, not an additional gllvmTMB fit."
  ), out)
  message("Wrote ", out)
  quit(status = 0L)
}
fixture <- make_tree_axis_fixture(spec$size)
fixture_checksum <- unname(tools::md5sum(normalizePath(file.path(dirname(script_path), "fixture.R"))))
response_sd <- if (identical(spec$model, "morphology")) {
  stats::sd(fixture$morphology$long$value)
} else {
  stats::sd(fixture$community$long$value)
}
expected_log_sigma_eps <- log(max(1e-3 * response_sd, 1e-6))
started <- Sys.time()
warnings <- character()
fit <- NULL
fit_error <- NULL
trace_name <- if (identical(spec$optimizer, "optim")) "optim" else ".gllvmTMB_run_nlminb"
trace_where <- if (identical(spec$optimizer, "optim")) asNamespace("stats") else asNamespace("gllvmTMB")
trace(trace_name, where = trace_where, print = FALSE,
  tracer = quote({
    .GlobalEnv$.tree_axis_call_entries <- .GlobalEnv$.tree_axis_call_entries + 1L
    if (.GlobalEnv$.tree_axis_call_entries > .GlobalEnv$.tree_axis_attempt_limit)
      stop("Optimizer-attempt budget exceeded; no additional optimization allowed")
    .tree_axis_start_copy <- if (.GlobalEnv$trace_name == "optim") par else args$start
    message("OPTIMIZER_ATTEMPT_ENTER id=", .GlobalEnv$fit_id,
            " attempt=", .GlobalEnv$.tree_axis_call_entries)
    entry_path <- file.path(.GlobalEnv$result_dir, paste0(.GlobalEnv$fit_id,
      "-attempt-", .GlobalEnv$.tree_axis_call_entries, "-start.rds"))
    if (file.exists(entry_path)) stop("Refusing to overwrite optimizer start receipt")
    saveRDS(.tree_axis_start_copy, entry_path)
  }),
  exit = quote({
    raw <- returnValue()
    normalized <- raw
    if (.GlobalEnv$trace_name == "optim") {
      normalized <- list(par = raw$par, objective = raw$value,
        convergence = raw$convergence, message = if (is.null(raw$message)) "" else raw$message,
        iterations = unname(raw$counts[["function"]]),
        evaluations = unname(raw$counts[["gradient"]]))
    }
    captured <- list(start = .tree_axis_start_copy, result = normalized, raw = raw)
    .GlobalEnv$.tree_axis_calls[[length(.GlobalEnv$.tree_axis_calls) + 1L]] <- captured
    exit_path <- file.path(.GlobalEnv$result_dir, paste0(.GlobalEnv$fit_id,
      "-attempt-", .GlobalEnv$.tree_axis_call_entries, "-result.rds"))
    if (file.exists(exit_path)) stop("Refusing to overwrite optimizer result receipt")
    saveRDS(captured, exit_path)
    message("OPTIMIZER_ATTEMPT_EXIT id=", .GlobalEnv$fit_id,
            " attempt=", .GlobalEnv$.tree_axis_call_entries,
            " code=", normalized$convergence, " objective=", normalized$objective)
  }))
fit <- tryCatch(
  withCallingHandlers(
    .tree_axis_fit_call(fixture, spec, start_spec),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  ),
  error = function(e) {
    fit_error <<- conditionMessage(e)
    NULL
  }
)
untrace(trace_name, where = trace_where)
elapsed_s <- as.numeric(difftime(Sys.time(), started, units = "secs"))
diagnostic <- if (is.null(fit)) NULL else tryCatch(
  gllvmTMB_diagnose(fit, verbose = FALSE), error = function(e) list(error = conditionMessage(e))
)
public <- if (is.null(fit)) NULL else tryCatch(
  .tree_axis_public_result(fit, spec$model),
  error = function(e) list(error = conditionMessage(e))
)
restart_snapshots <- if (is.null(fit)) NULL else tryCatch(
  .tree_axis_restart_snapshots(fit, .tree_axis_calls, spec$model, public),
  error = function(e) list(error = conditionMessage(e), raw_calls = .tree_axis_calls)
)
receipt <- list(
  schema = "tree-axis-latent-fit-v1",
  id = fit_id,
  spec = spec,
  start = start_spec,
  fixture_version = fixture$version,
  fixture_checksum = fixture_checksum,
  source_sha = tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA_character_),
  R = R.version.string,
  libpaths = .libPaths(),
  started = started,
  elapsed_s = elapsed_s,
  warnings = warnings,
  error = fit_error,
  fit = fit,
  objective = if (is.null(fit)) NA_real_ else fit$opt$objective,
  convergence = if (is.null(fit)) NA_integer_ else fit$opt$convergence,
  max_gradient = if (is.null(fit)) NA_real_ else .tree_axis_gradient(fit),
  gaussian = if (is.null(fit)) NULL else .tree_axis_gaussian_map(fit, expected_log_sigma_eps),
  diagnostic = diagnostic,
  public = public,
  restart_snapshots = restart_snapshots,
  optimizer_calls = .tree_axis_calls,
  optimizer_entries = .tree_axis_call_entries,
  runner_checksum = unname(tools::md5sum(script_path)),
  restart_history = if (is.null(fit)) NULL else fit$restart_history
)
saveRDS(receipt, out)
message("Wrote ", out)
if (!is.null(fit_error) || !is.null(public$error) || !is.null(restart_snapshots$error)) quit(status = 1L)
