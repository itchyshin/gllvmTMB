#!/usr/bin/env Rscript
# Private Design 101 only.  It neither reads prior result roots nor writes any
# package path.  The Design-98 equations/TMB templates are loaded by explicit
# source path and fingerprinted; no Design-98 fixture, contract, task, or
# record is consulted.

d101_abort <- function(...) stop(paste0(..., collapse = ""), call. = FALSE)
d101_require <- function() {
  for (pkg in c("jsonlite", "digest", "TMB")) {
    if (!requireNamespace(pkg, quietly = TRUE)) d101_abort("Missing package: ", pkg)
  }
}
d101_hash_file <- function(path) digest::digest(file = path, algo = "sha256")
d101_hash_object <- function(x) digest::digest(serialize(x, NULL, version = 2L), algo = "sha256", serialize = FALSE)
d101_now <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
d101_json <- function(path, object) {
  tmp <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(unlink(tmp, force = TRUE), add = TRUE)
  writeLines(jsonlite::toJSON(object, auto_unbox = TRUE, null = "null", digits = 16, pretty = TRUE), tmp, useBytes = TRUE)
  if (!file.link(tmp, path)) d101_abort("Refusing nonexclusive publish: ", path)
  invisible(path)
}
d101_mkdir <- function(root) {
  for (dir in c(root, file.path(root, "records"), file.path(root, "receipts"))) {
    if (!dir.exists(dir) && !dir.create(dir, recursive = TRUE, showWarnings = FALSE)) d101_abort("Cannot create: ", dir)
  }
}
d101_with_rng <- function(code) {
  old_kind <- RNGkind(); had <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({do.call(RNGkind, as.list(old_kind)); if (had) assign(".Random.seed", old_seed, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)}, add = TRUE)
  force(code)
}
d101_fixture <- function() {
  truth <- list(
    beta = c(-0.60, -0.20, 0.18, 0.45, -0.36, 0.08),
    loading = rbind(c(0.78, 0), c(0.16, 0.66), c(-0.31, 0.35), c(0.43, -0.18), c(-0.26, -0.39), c(0.25, 0.42)),
    q = 2L, n = 24L, seed = 1012401L, rng_kind = c("Mersenne-Twister", "Inversion", "Rejection")
  )
  d101_with_rng({
    do.call(RNGkind, as.list(truth$rng_kind)); set.seed(truth$seed)
    u <- matrix(rnorm(truth$n * truth$q), truth$n, truth$q)
    p <- plogis(sweep(u %*% t(truth$loading), 2L, truth$beta, "+"))
    y <- matrix(rbinom(truth$n * length(truth$beta), 1L, as.vector(p)), truth$n, length(truth$beta))
    if (any(colSums(y) %in% c(0L, truth$n))) d101_abort("Fresh fixture has a degenerate trait")
    list(truth = truth, y = y, sha256 = d101_hash_object(y))
  })
}
d101_endpoint <- function(y, truth, method, start) {
  full <- method %in% c("QF", "JF")
  local <- d98_declared_local_start(nrow(y), full)
  initial <- d98_pack_variational(start$beta, start$loading_free, local$mean, local$chol_free)
  objective <- d98_build_va_objective(y, start$beta, start$loading_free, local$mean, local$chol_free, method, d98_gh(31L))
  p1 <- d98_fit_phase(objective, "va_phase1", initial, list(toy_smoke = TRUE, nlminb_iter_max = 180L, nlminb_eval_max = 260L))
  if (!is.finite(p1$objective) || any(!is.finite(p1$par))) return(list(status = "failed", stage = "phase1", reason = "non_finite_phase1", phase1 = p1))
  p2 <- d98_fit_phase(objective, "va_phase2", p1$par, list(toy_smoke = TRUE, bfgs_maxit = 280L, bfgs_reltol = 1e-10))
  if (!is.finite(p2$objective) || any(!is.finite(p2$par))) return(list(status = "failed", stage = "phase2", reason = "non_finite_phase2", phase1 = p1, phase2 = p2))
  final <- d98_unpack_variational(p2$par, nrow(y), ncol(y), full)
  gradient <- objective$gr(p2$par)
  grad_max <- max(abs(gradient))
  common <- d98_gh_log_marginal(y, final$beta, final$loading_free, d98_gh(61L))
  bound_r <- d98_variational_elbo(y, final$beta, final$loading_free, final$mean, final$chol_free, method, d98_gh(31L))
  healthy <- identical(p2$code, 0L) && is.finite(common) && all(is.finite(gradient)) && grad_max < 1e-3
  list(
    status = if (healthy) "healthy" else "unhealthy",
    reason = if (healthy) NULL else paste(c(if (p2$code != 0L) paste0("phase2_code=", p2$code), if (grad_max >= 1e-3) "gradient_gate", if (!is.finite(common)) "common_scale_non_finite"), collapse = ";"),
    phase1 = p1, phase2 = p2, objective = -p2$objective, objective_r = bound_r,
    objective_abs_disagreement = abs((-p2$objective) - bound_r), gradient_max = grad_max,
    common_gh61_log_marginal = common,
    beta = final$beta, loading_free = final$loading_free,
    Sigma = d98_loading_from_free(final$loading_free, ncol(y)) %*% t(d98_loading_from_free(final$loading_free, ncol(y))),
    metrics = d98_accuracy_metrics(d98_transform_variational(final$beta, final$loading_free, final$mean, final$chol_free, method), truth)
  )
}

