#!/usr/bin/env Rscript

## Private LA-MSPL uncertainty-candidate pilot.  This script is deliberately
## outside the frozen lane-b B2 root: B2 is point-estimation evidence and must
## not be restarted or repurposed for interval calibration.

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x
arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}
command <- if (length(args)) args[[1L]] else ""
root <- arg_value("--root")
if (!nzchar(root %||% "")) stop("Use --root <outside-repository-campaign-root>.")
procedure <- arg_value("--procedure", "both")
if (!procedure %in% c("both", "hessian_only")) {
  stop("Use --procedure both or hessian_only.", call. = FALSE)
}

manifest <- function(n_rep = 100L) {
  out <- data.frame(
    cell_id = c("U001", "U002", "U003", "U004"),
    link = c("logit", "probit", "cloglog", "cloglog"),
    regime = c("baseline", "baseline", "baseline", "low_prevalence"),
    beta_shift = c(0, 0, 0, -1.5),
    n_rep = rep(as.integer(n_rep), 4L),
    stringsAsFactors = FALSE
  )
  out$manifest_version <- "lane-b-mspl-uncertainty-v2-2026-08-13"
  out$seed_base <- 1813000000L + seq_len(nrow(out)) * 10000L
  out
}

write_manifest <- function(root, n_rep, procedure, campaign_id, source_sha) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "raw"), showWarnings = FALSE)
  m <- manifest(n_rep)
  m$procedure <- procedure
  m$campaign_id <- campaign_id
  m$source_sha <- source_sha
  utils::write.csv(m, file.path(root, "manifest.csv"), row.names = FALSE)
  writeLines(c(
    "Private LA-MSPL uncertainty-candidate campaign.",
    paste("Procedure:", procedure, "(active penalised objective only)."),
    "No result is a calibrated SE or confidence interval; profile is not evaluated in hessian_only mode.",
    "Public MSPL inference stays fail-closed.",
    "Failures are retained and count as unavailable; do not substitute another procedure."
  ), file.path(root, "README.txt"))
  invisible(m)
}

simulate_data <- function(cell, replicate_id) {
  set.seed(cell$seed_base + as.integer(replicate_id))
  n_site <- 24L; n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%d", seq_len(n_trait)), n_site),
                  levels = sprintf("t%d", seq_len(n_trait)))
  z <- stats::rnorm(n_site)
  beta <- c(-0.5, 0.1, 0.55) + cell$beta_shift
  lambda <- c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * lambda[as.integer(trait)]
  mu <- switch(cell$link,
    logit = stats::plogis(eta), probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta))
  )
  list(data = data.frame(site = site, trait = trait,
                         y = stats::rbinom(length(mu), 1L, mu)), beta = beta)
}

run_one <- function(cell, replicate_id, procedure) {
  sim <- simulate_data(cell, replicate_id)
  fit <- tryCatch(gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, family = stats::binomial(cell$link), estimator = "mspl",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0,
                                         se = FALSE, warn_runaway = FALSE)
  ), error = identity)
  if (inherits(fit, "error")) return(data.frame(
    cell_id = cell$cell_id, replicate_id = replicate_id, target = seq_along(sim$beta),
    truth = sim$beta, estimate = NA_real_, fit_status = "fit_error",
    hessian_status = "not_run_fit_error", objective_source = NA_character_,
    hessian_method = NA_character_, hessian_rank = NA_integer_,
    minimum_eigenvalue = NA_real_, profile_lower_status = "not_run",
    profile_upper_status = "not_run", hessian_se = NA_real_,
    hessian_covers = FALSE, profile_covers = FALSE, procedure = procedure,
    campaign_id = cell$campaign_id, source_sha = cell$source_sha,
    message = conditionMessage(fit), stringsAsFactors = FALSE
  ))
  idx <- which(names(fit$opt$par) == "b_fix")
  do.call(rbind, lapply(seq_along(idx), function(j) {
    h <- tryCatch(
      gllvmTMB:::.gllvmTMB_mspl_penalized_hessian_diagnostic(fit, idx[[j]]),
      error = function(e) list(
        status = "hessian_call_error", estimate = fit$opt$par[idx[[j]]],
        se = NA_real_, diagnostic_lower = NA_real_, diagnostic_upper = NA_real_,
        objective_source = NA_character_, hessian_method = NA_character_,
        hessian_rank = NA_integer_, minimum_eigenvalue = NA_real_,
        message = conditionMessage(e)
      )
    )
    q <- if (identical(procedure, "both")) {
      p <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
        fit, idx[[j]], step = .5, max_steps = 12L,
        control = list(eval.max = 100L, iter.max = 100L)
      )
      gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(p)
    } else {
      list(lower_status = "not_run", upper_status = "not_run",
           diagnostic_lower = NA_real_, diagnostic_upper = NA_real_)
    }
    truth <- sim$beta[[j]]
    data.frame(
      cell_id = cell$cell_id, replicate_id = replicate_id, target = j,
      truth = truth, estimate = h$estimate, fit_status = "ok",
      hessian_status = h$status, objective_source = h$objective_source,
      hessian_method = h$hessian_method, hessian_rank = h$hessian_rank,
      minimum_eigenvalue = h$minimum_eigenvalue,
      profile_lower_status = q$lower_status,
      profile_upper_status = q$upper_status, hessian_se = h$se,
      hessian_covers = identical(h$status, "ok") &&
        truth >= h$diagnostic_lower && truth <= h$diagnostic_upper,
      profile_covers = identical(q$lower_status, "crossed") &&
        identical(q$upper_status, "crossed") && truth >= q$diagnostic_lower &&
        truth <= q$diagnostic_upper,
      procedure = procedure,
      campaign_id = cell$campaign_id, source_sha = cell$source_sha,
      message = h$message %||% NA_character_, stringsAsFactors = FALSE
    )
  }))
}

