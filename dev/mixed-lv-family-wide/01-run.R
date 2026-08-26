## Retained per-attempt runner for the frozen mixed-family LV ADEMP manifest.
## Sourceable by tests; no fit runs unless GLLVMTMB_MIXED_LV_RUN=true.

if (!exists("MIXED_LV_HARNESS_SCHEMA", inherits = TRUE)) {
  caller_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(caller_file)) caller_file <- ""
  candidates <- c(file.path("dev", "mixed-lv-family-wide", "00-manifest.R"),
    file.path(dirname(caller_file), "00-manifest.R"))
  manifest_file <- candidates[file.exists(candidates)][1L]
  if (is.na(manifest_file)) stop("Cannot locate 00-manifest.R")
  source(manifest_file, local = FALSE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

mixed_lv_sigma_shared <- function(loading) {
  if (!is.matrix(loading) || !is.numeric(loading)) {
    stop("loading must be a numeric matrix")
  }
  tcrossprod(loading)
}

mixed_lv_fit_weights <- function(family_ids, weights) {
  if (16L %in% as.integer(family_ids)) NULL else weights
}

mixed_lv_atomic_save_rds <- function(object, path) {
  if (file.exists(path)) stop("attempt_already_exists: refusing to overwrite retained record")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(".", basename(path), "."), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  saveRDS(object, tmp)
  if (!file.rename(tmp, path)) stop("atomic_write_failure: could not rename retained record")
  invisible(path)
}

mixed_lv_support_check <- function(family_id, y, trials = NULL) {
  family_id <- as.integer(family_id)
  finite <- length(y) > 0L && all(is.finite(y))
  integerish <- finite && all(abs(y - round(y)) < 1e-8)
  ok <- finite
  if (family_id %in% c(1L, 8L)) {
    ok <- integerish && length(trials) == 1L && is.finite(trials) &&
      all(y >= 0 & y <= trials) && any(y > 0) && any(y < trials)
  } else if (family_id %in% c(2L, 5L, 15L)) {
    ok <- integerish && all(y >= 0)
  } else if (family_id %in% c(3L, 4L)) {
    ok <- all(y > 0)
  } else if (family_id == 6L) {
    ok <- all(y >= 0) && any(y == 0) && any(y > 0)
  } else if (family_id == 7L) {
    ok <- all(y > 0 & y < 1)
  } else if (family_id %in% c(10L, 11L)) {
    ok <- integerish && all(y >= 1)
  } else if (family_id %in% c(12L, 13L)) {
    ok <- all(y >= 0) && any(y == 0) && any(y > 0)
  } else if (family_id == 14L) {
    counts <- if (integerish) tabulate(as.integer(y), nbins = 4L) else integer()
    ok <- integerish && all(y %in% 1:4) && length(counts) == 4L && all(counts >= 2L)
  } else if (family_id == 16L) {
    counts <- if (integerish) tabulate(as.integer(y), nbins = 3L) else integer()
    ok <- integerish && all(y %in% 1:3) && length(counts) == 3L && all(counts >= 2L)
  }
  list(ok = isTRUE(ok), family_id = family_id, n = length(y),
    n_zero = if (finite) sum(y == 0) else NA_integer_)
}

mixed_lv_family <- function(fid, lid = 0L) {
  switch(as.character(fid),
    `0` = stats::gaussian(),
    `1` = stats::binomial(link = c("logit", "probit", "cloglog")[[lid + 1L]]),
    `2` = stats::poisson(), `3` = gllvmTMB::lognormal(),
    `4` = stats::Gamma(link = "log"), `5` = gllvmTMB::nbinom2(),
    `6` = gllvmTMB::tweedie(p = 1.5), `7` = gllvmTMB::Beta(),
    `8` = gllvmTMB::betabinomial(),
    `9` = suppressMessages(gllvmTMB::student(df = 5)),
    `10` = gllvmTMB::truncated_poisson(),
    `11` = gllvmTMB::truncated_nbinom2(),
    `12` = gllvmTMB::delta_lognormal(), `13` = gllvmTMB::delta_gamma(),
    `14` = gllvmTMB::ordinal_probit(), `15` = gllvmTMB::nbinom1(),
    `16` = gllvmTMB::multinomial(), stop("unknown family ID: ", fid))
}

mixed_lv_intercepts <- function(fid, lid = 0L) {
  if (fid == 0L) return(c(.15, -.10))
  if (fid == 1L) return(switch(as.character(lid),
    `0` = c(-.2, .2), `1` = c(-.1, .1), `2` = c(-1, -.8)))
  if (fid %in% c(2L, 5L, 10L, 11L, 15L)) return(log(c(4, 6)))
  if (fid %in% c(3L, 4L, 6L)) return(c(.3, .6))
  if (fid %in% c(7L, 8L)) return(c(-.2, .2))
  if (fid == 9L) return(c(.15, -.1))
  if (fid %in% c(12L, 13L)) return(c(.5, .8))
  if (fid == 14L) return(c(-.3, -.1))
  if (fid == 16L) return(c(.3, -.4))
  stop("no intercept truth for family ID ", fid)
}

mixed_lv_positive_count <- function(mu, kind = c("poisson", "nbinom2")) {
  kind <- match.arg(kind)
  vapply(mu, function(m) repeat {
    y <- if (kind == "poisson") stats::rpois(1L, m) else
      stats::rnbinom(1L, mu = m, size = 3)
    if (y > 0L) return(as.numeric(y))
  }, numeric(1L))
}

mixed_lv_draw_scalar <- function(fid, lid, eta) {
  n <- length(eta)
  if (fid == 0L) return(stats::rnorm(n, eta, .3))
  if (fid == 1L) {
    p <- switch(as.character(lid), `0` = stats::plogis(eta),
      `1` = stats::pnorm(eta), `2` = -expm1(-exp(eta)))
    return(stats::rbinom(n, 20L, p))
  }
  if (fid == 2L) return(stats::rpois(n, exp(eta)))
  if (fid == 3L) return(stats::rlnorm(n, eta, .3))
  if (fid == 4L) return(stats::rgamma(n, shape = 6, scale = exp(eta) / 6))
  if (fid == 5L) return(stats::rnbinom(n, mu = exp(eta), size = 4))
  if (fid == 6L) {
    if (!requireNamespace("mgcv", quietly = TRUE)) stop("mgcv required for Tweedie DGP")
    return(mgcv::rTweedie(exp(eta), p = 1.5, phi = 1))
  }
  if (fid == 7L) { mu <- stats::plogis(eta); return(stats::rbeta(n, mu * 15, (1 - mu) * 15)) }
  if (fid == 8L) { mu <- stats::plogis(eta); p <- stats::rbeta(n, mu * 5, (1 - mu) * 5); return(stats::rbinom(n, 20L, p)) }
  if (fid == 9L) return(eta + .7 * stats::rt(n, df = 5))
  if (fid == 10L) return(mixed_lv_positive_count(exp(eta), "poisson"))
  if (fid == 11L) return(mixed_lv_positive_count(exp(eta), "nbinom2"))
  if (fid == 12L) return(stats::rbinom(n, 1L, stats::plogis(eta)) * stats::rlnorm(n, eta, .7))
  if (fid == 13L) return(stats::rbinom(n, 1L, stats::plogis(eta)) * stats::rgamma(n, 1 / .8^2, scale = exp(eta) * .8^2))
  if (fid == 14L) { z <- eta + stats::rnorm(n); return(vapply(z, function(x) 1L + sum(x > c(0, .8, 1.6)), integer(1L))) }
  if (fid == 15L) { mu <- exp(eta); return(stats::rnbinom(n, mu = mu, size = mu)) }
  stop("scalar draw unavailable for family ID ", fid)
}

mixed_lv_softmax_draw <- function(eta2, eta3) vapply(seq_along(eta2), function(i) {
  q <- c(0, eta2[[i]], eta3[[i]]); q <- exp(q - max(q)); sample.int(3L, 1L, prob = q)
}, integer(1L))

mixed_lv_parse_ids <- function(x) as.integer(strsplit(x, ",", fixed = TRUE)[[1L]])

mixed_lv_make_fixture <- function(cell, seed) {
  set.seed(seed)
  fids <- mixed_lv_parse_ids(cell$family_ids)
  lids <- mixed_lv_parse_ids(cell$link_ids)
  n <- cell$n_units; reps <- cell$n_repeats
  x0 <- stats::rnorm(n); innovation <- stats::rnorm(n)
  score0 <- .6 * x0 + innovation
  unit_i <- rep(seq_len(n), each = reps); x <- x0[unit_i]; score <- score0[unit_i]
  component_seeds <- sample.int(.Machine$integer.max, max(4L, length(fids) + 1L))

  if (16L %in% fids) {
    bm <- mixed_lv_intercepts(16L); set.seed(component_seeds[[1L]])
    if (cell$cell_kind == "pure") {
      lambda <- c(.7, -.55)
      y <- mixed_lv_softmax_draw(bm[[1L]] + lambda[[1L]] * score,
        bm[[2L]] + lambda[[2L]] * score)
      dat <- data.frame(unit = factor(sprintf("u%03d", unit_i)),
        trait = factor("category"), x = x, value = y)
      family <- mixed_lv_family(16L); beta <- bm
      support <- list(multinomial = mixed_lv_support_check(16L, y))
    } else {
      lambda <- c(.7, -.55, .45); bg <- .15
      yg <- stats::rnorm(length(score), bg + lambda[[1L]] * score, .3)
      y <- mixed_lv_softmax_draw(bm[[1L]] + lambda[[2L]] * score,
        bm[[2L]] + lambda[[3L]] * score)
      dat <- do.call(rbind, lapply(seq_along(unit_i), function(i) data.frame(
        unit = sprintf("u%03d", unit_i[[i]]), trait = c("gaussian", "category"),
        family = c("g", "m"), x = x[[i]], value = c(yg[[i]], y[[i]]))))
      dat$unit <- factor(dat$unit); dat$trait <- factor(dat$trait,
        levels = c("gaussian", "category")); dat$family <- factor(dat$family)
      family <- list(g = mixed_lv_family(0L), m = mixed_lv_family(16L));
      attr(family, "family_var") <- "family"; beta <- c(bg, bm)
      support <- list(gaussian = mixed_lv_support_check(0L, yg),
        multinomial = mixed_lv_support_check(16L, y))
    }
    return(list(data = dat, family = family, weights = rep(1, nrow(dat)),
      truth = list(B_lv = lambda * .6, Sigma_shared = tcrossprod(lambda),
        intercept = beta, score_identity = 0), support = support,
      component_seeds = component_seeds))
  }

  if (cell$cell_kind == "pure") {
    fids <- rep(fids, 2L); lids <- rep(lids, 2L); labels <- c("trait_a", "trait_b")
    beta <- mixed_lv_intercepts(fids[[1L]], lids[[1L]]); lambda <- c(.7, -.55)
  } else if (cell$cell_kind == "sentinel") {
    labels <- c("poisson", "Gamma", "Beta"); beta <- c(log(4), .3, -.2); lambda <- c(.7, -.55, .45)
  } else {
    labels <- if (identical(fids, c(2L, 3L))) c("poisson", "lognormal") else c("gaussian", "candidate")
    beta <- c(mixed_lv_intercepts(fids[[1L]], lids[[1L]])[[1L]],
      mixed_lv_intercepts(fids[[2L]], lids[[2L]])[[2L]]); lambda <- c(.7, -.55)
  }
  ys <- vector("list", length(fids)); support <- vector("list", length(fids))
  for (j in seq_along(fids)) {
    set.seed(component_seeds[[j]]); ys[[j]] <- mixed_lv_draw_scalar(fids[[j]], lids[[j]], beta[[j]] + lambda[[j]] * score)
    support[[j]] <- mixed_lv_support_check(fids[[j]], ys[[j]], if (fids[[j]] %in% c(1L, 8L)) 20L else NULL)
  }
  names(support) <- labels
  dat <- do.call(rbind, lapply(seq_along(unit_i), function(i) data.frame(
    unit = sprintf("u%03d", unit_i[[i]]), trait = labels,
    family = paste0("f", seq_along(fids)), x = x[[i]],
    value = vapply(ys, `[[`, numeric(1L), i),
    weight = ifelse(fids %in% c(1L, 8L), 20L, 1L))))
  dat$unit <- factor(dat$unit); dat$trait <- factor(dat$trait, levels = labels)
  dat$family <- factor(dat$family, levels = paste0("f", seq_along(fids)))
  family <- if (cell$cell_kind == "pure") mixed_lv_family(fids[[1L]], lids[[1L]]) else {
    z <- setNames(Map(mixed_lv_family, fids, lids), levels(dat$family)); attr(z, "family_var") <- "family"; z
  }
  list(data = dat, family = family, weights = dat$weight,
    truth = list(B_lv = lambda * .6, Sigma_shared = tcrossprod(lambda),
      intercept = beta, score_identity = 0), support = support,
    component_seeds = component_seeds)
}

mixed_lv_attempt_stub <- function(task, status = "started", failure_stage = NA_character_) {
  list(schema_version = MIXED_LV_HARNESS_SCHEMA, task_id = task$task_id[[1L]],
    cell_id = task$cell_id[[1L]], campaign_kind = task$campaign_kind[[1L]],
    rep = task$rep[[1L]], rep_seed = task$rep_seed[[1L]],
    evidence_eligible = isTRUE(task$evidence_eligible[[1L]]), status = status,
    failure_stage = failure_stage)
}

mixed_lv_capture <- function(expr, log) withCallingHandlers(expr, warning = function(w) {
  log$warnings[[length(log$warnings) + 1L]] <- list(class = class(w), message = conditionMessage(w))
  invokeRestart("muffleWarning")
})

mixed_lv_run_attempt <- function(task, cell, output_dir) {
  start <- Sys.time(); stage <- "source_gate"; log <- new.env(parent = emptyenv()); log$warnings <- list()
  record <- mixed_lv_attempt_stub(task)
  record$pinned_head <- MIXED_LV_PINNED_HEAD
  record$manifest_id <- MIXED_LV_MANIFEST_ID
  record$formula_id <- MIXED_LV_FORMULA_ID
  record$harness_manifest <- mixed_lv_harness_manifest()
  record$source_head_observed <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]],
    error = function(e) NA_character_)
  record$source_manifest <- mixed_lv_observe_source_manifest()
  record$expected_family_ids <- mixed_lv_parse_ids(cell$family_ids)
  record$expected_link_ids <- mixed_lv_parse_ids(cell$link_ids)
  dir.create(file.path(output_dir, "started"), recursive = TRUE, showWarnings = FALSE)
  started_path <- file.path(output_dir, "started", sprintf("task-%06d.rds", record$task_id))
  final_path <- file.path(output_dir, "attempts", sprintf("task-%06d.rds", record$task_id))
  if (file.exists(started_path) || file.exists(final_path)) {
    stop("attempt_already_exists: retained tasks are immutable and cannot be retried in place")
  }
  mixed_lv_atomic_save_rds(record, started_path)
  out <- tryCatch({
    mixed_lv_validate_source_identity(record$source_head_observed,
      record$source_manifest)
    stage <- "dgp"; fixture <- mixed_lv_capture(mixed_lv_make_fixture(cell, task$rep_seed), log)
    record$component_seeds <- fixture$component_seeds
    record$truth <- fixture$truth
    record$dgp_support <- fixture$support
    record$dgp_support_ok <- all(vapply(fixture$support, function(x) isTRUE(x$ok), logical(1L)))
    if (!record$dgp_support_ok) stop("dgp_support_failure")
    stage <- "fit"
    fit_weights <- mixed_lv_fit_weights(record$expected_family_ids, fixture$weights)
    record$weights_dispatch <- if (is.null(fit_weights)) "NULL_multinomial" else "family_aware_vector"
    fit <- mixed_lv_capture(suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
      data = fixture$data, unit = "unit", trait = "trait", family = fixture$family,
      weights = fit_weights, silent = TRUE,
      control = gllvmTMB::gllvmTMBcontrol(se = task$campaign_kind == "calibration")
    )), log)
    stage <- "extract"
    par <- fit$tmb_obj$env$parList(fit$opt$par); grad <- tryCatch(fit$tmb_obj$gr(fit$opt$par), error = function(e) NA_real_)
    B <- as.numeric(fit$report$B_lv_unit); Sigma <- mixed_lv_sigma_shared(fit$report$Lambda_B)
    beta <- as.numeric(par$b_fix); identity_error <- max(abs(fit$report$U_B_total - (fit$report$U_lv_mean_B + t(par$z_B))))
    record$fit_convergence_code <- fit$opt$convergence %||% NA_integer_
    record$fit_converged <- identical(record$fit_convergence_code, 0L)
    record$fit_message <- fit$opt$message %||% NA_character_
    record$fit_objective <- fit$opt$objective %||% NA_real_
    record$max_gradient <- if (any(is.finite(grad))) max(abs(grad), na.rm = TRUE) else NA_real_
    record$diag_B_disabled <- !isTRUE(fit$use$diag_B)
    record$family_ids_observed <- sort(unique(as.integer(fit$tmb_data$family_id_vec)))
    observed_pairs <- unique(paste(fit$tmb_data$family_id_vec,
      fit$tmb_data$link_id_vec, sep = ":"))
    expected_pairs <- unique(paste(record$expected_family_ids,
      record$expected_link_ids, sep = ":"))
    record$family_ids_ok <- identical(record$family_ids_observed,
      sort(unique(record$expected_family_ids)))
    record$link_pairs_ok <- setequal(observed_pairs, expected_pairs)
    record$B_lv <- B; record$Sigma_shared <- Sigma; record$intercept <- beta
    record$B_lv_error <- B - fixture$truth$B_lv
    record$Sigma_entry_error <- as.numeric(Sigma - fixture$truth$Sigma_shared)
    record$intercept_error <- beta - fixture$truth$intercept
    record$B_lv_abs_error <- max(abs(B - fixture$truth$B_lv))
    den <- sqrt(sum(fixture$truth$Sigma_shared^2)); record$Sigma_rel_frob_error <- sqrt(sum((Sigma - fixture$truth$Sigma_shared)^2)) / den
    record$intercept_rmse <- sqrt(mean((beta - fixture$truth$intercept)^2))
    record$score_identity_error <- identity_error
    record$point_eligible <- record$fit_converged && is.finite(record$fit_objective) &&
      is.finite(record$max_gradient) && record$max_gradient <= MIXED_LV_THRESHOLDS$max_gradient &&
      all(is.finite(c(B, Sigma, beta))) && record$diag_B_disabled &&
      record$family_ids_ok && record$link_pairs_ok &&
      identity_error <= MIXED_LV_THRESHOLDS$max_score_identity_error
    record$pd_hessian <- isTRUE(fit$sd_report$pdHess)
    record$interval_eligible <- FALSE; record$covered_all_B_lv <- NA
    if (task$campaign_kind == "calibration") {
      eff <- tryCatch(
        mixed_lv_capture(gllvmTMB::extract_lv_effects(fit, type = "trait_effect"), log),
        error = function(e) {
          record$interval_error_class <<- class(e)
          record$interval_error_message <<- conditionMessage(e)
          NULL
        })
      record$B_lv_interval <- eff
      if (!is.null(eff)) {
        record$interval_eligible <- record$point_eligible && record$pd_hessian &&
          nrow(eff) == length(fixture$truth$B_lv) && all(is.finite(eff$lower)) && all(is.finite(eff$upper))
        if (record$interval_eligible) {
          record$B_lv_covered <- fixture$truth$B_lv >= eff$lower & fixture$truth$B_lv <= eff$upper
          record$covered_all_B_lv <- all(record$B_lv_covered)
        }
      }
    }
    record$session_info <- capture.output(utils::sessionInfo())
    record$status <- "fit_returned"; record
  }, error = function(e) {
    record$status <- "error"; record$failure_stage <- stage
    record$error_class <- class(e); record$error_message <- conditionMessage(e); record
  })
  out$warnings <- log$warnings; out$warning_count <- length(log$warnings)
  out$runtime_s <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  out
}

