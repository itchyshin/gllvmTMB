#!/usr/bin/env Rscript

## Research-only, resumable R3/R4/R5 pilot runner for Design 85.
## One process handles a contiguous seed range so the standalone VA template
## is compiled once and reused. Outputs are local RDS receipts, never Actions
## artifacts and never a user-facing fitting surface.

options(warn = 1)

if (!exists(".va_r3_fit", mode = "function")) {
  source_file <- file.path("R", "va-r3-proto.R")
  if (file.exists(source_file)) {
    sys.source(source_file, envir = .GlobalEnv)
  } else {
    .va_r3_fit <- getFromNamespace(".va_r3_fit", "gllvmTMB")
  }
}

parse_args <- function(x) {
  out <- list(cell = NULL, seed_start = NULL, seed_end = NULL, output = NULL)
  for (arg in x) {
    piece <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    if (length(piece) != 2L || !piece[1L] %in% names(out)) {
      stop("Arguments must be --cell=, --seed_start=, --seed_end=, --output=.")
    }
    out[[piece[1L]]] <- piece[2L]
  }
  if (any(vapply(out, is.null, logical(1)))) stop("All four arguments are required.")
  out$seed_start <- as.integer(out$seed_start)
  out$seed_end <- as.integer(out$seed_end)
  if (!out$cell %in% c("q1", "q2", "q4", "q6") ||
      is.na(out$seed_start) || is.na(out$seed_end) ||
      out$seed_start < 1L || out$seed_end < out$seed_start) {
    stop("Invalid cell or seed range.")
  }
  out
}

frob_relative <- function(estimate, truth) {
  sqrt(sum((estimate - truth)^2)) / sqrt(sum(truth^2))
}

make_dgp <- function(cell, seed) {
  q <- as.integer(sub("q", "", cell, fixed = TRUE))
  N <- if (q <= 2L) 60L else 80L
  T <- max(q + 2L, 4L)
  n_trials <- 12L
  set.seed(850000L + q * 10000L + seed)
  Lambda <- matrix(0, T, q)
  for (j in seq_len(q)) {
    Lambda[j, j] <- 0.78 + 0.04 * j
    if (j < T) {
      rows <- seq.int(j + 1L, T)
      Lambda[rows, j] <- 0.30 * sin(rows + 1.7 * j)
    }
  }
  beta <- seq(-0.45, 0.45, length.out = T)
  score <- matrix(stats::rnorm(N * q), N, q)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  eta <- drop(X %*% beta) + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  probability <- stats::plogis(eta)
  y <- stats::rbinom(N * T, n_trials, probability)
  y_replicate <- stats::rbinom(N * T, n_trials, probability)
  data <- data.frame(
    succ = y, fail = n_trials - y,
    trait = factor(sprintf("t%02d", trait)),
    unit = factor(sprintf("u%03d", unit))
  )
  list(q = q, N = N, T = T, trials = rep.int(n_trials, N * T),
       y = y, y_replicate = y_replicate, unit = unit, trait = trait,
       X = X, data = data, beta = beta, Lambda = Lambda,
       Sigma = tcrossprod(Lambda), probability = probability)
}

ml_formula <- function(q) {
  if (q == 0L) return(cbind(succ, fail) ~ 0 + trait)
  stats::as.formula(paste0(
    "cbind(succ, fail) ~ 0 + trait + ",
    "latent(0 + trait | unit, d = ", q, ", unique = FALSE)"
  ))
}

fit_ml <- function(dgp, q) {
  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      ml_formula(q), data = dgp$data, family = stats::binomial(), unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)
    ))),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(fit, "error")) {
    return(list(q = q, healthy = FALSE, elapsed = elapsed,
                error = conditionMessage(fit)))
  }
  gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
  max_gradient <- if (all(is.finite(gradient))) max(abs(gradient)) else Inf
  healthy <- identical(fit$opt$convergence, 0L) &&
    is.finite(fit$opt$objective) && max_gradient < 1e-3
  list(q = q, healthy = healthy, elapsed = elapsed, fit = fit,
       convergence = fit$opt$convergence, objective = fit$opt$objective,
       max_gradient = max_gradient,
       BIC = if (healthy) unname(stats::BIC(fit)) else Inf,
       pd_hessian = isTRUE(fit$fit_health$pd_hessian))
}

