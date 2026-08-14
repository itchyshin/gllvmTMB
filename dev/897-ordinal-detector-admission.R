## #897 ordinal-probit degeneracy-detector admission harness.
##
## This is evidence machinery, not package behaviour.  It records a known-DGP
## shared-covariance failure label alongside quantities available from one
## fitted ordinal-probit model.  The truth label is never an input to a
## prospective check_gllvmTMB() row.

suppressPackageStartupMessages(library(gllvmTMB))

args <- commandArgs(trailingOnly = TRUE)
smoke <- "--smoke" %in% args
failure_smoke <- "--failure-smoke" %in% args
timing_smoke <- "--timing-smoke" %in% args
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else NA_character_
out_dir <- Sys.getenv(
  "GLLVM897_OUT",
  file.path(path.expand("~"), "gllvm_work", "results", "897-ordinal-detector")
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

stop_if <- function(x, message) if (isTRUE(x)) stop(message, call. = FALSE)

rel_frob <- function(x, truth) {
  norm(x - truth, "F") / norm(truth, "F")
}

ordinal_probabilities <- function(fit) {
  eta <- as.numeric(fit$report$eta)
  trait_id <- as.integer(fit$tmb_data$trait_id) + 1L
  n_cuts <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  cuts <- extract_cutpoints(fit, quiet = TRUE)
  out <- rep(NA_real_, length(eta))
  for (trait in seq_along(n_cuts)) {
    idx <- which(trait_id == trait)
    tau <- c(0, cuts$tau_estimate[cuts$trait == levels(fit$data[[fit$trait_col]])[trait]])
    bounds <- c(-Inf, tau, Inf)
    probs <- vapply(seq_len(length(bounds) - 1L), function(k) {
      stats::pnorm(bounds[k + 1L] - eta[idx]) - stats::pnorm(bounds[k] - eta[idx])
    }, numeric(length(idx)))
    out[idx] <- apply(probs, 1L, max)
  }
  out
}

make_fixture <- function(n, p, q, categories, missing, loading_shape, seed) {
  set.seed(seed)
  Lambda <- matrix(stats::rnorm(p * q, sd = 0.7), p, q)
  if (identical(loading_shape, "sparse_identifiable")) {
    Lambda[] <- 0
    Lambda[cbind(seq_len(p), rep(seq_len(q), length.out = p))] <-
      stats::rnorm(p, mean = 1.2, sd = 0.15)
  }
  scores <- matrix(stats::rnorm(n * q), n, q)
  alpha <- stats::rnorm(p, sd = 0.3)
  tau <- switch(
    as.character(categories),
    "3" = c(0, 0.7),
    "4" = c(0, 0.7, 1.4),
    "6" = c(0, 0.35, 0.8, 1.35, 2.1),
    stop("categories must be 3, 4, or 6", call. = FALSE)
  )
  eta <- scores %*% t(Lambda) + matrix(alpha, n, p, byrow = TRUE)
  latent <- as.numeric(t(eta)) + stats::rnorm(n * p)
  value <- 1L + vapply(latent, function(x) sum(x > tau), integer(1))
  if (missing > 0) {
    value[sample.int(length(value), floor(length(value) * missing))] <- NA_integer_
  }
  data <- data.frame(
    site = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(seq_len(p), times = n)),
    value = value
  )
  list(data = data, Sigma_B = tcrossprod(Lambda), Lambda_B = Lambda, tau = tau)
}

