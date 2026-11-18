## CI-13 pure campaign packet: pinned, unrotated standardized loadings.
## This file contains no fitter, simulator, or campaign launcher.

.ci13_campaign_id <- "CI-13"
.ci13_schema_version <- "ci13-outer-v1"
.ci13_seed_base <- 130000000L
.ci13_n_sim <- 5000L
.ci13_gate <- 0.94
`%||%` <- function(x, y) if (is.null(x)) y else x

ci13_campaign_spec <- function() {
  cells <- expand.grid(
    n_units = c(150L, 400L),
    d = c(1L, 2L),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  cells <- cells[order(cells$n_units, cells$d), , drop = FALSE]
  cells$cell_id <- seq_len(nrow(cells))
  rownames(cells) <- NULL
  list(
    campaign_id = .ci13_campaign_id,
    schema_version = .ci13_schema_version,
    seed_base = .ci13_seed_base,
    n_sim = .ci13_n_sim,
    gate = .ci13_gate,
    family = "gaussian",
    tier = "ordinary-unit",
    n_traits = 3L,
    covstruct = "latent(unique=TRUE)",
    rotation = "native-pinned-unrotated",
    confirmatory_map = "diagonal anchors pinned; strict-lower entries promotional",
    target_scale = "standardized-loading",
    interval_method = "joint-delta-wald",
    cells = cells
  )
}

ci13_rep_seed <- function(cell_id, local_rep) {
  cell_id <- as.integer(cell_id)
  local_rep <- as.integer(local_rep)
  if (
    length(cell_id) != 1L ||
      is.na(cell_id) ||
      cell_id < 1L ||
      cell_id > 4L ||
      length(local_rep) != 1L ||
      is.na(local_rep) ||
      local_rep < 1L ||
      local_rep > .ci13_n_sim
  ) {
    stop(
      "CI-13 seed identity is outside the frozen four-cell, 5000-replicate campaign",
      call. = FALSE
    )
  }
  as.integer(.ci13_seed_base + cell_id * 10000L + local_rep)
}

ci13_seed_sets_intersect <- function(cell_a, reps_a, cell_b, reps_b) {
  length(intersect(
    vapply(reps_a, function(rep) ci13_rep_seed(cell_a, rep), integer(1)),
    vapply(reps_b, function(rep) ci13_rep_seed(cell_b, rep), integer(1))
  )) >
    0L
}

ci13_lower_tri_index <- function(n_traits = 3L, d) {
  n_traits <- as.integer(n_traits)
  d <- as.integer(d)
  if (
    length(n_traits) != 1L ||
      length(d) != 1L ||
      is.na(n_traits) ||
      is.na(d) ||
      n_traits < 1L ||
      d < 1L ||
      d > n_traits
  ) {
    stop(
      "CI-13 needs 1 <= d <= n_traits for lower-triangular packing",
      call. = FALSE
    )
  }
  ## Match theta_rr_B exactly: diagonal entries first, then the strict lower
  ## triangle column-by-column.  This is intentionally not R's lower.tri()
  ## vector order and is checked against lambda_packed_index()/build_Lambda.
  diagonal <- data.frame(
    trait = seq_len(d),
    factor = seq_len(d),
    stringsAsFactors = FALSE
  )
  strict_lower <- do.call(
    rbind,
    lapply(seq_len(d), function(k) {
      if (k >= n_traits) {
        return(NULL)
      }
      data.frame(
        trait = seq.int(k + 1L, n_traits),
        factor = k,
        stringsAsFactors = FALSE
      )
    })
  )
  out <- rbind(diagonal, strict_lower)
  out$parameter_index <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

ci13_reconstruct_lambda <- function(packed, n_traits = 3L, d) {
  index <- ci13_lower_tri_index(n_traits, d)
  packed <- as.numeric(packed)
  if (length(packed) != nrow(index) || any(!is.finite(packed))) {
    stop(
      "CI-13 lower-triangular loading vector has the wrong length or non-finite entries",
      call. = FALSE
    )
  }
  lambda <- matrix(0, nrow = n_traits, ncol = d)
  lambda[cbind(index$trait, index$factor)] <- packed
  lambda
}

ci13_psi_sq <- function(log_psi) {
  log_psi <- as.numeric(log_psi)
  if (!length(log_psi) || any(!is.finite(log_psi))) {
    stop("CI-13 log psi must be finite", call. = FALSE)
  }
  exp(log_psi)^2
}

ci13_sigma <- function(lambda, log_psi) {
  if (!is.matrix(lambda) || nrow(lambda) != length(log_psi)) {
    stop("CI-13 Lambda and log psi have incompatible dimensions", call. = FALSE)
  }
  tcrossprod(lambda) + diag(ci13_psi_sq(log_psi), nrow(lambda))
}

ci13_structurally_free_targets <- function(n_traits = 3L, d) {
  index <- ci13_lower_tri_index(n_traits, d)
  ## The native diagonal is numerically anchored through lambda_constraint in
  ## CI-13.  Only strict-lower coordinates remain free after that map and are
  ## promotional; diagonal standardized rows are diagnostic provenance only.
  index <- index[index$trait > index$factor, , drop = FALSE]
  data.frame(
    target_id = sprintf("rho_t%d_k%d", index$trait, index$factor),
    trait = index$trait,
    factor = index$factor,
    estimand = sprintf(
      "Lambda[%d,%d]/sqrt(Sigma[%d,%d])",
      index$trait,
      index$factor,
      index$trait,
      index$trait
    ),
    scale = "standardized-loading",
    stringsAsFactors = FALSE
  )
}

ci13_pinned_diagnostic_targets <- function(n_traits = 3L, d) {
  index <- ci13_lower_tri_index(n_traits, d)
  index <- index[index$trait == index$factor, , drop = FALSE]
  data.frame(
    target_id = sprintf("rho_t%d_k%d", index$trait, index$factor),
    trait = index$trait,
    factor = index$factor,
    estimand = sprintf(
      "Lambda[%d,%d]/sqrt(Sigma[%d,%d])",
      index$trait,
      index$factor,
      index$trait,
      index$trait
    ),
    scale = "standardized-loading",
    status = "pinned-diagnostic",
    stringsAsFactors = FALSE
  )
}

ci13_native_confirmatory_constraint <- function(
  diagonal_anchors,
  n_traits = 3L,
  d
) {
  d <- as.integer(d)
  n_traits <- as.integer(n_traits)
  diagonal_anchors <- as.numeric(diagonal_anchors)
  if (
    length(diagonal_anchors) != d ||
      any(!is.finite(diagonal_anchors)) ||
      d < 1L ||
      d > n_traits
  ) {
    stop(
      "CI-13 needs one finite native diagonal anchor per factor",
      call. = FALSE
    )
  }
  constraint <- matrix(NA_real_, nrow = n_traits, ncol = d)
  constraint[cbind(seq_len(d), seq_len(d))] <- diagonal_anchors
  constraint
}

ci13_validate_target_scale <- function(scale) {
  if (!identical(scale, "standardized-loading")) {
    stop(
      "CI-13 promotional targets must be standardized loadings, not raw or rotated loadings",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

.ci13_unpack_theta <- function(theta, n_traits, d) {
  index <- ci13_lower_tri_index(n_traits, d)
  theta <- as.numeric(theta)
  if (length(theta) != nrow(index) + n_traits || any(!is.finite(theta))) {
    stop(
      "CI-13 theta has incompatible length or non-finite entries",
      call. = FALSE
    )
  }
  list(
    index = index,
    lambda = ci13_reconstruct_lambda(theta[seq_len(nrow(index))], n_traits, d),
    log_psi = theta[nrow(index) + seq_len(n_traits)]
  )
}

.ci13_target_position <- function(index, trait, factor) {
  hit <- which(
    index$trait == as.integer(trait) & index$factor == as.integer(factor)
  )
  if (length(hit) != 1L) {
    stop(
      "CI-13 target is structurally fixed by the lower-triangular constraint",
      call. = FALSE
    )
  }
  hit
}

ci13_standardized_loading <- function(theta, trait, factor, n_traits = 3L, d) {
  pieces <- .ci13_unpack_theta(theta, n_traits, d)
  .ci13_target_position(pieces$index, trait, factor)
  sigma_tt <- sum(pieces$lambda[trait, ]^2) + ci13_psi_sq(pieces$log_psi[trait])
  pieces$lambda[trait, factor] / sqrt(sigma_tt)
}

ci13_standardized_loading_gradient <- function(
  theta,
  trait,
  factor,
  n_traits = 3L,
  d
) {
  pieces <- .ci13_unpack_theta(theta, n_traits, d)
  target_pos <- .ci13_target_position(pieces$index, trait, factor)
  lambda_tk <- pieces$lambda[trait, factor]
  psi_sq <- ci13_psi_sq(pieces$log_psi[trait])
  sigma_tt <- sum(pieces$lambda[trait, ]^2) + psi_sq
  gradient <- numeric(length(theta))
  for (i in seq_len(nrow(pieces$index))) {
    if (pieces$index$trait[i] == trait) {
      j <- pieces$index$factor[i]
      gradient[i] <- -lambda_tk * pieces$lambda[trait, j] / sigma_tt^(3 / 2)
    }
  }
  gradient[target_pos] <- gradient[target_pos] + 1 / sqrt(sigma_tt)
  gradient[nrow(pieces$index) + trait] <- -lambda_tk * psi_sq / sigma_tt^(3 / 2)
  gradient
}

ci13_standardized_loading_gradient_fd <- function(
  theta,
  trait,
  factor,
  n_traits = 3L,
  d,
  eps = 1e-6
) {
  theta <- as.numeric(theta)
  vapply(
    seq_along(theta),
    function(i) {
      plus <- minus <- theta
      plus[i] <- plus[i] + eps
      minus[i] <- minus[i] - eps
      (ci13_standardized_loading(plus, trait, factor, n_traits, d) -
        ci13_standardized_loading(minus, trait, factor, n_traits, d)) /
        (2 * eps)
    },
    numeric(1)
  )
}

ci13_joint_delta_interval <- function(
  theta,
  covariance,
  trait,
  factor,
  n_traits = 3L,
  d,
  level = 0.95
) {
  gradient <- ci13_standardized_loading_gradient(
    theta,
    trait,
    factor,
    n_traits,
    d
  )
  covariance <- as.matrix(covariance)
  if (
    !identical(dim(covariance), c(length(theta), length(theta))) ||
      any(!is.finite(covariance))
  ) {
    stop(
      "CI-13 joint covariance has incompatible dimension or non-finite entries",
      call. = FALSE
    )
  }
  variance <- drop(crossprod(gradient, covariance %*% gradient))
  if (!is.finite(variance) || variance < 0) {
    stop("CI-13 joint delta variance is invalid", call. = FALSE)
  }
  estimate <- ci13_standardized_loading(theta, trait, factor, n_traits, d)
  se <- sqrt(variance)
  critical <- stats::qnorm(1 - (1 - level) / 2)
  list(
    estimate = estimate,
    se = se,
    lower = estimate - critical * se,
    upper = estimate + critical * se,
    gradient = gradient,
    scale = "standardized-loading"
  )
}

ci13_cell_targets <- function(spec, cell_id) {
  cell <- spec$cells[spec$cells$cell_id == as.integer(cell_id), , drop = FALSE]
  if (nrow(cell) != 1L) {
    stop("unknown CI-13 cell", call. = FALSE)
  }
  ci13_structurally_free_targets(spec$n_traits, cell$d)
}

.ci13_target_contracts <- function(manifest) {
  stats::setNames(
    lapply(manifest$selected_cell_ids, function(cell_id) {
      ci13_cell_targets(manifest$spec, cell_id)
    }),
    as.character(manifest$selected_cell_ids)
  )
}

.ci13_outer_key <- function(cell_id, rep) {
  paste(as.integer(cell_id), as.integer(rep), sep = "::")
}
.ci13_manifest_fingerprint <- function(manifest) {
  cells <- apply(
    manifest$spec$cells[, c("cell_id", "n_units", "d")],
    1L,
    paste,
    collapse = ":"
  )
  expected <- vapply(
    manifest$expected,
    function(x) paste(x$cell_id, x$rep, x$seed, sep = ":"),
    character(1)
  )
  targets <- vapply(
    manifest$selected_cell_ids,
    function(cell_id) {
      paste(ci13_cell_targets(manifest$spec, cell_id)$target_id, collapse = ",")
    },
    character(1)
  )
  paste(
    manifest$campaign_id,
    manifest$schema_version,
    manifest$source_sha,
    manifest$seed_base,
    manifest$n_sim,
    manifest$gate,
    paste(cells, collapse = "|"),
    paste(targets, collapse = "|"),
    paste(expected, collapse = "|"),
    sep = "||"
  )
}

ci13_attempt_manifest <- function(
  spec = ci13_campaign_spec(),
  cell_ids = NULL,
  rep_ids = NULL,
  source_sha,
  historical_seeds = integer()
) {
  frozen <- identical(spec$campaign_id, .ci13_campaign_id) &&
    identical(spec$schema_version, .ci13_schema_version) &&
    identical(spec$n_sim, .ci13_n_sim) &&
    identical(spec$seed_base, .ci13_seed_base) &&
    identical(spec$rotation, "native-pinned-unrotated") &&
    identical(
      spec$confirmatory_map,
      "diagonal anchors pinned; strict-lower entries promotional"
    ) &&
    identical(spec$target_scale, "standardized-loading") &&
    nrow(spec$cells) == 4L
  if (!frozen) {
    stop(
      "CI-13 requires the frozen four-cell pinned-loading campaign",
      call. = FALSE
    )
  }
  if (
    missing(source_sha) ||
      !is.character(source_sha) ||
      length(source_sha) != 1L ||
      !nzchar(source_sha)
  ) {
    stop("CI-13 manifest requires a non-empty source SHA", call. = FALSE)
  }
  cell_ids <- sort(unique(as.integer(cell_ids %||% spec$cells$cell_id)))
  rep_ids <- sort(unique(as.integer(rep_ids %||% seq_len(spec$n_sim))))
  if (
    !all(cell_ids %in% spec$cells$cell_id) ||
      anyNA(rep_ids) ||
      any(rep_ids < 1L | rep_ids > spec$n_sim)
  ) {
    stop(
      "CI-13 manifest selection is outside the frozen campaign",
      call. = FALSE
    )
  }
  expected <- unlist(
    lapply(cell_ids, function(cell_id) {
      lapply(rep_ids, function(rep) {
        list(
          cell_id = cell_id,
          rep = rep,
          seed = ci13_rep_seed(cell_id, rep)
        )
      })
    }),
    recursive = FALSE
  )
  seeds <- vapply(expected, `[[`, integer(1), "seed")
  if (anyDuplicated(seeds)) {
    stop("CI-13 manifest has a seed collision", call. = FALSE)
  }
  if (length(intersect(seeds, as.integer(historical_seeds)))) {
    stop("CI-13 manifest conflicts with a historical seed", call. = FALSE)
  }
  manifest <- list(
    campaign_id = spec$campaign_id,
    schema_version = spec$schema_version,
    source_sha = source_sha,
    seed_base = spec$seed_base,
    n_sim = spec$n_sim,
    gate = spec$gate,
    spec = spec,
    selected_cell_ids = cell_ids,
    selected_rep_ids = rep_ids,
    expected = expected
  )
  manifest$fingerprint <- .ci13_manifest_fingerprint(manifest)
  class(manifest) <- "ci13_attempt_manifest"
  manifest
}

ci13_validate_manifest <- function(manifest) {
  needed <- c(
    "campaign_id",
    "schema_version",
    "source_sha",
    "seed_base",
    "n_sim",
    "gate",
    "spec",
    "selected_cell_ids",
    "expected",
    "fingerprint"
  )
  if (!is.list(manifest) || !all(needed %in% names(manifest))) {
    stop("invalid CI-13 attempt manifest", call. = FALSE)
  }
  if (
    !identical(manifest$campaign_id, .ci13_campaign_id) ||
      !identical(manifest$schema_version, .ci13_schema_version) ||
      !identical(manifest$seed_base, .ci13_seed_base) ||
      !identical(manifest$n_sim, .ci13_n_sim) ||
      !identical(manifest$gate, .ci13_gate) ||
      !identical(manifest$spec$rotation, "native-pinned-unrotated") ||
      !identical(
        manifest$spec$confirmatory_map,
        "diagonal anchors pinned; strict-lower entries promotional"
      ) ||
      !identical(manifest$spec$target_scale, "standardized-loading") ||
      !is.character(manifest$source_sha) ||
      length(manifest$source_sha) != 1L ||
      !nzchar(manifest$source_sha)
  ) {
    stop(
      "CI-13 manifest does not match the frozen campaign contract",
      call. = FALSE
    )
  }
  keys <- vapply(
    manifest$expected,
    function(x) .ci13_outer_key(x$cell_id, x$rep),
    character(1)
  )
  if (anyDuplicated(keys)) {
    stop("CI-13 manifest has duplicate outer identities", call. = FALSE)
  }
  if (!identical(manifest$fingerprint, .ci13_manifest_fingerprint(manifest))) {
    stop("CI-13 attempt manifest was modified after freezing", call. = FALSE)
  }
  invisible(TRUE)
}

.ci13_target_results_from_contract <- function(targets, outcomes) {
  target_ids <- targets$target_id
  if (
    is.null(names(outcomes)) ||
      length(outcomes) != length(target_ids) ||
      !setequal(names(outcomes), target_ids)
  ) {
    stop(
      "CI-13 eligible outer attempts require a complete target payload",
      call. = FALSE
    )
  }
  outcomes <- unname(unlist(outcomes[target_ids], use.names = FALSE))
  if (!all(outcomes %in% c("covered", "miss", "ci_failed"))) {
    stop(
      "CI-13 target outcomes must be covered, miss, or ci_failed",
      call. = FALSE
    )
  }
  lapply(seq_along(target_ids), function(i) {
    list(
      target_id = target_ids[i],
      trait = targets$trait[i],
      factor = targets$factor[i],
      estimand = targets$estimand[i],
      scale = targets$scale[i],
      outcome = outcomes[i]
    )
  })
}

.ci13_target_results_from_verified_manifest <- function(
  manifest,
  cell_id,
  outcomes
) {
  .ci13_target_results_from_contract(
    ci13_cell_targets(manifest$spec, cell_id),
    outcomes
  )
}

ci13_target_results_factory <- function(manifest) {
  ci13_validate_manifest(manifest)
  contracts <- .ci13_target_contracts(manifest)
  function(cell_id, outcomes) {
    targets <- contracts[[as.character(as.integer(cell_id))]]
    if (is.null(targets)) {
      stop("unknown CI-13 cell", call. = FALSE)
    }
    .ci13_target_results_from_contract(targets, outcomes)
  }
}

ci13_target_results <- function(manifest, cell_id, outcomes) {
  ci13_target_results_factory(manifest)(cell_id, outcomes)
}

.ci13_validate_target_results_from_contract <- function(
  targets,
  target_results
) {
  if (!is.list(target_results) || length(target_results) != nrow(targets)) {
    stop(
      "CI-13 eligible outer attempts require a complete target payload",
      call. = FALSE
    )
  }
  ids <- vapply(
    target_results,
    function(x) x$target_id %||% NA_character_,
    character(1)
  )
  if (anyDuplicated(ids) || !setequal(ids, targets$target_id)) {
    stop(
      "CI-13 eligible outer attempts require each frozen target exactly once",
      call. = FALSE
    )
  }
  for (result in target_results) {
    hit <- match(result$target_id, targets$target_id)
    if (
      is.na(hit) ||
        !identical(result$estimand, targets$estimand[hit]) ||
        !identical(result$scale, "standardized-loading")
    ) {
      stop(
        "CI-13 raw, rotated, or mismatched target payload is forbidden",
        call. = FALSE
      )
    }
    ci13_validate_target_scale(result$scale)
    if (!result$outcome %in% c("covered", "miss", "ci_failed")) {
      stop(
        "CI-13 target outcomes must be covered, miss, or ci_failed",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

.ci13_validate_target_results <- function(manifest, cell_id, target_results) {
  .ci13_validate_target_results_from_contract(
    ci13_cell_targets(manifest$spec, cell_id),
    target_results
  )
}

.ci13_outer_attempt_from_verified_manifest <- function(
  manifest,
  cell_id,
  rep,
  outcome,
  target_results = NULL,
  attempt_version = 1L,
  target_contracts = NULL
) {
  cell_id <- as.integer(cell_id)
  rep <- as.integer(rep)
  attempt_version <- as.integer(attempt_version)
  key <- .ci13_outer_key(cell_id, rep)
  expected <- vapply(
    manifest$expected,
    function(x) .ci13_outer_key(x$cell_id, x$rep),
    character(1)
  )
  if (!key %in% expected) {
    stop("outer attempt is outside the immutable CI-13 manifest", call. = FALSE)
  }
  allowed <- c(
    "eligible",
    "base_fit_failed",
    "infrastructure_failure",
    "scientific_base_failure"
  )
  if (!outcome %in% allowed) {
    stop("unknown CI-13 outer outcome", call. = FALSE)
  }
  if (identical(outcome, "eligible")) {
    targets <- if (is.null(target_contracts)) {
      ci13_cell_targets(manifest$spec, cell_id)
    } else {
      target_contracts[[as.character(cell_id)]]
    }
    if (is.null(targets)) {
      stop("unknown CI-13 cell", call. = FALSE)
    }
    .ci13_validate_target_results_from_contract(targets, target_results)
  }
  if (!identical(outcome, "eligible") && !is.null(target_results)) {
    stop(
      "non-eligible CI-13 outer attempts cannot carry target results",
      call. = FALSE
    )
  }
  list(
    campaign_id = manifest$campaign_id,
    schema_version = manifest$schema_version,
    source_sha = manifest$source_sha,
    cell_id = cell_id,
    rep = rep,
    seed = ci13_rep_seed(cell_id, rep),
    attempt_version = attempt_version,
    outcome = outcome,
    target_results = target_results
  )
}

## A batch factory performs the expensive immutable fingerprint check exactly
## once, then produces canonical rows against that frozen manifest.  This keeps
## a full 20,000-row pure ledger linear without weakening the pre-run guard.
ci13_outer_attempt_factory <- function(manifest) {
  ci13_validate_manifest(manifest)
  contracts <- .ci13_target_contracts(manifest)
  function(cell_id, rep, outcome, target_results = NULL, attempt_version = 1L) {
    .ci13_outer_attempt_from_verified_manifest(
      manifest,
      cell_id,
      rep,
      outcome,
      target_results,
      attempt_version,
      contracts
    )
  }
}

ci13_outer_attempt <- function(
  manifest,
  cell_id,
  rep,
  outcome,
  target_results = NULL,
  attempt_version = 1L
) {
  ci13_outer_attempt_factory(manifest)(
    cell_id,
    rep,
    outcome,
    target_results,
    attempt_version
  )
}

## Deterministic pure fixture for the full-campaign promotion gate.  It is not a
## runner and cannot hide a scientific failure: ci13_promote() revalidates every
## returned row, seed, and nested target payload before using it.
ci13_synthetic_all_covered_attempts <- function(manifest) {
  ci13_validate_manifest(manifest)
  make_payload <- ci13_target_results_factory(manifest)
  payloads <- stats::setNames(
    lapply(manifest$selected_cell_ids, function(cell_id) {
      targets <- ci13_cell_targets(manifest$spec, cell_id)$target_id
      make_payload(
        cell_id,
        stats::setNames(rep("covered", length(targets)), targets)
      )
    }),
    as.character(manifest$selected_cell_ids)
  )
  lapply(manifest$expected, function(x) {
    list(
      campaign_id = manifest$campaign_id,
      schema_version = manifest$schema_version,
      source_sha = manifest$source_sha,
      cell_id = x$cell_id,
      rep = x$rep,
      seed = x$seed,
      attempt_version = 1L,
      outcome = "eligible",
      target_results = payloads[[as.character(x$cell_id)]]
    )
  })
}

.ci13_attempt_df <- function(attempts) {
  data.frame(
    campaign_id = vapply(attempts, `[[`, character(1), "campaign_id"),
    schema_version = vapply(attempts, `[[`, character(1), "schema_version"),
    source_sha = vapply(attempts, `[[`, character(1), "source_sha"),
    cell_id = vapply(attempts, `[[`, integer(1), "cell_id"),
    rep = vapply(attempts, `[[`, integer(1), "rep"),
    seed = vapply(attempts, `[[`, integer(1), "seed"),
    attempt_version = vapply(attempts, `[[`, integer(1), "attempt_version"),
    outcome = vapply(attempts, `[[`, character(1), "outcome"),
    stringsAsFactors = FALSE
  )
}

.ci13_validate_outer_attempt <- function(
  manifest,
  attempt,
  target_contracts = NULL
) {
  required <- c(
    "campaign_id",
    "schema_version",
    "source_sha",
    "cell_id",
    "rep",
    "seed",
    "attempt_version",
    "outcome",
    "target_results"
  )
  if (!is.list(attempt) || !all(required %in% names(attempt))) {
    stop("invalid CI-13 outer attempt", call. = FALSE)
  }
  if (
    !identical(attempt$campaign_id, manifest$campaign_id) ||
      !identical(attempt$schema_version, manifest$schema_version) ||
      !identical(attempt$source_sha, manifest$source_sha) ||
      !identical(attempt$seed, ci13_rep_seed(attempt$cell_id, attempt$rep))
  ) {
    stop(
      "CI-13 outer attempt seed or provenance conflicts with manifest",
      call. = FALSE
    )
  }
  allowed_outcomes <- c(
    "eligible",
    "base_fit_failed",
    "infrastructure_failure",
    "scientific_base_failure"
  )
  if (
    length(attempt$outcome) != 1L ||
      !attempt$outcome %in% allowed_outcomes
  ) {
    stop("CI-13 outer outcome is not in the frozen contract", call. = FALSE)
  }
  if (
    length(attempt$attempt_version) != 1L ||
      is.na(attempt$attempt_version) ||
      attempt$attempt_version < 1L
  ) {
    stop("CI-13 outer attempt version is invalid", call. = FALSE)
  }
  if (identical(attempt$outcome, "eligible")) {
    targets <- if (is.null(target_contracts)) {
      ci13_cell_targets(manifest$spec, attempt$cell_id)
    } else {
      target_contracts[[as.character(attempt$cell_id)]]
    }
    if (is.null(targets)) {
      stop("unknown CI-13 cell", call. = FALSE)
    }
    .ci13_validate_target_results_from_contract(targets, attempt$target_results)
  } else if (!is.null(attempt$target_results)) {
    stop(
      "CI-13 non-eligible outer attempts cannot carry target payloads",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

ci13_merge_attempts <- function(manifest, attempts) {
  ci13_validate_manifest(manifest)
  if (!is.list(attempts) || !length(attempts)) {
    stop("missing canonical CI-13 outer attempts", call. = FALSE)
  }
  contracts <- .ci13_target_contracts(manifest)
  for (attempt in attempts) {
    .ci13_validate_outer_attempt(manifest, attempt, contracts)
  }
  operational <- .ci13_attempt_df(attempts)
  operational$key <- .ci13_outer_key(operational$cell_id, operational$rep)
  operational$version_key <- paste(
    operational$key,
    operational$attempt_version,
    sep = "::v"
  )
  if (anyDuplicated(operational$version_key)) {
    stop("duplicate canonical CI-13 outer attempts", call. = FALSE)
  }
  expected <- vapply(
    manifest$expected,
    function(x) .ci13_outer_key(x$cell_id, x$rep),
    character(1)
  )
  canonical <- operational[operational$attempt_version == 1L, , drop = FALSE]
  if (any(!expected %in% canonical$key)) {
    stop("missing canonical CI-13 outer attempts", call. = FALSE)
  }
  if (any(!canonical$key %in% expected)) {
    stop("unexpected canonical CI-13 outer attempt", call. = FALSE)
  }
  if (!anyDuplicated(operational$key)) {
    if (any(operational$attempt_version != 1L)) {
      stop("CI-13 retry history must be consecutive", call. = FALSE)
    }
    final <- attempts
  } else {
    for (rows in split(operational, operational$key)) {
      rows <- rows[order(rows$attempt_version), , drop = FALSE]
      if (!identical(rows$attempt_version, seq_len(nrow(rows)))) {
        stop("CI-13 retry history must be consecutive", call. = FALSE)
      }
      if (nrow(rows) > 1L) {
        for (i in 2:nrow(rows)) {
          if (identical(rows$outcome[i - 1L], "scientific_base_failure")) {
            stop(
              "CI-13 scientific failure is terminal and cannot be retried",
              call. = FALSE
            )
          }
          if (!identical(rows$outcome[i - 1L], "infrastructure_failure")) {
            stop(
              "CI-13 retries are permitted only after infrastructure failure",
              call. = FALSE
            )
          }
        }
      }
    }
    final_index <- vapply(
      split(seq_len(nrow(operational)), operational$key),
      function(i) i[which.max(operational$attempt_version[i])],
      integer(1)
    )
    final <- attempts[final_index]
  }
  list(
    manifest = manifest,
    attempts = attempts,
    operational = operational,
    canonical = canonical,
    final = final
  )
}

.ci13_clustered_mcse <- function(eligible, target_id) {
  if (!length(eligible)) {
    return(NA_real_)
  }
  covered <- vapply(
    eligible,
    function(x) {
      result <- Filter(
        function(y) identical(y$target_id, target_id),
        x$target_results
      )[[1L]]
      identical(result$outcome, "covered")
    },
    logical(1)
  )
  reps <- vapply(eligible, `[[`, integer(1), "rep")
  means <- vapply(split(covered, reps), mean, numeric(1))
  if (length(means) <= 1L) {
    return(0)
  }
  sqrt(stats::var(means) / length(means))
}

ci13_summarise <- function(merged) {
  manifest <- merged$manifest
  rows <- list()
  for (cell_id in manifest$selected_cell_ids) {
    outers <- Filter(function(x) identical(x$cell_id, cell_id), merged$final)
    eligible <- Filter(function(x) identical(x$outcome, "eligible"), outers)
    for (target in seq_len(nrow(ci13_cell_targets(manifest$spec, cell_id)))) {
      target_row <- ci13_cell_targets(manifest$spec, cell_id)[
        target,
        ,
        drop = FALSE
      ]
      outcomes <- if (length(eligible)) {
        vapply(
          eligible,
          function(x) {
            Filter(
              function(y) identical(y$target_id, target_row$target_id),
              x$target_results
            )[[1L]]$outcome
          },
          character(1)
        )
      } else {
        character(0)
      }
      coverage <- if (length(eligible)) {
        mean(outcomes == "covered")
      } else {
        NA_real_
      }
      mcse <- .ci13_clustered_mcse(eligible, target_row$target_id)
      rows[[length(rows) + 1L]] <- data.frame(
        cell_id = cell_id,
        target_id = target_row$target_id,
        trait = target_row$trait,
        factor = target_row$factor,
        estimand = target_row$estimand,
        scale = target_row$scale,
        n_outer = length(outers),
        n_eligible = length(eligible),
        n_covered = sum(outcomes == "covered"),
        n_ci_failed = sum(outcomes == "ci_failed"),
        base_fit_failed = sum(vapply(
          outers,
          function(x) identical(x$outcome, "base_fit_failed"),
          logical(1)
        )),
        scientific_failures = sum(vapply(
          outers,
          function(x) identical(x$outcome, "scientific_base_failure"),
          logical(1)
        )),
        infrastructure_failures = sum(vapply(
          outers,
          function(x) identical(x$outcome, "infrastructure_failure"),
          logical(1)
        )),
        availability_rate = if (length(outers)) {
          length(eligible) / length(outers)
        } else {
          NA_real_
        },
        coverage = coverage,
        mcse = mcse,
        lower_2mcse = coverage - 2 * mcse,
        stringsAsFactors = FALSE
      )
    }
  }
  targets <- do.call(rbind, rows)
  rownames(targets) <- NULL
  list(
    targets = targets,
    availability = targets[, c(
      "cell_id",
      "target_id",
      "n_outer",
      "n_eligible",
      "base_fit_failed",
      "availability_rate"
    )]
  )
}

ci13_promote <- function(manifest, attempts) {
  merged <- ci13_merge_attempts(manifest, attempts)
  summary <- ci13_summarise(merged)
  targets <- summary$targets
  ## Availability and every failure mechanism are reported, but are not an
  ## extra promotion floor.  Promotion is the pre-registered coverage/lower
  ## band rule, applied separately to every structurally-free target.
  target_ok <- !is.na(targets$coverage) &
    !is.na(targets$mcse) &
    targets$coverage >= manifest$gate &
    targets$lower_2mcse >= manifest$gate
  cell_promotion <- aggregate(target_ok, list(cell_id = targets$cell_id), all)
  names(cell_promotion)[2L] <- "promote"
  campaign_complete <- identical(as.integer(manifest$selected_cell_ids), 1:4) &&
    identical(as.integer(manifest$selected_rep_ids), seq_len(.ci13_n_sim)) &&
    length(manifest$expected) == 4L * .ci13_n_sim
  promote <- isTRUE(campaign_complete) && all(target_ok)
  list(
    merged = merged,
    targets = targets,
    availability = summary$availability,
    cell_promotion = cell_promotion,
    promotion = list(
      promote = promote,
      campaign_complete = campaign_complete,
      gate = manifest$gate,
      reason = if (!campaign_complete) {
        "incomplete CI-13 campaign; promotion is fail-closed"
      } else if (all(target_ok)) {
        "every structurally free target passed"
      } else {
        "one or more structurally free targets failed"
      },
      availability_note = "Availability is reported only and is not a promotion criterion."
    )
  )
}
