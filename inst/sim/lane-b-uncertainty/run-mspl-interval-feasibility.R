#!/usr/bin/env Rscript

## Private Arc-3 LA-MSPL bootstrap feasibility runner. This is deliberately
## separate from public bootstrap/confint dispatch and from repeated-sampling
## coverage campaigns. Every requested draw is retained exactly once.

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x
arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}
atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-interval-", dirname(path), fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path)
  invisible(path)
}

manifest_table <- function(
  n_bootstrap = 1000L,
  shard_size = 100L,
  clusters = c("fir", "nibi", "rorqual"),
  campaign_id,
  source_sha,
  mcse_reps = 2000L
) {
  regimes <- data.frame(
    regime = c("baseline", "low_prevalence", "high_prevalence", "strong_signal"),
    beta_shift = c(0, -1.5, 1.5, 0), lambda_scale = c(1, 1, 1, 1.75),
    stringsAsFactors = FALSE
  )
  out <- merge(
    regimes,
    data.frame(link = c("logit", "probit", "cloglog"), stringsAsFactors = FALSE),
    by = NULL, sort = FALSE
  )
  out$case_number <- seq_len(nrow(out))
  out$case_id <- sprintf("C%03d", out$case_number)
  out$fixture_seed <- 8808L + match(out$link, c("logit", "probit", "cloglog")) + 1L
  out$n_bootstrap <- as.integer(n_bootstrap)
  out$shard_size <- as.integer(shard_size)
  out$n_shards <- as.integer(ceiling(n_bootstrap / shard_size))
  out$minimum_usable <- as.integer(ceiling(0.95 * n_bootstrap))
  out$mcse_reps <- as.integer(mcse_reps)
  out$assigned_cluster <- rep(clusters, length.out = nrow(out))
  out$manifest_version <- "lane-b-mspl-interval-v1-2026-08-14"
  out$campaign_id <- campaign_id
  out$source_sha <- source_sha
  out[, c(
    "case_id", "case_number", "regime", "link", "beta_shift",
    "lambda_scale", "fixture_seed", "n_bootstrap", "shard_size",
    "n_shards", "minimum_usable", "mcse_reps", "assigned_cluster",
    "manifest_version", "campaign_id", "source_sha"
  )]
}

fixture_data <- function(case) {
  set.seed(case$fixture_seed[[1L]])
  n_site <- 24L
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  beta <- c(-0.5, 0.1, 0.55) + case$beta_shift[[1L]]
  lambda <- case$lambda_scale[[1L]] * c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * lambda[as.integer(trait)]
  mu <- switch(
    case$link[[1L]],
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta))
  )
  data.frame(
    site = site, trait = trait,
    y = stats::rbinom(length(mu), 1L, mu)
  )
}

fit_mspl <- function(data, link) {
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = data, family = stats::binomial(link = link), estimator = "mspl",
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    ),
    silent = TRUE
  )
}

runtime_fingerprint <- function() {
  paste(
    R.version$version.string,
    paste0("TMB=", as.character(utils::packageVersion("TMB"))),
    paste0("gllvmTMB=", as.character(utils::packageVersion("gllvmTMB"))),
    R.version$platform,
    sep = " | "
  )
}

failure_rows <- function(case, replicate_id, status, message, cluster,
                         fingerprint, unconditional_redraw = FALSE) {
  data.frame(
    manifest_version = case$manifest_version,
    campaign_id = case$campaign_id, source_sha = case$source_sha,
    cluster = cluster, case_id = case$case_id,
    case_number = case$case_number, regime = case$regime, link = case$link,
    bootstrap_rep_id = replicate_id, target = seq_len(3L),
    target_name = sprintf("b_fix[%d]", seq_len(3L)), estimate = NA_real_,
    status = status, convergence = NA_integer_, objective = NA_real_,
    estimator_id = NA_integer_, unconditional_redraw = unconditional_redraw,
    seed = 1814000000L + case$case_number * 10000L + replicate_id,
    message = message, runtime_fingerprint = fingerprint,
    elapsed_seconds = NA_real_,
    stringsAsFactors = FALSE
  )
}

