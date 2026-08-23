#!/usr/bin/env Rscript

## Release-evidence local smoke: 12 frozen augmented phylo_indep slope cells.
##
## This is a one-seed operational/recovery smoke, not a coverage campaign and
## not an admission mechanism.  It deliberately retains every failure in the
## results CSV.  The 12 cells are the 11 current admitted family IDs, with the
## two admitted binomial links recorded as separate cells.  See README.md for
## the symbol-to-implementation alignment table and stop rules.

`%||%` <- function(x, y) if (is.null(x)) y else x
options(warn = 1)

script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L] %||% "dev/release-evidence/run-slope-smoke.R")
script_dir <- dirname(normalizePath(script_arg, mustWork = FALSE))
if (!dir.exists(script_dir)) script_dir <- "dev/release-evidence"
repo_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
if (!file.exists(file.path(repo_root, "DESCRIPTION"))) {
  stop("Could not locate the package source checkout from: ", script_dir)
}
manifest_path <- file.path(script_dir, "slope-smoke-manifest.csv")
out_path <- Sys.getenv("GLLVMTMB_SLOPE_SMOKE_OUTPUT", file.path(script_dir, "slope-smoke-results.csv"))
summary_path <- sub("\\.csv$", "-summary.csv", out_path)
if (!file.exists(manifest_path)) stop("Frozen manifest not found: ", manifest_path)

per_fit_limit <- 90
total_limit <- 20 * 60
manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
stopifnot(nrow(manifest) == 12L, length(unique(manifest$cell_id)) == 12L)
max_cells <- suppressWarnings(as.integer(Sys.getenv("GLLVMTMB_SLOPE_SMOKE_MAX_CELLS", "12")))
if (!is.finite(max_cells) || max_cells < 1L || max_cells > nrow(manifest)) {
  stop("GLLVMTMB_SLOPE_SMOKE_MAX_CELLS must be an integer from 1 through ", nrow(manifest))
}
first_cell <- suppressWarnings(as.integer(Sys.getenv("GLLVMTMB_SLOPE_SMOKE_FIRST_CELL", "1")))
if (!is.finite(first_cell) || first_cell < 1L || first_cell > nrow(manifest)) {
  stop("GLLVMTMB_SLOPE_SMOKE_FIRST_CELL must be an integer from 1 through ", nrow(manifest))
}
manifest <- manifest[seq.int(first_cell, min(max_cells, nrow(manifest))), , drop = FALSE]

if (!requireNamespace("ape", quietly = TRUE)) stop("Package 'ape' is required.")
if (!requireNamespace("pkgload", quietly = TRUE)) stop("Package 'pkgload' is required to load the source checkout.")
pkgload::load_all(repo_root, quiet = TRUE, export_all = FALSE)
package_path <- normalizePath(getNamespaceInfo(asNamespace("gllvmTMB"), "path"), mustWork = TRUE)
if (!identical(package_path, repo_root)) {
  stop("Loaded gllvmTMB namespace is not the requested source checkout: ", package_path)
}

repo_revision <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
  error = function(e) NA_character_
)
repo_revision <- if (length(repo_revision)) repo_revision[[1L]] else NA_character_

make_dgp <- function(seed, n_species, n_rep) {
  set.seed(seed)
  n_trait <- 3L
  tree <- ape::rcoal(n_species)
  tree$tip.label <- sprintf("sp%03d", seq_len(n_species))
  A <- ape::vcv(tree, corr = TRUE)
  L <- t(chol(A + diag(1e-8, n_species)))
  trait <- sprintf("t%d", seq_len(n_trait))
  beta_truth <- c(-0.35, 0, 0.35)
  sd_int_truth <- c(0.45, 0.55, 0.40)
  sd_slope_truth <- c(0.35, 0.45, 0.30)
  rho_truth <- c(0.20, -0.15, 0.10)
  effects <- lapply(seq_len(n_trait), function(j) {
    Sigma <- diag(c(sd_int_truth[[j]], sd_slope_truth[[j]])) %*%
      matrix(c(1, rho_truth[[j]], rho_truth[[j]], 1), 2L) %*%
      diag(c(sd_int_truth[[j]], sd_slope_truth[[j]]))
    L %*% matrix(stats::rnorm(n_species * 2L), n_species, 2L) %*% chol(Sigma)
  })
  base <- expand.grid(species = tree$tip.label, rep = seq_len(n_rep), KEEP.OUT.ATTRS = FALSE)
  base$x <- stats::rnorm(nrow(base))
  d <- do.call(rbind, lapply(seq_len(n_trait), function(j) {
    data.frame(species = base$species, rep = base$rep, x = base$x,
      trait = trait[[j]], eta = beta_truth[[j]] +
        effects[[j]][match(base$species, tree$tip.label), 1L] +
        effects[[j]][match(base$species, tree$tip.label), 2L] * base$x,
      stringsAsFactors = FALSE)
  }))
  d$species <- factor(d$species, levels = tree$tip.label)
  d$trait <- factor(d$trait, levels = trait)
  list(data = d, tree = tree, beta = beta_truth, sd = as.vector(rbind(sd_int_truth, sd_slope_truth)), rho = rho_truth)
}

