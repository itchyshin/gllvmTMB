## Immutable contract for the fresh iJSDM response-information campaign.
## Qualification identities are deliberately outside the scientific denominator.

ISDM_RESPINFO_SCHEMA <- "isdm-response-information-contract-v3"
ISDM_RESPINFO_RECORD_SCHEMA <- "isdm-response-information-record-v3"
ISDM_RESPINFO_SEED_BASE <- 209110001L
ISDM_RESPINFO_QUALIFICATION_SEED_BASE <- 209000001L
ISDM_RESPINFO_N_SEEDS <- 50L
ISDM_RESPINFO_BOOTSTRAP_SEED <- 209019999L
ISDM_RESPINFO_BOOTSTRAP_B <- 2000L
ISDM_RESPINFO_GRADIENT_MAX <- 0.01

.isdm_respinfo_abort <- function(message, class) {
  stop(structure(list(message = message, call = NULL),
                 class = c(class, "isdm_respinfo_contract_error", "error", "condition")))
}

isdm_respinfo_cells <- function() {
  out <- expand.grid(n_sources = c(2L, 3L), n_cells = c(150L, 810L),
                     overlap = c("full", "weak"), KEEP.OUT.ATTRS = FALSE,
                     stringsAsFactors = FALSE)
  out <- out[order(out$n_sources, out$n_cells, match(out$overlap, c("full", "weak"))), , drop = FALSE]
  rownames(out) <- NULL
  if (nrow(out) != 8L) .isdm_respinfo_abort("cell grid must contain eight rows", "isdm_respinfo_cell_grid_invalid")
  out
}

isdm_respinfo_plan <- function() {
  cells <- isdm_respinfo_cells()
  datasets <- do.call(rbind, lapply(seq_len(nrow(cells)), function(cell_index) {
    seed_index <- seq_len(ISDM_RESPINFO_N_SEEDS)
    data.frame(cell_index, seed_index,
      n_sources = cells$n_sources[[cell_index]], n_cells = cells$n_cells[[cell_index]], overlap = cells$overlap[[cell_index]],
      structure_seed = ISDM_RESPINFO_SEED_BASE + 100000L * cell_index + seed_index,
      observation_seed = ISDM_RESPINFO_SEED_BASE + 1000000L + 100000L * cell_index + seed_index,
      optimizer_seed = ISDM_RESPINFO_SEED_BASE + 3000000L + cell_index * 1000L + seed_index,
      stringsAsFactors = FALSE)
  }))
  datasets$dataset_id <- seq_len(nrow(datasets))
  plan <- datasets[rep(seq_len(nrow(datasets)), each = 2L), , drop = FALSE]
  plan$variant <- rep(c("baseline", "rep3"), times = nrow(datasets))
  plan$task_id <- seq_len(nrow(plan))
  plan$rep3_seed_1 <- NA_integer_; plan$rep3_seed_2 <- NA_integer_
  rep3 <- plan$variant == "rep3"
  plan$rep3_seed_1[rep3] <- ISDM_RESPINFO_SEED_BASE + 2000000L + 2L * plan$dataset_id[rep3] - 1L
  plan$rep3_seed_2[rep3] <- plan$rep3_seed_1[rep3] + 1L
  plan <- plan[, c("task_id", "dataset_id", "cell_index", "seed_index", "n_sources", "n_cells", "overlap", "variant", "structure_seed", "observation_seed", "rep3_seed_1", "rep3_seed_2", "optimizer_seed"), drop = FALSE]
  rownames(plan) <- NULL
  isdm_respinfo_validate_plan(plan)
  plan
}

isdm_respinfo_pilot_plan <- function(plan = isdm_respinfo_plan()) {
  isdm_respinfo_validate_plan(plan)
  out <- plan[plan$seed_index == 1L, , drop = FALSE]
  if (nrow(out) != 16L || length(unique(out$cell_index)) != 8L) .isdm_respinfo_abort("pilot must retain one paired dataset per cell", "isdm_respinfo_pilot_invalid")
  out
}

