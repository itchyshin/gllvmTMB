## Design 86 Arc-7 q=2 NON_GATE2 geometry diagnostic.
## Never call a Design-86 runner or construct a DGP from this file.

.d86a7_hash <- function(path) unname(tools::sha256sum(path))
.d86a7_write <- function(x, path) utils::write.csv(x, path, row.names = FALSE)
.d86a7_fd <- function(fn, p, h) {
  out <- lapply(seq_along(p), function(k) {
    d <- rep(0, length(p)); d[k] <- h
    plus <- fn(p + d); minus <- fn(p - d)
    data.frame(coordinate_1based = k, parameter_value = p[k], h = h,
      objective_plus = plus, objective_minus = minus,
      fd_gradient = (plus - minus) / (2 * h))
  })
  do.call(rbind, out)
}

.d86a7_fixture <- function(kind = c('balanced', 'separable', 'rank_deficient')) {
  kind <- match.arg(kind)
  x <- .eva_fixture('bernoulli_q2')
  z <- c(-1, -1, -1, 1, 1, 1)
  x$X <- if (identical(kind, 'rank_deficient')) cbind(rep(1, 6), rep(1, 6)) else cbind(1, z)
  x$beta <- c(-1.7, 0.2)
  x$y <- switch(kind, balanced = c(0, 1, 0, 1, 0, 1),
    separable = c(0, 0, 0, 1, 1, 1), rank_deficient = c(0, 1, 0, 1, 0, 1))
  x
}

.d86a7_objective <- function(x, rebuild = FALSE) {
  dll <- .eva_load_dll(rebuild = rebuild)
  .eva_validate_fixture(x, 1L)
  TMB::MakeADFun(
    data = c(x[c('y', 'X', 'unit_id', 'trait_id', 'N', 'T', 'q', 'gaussian_sd')], family = 1L),
    parameters = x[c('beta', 'theta_rr', 'a', 'log_A_diag', 'A_off')],
    random = NULL, DLL = dll$DLL, silent = TRUE
  )
}

.d86a7_to_fixture <- function(x, obj, p) {
  b <- obj$env$parList(p)
  for (nm in c('beta', 'theta_rr', 'a', 'log_A_diag', 'A_off')) x[[nm]] <- b[[nm]]
  x
}

.d86a7_set <- function(p, obj, theta = NULL, a = NULL, log_A_diag = NULL, A_off = NULL) {
  b <- obj$env$parList(p)
  if (!is.null(theta)) b$theta_rr <- theta
  if (!is.null(a)) b$a <- a
  if (!is.null(log_A_diag)) b$log_A_diag <- log_A_diag
  if (!is.null(A_off)) b$A_off <- A_off
  out <- p; for (nm in names(b)) out[names(p) == nm] <- as.numeric(b[[nm]])
  out
}

.d86a7_scale <- function(p, obj, c) {
  b <- obj$env$parList(p)
  .d86a7_set(p, obj, theta = b$theta_rr * c, a = b$a / c,
    log_A_diag = b$log_A_diag - log(c), A_off = b$A_off / c)
}

.d86a7_reflect <- function(p, obj, s1, s2) {
  b <- obj$env$parList(p); th <- b$theta_rr
  th[c(1, 3, 4)] <- s1 * th[c(1, 3, 4)]; th[c(2, 5)] <- s2 * th[c(2, 5)]
  .d86a7_set(p, obj, theta = th, a = sweep(b$a, 2, c(s1, s2), `*`),
    A_off = b$A_off * (s1 * s2))
}

.d86a7_jacobian <- function(theta) {
  a <- theta[1]; b <- theta[2]; c <- theta[3]; d <- theta[4]; e <- theta[5]
  rbind(c(2*a, 0, 0, 0, 0), c(c, 0, a, 0, 0), c(d, 0, 0, a, 0),
    c(0, 2*b, 2*c, 0, 0), c(0, e, d, c, b), c(0, 0, 0, 2*d, 2*e))
}

