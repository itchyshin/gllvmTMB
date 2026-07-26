#!/usr/bin/env Rscript
## Private HVT-1 certification runner.  It consumes frozen local campaign
## coordinates but never refits, changes a fixture, or emits a gap unless every
## adaptive certification check for that cell passes.

hvt1_abort <- function(...) stop(..., call. = FALSE)
`%||%` <- function(x, y) if (is.null(x)) y else x

hvt1_root <- function(path = getwd()) {
  path <- normalizePath(path, mustWork = TRUE)
  while (!file.exists(file.path(path, "R", "va-r3-proto.R"))) {
    parent <- dirname(path)
    if (identical(parent, path)) hvt1_abort("Run inside the HVT-1 worktree.")
    path <- parent
  }
  path
}

hvt1_sha256 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

hvt1_lock <- function(root, campaign_path) {
  paths <- c(
    va_r3_proto = file.path(root, "R", "va-r3-proto.R"),
    tmb_template = file.path(root, "inst", "tmb", "gllvmTMB_va_r3.cpp"),
    old_runner = file.path(root, "dev", "va-variance-gate", "run-va-variance-gate.R"),
    calibration_receipt = file.path(root, "dev", "va-variance-gate", "calibration-receipts", "2026-07-26-post-calibration-cell-map.md"),
    source_manifest = file.path(root, "dev", "va-variance-gate", "source-manifest.md")
  )
  expected <- c(
    va_r3_proto = "ecf5d4b76880339262d1e60c7937115848a43590033449212d39f36ff49acdf9",
    tmb_template = "8f13267a27835592db8b9e63f4e86ca5a4fdb91cd425f22600df11317981e065",
    old_runner = "7f9890fd33cf952c3a2742e9d05d398ef5c3f57c38a60f9662ba785748602c03",
    calibration_receipt = "4c3cf66914db44121f263a8cbd10426a023717eebf97077158427201e3b67d3e",
    source_manifest = "84a8b2a59314409c837cdc889aef8939bb07563fcc08e9177d120998b6210eec"
  )
  observed <- vapply(paths, hvt1_sha256, character(1))
  campaign_expected <- "6f4c899587cd57454b3bd8cf5f174c76ce31229516a83a03246616c56d7bb64c"
  frozen_base <- "f22800812b123eb3e3dcf8e08db72769a45c10ae"
  head <- system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE)
  base_ancestor <- identical(system2("git", c("-C", root, "merge-base", "--is-ancestor", frozen_base, unname(head))), 0L)
  clean <- identical(system2("git", c("-C", root, "diff", "--quiet", "f22800812b123eb3e3dcf8e08db72769a45c10ae", "--", names(paths))), 0L)
  list(
    pass = base_ancestor && clean &&
      identical(observed, expected) && identical(hvt1_sha256(campaign_path), campaign_expected),
    git_head = unname(head), frozen_source_base = frozen_base, frozen_base_ancestor = base_ancestor, clean_frozen_inputs = clean,
    expected = expected, observed = observed,
    campaign_rds = normalizePath(campaign_path, mustWork = FALSE),
    campaign_rds_sha256 = hvt1_sha256(campaign_path), campaign_rds_expected_sha256 = campaign_expected,
    adaptive_oracle_sha256 = hvt1_sha256(file.path(root, "dev", "va-variance-gate", "high-variance-oracle.R")),
    adaptive_runner_sha256 = hvt1_sha256(file.path(root, "dev", "va-variance-gate", "run-high-variance-oracle.R")),
    R = R.version.string,
    TMB = if (requireNamespace("TMB", quietly = TRUE)) as.character(utils::packageVersion("TMB")) else NA_character_,
    platform = R.version$platform
  )
}

hvt1_fixture <- function(campaign, band) {
  cell <- campaign$results[[paste0("observed_band_", band)]]
  fixture <- cell$fixture
  fixture$response_sha256 <- digest::digest(as.integer(fixture$y), algo = "sha256", serialize = TRUE)
  fixture$observed_variance_band <- cell$observed_variance_band
  fixture$observed_max_projected_variance <- cell$observed_max_projected_variance
  fixture
}

