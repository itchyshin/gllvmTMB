## dev/lv-wald-coverage.R
## ======================
## Design 73 native TMB Wald-coverage campaign harness.
##
## This is a dev-only simulation runner. It is intentionally not exported
## and is excluded from the package tarball through `.Rbuildignore`.
##
## Scope:
##   - ordinary unit-tier Gaussian `latent(..., lv = ~ x)`;
##   - ordinary unit-tier pure-binomial logit/probit/cloglog
##     `latent(..., unique = FALSE, lv = ~ x)`;
##   - target `B_lv = Lambda %*% t(alpha)`;
##   - Wald intervals from `ADREPORT(B_lv_unit)` SEs;
##   - normal-critical Wald and unit-df t-critical Wald comparators.
##
## The harness records failed-fit denominators and Monte Carlo standard
## errors. A smoke run from this file is not coverage calibration evidence;
## production admission still needs >= 500 reps/cell.
## The t-critical comparator is a small-N candidate, not an inferential claim.
##
## Examples:
##   source("dev/lv-wald-coverage.R")
##   plan <- lv_wald_coverage_grid(n_reps = 500L, seed_base = 20260628L)
##   res <- lv_wald_coverage_run_cell("gaussian-d1-n72-t3", n_reps = 2L)
##   lv_wald_coverage_summarise(res)
##
## CLI examples:
##   GLLVMTMB_LV_WALD_COVERAGE_CLI=true Rscript dev/lv-wald-coverage.R \
##     --mode=preflight --results-dir=/tmp/lv-wald
##   GLLVMTMB_LV_WALD_COVERAGE_CLI=true Rscript dev/lv-wald-coverage.R \
##     --mode=task --task-id=${SLURM_ARRAY_TASK_ID} \
##     --results-dir=/project/<account>/gllvmtmb-lv-wald

LV_WALD_DEFAULT_N_REPS <- 500L
LV_WALD_DEFAULT_SEED_BASE <- 20260628L
LV_WALD_NOMINAL <- 0.95
LV_WALD_PASS_LO <- 0.92
LV_WALD_PASS_HI <- 0.98
LV_WALD_INTERVAL_METHODS <- c("wald_z", "wald_t_unit")

LV_WALD_CELLS <- data.frame(
  cell_id = c(
    "gaussian-d1-n72-t3",
    "gaussian-d1-n144-t3",
    "gaussian-d2-n96-t4",
    "gaussian-d2-n160-t4",
    "binomial-logit-d1-n160-t3",
    "binomial-probit-d1-n160-t3",
    "binomial-cloglog-d1-n160-t3"
  ),
  family = c(
    rep("gaussian", 4L),
    rep("binomial", 3L)
  ),
  link = c(
    rep(NA_character_, 4L),
    "logit",
    "probit",
    "cloglog"
  ),
  n_trials = c(rep(NA_integer_, 4L), rep(18L, 3L)),
  d = c(1L, 1L, 2L, 2L, 1L, 1L, 1L),
  n_units = c(72L, 144L, 96L, 160L, 160L, 160L, 160L),
  n_traits = c(3L, 3L, 4L, 4L, 3L, 3L, 3L),
  predictor = "x",
  stringsAsFactors = FALSE
)

lv_wald_null <- function(x, y) {
  if (is.null(x)) y else x
}

`%||%` <- lv_wald_null

lv_wald_cell <- function(cell_id, cells = LV_WALD_CELLS) {
  idx <- match(cell_id, cells$cell_id)
  if (is.na(idx)) {
    stop(
      "Unknown LV Wald coverage cell: ",
      cell_id,
      ". Known cells: ",
      paste(cells$cell_id, collapse = ", ")
    )
  }
  cells[idx, , drop = FALSE]
}

lv_wald_ensure_package <- function() {
  if (requireNamespace("gllvmTMB", quietly = TRUE)) {
    return(invisible(TRUE))
  }
  if (
    requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")
  ) {
    pkgload::load_all(".", quiet = TRUE)
    return(invisible(TRUE))
  }
  stop(
    "dev/lv-wald-coverage.R requires gllvmTMB to be installed, ",
    "or must be run from a source checkout with pkgload available."
  )
}