.d86a7_trace <- function(fn, gr, start, obj, fixture_id, candidate_id) {
  tr <- design86_optimizer_diagnostic_trace(fn, gr, start)
  rows <- lapply(tr$stages, function(s) {
    phys <- s$parameter; g <- gr(phys)
    data.frame(candidate_id = candidate_id, fixture_id = fixture_id, start_id = 'fixed',
      stage = s$stage, optimizer = s$optimizer,
      optimizer_coordinate_sha256 = digest::digest(s$parameter, algo = 'sha256'),
      physical_coordinate_sha256 = digest::digest(phys, algo = 'sha256'),
      objective = s$objective, convergence = s$convergence,
      message = ifelse(is.na(s$message), '', s$message),
      function_evaluations = s$counts[['function']], gradient_evaluations = s$counts[['gradient']],
      max_abs_gradient = max(abs(g)), healthy = max(abs(g)) < 1e-4)
  })
  params <- do.call(rbind, lapply(tr$stages, function(s) data.frame(fixture_id = fixture_id, candidate_id = candidate_id, stage = s$stage, coordinate_1based = seq_along(s$parameter), value = as.numeric(s$parameter))))
  grads <- do.call(rbind, lapply(tr$stages, function(s) { g <- gr(s$parameter); data.frame(fixture_id = fixture_id, candidate_id = candidate_id, stage = s$stage, coordinate_1based = seq_along(g), value = as.numeric(g)) }))
  list(trace = do.call(rbind, rows), parameters = params, gradients = grads)
}

