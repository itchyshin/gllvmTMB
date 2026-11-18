# Retained two-cell point-recovery campaign for the cross-family LV predictor bridge.
#
# This file is sourceable without fitting. A fit runs only through
# `cross_family_lv_run_task()` or the explicit `--task` CLI.

`%||%` <- function(x, y) if (is.null(x)) y else x

CROSS_FAMILY_LV_SCHEMA <- "cross-family-lv-recovery-v1"
CROSS_FAMILY_LV_SEED_BASE <- 202608270L
CROSS_FAMILY_LV_EXPECTED_REPS <- 200L

cross_family_lv_cells <- function() {
  data.frame(
    cell_id = c("continuous-unequal-scale-d2", "five-family-d3"),
    rank = c(2L, 3L),
    n_units = c(240L, 500L),
    n_repeats = c(4L, 6L),
    stringsAsFactors = FALSE
  )
}

cross_family_lv_plan <- function(n_reps = CROSS_FAMILY_LV_EXPECTED_REPS) {
  n_reps <- as.integer(n_reps)
  if (length(n_reps) != 1L || is.na(n_reps) || n_reps < 1L) {
    stop("n_reps must be one positive integer")
  }
  cells <- cross_family_lv_cells()
  out <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
    data.frame(
      task_id = (i - 1L) * n_reps + seq_len(n_reps),
      cell_id = cells$cell_id[[i]],
      rep = seq_len(n_reps),
      seed = CROSS_FAMILY_LV_SEED_BASE + (i - 1L) * 100000L + seq_len(n_reps),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

cross_family_lv_atomic_save <- function(object, path) {
  if (file.exists(path)) stop("attempt_already_exists: refusing to overwrite")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(".", basename(path)), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  saveRDS(object, tmp)
  if (!file.rename(tmp, path)) stop("atomic retained-record rename failed")
  invisible(path)
}

cross_family_lv_continuous_fixture <- function(seed, n_units = 240L, reps = 4L) {
  set.seed(seed)
  d <- 2L
  x <- as.numeric(scale(stats::rnorm(n_units)))
  alpha <- c(0.55, -0.30)
  lambda <- rbind(
    g1 = c(0.90, 0.00),
    g2 = c(-0.55, 0.65),
    l1 = c(0.70, 0.35),
    l2 = c(-0.40, 0.80)
  )
  intercept <- c(g1 = 0.4, g2 = -0.2, l1 = 0.1, l2 = 0.35)
  sigma <- c(gaussian = 0.25, lognormal = 0.65)
  scores <- outer(x, alpha) + matrix(stats::rnorm(n_units * d), n_units, d)
  eta <- sweep(scores %*% t(lambda), 2L, intercept, "+")
  units <- sprintf("u%03d", seq_len(n_units))

  rows <- vector("list", reps)
  for (r in seq_len(reps)) {
    y <- cbind(
      stats::rnorm(n_units, eta[, "g1"], sigma[["gaussian"]]),
      stats::rnorm(n_units, eta[, "g2"], sigma[["gaussian"]]),
      stats::rlnorm(n_units, eta[, "l1"], sigma[["lognormal"]]),
      stats::rlnorm(n_units, eta[, "l2"], sigma[["lognormal"]])
    )
    colnames(y) <- rownames(lambda)
    rows[[r]] <- do.call(rbind, lapply(seq_len(n_units), function(i) {
      data.frame(
        unit = units[[i]], replicate = r, trait = rownames(lambda),
        family = c("g", "g", "l", "l"), x = x[[i]],
        value = as.numeric(y[i, ]), stringsAsFactors = FALSE
      )
    }))
  }
  data <- do.call(rbind, rows)
  data$unit <- factor(data$unit, levels = units)
  data$trait <- factor(data$trait, levels = rownames(lambda))
  data$family <- factor(data$family, levels = c("g", "l"))
  families <- list(g = stats::gaussian(), l = gllvmTMB::lognormal())
  attr(families, "family_var") <- "family"
  list(
    data = data,
    families = families,
    truth = list(
      B_lv = drop(lambda %*% alpha),
      Sigma_shared = tcrossprod(lambda),
      R_shared = stats::cov2cor(tcrossprod(lambda)),
      sigma_eps = sigma
    )
  )
}

cross_family_lv_five_fixture <- function(seed, n_units = 500L, reps = 6L) {
  if (!exists("simulate_five_family_lv_predictor", mode = "function")) {
    source(file.path("dev", "cross-family-lv-predictor", "five-family-canary.R"),
      local = FALSE)
  }
  x <- simulate_five_family_lv_predictor(
    seed = seed, n_units = n_units, reps = reps, d = 3L
  )
  families <- list(
    g = stats::gaussian(), b = stats::binomial(), p = stats::poisson(),
    o = gllvmTMB::ordinal_probit(), m = gllvmTMB::multinomial()
  )
  attr(families, "family_var") <- "family"
  list(
    data = x$data,
    families = families,
    truth = list(B_lv = x$B_lv, Sigma_shared = x$Sigma_shared, R_shared = x$R_shared)
  )
}

cross_family_lv_fit_cell <- function(cell_id, seed) {
  cell <- cross_family_lv_cells()
  cell <- cell[cell$cell_id == cell_id, , drop = FALSE]
  if (nrow(cell) != 1L) stop("unknown cell_id: ", cell_id)
  fixture <- if (identical(cell_id, "continuous-unequal-scale-d2")) {
    cross_family_lv_continuous_fixture(seed, cell$n_units, cell$n_repeats)
  } else {
    cross_family_lv_five_fixture(seed, cell$n_units, cell$n_repeats)
  }
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = cell$rank,
      unique = FALSE, lv = ~x),
    data = fixture$data, family = fixture$families,
    trait = "trait", unit = "unit", silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  Sigma <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "shared", link_residual = "none"
  ))$Sigma
  B_lv <- as.numeric(fit$report$B_lv_unit)
  names(B_lv) <- rownames(fixture$truth$Sigma_shared)
  R_shared <- stats::cov2cor(Sigma)
  gradient <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
  total <- gllvmTMB::extract_ordination(fit, level = "unit", component = "total")$scores
  mean <- gllvmTMB::extract_ordination(fit, level = "unit", component = "mean")$scores
  innovation <- gllvmTMB::extract_ordination(fit, level = "unit", component = "innovation")$scores
  list(
    fit = fit,
    truth = fixture$truth,
    estimate = list(
      B_lv = B_lv, Sigma_shared = Sigma, R_shared = R_shared,
      sigma_eps = as.numeric(fit$report$sigma_eps)
    ),
    convergence = fit$opt$convergence,
    objective = fit$opt$objective,
    max_gradient = if (any(is.finite(gradient))) max(abs(gradient), na.rm = TRUE) else NA_real_,
    score_identity_error = max(abs(total - mean - innovation))
  )
}