isdm_respinfo_qualification_plan <- function() {
  out <- expand.grid(variant = c("baseline", "rep3"), host = c("totoro", "drac"),
                     KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  out$qualification_id <- seq_len(nrow(out)); out$task_id <- 900000L + out$qualification_id
  out$n_sources <- 2L; out$n_cells <- 150L; out$overlap <- "full"
  host_index <- match(out$host, c("totoro", "drac"))
  out$structure_seed <- ISDM_RESPINFO_QUALIFICATION_SEED_BASE + host_index
  out$observation_seed <- ISDM_RESPINFO_QUALIFICATION_SEED_BASE + 100L + host_index
  out$optimizer_seed <- ISDM_RESPINFO_QUALIFICATION_SEED_BASE + 200L + host_index
  out$rep3_seed_1 <- ifelse(out$variant == "rep3", ISDM_RESPINFO_QUALIFICATION_SEED_BASE + 300L + 2L * host_index - 1L, NA_integer_)
  out$rep3_seed_2 <- ifelse(out$variant == "rep3", ISDM_RESPINFO_QUALIFICATION_SEED_BASE + 300L + 2L * host_index, NA_integer_)
  isdm_respinfo_validate_qualification_plan(out)
  out
}

isdm_respinfo_validate_qualification_plan <- function(plan) {
  required <- c("qualification_id", "task_id", "host", "variant", "n_sources", "n_cells", "overlap",
                "structure_seed", "observation_seed", "optimizer_seed", "rep3_seed_1", "rep3_seed_2")
  if (!is.data.frame(plan) || !all(required %in% names(plan)) || nrow(plan) != 4L ||
      !identical(sort(as.integer(plan$qualification_id)), 1:4) ||
      !identical(sort(as.integer(plan$task_id)), 900001:900004) ||
      !identical(sort(unique(as.character(plan$host))), c("drac", "totoro")) ||
      !identical(sort(unique(as.character(plan$variant))), c("baseline", "rep3"))) {
    .isdm_respinfo_abort("qualification plan is malformed", "isdm_respinfo_qualification_plan_invalid")
  }
  pairs <- split(plan, plan$host)
  nested <- vapply(pairs, function(x) {
    x <- x[match(c("baseline", "rep3"), x$variant), , drop = FALSE]
    identical(as.character(x$variant), c("baseline", "rep3")) &&
      all(vapply(c("n_sources", "n_cells", "overlap", "structure_seed", "observation_seed", "optimizer_seed"),
                 function(name) length(unique(x[[name]])) == 1L, logical(1L))) &&
      is.na(x$rep3_seed_1[[1L]]) && is.na(x$rep3_seed_2[[1L]]) &&
      is.finite(x$rep3_seed_1[[2L]]) && is.finite(x$rep3_seed_2[[2L]])
  }, logical(1L))
  seeds <- c(plan$structure_seed, plan$observation_seed, plan$optimizer_seed,
             plan$rep3_seed_1[!is.na(plan$rep3_seed_1)], plan$rep3_seed_2[!is.na(plan$rep3_seed_2)])
  if (!all(nested) || any(seeds >= ISDM_RESPINFO_SEED_BASE)) {
    .isdm_respinfo_abort("qualification plan violates its isolated seed contract", "isdm_respinfo_qualification_plan_invalid")
  }
  invisible(TRUE)
}

isdm_respinfo_validate_plan <- function(plan) {
  required <- c("task_id", "dataset_id", "cell_index", "seed_index", "n_sources", "n_cells", "overlap", "variant", "structure_seed", "observation_seed", "rep3_seed_1", "rep3_seed_2", "optimizer_seed")
  if (!is.data.frame(plan) || !all(required %in% names(plan))) .isdm_respinfo_abort("plan lacks required columns", "isdm_respinfo_plan_invalid")
  if (nrow(plan) != 800L || !identical(as.integer(plan$task_id), 1:800) || anyDuplicated(plan$task_id)) .isdm_respinfo_abort("plan must retain 800 unique fit identities", "isdm_respinfo_plan_count_invalid")
  if (length(unique(plan$dataset_id)) != 400L || !identical(as.integer(table(factor(plan$variant, levels = c("baseline", "rep3")))), c(400L, 400L))) .isdm_respinfo_abort("plan must retain 400 baseline/rep3 pairs", "isdm_respinfo_plan_count_invalid")
  if (!identical(sort(unique(plan$n_sources)), c(2L, 3L)) || !identical(sort(unique(plan$n_cells)), c(150L, 810L)) || !identical(sort(unique(plan$overlap)), c("full", "weak"))) .isdm_respinfo_abort("plan has an unexpected design cell", "isdm_respinfo_cell_grid_invalid")
  pairs <- split(plan, plan$dataset_id)
  pair_optimizer <- vapply(pairs, function(x) as.integer(x$optimizer_seed[[1L]]), integer(1L))
  if (anyDuplicated(pair_optimizer)) .isdm_respinfo_abort("optimizer seeds collide across paired datasets", "isdm_respinfo_optimizer_seed_collision")
  pair_ok <- vapply(pairs, function(x) {
    shared <- c("cell_index", "seed_index", "n_sources", "n_cells", "overlap", "structure_seed", "observation_seed", "optimizer_seed")
    identical(as.character(x$variant), c("baseline", "rep3")) && all(vapply(shared, function(name) length(unique(x[[name]])) == 1L, logical(1L))) &&
      all(is.na(x$rep3_seed_1[x$variant == "baseline"])) && all(is.na(x$rep3_seed_2[x$variant == "baseline"])) &&
      all(is.finite(x$rep3_seed_1[x$variant == "rep3"])) && all(is.finite(x$rep3_seed_2[x$variant == "rep3"]))
  }, logical(1L))
  if (!all(pair_ok)) .isdm_respinfo_abort("baseline and rep3 pairs are not nested or do not share an optimizer seed", "isdm_respinfo_pair_not_nested")
  response_seeds <- c(vapply(pairs, function(x) x$observation_seed[[1L]], integer(1L)), plan$rep3_seed_1[!is.na(plan$rep3_seed_1)], plan$rep3_seed_2[!is.na(plan$rep3_seed_2)])
  if (anyDuplicated(response_seeds)) .isdm_respinfo_abort("response streams collide", "isdm_respinfo_response_seed_collision")
  if (any(c(plan$structure_seed, response_seeds, plan$optimizer_seed) < ISDM_RESPINFO_SEED_BASE)) .isdm_respinfo_abort("scientific plan uses a qualification seed", "isdm_respinfo_seed_namespace_collision")
  invisible(TRUE)
}
