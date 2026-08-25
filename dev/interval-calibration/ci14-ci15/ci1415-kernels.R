## CI-14/15 pure interval-calibration campaign packet.
##
## This file is deliberately free of simulation and fitting code.  It freezes
## target identities, DGP/fit alignment, seed identities, immutable manifests,
## and all-attempt retention for a separately approved coverage campaign.

.ci1415_schema_version <- "ci1415-outer-v1"
.ci1415_truth_schema <- "ci1415-truth-v1"
.ci1415_n_sim <- 5000L
.ci1415_gate <- 0.94
.ci1415_seed_base <- c(CI14 = 140000000L, CI15 = 150000000L)

`%||%` <- function(x, y) if (is.null(x)) y else x

.ci1415_stop <- function(...) stop(..., call. = FALSE)

.ci1415_targets <- function(route) {
  traits <- switch(
    route,
    CI14 = paste0("trait", 1:3),
    CI15_PHYLO = paste0("trait", 1:2),
    CI15_LOADINGS = paste0("trait", 1:3),
    .ci1415_stop("unknown CI-14/15 route")
  )
  if (identical(route, "CI14")) {
    return(c(
      lapply(traits, function(trait) {
        list(
          target_id = paste0("unique_psi_slope_sd:", trait),
          trait = trait,
          component = "unique_psi",
          estimand = "psi_slope[trait]",
          extractor = "slope_sd_ci()$estimate"
        )
      }),
      lapply(traits, function(trait) {
        list(
          target_id = paste0("total_marginal_slope_sd:", trait),
          trait = trait,
          component = "total_marginal",
          estimand = "sqrt(diag(Lambda_slope Lambda_slope^T + Psi_slope))[trait]",
          extractor = "slope_sd_ci()$total_sd"
        )
      })
    ))
  }
  component <- "total_marginal"
  prefix <- if (identical(route, "CI15_PHYLO")) {
    "phylo_cholesky_marginal_slope_sd"
  } else {
    "loadings_only_marginal_slope_sd"
  }
  estimand <- if (identical(route, "CI15_PHYLO")) {
    "sqrt(diag(L_phy L_phy^T))[interleaved slope coordinate]"
  } else {
    "sqrt(diag(Lambda_slope Lambda_slope^T))[trait]"
  }
  extractor <- if (identical(route, "CI15_PHYLO")) {
    "slope_sd_ci()$estimate (ADREPORT sd_b)"
  } else {
    "slope_sd_ci()$estimate (ADREPORT sd_rr_B_slope)"
  }
  lapply(traits, function(trait) {
    list(
      target_id = paste0(prefix, ":", trait),
      trait = trait,
      component = component,
      estimand = estimand,
      extractor = extractor
    )
  })
}

.ci1415_target_ids <- function(route) {
  vapply(.ci1415_targets(route), `[[`, character(1), "target_id")
}

.ci1415_truth_fingerprint <- function(x) {
  pieces <- c(
    x$truth_schema,
    x$route,
    x$fit_contract$covstruct,
    x$fit_contract$extractor,
    x$fit_contract$psi_contract,
    as.character(x$traits),
    as.character(x$psi_slope),
    as.character(x$lambda_slope),
    as.character(x$L),
    as.character(x$slope_positions)
  )
  paste(pieces[!is.na(pieces)], collapse = "||")
}

