## Immutable contract for the integrated-JSDM failure-mechanism experiment.
## Sourceable without loading gllvmTMB and never starts a fit.

ISDM_DIAG_CONTRACT_SCHEMA <- "isdm-identifiability-diagnostic-contract-v1"
ISDM_DIAG_SEED_MANIFEST_SCHEMA <- "isdm-identifiability-seed-manifest-v1"
ISDM_DIAG_PRODUCTION_SOURCE_SHA <-
  "c5bb0b80a0a733c6d7cb1bab826003bbaa589fe4"
ISDM_DIAG_PRODUCTION_SOURCE_TREE <-
  "655282a18631700e033319d299e686162b52be97"
ISDM_DIAG_RAW_MANIFEST_SHA256 <-
  "bfcc17994d2fc9a46c5d9f372be63ce2074629a2fe6dbd9a01df156d35e5e092"
ISDM_DIAG_ADJUDICATION_V3_SHA256 <-
  "32c7a9cb325d1e45f015b38b53a8722473e0a9ffc254d3f5e79fb2c6c22001ab"
ISDM_DIAG_CHAIN_MANIFEST_SHA256 <-
  "b452c79c2328a88a1821bee3b1925ccd357c7af1b3dbb4ea7453509127bf9bfa"
ISDM_DIAG_OPTIMIZER_SEED_FIRST <- 203100001L
ISDM_DIAG_REP3_SEED_BASE <- 203000000L

.isdm_diag_abort <- function(message, class) {
  stop(structure(
    list(message = message, call = NULL),
    class = c(class, "isdm_diag_contract_error", "error", "condition")
  ))
}

.isdm_diag_require_columns <- function(x, columns, what) {
  if (!is.data.frame(x) || !all(columns %in% names(x))) {
    missing <- setdiff(columns, names(x))
    .isdm_diag_abort(
      paste0(what, " lacks required columns: ", paste(missing, collapse = ", ")),
      "isdm_diag_contract_invalid"
    )
  }
  invisible(TRUE)
}

isdm_diag_outcome_class <- function(convergence, pd_hessian,
                                    status = "fit_returned") {
  if (length(status) != 1L || !identical(status, "fit_returned") ||
      length(convergence) != 1L || is.na(convergence) ||
      length(pd_hessian) != 1L || is.na(pd_hessian)) {
    .isdm_diag_abort(
      "a production outcome class requires a returned fit and finite diagnostics",
      "isdm_diag_outcome_unavailable"
    )
  }
  if (identical(as.integer(convergence), 0L)) {
    if (isTRUE(pd_hessian)) "converged_pd" else "converged_nonpd"
  } else {
    if (isTRUE(pd_hessian)) "nonconverged_pd" else "nonconverged_nonpd"
  }
}

isdm_diag_validate_index <- function(index) {
  required <- c(
    "task_id", "programme", "n_sources", "overlap", "n_cells", "pair_id",
    "structure_seed", "seed", "status", "convergence", "pd_hessian",
    "source_sha", "source_tree", "record_sha256"
  )
  .isdm_diag_require_columns(index, required, "production index")
  if (anyDuplicated(index$task_id) || anyDuplicated(index$seed)) {
    .isdm_diag_abort(
      "production task_id and seed identities must be unique",
      "isdm_diag_identity_duplicate"
    )
  }
  if (any(index$source_sha != ISDM_DIAG_PRODUCTION_SOURCE_SHA) ||
      any(index$source_tree != ISDM_DIAG_PRODUCTION_SOURCE_TREE)) {
    .isdm_diag_abort(
      "production record source does not match the frozen source pin",
      "isdm_diag_source_mismatch"
    )
  }
  hashes <- tolower(index$record_sha256)
  if (any(is.na(hashes)) || any(!grepl("^[0-9a-f]{64}$", hashes))) {
    .isdm_diag_abort(
      "production record SHA-256 is missing or malformed",
      "isdm_diag_record_hash_invalid"
    )
  }
  invisible(TRUE)
}

.isdm_diag_cell_order <- function(x) {
  order(
    match(x$n_sources, c(2L, 3L)),
    match(x$n_cells, c(150L, 810L)),
    match(x$overlap, c("full", "weak")),
    x$seed
  )
}