lv_wald_cell_seeds <- function(cell, n_reps, seed_base, cell_index) {
  set.seed(as.integer(seed_base) + 1009L * as.integer(cell_index))
  sample.int(.Machine$integer.max, as.integer(n_reps))
}

lv_wald_coverage_grid <- function(
  n_reps = LV_WALD_DEFAULT_N_REPS,
  seed_base = LV_WALD_DEFAULT_SEED_BASE,
  cells = LV_WALD_CELLS
) {
  n_reps <- as.integer(n_reps)
  if (length(n_reps) != 1L || is.na(n_reps) || n_reps < 1L) {
    stop("n_reps must be a positive integer")
  }
  rows <- vector("list", nrow(cells))
  task_offset <- 0L
  for (i in seq_len(nrow(cells))) {
    cell <- cells[i, , drop = FALSE]
    rep_seed <- lv_wald_cell_seeds(cell, n_reps, seed_base, cell_index = i)
    rows[[i]] <- data.frame(
      task_id = task_offset + seq_len(n_reps),
      cell_id = cell$cell_id,
      family = cell$family,
      link = cell$link,
      d = cell$d,
      n_trials = cell$n_trials,
      n_units = cell$n_units,
      n_traits = cell$n_traits,
      predictor = cell$predictor,
      rep = seq_len(n_reps),
      rep_seed = rep_seed,
      seed_base = as.integer(seed_base),
      stringsAsFactors = FALSE
    )
    task_offset <- task_offset + n_reps
  }
  do.call(rbind, rows)
}

lv_wald_coverage_data <- function(
  n_units,
  n_traits,
  d,
  seed,
  predictor = "x",
  family = "gaussian",
  link = NA_character_,
  n_trials = NA_integer_
) {
  if (n_traits > 4L) {
    stop("lv_wald_coverage_data() currently defines truths for <= 4 traits.")
  }
  if (d > 2L) {
    stop("lv_wald_coverage_data() currently defines truths for d <= 2.")
  }
  family <- match.arg(family, c("gaussian", "binomial"))
  if (identical(family, "binomial")) {
    link <- match.arg(as.character(link), c("logit", "probit", "cloglog"))
    n_trials <- as.integer(n_trials)
    if (length(n_trials) != 1L || is.na(n_trials) || n_trials < 1L) {
      stop("n_trials must be a positive integer for binomial cells")
    }
    if (!identical(as.integer(d), 1L)) {
      stop("binomial LV Wald cells currently use d = 1.")
    }
    if (n_traits > 3L) {
      stop("binomial LV Wald cells currently define truths for <= 3 traits.")
    }
  }
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  x_unit <- scale(seq(-1.5, 1.5, length.out = n_units))[, 1L]

  if (identical(family, "binomial")) {
    Lambda <- matrix(c(0.55, -0.45, 0.50)[seq_len(n_traits)], ncol = 1L)
    alpha <- matrix(0.55, nrow = 1L, ncol = 1L)
  } else if (identical(as.integer(d), 1L)) {
    Lambda <- matrix(c(0.70, -0.45, 0.55, 0.35)[seq_len(n_traits)], ncol = 1L)
    alpha <- matrix(0.65, nrow = 1L, ncol = 1L)
  } else {
    Lambda <- matrix(
      c(
        0.65,
        0.20,
        -0.45,
        0.30,
        0.50,
        -0.25,
        0.35,
        0.45
      )[seq_len(n_traits * d)],
      nrow = n_traits,
      ncol = d,
      byrow = TRUE
    )
    alpha <- matrix(c(0.55, -0.35), nrow = 1L, ncol = d)
  }
  if (identical(family, "binomial")) {
    beta <- matrix(
      switch(
        link,
        logit = c(-0.15, 0.05, -0.05),
        probit = c(-0.10, 0.10, 0.00),
        cloglog = c(-1.00, -0.85, -1.10)
      )[seq_len(n_traits)],
      ncol = 1L
    )
    psi <- rep(NA_real_, n_traits)
    innovation_sd <- 0.70
  } else {
    beta <- matrix(c(0.10, -0.05, 0.08, 0.03)[seq_len(n_traits)], ncol = 1L)
    psi <- c(0.18, 0.14, 0.16, 0.20)[seq_len(n_traits)]
    innovation_sd <- 1
  }

  innovation <- matrix(
    stats::rnorm(n_units * d, sd = innovation_sd),
    nrow = n_units,
    ncol = d
  )
  mean_scores <- x_unit %*% alpha
  scores <- mean_scores + innovation

  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      out <- data.frame(
        unit = units[[i]],
        trait = traits,
        stringsAsFactors = FALSE
      )
      out[[predictor]] <- x_unit[[i]]
      out
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  trait_i <- as.integer(df$trait)
  unit_i <- as.integer(df$unit)
  eta <- as.numeric(beta[trait_i, 1L]) +
    rowSums(Lambda[trait_i, , drop = FALSE] * scores[unit_i, , drop = FALSE])
  if (identical(family, "binomial")) {
    p <- switch(
      link,
      logit = stats::plogis(eta),
      probit = stats::pnorm(eta),
      cloglog = 1 - exp(-exp(eta))
    )
    df$success <- stats::rbinom(nrow(df), size = n_trials, prob = p)
    df$failure <- n_trials - df$success
  } else {
    df$value <- eta + stats::rnorm(nrow(df), sd = psi[trait_i])
  }

  attr(df, "truth") <- list(
    traits = traits,
    family = family,
    link = if (identical(family, "binomial")) link else NA_character_,
    n_trials = if (identical(family, "binomial")) n_trials else NA_integer_,
    predictor = predictor,
    Lambda = Lambda,
    alpha = alpha,
    B_lv = Lambda %*% t(alpha),
    Sigma_shared = Lambda %*% t(Lambda),
    psi = psi,
    Sigma_total = if (identical(family, "gaussian")) {
      Lambda %*% t(Lambda) + diag(psi^2, n_traits)
    } else {
      NA
    },
    d = d
  )
  df
}