write_receipt <- function(result, out) {
  required <- c(
    "cell_id", "replicate_id", "target", "truth", "estimate", "fit_status",
    "hessian_status", "objective_source", "hessian_method", "hessian_rank",
    "minimum_eigenvalue", "hessian_se", "hessian_covers", "procedure",
    "campaign_id", "source_sha", "message"
  )
  if (!identical(nrow(result), 3L) || !all(required %in% names(result)) ||
      anyDuplicated(result[c("cell_id", "replicate_id", "target")])) {
    stop("Refusing to write an incomplete or malformed target-level receipt.")
  }
  tmp <- tempfile(pattern = ".receipt-", tmpdir = dirname(out), fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(result, tmp, row.names = FALSE)
  if (!file.rename(tmp, out)) stop("Could not atomically publish receipt.")
  invisible(out)
}

if (identical(command, "prepare")) {
  campaign_id <- arg_value("--campaign-id")
  source_sha <- arg_value("--source-sha")
  if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) {
    stop("prepare requires --campaign-id and --source-sha.", call. = FALSE)
  }
  write_manifest(root, as.integer(arg_value("--n-rep", "100")), procedure,
                 campaign_id, source_sha)
} else if (identical(command, "run")) {
  if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
  m <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  cell <- m[m$cell_id == arg_value("--cell-id"), , drop = FALSE]
  if (nrow(cell) != 1L) stop("Unknown --cell-id.")
  reps <- seq.int(as.integer(arg_value("--start", "1")),
                  as.integer(arg_value("--end", as.character(cell$n_rep))))
  for (replicate_id in reps) {
    out <- file.path(root, "raw", sprintf("%s-%04d.csv", cell$cell_id,
                                           replicate_id))
    if (file.exists(out)) next
    write_receipt(run_one(cell, replicate_id, cell$procedure[[1L]]), out)
  }
} else if (identical(command, "summarise")) {
  files <- list.files(file.path(root, "raw"), full.names = TRUE, pattern = "\\.csv$")
  if (!length(files)) stop("No raw shards.")
  d <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
  if (!"procedure" %in% names(d)) d$procedure <- "both"
  manifest_data <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  required_receipt <- c("cell_id", "replicate_id", "target", "campaign_id", "source_sha")
  if (!all(required_receipt %in% names(d)) ||
      anyDuplicated(d[c("cell_id", "replicate_id", "target")])) {
    stop("Receipt identity is missing or duplicated.", call. = FALSE)
  }
  expected <- do.call(rbind, lapply(seq_len(nrow(manifest_data)), function(i) {
    data.frame(cell_id = manifest_data$cell_id[[i]],
               replicate_id = seq_len(manifest_data$n_rep[[i]]), target = 1:3)
  }))
  observed_key <- paste(d$cell_id, d$replicate_id, d$target, sep = "\r")
  expected_key <- paste(expected$cell_id, expected$replicate_id, expected$target, sep = "\r")
  if (!setequal(observed_key, expected_key)) {
    stop("Receipt set does not exactly match the frozen manifest.", call. = FALSE)
  }
  key <- interaction(d$cell_id, d$target, drop = TRUE)
  ans <- do.call(rbind, lapply(split(d, key), function(x) {
    hessian_ok <- x$hessian_status == "ok"
    hessian_coverage <- mean(x$hessian_covers %in% TRUE)
    usable_estimates <- x$estimate[is.finite(x$estimate)]
    usable_se <- x$hessian_se[hessian_ok & is.finite(x$hessian_se)]
    empirical_sd <- if (length(usable_estimates) > 1L) stats::sd(usable_estimates) else NA_real_
    data.frame(
    cell_id = x$cell_id[[1]], target = x$target[[1]], procedure = x$procedure[[1]],
    attempted = nrow(x), fit_available = mean(x$fit_status == "ok"),
    hessian_available = mean(hessian_ok),
    profile_available = mean(x$profile_lower_status == "crossed" &
                               x$profile_upper_status == "crossed", na.rm = TRUE),
    hessian_coverage_unconditional = hessian_coverage,
    hessian_coverage_conditional = if (any(hessian_ok)) mean(x$hessian_covers[hessian_ok] %in% TRUE) else NA_real_,
    hessian_coverage_mcse = sqrt(hessian_coverage * (1 - hessian_coverage) / nrow(x)),
    hessian_bias = if (length(usable_estimates)) mean(usable_estimates - x$truth[is.finite(x$estimate)]) else NA_real_,
    hessian_rmse = if (length(usable_estimates)) sqrt(mean((usable_estimates - x$truth[is.finite(x$estimate)])^2)) else NA_real_,
    empirical_sd = empirical_sd, hessian_mean_se = if (length(usable_se)) mean(usable_se) else NA_real_,
    hessian_se_to_empirical_sd = if (is.finite(empirical_sd) && empirical_sd > 0 && length(usable_se)) mean(usable_se) / empirical_sd else NA_real_,
    hessian_mean_width = if (length(usable_se)) 2 * stats::qnorm(.975) * mean(usable_se) else NA_real_,
    profile_coverage_unconditional = mean(x$profile_covers %in% TRUE)
    )
  }))
  utils::write.csv(ans, file.path(root, "summary.csv"), row.names = FALSE)
} else stop("Use prepare, run, or summarise.")
