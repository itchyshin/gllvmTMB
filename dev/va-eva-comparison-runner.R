## Private executable comparisons for the VA/EVA approximation-engine spine.
##
## This file is intentionally outside the package API.  Run with:
##
##   Rscript --vanilla dev/va-eva-comparison-runner.R
##
## It writes an RDS manifest and a Markdown receipt below
## dev/va-eva-engine-spine/receipts/.  Every call is retained, including a
## failed optimizer: LA and gllvm are comparators, never truth, and VA/EVA
## negative objectives are never pooled.

`%||%` <- function(x, y) if (is.null(x)) y else x

va_eva_runner_root <- function(path = getwd()) {
  normalizePath(path, mustWork = TRUE)
}

va_eva_hash_object <- function(x) digest::digest(x, algo = "sha256", serialize = TRUE)

va_eva_file_hashes <- function(root, paths) {
  full <- file.path(root, paths)
  stats::setNames(unname(tools::sha256sum(full)), paths)
}

va_eva_git_head <- function(root) {
  trimws(system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE))
}

va_eva_software_provenance <- function() {
  packages <- c("TMB", "gllvm", "gllvmTMB", "devtools", "digest", "jsonlite")
  list(
    R = R.version.string, platform = R.version$platform,
    packages = stats::setNames(vapply(packages, function(pkg) {
      if (requireNamespace(pkg, quietly = TRUE)) as.character(utils::packageVersion(pkg)) else NA_character_
    }, character(1)), packages),
    library_paths = .libPaths(), rng_kind = RNGkind()
  )
}

va_eva_runner_load <- function(root = va_eva_runner_root()) {
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("The private runner requires devtools::load_all().", call. = FALSE)
  }
  devtools::load_all(root, quiet = TRUE, export_all = FALSE)
  source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
  ## The adapters are deliberately unexported package code.  Source the three
  ## private files into this runner's environment as well, so the dev-only
  ## executable has no public API dependency.
  va_eva_source_private_engines(root, envir = .GlobalEnv)
  invisible(root)
}

## Alignment table (private comparison cells)
##
## | Symbol | gllvmTMB route | Fixture / reference | Quantity retained |
## | --- | --- | --- | --- |
## | y_it, n_it >= 2 | latent(..., unique = FALSE), binomial logit | fixed-seed multi-trial VA fixture | VA, gllvm VA, gllvmTMB LA records |
## | y_it in {0,1} | latent(..., unique = FALSE), binomial logit | sealed EVA Gate-1 Bernoulli fixture | EVA, gllvm EVA, gllvmTMB LA records |
## | E_q[log p(y|eta)] | no fitted-model claim | scalar integration / sealed scalar oracle | reference-only exact record |
##
## The first two rows use the same loadings-only latent subset.  The third is
## an independent small-coordinate oracle; it is not a marginal-likelihood
## ranking or a general truth calculation for the fitted models.

va_eva_multitrial_fixture <- function(seed = 240726L, N = 18L, T = 2L, trials = 8L) {
  set.seed(seed)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), times = N)
  lambda <- c(0.65, -0.40)
  beta <- c(-0.25, 0.30)
  z <- stats::rnorm(N)
  eta <- beta[trait] + lambda[trait] * z[unit]
  y <- stats::rbinom(N * T, size = trials, prob = stats::plogis(eta))
  long <- data.frame(
    unit = factor(unit), trait = factor(paste0("t", trait)),
    succ = y, fail = trials - y, value = y, n_trials = trials
  )
  list(
    y = matrix(y, nrow = N, ncol = T, byrow = TRUE),
    n_trials = matrix(trials, nrow = N, ncol = T),
    long = long, X = stats::model.matrix(~ 0 + trait, long),
    unit_id = unit, trait_id = trait, q = 1L,
    seed = seed, N = N, T = T, trials = trials,
    fixture_checksum = va_eva_hash_object(list(y, trials, beta, lambda, seed))
  )
}

va_eva_sealed_eva_fixture <- function() {
  x <- .eva_fixture("bernoulli")
  long <- data.frame(
    unit = factor(x$unit_id + 1L), trait = factor(paste0("t", x$trait_id + 1L)),
    value = x$y
  )
  list(
    x = x,
    y = matrix(x$y, nrow = x$N, ncol = x$T, byrow = TRUE),
    long = long, fixture_checksum = va_eva_hash_object(x)
  )
}