lv_wald_coverage_fit <- function(
  data,
  d,
  family = "gaussian",
  link = NA_character_
) {
  lv_wald_ensure_package()
  family <- match.arg(family, c("gaussian", "binomial"))
  old_options <- options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  on.exit(options(old_options), add = TRUE)
  control <- gllvmTMB::gllvmTMBcontrol(
    se = TRUE,
    optimizer = "optim",
    optArgs = list(method = "BFGS")
  )
  if (identical(family, "binomial")) {
    link <- match.arg(as.character(link), c("logit", "probit", "cloglog"))
    return(suppressMessages(gllvmTMB::gllvmTMB(
      cbind(success, failure) ~ 0 +
        trait +
        latent(0 + trait | unit, d = d, unique = FALSE, lv = ~x),
      data = data,
      unit = "unit",
      trait = "trait",
      family = stats::binomial(link = link),
      control = control
    )))
  }
  suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = d, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = control
  ))
}

lv_wald_truth_rows <- function(truth) {
  data.frame(
    target = "B_lv",
    trait = truth$traits,
    predictor = truth$predictor,
    target_id = paste0("B_lv[", truth$traits, ",", truth$predictor, "]"),
    truth = as.numeric(truth$B_lv[, 1L]),
    stringsAsFactors = FALSE
  )
}

lv_wald_interval_methods <- function(methods = LV_WALD_INTERVAL_METHODS) {
  methods <- unique(as.character(methods))
  known <- c("wald_z", "wald_t_unit")
  unknown <- setdiff(methods, known)
  if (length(unknown)) {
    stop(
      "Unknown LV Wald interval method(s): ",
      paste(unknown, collapse = ", "),
      ". Known methods: ",
      paste(known, collapse = ", ")
    )
  }
  methods
}

lv_wald_unit_t_df <- function(n_units, d) {
  max(1L, as.integer(n_units) - as.integer(d) - 1L)
}

lv_wald_interval_critical <- function(method, level, n_units, d) {
  if (identical(method, "wald_z")) {
    return(list(
      critical = stats::qnorm((1 + level) / 2),
      df = NA_real_,
      df_source = "normal"
    ))
  }
  if (identical(method, "wald_t_unit")) {
    df <- lv_wald_unit_t_df(n_units = n_units, d = d)
    return(list(
      critical = stats::qt((1 + level) / 2, df = df),
      df = df,
      df_source = "n_units_minus_d_minus_1"
    ))
  }
  stop("Unhandled LV Wald interval method: ", method)
}