cross_family_lv_run_task <- function(task_id, output_dir, n_reps = CROSS_FAMILY_LV_EXPECTED_REPS) {
  task_id <- as.integer(task_id)
  plan <- cross_family_lv_plan(n_reps)
  task <- plan[plan$task_id == task_id, , drop = FALSE]
  if (nrow(task) != 1L) stop("task_id absent from immutable plan")
  expected_sha <- Sys.getenv("CROSS_FAMILY_LV_PINNED_SHA", unset = "")
  observed_sha <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]],
    error = function(e) NA_character_
  )
  if (n_reps == CROSS_FAMILY_LV_EXPECTED_REPS && !nzchar(expected_sha)) {
    stop("CROSS_FAMILY_LV_PINNED_SHA is required for the retained r200 campaign")
  }
  if (nzchar(expected_sha) && !identical(observed_sha, expected_sha)) {
    stop("source_sha_mismatch: observed checkout is not the approved candidate")
  }
  started_path <- file.path(output_dir, "started", sprintf("task-%06d.rds", task_id))
  final_path <- file.path(output_dir, "attempts", sprintf("task-%06d.rds", task_id))
  started <- list(
    schema = CROSS_FAMILY_LV_SCHEMA, task_id = task_id,
    cell_id = task$cell_id[[1L]], rep = task$rep[[1L]], seed = task$seed[[1L]],
    status = "started", expected_sha = expected_sha, observed_sha = observed_sha,
    started_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  cross_family_lv_atomic_save(started, started_path)
  start <- Sys.time()
  record <- tryCatch({
    result <- cross_family_lv_fit_cell(task$cell_id[[1L]], task$seed[[1L]])
    truth <- result$truth
    est <- result$estimate
    list(
      schema = CROSS_FAMILY_LV_SCHEMA, task_id = task_id,
      cell_id = task$cell_id[[1L]], rep = task$rep[[1L]], seed = task$seed[[1L]],
      status = "fit_returned", expected_sha = expected_sha,
      observed_sha = observed_sha, convergence = result$convergence,
      objective = result$objective, max_gradient = result$max_gradient,
      score_identity_error = result$score_identity_error,
      B_lv_error = as.numeric(est$B_lv - truth$B_lv),
      Sigma_error = as.numeric(est$Sigma_shared - truth$Sigma_shared),
      R_error = as.numeric((est$R_shared - truth$R_shared)[upper.tri(truth$R_shared)]),
      log_sigma_error = if (!is.null(truth$sigma_eps)) {
        log(est$sigma_eps) - log(unname(truth$sigma_eps))
      } else numeric(0L),
      point_eligible = identical(result$convergence, 0L) &&
        is.finite(result$objective) && is.finite(result$max_gradient) &&
        result$max_gradient <= 0.01 && result$score_identity_error <= 1e-8 &&
        all(is.finite(c(est$B_lv, est$Sigma_shared, est$R_shared, est$sigma_eps))),
      estimate = est, truth = truth
    )
  }, error = function(e) {
    list(
      schema = CROSS_FAMILY_LV_SCHEMA, task_id = task_id,
      cell_id = task$cell_id[[1L]], rep = task$rep[[1L]], seed = task$seed[[1L]],
      status = "error", expected_sha = expected_sha,
      observed_sha = observed_sha, point_eligible = FALSE,
      error_class = class(e), error_message = conditionMessage(e)
    )
  })
  record$runtime_s <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  record$session_info <- capture.output(utils::sessionInfo())
  cross_family_lv_atomic_save(record, final_path)
  record
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 4L && identical(args[[1L]], "--task")) {
  result <- cross_family_lv_run_task(
    task_id = as.integer(args[[2L]]), output_dir = args[[3L]],
    n_reps = as.integer(args[[4L]])
  )
  print(result[c("task_id", "cell_id", "status", "point_eligible", "runtime_s")])
}
