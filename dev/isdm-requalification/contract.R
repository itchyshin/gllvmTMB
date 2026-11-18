## Immutable design contract for the integrated-JSDM requalification lane.
## This file is sourceable without loading gllvmTMB and never starts a fit.

ISDM_CONTRACT_SCHEMA <- "isdm-requalification-contract-v1"
ISDM_POINT_SEED_FIRST <- 202608280L
ISDM_SPATIAL_SEED_FIRST <- 202610080L
ISDM_INTERVAL_SEED_FIRST <- 202610880L

isdm_expected_fixed_targets <- function(n_sources) {
  n_sources <- as.integer(n_sources)
  if (!n_sources %in% c(2L, 3L)) stop("n_sources must be 2 or 3")
  ecological <- c(paste0("traitsp", 1:3), paste0("traitsp", 1:3, ":env"))
  source <- unlist(lapply(seq_len(n_sources), function(d) {
    c(if (d < n_sources) paste0("isdm_source:source", d, ":(Intercept)"),
      paste0("isdm_source:source", d, ":bias_x"))
  }), use.names = FALSE)
  c(ecological, source)
}

.isdm_repeat_cells <- function(cells, n_reps, seed_first, programme) {
  stopifnot(is.data.frame(cells), n_reps > 0L, length(seed_first) == 1L)
  index <- rep(seq_len(nrow(cells)), each = n_reps)
  out <- cells[index, , drop = FALSE]
  out$rep <- rep(seq_len(n_reps), times = nrow(cells))
  out$seed <- seq.int(seed_first, length.out = nrow(out))
  out$programme <- programme
  out$task_id <- seq_len(nrow(out))
  rownames(out) <- NULL
  out[, c("task_id", "programme", setdiff(names(out),
                                            c("task_id", "programme"))),
      drop = FALSE]
}

isdm_point_plan <- function(slice = c("ordinary", "attack", "spatial")) {
  slice <- match.arg(slice)
  ordinary_cells <- expand.grid(
    n_sources = c(2L, 3L), overlap = c("full", "weak"),
    n_cells = c(150L, 810L), stringsAsFactors = FALSE
  )
  attack_cells <- data.frame(
    n_sources = c(2L, 3L), overlap = "disconnected", n_cells = 810L,
    stringsAsFactors = FALSE
  )
  spatial_cells <- expand.grid(
    n_sources = c(2L, 3L), overlap = c("full", "weak"),
    n_cells = 810L, stringsAsFactors = FALSE
  )
  if (slice == "ordinary") {
    out <- .isdm_repeat_cells(ordinary_cells, 200L,
                              ISDM_POINT_SEED_FIRST, "ordinary")
    pair_key <- interaction(out$n_sources, out$n_cells, out$rep, drop = TRUE)
    out$pair_id <- as.integer(pair_key)
    out$structure_seed <- 202700000L + out$pair_id
    return(out)
  }
  if (slice == "attack") {
    out <- .isdm_repeat_cells(attack_cells, 100L,
                              ISDM_POINT_SEED_FIRST + 1600L, "attack")
    out$task_id <- out$task_id + 1600L
    return(out)
  }
  out <- .isdm_repeat_cells(spatial_cells, 200L,
                            ISDM_SPATIAL_SEED_FIRST, "spatial")
  out$task_id <- out$task_id + 1800L
  out
}

isdm_interval_plan <- function() {
  cells <- expand.grid(
    n_cells = c(150L, 810L), n_sources = c(2L, 3L),
    overlap = c("full", "weak"), stringsAsFactors = FALSE
  )
  .isdm_repeat_cells(cells, 600L, ISDM_INTERVAL_SEED_FIRST, "interval")
}

isdm_ordinary_campaign_plan <- function() {
  ordinary <- isdm_point_plan("ordinary")
  attack <- isdm_point_plan("attack")
  attack$pair_id <- NA_integer_
  attack$structure_seed <- attack$seed
  rbind(ordinary, attack[names(ordinary)])
}

isdm_prerun_plan <- function() {
  point <- rbind(
    unique(isdm_point_plan("ordinary")[c("programme", "n_sources",
                                          "overlap", "n_cells")]),
    unique(isdm_point_plan("attack")[c("programme", "n_sources",
                                        "overlap", "n_cells")]),
    unique(isdm_point_plan("spatial")[c("programme", "n_sources",
                                         "overlap", "n_cells")])
  )
  point$prerun_rep <- 1L
  interval <- unique(isdm_interval_plan()[c("n_cells", "n_sources", "overlap")])
  interval <- interval[rep(seq_len(nrow(interval)), each = 3L), , drop = FALSE]
  interval$programme <- "interval"
  interval$prerun_rep <- rep(1:3, times = 8L)
  out <- rbind(
    point[c("programme", "n_sources", "overlap", "n_cells", "prerun_rep")],
    interval[c("programme", "n_sources", "overlap", "n_cells", "prerun_rep")]
  )
  out$seed <- seq.int(202608001L, length.out = nrow(out))
  out$task_id <- seq_len(nrow(out))
  rownames(out) <- NULL
  out[c("task_id", "programme", "n_sources", "overlap", "n_cells",
        "prerun_rep", "seed")]
}

isdm_frozen_gates <- function() {
  list(
    ordinary = list(
      campaign_terminal_n = 1800L,
      promotion_terminal_n = 1600L,
      stress_terminal_n = 200L,
      convergence_min = 0.95,
      finite_objective_min = 0.99,
      pd_hessian_min = 0.85,
      target_availability_min = 0.85,
      coefficient_abs_bias_max = 0.10,
      coefficient_rmse_max = 0.25,
      surface_correlation_median_min = 0.90,
      surface_nrmse_median_max = 0.50,
      sigma_relative_frobenius_median_max = 0.35,
      psi_relative_error_median_max = 0.35,
      weak_surface_correlation_median_min = 0.80,
      weak_rmse_ratio_max = 2.0
    ),
    spatial = list(
      terminal_n = 800L,
      training_identity_max = 1e-10,
      heldout_surface_correlation_median_min = 0.90,
      heldout_surface_nrmse_median_max = 0.50,
      target_availability_min = 0.85
    ),
    interval = list(
      terminal_n = 4800L,
      availability_min = 0.85,
      ordered_finite_min = 0.99,
      nominal_level = 0.95,
      wilson_confidence = 0.90,
      wilson90_acceptance = c(0.92, 0.98),
      immediate_failure_below = 0.80,
      response_transform_tolerance = 1e-10,
      quantile_type = 1L,
      coverage_unit = "species_within_cell_across_replicates",
      nsim = 1000L,
      escalation_total_per_cell = 2000L
    )
  )
}

isdm_estimand_contract <- function() {
  list(
    admitted = c(
      "ecological_coefficients", "source_observation_coefficients",
      "centered_relative_intensity", "Sigma", "Psi"
    ),
    refused = c(
      "raw_latent_scores", "unaligned_loadings", "absolute_abundance",
      "occupancy", "detectability"
    )
  )
}