lv_wald_fit_health <- function(fit = NULL, fit_error = NA_character_) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    return(data.frame(
      fit_error = fit_error,
      fit_convergence_code = NA_integer_,
      fit_converged = FALSE,
      fit_message = NA_character_,
      fit_objective = NA_real_,
      max_gradient = NA_real_,
      pd_hessian = FALSE,
      sdreport_ok = FALSE,
      stringsAsFactors = FALSE
    ))
  }
  grad <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
  max_gradient <- if (length(grad) == 0L || all(is.na(grad))) {
    NA_real_
  } else {
    max(abs(grad), na.rm = TRUE)
  }
  data.frame(
    fit_error = NA_character_,
    fit_convergence_code = fit$opt$convergence %||% NA_integer_,
    fit_converged = isTRUE(fit$opt$convergence == 0L),
    fit_message = fit$opt$message %||% NA_character_,
    fit_objective = fit$opt$objective %||% NA_real_,
    max_gradient = max_gradient,
    pd_hessian = if (!is.null(fit$sd_report)) {
      isTRUE(fit$sd_report$pdHess)
    } else {
      FALSE
    },
    sdreport_ok = !is.null(fit$sd_report),
    stringsAsFactors = FALSE
  )
}

lv_wald_extract_effects <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    return(list(data = NULL, error = "fit unavailable"))
  }
  err <- NULL
  effects <- tryCatch(
    gllvmTMB::extract_lv_effects(fit),
    error = function(e) {
      err <<- conditionMessage(e)
      NULL
    }
  )
  list(data = effects, error = err)
}

lv_wald_coverage_run_rep <- function(
  plan_row,
  level = LV_WALD_NOMINAL,
  interval_methods = LV_WALD_INTERVAL_METHODS
) {
  start <- proc.time()[["elapsed"]]
  interval_methods <- lv_wald_interval_methods(interval_methods)
  data <- lv_wald_coverage_data(
    n_units = plan_row$n_units,
    n_traits = plan_row$n_traits,
    d = plan_row$d,
    seed = plan_row$rep_seed,
    predictor = plan_row$predictor,
    family = plan_row$family,
    link = plan_row$link,
    n_trials = plan_row$n_trials
  )
  truth <- attr(data, "truth")
  truth_rows <- lv_wald_truth_rows(truth)

  fit_error <- NA_character_
  fit <- tryCatch(
    lv_wald_coverage_fit(
      data,
      d = plan_row$d,
      family = plan_row$family,
      link = plan_row$link
    ),
    error = function(e) {
      fit_error <<- conditionMessage(e)
      NULL
    }
  )
  health <- lv_wald_fit_health(fit, fit_error)
  extracted <- lv_wald_extract_effects(fit)
  effects <- extracted$data
  extract_error <- extracted$error %||% NA_character_

  if (is.null(effects)) {
    matched <- data.frame(
      estimate = NA_real_,
      std.error = NA_real_,
      uncertainty_status = NA_character_,
      validation_row = NA_character_
    )
  } else {
    effect_key <- paste(effects$trait, effects$predictor, sep = "\r")
    truth_key <- paste(truth_rows$trait, truth_rows$predictor, sep = "\r")
    idx <- match(truth_key, effect_key)
    matched <- data.frame(
      estimate = effects$estimate[idx],
      std.error = effects$std.error[idx],
      uncertainty_status = effects$uncertainty_status[idx],
      validation_row = effects$validation_row[idx],
      stringsAsFactors = FALSE
    )
  }

  method_rows <- lapply(interval_methods, function(method) {
    critical <- lv_wald_interval_critical(
      method = method,
      level = level,
      n_units = plan_row$n_units,
      d = plan_row$d
    )
    lower <- matched$estimate - critical$critical * matched$std.error
    upper <- matched$estimate + critical$critical * matched$std.error
    ci_available <- is.finite(lower) & is.finite(upper)
    eligible <- isTRUE(health$fit_converged) &
      isTRUE(health$pd_hessian) &
      isTRUE(health$sdreport_ok) &
      ci_available
    covered <- rep(NA, nrow(truth_rows))
    covered[eligible] <- lower[eligible] <= truth_rows$truth[eligible] &
      truth_rows$truth[eligible] <= upper[eligible]

    cbind(
      plan_row[rep(1L, nrow(truth_rows)), , drop = FALSE],
      truth_rows,
      matched,
      data.frame(
        level = level,
        interval_method = method,
        critical = critical$critical,
        critical_df = critical$df,
        critical_df_source = critical$df_source,
        conf.low = lower,
        conf.high = upper,
        ci_available = ci_available,
        eligible = eligible,
        covered = covered,
        error = matched$estimate - truth_rows$truth,
        runtime_s = proc.time()[["elapsed"]] - start,
        extract_error = extract_error,
        stringsAsFactors = FALSE
      ),
      health[rep(1L, nrow(truth_rows)), , drop = FALSE]
    )
  })
  do.call(rbind, method_rows)
}