run_replicate <- function(base_fit, case, replicate_id, cluster, fingerprint) {
  seed <- 1814000000L + case$case_number[[1L]] * 10000L + replicate_id
  redraw <- gllvmTMB:::.check_simulate_unconditional(base_fit)
  if (!isTRUE(redraw$can_redraw) || length(redraw$unhandled)) {
    return(failure_rows(
      case, replicate_id, "unconditional_redraw_unavailable",
      paste(redraw$unhandled, collapse = ","), cluster, fingerprint
    ))
  }
  simulated <- tryCatch(
    stats::simulate(
      base_fit, nsim = 1L, seed = seed, condition_on_RE = FALSE
    ),
    error = identity
  )
  if (inherits(simulated, "error")) {
    return(failure_rows(
      case, replicate_id, "simulate_error", conditionMessage(simulated),
      cluster, fingerprint, TRUE
    ))
  }
  y <- as.numeric(simulated[, 1L])
  if (length(y) != nrow(base_fit$data) || any(!is.finite(y))) {
    return(failure_rows(
      case, replicate_id, "simulate_nonfinite", "Invalid simulated response.",
      cluster, fingerprint, TRUE
    ))
  }
  data <- base_fit$data
  data$y <- y
  started <- proc.time()[[3L]]
  refit <- tryCatch(fit_mspl(data, case$link[[1L]]), error = identity)
  elapsed <- proc.time()[[3L]] - started
  if (inherits(refit, "error")) {
    out <- failure_rows(
      case, replicate_id, "refit_error", conditionMessage(refit),
      cluster, fingerprint, TRUE
    )
    out$elapsed_seconds <- elapsed
    return(out)
  }
  index <- which(names(refit$opt$par) == "b_fix")
  estimate <- as.numeric(refit$opt$par[index])
  active <- !is.null(refit$tmb_obj) &&
    !identical(refit$tmb_obj, refit$mspl$unpenalized_tmb_obj) &&
    identical(as.integer(refit$tmb_obj$env$data$estimator_id), 1L)
  status <- if (!identical(refit$opt$convergence, 0L)) {
    "refit_optimizer_failed"
  } else if (!active) {
    "penalised_objective_mismatch"
  } else if (length(index) != 3L ||
             !identical(as.character(refit$X_fix_names),
                        as.character(base_fit$X_fix_names))) {
    "target_alignment_failed"
  } else if (any(!is.finite(estimate))) {
    "estimate_nonfinite"
  } else {
    "ok"
  }
  out <- failure_rows(
    case, replicate_id, status,
    refit$opt$message %||% "", cluster, fingerprint, TRUE
  )
  out$convergence <- as.integer(refit$opt$convergence)
  out$objective <- as.numeric(refit$opt$objective)
  out$estimator_id <- if (active) 1L else NA_integer_
  out$elapsed_seconds <- elapsed
  if (identical(status, "ok")) {
    out$estimate <- estimate
    out$target_name <- as.character(refit$X_fix_names)
  }
  out
}

validate_receipts <- function(data, manifest) {
  expected <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    expand.grid(
      case_id = manifest$case_id[[i]],
      bootstrap_rep_id = seq_len(manifest$n_bootstrap[[i]]),
      target = seq_len(3L), stringsAsFactors = FALSE
    )
  }))
  key <- function(x) paste(
    x$case_id, x$bootstrap_rep_id, x$target, sep = "\r"
  )
  if (anyDuplicated(key(data)) || !setequal(key(data), key(expected)) ||
      nrow(data) != nrow(expected)) {
    stop("Raw receipt keys do not exactly match the frozen manifest.", call. = FALSE)
  }
  m <- match(data$case_id, manifest$case_id)
  fields <- c(
    "manifest_version", "campaign_id", "source_sha", "assigned_cluster"
  )
  observed_names <- c(
    "manifest_version", "campaign_id", "source_sha", "cluster"
  )
  mismatch <- vapply(seq_along(fields), function(i) {
    any(as.character(data[[observed_names[[i]]]]) !=
          as.character(manifest[[fields[[i]]]][m]))
  }, logical(1L))
  if (any(mismatch)) {
    stop("Raw receipt provenance does not match the frozen manifest.", call. = FALSE)
  }
  invisible(expected)
}