isdm_diag_select_nonspatial <- function(index) {
  isdm_diag_validate_index(index)
  ordinary <- index[index$programme == "ordinary" &
                      index$n_sources %in% c(2L, 3L) &
                      index$n_cells %in% c(150L, 810L) &
                      index$overlap %in% c("full", "weak"), , drop = FALSE]
  if (nrow(ordinary) == 0L) {
    .isdm_diag_abort("ordinary production records are absent",
                     "isdm_diag_pair_missing")
  }
  chosen <- list()
  k <- 0L
  for (n_sources in c(2L, 3L)) for (n_cells in c(150L, 810L)) {
    cell <- ordinary[ordinary$n_sources == n_sources &
                       ordinary$n_cells == n_cells, , drop = FALSE]
    full_ids <- cell$pair_id[cell$overlap == "full"]
    weak_ids <- cell$pair_id[cell$overlap == "weak"]
    common <- sort(intersect(full_ids[!is.na(full_ids)],
                             weak_ids[!is.na(weak_ids)]))
    if (!length(common)) {
      .isdm_diag_abort(
        sprintf("no full/weak pair exists for n_sources=%d, n_cells=%d",
                n_sources, n_cells),
        "isdm_diag_pair_missing"
      )
    }
    selected <- cell[cell$pair_id == common[[1L]], , drop = FALSE]
    if (nrow(selected) != 2L || anyDuplicated(selected$overlap) ||
        !identical(sort(selected$overlap), c("full", "weak")) ||
        length(unique(selected$structure_seed)) != 1L) {
      .isdm_diag_abort(
        sprintf("ambiguous full/weak pair for n_sources=%d, n_cells=%d",
                n_sources, n_cells),
        "isdm_diag_pair_ambiguous"
      )
    }
    k <- k + 1L
    chosen[[k]] <- selected
  }
  out <- do.call(rbind, chosen)
  out <- out[.isdm_diag_cell_order(out), , drop = FALSE]
  rownames(out) <- NULL
  out
}

isdm_diag_select_spatial <- function(index) {
  isdm_diag_validate_index(index)
  spatial <- index[index$programme == "spatial" &
                     index$n_sources %in% c(2L, 3L) &
                     index$overlap %in% c("full", "weak") &
                     index$n_cells == 810L, , drop = FALSE]
  if (!nrow(spatial)) {
    .isdm_diag_abort("spatial production records are absent",
                     "isdm_diag_outcome_class_missing")
  }
  spatial$outcome_class <- vapply(seq_len(nrow(spatial)), function(i) {
    isdm_diag_outcome_class(
      spatial$convergence[[i]], spatial$pd_hessian[[i]], spatial$status[[i]]
    )
  }, character(1L))
  required_classes <- c(
    "converged_pd", "converged_nonpd", "nonconverged_nonpd"
  )
  chosen <- list()
  k <- 0L
  for (n_sources in c(2L, 3L)) for (overlap in c("full", "weak")) {
    cell <- spatial[spatial$n_sources == n_sources &
                      spatial$overlap == overlap, , drop = FALSE]
    for (outcome_class in required_classes) {
      candidates <- cell[cell$outcome_class == outcome_class, , drop = FALSE]
      if (!nrow(candidates)) {
        .isdm_diag_abort(
          sprintf("missing %s for n_sources=%d, overlap=%s",
                  outcome_class, n_sources, overlap),
          "isdm_diag_outcome_class_missing"
        )
      }
      k <- k + 1L
      chosen[[k]] <- candidates[which.min(candidates$seed), , drop = FALSE]
    }
  }
  out <- do.call(rbind, chosen)
  rownames(out) <- NULL
  out
}

.isdm_diag_expand <- function(selected, variants, slice, first_task_id) {
  index <- rep(seq_len(nrow(selected)), each = length(variants))
  out <- selected[index, , drop = FALSE]
  out$variant <- rep(variants, times = nrow(selected))
  out$slice <- slice
  out$native_task_id <- out$task_id
  out$sentinel_class <- if (slice == "spatial") out$outcome_class else
    "paired_min_pair"
  out$task_id <- seq.int(first_task_id, length.out = nrow(out))
  out
}

isdm_diag_plan <- function(nonspatial, spatial) {
  if (nrow(nonspatial) != 8L || nrow(spatial) != 12L) {
    .isdm_diag_abort("seed selections must contain 8 nonspatial and 12 spatial rows",
                     "isdm_diag_selection_count_invalid")
  }
  nonsp <- .isdm_diag_expand(
    nonspatial, c("baseline", "rep3"), "nonspatial", 1L
  )
  spatial_plan <- .isdm_diag_expand(
    spatial, c("default", "bfgs_continuation", "nlminb5"), "spatial", 17L
  )
  plan <- rbind(nonsp, spatial_plan)
  plan$optimizer_seed <- seq.int(
    ISDM_DIAG_OPTIMIZER_SEED_FIRST, length.out = nrow(plan)
  )
  plan$rep3_seed_1 <- ifelse(
    plan$variant == "rep3",
    ISDM_DIAG_REP3_SEED_BASE + 2L * plan$native_task_id,
    NA_integer_
  )
  plan$rep3_seed_2 <- ifelse(
    plan$variant == "rep3", plan$rep3_seed_1 + 1L, NA_integer_
  )
  keep <- c(
    "task_id", "slice", "native_task_id", "seed", "n_sources", "overlap",
    "n_cells", "variant", "sentinel_class", "optimizer_seed", "pair_id",
    "structure_seed", "rep3_seed_1", "rep3_seed_2", "source_sha",
    "source_tree", "record_sha256"
  )
  plan <- plan[, keep, drop = FALSE]
  rownames(plan) <- NULL
  isdm_diag_validate_plan(plan)
  plan
}