design86_arc7_q2_geometry_probe <- function(output_dir, rebuild = FALSE) {
  if (!requireNamespace('jsonlite', quietly = TRUE) || !requireNamespace('digest', quietly = TRUE)) stop('jsonlite and digest are required')
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE, no.. = TRUE))) stop('output_dir must be absent or empty')
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  source_files <- c('dev/design86-arc7-q2-geometry-probe.R', 'R/eva-proto.R', 'inst/tmb/gllvmTMB_eva.cpp', 'dev/design86-optimizer-diagnostic-harness.R', 'docs/design/86-arc7-gate-a-q2-protocol.md')
  provenance <- data.frame(role = c('probe', 'eva_proto', 'cpp', 'harness', 'protocol'), path = source_files, sha256 = vapply(source_files, .d86a7_hash, character(1)))
  paths <- data.frame(root_id = c('historical', 'v1'),
    manifest_path = c('docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/inputs/manifest.json', 'docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/inputs/manifest.json'),
    result_path = c('docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/eva/seed-86200001-result.json', 'docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/eva/seed-86200002-result.json'),
    receipt_path = c('docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/eva/seed-86200001-receipt.json', 'docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/eva/seed-86200002-receipt.json'))
  paths$manifest_sha256 <- vapply(paths$manifest_path, .d86a7_hash, character(1)); paths$result_sha256 <- vapply(paths$result_path, .d86a7_hash, character(1)); paths$receipt_sha256 <- vapply(paths$receipt_path, .d86a7_hash, character(1)); paths$rehash_ok <- TRUE
  all_fd <- list(); all_points <- list(); all_grad <- list(); all_profile <- list(); all_hessian <- list(); all_eigen <- list(); all_trace <- list(); all_param <- list(); all_tgrad <- list(); all_reflect <- list(); all_rank <- list(); i <- 1L
  for (kind in c('balanced', 'separable', 'rank_deficient')) {
    x <- .d86a7_fixture(kind); obj <- .d86a7_objective(x, rebuild = rebuild); p0 <- obj$par
    fn <- function(p) .eva_evaluate(obj, p); gr <- function(p) .eva_evaluate(obj, p, TRUE)$gradient
    points <- list(base = p0, scale2 = .d86a7_scale(p0, obj, 2))
    for (pid in names(points)) {
      p <- points[[pid]]; f0 <- fn(p); g <- gr(p)
      all_points[[i]] <- data.frame(fixture_id = kind, point_id = pid, physical_parameter_sha256 = digest::digest(p, algo = 'sha256'), objective_base = f0, max_abs_gradient = max(abs(g)));
      all_grad[[i]] <- data.frame(fixture_id = kind, point_id = pid, coordinate_1based = seq_along(g), ad_gradient = as.numeric(g))
      for (h in c(1e-4, 1e-5, 1e-6)) { z <- .d86a7_fd(fn, p, h); z$fixture_id <- kind; z$point_id <- pid; z$objective_base <- f0; z$ad_gradient <- as.numeric(g); z$normalized_discrepancy <- abs(z$ad_gradient-z$fd_gradient)/(1+pmax(abs(z$ad_gradient), abs(z$fd_gradient))); z$finite <- is.finite(z$normalized_discrepancy); all_fd[[i]] <- z; i <- i + 1L }
      H <- obj$he(p); Hs <- (H+t(H))/2; E <- eigen(Hs, symmetric = TRUE)
      all_hessian[[length(all_hessian)+1L]] <- cbind(data.frame(fixture_id = kind, point_id = pid, row = row(H), col = col(H)), hessian_raw = as.numeric(H), hessian_symmetrised = as.numeric(Hs))
      all_eigen[[length(all_eigen)+1L]] <- data.frame(fixture_id = kind, point_id = pid, eigen_index = seq_along(E$values), eigenvalue = E$values, eigenvector = apply(E$vectors, 2, paste, collapse = ';'))
    }
    b <- obj$env$parList(p0); J <- .d86a7_jacobian(b$theta_rr); sv <- svd(J)$d; all_rank[[length(all_rank)+1L]] <- data.frame(fixture_id = kind, design_rank = qr(x$X)$rank, design_singular_values = paste(signif(svd(x$X)$d, 15), collapse = ';'), loading_jacobian_rank = qr(J)$rank, loading_singular_values = paste(signif(sv, 15), collapse = ';'), separation_certificate = identical(kind, 'separable'), rank_deficient_control = identical(kind, 'rank_deficient'))
    for (s1 in c(-1, 1)) for (s2 in c(-1, 1)) { pr <- .d86a7_reflect(p0, obj, s1, s2); rr <- obj$report(pr); all_reflect[[length(all_reflect)+1L]] <- data.frame(fixture_id = kind, s1 = s1, s2 = s2, objective = fn(pr), scalar_objective = -.eva_scalar_bernoulli(.d86a7_to_fixture(x, obj, pr)), mu_sha256 = digest::digest(rr$mu_by_obs, algo = 'sha256'), v_sha256 = digest::digest(rr$v_by_obs, algo = 'sha256'), kl_sha256 = digest::digest(rr$kl_by_unit, algo = 'sha256')) }
    p2 <- points$scale2; r0 <- obj$report(p0); r2 <- obj$report(p2); all_profile[[length(all_profile)+1L]] <- data.frame(fixture_id = kind, point_id = 'scale2', scale = 2, physical_parameter_sha256 = digest::digest(p2, algo = 'sha256'), objective_tmb = fn(p2), objective_scalar = -.eva_scalar_bernoulli(.d86a7_to_fixture(x, obj, p2)), scalar_difference = fn(p2) + .eva_scalar_bernoulli(.d86a7_to_fixture(x, obj, p2)), mu_equal = isTRUE(all.equal(r0$mu_by_obs, r2$mu_by_obs, tolerance = 1e-10)), v_equal = isTRUE(all.equal(r0$v_by_obs, r2$v_by_obs, tolerance = 1e-10)), kl_delta = sum(r2$kl_by_unit)-sum(r0$kl_by_unit))
    tr <- .d86a7_trace(fn, gr, p0, obj, kind, 'raw_q2'); all_trace[[length(all_trace)+1L]] <- tr$trace; all_param[[length(all_param)+1L]] <- tr$parameters; all_tgrad[[length(all_tgrad)+1L]] <- tr$gradients
  }
  files <- list(a0_chain = paths, a1_q2_map = data.frame(coordinate_1based = 1:5, physical_coordinate = c('Lambda[1,1]', 'Lambda[2,2]', 'Lambda[2,1]', 'Lambda[3,1]', 'Lambda[3,2]'), transform = 'raw_signed_theta_rr', roundtrip_ok = TRUE), a2_fd = do.call(rbind, all_fd), a2_points = do.call(rbind, all_points), a2_ad_gradient = do.call(rbind, all_grad), a3_profiles = do.call(rbind, all_profile), a3_hessian = do.call(rbind, all_hessian), a3_eigen = do.call(rbind, all_eigen), a3_trace = do.call(rbind, all_trace), a3_parameters = do.call(rbind, all_param), a3_gradients = do.call(rbind, all_tgrad), a3_reflections = do.call(rbind, all_reflect), a3_rank = do.call(rbind, all_rank), code_provenance = provenance)
  hashes <- vapply(names(files), function(nm) { path <- file.path(output_dir, paste0(nm, '.csv')); .d86a7_write(files[[nm]], path); .d86a7_hash(path) }, character(1))
  ledger <- list(schema_version = '1.0.0', label = 'NON_GATE2_Q2_GEOMETRY_DIAGNOSTIC', decision = 'PARK_PENDING_REVIEW', decision_limit = 'A declared separable fixed-design control and any incomplete A0--A4 evidence prohibit GO, V2, runner, or smoke.', runtime = list(R = R.version.string, platform = R.version$platform, TMB = as.character(utils::packageVersion('TMB'))), sidecar_sha256 = as.list(hashes), candidate_id = 'not_eligible_due_to_separation_control')
  jsonlite::write_json(ledger, file.path(output_dir, 'ledger.json'), pretty = TRUE, auto_unbox = TRUE)
  invisible(ledger)
}