## Symbolic truth first.  The CI-14 diagonal and shared blocks are both
## present: Psi_slope = diag(psi_slope^2), Sigma_slope = Lambda Lambda^T +
## Psi_slope.  CI-15 loadings-only is deliberately the Psi=0 subset.
ci1415_truth <- function(route = c("CI14", "CI15_PHYLO", "CI15_LOADINGS")) {
  route <- match.arg(route)
  out <- switch(
    route,
    CI14 = {
      lambda_slope <- rbind(c(0.42, 0.00), c(0.22, 0.37), c(-0.16, 0.31))
      psi_slope <- c(0.29, 0.34, 0.26)
      list(
        truth_schema = .ci1415_truth_schema,
        route = "ordinary_augmented_latent_unique",
        traits = paste0("trait", 1:3),
        lambda_slope = lambda_slope,
        psi_slope = psi_slope,
        unique_slope_sd = psi_slope,
        total_slope_sd = sqrt(rowSums(lambda_slope^2) + psi_slope^2),
        L = NULL,
        slope_positions = NULL,
        fit_contract = list(
          covstruct = "latent(0 + trait + (0 + trait):x | individual, d = 2, unique = TRUE)",
          extractor = "slope_sd_ci()$estimate plus slope_sd_ci()$total_sd",
          psi_contract = "Psi_slope is nonzero and fitted"
        )
      )
    },
    CI15_PHYLO = {
      ## Interleaved coordinates are (intercept_t1, slope_t1,
      ## intercept_t2, slope_t2), matching R/slope-sd-ci.R.
      L <- matrix(0, 4L, 4L)
      L[lower.tri(L, diag = TRUE)] <- c(
        0.80,
        0.20,
        -0.10,
        0.15,
        0.60,
        0.10,
        -0.05,
        0.50,
        0.10,
        0.45
      )
      list(
        truth_schema = .ci1415_truth_schema,
        route = "phylo_cholesky",
        traits = paste0("trait", 1:2),
        lambda_slope = NULL,
        psi_slope = numeric(),
        L = L,
        slope_positions = c(2L, 4L),
        marginal_slope_sd = sqrt(diag(L %*% t(L)))[c(2L, 4L)],
        fit_contract = list(
          covstruct = "phylo_dep(0 + trait + (0 + trait):x | species)",
          extractor = "slope_sd_ci()$estimate via ADREPORT sd_b",
          psi_contract = "no diagonal-Psi companion in this Cholesky route"
        )
      )
    },
    CI15_LOADINGS = {
      lambda_slope <- rbind(c(0.38, 0.00), c(0.18, 0.33), c(-0.12, 0.27))
      list(
        truth_schema = .ci1415_truth_schema,
        route = "ordinary_loadings_only",
        traits = paste0("trait", 1:3),
        lambda_slope = lambda_slope,
        psi_slope = rep(0, 3L),
        L = NULL,
        slope_positions = NULL,
        marginal_slope_sd = sqrt(rowSums(lambda_slope^2)),
        fit_contract = list(
          covstruct = "latent(0 + trait + (0 + trait):x | individual, d = 2, unique = FALSE)",
          extractor = "slope_sd_ci()$estimate via ADREPORT sd_rr_B_slope",
          psi_contract = "Psi_slope is exactly zero in DGP and fit"
        )
      )
    }
  )
  out$fingerprint <- .ci1415_truth_fingerprint(out)
  out
}

## This is the intentionally old fixture that must never seed CI-15
## loadings-only calibration: it has a nonzero diagonal Psi omitted by the
## fitted model, so no common marginal target exists.
ci1415_old_misspecified_loadings_fixture <- function() {
  out <- ci1415_truth("CI15_LOADINGS")
  out$psi_slope <- c(0.23, 0.19, 0.21)
  out$marginal_slope_sd <- sqrt(rowSums(out$lambda_slope^2) + out$psi_slope^2)
  out$fixture_type <- "negative_control_misspecified_psi_positive"
  out$fingerprint <- .ci1415_truth_fingerprint(out)
  out
}

ci1415_validate_truth <- function(kind, truth) {
  if (
    !is.list(truth) ||
      !identical(truth$truth_schema, .ci1415_truth_schema) ||
      !is.character(truth$fingerprint) ||
      length(truth$fingerprint) != 1L ||
      !identical(truth$fingerprint, .ci1415_truth_fingerprint(truth))
  ) {
    .ci1415_stop("CI-14/15 truth schema mismatch or modified truth fingerprint")
  }
  if (identical(kind, "CI14")) {
    if (
      !identical(truth$route, "ordinary_augmented_latent_unique") ||
        !identical(dim(truth$lambda_slope), c(3L, 2L)) ||
        length(truth$psi_slope) != 3L ||
        any(!is.finite(truth$psi_slope)) ||
        any(truth$psi_slope <= 0) ||
        !isTRUE(all.equal(truth$unique_slope_sd, truth$psi_slope)) ||
        !isTRUE(all.equal(
          truth$total_slope_sd,
          sqrt(rowSums(truth$lambda_slope^2) + truth$psi_slope^2)
        )) ||
        !identical(
          truth$fit_contract$psi_contract,
          "Psi_slope is nonzero and fitted"
        )
    ) {
      .ci1415_stop(
        "CI-14 truth does not match the unique-Psi plus total-marginal estimand"
      )
    }
  } else if (identical(kind, "CI15_PHYLO")) {
    if (
      !identical(truth$route, "phylo_cholesky") ||
        !identical(dim(truth$L), c(4L, 4L)) ||
        !identical(as.integer(truth$slope_positions), c(2L, 4L)) ||
        !isTRUE(all.equal(
          truth$marginal_slope_sd,
          sqrt(diag(truth$L %*% t(truth$L)))[truth$slope_positions]
        ))
    ) {
      .ci1415_stop(
        "CI-15 phylogenetic Cholesky truth has a route, trait, or packing-order mismatch"
      )
    }
  } else if (identical(kind, "CI15_LOADINGS")) {
    if (
      !identical(truth$route, "ordinary_loadings_only") ||
        !identical(dim(truth$lambda_slope), c(3L, 2L)) ||
        !identical(as.numeric(truth$psi_slope), rep(0, 3L))
    ) {
      .ci1415_stop(
        "CI-15 loadings-only calibration requires Psi = 0 in both DGP and fit"
      )
    }
    if (
      !isTRUE(all.equal(
        truth$marginal_slope_sd,
        sqrt(rowSums(truth$lambda_slope^2))
      ))
    ) {
      .ci1415_stop(
        "CI-15 loadings-only marginal target does not match Lambda Lambda^T"
      )
    }
  } else {
    .ci1415_stop("unknown CI-14/15 truth kind")
  }
  invisible(TRUE)
}

