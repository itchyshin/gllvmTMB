#!/usr/bin/env Rscript
# Research-only VA-R3 variance-domain campaign.  This is deliberately not a
# package test or a public fitting interface.  It uses multi-trial binomial
# data only (n_trials = 12) and retains every optimisation/truth attempt.

va_gate_abort <- function(...) stop(..., call. = FALSE)

va_gate_root <- function(path = getwd()) {
  path <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "R", "va-r3-proto.R")) &&
        file.exists(file.path(path, "inst", "tmb", "gllvmTMB_va_r3.cpp"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  va_gate_abort("Run inside a worktree containing R/va-r3-proto.R and inst/tmb/gllvmTMB_va_r3.cpp.")
}

va_gate_config <- function() {
  list(
    campaign_id = "va-r3-variance-domain-20260726",
    q = 2L,
    N = 10L,
    T = 2L,
    n_trials = 12L,
    beta = c(-2.2, -2.6),
    calibration_receipt = "dev/va-variance-gate/calibration-receipts/2026-07-26-post-calibration-cell-map.md",
    campaign_cells = list(
      `4` = list(nominal_prior_target = 12, seed = 2026074012L,
                 expected_observed_max_projected_variance = 4.614,
                 observed_variance_band = c(3, 6)),
      `6` = list(nominal_prior_target = 50, seed = 2026074050L,
                 expected_observed_max_projected_variance = 5.988,
                 observed_variance_band = c(5, 7)),
      `10` = list(nominal_prior_target = 55, seed = 2026074055L,
                  expected_observed_max_projected_variance = 8.674,
                  observed_variance_band = c(8, 12)),
      `20` = list(nominal_prior_target = 45, seed = 2026074045L,
                  expected_observed_max_projected_variance = 22.191,
                  observed_variance_band = c(18, 24))
    ),
    va_H_ladder = c(15L, 25L, 61L),
    truth_H_ladder = c(151L, 301L, 501L, 801L),
    truth_tail_tolerance = 1e-3,
    fit_control = list(eval.max = 2000L, iter.max = 2000L),
    fixture_rule = "q=2; binomial-logit; n_trials=12; complete N by T cells; no Bernoulli"
  )
}

va_gate_logspace_add <- function(x) {
  if (!length(x) || anyNA(x)) return(NA_real_)
  top <- max(x)
  if (!is.finite(top)) return(top)
  top + log(sum(exp(x - top)))
}

va_gate_softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

## Generic physicists' Hermite rule for the independent *truth* evaluator.
## Squared first eigenvector entries are normalized N(0, 1) weights after
## x -> sqrt(2) x.  Unlike .va_r3_gh_rule(), this accepts the truth ladder.
va_gate_normal_gh <- function(H) {
  H <- as.integer(H)
  if (length(H) != 1L || is.na(H) || H < 2L) {
    va_gate_abort("Truth quadrature order H must be one integer >= 2.")
  }
  J <- matrix(0, H, H)
  off <- sqrt(seq_len(H - 1L) / 2)
  J[cbind(seq_len(H - 1L), 2:H)] <- off
  J[cbind(2:H, seq_len(H - 1L))] <- off
  ee <- eigen(J, symmetric = TRUE)
  ord <- order(ee$values)
  weights <- ee$vectors[1L, ord]^2
  weights <- weights / sum(weights)
  list(H = H, z = sqrt(2) * unname(ee$values[ord]), log_weight = log(weights))
}

va_gate_fixture <- function(nominal_prior_target, seed, config = va_gate_config()) {
  nominal_prior_target <- as.numeric(nominal_prior_target)
  if (length(nominal_prior_target) != 1L || !is.finite(nominal_prior_target) || nominal_prior_target <= 0) {
    va_gate_abort("nominal_prior_target must be one positive finite projected-variance level.")
  }
  set.seed(as.integer(seed))
  ## Lower-triangular q = T = 2 loading matrix.  Each row has squared norm
  ## exactly nominal_prior_target, which labels the DGP's prior max projected variance.
  cross <- 0.25
  Lambda <- rbind(
    c(sqrt(nominal_prior_target), 0),
    c(cross * sqrt(nominal_prior_target), sqrt((1 - cross^2) * nominal_prior_target))
  )
  u <- matrix(stats::rnorm(config$N * config$q), ncol = config$q)
  unit_id <- rep(seq_len(config$N), each = config$T)
  trait_id <- rep(seq_len(config$T), times = config$N)
  eta <- config$beta[trait_id] + rowSums(u[unit_id, , drop = FALSE] *
                                           Lambda[trait_id, , drop = FALSE])
  n_trials <- rep.int(config$n_trials, config$N * config$T)
  y <- stats::rbinom(length(eta), size = n_trials, prob = stats::plogis(eta))
  list(
    y = as.integer(y), n_trials = as.integer(n_trials),
    X = stats::model.matrix(~ 0 + factor(trait_id)),
    unit_id = as.integer(unit_id), trait_id = as.integer(trait_id),
    q = config$q, N = config$N, T = config$T,
    family = "binomial", link = "logit",
    nominal_prior_target = nominal_prior_target,
    seed = as.integer(seed), beta_true = config$beta, Lambda_true = Lambda
  )
}

va_gate_validate_fixture <- function(fixture) {
  if (any(fixture$n_trials < 2L) || any(fixture$n_trials == 1L)) {
    va_gate_abort("Scope violation: this campaign is multi-trial binomial only.")
  }
  if (!identical(as.integer(fixture$q), 2L)) {
    va_gate_abort("The truth evaluator is deliberately restricted to q = 2.")
  }
  invisible(fixture)
}

## Evaluate log p(y | beta, Lambda) with independent product GH, integrating
## each unit's two latent coordinates.  It never uses AGHQ or a Laplace value.
va_gate_truth_one <- function(validated, beta, Lambda, H) {
  if (validated$q != 2L || ncol(Lambda) != 2L || nrow(Lambda) != validated$T) {
    va_gate_abort("Truth evaluator requires a finite T by 2 loading matrix.")
  }
  if (length(beta) != ncol(validated$X) || any(!is.finite(beta)) ||
      any(!is.finite(Lambda))) {
    va_gate_abort("Truth evaluator received non-finite fixed global coordinates.")
  }
  gh <- va_gate_normal_gh(H)
  z1 <- rep(gh$z, each = length(gh$z))
  z2 <- rep(gh$z, times = length(gh$z))
  logw <- rep(gh$log_weight, each = length(gh$log_weight)) +
    rep(gh$log_weight, times = length(gh$log_weight))
  total <- 0
  for (i in seq_len(validated$N)) {
    rows <- which(validated$unit_id == i - 1L)
    traits <- validated$trait_id[rows] + 1L
    eta <- tcrossprod(z1, Lambda[traits, 1L]) +
      tcrossprod(z2, Lambda[traits, 2L]) +
      matrix(as.numeric(validated$X[rows, , drop = FALSE] %*% beta),
             nrow = length(z1), ncol = length(rows), byrow = TRUE)
    y <- validated$y[rows]
    n <- validated$n_trials[rows]
    log_choose <- lgamma(n + 1) - lgamma(y + 1) - lgamma(n - y + 1)
    log_integrand <- rowSums(sweep(eta, 2L, y, `*`) -
                               sweep(va_gate_softplus(eta), 2L, n, `*`)) +
      sum(log_choose)
    unit_loglik <- va_gate_logspace_add(logw + log_integrand)
    if (!is.finite(unit_loglik)) va_gate_abort("Non-finite truth integral at unit ", i, ".")
    total <- total + unit_loglik
  }
  unname(total)
}

va_gate_truth_ladder <- function(validated, beta, Lambda, config) {
  attempts <- lapply(config$truth_H_ladder, function(H) {
    tryCatch(list(H = H, value = va_gate_truth_one(validated, beta, Lambda, H),
                  error = NA_character_),
             error = function(e) list(H = H, value = NA_real_, error = conditionMessage(e)))
  })
  values <- vapply(attempts, `[[`, numeric(1), "value")
  names(values) <- paste0("H", config$truth_H_ladder)
  finite <- all(is.finite(values))
  full_spread <- if (finite) diff(range(values)) else Inf
  tail_spread <- if (finite) abs(values[length(values)] - values[length(values) - 1L]) else Inf
  stable <- finite && tail_spread <= config$truth_tail_tolerance
  list(
    classification = if (stable) "stable" else "uninterpretable",
    reason = if (stable) {
      "H501-to-H801 tail difference is within the predeclared tolerance."
    } else if (!finite) {
      "At least one fixed-coordinate truth integral was non-finite or errored."
    } else {
      "H501-to-H801 tail difference exceeds the predeclared truth tolerance."
    },
    values = values, attempts = attempts, full_ladder_spread = full_spread,
    tail_spread = tail_spread, tail_tolerance = config$truth_tail_tolerance
  )
}

va_gate_fixed_elbo_ladder <- function(fit, validated, source, config) {
  if (is.null(fit$best) || is.null(fit$objective) || is.null(fit$best$par)) {
    return(list(classification = "unavailable", attempts = list(), values = numeric()))
  }
  parameters <- fit$objective$env$parList(fit$best$par)
  attempts <- lapply(config$va_H_ladder, function(H) {
    tryCatch({
      obj <- .va_r3_make_objective(validated, H = H, source = source,
                                    parameters = parameters, rebuild = FALSE,
                                    silent = TRUE)
      list(H = H, elbo = -obj$fn(obj$par), error = NA_character_)
    }, error = function(e) list(H = H, elbo = NA_real_, error = conditionMessage(e)))
  })
  values <- vapply(attempts, `[[`, numeric(1), "elbo")
  names(values) <- paste0("H", config$va_H_ladder)
  list(classification = if (all(is.finite(values))) "complete" else "incomplete",
       attempts = attempts, values = values,
       spread = if (all(is.finite(values))) diff(range(values)) else Inf)
}

va_gate_one_cell <- function(observed_band, cell, config, source) {
  nominal_prior_target <- cell$nominal_prior_target
  seed <- cell$seed
  fixture <- va_gate_fixture(nominal_prior_target, seed, config)
  va_gate_validate_fixture(fixture)
  validated <- do.call(.va_r3_validate_data, fixture[c(
    "y", "n_trials", "X", "unit_id", "trait_id", "q", "N", "T", "family", "link"
  )])
  fit <- tryCatch(
    .va_r3_fit(y = fixture$y, n_trials = fixture$n_trials, X = fixture$X,
               unit_id = fixture$unit_id, trait_id = fixture$trait_id,
               q = fixture$q, N = fixture$N, T = fixture$T,
               family = "binomial", link = "logit", H = 61L,
               source = source, control = config$fit_control, silent = TRUE),
    error = function(e) structure(list(error = conditionMessage(e)), class = "va_gate_fit_error")
  )
  if (inherits(fit, "va_gate_fit_error")) {
    return(list(observed_band = observed_band, nominal_prior_target = nominal_prior_target,
                seed = seed, expected_observed_max_projected_variance = cell$expected_observed_max_projected_variance,
                observed_variance_band = cell$observed_variance_band,
                selection_receipt_path = config$calibration_receipt, fixture = fixture,
                classification = "uninterpretable_fit_error", fit_error = fit$error,
                optimizer_attempts = list(), fixed_elbo = list(), truth = list()))
  }
  fixed_elbo <- va_gate_fixed_elbo_ladder(fit, validated, source, config)
  truth <- list(classification = "uninterpretable_no_fixed_global", attempts = list())
  gap <- NA_real_
  if (!is.null(fit$best) && !is.null(fit$objective) && !is.null(fit$best$par)) {
    fixed <- fit$objective$env$parList(fit$best$par)
    Lambda <- .va_r3_unpack_theta_rr(fixed$theta_rr, validated$T, validated$q)
    truth <- va_gate_truth_ladder(validated, fixed$beta, Lambda, config)
    if (identical(truth$classification, "stable") &&
        is.finite(fixed_elbo$values[["H61"]])) {
      gap <- unname(fixed_elbo$values[["H61"]] - tail(truth$values, 1L))
    }
  }
  list(
    observed_band = observed_band, nominal_prior_target = nominal_prior_target,
    seed = seed, expected_observed_max_projected_variance = cell$expected_observed_max_projected_variance,
    observed_variance_band = cell$observed_variance_band,
    selection_receipt_path = config$calibration_receipt, fixture = fixture,
    observed_max_projected_variance = fit$health$max_projected_variance,
    fit_status = fit$status, fit_health = fit$health,
    optimizer_attempts = fit$starts, fixed_elbo = fixed_elbo, truth = truth,
    elbo_minus_truth = gap,
    classification = if (identical(truth$classification, "stable")) {
      "truth_stable"
    } else {
      "truth_uninterpretable"
    }
  )
}

va_gate_manifest <- function(root, source, config) {
  files <- c(file.path(root, "R", "va-r3-proto.R"), source,
             file.path(root, "dev", "va-variance-gate", "run-va-variance-gate.R"))
  calibration_receipt <- file.path(root, config$calibration_receipt)
  list(
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    git_head = system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE),
    source_files = stats::setNames(unname(tools::md5sum(files)), files),
    calibration_receipt_sha256 = unname(tools::sha256sum(calibration_receipt)),
    config = config,
    R = R.version.string,
    TMB = if (requireNamespace("TMB", quietly = TRUE)) as.character(utils::packageVersion("TMB")) else NA_character_
  )
}

