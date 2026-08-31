#!/usr/bin/env Rscript
# Fixed endpoint checks ONLY: no outer optimizer and no replacement fit.
# Run against the newly installed DLL after the compiled small-fixture tests.
# Expected wall time 10-30 seconds; external process cap 60 seconds.
library(gllvmTMB)
source("dev/tree-axis-latent/fixture.R")
outdir <- Sys.getenv("GLLVM_TREE_AXIS_COLLAPSE_CHECKS")
manifest <- Sys.getenv("GLLVM_TREE_AXIS_COLLAPSE_PROVENANCE")
stopifnot(nzchar(outdir), nzchar(manifest), file.exists(manifest))
provenance <- jsonlite::read_json(manifest, simplifyVector = TRUE)
stopifnot(identical(normalizePath(find.package("gllvmTMB")), provenance$library),
  identical(digest::digest(file = file.path(provenance$library, "libs/gllvmTMB.so"),
                           algo = "sha256"), provenance$dll_sha256),
  identical(unname(tools::md5sum("dev/tree-axis-latent/fixture.R")),
            "6c3bae640dd86491171cb20fbb56b0e4"))
expected_sources <- c(list.files("R", pattern="[.]R$", full.names=TRUE),
    "src/gllvmTMB.cpp", "inst/include/gllvmTMB/detail/column_prior.hpp", "NAMESPACE", "DESCRIPTION")
stopifnot(length(provenance$source_sha256) > 0L,
  !is.null(names(provenance$source_sha256)),
  !anyDuplicated(names(provenance$source_sha256)),
  setequal(names(provenance$source_sha256),expected_sources))
for (path in names(provenance$source_sha256)) stopifnot(identical(
  digest::digest(file = path, algo = "sha256"), provenance$source_sha256[[path]]))
if (!dir.create(outdir, recursive = FALSE, showWarnings = FALSE)) {
  stop("Refusing to overwrite any cell-collapse check directory")
}
root <- "/private/tmp/gllvm-tree-axis-latent-20260830"
saved <- file.path(root, "repaired-nlminb-7c88")
algebra_path <- "dev/tree-axis-latent/endpoint-score.R"
endpoint <- readRDS(file.path(saved, "endpoint-score.rds"))
stopifnot(identical(digest::digest(file = algebra_path, algo = "sha256"),
                    endpoint$script_sha256))
# Load only the reviewed algebra and its frozen fixture setup; never run the
# old script's top-level evaluator or its old-library provenance check.
lines <- readLines(algebra_path)
first <- which(lines == "f<-make_tree_axis_fixture('target')$community")
last <- grep("^out<-list\\(provenance=", lines)
stopifnot(length(first) == 1L, length(last) == 1L, last > first)
eval(parse(text = lines[first:(last - 1L)]), envir = environment())
plan <- data.frame(id = c(rep("M1", 3), "W1", rep("N2", 3), rep("N3", 3)),
                   start = c(1:3, 1L, 1:3, 1:3))
metadata <- list(provenance = provenance, plan = plan,
  runner_sha256 = digest::digest(file = "dev/tree-axis-latent/check-cell-collapse.R", algo = "sha256"),
  algebra_sha256 = endpoint$script_sha256, outer_optimizer_calls = 0L,
  cap_seconds = 60L, cumulative_optimizer_attempts = 21L, ceiling = 33L,
  tiny_steps = c(0, 1e-4, -1e-4, 1e-6, -1e-6),
  equivalence_limits = list(absolute_nll = 1e-6, max_score = 1e-6,
    max_eta = 1e-6, public_covariance = 1e-8, ordination = 1e-6),
  tiny_difference_limit = 1e-5,
  meaning = "Implementation equivalence and value precision checks; no article convergence gate waiver")
saveRDS(metadata, file.path(outdir, "admission.rds"))