ci1415_campaign_spec <- function(packet = c("CI14", "CI15")) {
  packet <- match.arg(packet)
  if (identical(packet, "CI14")) {
    cells <- data.frame(
      cell_id = 1:2,
      route = "CI14",
      n_ind = c(50L, 100L),
      n_sp = NA_integer_,
      n_traits = 3L,
      rank = 2L,
      repeats = 6L,
      stringsAsFactors = FALSE
    )
    return(list(
      packet = packet,
      campaign_id = "CI-14",
      schema_version = .ci1415_schema_version,
      seed_base = unname(.ci1415_seed_base[[packet]]),
      n_sim = .ci1415_n_sim,
      gate = .ci1415_gate,
      family = "gaussian",
      tier = "ordinary-unit-slope",
      interval_method = "wald_log_scale",
      repeats = 6L,
      cells = cells,
      targets = .ci1415_targets("CI14"),
      truth = ci1415_truth("CI14")
    ))
  }
  cells <- data.frame(
    cell_id = 1:4,
    route = c("CI15_PHYLO", "CI15_PHYLO", "CI15_LOADINGS", "CI15_LOADINGS"),
    n_ind = c(NA_integer_, NA_integer_, 100L, 200L),
    n_sp = c(70L, 140L, NA_integer_, NA_integer_),
    n_traits = c(2L, 2L, 3L, 3L),
    rank = c(NA_integer_, NA_integer_, 2L, 2L),
    repeats = c(6L, 6L, 6L, 6L),
    stringsAsFactors = FALSE
  )
  list(
    packet = packet,
    campaign_id = "CI-15",
    schema_version = .ci1415_schema_version,
    seed_base = unname(.ci1415_seed_base[[packet]]),
    n_sim = .ci1415_n_sim,
    gate = .ci1415_gate,
    family = "gaussian",
    tier = "mixed-slope-routes",
    interval_method = "wald_log_scale",
    repeats = 6L,
    cells = cells,
    targets = list(
      CI15_PHYLO = .ci1415_targets("CI15_PHYLO"),
      CI15_LOADINGS = .ci1415_targets("CI15_LOADINGS")
    ),
    truth = list(
      CI15_PHYLO = ci1415_truth("CI15_PHYLO"),
      CI15_LOADINGS = ci1415_truth("CI15_LOADINGS")
    )
  )
}

.ci1415_validate_spec <- function(spec) {
  if (
    !is.list(spec) ||
      !spec$packet %in% c("CI14", "CI15") ||
      !identical(spec$schema_version, .ci1415_schema_version) ||
      !identical(spec$n_sim, .ci1415_n_sim) ||
      !identical(spec$gate, .ci1415_gate) ||
      !identical(spec$seed_base, unname(.ci1415_seed_base[[spec$packet]]))
  ) {
    .ci1415_stop("CI-14/15 specification does not match the frozen campaign")
  }
  if (identical(spec$packet, "CI14")) {
    if (
      !identical(spec$cells$n_ind, c(50L, 100L)) ||
        nrow(spec$cells) != 2L ||
        !identical(spec$repeats, 6L) ||
        length(spec$targets) != 6L
    ) {
      .ci1415_stop("CI-14 must retain its two-cell, three-trait, d=2 contract")
    }
    ci1415_validate_truth("CI14", spec$truth)
  } else {
    if (
      nrow(spec$cells) != 4L ||
        !identical(spec$cells$n_sp[1:2], c(70L, 140L)) ||
        !identical(spec$cells$n_ind[3:4], c(100L, 200L)) ||
        !identical(
          spec$cells$route,
          c("CI15_PHYLO", "CI15_PHYLO", "CI15_LOADINGS", "CI15_LOADINGS")
        )
    ) {
      .ci1415_stop(
        "CI-15 must retain its distinct two-cell phylo and loadings-only routes"
      )
    }
    ci1415_validate_truth("CI15_PHYLO", spec$truth$CI15_PHYLO)
    ci1415_validate_truth("CI15_LOADINGS", spec$truth$CI15_LOADINGS)
  }
  invisible(TRUE)
}