make_response <- function(d, family, link) {
  eta <- d$eta
  if (family == "gaussian") return(eta + stats::rnorm(length(eta), sd = 0.35))
  if (family == "binomial") return(stats::rbinom(length(eta), 1L, if (link == "probit") stats::pnorm(eta) else stats::plogis(eta)))
  if (family == "poisson") return(stats::rpois(length(eta), pmin(exp(eta), 100)))
  if (family == "lognormal") return(exp(eta + stats::rnorm(length(eta), sd = 0.35)))
  if (family == "Gamma") { mu <- pmin(exp(eta), 100); return(stats::rgamma(length(mu), shape = 4, rate = 4 / mu)) }
  if (family == "nbinom2") return(stats::rnbinom(length(eta), mu = pmin(exp(eta), 100), size = 3))
  if (family == "nbinom1") { mu <- pmin(exp(eta), 100); return(stats::rnbinom(length(mu), mu = mu, size = mu / 0.7)) }
  if (family == "Beta") { p <- pmin(pmax(stats::plogis(eta), 1e-4), 1 - 1e-4); return(stats::rbeta(length(p), p * 12, (1 - p) * 12)) }
  if (family == "betabinomial") {
    p <- pmin(pmax(stats::plogis(eta), 1e-4), 1 - 1e-4)
    pp <- stats::rbeta(length(p), p * 8, (1 - p) * 8)
    success <- stats::rbinom(length(p), 15L, pp)
    return(cbind(success = success, failure = 15L - success))
  }
  if (family == "student") return(eta + stats::rt(length(eta), df = 6) * 0.35)
  if (family == "ordinal_probit") return(as.integer(cut(eta + stats::rnorm(length(eta)), breaks = c(-Inf, -0.6, 0.6, Inf), labels = FALSE)))
  stop("No DGP for ", family)
}

family_object <- function(family, link) switch(family,
  gaussian = stats::gaussian(), binomial = stats::binomial(link = link), poisson = stats::poisson(),
  lognormal = gllvmTMB::lognormal(), Gamma = stats::Gamma(link = link), nbinom2 = gllvmTMB::nbinom2(),
  nbinom1 = gllvmTMB::nbinom1(), Beta = gllvmTMB::Beta(), betabinomial = gllvmTMB::betabinomial(),
  student = gllvmTMB::student(), ordinal_probit = gllvmTMB::ordinal_probit())