make_tape <- function(fit, collapsed) {
  dat <- fit$tmb_data
  dat$integrate_gaussian_diag_B <- as.integer(collapsed)
  mp <- fit$tmb_map
  pars <- fit$tmb_obj$env$parList()
  if (collapsed) stopifnot(getFromNamespace(".gllvmTMB_gaussian_diag_B_eligible", "gllvmTMB")(
    dat, mp, pars, REML = FALSE, estimator = "ml",
    control = list(integration = "laplace", aghq = FALSE)))
  if (collapsed) mp$s_B <- factor(rep(NA_integer_, length(pars$s_B))) else mp$s_B <- NULL
  random <- setdiff(fit$random, "s_B")
  if (!collapsed) random <- fit$random
  stopifnot("s_B" %in% fit$random, all(fit$tmb_data$is_y_observed == 1L))
  obj <- TMB::MakeADFun(dat, pars, map = mp, random = random, DLL = "gllvmTMB", silent = TRUE)
  stopifnot(identical(obj$env$inner.control, fit$tmb_obj$env$inner.control),
    identical(obj$env$inner.method, fit$tmb_obj$env$inner.method))
  list(obj = obj, data = dat, map = mp, random = random, collapsed = collapsed)
}
public_covariance <- function(fit, morphology) {
  cov <- function(level) list(
    shared = suppressMessages(extract_Sigma(fit, level = level, part = "shared", link_residual = "none")$Sigma),
    unique = suppressMessages(extract_Sigma(fit, level = level, part = "unique", link_residual = "none")$s),
    total = suppressMessages(extract_Sigma(fit, level = level, part = "total", link_residual = "none")$Sigma))
  ans <- list(unit = cov("unit"))
  if (morphology) ans$phy <- cov("phy") else ans$column_coef <- extract_Sigma(fit, level = "column_coef")
  ans
}
evaluate <- function(tape, fit, par, morphology) {
  warnings <- character()
  result <- withCallingHandlers({
  obj <- tape$obj
  stopifnot(identical(names(par), names(obj$par)))
  value <- obj$fn(par)
  gradient <- as.numeric(obj$gr(par))
  obj$env$last.par.best <- obj$env$last.par
  full <- obj$env$last.par
  report <- obj$report(full)
  transient <- fit
  transient$tmb_obj <- obj
  transient$tmb_data <- tape$data
  transient$tmb_map <- tape$map
  transient$random <- tape$random
  transient$integrated_gaussian_diag_B <- tape$collapsed
  transient$opt$par <- par
  transient$opt$objective <- value
  transient$report <- report
  transient$sd_report <- NULL
  list(value = value, gradient = gradient,
    inner_max_gradient = max(abs(obj$env$f(full, order = 1)[obj$env$random])),
    report = report, s_B = if (tape$collapsed) report$s_B_conditional_mean else
      matrix(full[names(full) == "s_B"], fit$n_traits, fit$n_sites),
    covariance = public_covariance(transient, morphology),
    fitted = stats::fitted(transient),
    prediction = stats::predict(transient),
    newdata_prediction = stats::predict(transient, newdata = fit$data),
    ordination = extract_ordination(transient, level = "unit"))
  }, warning = function(w) {
    text <- conditionMessage(w)
    warnings <<- c(warnings, text)
    message("CELL_COLLAPSE_EVALUATION_WARNING collapsed=", tape$collapsed, ": ", text)
    invokeRestart("muffleWarning")
  })
  result$warnings <- warnings
  result
}
close_pair <- function(pair) for (tape in pair) TMB::FreeADFun(tape$obj)
results <- list()
for (id in unique(plan$id)) {
  path <- file.path(if (id %in% c("M1", "W1")) file.path(root, "results") else saved,
                    paste0("fit-", id, ".rds"))
  r <- readRDS(path)
  fit <- r$fit
  pair <- list(old = make_tape(fit, FALSE), new = make_tape(fit, TRUE))
  morphology <- id %in% c("M1", "W1")
  for (i in plan$start[plan$id == id]) {
    key <- paste0(id, "-start", i)
    par <- r$optimizer_calls[[i]]$result$par
    entry <- list(id = key, receipt_sha256 = digest::digest(file = path, algo = "sha256"),
                  par = par, entered = Sys.time())
    dest <- file.path(outdir, paste0(key, ".rds"))
    saveRDS(entry, dest)
    entry$old <- evaluate(pair$old, fit, par, morphology)
    entry$new <- evaluate(pair$new, fit, par, morphology)
    entry$differences <- list(value = entry$new$value - entry$old$value,
      max_gradient = max(abs(entry$new$gradient - entry$old$gradient)),
      max_eta = max(abs(entry$new$report$eta - entry$old$report$eta)),
      max_cell_mode = max(abs(entry$new$s_B - entry$old$s_B)))
    if (!morphology) {
      oracle <- independent(par, r$gaussian$fixed_value, id == "N3")
      entry$oracle <- list(value = oracle$value, gradient = oracle$gradient,
        collapsed_value_error = entry$new$value - oracle$value,
        collapsed_max_score_error = max(abs(entry$new$gradient - oracle$gradient)))
    }
    entry$finished <- Sys.time()
    saveRDS(entry, dest)
    results[[key]] <- entry
    message(key, " nll_delta=", entry$differences$value,
      " gradient_delta=", entry$differences$max_gradient,
      " eta_delta=", entry$differences$max_eta)
    stopifnot(is.finite(entry$new$value), all(is.finite(entry$new$gradient)),
      abs(entry$differences$value) < 1e-6, entry$differences$max_gradient < 1e-6,
      entry$differences$max_eta < 1e-6, entry$differences$max_cell_mode < 1e-6,
      isTRUE(all.equal(entry$new$covariance, entry$old$covariance, tolerance = 1e-8)),
      isTRUE(all.equal(entry$new$fitted, entry$old$fitted, tolerance = 1e-6)),
      isTRUE(all.equal(entry$new$prediction, entry$old$prediction, tolerance = 1e-6)),
      isTRUE(all.equal(entry$new$newdata_prediction, entry$old$newdata_prediction, tolerance = 1e-6)),
      isTRUE(all.equal(entry$new$ordination, entry$old$ordination, tolerance = 1e-6)))
    if (!morphology) stopifnot(abs(entry$oracle$collapsed_value_error) < 1e-6,
                               entry$oracle$collapsed_max_score_error < 1e-6)
  }
  close_pair(pair)
}

