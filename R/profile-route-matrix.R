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
      "kernel_named",
      "unit_slope",
      "phy_unique_slope",
      "phy_indep_slope",
      "phy_dep",
      "phy_slope",
      "spde_base_slope",
      "spde_indep_slope",
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
      "source_named",
      "augmented_peer",
      "augmented_source",
      "augmented_source",
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
      "kernel_levels$name",
      "B_slope",
      "phy",
      "phy",
      "phy",
      "phy_slope",
      "spatial",
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
      "T_by_T_named_kernel",
      "slope_block",
      "intercept_slope_2_by_2",
      "block_diagonal_augmented",
      "full_augmented",
      "per_lhs_block",
      "intercept_slope_2_by_2",
      "block_diagonal_augmented",
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
      "Named kernel tier; point covariance can be extracted by fitted kernel name.",
      "Ordinary augmented latent random-regression tier.",
      "Legacy/canonical phylo_unique shared 2x2 augmented slope tier.",
      "Current phylo_indep per-trait block-diagonal augmented slope tier.",
      "Phylogenetic full augmented dependency tier.",
      "Phylogenetic augmented latent slope tier.",
      "Legacy/canonical spatial_unique shared 2x2 augmented slope tier.",
      "Current spatial_indep per-trait block-diagonal augmented slope tier.",
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
.profile_abort_point_only_rho <- function(tier, parm = NULL) {
  tier <- .canonical_level_name(tier)
  route <- .profile_route_status("rho", tier)
  token <- if (!is.null(parm)) {
    paste0(" for ", parm)
  } else {
    ""
  }
  cli::cli_abort(c(
    "Profile correlation intervals are not available{token}.",
    "i" = "The profile route matrix marks tier {.val {tier}} rho as {.val {route$status}}.",
    "i" = "Cluster and cluster2 tiers are diagonal-only; off-diagonal correlations are structural zeros, not likelihood-profile targets.",
    ">" = "Use {.fn extract_Sigma_table} for point covariance/correlation reporting, and keep interval claims blocked until a dedicated route is implemented."
  ))
}

#' @keywords internal
#' @noRd
.profile_nonlinear_release_gate <- function() {
  paste(
    "Public profile CI remains blocked until an exact or independently",
    "tolerance-certified constraint solver, an exposed optimizer-status",
    "ledger, retained failed endpoints, target-specific calibration, and",
    "explicit maintainer promotion are all present."
  )
}