ci1415_rep_seed <- function(packet, cell_id, rep) {
  packet <- match.arg(packet, c("CI14", "CI15"))
  cell_id <- as.integer(cell_id)
  rep <- as.integer(rep)
  n_cells <- if (identical(packet, "CI14")) 2L else 4L
  if (
    length(cell_id) != 1L ||
      is.na(cell_id) ||
      cell_id < 1L ||
      cell_id > n_cells ||
      length(rep) != 1L ||
      is.na(rep) ||
      rep < 1L ||
      rep > .ci1415_n_sim
  ) {
    .ci1415_stop("CI-14/15 seed identity is outside the frozen campaign")
  }
  as.integer(.ci1415_seed_base[[packet]] + cell_id * 10000L + rep)
}

.ci1415_route_for_cell <- function(spec, cell_id) {
  hit <- match(as.integer(cell_id), spec$cells$cell_id)
  if (is.na(hit)) {
    .ci1415_stop("cell is outside the frozen CI-14/15 specification")
  }
  as.character(spec$cells$route[[hit]])
}

.ci1415_truth_for_route <- function(spec, route) {
  if (identical(spec$packet, "CI14")) {
    return(spec$truth)
  }
  spec$truth[[route]]
}

.ci1415_manifest_fingerprint <- function(manifest) {
  expected <- vapply(
    manifest$expected,
    function(x) {
      paste(
        x$cell_id,
        x$rep,
        x$seed,
        x$route,
        paste(x$target_ids, collapse = ","),
        x$truth_fingerprint,
        sep = ":"
      )
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
    paste(expected, collapse = "|"),
    sep = "||"
  )
}

ci1415_attempt_manifest <- function(
  packet = c("CI14", "CI15"),
  cell_ids = NULL,
  rep_ids = NULL,
  source_sha
) {
  packet <- match.arg(packet)
  spec <- ci1415_campaign_spec(packet)
  .ci1415_validate_spec(spec)
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    .ci1415_stop("CI-14/15 manifest requires a non-empty source SHA")
  }
  cell_ids <- sort(unique(as.integer(cell_ids %||% spec$cells$cell_id)))
  rep_ids <- sort(unique(as.integer(rep_ids %||% seq_len(spec$n_sim))))
  if (
    !all(cell_ids %in% spec$cells$cell_id) ||
      anyNA(rep_ids) ||
      any(rep_ids < 1L | rep_ids > spec$n_sim)
  ) {
    .ci1415_stop("CI-14/15 manifest selection is outside the frozen campaign")
  }
  expected <- unlist(
    lapply(cell_ids, function(cell_id) {
      route <- .ci1415_route_for_cell(spec, cell_id)
      truth <- .ci1415_truth_for_route(spec, route)
      lapply(rep_ids, function(rep) {
        list(
          cell_id = cell_id,
          rep = rep,
          seed = ci1415_rep_seed(packet, cell_id, rep),
          route = route,
          target_ids = .ci1415_target_ids(route),
          truth_fingerprint = truth$fingerprint
        )
      })
    }),
    recursive = FALSE
  )
  manifest <- list(
    packet = packet,
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
  manifest$fingerprint <- .ci1415_manifest_fingerprint(manifest)
  class(manifest) <- "ci1415_attempt_manifest"
  manifest
}

ci1415_validate_manifest <- function(manifest) {
  need <- c(
    "packet",
    "campaign_id",
    "schema_version",
    "source_sha",
    "seed_base",
    "n_sim",
    "gate",
    "spec",
    "selected_cell_ids",
    "selected_rep_ids",
    "expected",
    "fingerprint"
  )
  if (!is.list(manifest) || !all(need %in% names(manifest))) {
    .ci1415_stop("invalid CI-14/15 manifest")
  }
  .ci1415_validate_spec(manifest$spec)
  if (
    !identical(manifest$packet, manifest$spec$packet) ||
      !identical(manifest$campaign_id, manifest$spec$campaign_id) ||
      !identical(manifest$schema_version, .ci1415_schema_version) ||
      !identical(manifest$source_sha, as.character(manifest$source_sha)) ||
      !nzchar(manifest$source_sha) ||
      !identical(manifest$seed_base, manifest$spec$seed_base) ||
      !identical(manifest$n_sim, .ci1415_n_sim) ||
      !identical(manifest$gate, .ci1415_gate)
  ) {
    .ci1415_stop(
      "CI-14/15 manifest does not match the frozen campaign contract"
    )
  }
  keys <- vapply(
    manifest$expected,
    function(x) paste(x$cell_id, x$rep, x$seed, sep = "::"),
    character(1)
  )
  if (length(keys) != length(unique(keys))) {
    .ci1415_stop("CI-14/15 manifest has duplicate outer rows")
  }
  for (x in manifest$expected) {
    route <- .ci1415_route_for_cell(manifest$spec, x$cell_id)
    truth <- .ci1415_truth_for_route(manifest$spec, route)
    if (
      !identical(x$route, route) ||
        !identical(x$target_ids, .ci1415_target_ids(route)) ||
        !identical(x$truth_fingerprint, truth$fingerprint) ||
        !identical(x$seed, ci1415_rep_seed(manifest$packet, x$cell_id, x$rep))
    ) {
      .ci1415_stop(
        "CI-14/15 manifest has a route, target, truth, or seed mismatch"
      )
    }
  }
  if (
    !identical(manifest$fingerprint, .ci1415_manifest_fingerprint(manifest))
  ) {
    .ci1415_stop("CI-14/15 manifest was modified after freezing")
  }
  invisible(TRUE)
}

.ci1415_expected <- function(manifest, cell_id, rep) {
  hit <- vapply(
    manifest$expected,
    function(x) {
      identical(as.integer(x$cell_id), as.integer(cell_id)) &&
        identical(as.integer(x$rep), as.integer(rep))
    },
    logical(1)
  )
  if (sum(hit) != 1L) {
    .ci1415_stop("outer attempt is outside the immutable CI-14/15 manifest")
  }
  manifest$expected[[which(hit)]]
}

ci1415_target_results <- function(
  manifest,
  route,
  outcome = c("covered", "miss", "ci_failed")
) {
  ci1415_validate_manifest(manifest)
  outcome <- match.arg(outcome)
  target_ids <- .ci1415_target_ids(route)
  if (!route %in% vapply(manifest$expected, `[[`, character(1), "route")) {
    .ci1415_stop("target route is absent from the manifest")
  }
  truth <- .ci1415_truth_for_route(manifest$spec, route)
  targets <- .ci1415_targets(route)
  lapply(seq_along(targets), function(i) {
    c(
      targets[[i]],
      list(
        outcome = outcome,
        truth_fingerprint = truth$fingerprint
      )
    )
  })
}

.ci1415_validate_target_results <- function(expected, results) {
  if (!is.list(results) || length(results) != length(expected$target_ids)) {
    .ci1415_stop(
      "eligible CI-14/15 outer attempts require a complete target payload"
    )
  }
  ids <- vapply(
    results,
    function(x) x$target_id %||% NA_character_,
    character(1)
  )
  if (anyDuplicated(ids) || !identical(ids, expected$target_ids)) {
    .ci1415_stop(
      "eligible CI-14/15 target order or identities do not match the frozen route"
    )
  }
  targets <- .ci1415_targets(expected$route)
  for (i in seq_along(results)) {
    result <- results[[i]]
    target <- targets[[i]]
    if (
      !identical(result$trait, target$trait) ||
        !identical(result$component, target$component) ||
        !identical(result$estimand, target$estimand) ||
        !identical(result$extractor, target$extractor) ||
        !identical(result$truth_fingerprint, expected$truth_fingerprint) ||
        !result$outcome %in% c("covered", "miss", "ci_failed")
    ) {
      .ci1415_stop(
        "CI-14/15 target payload has a trait, component, route, or truth mismatch"
      )
    }
  }
  invisible(TRUE)
}

ci1415_outer_attempt <- function(
  manifest,
  cell_id,
  rep,
  outcome = c(
    "eligible",
    "base_fit_failed",
    "scientific_failure",
    "infrastructure_failure"
  ),
  target_results = NULL,
  attempt_version = 1L
) {
  ci1415_validate_manifest(manifest)
  outcome <- match.arg(outcome)
  cell_id <- as.integer(cell_id)
  rep <- as.integer(rep)
  attempt_version <- as.integer(attempt_version)
  expected <- .ci1415_expected(manifest, cell_id, rep)
  if (is.na(attempt_version) || attempt_version < 1L) {
    .ci1415_stop("invalid CI-14/15 attempt version")
  }
  if (identical(outcome, "eligible")) {
    .ci1415_validate_target_results(expected, target_results)
  } else if (!is.null(target_results)) {
    .ci1415_stop(
      "non-eligible CI-14/15 outer attempts cannot carry target results"
    )
  }
  list(
    packet = manifest$packet,
    campaign_id = manifest$campaign_id,
    schema_version = manifest$schema_version,
    source_sha = manifest$source_sha,
    cell_id = cell_id,
    rep = rep,
    seed = expected$seed,
    route = expected$route,
    truth_fingerprint = expected$truth_fingerprint,
    attempt_version = attempt_version,
    outcome = outcome,
    target_results = target_results
  )
}

.ci1415_attempt_table <- function(attempts) {
  if (!length(attempts)) {
    return(data.frame())
  }
  data.frame(
    packet = vapply(attempts, `[[`, character(1), "packet"),
    campaign_id = vapply(attempts, `[[`, character(1), "campaign_id"),
    schema_version = vapply(attempts, `[[`, character(1), "schema_version"),
    source_sha = vapply(attempts, `[[`, character(1), "source_sha"),
    cell_id = vapply(attempts, `[[`, integer(1), "cell_id"),
    rep = vapply(attempts, `[[`, integer(1), "rep"),
    seed = vapply(attempts, `[[`, integer(1), "seed"),
    route = vapply(attempts, `[[`, character(1), "route"),
    truth_fingerprint = vapply(
      attempts,
      `[[`,
      character(1),
      "truth_fingerprint"
    ),
    attempt_version = vapply(attempts, `[[`, integer(1), "attempt_version"),
    outcome = vapply(attempts, `[[`, character(1), "outcome"),
    stringsAsFactors = FALSE
  )
}

ci1415_merge_attempts <- function(manifest, attempts) {
  ci1415_validate_manifest(manifest)
  if (!is.list(attempts) || !length(attempts)) {
    .ci1415_stop("missing canonical CI-14/15 outer attempts")
  }
  tab <- .ci1415_attempt_table(attempts)
  if (
    any(tab$packet != manifest$packet) ||
      any(tab$campaign_id != manifest$campaign_id) ||
      any(tab$schema_version != manifest$schema_version) ||
      any(tab$source_sha != manifest$source_sha)
  ) {
    .ci1415_stop(
      "CI-14/15 attempt campaign identity conflicts with its manifest"
    )
  }
  tab$key <- paste(tab$cell_id, tab$rep, tab$seed, sep = "::")
  tab$version_key <- paste(tab$key, tab$attempt_version, sep = "::v")
  if (anyDuplicated(tab$version_key)) {
    .ci1415_stop("duplicate canonical CI-14/15 outer attempts")
  }
  expected_keys <- vapply(
    manifest$expected,
    function(x) paste(x$cell_id, x$rep, x$seed, sep = "::"),
    character(1)
  )
  if (any(!tab$key %in% expected_keys)) {
    .ci1415_stop("CI-14/15 attempt is outside immutable manifest")
  }
  expected_identity_keys <- vapply(
    manifest$expected,
    function(x) paste(x$cell_id, x$rep, sep = "::"),
    character(1)
  )
  expected_by_identity <- stats::setNames(
    manifest$expected,
    expected_identity_keys
  )
  for (i in seq_along(attempts)) {
    attempt <- attempts[[i]]
    expected <- expected_by_identity[[paste(
      attempt$cell_id,
      attempt$rep,
      sep = "::"
    )]]
    if (is.null(expected)) {
      .ci1415_stop("outer attempt is outside the immutable CI-14/15 manifest")
    }
    if (
      !identical(attempt$seed, expected$seed) ||
        !identical(attempt$route, expected$route) ||
        !identical(attempt$truth_fingerprint, expected$truth_fingerprint)
    ) {
      .ci1415_stop("CI-14/15 attempt has a seed, route, or truth mismatch")
    }
    if (identical(attempt$outcome, "eligible")) {
      .ci1415_validate_target_results(expected, attempt$target_results)
    }
    if (
      !identical(attempt$outcome, "eligible") &&
        !is.null(attempt$target_results)
    ) {
      .ci1415_stop(
        "non-eligible CI-14/15 outer attempts cannot carry target results"
      )
    }
  }
  rows_by_key <- split(seq_len(nrow(tab)), tab$key)
  if (any(!expected_keys %in% names(rows_by_key))) {
    .ci1415_stop("missing canonical outer attempt")
  }
  final_index <- integer(length(expected_keys))
  for (i in seq_along(expected_keys)) {
    rows <- rows_by_key[[expected_keys[[i]]]]
    rows <- rows[order(tab$attempt_version[rows])]
    if (!identical(tab$attempt_version[rows], seq_along(rows))) {
      .ci1415_stop(
        "CI-14/15 retry history must be consecutively versioned from one"
      )
    }
    if (length(rows) > 1L) {
      for (j in 2:length(rows)) {
        previous <- tab$outcome[rows[[j - 1L]]]
        if (identical(previous, "scientific_failure")) {
          .ci1415_stop(
            "CI-14/15 scientific failures are terminal and cannot be retried"
          )
        }
        if (!identical(previous, "infrastructure_failure")) {
          .ci1415_stop(
            "CI-14/15 retries are permitted only after infrastructure failure"
          )
        }
      }
    }
    final_index[[i]] <- rows[[length(rows)]]
  }
  canonical <- tab[
    final_index,
    setdiff(names(tab), c("key", "version_key")),
    drop = FALSE
  ]
  canonical$target_results <- I(lapply(final_index, function(i) {
    attempts[[i]]$target_results
  }))
  rownames(canonical) <- NULL
  list(
    manifest = manifest,
    attempts = attempts,
    attempt_table = tab,
    canonical = canonical
  )
}

.ci1415_clustered_mcse <- function(covered) {
  covered <- as.numeric(covered)
  if (!length(covered)) {
    return(NA_real_)
  }
  if (length(covered) == 1L) {
    return(0)
  }
  stats::sd(covered) / sqrt(length(covered))
}

ci1415_summarise <- function(merged) {
  manifest <- merged$manifest
  canonical <- merged$canonical
  rows <- lapply(manifest$selected_cell_ids, function(cell_id) {
    route <- .ci1415_route_for_cell(manifest$spec, cell_id)
    targets <- .ci1415_targets(route)
    outer <- canonical[canonical$cell_id == cell_id, , drop = FALSE]
    eligible <- outer[outer$outcome == "eligible", , drop = FALSE]
    do.call(
      rbind,
      lapply(targets, function(target) {
        target_outcomes <- if (nrow(eligible)) {
          vapply(
            eligible$target_results,
            function(payload) {
              hit <- Filter(
                function(x) identical(x$target_id, target$target_id),
                payload
              )
              hit[[1L]]$outcome
            },
            character(1)
          )
        } else {
          character()
        }
        covered <- target_outcomes == "covered"
        data.frame(
          packet = manifest$packet,
          cell_id = as.integer(cell_id),
          route = route,
          target_id = target$target_id,
          trait = target$trait,
          component = target$component,
          n_outer = nrow(outer),
          eligible = length(target_outcomes),
          covered = sum(covered),
          miss = sum(target_outcomes %in% c("miss", "ci_failed")),
          ci_failed = sum(target_outcomes == "ci_failed"),
          coverage = if (length(covered)) mean(covered) else NA_real_,
          mcse = .ci1415_clustered_mcse(covered),
          availability = if (nrow(outer)) {
            length(target_outcomes) / nrow(outer)
          } else {
            NA_real_
          },
          base_fit_failed = sum(outer$outcome == "base_fit_failed"),
          scientific_failure = sum(outer$outcome == "scientific_failure"),
          infrastructure_failure = sum(
            outer$outcome == "infrastructure_failure"
          ),
          stringsAsFactors = FALSE
        )
      })
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

ci1415_promote <- function(manifest, attempts) {
  if (
    !is.list(manifest) ||
      length(manifest$packet) != 1L ||
      !manifest$packet %in% c("CI14", "CI15")
  ) {
    .ci1415_stop("CI-14/15 promotion requires the immutable manifest first")
  }
  ci1415_validate_manifest(manifest)
  merged <- ci1415_merge_attempts(manifest, attempts)
  summary <- ci1415_summarise(merged)
  needed <- c("cell_id", "target_id", "coverage", "mcse", "eligible")
  if (!is.data.frame(summary) || !all(needed %in% names(summary))) {
    .ci1415_stop("CI-14/15 promotion requires a complete target summary")
  }
  expected_full <- identical(
    manifest$selected_cell_ids,
    manifest$spec$cells$cell_id
  ) &&
    identical(manifest$selected_rep_ids, seq_len(manifest$n_sim))
  rows <- lapply(manifest$selected_cell_ids, function(cell_id) {
    route <- .ci1415_route_for_cell(manifest$spec, cell_id)
    target_ids <- .ci1415_target_ids(route)
    tab <- summary[summary$cell_id == cell_id, , drop = FALSE]
    if (
      nrow(tab) != length(target_ids) ||
        !identical(as.character(tab$target_id), target_ids)
    ) {
      .ci1415_stop(
        "CI-14/15 promotion has incomplete, duplicate, or reordered targets"
      )
    }
    tab$lower_band <- tab$coverage - 2 * tab$mcse
    retained_complete <- tab$n_outer == manifest$n_sim &
      tab$n_outer ==
        tab$eligible +
          tab$base_fit_failed +
          tab$scientific_failure +
          tab$infrastructure_failure
    tab$target_pass <- is.finite(tab$coverage) &
      is.finite(tab$mcse) &
      tab$eligible > 0L &
      retained_complete &
      tab$coverage >= manifest$gate &
      tab$lower_band >= manifest$gate
    tab$cell_pass <- all(tab$target_pass)
    tab
  })
  targets <- do.call(rbind, rows)
  rownames(targets) <- NULL
  campaign_complete <- isTRUE(expected_full) &&
    all(targets$n_outer == manifest$n_sim)
  list(
    targets = targets,
    promotion = list(
      complete_campaign = campaign_complete,
      promote = campaign_complete && all(targets$target_pass),
      gate = manifest$gate,
      availability_is_not_a_gate = TRUE
    )
  )
}

ci1415_synthetic_all_covered_attempts <- function(manifest) {
  ci1415_validate_manifest(manifest)
  routes <- unique(vapply(manifest$expected, `[[`, character(1), "route"))
  payloads <- lapply(
    routes,
    function(route) ci1415_target_results(manifest, route, outcome = "covered")
  )
  names(payloads) <- routes
  lapply(manifest$expected, function(expected) {
    list(
      packet = manifest$packet,
      campaign_id = manifest$campaign_id,
      schema_version = manifest$schema_version,
      source_sha = manifest$source_sha,
      cell_id = expected$cell_id,
      rep = expected$rep,
      seed = expected$seed,
      route = expected$route,
      truth_fingerprint = expected$truth_fingerprint,
      attempt_version = 1L,
      outcome = "eligible",
      target_results = payloads[[expected$route]]
    )
  })
}

## Pure proof shape for the frozen complete-campaign gate.  It deliberately
## creates no outer attempts and makes no empirical claim; pre-run and remote
## campaigns must instead pass through ci1415_merge_attempts().
ci1415_synthetic_all_covered_summary <- function(manifest) {
  ci1415_validate_manifest(manifest)
  rows <- lapply(manifest$selected_cell_ids, function(cell_id) {
    route <- .ci1415_route_for_cell(manifest$spec, cell_id)
    targets <- .ci1415_targets(route)
    do.call(
      rbind,
      lapply(targets, function(target) {
        data.frame(
          packet = manifest$packet,
          cell_id = as.integer(cell_id),
          route = route,
          target_id = target$target_id,
          trait = target$trait,
          component = target$component,
          n_outer = length(manifest$selected_rep_ids),
          eligible = length(manifest$selected_rep_ids),
          covered = length(manifest$selected_rep_ids),
          miss = 0L,
          ci_failed = 0L,
          coverage = 1,
          mcse = 0,
          availability = 1,
          base_fit_failed = 0L,
          scientific_failure = 0L,
          infrastructure_failure = 0L,
          stringsAsFactors = FALSE
        )
      })
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

ci1415_alignment_table <- function() {
  data.frame(
    symbol = c(
      "Lambda_slope",
      "Psi_slope",
      "L_phy",
      "Lambda_slope_only",
      "Psi_slope_zero"
    ),
    covstruct = c(
      "latent(..., d=2, unique=TRUE)",
      "latent(..., d=2, unique=TRUE)",
      "phylo_dep(...)",
      "latent(..., d=2, unique=FALSE)",
      "latent(..., d=2, unique=FALSE)"
    ),
    dgp = c(
      "nonzero 3x2 slope loadings",
      "nonzero diagonal slope Psi",
      "4x4 interleaved lower Cholesky factor",
      "nonzero 3x2 slope loadings",
      "exactly zero diagonal slope Psi"
    ),
    extractor = c(
      "total_sd",
      "estimate",
      "ADREPORT sd_b",
      "ADREPORT sd_rr_B_slope",
      "route guard"
    ),
    truth = c(
      "sqrt(diag(Lambda Lambda^T + Psi))",
      "psi",
      "sqrt(diag(L L^T))[2,4]",
      "sqrt(diag(Lambda Lambda^T))",
      "Psi equals zero"
    ),
    stringsAsFactors = FALSE
  )
}

ci1415_smoke_plan <- function() {
  list(
    execution = "not_run",
    would_fit = FALSE,
    would_simulate = FALSE,
    estimate_required_before_run = TRUE,
    command = "Rscript dev/interval-calibration/ci14-ci15/smoke.R"
  )
}