hvt1_unpack_lambda <- function(theta) {
  if (length(theta) != 3L || any(!is.finite(theta))) hvt1_abort("Retained theta_rr is not q=2,T=2.")
  rbind(c(theta[[1L]], 0), c(theta[[3L]], theta[[2L]]))
}

hvt1_coordinate_record <- function(campaign, band) {
  cell <- campaign$results[[paste0("observed_band_", band)]]
  attempts <- cell$optimizer_attempts
  best <- attempts[[which.min(vapply(attempts, `[[`, numeric(1), "objective"))]]
  par <- best$par
  beta <- unname(par[seq_len(2L)])
  theta <- unname(par[3:5])
  list(beta = beta, theta_rr = theta, Lambda = hvt1_unpack_lambda(theta), fixed_elbo = cell$fixed_elbo$values[["H61"]],
       gh_H501 = cell$truth$values[["H501"]], gh_H801 = cell$truth$values[["H801"]],
       gh_tail = cell$truth$tail_spread, observed = cell$observed_max_projected_variance,
       coordinates_sha256 = digest::digest(list(beta = beta, theta = theta), algo = "sha256", serialize = TRUE))
}

hvt1_pass <- function(value, tolerance) is.finite(value) && abs(value) <= tolerance

hvt1_q1_reference <- function(fixture, beta, Lambda, control) {
  per_unit <- vapply(seq_len(fixture$N), function(i) {
    rows <- which(fixture$unit_id == i)
    log_integrand <- function(u) {
      eta <- as.numeric(fixture$X[rows, , drop = FALSE] %*% beta) +
        as.numeric(Lambda[fixture$trait_id[rows], 1L]) * u
      sum(stats::dbinom(fixture$y[rows], fixture$n_trials[rows], stats::plogis(eta), log = TRUE)) + stats::dnorm(u, log = TRUE)
    }
    mode <- stats::optim(0, function(u) -log_integrand(u), method = "BFGS")$par
    shift <- log_integrand(mode)
    integrand <- function(u) vapply(u, function(point) exp(log_integrand(point) - shift), numeric(1))
    shift + log(stats::integrate(integrand, lower = -control$tail_bound, upper = control$tail_bound,
                         rel.tol = control$rel.tol, abs.tol = control$abs.tol,
                         subdivisions = control$subdivisions, stop.on.error = TRUE)$value)
  }, numeric(1))
  list(per_unit = per_unit, total = sum(per_unit), independently_coded = TRUE)
}