select_ml_rank <- function(candidates) {
  healthy <- Filter(function(x) isTRUE(x$healthy), candidates)
  if (!length(healthy)) return(NA_integer_)
  best <- min(vapply(healthy, `[[`, numeric(1), "BIC"))
  eligible <- Filter(function(x) x$BIC <= best + 2, healthy)
  min(vapply(eligible, `[[`, integer(1), "q"))
}

predictive_scores <- function(y, trials, p) {
  p <- pmin(pmax(as.numeric(p), 1e-12), 1 - 1e-12)
  list(
    negative_log_score = mean(-(y * log(p) + (trials - y) * log1p(-p))),
    squared_error = mean((y / trials - p)^2)
  )
}

va_probability <- function(report, rule) {
  vapply(seq_along(report$mu_by_obs), function(i) {
    sum(rule$weights * stats::plogis(
      report$mu_by_obs[i] + sqrt(2 * report$v_by_obs[i]) * rule$nodes
    )) / sqrt(pi)
  }, numeric(1))
}

summarise_method <- function(method, fit, dgp) {
  if (method == "ML") {
    if (!isTRUE(fit$healthy) || fit$q == 0L) return(NULL)
    object <- fit$fit
    Lambda <- object$report$Lambda_B
    beta <- unname(object$tmb_obj$env$last.par.best[
      names(object$tmb_obj$env$last.par.best) == "b_fix"
    ])
    probability <- as.numeric(stats::predict(object, type = "response")$est)
    elapsed <- fit$elapsed
    gradient <- fit$max_gradient
    healthy <- fit$healthy
  } else {
    object <- fit
    if (is.null(object) || !identical(object$status, "healthy")) return(NULL)
    Lambda <- object$report$Lambda
    beta <- unname(object$best$par[names(object$best$par) == "beta"])
    probability <- va_probability(object$report, object$quadrature)
    elapsed <- object$elapsed
    gradient <- object$best$max_abs_gradient
    healthy <- identical(object$status, "healthy")
  }
  scores <- predictive_scores(dgp$y_replicate, dgp$trials, probability)
  singular <- svd(Lambda, nu = 0L, nv = 0L)$d
  truth_singular <- svd(dgp$Lambda, nu = 0L, nv = 0L)$d
  rank_matches_truth <- ncol(Lambda) == ncol(dgp$Lambda)
  list(
    healthy = healthy, elapsed = elapsed, max_gradient = gradient,
    beta_rmse = sqrt(mean((beta - dgp$beta)^2)),
    sigma_relative_error = frob_relative(tcrossprod(Lambda), dgp$Sigma),
    rank_matches_truth = rank_matches_truth,
    axis_collapsed = if (rank_matches_truth) {
      min(singular) < 0.1 * min(truth_singular)
    } else {
      NA
    },
    negative_log_score = scores$negative_log_score,
    squared_error = scores$squared_error
  )
}

