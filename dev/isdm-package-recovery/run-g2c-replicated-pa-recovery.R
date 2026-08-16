#!/usr/bin/env Rscript

## Developer-only G2c three-visit PA recovery harness.
## This file deliberately does not alter the one-visit G2 package evidence.

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
if (!mode %in% c("fixture", "smoke", "validate", "summarize")) {
  stop("mode must be fixture, smoke, validate, or summarize", call. = FALSE)
}
if (!scenario %in% c("ordinary", "disconnected", "weak_overlap")) {
  stop("unknown scenario", call. = FALSE)
}
if (is.na(replicate) || replicate < 1L ||
    (scenario == "ordinary" && replicate > 20L) ||
    (scenario != "ordinary" && replicate > 5L)) {
  stop("replicate is outside the frozen G2c panel", call. = FALSE)
}
if (is.null(root)) stop("--output=<result-root> is required", call. = FALSE)
root <- normalizePath(root, mustWork = FALSE)

suppressMessages(devtools::load_all(pkg, quiet = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
runner_file <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
protocol_file <- file.path(dirname(runner_file), "2026-08-10-g2c-replicated-pa-protocol.md")
decision_file <- file.path(dirname(runner_file), "2026-08-10-g2c-replicated-pa-decision.md")
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
  alpha = c(sp1 = -1.40, sp2 = -1.20, sp3 = -1.55),
  beta = c(sp1 = -0.55, sp2 = 0.35, sp3 = 0.70),
  lambda = c(sp1 = 0.70, sp2 = -0.55, sp3 = 0.45),
  psi_sd = c(sp1 = 0.35, sp2 = 0.30, sp3 = 0.40),
  gamma = c(sp1 = 0.45, sp2 = -0.35, sp3 = 0.25),
  gbif_contrast = c(sp1 = 0.30, sp2 = -0.20, sp3 = 0.15)
)
seed_for <- function(scenario, replicate) {
  if (scenario == "ordinary") return(as.integer(81100L + replicate))
  as.integer(81100L + replicate) # attacks deliberately reuse ordinary primitives 1:5
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
    b <- as.numeric(scale(.9 * x + sqrt(1 - .9^2) * stats::rnorm(n_cell)))
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
  if (any(!is.na(one$B[one$rows$source == "survey", , drop = FALSE])) || any(!is.na(three$B[three$rows$source == "survey", , drop = FALSE]))) stop("survey B gate drift")
  if (!identical(one$rows, three$rows[match(seq_len(nrow(one$rows)), seq_len(nrow(one$rows))), , drop = FALSE])) {
    ## rows_three is built as GBIF, visit1, visit2, visit3; one_visit must be the matching subset.
    key <- paste(three$rows$source, three$rows$cell_id, three$rows$trait, three$rows$survey_event_id)
    key_one <- paste(one$rows$source, one$rows$cell_id, one$rows$trait, one$rows$survey_event_id)
    if (!identical(one$rows, three$rows[match(key_one, key), , drop = FALSE])) stop("GBIF/first-visit identity drift")
  }
  keep <- three$rows$source == "survey"
  n_events <- table(three$rows$cell_id[keep], three$rows$trait[keep])
  if (!all(n_events == 3L) || anyDuplicated(three$rows[keep, c("cell_id", "trait", "survey_event_id")])) stop("three-event contract drift")
  if (any(three$rows$source == "survey" & three$rows$branch != "pa") || any(three$rows$source == "gbif" & three$rows$branch != "count")) stop("source branch drift")
  if (!identical(fx$truth$scenario, "ordinary") && identical(fx$truth$scenario, "disconnected") && length(intersect(fx$truth$gbif_cells, fx$truth$survey_cells))) stop("disconnected support overlap")
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
profile_theta_diag <- function(fit) {
  ## theta_diag_B is the package's log-SD coordinate; this is the protocol's log_psi ledger.
  base <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
  if (length(base) != 3L) stop("expected exactly three theta_diag_B coordinates")
  lapply(seq_along(base), function(k) {
    grid <- base[[k]] + c(-2, -1, 0, 1, 2)
    rows <- lapply(grid, function(value) {
      pars <- fit$tmb_obj$env$parList(fit$opt$par); pars$theta_diag_B[[k]] <- value
      map <- fit$tmb_map; selector <- factor(seq_along(pars$theta_diag_B)); selector[[k]] <- NA; map$theta_diag_B <- selector
      obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = pars, map = map, random = fit$random,
        DLL = fit$tmb_obj$env$DLL, silent = TRUE)
      opt <- tryCatch(stats::nlminb(obj$par, obj$fn, obj$gr), error = function(e) e)
      if (inherits(opt, "error")) return(data.frame(coordinate = k, offset = value - base[[k]], value = value, nll = NA_real_, convergence = NA_integer_, message = conditionMessage(opt)))
      data.frame(coordinate = k, offset = value - base[[k]], value = value, nll = obj$fn(opt$par), convergence = opt$convergence, message = opt$message %||% "")
    })
    tab <- do.call(rbind, rows); centre <- tab$nll[tab$offset == 0]
    tab$delta_nll <- tab$nll - centre
    tab
  })
}
profile_pass <- function(profiles) {
  if (length(profiles) != 3L || any(vapply(profiles, function(x) nrow(x) != 5L, logical(1)))) return(FALSE)
  all(vapply(profiles, function(x) all(is.finite(x$nll)) && all(x$convergence == 0L) &&
    all(x$delta_nll[x$offset %in% c(-2, 2)] >= 2), logical(1)))
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
  rh <- fit$restart_history; gradient <- fit$tmb_obj$gr(fit$opt$par)
  list(eligible = is.data.frame(rh) && nrow(rh) == 3L && sum(rh$selected) == 1L &&
    isTRUE(fit$opt$convergence == 0L) && isTRUE(fit$sd_report$pdHess) && all(is.finite(gradient)) && max(abs(gradient)) <= 1e-3 && profile_pass(profiles),
    max_abs_gradient = if (all(is.finite(gradient))) max(abs(gradient)) else NA_real_)
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
  fx <- make_fixture(seed, scenario); validate_paired_fixture(fx)
  one <- run_arm(fx$one_visit, fx$truth, seed, profile = profile)
  three <- run_arm(fx$three_visit, fx$truth, seed, profile = profile)
  list(fixture = fx, one_visit = one, three_visit = three,
       paired_identity = list(gbif_and_first_visit_identical = TRUE, added_events = 2L, shared_cell_latent = TRUE, survey_bias_structural_zero = TRUE))
}
manifest <- function(seed, scenario, replicate) list(seed = seed, scenario = scenario, replicate = replicate, package_commit = assert_campaign_sha(),
  runner_md5 = hash_file(runner_file), protocol_md5 = hash_file(protocol_file), decision_md5 = hash_file(decision_file), r_version = R.version.string,
  tmb_version = as.character(utils::packageVersion("TMB")), platform = R.version$platform, completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
write_fixture <- function(out, result, seed, scenario, replicate) {
  final <- file.path(root, c("summary.rds", "receipt.md", "smoke-receipt.md", "file-manifest.csv")); if (any(file.exists(final)) || file.exists(out)) stop("immutable result root already contains final or fixture output", call. = FALSE)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE); result$manifest <- manifest(seed, scenario, replicate); saveRDS(result, out)
}
expected_grid <- function() rbind(data.frame(scenario = "ordinary", replicate = 1:20, seed = 81101:81120), data.frame(scenario = "disconnected", replicate = 1:5, seed = 81101:81105), data.frame(scenario = "weak_overlap", replicate = 1:5, seed = 81101:81105))
summarize_root <- function() {
  final <- file.path(root, c("summary.rds", "receipt.md", "file-manifest.csv")); if (any(file.exists(final))) stop("immutable root already summarised", call. = FALSE)
  files <- sort(list.files(file.path(root, "fixtures"), pattern = "\\.rds$", full.names = TRUE)); grid <- expected_grid(); if (length(files) != nrow(grid)) stop("incomplete frozen G2c panel", call. = FALSE)
  rs <- lapply(files, readRDS); man <- do.call(rbind, lapply(rs, function(x) as.data.frame(x$manifest[1:3], stringsAsFactors = FALSE))); if (!identical(man[order(man$scenario, man$replicate), ], grid[order(grid$scenario, grid$replicate), ])) stop("fixture grid mismatch", call. = FALSE)
  prov <- lapply(rs, function(x) unlist(x$manifest[c("package_commit", "runner_md5", "protocol_md5", "decision_md5", "r_version", "tmb_version", "platform")])); if (length(unique(vapply(prov, paste, character(1), collapse = "|"))) != 1L) stop("mixed provenance", call. = FALSE)
  tab <- do.call(rbind, lapply(rs, function(x) data.frame(seed = x$manifest$seed, scenario = x$manifest$scenario, replicate = x$manifest$replicate, target_pass = isTRUE(x$three_visit$target_pass), eligible = isTRUE(x$three_visit$eligibility$eligible), stringsAsFactors = FALSE)))
  ordinary <- tab[tab$scenario == "ordinary", ]; attacks <- tab[tab$scenario != "ordinary", ]; pass <- sum(ordinary$target_pass) >= 18L && all(!attacks$target_pass)
  verdict <- if (pass) "G2C_REPLICATED_PA_PASS" else "G2C_REPLICATED_PA_HOLD"; saveRDS(list(verdict = verdict, rows = tab, ordinary_passes = sum(ordinary$target_pass), ordinary_required = 20L), file.path(root, "summary.rds"))
  retained <- c(files, file.path(root, "summary.rds")); utils::write.csv(data.frame(path = basename(retained), md5 = vapply(retained, hash_file, character(1))), file.path(root, "file-manifest.csv"), row.names = FALSE)
  writeLines(c(paste0("# ", verdict), "", sprintf("Ordinary three-visit target passes: %d / 20.", sum(ordinary$target_pass)), "This is private synthetic recovery evidence only."), file.path(root, "receipt.md"))
  cat(verdict, "\n")
}
validate_no_write <- function() {
  fx <- make_fixture(81101L, "ordinary"); validate_paired_fixture(fx)
  if (!identical(fx$one_visit$rows, fx$three_visit$rows[seq_len(nrow(fx$one_visit$rows)), , drop = FALSE])) stop("first-arm row order contract failed")
  if (any(!is.na(fx$three_visit$B[fx$three_visit$rows$source == "survey", 1]))) stop("B gate validation failed")
  cat("G2c fixture/event contract validation PASS (no fit)\n")
}
if (mode == "validate") {
  validate_no_write()
} else if (mode == "summarize") {
  summarize_root()
} else if (mode == "smoke") {
  if (scenario != "ordinary" || replicate != 1L) stop("the frozen local smoke is ordinary replicate 1", call. = FALSE)
  if (length(list.files(root, all.files = TRUE, no.. = TRUE))) stop("smoke root must be new and empty", call. = FALSE)
  out <- file.path(root, "fixtures", paste0(fixture_id(scenario, replicate), ".rds"))
  result <- run_fixture(seed_for(scenario, replicate), scenario, replicate, profile = TRUE)
  write_fixture(out, result, seed_for(scenario, replicate), scenario, replicate)
  ledger <- result$fixture$three_visit$rows[result$fixture$three_visit$rows$source == "survey", c("cell_id", "trait", "survey_event_id", "support", "value")]
  utils::write.csv(ledger, file.path(root, "event-ledger.csv"), row.names = FALSE)
  smoke_pass <- isTRUE(result$three_visit$eligibility$eligible) && isTRUE(result$paired_identity$gbif_and_first_visit_identical) && isTRUE(result$paired_identity$shared_cell_latent) && isTRUE(result$paired_identity$survey_bias_structural_zero)
  smoke_status <- if (smoke_pass) "SMOKE_PASS" else "SMOKE_HOLD"
  writeLines(c(paste0("# ", smoke_status), "", "G2c ordinary replicate 1; private, synthetic, developer-only.",
    paste0("three_visit_status: ", result$three_visit$status),
    paste0("three_visit_max_abs_gradient: ", format(result$three_visit$eligibility$max_abs_gradient %||% NA_real_, scientific = TRUE)),
    "This smoke is structural/numerical admission evidence, not a recovery verdict."), file.path(root, "smoke-receipt.md"))
  cat(smoke_status, "\n")
} else {
  out <- file.path(root, "fixtures", paste0(fixture_id(scenario, replicate), ".rds")); result <- run_fixture(seed_for(scenario, replicate), scenario, replicate, profile = TRUE); write_fixture(out, result, seed_for(scenario, replicate), scenario, replicate); cat("retained ", out, "\n", sep = "")
}