# Exact saved failed IID endpoint and the already declared analytic-gradient
# direction: five fixed points, without a line search or a new selected start.
r <- readRDS(file.path(saved, "fit-N2.rds"))
base <- r$optimizer_calls[[1L]]$result$par
eps <- r$gaussian$fixed_value
exact_base <- independent(base, eps, FALSE)
direction <- exact_base$gradient / sqrt(sum(exact_base$gradient^2))
pair <- list(old = make_tape(r$fit, FALSE), new = make_tape(r$fit, TRUE))
tiny <- list()
for (i in seq_along(metadata$tiny_steps)) {
  h <- metadata$tiny_steps[i]
  par <- base + h * direction
  a <- independent(par, eps, FALSE)
  point <- list(step = h, par = par, oracle = a$value, oracle_gradient = a$gradient)
  dest <- file.path(outdir, paste0("tiny-", i, ".rds"))
  saveRDS(point, dest)
  for (name in names(pair)) {
    obj <- pair[[name]]$obj
    point[[name]] <- list(value = obj$fn(par), gradient = as.numeric(obj$gr(par)))
  }
  saveRDS(point, dest)
  tiny[[i]] <- point
}
close_pair(pair)
precision <- lapply(c(1e-4, 1e-6), function(h) {
  a <- tiny[[which(metadata$tiny_steps == h)]]
  b <- tiny[[which(metadata$tiny_steps == -h)]]
  c(step = h, analytic = sum(exact_base$gradient * direction),
    oracle = (a$oracle - b$oracle)/(2*h),
    old = (a$old$value - b$old$value)/(2*h),
    collapsed = (a$new$value - b$new$value)/(2*h))
})
receipt <- list(metadata = metadata, endpoints = results, tiny = tiny, precision = precision)
saveRDS(receipt, file.path(outdir, "receipt.rds"))
print(precision)
stopifnot(all(vapply(precision, function(x) abs(x["collapsed"] - x["oracle"]) < 1e-5, logical(1))))
cat("CELL_COLLAPSE_FIXED_ENDPOINT_CHECKS_PASS_NO_OUTER_OPTIMIZER\n")
