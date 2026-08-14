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
totoro_preflight <- "--totoro-preflight" %in% args
campaign <- "--campaign" %in% args
campaign_phase <- Sys.getenv("GLLVM897_PHASE", "development")
campaign_seeds <- as.integer(strsplit(Sys.getenv("GLLVM897_SEEDS", "1,2,3"), ",", fixed = TRUE)[[1L]])
workers <- as.integer(Sys.getenv("GLLVM897_WORKERS", "1"))
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_arg)) sub("^--file=", "", script_arg[[1L]]) else NA_character_
out_dir <- Sys.getenv(
  "GLLVM897_OUT",
  file.path(path.expand("~"), "gllvm_work", "results", "897-ordinal-detector")
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

stop_if <- function(x, message) if (isTRUE(x)) stop(message, call. = FALSE)
stop_if(!is.finite(workers) || workers < 1L || workers > 150L,
        "GLLVM897_WORKERS must be an integer from 1 through 150")

rel_frob <- function(x, truth) {
  norm(x - truth, "F") / norm(truth, "F")
}

hash_rds <- function(x) {
  path <- tempfile("gllvm897-hash-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(x, path, version = 2)
  unname(tools::md5sum(path))
}

fit_contract <- function(fit, categories) {
  map <- fit$tmb_obj$env$map
  par_names <- names(fit$tmb_obj$env$par)
  random_names <- par_names[fit$tmb_obj$env$random]
  data.frame(
    rr_B = isTRUE(fit$use$rr_B),
    diag_B = isTRUE(fit$use$diag_B),
    family_id_14 = identical(unique(as.integer(fit$tmb_data$family_id_vec)), 14L),
    unique_false = !isTRUE(fit$use$diag_B),
    theta_diag_B_mapped = isTRUE(all(is.na(as.vector(map$theta_diag_B)))),
    s_B_mapped = isTRUE(all(is.na(as.vector(map$s_B)))),
    categories_match = identical(
      unique(as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)),
      as.integer(categories - 2L)
    ),
    random_blocks = paste(unique(random_names), collapse = ";"),
    formula = paste(deparse(fit$call$formula), collapse = " "),
    control = "gllvmTMBcontrol(); aghq_ridge omitted",
    stringsAsFactors = FALSE
  )
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
  list(
    data = data, Sigma_B = tcrossprod(Lambda), Lambda_B = Lambda, scores = scores,
    latent = latent, tau = tau
  )
}

fit_cell <- function(cell) {
  cell_id <- paste(
    paste0("n", cell$n), paste0("p", cell$p), paste0("q", cell$q),
    paste0("K", cell$categories), paste0("miss", cell$missing),
    cell$loading_shape, paste0("seed", cell$seed), sep = "-"
  )
  base <- data.frame(
    cell_id = cell_id, seed = cell$seed, n = cell$n, p = cell$p, q = cell$q,
    categories = cell$categories, missing = cell$missing,
    loading_shape = cell$loading_shape, rng_kind = paste(RNGkind(), collapse = "/"),
    start_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
  fixture <- make_fixture(
    cell$n, cell$p, cell$q, cell$categories, cell$missing,
    cell$loading_shape, cell$seed
  )
  observed_counts <- vapply(seq_len(cell$p), function(trait) {
    tabulate(
      fixture$data$value[fixture$data$trait == trait & !is.na(fixture$data$value)],
      nbins = cell$categories
    )
  }, integer(cell$categories))
  singular_values <- svd(fixture$Lambda_B, nu = 0L, nv = 0L)$d
  if (any(observed_counts == 0L) ||
      length(singular_values) < cell$q ||
      any(singular_values[seq_len(cell$q)] <= sqrt(.Machine$double.eps))) {
    return(cbind(
      base, status = "INVALID_DGP", observed_n = sum(observed_counts),
      min_category_count = min(observed_counts),
      lambda_rank = sum(singular_values > sqrt(.Machine$double.eps)),
      lambda_condition = max(singular_values) / min(singular_values),
      Lambda_hash = hash_rds(fixture$Lambda_B), Z_hash = hash_rds(fixture$scores),
      latent_hash = hash_rds(fixture$latent), missing_hash = hash_rds(is.na(fixture$data$value)),
      note = "intended category absent or true Lambda rank deficient"
    ))
  }
  cpu_started <- proc.time()
  warnings <- character(0)
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | site, d = cell$q, unique = FALSE),
        data = fixture$data, trait = "trait", unit = "site", family = ordinal_probit()
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  cpu_elapsed <- proc.time() - cpu_started
  if (inherits(fit, "error")) {
    return(cbind(
      base, status = "ERROR", user_cpu = cpu_elapsed[["user.self"]],
      system_cpu = cpu_elapsed[["sys.self"]], observed_n = sum(observed_counts),
      min_category_count = min(observed_counts),
      lambda_rank = length(singular_values),
      lambda_condition = max(singular_values) / min(singular_values),
      Lambda_hash = hash_rds(fixture$Lambda_B),
      Z_hash = hash_rds(fixture$scores), latent_hash = hash_rds(fixture$latent),
      missing_hash = hash_rds(is.na(fixture$data$value)),
      true_cutpoints = paste(fixture$tau, collapse = ";"),
      warnings = paste(warnings, collapse = " | "), note = conditionMessage(fit)
    ))
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
  raw_gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
  contract <- fit_contract(fit, cell$categories)
  cbind(
    base,
    status = "OK",
    end_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    user_cpu = cpu_elapsed[["user.self"]],
    system_cpu = cpu_elapsed[["sys.self"]],
    observed_n = sum(observed_counts),
    min_category_count = min(observed_counts),
    lambda_rank = length(singular_values),
    lambda_condition = max(singular_values) / min(singular_values),
    Lambda_hash = hash_rds(fixture$Lambda_B),
    Z_hash = hash_rds(fixture$scores), latent_hash = hash_rds(fixture$latent),
    missing_hash = hash_rds(is.na(fixture$data$value)),
    true_cutpoints = paste(fixture$tau, collapse = ";"),
    warnings = paste(warnings, collapse = " | "),
    convergence = convergence,
    pd_hess = pd_hess,
    max_gradient_raw = max(abs(raw_gradient), na.rm = TRUE),
    objective = as.numeric(stats::logLik(fit)),
    rel_frob = rel_frob(Sigma, fixture$Sigma_B),
    silent_degenerate = rel_frob(Sigma, fixture$Sigma_B) > 10 &&
      identical(convergence, 0L) && pd_hess,
    max_row_norm = max(row_norm),
    max_relative_row_norm = max(row_norm / typical_norm),
    min_observed_category_share = min(category_share),
    saturation_share = mean(max_category_prob >= 0.99),
    min_cutpoint_spacing = if (length(spacing)) min(spacing) else NA_real_,
    contract,
    note = ""
  )
}

grid <- expand.grid(
  n = c(60L, 150L, 400L, 1600L), p = c(12L, 27L), q = c(1L, 2L),
  categories = c(3L, 4L, 6L), missing = c(0, 0.3),
  loading_shape = c("homogeneous", "sparse_identifiable"),
  seed = c(1L, 2L, 3L), stringsAsFactors = FALSE
)
if (totoro_preflight) {
  ## Expensive-edge timing receipt only: this is deliberately not a calibration
  ## grid and must be approved before it is run on Totoro.
  grid <- expand.grid(
    n = 1600L, p = 27L, q = 2L, categories = c(3L, 6L), missing = 0.3,
    loading_shape = c("homogeneous", "sparse_identifiable"), seed = 4L,
    stringsAsFactors = FALSE
  )
} else if (campaign) {
  ## The target surface is deliberately ordinary ordinal-probit only.  The
  ## phase-specific seeds are disjoint so threshold selection cannot consume
  ## held-out evidence.
  grid <- expand.grid(
    n = c(60L, 150L, 400L, 1600L), p = c(12L, 27L), q = c(1L, 2L),
    categories = c(3L, 4L, 6L), missing = c(0, 0.3),
    loading_shape = c("homogeneous", "sparse_identifiable"),
    seed = campaign_seeds, stringsAsFactors = FALSE
  )
} else if (timing_smoke) {
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

tag <- if (totoro_preflight) "totoro-preflight" else if (campaign) {
  paste0("campaign-", campaign_phase)
} else if (timing_smoke) {
  "timing-smoke"
} else if (failure_smoke) {
  "failure-smoke"
} else if (smoke) {
  "smoke"
} else {
  "grid"
}
cell_dir <- file.path(out_dir, paste0(tag, "-cell-receipts"))
dir.create(cell_dir, recursive = TRUE, showWarnings = FALSE)
cell_key <- function(cell) {
  paste(
    paste0("n", cell$n), paste0("p", cell$p), paste0("q", cell$q),
    paste0("K", cell$categories), paste0("miss", cell$missing),
    cell$loading_shape, paste0("seed", cell$seed), sep = "-"
  )
}
record_cell <- function(cell) {
  receipt <- file.path(cell_dir, paste0(cell_key(cell), ".rds"))
  if (file.exists(receipt)) return(readRDS(receipt))
  row <- fit_cell(cell)
  temporary <- tempfile("write-", tmpdir = cell_dir, fileext = ".rds")
  saveRDS(row, temporary, version = 2)
  stop_if(!file.rename(temporary, receipt), paste("Cannot retain", receipt))
  row
}

started <- Sys.time()
cells <- split(grid, seq_len(nrow(grid)))
rows <- if (workers == 1L) {
  lapply(cells, record_cell)
} else {
  parallel::mclapply(cells, record_cell, mc.cores = workers, mc.preschedule = FALSE)
}
out <- do.call(rbind, rows)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
commit <- Sys.getenv("GLLVM897_COMMIT", unset = NA_character_)
if (is.na(commit) || !nzchar(commit)) commit <- system("git rev-parse HEAD 2>/dev/null", intern = TRUE)
provenance <- data.frame(
  commit = commit,
  script_md5 = if (!is.na(script_file) && file.exists(script_file)) {
    unname(tools::md5sum(script_file))
  } else {
    NA_character_
  },
  r_version = R.version.string,
  package_version = as.character(utils::packageVersion("gllvmTMB")),
  command = paste(commandArgs(), collapse = " "),
  smoke = smoke, failure_smoke = failure_smoke, timing_smoke = timing_smoke,
  totoro_preflight = totoro_preflight, campaign = campaign,
  campaign_phase = campaign_phase, workers = workers,
  elapsed_seconds = elapsed,
  stringsAsFactors = FALSE
)
utils::write.csv(out, file.path(out_dir, paste0(tag, "-cells.csv")), row.names = FALSE)
utils::write.csv(provenance, file.path(out_dir, paste0(tag, "-provenance.csv")), row.names = FALSE)
receipt_path <- file.path(out_dir, paste0(tag, "-receipt.rds"))
saveRDS(
  list(cells = out, provenance = provenance, tag = tag, created_at = Sys.time()),
  receipt_path,
  version = 2
)
artifact_paths <- c(
  file.path(out_dir, paste0(tag, "-cells.csv")),
  file.path(out_dir, paste0(tag, "-provenance.csv")),
  receipt_path
)
utils::write.csv(
  data.frame(file = basename(artifact_paths), md5 = unname(tools::md5sum(artifact_paths))),
  file.path(out_dir, paste0(tag, "-manifest.csv")),
  row.names = FALSE
)
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
