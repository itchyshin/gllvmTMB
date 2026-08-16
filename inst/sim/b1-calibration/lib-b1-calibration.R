## Design 118 -- B1 calibration-campaign harness, pure functions.
## docs/design/118-mspl-interval-calibration-protocol.md s2 (calibrator), s3
## (interval construction), s5 (grid, hold-outs, reps, gates), s6.2 (reduced
## budget). Fence line 2 is F-AMD (attractor-proximity), per the s8
## deviations ledger (DEV-3, branch claude/design118-s8-deviations) and
## docs/dev-log/2026-08-15-b1-launch-spec.md.
##
## Sourced by run-b1-shard.R (fitting) and tests/testthat/test-b1-calibration.R
## (pure-function checks); no side effects at source time.
##
## REUSE, not re-implementation (per the assignment brief): this file relies
## on inst/sim/b0-fence-roc/lib-b0-fence-roc.R for the analytic
## count-attractor root (b0_attractor_root/b0_attractor_score), the L1/L2
## labels (b0_label_l1/b0_label_l2 -- b0_label_l2 IS the F-AMD proximity
## statistic, DEV-3), the penalty-sensitivity probe (b0_s_j/b0_probe_class),
## the penalised-Hessian se (b0_penalised_se), the Route B surrogate
## (b0_route_b_surrogate), the separation screen (b0_screen_traits), the
## per-trait success counts (b0_trait_counts), the fit control recipe
## (b0_control), and `%||%`. None of those are T/n_site/q-specific, so they
## generalise to B1's grid unchanged. Callers must `source()`
## lib-b0-fence-roc.R BEFORE this file (see run-b1-shard.R and the test
## file for the load order).
##
## What could NOT be reused: B0's DGP (b0_manifest/b0_simulate_outer_data)
## is hard-wired to n_site=24, n_trait=3, a 4-regime beta_shift table -- B1
## needs continuous prevalence, variable n_site/n_trait/q (Design 118 s5.1),
## so the DGP below is new but structurally the same mechanism (same
## formula shape, same set.seed-per-outer-dataset simulation pattern).

## ---- Seeds (2026-08-15 launch spec) ---------------------------------
## b1_seed_base = 218,000,000 + cell_index*1,000,000 -- disjoint from B0
## (118,000,000-130,000,000ish) and the 2026-08-14 archive
## (1,900,000,000-2,020,000,000ish); see the launch spec's "Seeds" line.
b1_seed_base <- function(cell_index) 218000000L + as.integer(cell_index) * 1000000L

b1_outer_seed <- function(row, outer_id) as.integer(row$seed_base[[1L]]) + as.integer(outer_id)

## Bootstrap resample seeds live in a disjoint offset band per outer
## dataset (500,000 + ...), so they never collide with another outer_id's
## plain seed (outer_id is always < 500,000 in this campaign).
b1_bootstrap_seed <- function(row, outer_id, attempt_id) {
  as.integer(row$seed_base[[1L]]) + 500000L +
    (as.integer(outer_id) - 1L) * 1000L + as.integer(attempt_id)
}

## Deterministic 1-in-3 bootstrap-subset selection (Design 118 s6.2
## reduction), by seed/index arithmetic -- NOT RNG state, so it is
## reproducible from outer_id alone and needs no draw.
b1_in_bootstrap_subset <- function(outer_id) (as.integer(outer_id) %% 3L) == 1L

