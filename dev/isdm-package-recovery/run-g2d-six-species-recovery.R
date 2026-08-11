#!/usr/bin/env Rscript

## Developer-only G2d six-species three-visit PA recovery harness.
## This file deliberately does not alter G2c or one-visit G2 evidence.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- arg_value("mode", "fixture")
scenario <- arg_value("scenario", "ordinary")
replicate <- as.integer(arg_value("replicate", "1"))
root <- arg_value("output", NULL)
pkg <- normalizePath(arg_value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- arg_value("campaign-sha", NULL)
if (!mode %in% c("fixture", "smoke", "diagnostic", "validate", "init", "preflight", "summarize")) {
  stop("mode must be fixture, smoke, diagnostic, validate, init, preflight, or summarize", call. = FALSE)
}
if (!scenario %in% c("ordinary", "disconnected", "weak_overlap")) {
  stop("unknown scenario", call. = FALSE)
}
if (is.na(replicate) || replicate < 1L ||
    (scenario == "ordinary" && replicate > 20L) ||
    (scenario != "ordinary" && replicate > 5L)) {
  stop("replicate is outside the frozen G2d panel", call. = FALSE)
}
if (is.null(root)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(if (grepl("^/", root)) root else file.path(getwd(), root), mustWork = FALSE)

suppressMessages(devtools::load_all(pkg, quiet = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
protocol_file <- file.path(dirname(runner_file), "2026-08-10-g2d-six-species-protocol.md")
decision_file <- file.path(dirname(runner_file), "2026-08-10-g2d-six-species-decision.md")
package_commit <- function() {
  out <- suppressWarnings(system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))
  if (length(out) != 1L || !grepl("^[0-9a-f]{40}$", out)) stop("cannot resolve package HEAD", call. = FALSE)
  out
}
assert_campaign_sha <- function() {
  if (is.null(campaign_sha) || !grepl("^[0-9a-f]{40}$", campaign_sha)) {
    stop("--campaign-sha=<40-hex package commit> is required", call. = FALSE)
  }
  if (!identical(campaign_sha, package_commit())) stop("campaign SHA does not match --pkg HEAD", call. = FALSE)
  invisible(campaign_sha)
}

truth_constants <- list(
  alpha = c(sp1 = -1.40, sp2 = -1.20, sp3 = -1.55, sp4 = -1.35, sp5 = -1.60, sp6 = -1.10),
  beta = c(sp1 = -0.55, sp2 = 0.35, sp3 = 0.70, sp4 = -0.40, sp5 = 0.55, sp6 = 0.20),
  lambda = c(sp1 = 0.70, sp2 = -0.55, sp3 = 0.45, sp4 = 0.60, sp5 = -0.40, sp6 = 0.50),
  psi_sd = c(sp1 = 0.35, sp2 = 0.30, sp3 = 0.40, sp4 = 0.32, sp5 = 0.38, sp6 = 0.34),
  gamma = c(sp1 = 0.45, sp2 = -0.35, sp3 = 0.25, sp4 = -0.40, sp5 = 0.30, sp6 = 0.20),
  gbif_contrast = c(sp1 = 0.30, sp2 = -0.20, sp3 = 0.15, sp4 = -0.25, sp5 = 0.20, sp6 = -0.10)
)
profile_coordinate_names <- paste0("theta_diag_B_sp", 1:6)
seed_for <- function(scenario, replicate) {
  if (scenario == "ordinary") return(as.integer(86100L + replicate))
  as.integer(86100L + replicate) # attacks deliberately reuse ordinary primitives 1:5
}
fixture_id <- function(scenario, replicate) sprintf("%s-replicate-%02d", scenario, replicate)

make_fixture <- function(seed, scenario, n_cell = 120L) {
  set.seed(seed)
  tr <- truth_constants; species <- names(tr$alpha); cells <- paste0("cell_", seq_len(n_cell))
  x <- seq(-1, 1, length.out = n_cell)
  b <- as.numeric(scale(stats::rnorm(n_cell)))
  gbif_keep <- survey_keep <- rep(TRUE, n_cell)
  if (scenario == "disconnected") { survey_keep <- x <= 0; gbif_keep <- x > 0 }
  if (scenario == "weak_overlap") {
    x_std <- as.numeric(scale(x)); noise <- stats::rnorm(n_cell)
    noise <- stats::residuals(stats::lm(noise ~ x_std))
    b <- as.numeric(scale(.9 * x_std + sqrt(1 - .9^2) * as.numeric(scale(noise))))
    survey_keep <- abs(x) <= .25
  }
  z <- stats::rnorm(n_cell)
  eps <- sapply(tr$psi_sd, function(sd) stats::rnorm(n_cell, sd = sd))
  eta <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") + outer(z, tr$lambda) + eps
  a_g <- exp(seq(log(.8), log(2), length.out = n_cell)); a_s <- exp(seq(log(.6), log(1.4), length.out = n_cell))
  grid <- expand.grid(cell_id = cells, trait = species, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  idx <- match(paste(grid$cell_id, grid$trait), paste(rep(cells, times = length(species)), rep(species, each = n_cell)))
  eta_vec <- as.vector(eta); x_vec <- rep(x, times = length(species)); b_vec <- rep(b, times = length(species))
  g_support <- rep(a_g, times = length(species)); s_support <- rep(a_s, times = length(species))
  gbif <- transform(grid, source = "gbif", survey_event_id = NA_character_, branch = "count", support = g_support,
                    value = stats::rpois(nrow(grid), g_support * exp(eta_vec + rep(tr$gbif_contrast, each = n_cell) + b_vec * rep(tr$gamma, each = n_cell))))
  gbif$visit <- NA_integer_
  gbif <- gbif[gbif$cell_id %in% cells[gbif_keep], , drop = FALSE]
  pa <- lapply(1:3, function(event) transform(grid, source = "survey",
    survey_event_id = paste0("survey_v", event, "_", cell_id), branch = "pa", support = s_support,
    value = stats::rbinom(nrow(grid), 1L, 1 - exp(-s_support * exp(eta_vec))), visit = event))
  pa <- lapply(pa, function(x) x[x$cell_id %in% cells[survey_keep], , drop = FALSE])
  rows_three <- do.call(rbind, c(list(gbif), pa)); rows_one <- rbind(gbif, pa[[1L]])
  make_XB <- function(rows) {
    ix <- match(paste(rows$cell_id, rows$trait), paste(grid$cell_id, grid$trait))
    list(X = matrix(x_vec[ix], ncol = 1L, dimnames = list(NULL, "env")),
         B = matrix(ifelse(rows$source == "gbif", b_vec[ix], NA_real_), ncol = 1L, dimnames = list(NULL, "bias")))
  }
  a <- make_XB(rows_one); bmat <- make_XB(rows_three)
  list(one_visit = list(rows = rows_one, X = a$X, B = a$B),
       three_visit = list(rows = rows_three, X = bmat$X, B = bmat$B),
       truth = list(seed = seed, scenario = scenario, eta = eta, x = x, b = b, z = z, eps = eps,
         support_g = a_g, support_s = a_s, shared_Sigma = tcrossprod(tr$lambda),
         psi_variance = tr$psi_sd^2, constants = tr, survey_cells = cells[survey_keep], gbif_cells = cells[gbif_keep]))
}

validate_paired_fixture <- function(fx) {
  one <- fx$one_visit; three <- fx$three_visit
  ## Exact GBIF/visit-1 pairing is the ordinary-fixture invariant. The
  ## disconnected attack deliberately breaks spatial support overlap.
  if (.isdm_requires_exact_first_visit_pairing(fx$truth$scenario)) {
    .isdm_assert_gbif_first_visit_pairs(three$rows, three$rows$visit)
  }
  same_rows <- function(left, right) { row.names(left) <- row.names(right) <- NULL; identical(left, right) }
  species <- names(fx$truth$constants$alpha)
  if (length(species) != 6L || !identical(species, paste0("sp", 1:6))) stop("six-species truth contract drift")
  if (!identical(dim(fx$truth$shared_Sigma), c(6L, 6L)) || length(fx$truth$psi_variance) != 6L) stop("six-species covariance contract drift")
  if (ncol(one$X) != 1L || ncol(one$B) != 1L || nrow(one$X) != nrow(one$rows) || nrow(one$B) != nrow(one$rows)) stop("one-visit design contract drift")
  if (ncol(three$X) != 1L || ncol(three$B) != 1L || nrow(three$X) != nrow(three$rows) || nrow(three$B) != nrow(three$rows)) stop("three-visit design contract drift")
  if (any(!is.finite(one$B[one$rows$source == "gbif", , drop = FALSE])) || any(!is.finite(three$B[three$rows$source == "gbif", , drop = FALSE]))) stop("GBIF B gate drift")
  if (any(!is.na(one$B[one$rows$source == "survey", , drop = FALSE])) || any(!is.na(three$B[three$rows$source == "survey", , drop = FALSE]))) stop("survey B gate drift")
  if (!same_rows(one$rows, three$rows[seq_len(nrow(one$rows)), , drop = FALSE])) {
    ## rows_three is built as GBIF, visit1, visit2, visit3; one_visit must be the matching subset.
    key <- paste(three$rows$source, three$rows$cell_id, three$rows$trait, three$rows$survey_event_id)
    key_one <- paste(one$rows$source, one$rows$cell_id, one$rows$trait, one$rows$survey_event_id)
    if (!same_rows(one$rows, three$rows[match(key_one, key), , drop = FALSE])) stop("GBIF/first-visit identity drift")
  }
  if (!identical(one$X, three$X[seq_len(nrow(one$X)), , drop = FALSE]) || !identical(one$B, three$B[seq_len(nrow(one$B)), , drop = FALSE])) stop("GBIF/first-visit design identity drift")
  keep <- three$rows$source == "survey"
  n_events <- table(three$rows$cell_id[keep], three$rows$trait[keep])
  if (!all(n_events == 3L) || anyDuplicated(three$rows[keep, c("cell_id", "trait", "survey_event_id")])) stop("three-event contract drift")
  if (any(three$rows$source == "survey" & three$rows$branch != "pa") || any(three$rows$source == "gbif" & three$rows$branch != "count")) stop("source branch drift")
  if (!identical(fx$truth$scenario, "ordinary") && identical(fx$truth$scenario, "disconnected") && length(intersect(fx$truth$gbif_cells, fx$truth$survey_cells))) stop("disconnected support overlap")
  if (identical(fx$truth$scenario, "weak_overlap")) {
    overlap <- length(intersect(fx$truth$gbif_cells, fx$truth$survey_cells)) / length(fx$truth$gbif_cells)
    if (!isTRUE(all.equal(overlap, .25, tolerance = 0))) stop("weak-overlap support fraction drift")
    if (!is.finite(stats::cor(fx$truth$x, fx$truth$b)) || abs(stats::cor(fx$truth$x, fx$truth$b)) < .85) stop("weak-overlap x/b alignment drift")
  }
  invisible(TRUE)
}

fit_one <- function(dat, seed) {
  warnings <- character(); set.seed(seed + 100000L); started <- Sys.time()
  ans <- tryCatch(withCallingHandlers(.gll_isdm_fit(dat$rows, dat$X, dat$B, d = 1L,
    control = gllvmTMBcontrol(n_init = 3L, init_jitter = .25, se = TRUE, aghq = FALSE, warn_runaway = TRUE), silent = TRUE),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(e) structure(list(message = conditionMessage(e)), class = "isdm_fit_error"))
  list(value = ans, warnings = unique(warnings), elapsed_s = as.numeric(Sys.time() - started, units = "secs"))
}
fit_diagnostic <- function(dat, seed) {
  ## This is intentionally one optimisation only.  It proves the assembled
  ## TMB-map/extractor route, not convergence robustness or recovery.
  warnings <- character(); set.seed(seed + 200000L); started <- Sys.time()
  ans <- tryCatch(withCallingHandlers(.gll_isdm_fit(
    dat$rows, dat$X, dat$B, d = 1L,
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, aghq = FALSE,
      warn_runaway = TRUE
    ),
    silent = TRUE
  ), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  }), error = function(e) structure(list(message = conditionMessage(e)), class = "isdm_fit_error"))
  list(value = ans, warnings = unique(warnings), elapsed_s = as.numeric(Sys.time() - started, units = "secs"))
}
map_is_six_free <- function(map, n = 6L) {
  if (is.null(map)) return(TRUE)
  length(map) == n && !anyNA(map) && !anyDuplicated(as.integer(map)) &&
    identical(sort(as.integer(map)), seq_len(n))
}
audit_diagnostic_fit <- function(fit) {
  pars <- fit$tmb_obj$env$parList(fit$opt$par)
  theta_rr <- pars$theta_rr_B
  theta_diag <- pars$theta_diag_B
  lambda <- fit$report$Lambda_B
  sd <- as.numeric(fit$report$sd_B)
  shared <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "shared", link_residual = "none"
  ))$Sigma
  unique <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "unique", link_residual = "none"
  ))$s
  total <- suppressMessages(extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "none"
  ))$Sigma
  expected_shared <- tcrossprod(lambda)
  expected_total <- expected_shared + diag(sd^2, nrow(lambda))
  map_rr <- fit$tmb_map[["theta_rr_B", exact = TRUE]]
  map_diag <- fit$tmb_map[["theta_diag_B", exact = TRUE]]
  checks <- c(
    theta_rr_length = length(theta_rr) == 6L,
    theta_diag_length = length(theta_diag) == 6L,
    theta_diag_finite = all(is.finite(theta_diag)),
    rank_one_lambda = identical(dim(lambda), c(6L, 1L)) && all(is.finite(lambda)),
    theta_rr_matches_report = isTRUE(all.equal(
      .gllvmTMB_pack_rr_theta(lambda), as.numeric(theta_rr), tolerance = 1e-8
    )),
    six_free_rr_map = map_is_six_free(map_rr),
    six_free_diag_map = map_is_six_free(map_diag),
    positive_six_psi_sd = length(sd) == 6L && all(is.finite(sd)) && all(sd > 0),
    shared_extractor_identity = isTRUE(all.equal(shared, expected_shared, tolerance = 1e-8)),
    unique_extractor_identity = isTRUE(all.equal(as.numeric(unique), sd^2, tolerance = 1e-8)),
    total_extractor_identity = isTRUE(all.equal(total, expected_total, tolerance = 1e-8))
  )
  list(pass = all(checks), checks = checks, theta_rr_B = theta_rr,
       theta_diag_B = theta_diag, Lambda_B = lambda, sd_B = sd,
       shared = shared, unique = unique, total = total,
       map_theta_rr_B = map_rr, map_theta_diag_B = map_diag)
}
profile_theta_diag <- function(fit) {
  ## theta_diag_B is the package's log-SD coordinate; this is the protocol's log_psi ledger.
  base <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
  species <- paste0("sp", 1:6)
  offsets <- c(-2, -1, 0, 1, 2)
  if (length(base) != length(species)) stop("expected exactly six theta_diag_B coordinates")
  original_map <- fit$tmb_map[["theta_diag_B", exact = TRUE]]
  if (!is.null(original_map) && (length(original_map) != length(base) || anyNA(original_map) || anyDuplicated(as.integer(original_map)))) stop("theta_diag_B coordinates are tied or skipped")
  out <- lapply(seq_along(base), function(k) {
    grid <- base[[k]] + offsets
    rows <- lapply(grid, function(value) {
      pars <- fit$tmb_obj$env$parList(fit$opt$par); pars$theta_diag_B[[k]] <- value
      map <- fit$tmb_map; selector <- factor(seq_along(pars$theta_diag_B)); selector[[k]] <- NA; map$theta_diag_B <- selector
      obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = pars, map = map, random = fit$random,
        DLL = fit$tmb_obj$env$DLL, silent = TRUE)
      opt <- tryCatch(stats::nlminb(obj$par, obj$fn, obj$gr), error = function(e) e)
      if (inherits(opt, "error")) return(data.frame(coordinate = k, species = species[[k]], offset = value - base[[k]], value = value, nll = NA_real_, convergence = NA_integer_, message = conditionMessage(opt), stringsAsFactors = FALSE))
      data.frame(coordinate = k, species = species[[k]], offset = value - base[[k]], value = value, nll = obj$fn(opt$par), convergence = opt$convergence, message = opt$message %||% "", stringsAsFactors = FALSE)
    })
    tab <- do.call(rbind, rows); centre <- tab$nll[which.min(abs(tab$offset))]
    tab$delta_nll <- tab$nll - centre
    ok <- nrow(tab) == 5L && isTRUE(all.equal(tab$offset, offsets, tolerance = 1e-10)) && all(is.finite(tab$nll)) && all(tab$convergence == 0L) && isTRUE(all.equal(tab$delta_nll[which.min(abs(tab$offset))], 0, tolerance = 1e-8)) && all(tab$delta_nll[c(1L, 5L)] >= 2)
    tab$verdict <- if (ok) paste0("G2D_PROFILE_THETA_DIAG_B_", toupper(species[[k]]), "_PASS") else paste0("G2D_PROFILE_THETA_DIAG_B_", toupper(species[[k]]), "_HOLD")
    tab
  })
  names(out) <- species
  out
}
profile_pass <- function(profiles) {
  if (!identical(names(profiles), paste0("sp", 1:6)) || any(vapply(profiles, function(x) nrow(x) != 5L, logical(1)))) return(FALSE)
  all(vapply(profiles, function(x) identical(unique(x$verdict), paste0("G2D_PROFILE_THETA_DIAG_B_", toupper(x$species[[1L]]), "_PASS")), logical(1)))
}
coefficient_by_trait <- function(fit, fragment, species) {
  b <- .gllvmTMB_b_fix_values(fit); nm <- fit$X_fix_names
  out <- stats::setNames(rep(NA_real_, length(species)), species)
  for (sp in species) { hit <- grep(paste0("trait", sp, ".*", fragment), nm); if (length(hit) == 1L) out[[sp]] <- b[[hit]] }
  out
}
metrics_from_fit <- function(fit, dat, truth) {
  tr <- truth$constants; species <- names(tr$alpha)
  beta_hat <- coefficient_by_trait(fit, "isdm_x_env", species); gamma_hat <- coefficient_by_trait(fit, "isdm_gbif_b_bias", species)
  shared <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared", link_residual = "none"))$Sigma
  unique <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none"))$s
  eta_hat <- as.numeric(fit$report$eta) - log(dat$rows$support); survey <- dat$rows$source == "survey"
  map_cor <- vapply(species, function(sp) { ii <- survey & dat$rows$trait == sp; cells <- as.integer(sub("cell_", "", dat$rows$cell_id[ii])); stats::cor(eta_hat[ii] - mean(eta_hat[ii]), truth$eta[cells, sp] - mean(truth$eta[cells, sp])) }, numeric(1))
  list(max_abs_beta_error = max(abs(beta_hat - tr$beta)), max_abs_gamma_error = max(abs(gamma_hat - tr$gamma)), min_map_correlation = min(map_cor),
       shared_relative_frobenius = norm(shared - truth$shared_Sigma, "F") / norm(truth$shared_Sigma, "F"), max_abs_psi_variance_error = max(abs(unique - truth$psi_variance)),
       beta_hat = beta_hat, gamma_hat = gamma_hat, map_correlation = map_cor, shared_Sigma_hat = shared, psi_variance_hat = unique)
}
eligible_fit <- function(fit, profiles) {
  rh <- fit$restart_history; gradient <- fit$tmb_obj$gr(fit$opt$par); objective <- fit$tmb_obj$fn(fit$opt$par)
  list(eligible = is.data.frame(rh) && nrow(rh) == 3L && sum(rh$selected) == 1L &&
    is.finite(objective) && isTRUE(fit$opt$convergence == 0L) && isTRUE(fit$sd_report$pdHess) && all(is.finite(gradient)) && max(abs(gradient)) <= 1e-3 && profile_pass(profiles),
    objective = objective, max_abs_gradient = if (all(is.finite(gradient))) max(abs(gradient)) else NA_real_)
}
run_arm <- function(dat, truth, seed, profile = TRUE) {
  fit_res <- fit_one(dat, seed)
  if (inherits(fit_res$value, "isdm_fit_error")) return(list(status = "fit_error", detail = fit_res$value$message, warnings = fit_res$warnings, elapsed_s = fit_res$elapsed_s))
  fit <- fit_res$value; profiles <- if (profile) tryCatch(profile_theta_diag(fit), error = function(e) structure(list(message = conditionMessage(e)), class = "profile_error")) else list()
  if (inherits(profiles, "profile_error")) return(list(status = "profile_error", detail = profiles$message, fit = fit, warnings = fit_res$warnings, elapsed_s = fit_res$elapsed_s))
  eligibility <- eligible_fit(fit, profiles); metric <- tryCatch(metrics_from_fit(fit, dat, truth), error = function(e) structure(list(message = conditionMessage(e)), class = "metric_error"))
  if (inherits(metric, "metric_error")) return(list(status = "metric_error", detail = metric$message, fit = fit, profiles = profiles, eligibility = eligibility, warnings = fit_res$warnings, elapsed_s = fit_res$elapsed_s))
  targets <- all(is.finite(unlist(metric[c("max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation", "shared_relative_frobenius", "max_abs_psi_variance_error")], use.names = FALSE))) &&
    metric$max_abs_beta_error <= .30 && metric$max_abs_gamma_error <= .30 && metric$min_map_correlation >= .70 && metric$shared_relative_frobenius <= .50 && metric$max_abs_psi_variance_error <= .20
  list(status = if (eligibility$eligible) "eligible" else "ineligible", fit = fit, profiles = profiles, eligibility = eligibility, metrics = metric,
       target_pass = isTRUE(eligibility$eligible) && targets, warnings = fit_res$warnings, elapsed_s = fit_res$elapsed_s)
}
run_fixture <- function(seed, scenario, replicate, profile = TRUE) {
  assert_campaign_sha()
  ensure_result_root()
  require_root_receipt()
  fx <- make_fixture(seed, scenario); validate_paired_fixture(fx)
  one <- run_arm(fx$one_visit, fx$truth, seed, profile = profile)
  three <- run_arm(fx$three_visit, fx$truth, seed, profile = profile)
  list(fixture = fx, one_visit = one, three_visit = three,
       paired_identity = list(gbif_and_first_visit_identical = TRUE, added_events = 2L, shared_cell_latent = TRUE, survey_bias_structural_zero = TRUE))
}
manifest <- function(seed, scenario, replicate) list(seed = seed, scenario = scenario, replicate = replicate, package_commit = assert_campaign_sha(),
  runner_md5 = hash_file(runner_file), protocol_md5 = hash_file(protocol_file), decision_md5 = hash_file(decision_file), r_version = R.version.string,
  tmb_version = as.character(utils::packageVersion("TMB")), platform = R.version$platform, completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
ensure_result_root <- function() {
  allowed_parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
  if (!startsWith(normalizePath(root, mustWork = FALSE), paste0(allowed_parent, "/")) || grepl("g2c", basename(root), ignore.case = TRUE)) stop("G2d roots must be fresh non-G2c children of the private results directory", call. = FALSE)
  final <- file.path(root, c("summary.rds", "receipt.md", "smoke-receipt.md", "file-manifest.csv"))
  if (any(file.exists(final))) stop("immutable result root already contains final output", call. = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  invisible(root)
}
write_root_receipt <- function(purpose) {
  ensure_result_root()
  receipt_rds <- file.path(root, "root-receipt.rds")
  receipt_md <- file.path(root, "root-receipt.md")
  if (file.exists(receipt_rds) || file.exists(receipt_md)) stop("immutable root receipt already exists", call. = FALSE)
  receipt <- list(
    purpose = purpose,
    package_commit = assert_campaign_sha(),
    runner_md5 = hash_file(runner_file),
    protocol_md5 = hash_file(protocol_file),
    decision_md5 = hash_file(decision_file),
    seed_grid = expected_grid(),
    r_version = R.version.string,
    tmb_version = as.character(utils::packageVersion("TMB")),
    platform = R.version$platform,
    created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  saveRDS(receipt, receipt_rds)
  if (!identical(readRDS(receipt_rds), receipt)) stop("root receipt serialization check failed", call. = FALSE)
  writeLines(c("# G2D root receipt", "", paste0("purpose: ", purpose), paste0("package_commit: ", receipt$package_commit),
    paste0("runner_md5: ", receipt$runner_md5), paste0("protocol_md5: ", receipt$protocol_md5),
    paste0("decision_md5: ", receipt$decision_md5), paste0("platform: ", receipt$platform)), receipt_md)
  receipt
}
require_root_receipt <- function() {
  receipt_file <- file.path(root, "root-receipt.rds")
  if (!file.exists(receipt_file) || file.info(receipt_file)$size <= 0L) stop("pre-fit root receipt is missing", call. = FALSE)
  receipt <- readRDS(receipt_file)
  if (!identical(receipt$package_commit, assert_campaign_sha()) || !identical(receipt$runner_md5, hash_file(runner_file)) || !identical(receipt$protocol_md5, hash_file(protocol_file)) || !identical(receipt$decision_md5, hash_file(decision_file))) stop("root receipt provenance drift", call. = FALSE)
  invisible(receipt)
}
initialize_campaign_root <- function() {
  ensure_result_root()
  if (length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("campaign root must be new and empty", call. = FALSE)
  write_root_receipt("campaign")
  writeLines(c("# G2D campaign root initialized", "", "No fit was run.", "This root is now bound to its frozen receipt before fixture jobs may start."), file.path(root, "root-init.md"))
  cat("G2D_ROOT_INIT_PASS (no fit)\n")
}
write_preflight <- function() {
  ensure_result_root()
  if (length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("preflight root must be new and empty", call. = FALSE)
  receipt <- write_root_receipt("no-fit-writable-root-serialization-preflight")
  probe <- list(kind = "G2D_PREFLIGHT_SENTINEL", receipt = receipt, written_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
  probe_file <- file.path(root, "preflight-sentinel.rds")
  saveRDS(probe, probe_file)
  if (!identical(readRDS(probe_file), probe)) stop("preflight sentinel serialization check failed", call. = FALSE)
  retained <- c(file.path(root, "root-receipt.rds"), file.path(root, "root-receipt.md"), probe_file)
  utils::write.csv(data.frame(path = basename(retained), md5 = vapply(retained, hash_file, character(1))), file.path(root, "preflight-file-manifest.csv"), row.names = FALSE)
  writeLines(c("# G2D_PREFLIGHT_PASS", "", "No fit was run.", "Fresh root creation, receipt serialization, sentinel read-back, and manifest hashing passed."), file.path(root, "preflight-receipt.md"))
  cat("G2D_PREFLIGHT_PASS (no fit)\n")
}
write_fixture <- function(out, result, seed, scenario, replicate) {
  ensure_result_root()
  final <- file.path(root, c("summary.rds", "receipt.md", "smoke-receipt.md", "file-manifest.csv")); if (any(file.exists(final)) || file.exists(out)) stop("immutable result root already contains final or fixture output", call. = FALSE)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE); result$manifest <- manifest(seed, scenario, replicate); saveRDS(result, out)
}
expected_grid <- function() rbind(data.frame(scenario = "ordinary", replicate = 1:20, seed = 86101:86120), data.frame(scenario = "disconnected", replicate = 1:5, seed = 86101:86105), data.frame(scenario = "weak_overlap", replicate = 1:5, seed = 86101:86105))
attack_degradation <- function(arm) {
  finite_metric <- is.list(arm$metrics) && all(is.finite(unlist(arm$metrics[c("max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation", "shared_relative_frobenius", "max_abs_psi_variance_error")], use.names = FALSE)))
  complete <- arm$status %in% c("eligible", "ineligible") && is.list(arm$eligibility) && is.finite(arm$eligibility$objective %||% NA_real_) && finite_metric && is.list(arm$profiles) && length(arm$profiles) == 6L
  if (!complete) return("G2D_ATTACK_HOLD_INCOMPLETE_OR_NONFINITE")
  if (isTRUE(arm$target_pass)) return("G2D_ATTACK_HOLD_NO_DEGRADATION")
  if (isTRUE(arm$eligibility$eligible)) return("G2D_ATTACK_TARGET_DEGRADATION")
  "G2D_ATTACK_ELIGIBILITY_DEGRADATION"
}
fixture_artifacts_complete <- function(result) {
  top_ok <- all(c("fixture", "one_visit", "three_visit", "paired_identity", "manifest") %in% names(result))
  truth_ok <- is.list(result$fixture) && is.list(result$fixture$truth) && all(c("constants", "eta", "shared_Sigma", "psi_variance", "survey_cells", "gbif_cells") %in% names(result$fixture$truth))
  arm_ok <- function(arm) {
    base_ok <- is.list(arm) && all(c("status", "warnings", "elapsed_s") %in% names(arm))
    if (!base_ok) return(FALSE)
    if (arm$status %in% c("fit_error", "profile_error", "metric_error")) return(is.character(arm$detail) && length(arm$detail) == 1L && nzchar(arm$detail))
    if (!arm$status %in% c("eligible", "ineligible")) return(FALSE)
    metric_names <- c("max_abs_beta_error", "max_abs_gamma_error", "min_map_correlation", "shared_relative_frobenius", "max_abs_psi_variance_error")
    is.list(arm$fit) && is.list(arm$profiles) && length(arm$profiles) == 6L && is.list(arm$eligibility) && is.finite(arm$eligibility$objective %||% NA_real_) && is.list(arm$metrics) && all(metric_names %in% names(arm$metrics)) && all(is.finite(unlist(arm$metrics[metric_names], use.names = FALSE)))
  }
  paired_ok <- is.list(result$paired_identity) && all(vapply(c("gbif_and_first_visit_identical", "shared_cell_latent", "survey_bias_structural_zero"), function(name) isTRUE(result$paired_identity[[name]]), logical(1))) && identical(result$paired_identity$added_events, 2L)
  manifest_ok <- is.list(result$manifest) && all(c("seed", "scenario", "replicate", "package_commit", "runner_md5", "protocol_md5", "decision_md5", "r_version", "tmb_version", "platform") %in% names(result$manifest))
  isTRUE(top_ok && truth_ok && arm_ok(result$one_visit) && arm_ok(result$three_visit) && paired_ok && manifest_ok)
}
summarize_root <- function() {
  assert_campaign_sha(); ensure_result_root(); require_root_receipt()
  final <- file.path(root, c("summary.rds", "receipt.md", "file-manifest.csv")); if (any(file.exists(final))) stop("immutable root already summarised", call. = FALSE)
  files <- sort(list.files(file.path(root, "fixtures"), pattern = "\\.rds$", full.names = TRUE)); grid <- expected_grid(); if (length(files) != nrow(grid)) stop("incomplete frozen G2d panel", call. = FALSE)
  rs <- lapply(files, readRDS); man <- do.call(rbind, lapply(rs, function(x) as.data.frame(x$manifest[1:3], stringsAsFactors = FALSE))); if (!identical(man[order(man$scenario, man$replicate), ], grid[order(grid$scenario, grid$replicate), ])) stop("fixture grid mismatch", call. = FALSE)
  prov <- lapply(rs, function(x) unlist(x$manifest[c("package_commit", "runner_md5", "protocol_md5", "decision_md5", "r_version", "tmb_version", "platform")])); if (length(unique(vapply(prov, paste, character(1), collapse = "|"))) != 1L) stop("mixed provenance", call. = FALSE)
  tab <- do.call(rbind, lapply(rs, function(x) data.frame(seed = x$manifest$seed, scenario = x$manifest$scenario, replicate = x$manifest$replicate, target_pass = isTRUE(x$three_visit$target_pass), eligible = isTRUE(x$three_visit$eligibility$eligible), attack_verdict = if (x$manifest$scenario == "ordinary") NA_character_ else attack_degradation(x$three_visit), stringsAsFactors = FALSE)))
  artifacts_complete <- all(vapply(rs, fixture_artifacts_complete, logical(1)))
  ordinary <- tab[tab$scenario == "ordinary", ]; attacks <- tab[tab$scenario != "ordinary", ]
  attacks_complete <- nrow(attacks) == 10L && all(attacks$attack_verdict %in% c("G2D_ATTACK_TARGET_DEGRADATION", "G2D_ATTACK_ELIGIBILITY_DEGRADATION"))
  pass <- artifacts_complete && sum(ordinary$target_pass) >= 18L && attacks_complete
  verdict <- if (pass) "G2D_SIX_SPECIES_PASS" else "G2D_SIX_SPECIES_HOLD"; saveRDS(list(verdict = verdict, rows = tab, ordinary_passes = sum(ordinary$target_pass), ordinary_required = 20L, attacks_complete = attacks_complete, artifacts_complete = artifacts_complete), file.path(root, "summary.rds"))
  retained <- c(files, file.path(root, "summary.rds")); utils::write.csv(data.frame(path = basename(retained), md5 = vapply(retained, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
  writeLines(c(paste0("# ", verdict), "", sprintf("Ordinary three-visit target passes: %d / 20.", sum(ordinary$target_pass)), "This is private synthetic recovery evidence only."), file.path(root, "receipt.md"))
  cat(verdict, "\n")
}
validate_no_write <- function() {
  fx <- make_fixture(86101L, "ordinary"); validate_paired_fixture(fx)
  validate_paired_fixture(make_fixture(86101L, "disconnected"))
  validate_paired_fixture(make_fixture(86101L, "weak_overlap"))
  one_rows <- fx$one_visit$rows; three_rows <- fx$three_visit$rows[seq_len(nrow(fx$one_visit$rows)), , drop = FALSE]; row.names(one_rows) <- row.names(three_rows) <- NULL
  if (!identical(one_rows, three_rows)) stop("first-arm row order contract failed")
  if (any(!is.na(fx$three_visit$B[fx$three_visit$rows$source == "survey", 1]))) stop("B gate validation failed")
  if (!identical(expected_grid()$seed, c(86101:86120, 86101:86105, 86101:86105))) stop("frozen seed-grid contract failed")
  cat("G2D fixture/support/profile contract validation PASS (no fit)\n")
}
if (mode == "validate") {
  validate_no_write()
} else if (mode == "preflight") {
  write_preflight()
} else if (mode == "init") {
  initialize_campaign_root()
} else if (mode == "summarize") {
  summarize_root()
} else if (mode == "diagnostic") {
  if (scenario != "ordinary" || replicate != 1L) {
    stop("the approved diagnostic is ordinary replicate 1", call. = FALSE)
  }
  ensure_result_root()
  if (length(list.files(root, all.files = TRUE, no.. = TRUE))) {
    stop("diagnostic root must be new and empty", call. = FALSE)
  }
  write_root_receipt("single-fit-tmb-map-extractor-diagnostic")
  fx <- make_fixture(seed_for(scenario, replicate), scenario)
  validate_paired_fixture(fx)
  fit_res <- fit_diagnostic(fx$three_visit, seed_for(scenario, replicate))
  audit <- if (inherits(fit_res$value, "isdm_fit_error")) {
    list(pass = FALSE, checks = c(fit_constructed = FALSE), detail = fit_res$value$message)
  } else {
    tryCatch(audit_diagnostic_fit(fit_res$value), error = function(e) {
      list(pass = FALSE, checks = c(audit_completed = FALSE), detail = conditionMessage(e))
    })
  }
  saveRDS(fx$truth, file.path(root, "truth.rds"))
  saveRDS(fit_res, file.path(root, "diagnostic-fit.rds"))
  saveRDS(audit, file.path(root, "diagnostic-map-sigma.rds"))
  verdict <- if (isTRUE(audit$pass)) "G2D_DIAGNOSTIC_MAP_PASS" else "G2D_DIAGNOSTIC_MAP_HOLD"
  writeLines(c(
    paste0("# ", verdict), "",
    "Exactly one ordinary three-visit fit was run with n_init = 1 and no profile.",
    "This verifies TMB-map/extractor assembly only; it is not a smoke, recovery result, or campaign admission.",
    paste0("elapsed_s: ", format(fit_res$elapsed_s, scientific = FALSE)),
    paste0("checks: ", paste(names(audit$checks)[audit$checks], collapse = ", ")),
    if (!is.null(audit$detail)) paste0("detail: ", audit$detail) else NULL
  ), file.path(root, "diagnostic-receipt.md"))
  retained <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE))
  retained <- retained[!grepl("file-manifest\\.csv$", retained)]
  utils::write.csv(data.frame(
    path = sub(paste0("^", root, "/"), "", retained),
    md5 = vapply(retained, hash_file, character(1))
  ), file.path(root, "file-manifest.csv"), row.names = FALSE)
  cat(verdict, "\n")
} else if (mode == "smoke") {
  if (scenario != "ordinary" || replicate != 1L) stop("the frozen local smoke is ordinary replicate 1", call. = FALSE)
  ensure_result_root()
  if (length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("smoke root must be new and empty", call. = FALSE)
  write_root_receipt("local-smoke")
  out <- file.path(root, "fixtures", paste0(fixture_id(scenario, replicate), ".rds"))
  result <- run_fixture(seed_for(scenario, replicate), scenario, replicate, profile = TRUE)
  write_fixture(out, result, seed_for(scenario, replicate), scenario, replicate)
  ledger <- result$fixture$three_visit$rows[result$fixture$three_visit$rows$source == "survey", c("cell_id", "trait", "survey_event_id", "support", "value")]
  utils::write.csv(ledger, file.path(root, "event-ledger.csv"), row.names = FALSE)
  saveRDS(result$fixture$truth, file.path(root, "truth.rds"))
  saveRDS(result$paired_identity, file.path(root, "paired-map.rds"))
  saveRDS(list(one_visit = result$one_visit$fit %||% NULL, three_visit = result$three_visit$fit %||% NULL), file.path(root, "fit-receipt.rds"))
  saveRDS(list(one_visit = result$one_visit$profiles %||% NULL, three_visit = result$three_visit$profiles %||% NULL), file.path(root, "profile-ledger.rds"))
  saveRDS(list(one_visit = result$one_visit$eligibility %||% NULL, three_visit = result$three_visit$eligibility %||% NULL), file.path(root, "restart-ledger.rds"))
  saveRDS(list(one_visit = result$one_visit$metrics %||% NULL, three_visit = result$three_visit$metrics %||% NULL), file.path(root, "metric-ledger.rds"))
  required <- file.path(root, c("root-receipt.rds", "root-receipt.md", "truth.rds", "paired-map.rds", "fit-receipt.rds", "profile-ledger.rds", "restart-ledger.rds", "metric-ledger.rds", "event-ledger.csv"))
  receipts_ready <- all(file.exists(required) & file.info(required)$size > 0L)
  smoke_pass <- receipts_ready && isTRUE(result$three_visit$eligibility$eligible) && isTRUE(result$paired_identity$gbif_and_first_visit_identical) && isTRUE(result$paired_identity$shared_cell_latent) && isTRUE(result$paired_identity$survey_bias_structural_zero)
  smoke_status <- if (smoke_pass) "G2D_SMOKE_PASS" else "G2D_SMOKE_HOLD"
  writeLines(c(paste0("# ", smoke_status), "", "G2d ordinary replicate 1; private, synthetic, developer-only.",
    paste0("three_visit_status: ", result$three_visit$status),
    paste0("three_visit_max_abs_gradient: ", format(result$three_visit$eligibility$max_abs_gradient %||% NA_real_, scientific = TRUE)),
    "This smoke is structural/numerical admission evidence, not a recovery verdict."), file.path(root, "smoke-receipt.md"))
  retained <- sort(list.files(root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE))
  retained <- retained[!grepl("file-manifest\\.csv$", retained)]
  utils::write.csv(data.frame(path = sub(paste0("^", root, "/"), "", retained), md5 = vapply(retained, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
  cat(smoke_status, "\n")
} else {
  out <- file.path(root, "fixtures", paste0(fixture_id(scenario, replicate), ".rds")); result <- run_fixture(seed_for(scenario, replicate), scenario, replicate, profile = TRUE); write_fixture(out, result, seed_for(scenario, replicate), scenario, replicate); cat("retained ", out, "\n", sep = "")
}
