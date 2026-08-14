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

manifest <- function(n_rep = 100L) {
  out <- data.frame(
    cell_id = c("U001", "U002", "U003", "U004"),
    link = c("logit", "probit", "cloglog", "cloglog"),
    regime = c("baseline", "baseline", "baseline", "low_prevalence"),
    beta_shift = c(0, 0, 0, -1.5),
    n_rep = rep(as.integer(n_rep), 4L),
    stringsAsFactors = FALSE
  )
  out$manifest_version <- "lane-b-mspl-uncertainty-pilot-v1-2026-08-13"
  out$seed_base <- 1813000000L + seq_len(nrow(out)) * 10000L
  out
}

write_manifest <- function(root, n_rep) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "raw"), showWarnings = FALSE)
  m <- manifest(n_rep)
  utils::write.csv(m, file.path(root, "manifest.csv"), row.names = FALSE)
  writeLines(c(
    "Private LA-MSPL uncertainty-candidate pilot.",
    "Candidates: active penalised numerical outer Hessian; active penalised profile threshold.",
    "No result is a calibrated SE or confidence interval. Public MSPL inference stays fail-closed.",
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

run_one <- function(cell, replicate_id) {
  sim <- simulate_data(cell, replicate_id)
  fit <- tryCatch(gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, family = stats::binomial(cell$link), estimator = "mspl",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0,
                                         se = FALSE, warn_runaway = FALSE)
  ), error = identity)
  if (inherits(fit, "error")) return(data.frame(
    cell_id = cell$cell_id, replicate_id = replicate_id, target = NA_integer_,
    truth = NA_real_, fit_status = "fit_error", hessian_status = NA_character_,
    profile_lower_status = NA_character_, profile_upper_status = NA_character_,
    hessian_se = NA_real_, hessian_covers = NA, profile_covers = NA,
    message = conditionMessage(fit), stringsAsFactors = FALSE
  ))
  idx <- which(names(fit$opt$par) == "b_fix")
  do.call(rbind, lapply(seq_along(idx), function(j) {
    h <- gllvmTMB:::.gllvmTMB_mspl_penalized_hessian_diagnostic(fit, idx[[j]])
    p <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
      fit, idx[[j]], step = .5, max_steps = 12L,
      control = list(eval.max = 100L, iter.max = 100L)
    )
    q <- gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(p)
    truth <- sim$beta[[j]]
    data.frame(
      cell_id = cell$cell_id, replicate_id = replicate_id, target = j,
      truth = truth, estimate = h$estimate, fit_status = "ok",
      hessian_status = h$status, profile_lower_status = q$lower_status,
      profile_upper_status = q$upper_status, hessian_se = h$se,
      hessian_covers = identical(h$status, "ok") &&
        truth >= h$diagnostic_lower && truth <= h$diagnostic_upper,
      profile_covers = identical(q$lower_status, "crossed") &&
        identical(q$upper_status, "crossed") && truth >= q$diagnostic_lower &&
        truth <= q$diagnostic_upper,
      message = NA_character_, stringsAsFactors = FALSE
    )
  }))
}

if (identical(command, "prepare")) {
  write_manifest(root, as.integer(arg_value("--n-rep", "100")))
} else if (identical(command, "run")) {
  devtools::load_all(quiet = TRUE)
  m <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
  cell <- m[m$cell_id == arg_value("--cell-id"), , drop = FALSE]
  if (nrow(cell) != 1L) stop("Unknown --cell-id.")
  reps <- seq.int(as.integer(arg_value("--start", "1")),
                  as.integer(arg_value("--end", as.character(cell$n_rep))))
  rows <- do.call(rbind, lapply(reps, function(replicate_id) {
    run_one(cell, replicate_id)
  }))
  out <- file.path(root, "raw", sprintf("%s-%04d-%04d.csv", cell$cell_id,
                                         min(reps), max(reps)))
  utils::write.csv(rows, out, row.names = FALSE)
} else if (identical(command, "summarise")) {
  files <- list.files(file.path(root, "raw"), full.names = TRUE, pattern = "\\.csv$")
  if (!length(files)) stop("No raw shards.")
  d <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
  key <- interaction(d$cell_id, d$target, drop = TRUE)
  ans <- do.call(rbind, lapply(split(d, key), function(x) data.frame(
    cell_id = x$cell_id[[1]], target = x$target[[1]], attempted = nrow(x),
    hessian_available = mean(x$hessian_status == "ok", na.rm = TRUE),
    profile_available = mean(x$profile_lower_status == "crossed" &
                               x$profile_upper_status == "crossed", na.rm = TRUE),
    hessian_coverage_unconditional = mean(x$hessian_covers %in% TRUE),
    profile_coverage_unconditional = mean(x$profile_covers %in% TRUE)
  )))
  utils::write.csv(ans, file.path(root, "summary.csv"), row.names = FALSE)
} else stop("Use prepare, run, or summarise.")