run_seed <- function(cell, seed) {
  dgp <- make_dgp(cell, seed)
  reference_cell <- dgp$q <= 2L
  candidate_q <- if (reference_cell) 0:min(3L, dgp$q + 1L) else dgp$q
  ml_candidates <- lapply(candidate_q, function(q) fit_ml(dgp, q))
  selected_q <- if (reference_cell) select_ml_rank(ml_candidates) else dgp$q
  selected_ml <- if (!is.na(selected_q)) {
    ml_candidates[[which(vapply(ml_candidates, `[[`, integer(1), "q") == selected_q)]]
  } else NULL

  va <- NULL
  va_ladder <- NULL
  if (!is.na(selected_q) && selected_q > 0L && isTRUE(selected_ml$healthy)) {
    started <- proc.time()[["elapsed"]]
    prototype_source <- normalizePath(
      file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"), mustWork = TRUE
    )
    va <- .va_r3_fit(
      dgp$y, dgp$trials, dgp$X, dgp$unit, dgp$trait, selected_q,
      H = 61L,
      rank_source = if (reference_cell) "ml_bic" else "fixed_fixture",
      source = prototype_source,
      control = list(eval.max = 2000L, iter.max = 2000L)
    )
    va$elapsed <- proc.time()[["elapsed"]] - started
    if (!is.null(va$best) && !is.null(va$report)) {
      validated <- .va_r3_validate_data(
        dgp$y, dgp$trials, dgp$X, dgp$unit, dgp$trait, selected_q
      )
      ladder <- lapply(c(15L, 25L), function(H) {
        obj <- .va_r3_make_objective(
          validated, H = H,
          parameters = .va_r3_default_parameters(validated, 1L)
        )
        report <- obj$report(va$best$par)
        list(H = H, objective = obj$fn(va$best$par),
             expected_loglik_by_obs = report$expected_loglik_by_obs)
      })
      va_ladder <- list(
        H15_objective = ladder[[1L]]$objective,
        H25_objective = ladder[[2L]]$objective,
        H61_objective = va$report$negative_elbo,
        H25_H61_total = abs(ladder[[2L]]$objective - va$report$negative_elbo),
        H25_H61_max_per_observation = max(abs(
          ladder[[2L]]$expected_loglik_by_obs - va$report$expected_loglik_by_obs
        ))
      )
    }
  }

  va_diagnostics <- if (is.null(va)) NULL else list(
    status = va$status, elapsed = va$elapsed, health = va$health,
    source_commit = va$source_commit, source_checksum = va$source_checksum,
    rank_source = va$rank_source, quadrature_order = va$quadrature$order,
    starts = lapply(va$starts, function(x) x[setdiff(names(x), "par")]),
    ladder = va_ladder
  )

  list(
    schema = "va_r3_pilot_v1", cell = cell, seed = seed,
    attempted = TRUE, generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    git_commit = tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
                          error = function(e) NA_character_),
    platform = list(host = Sys.info()[["nodename"]], R = R.version.string,
                    os = Sys.info()[["sysname"]]),
    dgp = dgp[c("q", "N", "T", "beta", "Lambda", "Sigma")],
    candidate_q = candidate_q, selected_q = selected_q,
    ml_candidates = lapply(ml_candidates, function(x) x[setdiff(names(x), "fit")]),
    ml = summarise_method("ML", selected_ml, dgp),
    va = summarise_method("VA", va, dgp),
    va_diagnostics = va_diagnostics,
    va_status = if (is.na(selected_q)) "not_run_no_healthy_ml" else if (selected_q == 0L) {
      "not_applicable_rank_zero"
    } else if (is.null(va)) "not_run_unhealthy_ml" else va$status
  )
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
dir.create(args$output, recursive = TRUE, showWarnings = FALSE)
for (seed in seq.int(args$seed_start, args$seed_end)) {
  destination <- file.path(args$output, sprintf("%s_seed_%05d.rds", args$cell, seed))
  if (file.exists(destination)) next
  receipt <- tryCatch(run_seed(args$cell, seed), error = function(e) list(
    schema = "va_r3_pilot_v1", cell = args$cell, seed = seed,
    attempted = TRUE, va_status = "runner_error", error = conditionMessage(e),
    generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ))
  temporary <- paste0(destination, ".tmp-", Sys.getpid())
  saveRDS(receipt, temporary)
  if (!file.rename(temporary, destination)) stop("Atomic receipt rename failed: ", destination)
  message(args$cell, " seed ", seed, ": ", receipt$va_status)
}