fit_cell <- function(cell) {
  fixture <- make_fixture(
    cell$n, cell$p, cell$q, cell$categories, cell$missing,
    cell$loading_shape, cell$seed
  )
  fit <- tryCatch(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = cell$q, unique = FALSE),
      data = fixture$data, trait = "trait", unit = "site", family = ordinal_probit()
    )),
    error = function(e) e
  )
  base <- data.frame(
    seed = cell$seed, n = cell$n, p = cell$p, q = cell$q,
    categories = cell$categories, missing = cell$missing,
    loading_shape = cell$loading_shape, stringsAsFactors = FALSE
  )
  if (inherits(fit, "error")) {
    return(cbind(base, status = "ERROR", note = conditionMessage(fit)))
  }
  Lambda <- fit$report$Lambda_B
  if (!is.matrix(Lambda) || !all(is.finite(Lambda))) {
    return(cbind(base, status = "NO_LAMBDA", note = "Lambda_B missing or non-finite"))
  }
  Sigma <- tcrossprod(Lambda)
  row_norm <- sqrt(diag(Sigma))
  typical_norm <- stats::median(row_norm[row_norm > 0], na.rm = TRUE)
  observed <- !is.na(fixture$data$value)
  category_share <- vapply(seq_len(cell$p), function(trait) {
    y <- fixture$data$value[fixture$data$trait == trait & observed]
    min(tabulate(y, nbins = cell$categories) / length(y))
  }, numeric(1))
  max_category_prob <- ordinal_probabilities(fit)
  cuts <- extract_cutpoints(fit, quiet = TRUE)
  spacing <- unlist(lapply(split(cuts$tau_estimate, cuts$trait), diff), use.names = FALSE)
  convergence <- as.integer(fit$opt$convergence)
  pd_hess <- isTRUE(fit$sd_report$pdHess)
  cbind(
    base,
    status = "OK",
    convergence = convergence,
    pd_hess = pd_hess,
    objective = as.numeric(stats::logLik(fit)),
    rel_frob = rel_frob(Sigma, fixture$Sigma_B),
    silent_degenerate = rel_frob(Sigma, fixture$Sigma_B) > 10 &&
      identical(convergence, 0L) && pd_hess,
    max_row_norm = max(row_norm),
    max_relative_row_norm = max(row_norm / typical_norm),
    min_observed_category_share = min(category_share),
    saturation_share = mean(max_category_prob >= 0.99),
    min_cutpoint_spacing = if (length(spacing)) min(spacing) else NA_real_,
    note = ""
  )
}

grid <- expand.grid(
  n = c(60L, 150L, 400L, 1600L), p = c(12L, 27L), q = c(1L, 2L),
  categories = c(3L, 4L, 6L), missing = c(0, 0.3),
  loading_shape = c("homogeneous", "sparse_identifiable"),
  seed = c(1L, 2L, 3L), stringsAsFactors = FALSE
)
if (timing_smoke) {
  ## Seed 4 was a retained truth-labelled silent-degeneracy row in the first
  ## bounded probe.  This one-cell mode exists solely to price the exact
  ## pathological fit before any remote campaign is proposed.
  grid <- data.frame(
    n = 60L, p = 12L, q = 2L, categories = 4L, missing = 0,
    loading_shape = "homogeneous", seed = 4L, stringsAsFactors = FALSE
  )
} else if (failure_smoke) {
  grid <- data.frame(
    n = 60L, p = 12L, q = 2L, categories = 4L, missing = 0,
    loading_shape = "homogeneous", seed = seq_len(12L), stringsAsFactors = FALSE
  )
} else if (smoke) {
  grid <- data.frame(
    n = c(60L, 150L), p = 12L, q = 2L, categories = 4L, missing = 0,
    loading_shape = "homogeneous", seed = c(1L, 101L), stringsAsFactors = FALSE
  )
}

started <- Sys.time()
rows <- lapply(split(grid, seq_len(nrow(grid))), fit_cell)
out <- do.call(rbind, rows)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
provenance <- data.frame(
  commit = system("git rev-parse HEAD", intern = TRUE),
  script_md5 = if (!is.na(script_file) && file.exists(script_file)) {
    unname(tools::md5sum(script_file))
  } else {
    NA_character_
  },
  r_version = R.version.string,
  package_version = as.character(utils::packageVersion("gllvmTMB")),
  command = paste(commandArgs(), collapse = " "),
  smoke = smoke, failure_smoke = failure_smoke, timing_smoke = timing_smoke,
  elapsed_seconds = elapsed,
  stringsAsFactors = FALSE
)
tag <- if (timing_smoke) "timing-smoke" else if (failure_smoke) {
  "failure-smoke"
} else if (smoke) {
  "smoke"
} else {
  "grid"
}
utils::write.csv(out, file.path(out_dir, paste0(tag, "-cells.csv")), row.names = FALSE)
utils::write.csv(provenance, file.path(out_dir, paste0(tag, "-provenance.csv")), row.names = FALSE)
cat(sprintf("#897 %s: %d rows in %.2f s\n", tag, nrow(out), elapsed))
cat("status counts:\n")
print(table(out$status, useNA = "ifany"))
if ("silent_degenerate" %in% names(out)) {
  cat("silent-degenerate counts:\n")
  print(table(out$silent_degenerate, useNA = "ifany"))
}
flush.console()
rm(rows, out)
gc(verbose = FALSE)
quit(save = "no", status = 0L, runLast = FALSE)