d101_require()
design_dir <- normalizePath("dev/design101-va-jj-comparator", mustWork = TRUE)
repo <- normalizePath(file.path(design_dir, "..", ".."), mustWork = TRUE)
d98_dir <- file.path(repo, "dev", "design98-factorial-va-jj")
for (path in file.path(d98_dir, "R", c("oracle.R", "fits.R"))) if (!file.exists(path)) d101_abort("Missing reviewed equation source: ", path)
source(file.path(d98_dir, "R", "oracle.R")); source(file.path(d98_dir, "R", "fits.R"))
root <- "/private/tmp/gllvmtmb-design101b-q2-comparator"
if (dir.exists(root) || file.exists(root)) d101_abort("Output root already exists; immutable execution refuses reuse: ", root)
d101_mkdir(root)
fixture <- d101_fixture()
sources <- c(oracle = file.path(d98_dir, "R", "oracle.R"), fits = file.path(d98_dir, "R", "fits.R"), variational_cpp = file.path(d98_dir, "src", "design98_variational.cpp"))
contract <- list(design = 101L, label = "Design-101-B", approved_utc = "2026-07-24", output_root = root, fixture = list(n = fixture$truth$n, traits = length(fixture$truth$beta), q = fixture$truth$q, seed = fixture$truth$seed, rng_kind = fixture$truth$rng_kind, sha256 = fixture$sha256), methods = c("QD", "QF", "JD", "JF"), starts = c("A", "B", "C"), fitting_gh_order = 31L, common_scale_gh_order = 61L, optimizer = list(phase1 = "nlminb(iter=180,eval=260)", phase2 = "BFGS(maxit=280,reltol=1e-10)"), health_gate = "phase2 convergence=0; finite GH61; finite gradient; max_abs_gradient < 1e-3", scope = "one private fixture only; no EVA; no package path; no public claim", source_sha256 = vapply(sources, d101_hash_file, character(1)))
d101_json(file.path(root, "manifest.json"), contract)
d101_json(file.path(root, "fixture.json"), list(label = "d101b-single", truth = fixture$truth, y = fixture$y, sha256 = fixture$sha256))
# Gate 2: numerical values and AD gradients must be finite before any fit.
starts <- d98_declared_global_starts(fixture$y, fixture$truth)
logic <- lapply(contract$methods, function(method) {
  full <- method %in% c("QF", "JF"); local <- d98_declared_local_start(nrow(fixture$y), full); s <- starts[["A"]]
  o <- d98_build_va_objective(fixture$y, s$beta, s$loading_free, local$mean, local$chol_free, method, d98_gh(31L)); z <- c(s$beta, s$loading_free, as.vector(local$mean), as.vector(local$chol_free)); list(method = method, objective = -o$fn(z), gradient_max = max(abs(o$gr(z))), finite = is.finite(o$fn(z)) && all(is.finite(o$gr(z))))
})
names(logic) <- contract$methods
if (!all(vapply(logic, `[[`, logical(1), "finite"))) d101_abort("Pure-logic gate failed; no fitting started")
d101_json(file.path(root, "receipts", "pure-logic.json"), list(status = "passed", checks = logic, utc = d101_now()))
attempts <- list(); cursor <- 0L
for (method in contract$methods) for (start_id in contract$starts) {
  cursor <- cursor + 1L; task_id <- paste(method, start_id, sep = "-")
  result <- tryCatch(d101_endpoint(fixture$y, fixture$truth, method, starts[[start_id]]), error = function(e) list(status = "failed", stage = "exception", reason = conditionMessage(e)))
  record <- list(task_id = task_id, method = method, start_id = start_id, status = result$status, result = result, completed_utc = d101_now())
  d101_json(file.path(root, "records", paste0(task_id, ".json")), record)
  attempts[[cursor]] <- list(task_id = task_id, method = method, start_id = start_id, status = result$status, common_gh61_log_marginal = result$common_gh61_log_marginal %||% NA_real_, objective = result$objective %||% NA_real_, gradient_max = result$gradient_max %||% NA_real_, reason = result$reason %||% NULL)
}
healthy <- Filter(function(x) identical(x$status, "healthy"), attempts)
best <- if (length(healthy)) healthy[[which.max(vapply(healthy, `[[`, numeric(1), "common_gh61_log_marginal"))]] else NULL
d101_json(file.path(root, "summary.json"), list(status = if (length(healthy)) "complete_with_healthy_endpoints" else "complete_without_healthy_endpoints", attempts = attempts, healthy_count = length(healthy), best_common_scale_endpoint = best, retained_failures = Filter(function(x) !identical(x$status, "healthy"), attempts), scope_boundary = "single fresh fixture; descriptive numerical result only; no estimator ranking/general claim", completed_utc = d101_now()))
d101_json(file.path(root, "receipts", "terminal.json"), list(status = "PROGRESS_COMPLETE", required = c("manifest.json", "fixture.json", "receipts/pure-logic.json", "summary.json"), record_count = length(attempts), utc = d101_now()))
message("Design 101 complete: ", root)