lv_wald_rep_path <- function(results_dir, cell_id, rep) {
  file.path(
    results_dir,
    "replicates",
    cell_id,
    sprintf("rep-%04d.rds", as.integer(rep))
  )
}

lv_wald_write_rep <- function(rows, results_dir) {
  path <- lv_wald_rep_path(results_dir, rows$cell_id[[1L]], rows$rep[[1L]])
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(rows, path)
  path
}

lv_wald_coverage_run_cell <- function(
  cell_id,
  n_reps = LV_WALD_DEFAULT_N_REPS,
  seed_base = LV_WALD_DEFAULT_SEED_BASE,
  rep_indices = NULL,
  interval_methods = LV_WALD_INTERVAL_METHODS,
  results_dir = NULL,
  verbose = TRUE
) {
  cell <- lv_wald_cell(cell_id)
  plan <- lv_wald_coverage_grid(
    n_reps = n_reps,
    seed_base = seed_base,
    cells = cell
  )
  if (!is.null(rep_indices)) {
    plan <- plan[plan$rep %in% as.integer(rep_indices), , drop = FALSE]
  }
  rows <- vector("list", nrow(plan))
  for (i in seq_len(nrow(plan))) {
    if (isTRUE(verbose)) {
      message(
        "[lv-wald] ",
        plan$cell_id[[i]],
        " rep ",
        plan$rep[[i]],
        "/",
        n_reps
      )
    }
    rows[[i]] <- lv_wald_coverage_run_rep(
      plan[i, , drop = FALSE],
      interval_methods = interval_methods
    )
    if (!is.null(results_dir)) {
      lv_wald_write_rep(rows[[i]], results_dir)
    }
  }
  do.call(rbind, rows)
}

lv_wald_coverage_run_task <- function(
  task_id = Sys.getenv("SLURM_ARRAY_TASK_ID"),
  n_reps = LV_WALD_DEFAULT_N_REPS,
  seed_base = LV_WALD_DEFAULT_SEED_BASE,
  interval_methods = LV_WALD_INTERVAL_METHODS,
  results_dir,
  verbose = TRUE
) {
  if (missing(results_dir) || !nzchar(results_dir)) {
    stop("results_dir is required for task mode")
  }
  task_id <- as.integer(task_id)
  if (length(task_id) != 1L || is.na(task_id) || task_id < 1L) {
    stop("task_id must be a positive integer")
  }
  plan <- lv_wald_coverage_grid(n_reps = n_reps, seed_base = seed_base)
  if (task_id > nrow(plan)) {
    stop(
      "task_id ",
      task_id,
      " is outside the plan with ",
      nrow(plan),
      " tasks"
    )
  }
  if (isTRUE(verbose)) {
    message("[lv-wald] task ", task_id, "/", nrow(plan))
  }
  rows <- lv_wald_coverage_run_rep(
    plan[task_id, , drop = FALSE],
    interval_methods = interval_methods
  )
  path <- lv_wald_write_rep(rows, results_dir)
  attr(rows, "path") <- path
  rows
}

lv_wald_coverage_collect <- function(results_dir) {
  files <- list.files(
    file.path(results_dir, "replicates"),
    pattern = "[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  if (!length(files)) {
    stop("No LV Wald coverage replicate RDS files under ", results_dir)
  }
  rows <- lapply(files, readRDS)
  do.call(rbind, rows)
}