hvt1_cell <- function(band, campaign, oracle_control) {
  fixture <- hvt1_fixture(campaign, band)
  fixed <- hvt1_coordinate_record(campaign, band)
  zero_oracle <- hvt1_high_variance_oracle(fixture, fixed$beta, matrix(0, 2, 2), oracle_control, routes = "forward")
  zero_analytic <- list(per_unit = stats::dbinom(fixture$y, fixture$n_trials,
    stats::plogis(as.numeric(fixture$X %*% fixed$beta)), log = TRUE))
  zero_analytic$total <- sum(zero_analytic$per_unit)
  zero_diff <- zero_oracle$total - zero_analytic$total
  q1_lambda <- fixed$Lambda; q1_lambda[, 2L] <- 0
  q1_oracle <- hvt1_high_variance_oracle(fixture, fixed$beta, q1_lambda, oracle_control, routes = "forward")
  q1_reference <- hvt1_q1_reference(fixture, fixed$beta, q1_lambda, oracle_control)
  q1_diff <- q1_oracle$total - q1_reference$total
  baseline <- hvt1_high_variance_oracle(fixture, fixed$beta, fixed$Lambda, oracle_control)
  tight_control <- utils::modifyList(oracle_control, list(rel.tol = 1e-12, abs.tol = 1e-12, subdivisions = 2000L, tail_bound = 16))
  tightened <- hvt1_high_variance_oracle(fixture, fixed$beta, fixed$Lambda, tight_control)
  stable_diff <- if (identical(as.character(band), "4") && is.finite(fixed$gh_H801) && fixed$gh_tail <= 1e-3) baseline$total - fixed$gh_H801 else NA_real_
  checks <- list(
    zero_loading = hvt1_pass(zero_diff, 1e-10),
    effective_q1 = hvt1_pass(q1_diff, 1e-8) && max(abs(q1_oracle$per_unit$forward - q1_reference$per_unit)) <= 1e-9,
    stable_GH = if (identical(as.character(band), "4")) hvt1_pass(stable_diff, 1e-3) else TRUE,
    baseline_routes = all(vapply(c("forward", "reverse"), function(route)
      all(is.finite(baseline$per_unit[[route]])) && !length(unlist(baseline$errors[[route]])), logical(1))),
    forward_reverse_agreement = hvt1_pass(baseline$totals[["forward"]] - baseline$totals[["reverse"]], 1e-8),
    baseline_transforms = all(vapply(c("centred_scaled", "shifted_scaled"), function(route)
      all(is.finite(baseline$per_unit[[route]])) && !length(unlist(baseline$errors[[route]])), logical(1))),
    tightened_routes = isTRUE(tightened$certification$certified),
    tolerance_tightening = isTRUE(hvt1_pass(baseline$total - tightened$total, 1e-8) &&
      max(abs(as.matrix(baseline$per_unit) - as.matrix(tightened$per_unit))) <= 1e-9),
    transformed_tightened = isTRUE(max(abs(tightened$totals - tightened$total)) <= 1e-8),
    sum_units = all(vapply(names(baseline$totals), function(route) {
      values <- baseline$per_unit[[route]]
      hvt1_pass(sum(values) - baseline$totals[[route]], 1e-10) &&
        hvt1_pass(sum(rev(values)) - baseline$totals[[route]], 1e-10)
    }, logical(1)))
  )
  status <- if (all(unlist(checks))) "TRUTH_CERTIFIED_ADAPTIVE" else if (!checks$zero_loading || !checks$effective_q1 || !checks$stable_GH || !checks$sum_units || !checks$baseline_routes || !checks$forward_reverse_agreement) "ORACLE_NOT_CERTIFIED" else "TRUTH_UNINTERPRETABLE_ADAPTIVE"
  failed_checks <- names(checks)[!unlist(checks)]
  failure_detail <- if (length(tightened$errors$reverse)) paste0("tightened reverse route errors: ", paste(unlist(tightened$errors$reverse), collapse = " | ")) else NULL
  list(schema_version = "HVT1-1", observed_band = as.numeric(band), fixture = fixture, fixed = fixed,
       controls = list(baseline = oracle_control, tightened = tight_control), checks = checks,
       diagnostics = list(zero_diff = zero_diff, q1_diff = q1_diff, stable_GH_diff = stable_diff,
                          forward_reverse_diff = baseline$totals[["forward"]] - baseline$totals[["reverse"]],
                          baseline_tightened_diff = baseline$total - tightened$total),
       anchors = list(zero_oracle = zero_oracle, zero_analytic = zero_analytic,
                      q1_oracle = q1_oracle, q1_reference = q1_reference),
       baseline = baseline, tightened = tightened, status = status,
       status_reason = if (identical(status, "TRUTH_CERTIFIED_ADAPTIVE")) "All frozen certification checks passed." else paste(c(paste0("Failed checks: ", paste(failed_checks, collapse = ", ")), failure_detail), collapse = "; "),
       stop_triggered = identical(status, "ORACLE_NOT_CERTIFIED"),
       elbo_H61 = if (identical(status, "TRUTH_CERTIFIED_ADAPTIVE")) fixed$fixed_elbo else NA_real_,
       elbo_minus_truth = if (identical(status, "TRUTH_CERTIFIED_ADAPTIVE")) fixed$fixed_elbo - baseline$total else NA_real_)
}