va_eva_call_record <- function(name, scenario, call, extractor = NULL) {
  started <- proc.time()[["elapsed"]]
  answer <- tryCatch(force(call), error = identity)
  elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(answer, "error")) {
    return(list(
      name = name, scenario = scenario, status = "error",
      runtime_seconds = elapsed, result = NULL,
      diagnostics = list(message = conditionMessage(answer))
    ))
  }
  extracted <- tryCatch(
    if (is.null(extractor)) list() else extractor(answer), error = identity
  )
  if (inherits(extracted, "error")) {
    return(list(
      name = name, scenario = scenario, status = "extract_error",
      runtime_seconds = elapsed, result = answer,
      diagnostics = list(message = conditionMessage(extracted))
    ))
  }
  list(
    name = name, scenario = scenario,
    status = extracted$status %||%
      if (isTRUE(extracted$convergence %||% FALSE)) "ok" else "not_converged",
    runtime_seconds = elapsed, result = answer, diagnostics = extracted
  )
}

va_eva_gllvm_extract <- function(fit) {
  L <- tryCatch(as.matrix(gllvm::getLoadings(fit)), error = function(e) NULL)
  ## gllvm 2.0.11's accessor can fail on the small no-X fixtures used here;
  ## its fitted theta and sigma.lv still define the documented scaled loadings.
  if (is.null(L) || !length(L)) {
    theta <- fit$params$theta %||% NULL
    sigma <- fit$params$sigma.lv %||% NULL
    if (is.matrix(theta) && length(sigma) == ncol(theta) && all(is.finite(sigma))) {
      L <- sweep(theta, 2L, as.numeric(sigma), "*")
    }
  }
  beta0 <- as.numeric(fit$params$beta0 %||% numeric())
  separated <- length(beta0) && any(abs(beta0) > 15)
  list(
    convergence = isTRUE(fit$convergence),
    status = if (separated) "boundary_or_invalid_for_comparison" else NULL,
    logLik = as.numeric(fit$logL %||% NA_real_),
    LambdaLambdaT = if (is.matrix(L) && length(L)) tcrossprod(L) else matrix(numeric(), 0L, 0L),
    objective_note = "gllvm logL retained only within its named method; never pooled with VA/EVA scores."
  )
}

va_eva_laplace_extract <- function(fit) {
  L <- fit$report$Lambda_B %||% matrix(numeric(), 0L, 0L)
  fixed <- tryCatch(
    as.numeric(fit$tmb_obj$env$last.par.best[grepl("^b_fix", names(fit$tmb_obj$env$last.par.best))]),
    error = function(e) numeric()
  )
  separated <- length(fixed) && any(abs(fixed) > 15)
  list(
    convergence = identical(fit$opt$convergence, 0L),
    status = if (separated) "boundary_or_invalid_for_comparison" else NULL,
    negative_laplace_objective = as.numeric(fit$opt$objective %||% NA_real_),
    LambdaLambdaT = if (is.matrix(L)) tcrossprod(L) else matrix(numeric(), 0L, 0L),
    objective_note = "gllvmTMB Laplace objective is a comparator diagnostic, not truth."
  )
}

va_eva_va_quadrature_ladder <- function(result, fx, orders = c(15L, 25L, 61L)) {
  raw <- result$engine_result
  if (is.null(raw$best$par) || is.null(raw$best$objective)) {
    return(list(available = FALSE, reason = "VA fit supplied no fixed coordinates."))
  }
  validated <- .va_r3_validate_data(
    y = as.vector(fx$y), n_trials = as.vector(fx$n_trials), X = fx$X,
    unit_id = fx$unit_id, trait_id = fx$trait_id, q = fx$q
  )
  values <- vapply(orders, function(H) {
    parameters <- .va_r3_default_parameters(validated, 1L)
    obj <- .va_r3_make_objective(validated, H = H, parameters = parameters, silent = TRUE)
    as.numeric(obj$fn(raw$best$par))
  }, numeric(1))
  list(
    available = TRUE, orders = as.integer(orders), negative_elbo_gh = values,
    max_abs_spread = max(values) - min(values),
    coordinates = "best H61 VA-R3 fit; no re-optimisation at ladder orders"
  )
}

va_eva_run_multitrial_track <- function(fx = va_eva_multitrial_fixture()) {
  internal <- va_eva_call_record(
    "internal_va_r3", "complete_multitrial_binomial_logit",
    .approximation_engine_fit(
      "va_r3", y = as.vector(fx$y), n_trials = as.vector(fx$n_trials),
      X = fx$X, unit_id = fx$unit_id, trait_id = fx$trait_id, q = fx$q,
      H = 61L, rank_source = "fixed_fixture", silent = TRUE
    ),
    function(x) list(
      convergence = identical(x$status, "healthy"), score = x$score,
      health = x$diagnostics$health,
      quadrature_ladder = va_eva_va_quadrature_ladder(x, fx)
    )
  )
  laplace <- va_eva_call_record(
    "gllvmTMB_laplace", "complete_multitrial_binomial_logit",
    gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
      data = fx$long, family = stats::binomial(), unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0.01, se = FALSE)
    ), va_eva_laplace_extract
  )
  gllvm_va <- va_eva_call_record(
    "gllvm_va", "complete_multitrial_binomial_logit",
    gllvm::gllvm(
      y = fx$y, Ntrials = fx$n_trials, num.lv = 1L, family = "binomial",
      link = "logit", method = "VA", seed = 1L, n.init = 1L, sd.errors = FALSE,
      control = list(max.iter = 1000L, maxit = 1000L)
    ), va_eva_gllvm_extract
  )
  list(
    fixture = fx, rng_seed_after = .Random.seed,
    calls = list(internal_va_r3 = internal, laplace = laplace, gllvm_va = gllvm_va)
  )
}

