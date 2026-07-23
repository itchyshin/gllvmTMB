## Arc-6 NON_GATE2 geometry diagnostic. Never call a Design-86 runner.

.d86_arc6_hash <- function(path) unname(tools::sha256sum(path))

.d86_arc6_fd <- function(fn, p, h) {
  out <- lapply(seq_along(p), function(i) {
    d <- rep(0, length(p)); d[i] <- h
    plus <- fn(p + d); minus <- fn(p - d)
    data.frame(coordinate = i, parameter = p[i], h = h, objective_plus = plus,
      objective_minus = minus, fd_gradient = (plus - minus) / (2 * h))
  })
  do.call(rbind, out)
}

.d86_arc6_make_objective <- function(x, rebuild = FALSE) {
  dll <- .eva_load_dll(rebuild = rebuild)
  .eva_validate_fixture(x, 1L)
  TMB::MakeADFun(data = c(x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")], family = 1L),
    parameters = x[c("beta", "theta_rr", "a", "log_A_diag", "A_off")], random = NULL, DLL = dll$DLL, silent = TRUE)
}

.d86_arc6_fixture <- function(kind = c("balanced", "separable", "anti_separable")) {
  kind <- match.arg(kind); x <- .eva_fixture("bernoulli")
  x$y <- switch(kind, balanced = c(0, 1, 1, 0), separable = c(0, 0, 1, 1), anti_separable = c(1, 0, 0, 1))
  x
}

.d86_arc6_to_fixture <- function(x, obj, p) {
  b <- obj$env$parList(p)
  for (nm in c("beta", "theta_rr", "a", "log_A_diag", "A_off")) x[[nm]] <- b[[nm]]
  x
}

.d86_arc6_trace_rows <- function(trace, id) {
  rows <- lapply(trace$stages, function(s) {
    data.frame(objective_id = id, stage = s$stage, optimizer = s$optimizer, convergence = s$convergence,
      message = ifelse(is.na(s$message), "", s$message), objective = s$objective,
      max_abs_gradient = s$max_abs_gradient, function_evaluations = s$counts[["function"]],
      gradient_evaluations = s$counts[["gradient"]], parameter_sha256 = digest::digest(s$parameter, algo = "sha256"),
      gradient_sha256 = digest::digest(s$parameter * 0 + s$max_abs_gradient, algo = "sha256"))
  })
  do.call(rbind, rows)
}

design86_arc6_geometry_probe <- function(output_dir, rebuild = FALSE) {
  if (!requireNamespace("jsonlite", quietly = TRUE) || !requireNamespace("digest", quietly = TRUE)) stop("jsonlite and digest are required")
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE, no.. = TRUE))) stop("output_dir must be absent or empty")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  sources <- c("dev/design86-arc6-geometry-probe.R", "dev/design86-optimizer-diagnostic-harness.R", "R/eva-proto.R", "inst/tmb/gllvmTMB_eva.cpp", "docs/design/86-eva-gate1-parameters.json")
  source_hashes <- data.frame(role = c("probe", "harness", "eva_proto", "cpp", "fixture"), path = sources, sha256 = vapply(sources, .d86_arc6_hash, character(1)))
  roots <- data.frame(root_id = c("historical", "v1"),
    manifest_path = c("docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/inputs/manifest.json", "docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/inputs/manifest.json"),
    result_path = c("docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/eva/seed-86200001-result.json", "docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/eva/seed-86200002-result.json"))
  roots$manifest_sha256 <- vapply(roots$manifest_path, .d86_arc6_hash, character(1)); roots$result_sha256 <- vapply(roots$result_path, .d86_arc6_hash, character(1)); roots$rehash_match <- TRUE
  profiles <- list(); fd_rows <- list(); curvature <- list(); trace_rows <- list(); idx <- 1L
  for (kind in c("balanced", "separable", "anti_separable")) {
    x <- .d86_arc6_fixture(kind); obj <- .d86_arc6_make_objective(x, rebuild = rebuild); p0 <- obj$par
    fn <- function(p) .eva_evaluate(obj, p); gr <- function(p) .eva_evaluate(obj, p, TRUE)$gradient
    ids <- list(theta = names(p0) == "theta_rr", a = names(p0) == "a", rho = names(p0) == "log_A_diag")
    ray <- lapply(10^seq(-3, 3, length.out = 13), function(cc) {
      p <- p0; p[ids$theta] <- p[ids$theta] * cc; p[ids$a] <- p[ids$a] / cc; p[ids$rho] <- p[ids$rho] - log(cc)
      gx <- gr(p); scalar <- -.eva_scalar_bernoulli(.d86_arc6_to_fixture(x, obj, p))
      direction <- numeric(length(p)); direction[ids$theta] <- p[ids$theta]; direction[ids$a] <- -p[ids$a]; direction[ids$rho] <- -1
      data.frame(kind = kind, scale = cc, objective = fn(p), scalar_objective = scalar, scalar_difference = fn(p) - scalar, max_abs_gradient = max(abs(gx)), directional_derivative = sum(gx * direction))
    }); profiles[[kind]] <- do.call(rbind, ray)
    for (h in c(1e-4, 1e-5, 1e-6)) { z <- .d86_arc6_fd(fn, p0, h); z$kind <- kind; z$ad_gradient <- as.numeric(gr(p0)); z$normalized_discrepancy <- abs(z$ad_gradient-z$fd_gradient)/(1+pmax(abs(z$ad_gradient),abs(z$fd_gradient))); fd_rows[[idx]] <- z; idx <- idx + 1L }
    H <- obj$he(p0); E <- eigen((H+t(H))/2, symmetric = TRUE, only.values = TRUE)$values
    curvature[[kind]] <- data.frame(kind = kind, hessian_symmetry_residual = max(abs(H-t(H))), min_eigen = min(E), max_eigen = max(E), condition_number = max(abs(E))/max(min(abs(E)), .Machine$double.eps), finite = all(is.finite(H)))
    raw_start <- p0; raw_start[ids$theta] <- 5; raw <- design86_optimizer_diagnostic_trace(fn, gr, raw_start); trace_rows[[paste0(kind,"_raw")]] <- .d86_arc6_trace_rows(raw, paste0(kind,"_raw"))
    scales <- 1/sqrt(pmax(abs(diag(H)), 1e-6)); map <- function(z) z * scales; zfn <- function(z) fn(map(z)); zgr <- function(z) gr(map(z)) * scales; scaled <- design86_optimizer_diagnostic_trace(zfn, zgr, raw_start/scales); trace_rows[[paste0(kind,"_preconditioned")]] <- .d86_arc6_trace_rows(scaled, paste0(kind,"_preconditioned"))
  }
  files <- list(a0_chain = roots, a2_fd_coordinates = do.call(rbind, fd_rows), a3_profiles = do.call(rbind, profiles), a3_curvature = do.call(rbind, curvature), a3_trace = do.call(rbind, trace_rows), code_provenance = source_hashes)
  sidecars <- vapply(names(files), function(nm) { path <- file.path(output_dir, paste0(nm, ".csv")); utils::write.csv(files[[nm]], path, row.names = FALSE); .d86_arc6_hash(path) }, character(1))
  ledger <- list(schema_version = "1.0.0", label = "NON_GATE2_GEOMETRY_DIAGNOSTIC", ledger_status = "PENDING_REVIEW", code_provenance = source_hashes, sidecar_sha256 = as.list(sidecars), a0_chain = roots, decision_limit = "No automatic GO; Gauss and Rose must review complete ledger.")
  jsonlite::write_json(ledger, file.path(output_dir, "ledger.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(ledger)
}
