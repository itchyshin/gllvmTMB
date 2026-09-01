## One public-route fit per immutable scientific or engineering identity.

.respinfo_script <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(.respinfo_script) || !nzchar(.respinfo_script)) .respinfo_script <- file.path("dev", "isdm-requalification", "response-information", "runner.R")
.respinfo_dir <- dirname(normalizePath(.respinfo_script, mustWork = TRUE))
source(file.path(.respinfo_dir, "harness.R"), local = TRUE)
source(file.path(.respinfo_dir, "records.R"), local = TRUE)

.isdm_respinfo_sha256 <- function(path) {
  out <- system2("sha256sum", path, stdout = TRUE, stderr = TRUE)
  if (!identical(as.integer(attr(out, "status") %||% 0L), 0L) || length(out) != 1L) stop("SHA-256 failed", call. = FALSE)
  sub("[[:space:]].*$", "", out)
}

isdm_respinfo_verify_runtime_identity <- function(qualification) {
  required <- c("schema", "source_sha", "source_tree", "package_path", "dll_path", "dll_sha256", "harness_manifest_path", "harness_manifest_sha256", "harness_root")
  allowed_schema <- c("isdm-response-information-qualification-v2", "isdm-response-information-runtime-identity-v1")
  if (!is.list(qualification) || !all(required %in% names(qualification)) || !qualification$schema %in% allowed_schema) stop("qualification is malformed", call. = FALSE)
  suppressPackageStartupMessages(library(gllvmTMB))
  package_path <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
  dlls <- getLoadedDLLs(); dll_path <- if ("gllvmTMB" %in% names(dlls)) normalizePath(dlls[["gllvmTMB"]][["path"]], mustWork = TRUE) else NA_character_
  if (!identical(package_path, qualification$package_path) || !identical(dll_path, qualification$dll_path) ||
      !identical(.isdm_respinfo_sha256(dll_path), qualification$dll_sha256) ||
      !identical(.isdm_respinfo_sha256(qualification$harness_manifest_path), qualification$harness_manifest_sha256)) stop("loaded package/DLL or harness differs from qualification", call. = FALSE)
  old <- setwd(qualification$harness_root); on.exit(setwd(old), add = TRUE)
  check <- system2("sha256sum", c("-c", qualification$harness_manifest_path), stdout = TRUE, stderr = TRUE)
  if (!identical(as.integer(attr(check, "status") %||% 0L), 0L)) stop("harness content differs from qualification", call. = FALSE)
  invisible(TRUE)
}

isdm_respinfo_public_formula <- function() value ~ 0 + trait + trait:env + offset(log_support) + latent(0 + trait | cell_id, d = 1)
isdm_respinfo_fit <- function(fixture) suppressMessages(gllvmTMB::gllvmTMB(isdm_respinfo_public_formula(), data = fixture$data, trait = "trait", unit = "cell_id", family = fixture$families, silent = TRUE))
.isdm_respinfo_relative_frobenius <- function(estimate, truth) sqrt(sum((estimate - truth)^2)) / sqrt(sum(truth^2))

.isdm_respinfo_named_fixed <- function(fit) {
  values <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  if (length(values) != length(fit$X_fix_names)) stop("fixed-effect extraction length mismatch", call. = FALSE)
  stats::setNames(as.numeric(values), fit$X_fix_names)
}

.isdm_respinfo_bind_fixed_truth <- function(fit, truth_fixed, tolerance = 1e-8) {
  X <- as.matrix(fit$X_fix %||% fit$tmb_data$X_fix); if (is.null(colnames(X))) colnames(X) <- fit$X_fix_names
  if (nrow(X) != length(truth_fixed) || qr(X)$rank != ncol(X)) stop("fixed truth cannot be bound to fitted design", call. = FALSE)
  value <- qr.solve(X, truth_fixed); residual <- max(abs(as.numeric(X %*% value) - truth_fixed))
  if (!is.finite(residual) || residual > tolerance) stop("fixed truth does not lie in fitted design column space", call. = FALSE)
  stats::setNames(as.numeric(value), colnames(X))
}