lv_wald_coverage_summarise <- function(
  rows,
  nominal = LV_WALD_NOMINAL,
  pass_lo = LV_WALD_PASS_LO,
  pass_hi = LV_WALD_PASS_HI,
  production_n_reps = LV_WALD_DEFAULT_N_REPS
) {
  if (!"interval_method" %in% names(rows)) {
    rows$interval_method <- "wald_z"
  }
  required <- c(
    "cell_id",
    "target_id",
    "interval_method",
    "rep",
    "truth",
    "estimate",
    "error",
    "fit_converged",
    "pd_hessian",
    "sdreport_ok",
    "ci_available",
    "eligible",
    "covered",
    "runtime_s"
  )
  missing_cols <- setdiff(required, names(rows))
  if (length(missing_cols)) {
    stop(
      "Missing required LV Wald coverage columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  if (!"critical_df" %in% names(rows)) {
    rows$critical_df <- NA_real_
  }
  if (!"critical_df_source" %in% names(rows)) {
    rows$critical_df_source <- NA_character_
  }
  groups <- split(
    rows,
    list(rows$cell_id, rows$target_id, rows$interval_method),
    drop = TRUE
  )
  out <- lapply(groups, function(df) {
    df <- df[order(df$rep), , drop = FALSE]
    eligible <- isTRUE(df$eligible) | (!is.na(df$eligible) & df$eligible)
    errors <- df$error[eligible & is.finite(df$error)]
    n_eligible <- length(errors)
    coverage <- if (n_eligible > 0L) {
      mean(df$covered[eligible], na.rm = TRUE)
    } else {
      NA_real_
    }
    coverage_mcse <- if (n_eligible > 0L && is.finite(coverage)) {
      sqrt(coverage * (1 - coverage) / n_eligible)
    } else {
      NA_real_
    }
    nominal_mcse <- if (n_eligible > 0L) {
      sqrt(nominal * (1 - nominal) / n_eligible)
    } else {
      NA_real_
    }
    bias <- if (n_eligible > 0L) mean(errors) else NA_real_
    bias_mcse <- if (n_eligible > 1L) {
      stats::sd(errors) / sqrt(n_eligible)
    } else {
      NA_real_
    }
    rmse <- if (n_eligible > 0L) sqrt(mean(errors^2)) else NA_real_
    data.frame(
      cell_id = df$cell_id[[1L]],
      family = df$family[[1L]],
      link = if ("link" %in% names(df)) df$link[[1L]] else NA_character_,
      d = df$d[[1L]],
      n_trials = if ("n_trials" %in% names(df)) {
        df$n_trials[[1L]]
      } else {
        NA_integer_
      },
      n_units = df$n_units[[1L]],
      n_traits = df$n_traits[[1L]],
      target = df$target[[1L]],
      target_id = df$target_id[[1L]],
      trait = df$trait[[1L]],
      predictor = df$predictor[[1L]],
      truth = df$truth[[1L]],
      interval_method = df$interval_method[[1L]],
      critical_df = df$critical_df[[1L]],
      critical_df_source = df$critical_df_source[[1L]],
      n_attempted = length(unique(df$rep)),
      n_converged = sum(df$fit_converged, na.rm = TRUE),
      n_pd_hessian = sum(df$pd_hessian, na.rm = TRUE),
      n_sdreport_ok = sum(df$sdreport_ok, na.rm = TRUE),
      n_ci_available = sum(df$ci_available, na.rm = TRUE),
      n_eligible = n_eligible,
      coverage = coverage,
      coverage_mcse = coverage_mcse,
      nominal_coverage_mcse = nominal_mcse,
      bias = bias,
      bias_mcse = bias_mcse,
      rmse = rmse,
      mean_runtime_s = mean(df$runtime_s, na.rm = TRUE),
      fit_failure_rate = mean(!df$fit_converged, na.rm = TRUE),
      nonpd_hessian_rate = mean(!df$pd_hessian, na.rm = TRUE),
      sdreport_failure_rate = mean(!df$sdreport_ok, na.rm = TRUE),
      ci_unavailable_rate = mean(!df$ci_available, na.rm = TRUE),
      production_n_reps_met = length(unique(df$rep)) >= production_n_reps,
      passes_coverage_band = isTRUE(
        length(unique(df$rep)) >= production_n_reps &&
          is.finite(coverage) &&
          coverage >= pass_lo &&
          coverage <= pass_hi
      ),
      stringsAsFactors = FALSE
    )
  })
  summary <- do.call(rbind, out)
  rownames(summary) <- NULL
  summary$passes_wald_coverage_band <- summary$passes_coverage_band
  summary
}

lv_wald_write_outputs <- function(rows, results_dir) {
  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  summary <- lv_wald_coverage_summarise(rows)
  saveRDS(rows, file.path(results_dir, "lv-wald-coverage-long.rds"))
  saveRDS(summary, file.path(results_dir, "lv-wald-coverage-summary.rds"))
  write.csv(
    rows,
    file.path(results_dir, "lv-wald-coverage-long.csv"),
    row.names = FALSE
  )
  write.csv(
    summary,
    file.path(results_dir, "lv-wald-coverage-summary.csv"),
    row.names = FALSE
  )
  writeLines(
    capture.output(utils::sessionInfo()),
    file.path(results_dir, "session-info.txt")
  )
  invisible(summary)
}

lv_wald_arg_value <- function(args, name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

lv_wald_coverage_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  mode <- lv_wald_arg_value(args, "--mode", "preflight")
  n_reps <- as.integer(lv_wald_arg_value(
    args,
    "--n-reps",
    as.character(LV_WALD_DEFAULT_N_REPS)
  ))
  seed_base <- as.integer(lv_wald_arg_value(
    args,
    "--seed-base",
    as.character(LV_WALD_DEFAULT_SEED_BASE)
  ))
  results_dir <- lv_wald_arg_value(args, "--results-dir", "dev/lv-wald-results")
  interval_methods <- strsplit(
    lv_wald_arg_value(
      args,
      "--interval-methods",
      paste(LV_WALD_INTERVAL_METHODS, collapse = ",")
    ),
    ",",
    fixed = TRUE
  )[[1L]]
  interval_methods <- lv_wald_interval_methods(trimws(interval_methods))

  if (identical(mode, "preflight")) {
    plan <- lv_wald_coverage_grid(n_reps = n_reps, seed_base = seed_base)
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(plan, file.path(results_dir, "lv-wald-coverage-plan.rds"))
    write.csv(
      plan,
      file.path(results_dir, "lv-wald-coverage-plan.csv"),
      row.names = FALSE
    )
    message(
      "[lv-wald] wrote plan with ",
      nrow(plan),
      " task(s) to ",
      results_dir
    )
    return(invisible(plan))
  }

  if (identical(mode, "task")) {
    task_id <- lv_wald_arg_value(
      args,
      "--task-id",
      Sys.getenv("SLURM_ARRAY_TASK_ID")
    )
    rows <- lv_wald_coverage_run_task(
      task_id = task_id,
      n_reps = n_reps,
      seed_base = seed_base,
      interval_methods = interval_methods,
      results_dir = results_dir
    )
    message("[lv-wald] wrote ", attr(rows, "path"))
    return(invisible(rows))
  }

  if (identical(mode, "cell")) {
    cell_id <- lv_wald_arg_value(args, "--cell", LV_WALD_CELLS$cell_id[[1L]])
    rep_start <- as.integer(lv_wald_arg_value(args, "--rep-start", "1"))
    rep_end <- as.integer(lv_wald_arg_value(
      args,
      "--rep-end",
      as.character(n_reps)
    ))
    rows <- lv_wald_coverage_run_cell(
      cell_id = cell_id,
      n_reps = n_reps,
      seed_base = seed_base,
      rep_indices = seq.int(rep_start, rep_end),
      interval_methods = interval_methods,
      results_dir = results_dir
    )
    summary <- lv_wald_write_outputs(rows, results_dir)
    print(summary)
    return(invisible(rows))
  }

  if (identical(mode, "summarise")) {
    rows <- lv_wald_coverage_collect(results_dir)
    summary <- lv_wald_write_outputs(rows, results_dir)
    print(summary)
    return(invisible(summary))
  }

  stop("Unknown --mode: ", mode)
}

if (identical(Sys.getenv("GLLVMTMB_LV_WALD_COVERAGE_CLI"), "true")) {
  lv_wald_coverage_cli()
}
