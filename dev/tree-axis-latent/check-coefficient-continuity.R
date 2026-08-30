#!/usr/bin/env Rscript
# Four retained morphology endpoints only: G1 starts1-3 and GW1 start1.
# Capture the current wrapper before MakeADFun, then evaluate those fixed
# points. No standalone morphology optimization is authorized or performed.
# Expected runtime <10 seconds; require an external 60-second process cap.
library(gllvmTMB)
root <- Sys.getenv("GLLVM_TREE_AXIS_RESULTS")
stopifnot(identical(normalizePath(root),
  "/private/tmp/gllvm-tree-axis-latent-20260830/coefficient-standardization-7c88"))
outdir <- Sys.getenv("GLLVM_COEFFICIENT_CONTINUITY", file.path(root, "morphology-continuity-1"))
stopifnot(dir.create(outdir, recursive = FALSE, showWarnings = FALSE))
sha <- function(path) digest::digest(file = path, algo = "sha256")
manifest_path <- file.path(root, "provenance.json")
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
paths <- c(list.files("R", pattern = "[.]R$", full.names = TRUE), "src/gllvmTMB.cpp",
  "inst/include/gllvmTMB/detail/column_prior.hpp", "NAMESPACE", "DESCRIPTION")
stopifnot(setequal(names(manifest$source_sha256), paths),
  !anyDuplicated(names(manifest$source_sha256)),
  identical(normalizePath(find.package("gllvmTMB")), manifest$library),
  identical(sha(file.path(manifest$library, "libs/gllvmTMB.so")), manifest$dll_sha256),
  identical(unname(tools::md5sum("dev/tree-axis-latent/fixture.R")), "6c3bae640dd86491171cb20fbb56b0e4"),
  identical(manifest$fixture_md5, "6c3bae640dd86491171cb20fbb56b0e4"))
for (path in paths) stopifnot(identical(sha(path), manifest$source_sha256[[path]]))
source("dev/tree-axis-latent/fixture.R")
fixture <- make_tree_axis_fixture("target")
# Reuse reviewed call/output helpers only; never execute runner top-level code.
expr <- parse("dev/tree-axis-latent/run-fit.R")
wanted <- c(".tree_axis_formula_env", ".tree_axis_fit_call", ".tree_axis_sigma_public", ".tree_axis_public_result")
keep <- vapply(expr, function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
  is.name(x[[2L]]) && as.character(x[[2L]]) %in% wanted, logical(1))
stopifnot(sum(keep) == length(wanted))
eval(expr[keep], envir = globalenv())
.coefficient_continuity_optimizer_entries <- 0L
for (name in c("nlminb", "optim")) trace(name, where = asNamespace("stats"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.coefficient_continuity_optimizer_entries <- .GlobalEnv$.coefficient_continuity_optimizer_entries + 1L
    stop("No optimizer permitted in morphology continuity")
  }))
trace(".gllvmTMB_run_nlminb", where = asNamespace("gllvmTMB"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.coefficient_continuity_optimizer_entries <- .GlobalEnv$.coefficient_continuity_optimizer_entries + 1L
    stop("No optimizer permitted in morphology continuity")
  }))
metadata <- list(provenance = manifest, provenance_sha256 = sha(manifest_path),
  script_sha256 = sha("dev/tree-axis-latent/check-coefficient-continuity.R"),
  fixed_points = c("G1-start1", "G1-start2", "G1-start3", "GW1-start1"),
  outer_optimizer_calls = 0L, cap_seconds = 60L,
  permitted_payload_additions = "standardize_column_coef=0",
  meaning = "Same-source fixed-endpoint morphology continuity; no new morphology fit")