.isdm_respinfo_peak_rss_bytes <- function() {
  path <- "/proc/self/status"; if (!file.exists(path)) return(NA_real_)
  line <- grep("^VmHWM:", readLines(path, warn = FALSE), value = TRUE)
  if (length(line) != 1L) return(NA_real_)
  as.numeric(sub("^VmHWM:[[:space:]]*([0-9]+).*$", "\\1", line)) * 1024
}

isdm_respinfo_payload <- function(fit, fixture) {
  truth <- diagnostic_nonspatial_truth_components(fixture); estimate <- diagnostic_extract_nonspatial(fit, fixture)
  trait <- as.character(fixture$scoring$trait)
  truth_vectors <- lapply(truth[c("fixed", "shared", "full")], .diagnostic_surface_vector, scoring = fixture$scoring)
  metrics <- lapply(names(truth_vectors), function(target) diagnostic_surface_metrics(estimate[[target]], truth_vectors[[target]], trait)); names(metrics) <- names(truth_vectors)
  sigma <- gllvmTMB::extract_Sigma(fit, level = "unit", part = "total", link_residual = "none")$Sigma
  unique <- gllvmTMB::extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none")$s
  psi <- diag(as.numeric(if (is.matrix(unique)) diag(unique) else unique), nrow = 3L); dimnames(psi) <- dimnames(fixture$truth$Psi)
  fixed <- .isdm_respinfo_named_fixed(fit); fixed_truth <- .isdm_respinfo_bind_fixed_truth(fit, fixture$data$truth_fixed)
  aligned <- intersect(names(fixed), names(fixed_truth)); source_terms <- grep("^isdm_source:", aligned, value = TRUE)
  source_error <- if (length(source_terms)) sqrt(mean((fixed[source_terms] - fixed_truth[source_terms])^2)) else NA_real_
  list(diagnostics = list(convergence = as.integer(fit$opt$convergence), pd_hessian = isTRUE(fit$sd_report$pdHess), objective = as.numeric(fit$opt$objective), max_gradient = max(abs(fit$tmb_obj$gr(fit$opt$par))), finite = is.finite(fit$opt$objective), peak_rss_bytes = .isdm_respinfo_peak_rss_bytes()),
       raw = list(surfaces = estimate[c("fixed", "shared", "full")], trait = trait, Sigma = sigma, Psi = psi, fixed = fixed, fixed_truth = fixed_truth,
                  truth_surfaces = truth_vectors, truth_Sigma = fixture$truth$Sigma, truth_Psi = fixture$truth$Psi,
                  baseline_data_sha256 = fixture$design$baseline_data_sha256),
       metrics = c(metrics, list(Sigma_relative_frobenius = .isdm_respinfo_relative_frobenius(sigma, fixture$truth$Sigma), Psi_relative_error = diag(abs(psi - fixture$truth$Psi) / diag(fixture$truth$Psi)), source_coefficient_rmse = source_error, full_public_identity_error = estimate$identity_error, sign_invariance_error = estimate$sign_invariance$max_error)),
       design = fixture$design)
}

isdm_respinfo_run_one <- function(task, output_dir, qualification) {
  started <- isdm_respinfo_write_started(task, output_dir, qualification)
  begin <- Sys.time(); entered <- FALSE; fit <- NULL; payload <- list(); condition <- NULL
  tryCatch({ isdm_respinfo_verify_runtime_identity(qualification); fixture <- isdm_respinfo_fixture(task); set.seed(task$optimizer_seed[[1L]]); entered <- TRUE; fit <- isdm_respinfo_fit(fixture); payload <- isdm_respinfo_payload(fit, fixture) }, error = function(e) condition <<- e, interrupt = function(e) condition <<- e)
  status <- if (!is.null(fit)) "fit_returned" else if (inherits(condition, "interrupt")) "interrupted" else if (!is.null(condition)) "error" else "error"
  record <- isdm_respinfo_terminal_record(started, status, as.numeric(difftime(Sys.time(), begin, units = "secs")), payload, condition, optimizer_entered = entered)
  isdm_respinfo_write_terminal(record, output_dir); invisible(record)
}