va_gate_parse_args <- function(args) {
  out <- list(mode = "smoke", output = NULL, observed_bands = NULL)
  for (arg in args) {
    if (identical(arg, "--smoke")) out$mode <- "smoke"
    else if (identical(arg, "--campaign")) out$mode <- "campaign"
    else if (startsWith(arg, "--out=")) out$output <- sub("^--out=", "", arg)
    else if (startsWith(arg, "--observed-bands=")) out$observed_bands <- as.character(strsplit(sub("^--observed-bands=", "", arg), ",", fixed = TRUE)[[1L]])
    else va_gate_abort("Unknown argument: ", arg)
  }
  out
}

va_gate_run <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- va_gate_parse_args(args)
  root <- va_gate_root()
  source <- file.path(root, "inst", "tmb", "gllvmTMB_va_r3.cpp")
  sys.source(file.path(root, "R", "va-r3-proto.R"), envir = globalenv())
  config <- va_gate_config()
  observed_bands <- if (!is.null(options$observed_bands)) options$observed_bands else names(config$campaign_cells)
  if (identical(options$mode, "smoke")) observed_bands <- observed_bands[1L]
  if (!all(observed_bands %in% names(config$campaign_cells))) {
    va_gate_abort("observed_bands must be drawn from the frozen set: 4, 6, 10, 20.")
  }
  output <- options$output %||% file.path(root, "dev", "va-variance-gate", "results",
                                           paste0(options$mode, "-", format(Sys.time(), "%Y%m%d-%H%M%S")))
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  manifest <- va_gate_manifest(root, source, config)
  saveRDS(manifest, file.path(output, "source-manifest.rds"))
  results <- lapply(observed_bands, function(observed_band) {
    va_gate_one_cell(as.numeric(observed_band), config$campaign_cells[[observed_band]], config, source)
  })
  names(results) <- paste0("observed_band_", observed_bands)
  saveRDS(results, file.path(output, "attempts-and-results.rds"))
  summary <- data.frame(
    observed_band = vapply(results, `[[`, numeric(1), "observed_band"),
    nominal_prior_target = vapply(results, `[[`, numeric(1), "nominal_prior_target"),
    seed = vapply(results, `[[`, integer(1), "seed"),
    expected_observed_max_projected_variance = vapply(results, `[[`, numeric(1), "expected_observed_max_projected_variance"),
    selection_receipt_path = vapply(results, `[[`, character(1), "selection_receipt_path"),
    observed_max_projected_variance = vapply(results, function(x) x$observed_max_projected_variance %||% NA_real_, numeric(1)),
    fit_status = vapply(results, function(x) x$fit_status %||% NA_character_, character(1)),
    truth_classification = vapply(results, function(x) x$truth$classification %||% NA_character_, character(1)),
    truth_full_ladder_spread = vapply(results, function(x) x$truth$full_ladder_spread %||% NA_real_, numeric(1)),
    truth_tail_spread = vapply(results, function(x) x$truth$tail_spread %||% NA_real_, numeric(1)),
    elbo_minus_truth = vapply(results, function(x) x$elbo_minus_truth %||% NA_real_, numeric(1))
  )
  summary$observed_band_hit <- vapply(seq_len(nrow(summary)), function(i) {
    observed <- summary$observed_max_projected_variance[[i]]
    band <- results[[i]]$observed_variance_band
    if (!is.finite(observed)) return(NA)
    observed >= band[[1L]] && observed <= band[[2L]]
  }, logical(1))
  gate_conclusion <- if (identical(options$mode, "campaign") &&
      !all(summary$observed_band_hit %in% TRUE)) {
    list(status = "WITHHELD", reason = paste0(
      "No variance-domain gate conclusion: at least one requested calibrated finite-fixture cell ",
      "missed its predeclared observed projected-variance band."
    ))
  } else {
    list(status = "NOT_REPORTED", reason =
      "This runner reports retained numerical measurements; interpretation remains a maintainer decision.")
  }
  utils::write.csv(summary, file.path(output, "summary.csv"), row.names = FALSE)
  saveRDS(list(manifest = manifest, summary = summary, gate_conclusion = gate_conclusion,
               results = results),
          file.path(output, "campaign.rds"))
  print(summary, row.names = FALSE)
  message("Gate conclusion: ", gate_conclusion$status, " — ", gate_conclusion$reason)
  invisible(list(output = output, manifest = manifest, summary = summary,
                 gate_conclusion = gate_conclusion, results = results))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

if (sys.nframe() == 0L && !interactive()) va_gate_run()
