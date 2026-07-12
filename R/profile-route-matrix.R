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
      "source_named",
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
      "kernel_levels$name",
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
      "T_by_T_named_kernel",
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
      "Named kernel tier; point covariance can be extracted by fitted kernel name.",
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
    profile_gate = profile_gate,
    stringsAsFactors = FALSE
  )
}

#' @keywords internal
#' @noRd
.profile_augmented_target_table <- function() {
  common_gate <- paste(
    "Keep profile CI blocked until a selected Gaussian route has direct",
    "implementation, boundary handling, and focused recovery/calibration",
    "evidence."
  )
  rows <- list(
    .profile_augmented_target_row(
      "unit_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='shared/unique/total')",
      "2T_by_2T_total_augmented_covariance",
      "interleaved:intercept.trait,slope.x.trait",
      "Lambda_B_aug %*% t(Lambda_B_aug) plus optional diagonal Psi_B_aug",
      "same augmented 2T coefficient vector; no intercept-only denominator reuse",
      "RE-12;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "unit_slope", "communality", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='shared/total')",
      "length_2T_coefficientwise_share",
      "interleaved:intercept.trait,slope.x.trait",
      "diag(Lambda_B_aug %*% t(Lambda_B_aug))",
      "diag(total Sigma_unit_slope)",
      "RE-12;CI-11",
      "Name and validate as coefficient-level augmented communality before exposing."
    ),
    .profile_augmented_target_row(
      "unit_slope", "rho", "declared_blocked",
      "extract_Sigma(level='unit_slope', part='total')$R",
      "lower_triangle_of_2T_by_2T_correlation",
      "interleaved lower triangle over intercept.trait/slope.x.trait labels",
      "covariance element Sigma_unit_slope[i,j]",
      "sqrt(Sigma_unit_slope[i,i] * Sigma_unit_slope[j,j])",
      "RE-12;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "unit_slope", "proportion", "declared_blocked",
      "candidate from extract_Sigma(level='unit_slope')",
      "coefficientwise_or_trace_share_not_public",
      "must preserve intercept/slope labels",
      "selected augmented coefficient variance or trace component",
      "matched augmented denominator across all active tiers on the same scale",
      "RE-12;CI-11",
      "Choose coefficientwise versus trace-share semantics before implementation."
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy') -> level phy_unique_slope",
      "2_by_2_block_local_intercept_slope_covariance",
      "block-local:intercept,slope",
      "D %*% R %*% D from report$sd_b and report$cor_b",
      "single source-slope block; part/link_residual do not apply",
      "PHY-11..16;ANI-11;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "block-local:intercept,slope",
      "none",
      "none",
      "PHY-11..16;ANI-11;CI-11",
      "Do not create communality for a single 2x2 source random-slope block."
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "rho", "declared_blocked",
      "extract_Sigma(level='phy')$R[intercept,slope]",
      "single_intercept_slope_correlation",
      "block-local:intercept,slope",
      "Sigma_b[intercept,slope]",
      "sqrt(Sigma_b[intercept,intercept] * Sigma_b[slope,slope])",
      "PHY-11..16;ANI-11;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_unique_slope", "proportion", "declared_blocked",
      "candidate from 2x2 source-slope block",
      "block_trace_or_coefficient_share_not_public",
      "block-local:intercept,slope",
      "intercept/slope source variance component",
      "matched augmented source denominator; not intercept-only phy denominator",
      "PHY-11..16;ANI-11;CI-11",
      "Define denominator semantics before adding profile proportions."
    ),
    .profile_augmented_target_row(
      "phy_dep", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy') -> level phy_dep",
      "(1+s)T_by_(1+s)T_full_unstructured_covariance",
      "interleaved:intercept.trait,slope1.trait,...,slope_s.trait",
      "report$Sigma_b_dep",
      "single full source-slope covariance block",
      "RE-03;PHY-18;ANI-12;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_dep", "communality", "not_applicable_blocked",
      "no low-rank shared-loading split",
      "not_applicable",
      "interleaved dep columns",
      "none",
      "none",
      "RE-03;PHY-18;ANI-12;CI-11",
      "Do not label full dep covariance entries as communality."
    ),
    .profile_augmented_target_row(
      "phy_dep", "rho", "declared_blocked",
      "extract_Sigma(level='phy')$R",
      "lower_triangle_of_full_augmented_correlation",
      "interleaved lower triangle over dep columns",
      "Sigma_b_dep[i,j]",
      "sqrt(Sigma_b_dep[i,i] * Sigma_b_dep[j,j])",
      "RE-03;PHY-18;ANI-12;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_dep", "proportion", "declared_blocked",
      "candidate from report$Sigma_b_dep",
      "block_trace_or_coefficient_share_not_public",
      "interleaved dep columns",
      "selected dep variance or trace component",
      "matched augmented source denominator; no intercept-only borrowing",
      "RE-03;PHY-18;ANI-12;CI-11",
      "Define dep trace/diagonal denominator semantics before implementation."
    ),
    .profile_augmented_target_row(
      "phy_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "list_of_T_by_T_per_lhs_column",
      "per-column:intercept matrix then slope matrix; trait labels inside each",
      "Lambda_k %*% t(Lambda_k) for each LHS column",
      "block-diagonal across LHS columns; cross-column covariance is structural zero",
      "PHY-17;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_slope", "communality", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "per_lhs_column_traitwise_share",
      "column first, then trait",
      "diag(Lambda_k %*% t(Lambda_k))",
      "same per-column covariance; no cross-column denominator",
      "PHY-17;CI-11",
      "Name and validate per-column latent communality before exposing."
    ),
    .profile_augmented_target_row(
      "phy_slope", "rho", "declared_blocked",
      "extract_Sigma(level='phy_slope')",
      "within_column_lower_triangle_only",
      "column first, then trait-pair lower triangle",
      "Sigma_k[i,j]",
      "sqrt(Sigma_k[i,i] * Sigma_k[j,j]); cross-column rho is structural zero",
      "PHY-17;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "phy_slope", "proportion", "declared_blocked",
      "candidate from per-column Lambda_k blocks",
      "per_column_trace_or_trait_share_not_public",
      "column first, then trait",
      "selected per-column source-latent variance",
      "matched per-column augmented denominator",
      "PHY-17;CI-11",
      "Define per-column denominator semantics before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='spatial') -> level spde_base_slope",
      "2_by_2_block_local_intercept_slope_field_covariance",
      "block-local:intercept,slope",
      "D %*% R %*% D from report$sd_spde_b and report$cor_spde_b",
      "SPDE field scale; marginal conversion requires kappa_s",
      "SPA-08;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "communality", "not_applicable_blocked",
      "no shared-loading numerator",
      "not_applicable",
      "block-local:intercept,slope",
      "none",
      "none",
      "SPA-08;CI-11",
      "Do not create communality for a single 2x2 SPDE slope block."
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "rho", "declared_blocked",
      "extract_Sigma(level='spatial')$R[intercept,slope]",
      "single_intercept_slope_field_correlation",
      "block-local:intercept,slope",
      "Sigma_field[intercept,slope]",
      "sqrt(Sigma_field[intercept,intercept] * Sigma_field[slope,slope])",
      "SPA-08;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_base_slope", "proportion", "declared_blocked",
      "candidate from 2x2 SPDE field block",
      "field_trace_or_coefficient_share_not_public",
      "block-local:intercept,slope",
      "intercept/slope SPDE field variance",
      "matched spatial denominator on field or marginal scale, not mixed",
      "SPA-08;CI-11",
      "Write spatial denominator design before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_dep", "Sigma", "declared_blocked",
      "extract_Sigma(level='spatial') -> level spde_dep",
      "2T_by_2T_full_unstructured_field_covariance",
      "interleaved:intercept.trait,slope.trait",
      "report$Sigma_field",
      "SPDE field scale; marginal conversion divides by 4*pi*kappa^2",
      "SPA-10;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_dep", "communality", "not_applicable_blocked",
      "no low-rank shared-loading split",
      "not_applicable",
      "interleaved field columns",
      "none",
      "none",
      "SPA-10;CI-11",
      "Do not label full SPDE dep covariance entries as communality."
    ),
    .profile_augmented_target_row(
      "spde_dep", "rho", "declared_blocked",
      "extract_Sigma(level='spatial')$R",
      "lower_triangle_of_2T_by_2T_field_correlation",
      "interleaved lower triangle over field columns",
      "Sigma_field[i,j]",
      "sqrt(Sigma_field[i,i] * Sigma_field[j,j])",
      "SPA-10;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_dep", "proportion", "declared_blocked",
      "candidate from report$Sigma_field",
      "field_trace_or_coefficient_share_not_public",
      "interleaved field columns",
      "selected field variance or trace component",
      "matched spatial denominator on one declared scale",
      "SPA-10;CI-11",
      "Write spatial denominator design before profile proportions."
    ),
    .profile_augmented_target_row(
      "spde_slope", "Sigma", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "list_of_T_by_T_per_lhs_column_field_covariance",
      "per-column:intercept matrix then slope matrix; trait labels inside each",
      "Lambda_k %*% t(Lambda_k) for each LHS column",
      "block-diagonal across LHS columns on SPDE field scale",
      "SPA-09;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_slope", "communality", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "per_lhs_column_traitwise_share",
      "column first, then trait",
      "diag(Lambda_k %*% t(Lambda_k))",
      "same per-column field covariance; no cross-column denominator",
      "SPA-09;CI-11",
      "Name and validate per-column SPDE latent communality before exposing."
    ),
    .profile_augmented_target_row(
      "spde_slope", "rho", "declared_blocked",
      "extract_Sigma(level='spde_slope')",
      "within_column_lower_triangle_only",
      "column first, then trait-pair lower triangle",
      "Sigma_k[i,j]",
      "sqrt(Sigma_k[i,i] * Sigma_k[j,j]); cross-column rho is structural zero",
      "SPA-09;CI-11",
      common_gate
    ),
    .profile_augmented_target_row(
      "spde_slope", "proportion", "declared_blocked",
      "candidate from per-column Lambda_k SPDE blocks",
      "per_column_field_trace_or_trait_share_not_public",
      "column first, then trait",
      "selected per-column SPDE latent variance",
      "matched spatial denominator on one declared scale",
      "SPA-09;CI-11",
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
      "direct_sd", "kernel_named", "profile", "blocked",
      "no_profile_targets_for_named_kernel_tiers",
      "COE-04;CI-11",
      "Named kernel tiers may have point covariance extraction, but no direct profile target labels are exposed.",
      "Declare kernel-specific direct parameters and tests before adding profile targets."
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
      "Diagonal-only Sigma_cluster profile/Wald token is wired through the direct log-SD tier; a fitted Gaussian canary profiles finite diagonal rows.",
      "Bootstrap calibration and any non-diagonal cluster covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "cluster2", "profile", "partial",
      "direct_diag_sigma_profile:theta_diag_cluster2",
      "RE-11",
      "Diagonal-only Sigma_cluster2 profile/Wald token is wired through the direct log-SD tier; a fitted Gaussian canary profiles finite diagonal rows.",
      "Bootstrap calibration and any non-diagonal cluster2 covariance claim remain separate gates."
    ),
    .profile_route_row(
      "Sigma", "phy", "profile", "partial",
      "direct_phy_diag_or_derived_total",
      "CI-05;CI-07;PHY-05",
      "Phylogenetic direct diagonal and the separately documented phylogenetic-signal route exist.",
      "Full total-covariance profile calibration is not complete."
    ),
    .profile_route_row(
      "Sigma", "spatial", "profile", "partial",
      "direct_spatial_scale_profile",
      "CI-07;SPA-02;SPA-04",
      "The direct spatial scale parameter can be profiled.",
      "Total spatial covariance profile still needs a heavy gate."
    ),
    .profile_route_row(
      "Sigma", "kernel_named", "profile", "blocked",
      "extract_Sigma_point_only_no_confint_token",
      "COE-04;CI-11",
      "Named kernel Sigma blocks can be inspected as point estimates through extract_Sigma()/extract_Sigma_table(), but no confint Sigma token is wired.",
      "Add a named-kernel Sigma token, symbolic target, and focused recovery/calibration gate before exposing intervals."
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
      "communality", "kernel_named", "profile", "blocked",
      "extractor_denominator_not_declared_for_named_kernel",
      "COE-04;CI-11",
      "Named kernel point covariance exists, but kernel communality profile targets and denominators are not declared.",
      "Define kernel-specific shared/unique numerator and denominator semantics before implementation."
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
      "rho", "kernel_named", "profile", "blocked",
      "point_correlation_via_extract_Sigma_table_only",
      "COE-04;CI-11",
      "Named kernel correlations can be computed from point Sigma tables, but profile_ci_correlation()/confint() cannot request kernel names.",
      "Add named-kernel rho token parsing and direct tests before exposing profile intervals."
    ),
    .profile_route_row(
      "repeatability", "unit", "profile", "blocked",
      "withheld_diag_only_ratio_not_full_repeatability",
      "CI-04",
      "The former direct contrast estimated only the diagonal-companion ratio and omitted shared latent variance.",
      "Implement a target-explicit full-Sigma repeatability constraint before restoring a profile route."
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
    ),
    .profile_route_row(
      "proportion", "kernel_named", "profile", "blocked",
      "component_missing_from_profile_proportions",
      "COE-04;CI-11",
      "Named kernel components are not part of the current variance-proportion denominator.",
      "Define multi-kernel denominator semantics before adding profile proportions."
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
  split_targets <- .profile_augmented_target_table()
  for (lvl in split_levels) {
    for (est in split_estimands) {
      target <- split_targets[
        split_targets$level == lvl & split_targets$estimand == est,
        ,
        drop = FALSE
      ]
      is_unit_slope_rho <- identical(lvl, "unit_slope") &&
        identical(est, "rho")
      rows[[length(rows) + 1L]] <- .profile_route_row(
        est, lvl, "profile",
        if (is_unit_slope_rho) "partial" else "blocked",
        if (is_unit_slope_rho) {
          "fix_refit:profile_ci_correlation:unit_slope_selected_entry"
        } else {
          paste0("augmented_split_target_table:", target$target_state)
        },
        if (is_unit_slope_rho) {
          "RE-12;CI-11"
        } else {
          "RE-03;RE-12;SPA-08;SPA-09;SPA-10;PHY-11..18"
        },
        if (is_unit_slope_rho) {
          "Gaussian selected-entry rho:unit_slope profile canary is wired with known-DGP truth-inclusion evidence; calibration and broader augmented targets remain blocked."
        } else {
          "Point extraction/recovery may exist, and Design 74 declares the symbolic target, but profile CIs are not implemented or calibrated."
        },
        if (is_unit_slope_rho) {
          "Run boundary and empirical calibration before promoting beyond a canary."
        } else {
          target$profile_gate
        }
      )
    }
  }

  out <- do.call(rbind, rows)
  ## Release boundary (2026-07-11): the nonlinear quadratic-penalty driver did
  ## not enforce a sufficiently tight constraint or expose a complete
  ## constrained-optimizer status ledger. Keep the historical row inventory,
  ## but normalize every affected public route to blocked until an exact
  ## constraint solver and calibration gate replace the prototype.
  nonlinear <- out$estimand %in% c("communality", "rho", "proportion") &
    out$method == "profile" &
    !out$status %in% c("point_only", "not_applicable")
  out$status[nonlinear] <- "blocked"
  out$route[nonlinear] <- "withheld_nonlinear_penalty_profile"
  out$validation_row[nonlinear] <- ""
  out$claim[nonlinear] <- paste(
    "The former penalty-profile prototype remains internal;",
    "the public extractor and confint routes stop with an explanation."
  )
  out$next_gate[nonlinear] <- paste(
    "Implement an exact or demonstrably tight constraint, require usable",
    "constrained optimisation, expose failures, and establish target-specific",
    "coverage before restoring the route."
  )
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
    "phy_dep",
    "phy_slope",
    "spde_base_slope",
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