## ---- Grid (Design 118 s5.1) -------------------------------------------
## Calibration blocks (88 cells: C-core 40, C-q2 12, C-ID1 18, C-ID2 18) and
## hold-out blocks (44 cells: H1 18, H2 16, H3 10), each row flagged
## split = "train"/"holdout". Column order is the schema other functions
## rely on; keep the grid test in sync with any change here.
##
## Interpretation note (H1, "3 probit q=2" cells; Design 118 s5.1's table
## gives the cell COUNT but not which of C-q2's two n_site values the
## probit hold-out mirror uses). The non-q2 part of H1 mirrors C-core but
## drops the smallest n_site (12), keeping {24,48,96}; by the same
## exclude-the-smallest pattern this uses n_site = 96 (C-q2's larger site
## count) for the 3 probit q=2 cells, i.e. pi_target in {0.03,0.50,0.97} x
## n_site=96 x q=2. Flagged in the after-task report as an interpretation,
## not a silent grid resize.
b1_grid <- function() {
  c_core <- expand.grid(
    link = c("logit", "cloglog"),
    pi_target = c(0.03, 0.20, 0.50, 0.80, 0.97),
    n_site = c(12L, 24L, 48L, 96L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  c_core$n_trait <- 3L
  c_core$q <- 1L
  c_core$block <- "C-core"
  c_core$split <- "train"

  c_q2 <- expand.grid(
    link = c("logit", "cloglog"),
    pi_target = c(0.03, 0.50, 0.97),
    n_site = c(24L, 96L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  c_q2$n_trait <- 3L
  c_q2$q <- 2L
  c_q2$block <- "C-q2"
  c_q2$split <- "train"

  id1_tuples <- data.frame(
    n_site = c(96L, 48L, 24L), n_trait = c(3L, 6L, 12L), stringsAsFactors = FALSE
  )
  id1_rest <- expand.grid(
    link = c("logit", "cloglog"), pi_target = c(0.03, 0.50, 0.97),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  c_id1 <- merge(id1_tuples, id1_rest, by = NULL, sort = FALSE)
  c_id1$q <- 1L
  c_id1$block <- "C-ID1"
  c_id1$split <- "train"

  c_id2 <- expand.grid(
    n_trait = c(3L, 6L, 12L), link = c("logit", "cloglog"),
    pi_target = c(0.03, 0.50, 0.97),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  c_id2$n_site <- 48L
  c_id2$q <- 1L
  c_id2$block <- "C-ID2"
  c_id2$split <- "train"

  h1a <- expand.grid(
    pi_target = c(0.03, 0.20, 0.50, 0.80, 0.97), n_site = c(24L, 48L, 96L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  h1a$link <- "probit"
  h1a$n_trait <- 3L
  h1a$q <- 1L
  h1a$block <- "H1"
  h1a$split <- "holdout"

  h1b <- data.frame(pi_target = c(0.03, 0.50, 0.97), stringsAsFactors = FALSE)
  h1b$link <- "probit"
  h1b$n_site <- 96L ## documented assumption, see header note
  h1b$n_trait <- 3L
  h1b$q <- 2L
  h1b$block <- "H1"
  h1b$split <- "holdout"

  h2 <- expand.grid(
    pi_target = c(0.08, 0.92), link = c("logit", "cloglog"),
    n_site = c(12L, 24L, 48L, 96L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  h2$n_trait <- 3L
  h2$q <- 1L
  h2$block <- "H2"
  h2$split <- "holdout"

  h3 <- expand.grid(
    link = c("logit", "cloglog"), pi_target = c(0.03, 0.20, 0.50, 0.80, 0.97),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  h3$n_site <- 192L
  h3$n_trait <- 3L
  h3$q <- 1L
  h3$block <- "H3"
  h3$split <- "holdout"

  cols <- c("link", "pi_target", "n_site", "n_trait", "q", "block", "split")
  grid <- rbind(
    c_core[, cols], c_q2[, cols], c_id1[, cols], c_id2[, cols],
    h1a[, cols], h1b[, cols], h2[, cols], h3[, cols]
  )
  rownames(grid) <- NULL
  grid$cell_index <- seq_len(nrow(grid))
  grid$cell_id <- sprintf("B%03d", grid$cell_index)
  grid$seed_base <- b1_seed_base(grid$cell_index)
  grid$structure <- "ordinary_latent" ## Design 118 s4.1 envelope; constant
  grid$bootstrap_bearing <- !(grid$block %in% c("C-ID1", "C-ID2")) ## s6.1

  grid[, c(
    "cell_index", "cell_id", "block", "split", "link", "pi_target",
    "n_site", "n_trait", "q", "structure", "bootstrap_bearing", "seed_base"
  )]
}

b1_cell_row <- function(cell_id, grid = b1_grid()) {
  row <- grid[grid$cell_id == cell_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Unknown B1 cell_id: ", cell_id, call. = FALSE)
  row
}

## ---- Task-id <-> (cell, shard) mapping (SLURM array sizing) -----------
b1_shards_per_cell <- function(outer_per_shard = 10L, reps = 600L) {
  as.integer(ceiling(reps / outer_per_shard))
}

b1_task_map <- function(outer_per_shard = 10L, reps = 600L, grid = b1_grid()) {
  shards_per_cell <- b1_shards_per_cell(outer_per_shard, reps)
  do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    data.frame(
      task_id = (grid$cell_index[[i]] - 1L) * shards_per_cell + seq_len(shards_per_cell),
      cell_index = grid$cell_index[[i]], cell_id = grid$cell_id[[i]],
      shard_id = seq_len(shards_per_cell), stringsAsFactors = FALSE
    )
  }))
}

b1_task_lookup <- function(task_id, outer_per_shard = 10L, reps = 600L, grid = b1_grid()) {
  m <- b1_task_map(outer_per_shard, reps, grid)
  row <- m[m$task_id == as.integer(task_id), , drop = FALSE]
  if (nrow(row) != 1L) stop("Unknown B1 task_id: ", task_id, call. = FALSE)
  row
}

## ---- DGP (same generative mechanism as B0/the 2026-08-14 archive; see -
## header) parametrised by continuous prevalence and variable n_site/T/q --
b1_linkfun <- function(link) {
  switch(link,
    logit = stats::qlogis,
    probit = stats::qnorm,
    cloglog = function(p) log(-log1p(-p)),
    stop("Unknown link: ", link, call. = FALSE)
  )
}

## n_trait intercepts spread symmetrically (width 1.05, matching B0's own
## c(-0.5, 0.1, 0.55) spread width) around linkfun(pi_target), so the
## MEDIAN trait sits close to the nominal target and the extremes probe
## both tails (Design 118 s2.1 #2: "both tails").
b1_target_intercepts <- function(pi_target, link, n_trait) {
  n_trait <- as.integer(n_trait)
  centre <- b1_linkfun(link)(pi_target)
  centre + seq(-0.525, 0.525, length.out = n_trait)
}

## The 3 calibration-target trait positions within an n_trait-trait cell:
## the min-, median-, and max-prevalence trait (Design 118 s5.1). Because
## b1_target_intercepts() is monotone increasing in trait position by
## construction, these are simply the first, middle, and last positions.
b1_target_positions <- function(n_trait) {
  n_trait <- as.integer(n_trait)
  if (n_trait < 3L) stop("b1_target_positions() requires n_trait >= 3", call. = FALSE)
  mid <- as.integer(round((1L + n_trait) / 2))
  data.frame(
    slot = c("min", "median", "max"), position = c(1L, mid, n_trait),
    stringsAsFactors = FALSE
  )
}

## n_trait x q loading matrix: B0's own (0.8, -0.55, 0.35) triple, tiled
## across n_trait traits and cyclically rotated one position per latent
## factor column (so q=2 columns are not identical up to scale).
b1_lambda_matrix <- function(lambda_scale, n_trait, q) {
  n_trait <- as.integer(n_trait)
  q <- as.integer(q)
  base <- c(0.8, -0.55, 0.35)
  vapply(seq_len(q), function(j) {
    rotated <- base[((seq_len(3L) - 1L + (j - 1L)) %% 3L) + 1L]
    lambda_scale * rep_len(rotated, n_trait)
  }, numeric(n_trait))
}

b1_simulate_outer_data <- function(row, outer_id, lambda_scale = 1) {
  set.seed(b1_outer_seed(row, outer_id))
  n_site <- as.integer(row$n_site[[1L]])
  n_trait <- as.integer(row$n_trait[[1L]])
  q <- as.integer(row$q[[1L]])
  link <- row$link[[1L]]

  site <- factor(rep(sprintf("s%03d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%02d", seq_len(n_trait)), n_site),
    levels = sprintf("t%02d", seq_len(n_trait))
  )
  z <- matrix(stats::rnorm(n_site * q), nrow = n_site, ncol = q)
  intercepts <- b1_target_intercepts(row$pi_target[[1L]], link, n_trait)
  lambda <- b1_lambda_matrix(lambda_scale, n_trait, q)

  trait_idx <- as.integer(trait)
  site_idx <- as.integer(site)
  eta <- intercepts[trait_idx] +
    rowSums(lambda[trait_idx, , drop = FALSE] * z[site_idx, , drop = FALSE])
  mu <- switch(link,
    logit = stats::plogis(eta), probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta)), stop("Unknown link: ", link, call. = FALSE)
  )
  data.frame(site = site, trait = trait, y = stats::rbinom(length(mu), 1L, mu))
}

b1_formula <- function(q) {
  stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)", as.integer(q)
  ))
}

## b0_control() (mult wrapper) is reused unchanged -- it does not depend on
## q. b1_fit_mspl() only needs to make the formula q-dependent.
b1_fit_mspl <- function(data, link, q, mult = 1) {
  gllvmTMB::gllvmTMB(
    b1_formula(q), data = data, family = stats::binomial(link = link),
    estimator = "mspl", control = b0_control(mult), silent = TRUE
  )
}

## ---- Fence line 1 (screen), read off b0_screen_traits()'s "separation" -
## table (Design 118 s1.1). A trait is refused when its block is either
## NOT_CHECKED/constant_response (k in {0,n}, caught before the separation
## solver runs) or WARN/{complete,quasi_complete} (the solver's own
## verdict). Pure function so it is testable without a live fit.
b1_screen_refused <- function(screen_status, screen_severity) {
  (screen_status %in% "NOT_CHECKED" & screen_severity %in% "constant_response") |
    (screen_status %in% "WARN" & screen_severity %in% c("complete", "quasi_complete"))
}

## ---- Fence line 2, F-AMD (DEV-3): attractor-proximity, NOT the s_j ------
## threshold. b0_label_l2() (sourced from lib-b0-fence-roc.R) already IS
## this statistic: |estimate - attractor_root| < tol. s_j/probe_class are
## still computed and carried in the output for Design 117 s6.1 reporting,
## but per the s8 deviations ledger they no longer gate refusal.
b1_proximity_refused <- function(estimate, attractor_root, tol = 1e-4) {
  b0_label_l2(estimate, attractor_root, tol = tol)
}

## ---- Output schema -----------------------------------------------------
## One row per (outer dataset x calibration target). Keep the schema test
## in test-b1-calibration.R in sync with any change here.
b1_output_columns <- c(
  "cell_index", "cell_id", "block", "split", "link", "pi_target",
  "n_site", "n_trait", "q", "structure", "bootstrap_bearing",
  "shard_id", "outer_id", "seed",
  "p_free", "N_eff", "c_n",
  "target", "target_name", "target_slot", "truth", "k", "n_obs",
  "estimate", "converged",
  "screen_status", "screen_severity", "screen_refused",
  "attractor_root", "proximity_refused",
  "refused", "refusal_reason",
  "estimate_half_cn", "half_converged", "estimate_double_cn", "double_converged",
  "se_penalised", "hessian_status", "d_per_efold", "s_j", "probe_class",
  "route_b_s_surr", "route_b_status",
  "profile_attempted", "profile_status", "profile_lower", "profile_upper",
  "profile_available", "profile_covered",
  "in_bootstrap_subset", "bootstrap_attempted", "bootstrap_status",
  "bootstrap_usable_n", "bootstrap_lower", "bootstrap_upper",
  "bootstrap_available", "bootstrap_covered",
  "fit_elapsed_seconds", "probe_elapsed_seconds", "hessian_elapsed_seconds",
  "screen_elapsed_seconds", "profile_elapsed_seconds", "bootstrap_elapsed_seconds",
  "status", "message"
)

b1_na_row <- function(n = 1L) {
  out <- as.data.frame(matrix(NA, nrow = n, ncol = length(b1_output_columns)))
  names(out) <- b1_output_columns
  out
}

## ---- One outer dataset: simulate, fit, fence, profile, (subset) --------
## bootstrap. Every stage is wrapped so a failure anywhere downgrades that
## row's status/message instead of aborting the shard (B0's convention).
b1_run_outer <- function(row, outer_id, shard_id, bootstrap_reps = 500L,
                          profile_level = 0.95, boot_alpha = 0.05,
                          proximity_tol = 1e-4) {
  link <- row$link[[1L]]
  q <- as.integer(row$q[[1L]])
  n_trait <- as.integer(row$n_trait[[1L]])
  targets <- b1_target_positions(n_trait)
  n_targets <- nrow(targets)
  truth_all <- b1_target_intercepts(row$pi_target[[1L]], link, n_trait)
  seed <- b1_outer_seed(row, outer_id)
  data <- b1_simulate_outer_data(row, outer_id)
  counts <- b0_trait_counts(data)

  base_row <- function(status, message = "") {
    out <- b1_na_row(n_targets)
    out$cell_index <- row$cell_index[[1L]]
    out$cell_id <- row$cell_id[[1L]]
    out$block <- row$block[[1L]]
    out$split <- row$split[[1L]]
    out$link <- link
    out$pi_target <- row$pi_target[[1L]]
    out$n_site <- row$n_site[[1L]]
    out$n_trait <- n_trait
    out$q <- q
    out$structure <- row$structure[[1L]]
    out$bootstrap_bearing <- row$bootstrap_bearing[[1L]]
    out$shard_id <- as.integer(shard_id)
    out$outer_id <- as.integer(outer_id)
    out$seed <- seed
    out$target <- targets$position
    out$target_name <- counts$target_name[targets$position]
    out$target_slot <- targets$slot
    out$truth <- truth_all[targets$position]
    out$k <- counts$k[targets$position]
    out$n_obs <- counts$n_obs[targets$position]
    out$in_bootstrap_subset <- row$bootstrap_bearing[[1L]] && b1_in_bootstrap_subset(outer_id)
    out$status <- status
    out$message <- message
    out
  }

  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(b1_fit_mspl(data, link, q, mult = 1), error = identity)
  fit_elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(fit, "error")) {
    out <- base_row("outer_fit_error", conditionMessage(fit))
    out$fit_elapsed_seconds <- fit_elapsed
    return(out)
  }

  idx_all <- which(names(fit$opt$par) == "b_fix")
  if (length(idx_all) != n_trait) {
    out <- base_row("outer_target_alignment_failed", "")
    out$fit_elapsed_seconds <- fit_elapsed
    return(out)
  }
  idx <- idx_all[targets$position]

  out <- base_row("ok")
  out$fit_elapsed_seconds <- fit_elapsed
  out$converged <- identical(as.integer(fit$opt$convergence), 0L)
  out$p_free <- fit$tmb_obj$env$data$p_free
  out$N_eff <- fit$tmb_obj$env$data$N_eff
  invisible(fit$tmb_obj$fn(as.numeric(fit$opt$par))) ## sync internal state before report()
  rep <- fit$tmb_obj$report()
  c_n <- rep$mspl_c_n %||% NA_real_
  out$c_n <- c_n
  out$estimate <- as.numeric(fit$opt$par[idx])

  ## Fence line 2 ingredient: analytic count-attractor root per target.
  out$attractor_root <- vapply(seq_len(n_targets), function(i) {
    b0_attractor_root(
      k = out$k[[i]], n = out$n_obs[[i]], c_n = c_n, link = link
    )
  }, numeric(1L))
  out$proximity_refused <- b1_proximity_refused(out$estimate, out$attractor_root, tol = proximity_tol)

  ## Fence line 1: the shipped separation screen.
  screen_started <- proc.time()[["elapsed"]]
  sep <- tryCatch(b0_screen_traits(data, link), error = identity)
  out$screen_elapsed_seconds <- proc.time()[["elapsed"]] - screen_started
  if (!inherits(sep, "error")) {
    m <- match(out$target_name, sep$traits)
    out$screen_status <- sep$status[m]
    out$screen_severity <- sep$severity[m]
    out$screen_refused <- b1_screen_refused(out$screen_status, out$screen_severity)
    out$screen_refused[is.na(m)] <- TRUE ## fail-closed: no screen row found -> refuse
  } else {
    out$screen_refused <- TRUE ## fail-closed: screen itself errored -> refuse (Design 88 style)
  }

  out$refused <- out$screen_refused | out$proximity_refused
  out$refusal_reason <- ifelse(out$screen_refused %in% TRUE, "screen",
    ifelse(out$proximity_refused %in% TRUE, "proximity", "")
  )

  ## Route A probe (s_j): two extra outer refits at c_n/2 and 2c_n. Still
  ## computed and recorded for every coordinate (Design 117 s6.1 reporting)
  ## even though F-AMD no longer uses s_j for refusal (DEV-3).
  probe_started <- proc.time()[["elapsed"]]
  fit_half <- tryCatch(b1_fit_mspl(data, link, q, mult = 0.5), error = identity)
  fit_double <- tryCatch(b1_fit_mspl(data, link, q, mult = 2), error = identity)
  out$probe_elapsed_seconds <- proc.time()[["elapsed"]] - probe_started
  half_ok <- !inherits(fit_half, "error") &&
    length(which(names(fit_half$opt$par) == "b_fix")) == n_trait
  double_ok <- !inherits(fit_double, "error") &&
    length(which(names(fit_double$opt$par) == "b_fix")) == n_trait
  out$half_converged <- if (half_ok) identical(as.integer(fit_half$opt$convergence), 0L) else FALSE
  out$double_converged <- if (double_ok) identical(as.integer(fit_double$opt$convergence), 0L) else FALSE
  if (half_ok) {
    idx_h <- which(names(fit_half$opt$par) == "b_fix")[targets$position]
    out$estimate_half_cn <- as.numeric(fit_half$opt$par[idx_h])
  }
  if (double_ok) {
    idx_d <- which(names(fit_double$opt$par) == "b_fix")[targets$position]
    out$estimate_double_cn <- as.numeric(fit_double$opt$par[idx_d])
  }

  hessian_started <- proc.time()[["elapsed"]]
  hess <- b0_penalised_se(fit)
  out$hessian_elapsed_seconds <- proc.time()[["elapsed"]] - hessian_started
  out$hessian_status <- hess$status
  out$se_penalised <- hess$se[idx]
  if (half_ok && double_ok && identical(hess$status, "ok")) {
    sj <- b0_s_j(out$estimate_half_cn, out$estimate_double_cn, out$se_penalised)
    out$d_per_efold <- sj$d_per_efold
    out$s_j <- sj$s_j
    out$probe_class <- b0_probe_class(sj$s_j)
  }
  rb <- b0_route_b_surrogate(fit, hess$covariance)
  out$route_b_status <- rb$status
  out$route_b_s_surr <- rb$s_surr[idx]

  ## Penalised-profile interval (base construction, Design 118 s3.1), only
  ## for coordinates the fence did not refuse.
  for (i in seq_len(n_targets)) {
    if (isTRUE(out$refused[[i]])) {
      out$profile_attempted[[i]] <- FALSE
      out$profile_status[[i]] <- "refused"
      next
    }
    out$profile_attempted[[i]] <- TRUE
    profile_started <- proc.time()[["elapsed"]]
    probe <- tryCatch(
      gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
        fit, which = idx[[i]], step = 0.5, max_steps = 12L, level = profile_level,
        control = list(eval.max = 100L, iter.max = 100L),
        refinement_steps = 12L, bracket_tolerance = 1.25e-4
      ),
      error = identity
    )
    out$profile_elapsed_seconds[[i]] <- proc.time()[["elapsed"]] - profile_started
    if (inherits(probe, "error")) {
      out$profile_status[[i]] <- "profile_error"
      next
    }
    diagnostic <- gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(probe)
    ok <- identical(diagnostic$centre_status, "matched") &&
      identical(diagnostic$lower_status, "crossed") &&
      identical(diagnostic$upper_status, "crossed")
    out$profile_status[[i]] <- if (ok) "ok" else paste0(
      "profile_", diagnostic$centre_status, "_", diagnostic$lower_status, "_", diagnostic$upper_status
    )
    if (ok) {
      out$profile_lower[[i]] <- diagnostic$diagnostic_lower
      out$profile_upper[[i]] <- diagnostic$diagnostic_upper
      out$profile_available[[i]] <- TRUE
      out$profile_covered[[i]] <- out$truth[[i]] >= out$profile_lower[[i]] &&
        out$truth[[i]] <= out$profile_upper[[i]]
    } else {
      out$profile_available[[i]] <- FALSE
    }
  }

  ## Percentile bootstrap fallback (1-in-3 subset, bootstrap-bearing cells
  ## only, non-refused coordinates only -- Design 118 s1.4/s3.5/s6.2).
  for (i in seq_len(n_targets)) {
    attempt <- row$bootstrap_bearing[[1L]] && out$in_bootstrap_subset[[i]] && !isTRUE(out$refused[[i]])
    out$bootstrap_attempted[[i]] <- attempt
    if (!attempt) {
      out$bootstrap_status[[i]] <- if (isTRUE(out$refused[[i]])) "refused" else "not_in_subset"
      next
    }
    boot_started <- proc.time()[["elapsed"]]
    redraw <- tryCatch(.check_simulate_unconditional(fit), error = identity)
    if (inherits(redraw, "error") || !isTRUE(redraw$can_redraw)) {
      out$bootstrap_status[[i]] <- "unconditional_redraw_unavailable"
      out$bootstrap_elapsed_seconds[[i]] <- proc.time()[["elapsed"]] - boot_started
      next
    }
    values <- vapply(seq_len(bootstrap_reps), function(attempt_id) {
      bseed <- b1_bootstrap_seed(row, outer_id, attempt_id)
      simulated <- tryCatch(
        stats::simulate(fit, nsim = 1L, seed = bseed, condition_on_RE = FALSE),
        error = identity
      )
      if (inherits(simulated, "error")) return(NA_real_)
      y <- as.numeric(simulated[, 1L])
      if (length(y) != nrow(fit$data) || any(!is.finite(y))) return(NA_real_)
      bdata <- fit$data
      bdata$y <- y
      refit <- tryCatch(b1_fit_mspl(bdata, link, q, mult = 1), error = identity)
      if (inherits(refit, "error")) return(NA_real_)
      ridx <- which(names(refit$opt$par) == "b_fix")
      if (length(ridx) != n_trait || !identical(as.integer(refit$opt$convergence), 0L)) {
        return(NA_real_)
      }
      as.numeric(refit$opt$par[ridx[targets$position[[i]]]])
    }, numeric(1L))
    out$bootstrap_elapsed_seconds[[i]] <- proc.time()[["elapsed"]] - boot_started
    usable <- values[is.finite(values)]
    out$bootstrap_usable_n[[i]] <- length(usable)
    min_usable <- ceiling(0.95 * bootstrap_reps)
    if (length(usable) < min_usable) {
      out$bootstrap_status[[i]] <- "insufficient_usable_bootstrap"
      next
    }
    q_lo <- boot_alpha / 2
    q_hi <- 1 - boot_alpha / 2
    endpoints <- stats::quantile(usable, c(q_lo, q_hi), type = 7L, names = FALSE)
    if (any(!is.finite(endpoints)) || endpoints[[1L]] >= endpoints[[2L]]) {
      out$bootstrap_status[[i]] <- "bootstrap_endpoints_invalid"
      next
    }
    out$bootstrap_status[[i]] <- "ok"
    out$bootstrap_lower[[i]] <- endpoints[[1L]]
    out$bootstrap_upper[[i]] <- endpoints[[2L]]
    out$bootstrap_available[[i]] <- TRUE
    out$bootstrap_covered[[i]] <- out$truth[[i]] >= endpoints[[1L]] && out$truth[[i]] <= endpoints[[2L]]
  }

  out
}
