## Profile-likelihood route matrix.
##
## This internal ledger keeps the interval-routing story coherent across
## peer tiers (unit, unit_obs, cluster, cluster2), source tiers (phy,
## spatial), and augmented structural split tiers. It is deliberately a
## truth table: entries can be covered, partial, fallback, planned,
## point_only, not_applicable, or blocked. A row marked covered here does
## not imply empirical coverage calibration; it only says the route exists
## and is covered by focused tests.

#' @keywords internal
#' @noRd
.profile_route_levels <- function() {
  data.frame(
    level = c(
      "unit",
      "unit_obs",
      "cluster",
      "cluster2",
      "phy",
      "spatial",
      "unit_slope",
      "phy_unique_slope",
      "phy_dep",
      "phy_slope",
      "spde_base_slope",
      "spde_dep",
      "spde_slope"
    ),
    family = c(
      "peer",
      "peer",
      "peer_diagonal",
      "peer_diagonal",
      "source",
      "source",
      "augmented_peer",
      "augmented_source",
      "augmented_source",
      "augmented_source",
      "augmented_source",
      "augmented_source",
      "augmented_source"
    ),
    extractor_level = c(
      "unit",
      "unit_obs",
      "cluster",
      "cluster2",
      "phy",
      "spatial",
      "B_slope",
      "phy",
      "phy",
      "phy_slope",
      "spatial",
      "spatial",
      "spde_slope"
    ),
    covariance_shape = c(
      "T_by_T",
      "T_by_T",
      "diag_T",
      "diag_T",
      "T_by_T",
      "T_by_T",
      "slope_block",
      "intercept_slope_2_by_2",
      "full_augmented",
      "per_lhs_block",
      "intercept_slope_2_by_2",
      "full_augmented",
      "per_lhs_block"
    ),
    route_note = c(
      "Ordinary between-unit tier; may be unique-only or low-rank plus Psi.",
      "Within-unit / observation tier; may be unique-only or low-rank plus Psi.",
      "First extra diagonal grouping tier, engine block theta_diag_species.",
      "Second extra diagonal grouping tier, engine block theta_diag_cluster2.",
      "Source-specific phylogenetic tier; intercept-only total covariance is extractable.",
      "Source-specific SPDE tier; intercept-only total covariance is extractable.",
      "Ordinary augmented latent random-regression tier.",
      "Phylogenetic independent augmented slope tier.",
      "Phylogenetic full augmented dependency tier.",
      "Phylogenetic augmented latent slope tier.",
      "SPDE independent augmented slope tier.",
      "SPDE full augmented dependency tier.",
      "SPDE augmented latent slope tier."
    ),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
.profile_route_row <- function(
  estimand,
  level,
  method,
  status,
  route,
  validation_row,
  claim,
  next_gate
) {
  data.frame(
    estimand = estimand,
    level = level,
    method = method,
    status = status,
    route = route,
    validation_row = validation_row,
    claim = claim,
    next_gate = next_gate,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
.profile_route_matrix <- function() {
  rows <- list(
    .profile_route_row(
      "direct_sd", "unit", "profile", "covered",
      "profile_targets:theta_diag_B",
      "CI-02",
      "Direct log-SD entries can be profiled when the TMB object is retained.",
      "Coverage calibration remains CI-08/CI-10."
    ),
    .profile_route_row(
      "direct_sd", "unit_obs", "profile", "covered",
      "profile_targets:theta_diag_W",
      "CI-02",
      "Direct log-SD entries can be profiled when the TMB object is retained.",
      "Coverage calibration remains CI-08/CI-10."
    ),
    .profile_route_row(
      "direct_sd", "cluster", "profile", "covered",
      "profile_targets:theta_diag_species",
      "CI-02;RE-11",
      "The first diagonal grouping tier has direct log-SD profile labels.",
      "Do not call this a full covariance-matrix profile route."
    ),
    .profile_route_row(
      "direct_sd", "cluster2", "profile", "covered",
      "profile_targets:theta_diag_cluster2",
      "CI-02;RE-11",
      "The second diagonal grouping tier has direct log-SD profile labels.",
      "Do not call this a full covariance-matrix profile route."
    ),
    .profile_route_row(
      "direct_sd", "phy", "profile", "covered",
      "profile_targets:log_sd_phy_diag",
      "CI-02;PHY-05",
      "Per-trait phylogenetic unique SDs can be profiled directly.",
      "Total phylogenetic covariance intervals remain a derived route."
    ),
    .profile_route_row(
      "direct_sd", "spatial", "profile", "covered",
      "profile_targets:log_tau_spde/log_kappa_spde",
      "CI-02;SPA-03",
      "SPDE scale parameters can be profiled directly where present.",
      "Do not infer total spatial covariance calibration from scale profiles."
    ),
    .profile_route_row(
      "Sigma", "unit", "profile", "partial",
      "diag_only_direct_else_bootstrap_fallback",
      "CI-02;CI-03",
      "Pure diagonal Sigma_unit profiles directly; low-rank total Sigma falls back to bootstrap.",
      "Target-explicit full-Sigma profile needs a separate gate."
    ),
    .profile_route_row(
      "Sigma", "unit_obs", "profile", "partial",
      "diag_only_direct_else_bootstrap_fallback",
      "CI-02;CI-03",
      "Pure diagonal Sigma_unit_obs profiles directly; low-rank total Sigma falls back to bootstrap.",
      "Target-explicit full-Sigma profile needs a separate gate."
    ),
    .profile_route_row(
      "Sigma", "cluster", "profile", "partial",
      "direct_diag_sigma_profile:theta_diag_species",
      "RE-11",
      "Diagonal-only Sigma_cluster profile/Wald token is wired through the direct log-SD tier.",
      "Bootstrap calibration and any non-diagonal cluster covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "cluster2", "profile", "partial",
      "direct_diag_sigma_profile:theta_diag_cluster2",
      "RE-11",
      "Diagonal-only Sigma_cluster2 profile/Wald token is wired through the direct log-SD tier.",
      "Bootstrap calibration and any non-diagonal cluster2 covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "phy", "profile", "partial",
      "direct_phy_diag_or_derived_total",
      "CI-05;CI-07;PHY-05",
      "Phylogenetic direct diagonal and selected derived routes exist.",
      "Full total-covariance profile calibration is not complete."
    ),
    .profile_route_row(
      "Sigma", "spatial", "profile", "partial",
      "scale_profile_and_selected_rho_smoke",
      "CI-07;SPA-02;SPA-04",
      "Spatial scale and selected correlation profile routes exist.",
      "Total spatial covariance profile still needs a heavy gate."
    ),
    .profile_route_row(
      "communality", "unit", "profile", "covered",
      "fix_refit:profile_ci_communality",
      "CI-06;EXT-05",
      "Ordinary unit communality profile route is wired.",
      "Coverage calibration remains separate."
    ),
    .profile_route_row(
      "communality", "unit_obs", "profile", "covered",
      "fix_refit:profile_ci_communality",
      "CI-06;EXT-05",
      "Within-unit communality profile route is wired.",
      "Coverage calibration remains separate."
    ),
    .profile_route_row(
      "communality", "phy", "profile", "covered",
      "fix_refit:profile_ci_communality",
      "CI-06;EXT-05;PHY-08",
      "Phylogenetic-tier communality profile route is wired.",
      "Source-family calibration remains separate."
    ),
    .profile_route_row(
      "communality", "spatial", "profile", "planned",
      "no_profile_ci_communality_spatial_tier",
      "SPA-02",
      "Spatial total covariance is extractable but communality profile is not wired.",
      "Add spatial communality target function and heavy profile gate."
    ),
    .profile_route_row(
      "communality", "cluster", "profile", "not_applicable",
      "diagonal_only_no_shared_loading",
      "RE-11",
      "Diagonal cluster tiers have no shared loading numerator.",
      "No route unless a new cluster latent tier is designed."
    ),
    .profile_route_row(
      "communality", "cluster2", "profile", "not_applicable",
      "diagonal_only_no_shared_loading",
      "RE-11",
      "Diagonal cluster2 tiers have no shared loading numerator.",
      "No route unless a new cluster2 latent tier is designed."
    ),
    .profile_route_row(
      "rho", "unit", "profile", "covered",
      "fix_refit:profile_ci_correlation",
      "CI-07",
      "Ordinary unit low-rank-plus-Psi correlation profile route is wired.",
      "Gamma and other hard-family profile stability remains an inference-safety gate."
    ),
    .profile_route_row(
      "rho", "unit_obs", "profile", "covered",
      "fix_refit:profile_ci_correlation",
      "CI-07",
      "Within-unit low-rank-plus-Psi correlation profile route is wired.",
      "Hard-family profile stability remains an inference-safety gate."
    ),
    .profile_route_row(
      "rho", "phy", "profile", "covered",
      "fix_refit:profile_ci_correlation",
      "CI-07;PHY-05",
      "Phylogenetic low-rank-plus-Psi correlation profile route is wired.",
      "Source-specific coverage calibration remains separate."
    ),
    .profile_route_row(
      "rho", "spatial", "profile", "partial",
      "fix_refit:profile_ci_correlation",
      "CI-07;SPA-02;SPA-04",
      "Spatial correlation profile route exists with smoke evidence.",
      "Total-covariance spatial profile still needs a heavy gate."
    ),
    .profile_route_row(
      "rho", "cluster", "profile", "point_only",
      "structural_zero_off_diagonal",
      "RE-11",
      "Diagonal cluster correlations are zero by construction.",
      "No profile interval should be fabricated for structural zeros."
    ),
    .profile_route_row(
      "rho", "cluster2", "profile", "point_only",
      "structural_zero_off_diagonal",
      "RE-11",
      "Diagonal cluster2 correlations are zero by construction.",
      "No profile interval should be fabricated for structural zeros."
    ),
    .profile_route_row(
      "repeatability", "unit", "profile", "partial",
      "lincomb_diag_only:profile_ci_repeatability",
      "CI-04",
      "The direct profile route covers the diag-only ratio, not the full low-rank total Sigma ratio.",
      "Full repeatability profile needs target-explicit total Sigma constraints."
    ),
    .profile_route_row(
      "phylo_signal", "phy", "profile", "partial",
      "lincomb_two_component_or_wald_numeric_fallback",
      "CI-05",
      "Two-component phylo signal profiles directly; richer PGLLVM decompositions use labelled numeric Wald fallback.",
      "Full 3+ component profile remains planned."
    ),
    .profile_route_row(
      "proportion", "unit", "profile", "covered",
      "fix_refit:profile_ci_proportions",
      "CI-07;EXT-21;EXT-22",
      "Unit shared/unique proportions are represented in the current profile target function.",
      "Coverage calibration remains separate."
    ),
    .profile_route_row(
      "proportion", "unit_obs", "profile", "covered",
      "fix_refit:profile_ci_proportions",
      "CI-07;EXT-21;EXT-22",
      "Within-unit shared/unique proportions are represented in the current profile target function.",
      "Coverage calibration remains separate."
    ),
    .profile_route_row(
      "proportion", "phy", "profile", "covered",
      "fix_refit:profile_ci_proportions",
      "CI-07;EXT-21",
      "Phylogenetic shared/unique proportions are represented in the current profile target function.",
      "Coverage calibration remains separate."
    ),
    .profile_route_row(
      "proportion", "cluster", "profile", "partial",
      "fix_refit:unique_cluster",
      "RE-11;CI-11",
      "Cluster variance enters extract_proportions() and profile/Wald proportion routing as unique_cluster.",
      "Bootstrap refits preserve cluster arguments, but calibration and non-diagonal cluster claims remain out of scope."
    ),
    .profile_route_row(
      "proportion", "cluster2", "profile", "partial",
      "fix_refit:unique_cluster2",
      "RE-11;CI-11",
      "Cluster2 variance enters extract_proportions() and profile/Wald proportion routing as unique_cluster2.",
      "Bootstrap refits preserve cluster2 arguments, but calibration and non-diagonal cluster2 claims remain out of scope."
    ),
    .profile_route_row(
      "proportion", "spatial", "profile", "planned",
      "component_missing_from_profile_proportions",
      "SPA-02",
      "Spatial total covariance can be extracted but is not yet in profile proportions.",
      "Add SPDE shared/unique components only after a spatial denominator design."
    )
  )

  split_levels <- c(
    "unit_slope",
    "phy_unique_slope",
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
    "spde_dep",
    "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")
  for (lvl in split_levels) {
    for (est in split_estimands) {
      rows[[length(rows) + 1L]] <- .profile_route_row(
        est, lvl, "profile", "blocked",
        "augmented_split_target_not_declared",
        "RE-03;RE-12;SPA-08;SPA-09;SPA-10;PHY-11..18",
        "Point extraction/recovery may exist, but profile targets for augmented split blocks are not declared.",
        "Write symbolic target table before adding any augmented split profile route."
      )
    }
  }

  out <- do.call(rbind, rows)
  .validate_profile_route_matrix(out)
  out
}

#' @keywords internal
#' @noRd
.validate_profile_route_matrix <- function(x) {
  required <- c(
    "estimand", "level", "method", "status", "route",
    "validation_row", "claim", "next_gate"
  )
  missing <- setdiff(required, names(x))
  if (length(missing) > 0L) {
    cli::cli_abort("Internal profile route matrix missing columns: {.val {missing}}.")
  }

  ok_status <- c(
    "covered", "partial", "fallback", "planned",
    "blocked", "point_only", "not_applicable"
  )
  bad_status <- setdiff(x$status, ok_status)
  if (length(bad_status) > 0L) {
    cli::cli_abort("Invalid profile route status: {.val {bad_status}}.")
  }

  known_levels <- .profile_route_levels()$level
  bad_levels <- setdiff(x$level, known_levels)
  if (length(bad_levels) > 0L) {
    cli::cli_abort("Invalid profile route level: {.val {bad_levels}}.")
  }

  key <- paste(x$estimand, x$level, x$method, sep = "\r")
  if (anyDuplicated(key)) {
    dup <- key[duplicated(key)]
    cli::cli_abort("Duplicate profile route keys: {.val {dup}}.")
  }

  invisible(x)
}

#' @keywords internal
#' @noRd
.profile_route_status <- function(
  estimand,
  level,
  method = "profile",
  routes = .profile_route_matrix()
) {
  hit <- routes[
    routes$estimand == estimand &
      routes$level == level &
      routes$method == method,
    ,
    drop = FALSE
  ]
  if (nrow(hit) != 1L) {
    cli::cli_abort(
      "Expected one profile route for {.val {estimand}} / {.val {level}} / {.val {method}}, found {nrow(hit)}."
    )
  }
  hit
}