#' @keywords internal
#' @noRd
.profile_augmented_target_row <- function(
  level,
  estimand,
  target_state,
  point_route,
  target_shape,
  flatten_order,
  numerator,
  denominator,
  validation_row,
  profile_gate
) {
  release_gate <- .profile_nonlinear_release_gate()
  data.frame(
    level = level,
    estimand = estimand,
    target_state = target_state,
    point_route = point_route,
    target_shape = target_shape,
    flatten_order = flatten_order,
    numerator = numerator,
    denominator = denominator,
    validation_row = validation_row,
    profile_gate = paste(profile_gate, release_gate),
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
.profile_augmented_target_table <- function() {
  common_gate <- paste(
    "Point-extractor or historical canary evidence does not admit an",
    "augmented profile route."
  )
  rows <- list(
    .profile_augmented_target_row(
      "unit_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='shared/unique/total')",
      "2T_by_2T_total_augmented_covariance",
      "interleaved:intercept.trait,slope.x.trait",
      "Lambda_B_aug %*% t(Lambda_B_aug) plus optional diagonal Psi_B_aug",
      "same augmented 2T coefficient vector; no intercept-only denominator reuse",
      "Random-regression slope: partial recovery; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "unit_slope", "communality", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='shared/total')",
      "length_2T_coefficientwise_share",
      "interleaved:intercept.trait,slope.x.trait",
      "diag(Lambda_B_aug %*% t(Lambda_B_aug))",
      "diag(total Sigma_unit_slope)",
      "Random-regression slope: partial recovery; no CI",
      "Name and validate as coefficient-level augmented communality before exposing."
    ),
    .profile_augmented_target_row(
      "unit_slope", "rho", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='total')$R",
      "lower_triangle_of_2T_by_2T_correlation",
      "interleaved lower triangle over intercept.trait/slope.x.trait labels",
      "covariance element Sigma_unit_slope[i,j]",
      "sqrt(Sigma_unit_slope[i,i] * Sigma_unit_slope[j,j])",
      "Random-regression slope: partial recovery; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "unit_slope", "proportion", "declared_blocked",
      "candidate from extract_Sigma(level='unit_slope')",
      "coefficientwise_or_trace_share_not_public",
      "must preserve intercept/slope labels",
      "selected augmented coefficient variance or trace component",
      "matched augmented denominator across all active tiers on the same scale",
      "Random-regression slope: partial recovery; no CI",
      "Choose coefficientwise versus trace-share semantics before implementation."
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy') -> level phy_unique_slope",
      "2_by_2_block_local_intercept_slope_covariance",
      "block-local:intercept,slope",
      "D %*% R %*% D from report$sd_b and report$cor_b",
      "single source-slope block; part/link_residual do not apply",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "block-local:intercept,slope",
      "none",
      "none",
      "no CI (point estimate only)",
      "Do not create communality for a single 2x2 source random-slope block."
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "rho", "declared_blocked",
      "extract_Sigma(level='phy')$R[intercept,slope]",
      "single_intercept_slope_correlation",
      "block-local:intercept,slope",
      "Sigma_b[intercept,slope]",
      "sqrt(Sigma_b[intercept,intercept] * Sigma_b[slope,slope])",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "proportion", "declared_blocked",
      "candidate from 2x2 source-slope block",
      "block_trace_or_coefficient_share_not_public",
      "block-local:intercept,slope",
      "intercept/slope source variance component",
      "matched augmented source denominator; not intercept-only phy denominator",
      "no CI (point estimate only)",
      "Define denominator semantics before adding profile proportions."
    ),
    .profile_augmented_target_row(
      "phy_indep_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy') -> level phy_indep_slope",
      "2T_by_2T_block_diagonal_T_independent_2_by_2_blocks",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "blockdiag_t(L_t %*% t(L_t)) = report$Sigma_b_dep",
      "single block-diagonal source-slope covariance; part/link_residual do not apply",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_indep_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "none",
      "none",
      "no CI (point estimate only)",
      "Do not create communality for per-trait unstructured 2x2 blocks."
    ),
    .profile_augmented_target_row(
      "phy_indep_slope", "rho", "declared_blocked",
      "extract_Sigma(level='phy')$R within each trait block",
      "length_T_within_trait_intercept_slope_correlations",
      "trait order; one intercept-slope pair per trait",
      "Sigma_b_dep[intercept.trait,slope.trait]",
      "sqrt(Sigma_b_dep[intercept.trait,intercept.trait] * Sigma_b_dep[slope.trait,slope.trait])",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_indep_slope", "proportion", "declared_blocked",
      "candidate from report$Sigma_b_dep block diagonal",
      "coefficientwise_or_trace_share_not_public",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "selected within-trait augmented variance or block trace",
      "matched augmented coefficient vector across active tiers; no intercept-only denominator",
      "no CI (point estimate only)",
      "Choose coefficientwise versus trace-share semantics before implementation."
    ),
    .profile_augmented_target_row(
      "phy_dep", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy') -> level phy_dep",
      "(1+s)T_by_(1+s)T_full_unstructured_covariance",
      "interleaved:intercept.trait,slope1.trait,...,slope_s.trait",
      "report$Sigma_b_dep",
      "single full source-slope covariance block",
      "Multi-trait slope covariance: mixed evidence; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_dep", "communality", "not_applicable_blocked",
      "no low-rank shared-loading split",
      "not_applicable",
      "interleaved dep columns",
      "none",
      "none",
      "Multi-trait slope covariance: mixed evidence; no CI",
      "Do not label full dep covariance entries as communality."
    ),
    .profile_augmented_target_row(
      "phy_dep", "rho", "declared_blocked",
      "extract_Sigma(level='phy')$R",
      "lower_triangle_of_full_augmented_correlation",
      "interleaved lower triangle over dep columns",
      "Sigma_b_dep[i,j]",
      "sqrt(Sigma_b_dep[i,i] * Sigma_b_dep[j,j])",
      "Multi-trait slope covariance: mixed evidence; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_dep", "proportion", "declared_blocked",
      "candidate from report$Sigma_b_dep",
      "block_trace_or_coefficient_share_not_public",
      "interleaved dep columns",
      "selected dep variance or trace component",
      "matched augmented source denominator; no intercept-only borrowing",
      "Multi-trait slope covariance: mixed evidence; no CI",
      "Define dep trace/diagonal denominator semantics before implementation."
    ),
    .profile_augmented_target_row(
      "phy_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "list_of_T_by_T_per_lhs_column",
      "per-column:intercept matrix then slope matrix; trait labels inside each",
      "Lambda_k %*% t(Lambda_k) for each LHS column",
      "block-diagonal across LHS columns; cross-column covariance is structural zero",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_slope", "communality", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "per_lhs_column_traitwise_share",
      "column first, then trait",
      "diag(Lambda_k %*% t(Lambda_k))",
      "same per-column covariance; no cross-column denominator",
      "no CI (point estimate only)",
      "Name and validate per-column latent communality before exposing."
    ),
    .profile_augmented_target_row(
      "phy_slope", "rho", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "within_column_lower_triangle_only",
      "column first, then trait-pair lower triangle",
      "Sigma_k[i,j]",
      "sqrt(Sigma_k[i,i] * Sigma_k[j,j]); cross-column rho is structural zero",
      "no CI (point estimate only)",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_slope", "proportion", "declared_blocked",
      "candidate from per-column Lambda_k blocks",
      "per_column_trace_or_trait_share_not_public",
      "column first, then trait",
      "selected per-column source-latent variance",
      "matched per-column augmented denominator",
      "no CI (point estimate only)",
      "Define per-column denominator semantics before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='spatial') -> level spde_base_slope",
      "2_by_2_block_local_intercept_slope_field_covariance",
      "block-local:intercept,slope",
      "D %*% R %*% D from report$sd_spde_b and report$cor_spde_b",
      "SPDE field scale; marginal conversion requires kappa_s",
      "Spatial slope covariance: recovered for core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "block-local:intercept,slope",
      "none",
      "none",
      "Spatial slope covariance: recovered for core families; no CI",
      "Do not create communality for a single 2x2 SPDE slope block."
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "rho", "declared_blocked",
      "extract_Sigma(level='spatial')$R[intercept,slope]",
      "single_intercept_slope_field_correlation",
      "block-local:intercept,slope",
      "Sigma_field[intercept,slope]",
      "sqrt(Sigma_field[intercept,intercept] * Sigma_field[slope,slope])",
      "Spatial slope covariance: recovered for core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "proportion", "declared_blocked",
      "candidate from 2x2 SPDE field block",
      "field_trace_or_coefficient_share_not_public",
      "block-local:intercept,slope",
      "intercept/slope SPDE field variance",
      "matched spatial denominator on field or marginal scale, not mixed",
      "Spatial slope covariance: recovered for core families; no CI",
      "Write spatial denominator design before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_indep_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='spatial') -> level spde_indep_slope",
      "2T_by_2T_block_diagonal_T_independent_2_by_2_field_blocks",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "blockdiag_t(L_t %*% t(L_t)) = report$Sigma_field",
      "single block-diagonal spatial-slope field covariance; part/link_residual do not apply; field scale",
      "Spatial slope covariance: recovered for core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_indep_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "none",
      "none",
      "Spatial slope covariance: recovered for core families; no CI",
      "Do not create communality for per-trait unstructured 2x2 field blocks."
    ),
    .profile_augmented_target_row(
      "spde_indep_slope", "rho", "declared_blocked",
      "extract_Sigma(level='spatial')$R within each trait field block",
      "length_T_within_trait_intercept_slope_field_correlations",
      "trait order; one intercept-slope field pair per trait",
      "Sigma_field[intercept.trait,slope.trait]",
      "sqrt(Sigma_field[intercept.trait,intercept.trait] * Sigma_field[slope.trait,slope.trait])",
      "Spatial slope covariance: recovered for core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_indep_slope", "proportion", "declared_blocked",
      "candidate from report$Sigma_field block diagonal",
      "coefficientwise_or_trace_share_not_public",
      "interleaved_per_trait:intercept.trait,slope.trait",
      "selected within-trait field variance or block trace",
      "matched spatial denominator on one declared field or marginal scale",
      "Spatial slope covariance: recovered for core families; no CI",
      "Choose coefficientwise versus trace and field versus marginal semantics before implementation."
    ),
    .profile_augmented_target_row(
      "spde_dep", "Sigma", "declared_blocked",
      "extract_Sigma(level='spatial') -> level spde_dep",
      "2T_by_2T_full_unstructured_field_covariance",
      "interleaved:intercept.trait,slope.trait",
      "report$Sigma_field",
      "SPDE field scale; marginal conversion divides by 4*pi*kappa^2",
      "Spatial full-covariance slope: core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_dep", "communality", "not_applicable_blocked",
      "no low-rank shared-loading split",
      "not_applicable",
      "interleaved field columns",
      "none",
      "none",
      "Spatial full-covariance slope: core families; no CI",
      "Do not label full SPDE dep covariance entries as communality."
    ),
    .profile_augmented_target_row(
      "spde_dep", "rho", "declared_blocked",
      "extract_Sigma(level='spatial')$R",
      "lower_triangle_of_2T_by_2T_field_correlation",
      "interleaved lower triangle over field columns",
      "Sigma_field[i,j]",
      "sqrt(Sigma_field[i,i] * Sigma_field[j,j])",
      "Spatial full-covariance slope: core families; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_dep", "proportion", "declared_blocked",
      "candidate from report$Sigma_field",
      "field_trace_or_coefficient_share_not_public",
      "interleaved field columns",
      "selected field variance or trace component",
      "matched spatial denominator on one declared scale",
      "Spatial full-covariance slope: core families; no CI",
      "Write spatial denominator design before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "list_of_T_by_T_per_lhs_column_field_covariance",
      "per-column:intercept matrix then slope matrix; trait labels inside each",
      "Lambda_k %*% t(Lambda_k) for each LHS column",
      "block-diagonal across LHS columns on SPDE field scale",
      "Spatial reduced-rank slope: core families only; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_slope", "communality", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "per_lhs_column_traitwise_share",
      "column first, then trait",
      "diag(Lambda_k %*% t(Lambda_k))",
      "same per-column field covariance; no cross-column denominator",
      "Spatial reduced-rank slope: core families only; no CI",
      "Name and validate per-column SPDE latent communality before exposing."
    ),
    .profile_augmented_target_row(
      "spde_slope", "rho", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "within_column_lower_triangle_only",
      "column first, then trait-pair lower triangle",
      "Sigma_k[i,j]",
      "sqrt(Sigma_k[i,i] * Sigma_k[j,j]); cross-column rho is structural zero",
      "Spatial reduced-rank slope: core families only; no CI",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_slope", "proportion", "declared_blocked",
      "candidate from per-column Lambda_k SPDE blocks",
      "per_column_field_trace_or_trait_share_not_public",
      "column first, then trait",
      "selected per-column SPDE latent variance",
      "matched spatial denominator on one declared scale",
      "Spatial reduced-rank slope: core families only; no CI",
      "Write spatial denominator design before profile proportions."
    )
  )

  out <- do.call(rbind, rows)
  .validate_profile_augmented_target_table(out)
  out
}

#' @keywords internal
#' @noRd
.profile_route_matrix <- function() {
  withdrawn_route <- "withheld_nonlinear_penalty_profile"
  withdrawn_claim <- paste(
    "The former penalty-profile prototype remains internal;",
    "the public extractor and confint routes stop with an explanation."
  )
  withdrawn_gate <- .profile_nonlinear_release_gate()
  rows <- list(
    .profile_route_row(
      "direct_sd", "unit", "profile", "covered",
      "profile_targets:theta_diag_B",
      "direct profile route (not coverage-calibrated)",
      "Direct log-SD entries can be profiled when the TMB object is retained.",
      "Empirical coverage calibration is not established for this route."
    ),
    .profile_route_row(
      "direct_sd", "unit_obs", "profile", "covered",
      "profile_targets:theta_diag_W",
      "direct profile route (not coverage-calibrated)",
      "Direct log-SD entries can be profiled when the TMB object is retained.",
      "Empirical coverage calibration is not established for this route."
    ),
    .profile_route_row(
      "direct_sd", "cluster", "profile", "covered",
      "profile_targets:theta_diag_species",
      "diagonal grouping SD: direct profile route (not coverage-calibrated)",
      "The first diagonal grouping tier has direct log-SD profile labels.",
      "Do not call this a full covariance-matrix profile route."
    ),
    .profile_route_row(
      "direct_sd", "cluster2", "profile", "covered",
      "profile_targets:theta_diag_cluster2",
      "diagonal grouping SD: direct profile route (not coverage-calibrated)",
      "The second diagonal grouping tier has direct log-SD profile labels.",
      "Do not call this a full covariance-matrix profile route."
    ),
    .profile_route_row(
      "direct_sd", "phy", "profile", "covered",
      "profile_targets:log_sd_phy_diag",
      "phylogenetic direct-scale profile route (not coverage-calibrated)",
      "Per-trait phylogenetic unique SDs can be profiled directly.",
      "Total phylogenetic covariance intervals remain a derived route."
    ),
    .profile_route_row(
      "direct_sd", "spatial", "profile", "covered",
      "profile_targets:log_tau_spde/log_kappa_spde",
      "spatial scale parameter: direct profile route only",
      "SPDE scale parameters can be profiled directly where present.",
      "Do not infer total spatial covariance calibration from scale profiles."
    ),
    .profile_route_row(
      "direct_sd", "kernel_named", "profile", "blocked",
      "no_profile_targets_for_named_kernel_tiers",
      "profile CI blocked (point estimate only)",
      "Named kernel tiers may have point covariance extraction, but no direct profile target labels are exposed.",
      "Declare kernel-specific direct parameters and tests before adding profile targets."
    ),
    .profile_route_row(
      "Sigma", "unit", "profile", "partial",
      "diag_only_direct_else_bootstrap_fallback",
      "profile CI partial (diagonal only; else bootstrap)",
      "Pure diagonal Sigma_unit profiles directly; low-rank total Sigma falls back to bootstrap.",
      "Target-explicit full-Sigma profile needs a separate gate."
    ),
    .profile_route_row(
      "Sigma", "unit_obs", "profile", "partial",
      "diag_only_direct_else_bootstrap_fallback",
      "profile CI partial (diagonal only; else bootstrap)",
      "Pure diagonal Sigma_unit_obs profiles directly; low-rank total Sigma falls back to bootstrap.",
      "Target-explicit full-Sigma profile needs a separate gate."
    ),
    .profile_route_row(
      "Sigma", "cluster", "profile", "partial",
      "direct_diag_sigma_profile:theta_diag_species",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal-only Sigma_cluster profile/Wald token is wired through the direct log-SD tier; a fitted Gaussian canary profiles finite diagonal rows.",
      "Bootstrap calibration and any non-diagonal cluster covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "cluster2", "profile", "partial",
      "direct_diag_sigma_profile:theta_diag_cluster2",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal-only Sigma_cluster2 profile/Wald token is wired through the direct log-SD tier; a fitted Gaussian canary profiles finite diagonal rows.",
      "Bootstrap calibration and any non-diagonal cluster2 covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "phy", "profile", "partial",
      "direct_phy_diag_or_derived_total",
      "phylogenetic covariance CI: partial (diagonal only)",
      "Phylogenetic direct diagonal and the separately documented phylogenetic-signal route exist.",
      "Any derived total-Sigma target needs an exact or independently tolerance-certified constraint, an optimizer-status ledger, retained failures, target-specific calibration, and explicit maintainer promotion."
    ),
    .profile_route_row(
      "Sigma", "spatial", "profile", "partial",
      "direct_spatial_scale_profile",
      "spatial Sigma: direct-scale CI only, partial elsewhere",
      "The direct spatial scale parameter can be profiled.",
      "Any derived total-Sigma target needs an exact or independently tolerance-certified constraint, an optimizer-status ledger, retained failures, target-specific calibration, and explicit maintainer promotion."
    ),
    .profile_route_row(
      "Sigma", "kernel_named", "profile", "blocked",
      "extract_Sigma_point_only_no_confint_token",
      "profile CI blocked (point estimate only)",
      "Named kernel Sigma blocks can be inspected as point estimates through extract_Sigma()/extract_Sigma_table(), but no confint Sigma token is wired.",
      "Add a named-kernel Sigma token, symbolic target, and focused recovery/calibration gate before exposing intervals."
    ),
    .profile_route_row(
      "communality", "unit", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "communality", "unit_obs", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "communality", "phy", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "communality", "spatial", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "communality", "cluster", "profile", "not_applicable",
      "diagonal_only_no_shared_loading",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal cluster tiers have no shared loading numerator.",
      "No route unless a new cluster latent tier is designed."
    ),
    .profile_route_row(
      "communality", "cluster2", "profile", "not_applicable",
      "diagonal_only_no_shared_loading",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal cluster2 tiers have no shared loading numerator.",
      "No route unless a new cluster2 latent tier is designed."
    ),
    .profile_route_row(
      "communality", "kernel_named", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "rho", "unit", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "rho", "unit_obs", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "rho", "phy", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "rho", "spatial", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "rho", "cluster", "profile", "point_only",
      "structural_zero_off_diagonal",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal cluster correlations are zero by construction.",
      "No profile interval should be fabricated for structural zeros."
    ),
    .profile_route_row(
      "rho", "cluster2", "profile", "point_only",
      "structural_zero_off_diagonal",
      "diagonal grouping tier: no calibrated interval",
      "Diagonal cluster2 correlations are zero by construction.",
      "No profile interval should be fabricated for structural zeros."
    ),
    .profile_route_row(
      "rho", "kernel_named", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "repeatability", "unit", "profile", "blocked",
      withdrawn_route, "",
      "The former direct contrast estimated only the diagonal-companion ratio, omitted shared latent variance, and is withdrawn rather than retained as a partial repeatability profile.",
      withdrawn_gate
    ),
    .profile_route_row(
      "phylo_signal", "phy", "profile", "partial",
      "lincomb_two_component_or_wald_numeric_fallback",
      "phylo-signal profile-CI: 2-component only, partial beyond",
      "Two-component phylo signal profiles directly; richer PGLLVM decompositions use labelled numeric Wald fallback.",
      "Full 3+ component profile remains planned."
    ),
    .profile_route_row(
      "proportion", "unit", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "unit_obs", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "phy", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "cluster", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "cluster2", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "spatial", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    ),
    .profile_route_row(
      "proportion", "kernel_named", "profile", "blocked",
      withdrawn_route, "", withdrawn_claim, withdrawn_gate
    )
  )

  split_levels <- c(
    "unit_slope",
    "phy_unique_slope",
    "phy_indep_slope",
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
    "spde_indep_slope",
    "spde_dep",
    "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")
  split_targets <- .profile_augmented_target_table()
  for (lvl in split_levels) {
    for (est in split_estimands) {
      target <- split_targets[
        split_targets$level == lvl & split_targets$estimand == est,
        ,
        drop = FALSE
      ]
      is_nonlinear <- est %in% c("communality", "rho", "proportion")
      rows[[length(rows) + 1L]] <- .profile_route_row(
        est, lvl, "profile",
        "blocked",
        if (is_nonlinear) withdrawn_route else
          paste0("augmented_split_target_table:", target$target_state),
        if (is_nonlinear) "" else
          "augmented random-slope: recovery evidence varies by family/route; no CI",
        if (is_nonlinear) withdrawn_claim else
          "Point extraction/recovery may exist and the symbolic target is declared, but profile CIs are not implemented or calibrated.",
        if (is_nonlinear) withdrawn_gate else target$profile_gate
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
.validate_profile_augmented_target_table <- function(x) {
  required <- c(
    "level", "estimand", "target_state", "point_route", "target_shape",
    "flatten_order", "numerator", "denominator", "validation_row",
    "profile_gate"
  )
  missing <- setdiff(required, names(x))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Internal augmented target table missing columns: {.val {missing}}."
    )
  }

  split_levels <- c(
    "unit_slope",
    "phy_unique_slope",
    "phy_indep_slope",
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
    "spde_indep_slope",
    "spde_dep",
    "spde_slope"
  )
  split_estimands <- c("Sigma", "communality", "rho", "proportion")
  bad_levels <- setdiff(x$level, split_levels)
  bad_estimands <- setdiff(x$estimand, split_estimands)
  if (length(bad_levels) > 0L) {
    cli::cli_abort("Invalid augmented target level: {.val {bad_levels}}.")
  }
  if (length(bad_estimands) > 0L) {
    cli::cli_abort("Invalid augmented target estimand: {.val {bad_estimands}}.")
  }

  expected <- expand.grid(
    level = split_levels,
    estimand = split_estimands,
    stringsAsFactors = FALSE
  )
  key <- paste(x$level, x$estimand, sep = "\r")
  expected_key <- paste(expected$level, expected$estimand, sep = "\r")
  missing_key <- setdiff(expected_key, key)
  extra_key <- setdiff(key, expected_key)
  if (length(missing_key) > 0L || length(extra_key) > 0L) {
    cli::cli_abort("Augmented target table must cover every split level x estimand exactly once.")
  }
  if (anyDuplicated(key)) {
    cli::cli_abort("Duplicate augmented target keys detected.")
  }

  ok_state <- c("declared_blocked", "not_applicable_blocked")
  bad_state <- setdiff(x$target_state, ok_state)
  if (length(bad_state) > 0L) {
    cli::cli_abort("Invalid augmented target state: {.val {bad_state}}.")
  }
  text_cols <- setdiff(required, c("level", "estimand", "target_state"))
  empty <- vapply(x[text_cols], function(col) any(is.na(col) | !nzchar(col)), logical(1))
  if (any(empty)) {
    cli::cli_abort("Augmented target table has empty required fields.")
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