diagnostic_plan <- function(seed_manifest) {
  if (!is.list(seed_manifest) ||
      !identical(seed_manifest$schema, ISDM_DIAG_SEED_MANIFEST_SCHEMA) ||
      !is.data.frame(seed_manifest$nonspatial) ||
      !is.data.frame(seed_manifest$spatial)) {
    .isdm_diag_abort("invalid diagnostic seed manifest",
                     "isdm_diag_seed_manifest_invalid")
  }
  isdm_diag_plan(seed_manifest$nonspatial, seed_manifest$spatial)
}

isdm_diag_validate_plan <- function(plan) {
  required <- c(
    "task_id", "slice", "native_task_id", "seed", "n_sources", "overlap",
    "n_cells", "variant", "sentinel_class", "optimizer_seed", "pair_id",
    "structure_seed", "rep3_seed_1", "rep3_seed_2", "source_sha",
    "source_tree", "record_sha256"
  )
  .isdm_diag_require_columns(plan, required, "diagnostic plan")
  if (nrow(plan) != 52L || !identical(as.integer(plan$task_id), 1:52) ||
      anyDuplicated(plan$task_id) || anyDuplicated(plan$optimizer_seed)) {
    .isdm_diag_abort("diagnostic plan must retain 52 unique immutable identities",
                     "isdm_diag_plan_identity_invalid")
  }
  expected_variants <- c(
    baseline = 8L, rep3 = 8L, default = 12L,
    bfgs_continuation = 12L, nlminb5 = 12L
  )
  counts <- table(factor(plan$variant, levels = names(expected_variants)))
  if (!identical(as.integer(counts), unname(expected_variants)) ||
      !identical(as.integer(table(factor(plan$slice,
                                         levels = c("nonspatial", "spatial")))),
                 c(16L, 36L))) {
    .isdm_diag_abort("diagnostic plan arm counts differ from the frozen contract",
                     "isdm_diag_plan_count_invalid")
  }
  rep3 <- plan$variant == "rep3"
  if (any(is.na(plan$rep3_seed_1[rep3])) ||
      any(is.na(plan$rep3_seed_2[rep3])) ||
      any(plan$rep3_seed_1[rep3] %in% plan$seed) ||
      any(plan$rep3_seed_2[rep3] %in% plan$seed)) {
    .isdm_diag_abort("rep3 response streams collide with production seeds",
                     "isdm_diag_rep3_seed_invalid")
  }
  invisible(TRUE)
}

diagnostic_smoke_plan <- function(seed_manifest) {
  plan <- diagnostic_plan(seed_manifest)
  nonsp <- plan[plan$slice == "nonspatial" & plan$variant == "rep3", ,
                drop = FALSE][1L, , drop = FALSE]
  ineligible <- plan[plan$slice == "spatial" &
                       plan$sentinel_class %in%
                         c("converged_nonpd", "nonconverged_nonpd"), ,
                     drop = FALSE]
  native <- min(ineligible$native_task_id)
  spatial <- ineligible[ineligible$native_task_id == native, , drop = FALSE]
  spatial <- spatial[match(c("default", "bfgs_continuation", "nlminb5"),
                           spatial$variant), , drop = FALSE]
  out <- rbind(nonsp, spatial)
  out$smoke_task_id <- seq_len(nrow(out))
  out[, c("smoke_task_id", setdiff(names(out), "smoke_task_id")), drop = FALSE]
}

isdm_diag_contract <- function() {
  list(
    schema = ISDM_DIAG_CONTRACT_SCHEMA,
    production_source_sha = ISDM_DIAG_PRODUCTION_SOURCE_SHA,
    production_source_tree = ISDM_DIAG_PRODUCTION_SOURCE_TREE,
    raw_manifest_sha256 = ISDM_DIAG_RAW_MANIFEST_SHA256,
    adjudication_v3_sha256 = ISDM_DIAG_ADJUDICATION_V3_SHA256,
    chain_manifest_sha256 = ISDM_DIAG_CHAIN_MANIFEST_SHA256,
    planned_tasks = 52L,
    smoke_tasks = 4L,
    variants = c("baseline", "rep3", "default", "bfgs_continuation", "nlminb5")
  )
}