saveRDS(metadata, file.path(outdir, "admission.rds"))
capture <- function(r) {
  payload <- NULL
  testthat::local_mocked_bindings(MakeADFun = function(data, parameters, map, random, ...) {
    payload <<- list(data = data, parameters = parameters, map = map, random = random)
    stop("morphology-payload-captured", call. = FALSE)
  }, .package = "TMB")
  error <- tryCatch(.tree_axis_fit_call(fixture, r$spec, r$start), error = identity)
  stopifnot(inherits(error, "error"), identical(conditionMessage(error), "morphology-payload-captured"))
  payload
}
old_root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88"
results <- list()
for (id in c("G1", "GW1")) {
  path <- file.path(old_root, paste0("fit-", id, ".rds"))
  r <- readRDS(path)
  fit <- r$fit
  payload <- capture(r)
  old_data <- fit$tmb_data
  old_data$standardize_column_coef <- 0L
  stopifnot(setequal(names(payload$data), names(old_data)),
    all(vapply(names(old_data), function(name) identical(payload$data[[name]], old_data[[name]]), logical(1))),
    identical(payload$parameters, fit$tmb_params), identical(payload$map, fit$tmb_map),
    identical(payload$random, fit$random), identical(payload$data$standardize_column_coef, 0L))
  original <- readRDS(file.path("/private/tmp/gllvm-tree-axis-latent-20260830/results",
    paste0("fit-", if (id == "G1") "M1" else "W1", ".rds")))
  stopifnot(length(r$optimizer_calls) == length(original$optimizer_calls),
    all(vapply(seq_along(r$optimizer_calls), function(i)
      identical(r$optimizer_calls[[i]]$start, original$optimizer_calls[[i]]$start), logical(1))))
  saveRDS(list(payload = payload, retained_sha256 = sha(path)), file.path(outdir, paste0(id, "-payload.rds")))
  obj <- TMB::MakeADFun(payload$data, payload$parameters, map = payload$map,
    random = payload$random, DLL = "gllvmTMB", silent = TRUE)
  stopifnot(identical(obj$par, r$optimizer_calls[[1L]]$start))
  for (i in seq_along(r$optimizer_calls)) {
    key <- paste0(id, "-start", i)
    par <- r$optimizer_calls[[i]]$result$par
    dest <- file.path(outdir, paste0(key, ".rds"))
    entry <- list(id = key, retained_sha256 = sha(path), par = par, entered = Sys.time())
    saveRDS(entry, dest)
    warnings <- character()
    evaluated <- withCallingHandlers({
      value <- obj$fn(par)
      full <- obj$env$last.par
      report <- obj$report(full)
      gradient <- as.numeric(obj$gr(par))
      obj$env$last.par.best <- full
      transient <- fit
      transient$tmb_obj <- obj
      transient$tmb_data <- payload$data
      transient$tmb_params <- payload$parameters
      transient$tmb_map <- payload$map
      transient$opt <- r$optimizer_calls[[i]]$result
      transient$report <- report
      transient$standardized_column_coef <- FALSE
      public <- .tree_axis_public_result(transient, "morphology")
      covariance <- public[c("unit", "phy")]
      ref <- r$restart_snapshots$attempts[[i]]
      checks <- c(objective = is.finite(value) && abs(value - ref$objective) <= 1e-6,
        gradient = all(is.finite(gradient)) && max(abs(gradient)) < 1e-2 &&
          abs(max(abs(gradient)) - ref$max_gradient) <= 1e-6,
        covariance = all(vapply(names(covariance), function(name)
          isTRUE(all.equal(covariance[[name]], ref$covariance[[name]], tolerance = 1e-8)), logical(1))))
      if (i == r$restart_snapshots$selected) {
        checks <- c(checks, selected_public = isTRUE(all.equal(public, r$public, tolerance = 1e-6)),
          selected_reports = isTRUE(all.equal(report[names(fit$report)], fit$report, tolerance = 1e-6)),
          report_fields = setequal(names(report), names(fit$report)))
      }
      list(value = value, gradient = gradient, report = report, public = public,
        checks = checks, pass = all(checks %in% TRUE))
    }, warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); message(key, " WARNING ", conditionMessage(w))
      invokeRestart("muffleWarning")
    })
    entry$evaluated <- evaluated
    entry$warnings <- warnings
    entry$finished <- Sys.time()
    saveRDS(entry, dest)
    results[[key]] <- entry
    message(key, " objective_difference=", evaluated$value - r$optimizer_calls[[i]]$result$objective,
      " pass=", evaluated$pass)
    stopifnot(evaluated$pass)
  }
  TMB::FreeADFun(obj)
}
stopifnot(length(results) == 4L, .coefficient_continuity_optimizer_entries == 0L)
saveRDS(list(pass = TRUE, metadata = metadata, endpoints = results,
  outer_optimizer_calls = 0L), file.path(outdir, "receipt.rds"))
cat("COEFFICIENT_MORPHOLOGY_CONTINUITY_PASS_FOUR_FIXED_POINTS_NO_OUTER_OPTIMIZER\n")