mixed_lv_load_package <- function(root = ".", namespace_loaded = isNamespaceLoaded) {
  preloaded <- identical(
    Sys.getenv("GLLVMTMB_MIXED_LV_PACKAGE_PRELOADED"), "true"
  )
  if (preloaded) {
    if (!namespace_loaded("gllvmTMB")) {
      stop("preloaded package gate set but gllvmTMB namespace is not loaded")
    }
    return("preloaded")
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload required")
  pkgload::load_all(root, quiet = TRUE)
  "load_all"
}

mixed_lv_run_task <- function(campaign_kind, task_id, output_dir) {
  if (!identical(Sys.getenv("GLLVMTMB_MIXED_LV_RUN"), "true")) stop("fit gate closed: set GLLVMTMB_MIXED_LV_RUN=true only after compute approval")
  grid <- mixed_lv_task_grid(campaign_kind); task_id <- as.integer(task_id)
  if (length(task_id) != 1L || is.na(task_id) || !(task_id %in% grid$task_id)) stop("unknown task_id")
  task <- grid[grid$task_id == task_id, , drop = FALSE]
  cell <- mixed_lv_cells(); cell <- cell[cell$cell_id == task$cell_id, , drop = FALSE]
  head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
  mixed_lv_validate_source_identity(head, mixed_lv_observe_source_manifest())
  mixed_lv_load_package(".")
  dir.create(file.path(output_dir, "attempts"), recursive = TRUE, showWarnings = FALSE)
  out <- mixed_lv_run_attempt(task, cell, output_dir)
  final_path <- file.path(output_dir, "attempts", sprintf("task-%06d.rds", task_id))
  if (file.exists(final_path)) stop("attempt_already_exists: refusing to overwrite retained result")
  mixed_lv_atomic_save_rds(out, final_path)
  out
}

mixed_lv_partition_task_ids <- function(task_ids, worker_id, n_workers) {
  worker_id <- as.integer(worker_id)
  n_workers <- as.integer(n_workers)
  if (
    length(worker_id) != 1L || is.na(worker_id) ||
      length(n_workers) != 1L || is.na(n_workers) ||
      n_workers < 1L || worker_id < 1L || worker_id > n_workers
  ) {
    stop("worker_id must be between 1 and n_workers")
  }
  task_ids[(seq_along(task_ids) - 1L) %% n_workers == worker_id - 1L]
}

mixed_lv_run_worker <- function(
  campaign_kind,
  worker_id,
  n_workers,
  output_dir
) {
  if (!identical(Sys.getenv("GLLVMTMB_MIXED_LV_RUN"), "true")) {
    stop("fit gate closed: set GLLVMTMB_MIXED_LV_RUN=true only after compute approval")
  }
  grid <- mixed_lv_task_grid(campaign_kind)
  task_ids <- mixed_lv_partition_task_ids(grid$task_id, worker_id, n_workers)
  cells <- mixed_lv_cells()
  head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
  mixed_lv_validate_source_identity(head, mixed_lv_observe_source_manifest())
  mixed_lv_load_package(".")
  results <- vector("list", length(task_ids))
  for (i in seq_along(task_ids)) {
    task <- grid[grid$task_id == task_ids[[i]], , drop = FALSE]
    cell <- cells[cells$cell_id == task$cell_id, , drop = FALSE]
    results[[i]] <- mixed_lv_run_attempt(task, cell, output_dir)
    final_path <- file.path(
      output_dir,
      "attempts",
      sprintf("task-%06d.rds", task_ids[[i]])
    )
    mixed_lv_atomic_save_rds(results[[i]], final_path)
  }
  list(
    worker_id = as.integer(worker_id),
    n_workers = as.integer(n_workers),
    n_tasks = length(task_ids),
    task_ids = task_ids,
    status = vapply(results, `[[`, character(1L), "status")
  )
}

mixed_lv_cli_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  val <- function(key) sub(paste0("^--", key, "="), "", args[grepl(paste0("^--", key, "="), args)])[1L]
  list(
    campaign_kind = val("campaign-kind"),
    task_id = suppressWarnings(as.integer(val("task-id"))),
    worker_id = suppressWarnings(as.integer(val("worker-id"))),
    n_workers = suppressWarnings(as.integer(val("n-workers"))),
    output_dir = val("output-dir")
  )
}

if (identical(Sys.getenv("GLLVMTMB_MIXED_LV_RUN"), "true") && sys.nframe() == 0L) {
  a <- mixed_lv_cli_args()
  if (!is.na(a$worker_id) || !is.na(a$n_workers)) {
    print(mixed_lv_run_worker(
      a$campaign_kind,
      a$worker_id,
      a$n_workers,
      a$output_dir
    ))
  } else {
    print(mixed_lv_run_task(a$campaign_kind, a$task_id, a$output_dir))
  }
}