va_eva_run_bernoulli_track <- function(fx = va_eva_sealed_eva_fixture()) {
  set.seed(240727L)
  internal <- va_eva_call_record(
    "internal_eva_gate1", "sealed_bernoulli_logit",
    .approximation_engine_fit("eva", fixture = "bernoulli", silent = TRUE),
    function(x) list(
      status = "evaluated_fixed_gate1_fixture", convergence = FALSE,
      score = x$score, evaluation = x$evaluation
    )
  )
  laplace <- va_eva_call_record(
    "gllvmTMB_laplace", "sealed_bernoulli_logit",
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
      data = fx$long, family = stats::binomial(), unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0.01, se = FALSE)
    ), va_eva_laplace_extract
  )
  gllvm_eva <- va_eva_call_record(
    "gllvm_eva", "sealed_bernoulli_logit",
    gllvm::gllvm(
      y = fx$y, num.lv = 1L, family = "binomial", link = "logit", method = "EVA",
      seed = 1L, n.init = 1L, sd.errors = FALSE,
      control = list(max.iter = 1000L, maxit = 1000L)
    ), va_eva_gllvm_extract
  )
  list(
    fixture = fx, rng_seed_after = .Random.seed,
    calls = list(internal_eva_gate1 = internal, laplace = laplace, gllvm_eva = gllvm_eva)
  )
}

va_eva_va_exact_reference <- function() {
  ## VA scalar ELBO at fixed coordinates; its likelihood expectation is an
  ## independently integrated reference, not an optimisation target.
  va_data <- .va_r3_validate_data(
    y = 3L, n_trials = 8L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L
  )
  va_par <- list(beta = -0.3, theta_rr = 0.7, m = matrix(0.2, 1L, 1L),
                 log_L_diag = matrix(log(0.8), 1L, 1L), L_off = matrix(numeric(), 1L, 0L))
  va_obj <- .va_r3_make_objective(va_data, H = 61L, parameters = va_par, silent = TRUE)
  va_report <- va_obj$report(va_obj$par)
  mu <- -0.3 + 0.7 * 0.2
  variance <- (0.7 * 0.8)^2
  softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
  exact_expectation <- stats::integrate(
    function(z) softplus(mu + sqrt(variance) * z) * stats::dnorm(z),
    -Inf, Inf, rel.tol = 1e-12
  )$value
  va_exact <- lchoose(8, 3) + 3 * mu - 8 * exact_expectation

  list(
    label = "independent scalar integration at fixed VA coordinates",
    expected_loglik = va_exact, reported_expected_loglik = va_report$expected_loglik,
    max_abs_gap = abs(va_exact - va_report$expected_loglik)
  )
}

va_eva_eva_exact_reference <- function() {
  eva_x <- .eva_fixture("bernoulli")
  eva_obj <- .eva_make_objective("bernoulli", silent = TRUE)
  eva_value <- as.numeric(.eva_evaluate(eva_obj))
  list(
    label = "sealed R scalar parity reference at fixed EVA coordinates",
    independence = "R-versus-C++ parity only; shares sealed Gate-1 fixture and R helper source",
    scalar_oracle = .eva_scalar_bernoulli(eva_x),
    negative_eva_value = eva_value,
    max_abs_gap = abs(.eva_scalar_bernoulli(eva_x) + eva_value)
  )
}