endpoint_mcse <- function(x, case_number, target, n_rep) {
  set.seed(1814990000L + as.integer(case_number) * 100L + as.integer(target))
  q <- replicate(n_rep, stats::quantile(
    sample(x, length(x), replace = TRUE), c(0.025, 0.975),
    type = 7L, names = FALSE
  ))
  apply(q, 1L, stats::sd)
}

summarise_receipts <- function(data, manifest) {
  validate_receipts(data, manifest)
  key <- interaction(data$case_id, data$target, drop = TRUE)
  out <- do.call(rbind, lapply(split(data, key), function(x) {
    case <- manifest[match(x$case_id[[1L]], manifest$case_id), , drop = FALSE]
    usable <- x$status == "ok" & x$convergence == 0L &
      x$estimator_id == 1L & is.finite(x$estimate)
    estimates <- x$estimate[usable]
    endpoints <- if (length(estimates)) stats::quantile(
      estimates, c(0.025, 0.975), type = 7L, names = FALSE
    ) else c(NA_real_, NA_real_)
    width <- diff(endpoints)
    mcse <- if (length(estimates) >= 2L) endpoint_mcse(
      estimates, case$case_number, x$target[[1L]], case$mcse_reps
    ) else c(NA_real_, NA_real_)
    status <- if (sum(usable) < case$minimum_usable) {
      "insufficient_usable"
    } else if (any(!is.finite(endpoints))) {
      "endpoints_nonfinite"
    } else if (!is.finite(width) || width <= 0) {
      "endpoints_unordered"
    } else if (any(!is.finite(mcse))) {
      "endpoint_mcse_nonfinite"
    } else if (any(mcse > 0.1 * width)) {
      "endpoint_mcse_unstable"
    } else {
      "finite_stable"
    }
    target_name <- if (any(usable)) {
      x$target_name[which(usable)[1L]]
    } else {
      sprintf("b_fix[%d]", x$target[[1L]])
    }
    data.frame(
      case_id = x$case_id[[1L]], regime = x$regime[[1L]],
      link = x$link[[1L]], target = x$target[[1L]],
      target_name = target_name,
      attempted = nrow(x), usable = sum(usable),
      usable_fraction = mean(usable), lower = endpoints[[1L]],
      upper = endpoints[[2L]], width = width,
      lower_mcse = mcse[[1L]], upper_mcse = mcse[[2L]],
      bootstrap_status = status,
      finite_stable = identical(status, "finite_stable"),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

command <- if (length(args)) args[[1L]] else ""
root <- arg_value("--root")
if (!nzchar(root %||% "")) {
  stop("Use --root <outside-repository-campaign-root>.", call. = FALSE)
}

if (identical(command, "prepare")) {
  campaign_id <- arg_value("--campaign-id")
  source_sha <- arg_value("--source-sha")
  if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) {
    stop("prepare requires --campaign-id and --source-sha.", call. = FALSE)
  }
  clusters <- strsplit(
    arg_value("--clusters", "fir,nibi,rorqual"), ",", fixed = TRUE
  )[[1L]]
  manifest <- manifest_table(
    n_bootstrap = as.integer(arg_value("--n-bootstrap", "1000")),
    shard_size = as.integer(arg_value("--shard-size", "100")),
    clusters = clusters, campaign_id = campaign_id, source_sha = source_sha,
    mcse_reps = as.integer(arg_value("--mcse-reps", "2000"))
  )
  if (any(manifest$n_bootstrap < 1L) || any(manifest$shard_size < 1L) ||
      any(manifest$n_bootstrap %% manifest$shard_size != 0L)) {
    stop("Bootstrap size must be a positive multiple of shard size.")
  }
  dir.create(file.path(root, "raw"), recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(manifest, file.path(root, "manifest.csv"))
  writeLines(c(
    "Private LA-MSPL endpoint-construction feasibility campaign.",
    "No calibrated SE, confidence-interval, or coverage claim is authorised.",
    "Every requested bootstrap attempt is retained; there are no replacement draws.",
    "Public MSPL inference remains fail-closed."
  ), file.path(root, "README.txt"))
} else if (identical(command, "smoke")) {
  if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
  manifest <- utils::read.csv(
    file.path(root, "manifest.csv"), stringsAsFactors = FALSE
  )
  cluster <- arg_value("--cluster", "local")
  if (any(manifest$n_bootstrap != 1L) || any(manifest$n_shards != 1L) ||
      any(manifest$assigned_cluster != cluster)) {
    stop("smoke requires a 12-case, one-replicate manifest assigned to one cluster.")
  }
  fingerprint <- runtime_fingerprint()
  for (i in seq_len(nrow(manifest))) {
    case <- manifest[i, , drop = FALSE]
    out_file <- file.path(
      root, "raw", sprintf("%s-shard-001.csv", case$case_id)
    )
    base_fit <- tryCatch(
      fit_mspl(fixture_data(case), case$link[[1L]]), error = identity
    )
    result <- if (inherits(base_fit, "error")) {
      failure_rows(
        case, 1L, "base_fit_error", conditionMessage(base_fit),
        cluster, fingerprint
      )
    } else {
      run_replicate(base_fit, case, 1L, cluster, fingerprint)
    }
    atomic_write_csv(result, out_file)
  }
} else if (identical(command, "run")) {
  if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) {
    devtools::load_all(quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
  manifest <- utils::read.csv(
    file.path(root, "manifest.csv"), stringsAsFactors = FALSE
  )
  case <- manifest[manifest$case_id == arg_value("--case-id"), , drop = FALSE]
  shard <- as.integer(arg_value("--shard-id"))
  cluster <- arg_value("--cluster", Sys.getenv("SLURM_CLUSTER_NAME", "local"))
  if (nrow(case) != 1L || is.na(shard) || shard < 1L ||
      shard > case$n_shards[[1L]]) stop("Unknown case or shard.")
  if (!identical(cluster, case$assigned_cluster[[1L]])) {
    stop("Requested cluster does not match the frozen manifest assignment.")
  }
  out_file <- file.path(
    root, "raw", sprintf("%s-shard-%03d.csv", case$case_id, shard)
  )
  if (file.exists(out_file)) quit(save = "no", status = 0L)
  base_fit <- tryCatch(
    fit_mspl(fixture_data(case), case$link[[1L]]), error = identity
  )
  fingerprint <- runtime_fingerprint()
  first <- (shard - 1L) * case$shard_size[[1L]] + 1L
  last <- min(shard * case$shard_size[[1L]], case$n_bootstrap[[1L]])
  if (inherits(base_fit, "error")) {
    result <- do.call(rbind, lapply(first:last, function(rep) failure_rows(
      case, rep, "base_fit_error", conditionMessage(base_fit),
      cluster, fingerprint
    )))
  } else {
    result <- do.call(rbind, lapply(first:last, function(rep) {
      run_replicate(base_fit, case, rep, cluster, fingerprint)
    }))
  }
  if (nrow(result) != 3L * (last - first + 1L)) {
    stop("Refusing to publish an incomplete shard.")
  }
  atomic_write_csv(result, out_file)
} else if (identical(command, "summarise")) {
  manifest <- utils::read.csv(
    file.path(root, "manifest.csv"), stringsAsFactors = FALSE
  )
  files <- list.files(
    file.path(root, "raw"), pattern = "\\.csv$", full.names = TRUE
  )
  if (!length(files)) stop("No raw shards.")
  data <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
  summary <- summarise_receipts(data, manifest)
  if (all(manifest$n_bootstrap == 1000L) && nrow(data) != 36000L) {
    stop("Production receipt must contain exactly 36,000 target rows.")
  }
  atomic_write_csv(summary, file.path(root, "summary.csv"))
  failures <- as.data.frame(table(
    case_id = data$case_id, status = data$status
  ), stringsAsFactors = FALSE)
  failures <- failures[failures$Freq > 0L, , drop = FALSE]
  atomic_write_csv(failures, file.path(root, "failure-counts.csv"))
  writeLines(c(
    paste("raw_rows:", nrow(data)),
    paste("summary_rows:", nrow(summary)),
    paste("finite_stable:", sum(summary$finite_stable)),
    paste("public_fence: unchanged")
  ), file.path(root, "receipt.txt"))
} else {
  stop("Use prepare, smoke, run, or summarise.", call. = FALSE)
}