hvt1_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  root <- hvt1_root(); source(file.path(root, "dev", "va-variance-gate", "high-variance-oracle.R"))
  option <- function(prefix, default) {
    hit <- args[startsWith(args, prefix)]
    if (!length(hit)) default else sub(paste0("^", prefix), "", hit[[1L]])
  }
  out <- option("--out=", file.path("/private/tmp", "gllvmtmb-hvt1-results-20260726"))
  bands_arg <- option("--observed-bands=", "4,20")
  bands <- strsplit(bands_arg, ",", fixed = TRUE)[[1L]]
  campaign_path <- Sys.getenv("HVT1_CAMPAIGN_RDS", "/private/tmp/gllvmtmb-va-variance-gate-campaign-20260726/campaign.rds")
  lock <- hvt1_lock(root, campaign_path)
  dir.create(out, recursive = TRUE, showWarnings = FALSE); saveRDS(lock, file.path(out, "source-lock.rds"))
  if (!isTRUE(lock$pass)) {
    saveRDS(list(lock = lock, status = "ORACLE_NOT_CERTIFIED", reason = "Frozen source lock failed."), file.path(out, "hvt1-result.rds"))
    hvt1_abort("ORACLE_NOT_CERTIFIED: frozen source lock failed.")
  }
  campaign <- readRDS(campaign_path)
  cells <- c("4", "6", "10", "20")
  if (!all(bands %in% cells)) hvt1_abort("Use frozen observed bands: 4,6,10,20.")
  baseline_control <- list(rel.tol = 1e-10, abs.tol = 1e-10, subdivisions = 1000L, tail_bound = 12, agreement_tol = 1e-8)
  results <- list(); stopped <- FALSE
  for (band in bands) {
    if (stopped) { results[[band]] <- list(status = "NOT_RUN", observed_band = as.numeric(band)); next }
    result <- tryCatch(hvt1_cell(band, campaign, baseline_control),
                       error = function(e) list(observed_band = as.numeric(band), status = "ORACLE_NOT_CERTIFIED", error = conditionMessage(e), elbo_H61 = NA_real_, elbo_minus_truth = NA_real_))
    results[[band]] <- result
    if (identical(result$status, "ORACLE_NOT_CERTIFIED")) stopped <- TRUE
  }
  summary <- data.frame(observed_band = vapply(results, `[[`, numeric(1), "observed_band"),
                        status = vapply(results, `[[`, character(1), "status"),
                        elbo_H61 = vapply(results, function(x) x$elbo_H61 %||% NA_real_, numeric(1)),
                        elbo_minus_truth = vapply(results, function(x) x$elbo_minus_truth %||% NA_real_, numeric(1)))
  answer <- if (all(summary$status == "TRUTH_CERTIFIED_ADAPTIVE")) "CERTIFIED_FIXED_CELL" else "ORACLE_NOT_CERTIFIED"
  packet <- list(schema_version = "HVT1-1", campaign_id = "hvt1-high-variance-truth-oracle-20260726",
                 created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), git_head = lock$git_head,
                 source_sha256 = c(lock$observed, campaign_rds = lock$campaign_rds_sha256,
                                   adaptive_oracle = lock$adaptive_oracle_sha256, adaptive_runner = lock$adaptive_runner_sha256), runtime = list(R = lock$R, TMB = lock$TMB, platform = lock$platform),
                 lock = lock, requested_bands = bands, results = results, summary = summary, final_decision = answer)
  saveRDS(packet, file.path(out, "hvt1-result.rds")); utils::write.csv(summary, file.path(out, "summary.csv"), row.names = FALSE)
  print(summary, row.names = FALSE); message("HVT-1 final decision: ", answer)
  invisible(packet)
}

if (sys.nframe() == 0L) hvt1_main()