va_eva_write_comparison_receipt <- function(result, root = va_eva_runner_root()) {
  out <- file.path(root, "dev", "va-eva-engine-spine", "receipts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  manifest <- file.path(out, "2026-07-26-va-eva-executable-comparison.rds")
  saveRDS(result, manifest)
  manifest_hash <- unname(tools::sha256sum(manifest))
  calls <- c(result$multitrial$calls, result$bernoulli$calls)
  lines <- c(
    "# VA/EVA executable comparator receipt", "",
    "Private evidence only. The VA scalar integration is an independent fixed-coordinate oracle; EVA is sealed R-versus-C++ parity only. gllvmTMB Laplace and gllvm VA/EVA are comparators only.", "",
    "| Track | Call | Status | Runtime (s) |", "| --- | --- | --- | ---: |",
    vapply(calls, function(x) sprintf("| %s | %s | %s | %.3f |", x$scenario, x$name, x$status, x$runtime_seconds), character(1)),
    "", sprintf("VA scalar reference gap: %.3e", result$exact$va_scalar$max_abs_gap),
    sprintf("EVA scalar reference gap: %.3e", result$exact$eva_gate1$max_abs_gap), "",
    sprintf("Manifest SHA-256: %s", manifest_hash),
    "No cross-engine objective ranking was calculated. Call-level failures and boundary-invalid calls are retained in the RDS manifest."
  )
  writeLines(lines, file.path(out, "2026-07-26-va-eva-executable-comparison.md"))
  invisible(result)
}

va_eva_run_child_track <- function(track, root) {
  output <- tempfile(paste0("va-eva-", track, "-"), fileext = ".rds")
  runner <- file.path(root, "dev", "va-eva-comparison-runner.R")
  text <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("--vanilla", runner),
    env = c(
      paste0("VA_EVA_EXECUTABLE_TRACK=", track),
      paste0("VA_EVA_RESULT_PATH=", output),
      paste0("VA_EVA_RUNNER_ROOT=", root)
    ), stdout = TRUE, stderr = TRUE
  ))
  status <- attr(text, "status") %||% 0L
  if (!identical(status, 0L) || !file.exists(output)) {
    stop(
      "Child comparison track ", track, " failed (status ", status, "): \n",
      paste(text, collapse = "\n"), call. = FALSE
    )
  }
  readRDS(output)
}

va_eva_run_executable_comparisons <- function(root = va_eva_runner_root()) {
  stop(
    "Use dev/va-eva-executable-comparisons.sh. It starts each template-owning track from a fresh shell process.",
    call. = FALSE
  )
}

va_eva_assemble_executable_comparisons <- function(root = va_eva_runner_root()) {
  out <- file.path(root, "dev", "va-eva-engine-spine", "receipts", "executable-run")
  child_files <- c("multitrial.rds", "bernoulli.rds", "va_exact.rds", "eva_exact.rds")
  result <- list(
    provenance = list(
      root = root, git_head = va_eva_git_head(root),
      timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), research_only = TRUE,
      track_isolation = "one fresh R process per template-owning track",
      software = va_eva_software_provenance(),
      source_sha256 = va_eva_file_hashes(root, c(
        "R/va-r3-proto.R", "inst/tmb/gllvmTMB_va_r3.cpp", "R/eva-proto.R",
        "inst/tmb/gllvmTMB_eva.cpp", "R/approximation-engine.R",
        "dev/va-eva-comparator.R", "dev/va-eva-comparison-runner.R"
      )),
      child_sha256 = stats::setNames(unname(tools::sha256sum(file.path(out, child_files))), child_files)
    ),
    multitrial = readRDS(file.path(out, "multitrial.rds")),
    bernoulli = readRDS(file.path(out, "bernoulli.rds")),
    exact = list(
      va_scalar = readRDS(file.path(out, "va_exact.rds")),
      eva_gate1 = readRDS(file.path(out, "eva_exact.rds"))
    )
  )
  stopifnot(result$exact$va_scalar$max_abs_gap < 1e-9, result$exact$eva_gate1$max_abs_gap < 1e-10)
  va_eva_write_comparison_receipt(result, root)
  result
}

va_eva_run_requested_child <- function() {
  track <- Sys.getenv("VA_EVA_EXECUTABLE_TRACK")
  path <- Sys.getenv("VA_EVA_RESULT_PATH")
  root <- va_eva_runner_root(Sys.getenv("VA_EVA_RUNNER_ROOT", getwd()))
  if (!nzchar(track) || !nzchar(path)) return(invisible(FALSE))
  va_eva_runner_load(root)
  result <- switch(track,
    multitrial = va_eva_run_multitrial_track(),
    bernoulli = va_eva_run_bernoulli_track(),
    va_exact = va_eva_va_exact_reference(),
    eva_exact = va_eva_eva_exact_reference(),
    stop("Unknown VA/EVA child track: ", track, call. = FALSE)
  )
  saveRDS(result, path)
  cat("VA_EVA_CHILD_TRACK_PASS ", track, "\n", sep = "")
  TRUE
}

va_eva_run_requested_child()

if (identical(Sys.getenv("VA_EVA_EXECUTABLE_COMPARISONS"), "true")) {
  result <- va_eva_assemble_executable_comparisons()
  cat("VA_EVA_EXECUTABLE_COMPARISONS_PASS\n")
  cat(paste(vapply(c(result$multitrial$calls, result$bernoulli$calls), `[[`, character(1), "status"), collapse = ","), "\n")
}