one <- function(cell, started) {
  fx <- make_dgp(cell$seed, cell$n_species, cell$n_rep)
  y <- make_response(fx$data, cell$family, cell$link)
  d <- fx$data
  response <- "value"
  if (is.matrix(y)) { d$success <- y[, "success"]; d$failure <- 15L - d$success; response <- "cbind(success, failure)" } else d$value <- y
  form <- stats::as.formula(sprintf("%s ~ 0 + trait + phylo_indep(1 + x | species, tree = fx$tree)", response))
  warning_text <- character()
  elapsed <- system.time({
    setTimeLimit(elapsed = per_fit_limit, transient = TRUE)
    on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
    fit <- tryCatch(withCallingHandlers(
  gllvmTMB::gllvmTMB(form, data = d, trait = "trait", unit = "species", family = family_object(cell$family, cell$link)),
      warning = function(w) { warning_text <<- c(warning_text, conditionMessage(w)); invokeRestart("muffleWarning") }),
      error = function(e) e)
  })[["elapsed"]]
  base <- data.frame(repo_revision = repo_revision, source_checkout = repo_root, package_path = package_path, cell_id = cell$cell_id, family = cell$family, link = cell$link, seed = cell$seed,
    n_species = cell$n_species, n_rep = cell$n_rep, elapsed_seconds = elapsed,
    total_elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
    status = "error", error = NA_character_, warnings = paste(unique(warning_text), collapse = " | "),
    convergence = NA_integer_, pd_hessian = NA, max_abs_gradient = NA_real_,
    fixed_truth = paste(fx$beta, collapse = ";"), fixed_estimate = NA_character_, fixed_max_abs_error = NA_real_,
    sd_truth = paste(fx$sd, collapse = ";"), sd_estimate = NA_character_, sd_max_relative_error = NA_real_,
    cor_truth = paste(fx$rho, collapse = ";"), cor_estimate = NA_character_, cor_max_abs_error = NA_real_,
    healthy = FALSE, healthy_reason = "fit error", stringsAsFactors = FALSE)
  if (inherits(fit, "error")) { base$error <- conditionMessage(fit); return(base) }
  fixed <- as.numeric(fit$sd_report$par.fixed[names(fit$sd_report$par.fixed) == "b_fix"])
  sd <- as.numeric(fit$report$sd_b)
  cor_mat <- tryCatch(as.matrix(fit$report$cor_b_mat), error = function(e) NULL)
  cor <- if (!is.null(cor_mat) && nrow(cor_mat) == 6L) {
    cor_mat[cbind(c(1L, 3L, 5L), c(2L, 4L, 6L))]
  } else numeric()
  gradient <- tryCatch(as.numeric(fit$fit_health$max_gradient), error = function(e) NA_real_)
  base$status <- if (elapsed > per_fit_limit) "timeout" else "completed"
  base$convergence <- fit$opt$convergence
  base$pd_hessian <- isTRUE(fit$sd_report$pdHess)
  base$max_abs_gradient <- gradient
  base$fixed_estimate <- paste(fixed, collapse = ";")
  base$fixed_max_abs_error <- if (length(fixed) == 3L) max(abs(fixed - fx$beta)) else NA_real_
  base$sd_estimate <- paste(sd, collapse = ";")
  base$sd_max_relative_error <- if (length(sd) == 6L) max(abs(sd - fx$sd) / fx$sd) else NA_real_
  base$cor_estimate <- paste(cor, collapse = ";")
  base$cor_max_abs_error <- if (length(cor) == 3L) max(abs(cor - fx$rho)) else NA_real_
  healthy_bits <- c(
    completed = identical(base$status, "completed"),
    convergence = identical(base$convergence, 0L),
    pd_hessian = isTRUE(base$pd_hessian),
    gradient = is.finite(base$max_abs_gradient) && base$max_abs_gradient < 1e-2,
    elapsed = is.finite(base$elapsed_seconds) && base$elapsed_seconds <= per_fit_limit
  )
  base$healthy <- all(healthy_bits)
  base$healthy_reason <- if (base$healthy) "healthy" else paste(names(healthy_bits)[!healthy_bits], collapse = ";")
  base
}

started <- Sys.time(); rows <- list()
for (i in seq_len(nrow(manifest))) {
  if (as.numeric(difftime(Sys.time(), started, units = "secs")) >= total_limit) {
    rows[[length(rows) + 1L]] <- data.frame(repo_revision = repo_revision, source_checkout = repo_root, package_path = package_path, cell_id = manifest$cell_id[[i]], family = manifest$family[[i]], link = manifest$link[[i]], seed = manifest$seed[[i]], n_species = manifest$n_species[[i]], n_rep = manifest$n_rep[[i]], elapsed_seconds = NA_real_, total_elapsed_seconds = total_limit, status = "not_run_total_stop", error = "20-minute total stop rule reached", warnings = NA_character_, convergence = NA_integer_, pd_hessian = NA, max_abs_gradient = NA_real_, fixed_truth = NA_character_, fixed_estimate = NA_character_, fixed_max_abs_error = NA_real_, sd_truth = NA_character_, sd_estimate = NA_character_, sd_max_relative_error = NA_real_, cor_truth = NA_character_, cor_estimate = NA_character_, cor_max_abs_error = NA_real_, healthy = FALSE, healthy_reason = "total stop")
    next
  }
  rows[[length(rows) + 1L]] <- one(manifest[i, ], started)
  ## Persist progress before a later cell; failures are release evidence too.
  utils::write.csv(do.call(rbind, rows), out_path, row.names = FALSE, na = "")
}
result <- do.call(rbind, rows)
utils::write.csv(result, out_path, row.names = FALSE, na = "")
done <- result$elapsed_seconds[result$status == "completed" & is.finite(result$elapsed_seconds)]
smoke_pass <- nrow(result) == 12L && all(result$healthy)
summary <- data.frame(
  repo_revision = repo_revision,
  source_checkout = repo_root,
  package_path = package_path,
  n_cells = nrow(result),
  n_healthy = sum(result$healthy),
  smoke_pass = smoke_pass,
  p90_seconds = if (length(done)) as.numeric(stats::quantile(done, 0.9, names = FALSE)) else NA_real_,
  total_seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))
)
utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
cat("results:", normalizePath(out_path, mustWork = FALSE), "\n")
cat("summary:", normalizePath(summary_path, mustWork = FALSE), "\n")
cat("completed:", length(done), "/", nrow(result), " p90_seconds:", if (length(done)) as.numeric(stats::quantile(done, 0.9, names = FALSE)) else NA_real_, "\n")
cat("revision:", repo_revision, " total_seconds:", as.numeric(difftime(Sys.time(), started, units = "secs")), "\n")
