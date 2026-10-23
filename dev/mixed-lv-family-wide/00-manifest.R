## Immutable ADEMP manifest: family-wide predictor-informed ordinary LV.
##
## Alignment table
## | Symbol | Fit grammar | DGP | Recovery target | Truth |
## | u_i = alpha*x_i + e_i | latent(..., d=1, unique=FALSE, lv=~x) |
## | alpha=0.6, e_i~N(0,1) | score identity | mean + innovation |
## | B_lv = Lambda*alpha' | same ordinary LV term | fixed Lambda, alpha |
## | extract_lv_effects(type="trait_effect") | Lambda*alpha' |
## | Sigma_shared = Lambda*Lambda' | same ordinary LV term | fixed Lambda |
## | extract_Sigma(part="shared") | Lambda*Lambda' |
## | beta_0t | 0 + trait | family-scale intercepts | fitted trait intercepts |
##
## Raw alpha, raw Lambda, and signed raw scores are never cross-fit targets.

MIXED_LV_HARNESS_SCHEMA <- "mixed-lv-family-wide-v2"
MIXED_LV_MANIFEST_ID <- "mixed-lv-family-wide-v2__mixed19x200__pure19x200__8x500__K1__unique-false"
MIXED_LV_FORMULA_ID <- "value~0+trait+latent(0+trait|unit,d=1,unique=FALSE,lv=~x)"
MIXED_LV_PINNED_HEAD <- "7dd5eec733c42c722fe94be4c0e5a2efe1f4a3c3"
MIXED_LV_SEED_BASE <- 202608250L
MIXED_LV_SCIENTIFIC_TARGETS <-
  c("B_lv", "Sigma_shared", "intercept", "score_identity")
MIXED_LV_FORBIDDEN_TARGETS <-
  c("alpha", "Lambda", "raw_alpha", "raw_Lambda", "raw_score")

MIXED_LV_THRESHOLDS <- list(
  recovery_reps = 200L,
  calibration_reps = 500L,
  min_interval_eligible = 450L,
  min_convergence_rate = 0.95,
  min_point_availability_rate = 0.90,
  max_abs_B_bias = 0.10,
  max_B_rmse = 0.20,
  max_abs_Sigma_entry_bias = 0.15,
  max_abs_intercept_bias = 0.10,
  coverage_band = c(0.92, 0.98),
  max_score_identity_error = 1e-8,
  max_gradient = 1e-2
)

MIXED_LV_SOURCE_MANIFEST <- data.frame(
  path = c(
    "R/lv-predictor.R", "R/families.R", "R/fit-multi.R", "R/gllvmTMB.R",
    "R/extractors.R", "R/extract-sigma.R", "src/gllvmTMB.cpp"
  ),
  md5 = c(
    "03149776b17f0d4141cc7a9618a3bd1b",
    "3f229abe589813eee5e0f3e4bd92f005",
    "e0b0edb758b39a2ebf35c46f90114c20",
    "9746f7cddcbd567e3c563549bc328893",
    "cafc7037e00bbf25a3c97368932477d5",
    "6b933e073d3ceb9f6ae29444a20d2f08",
    "67bcf53f02b7e5b6b224af92b0bfab4f"
  ),
  stringsAsFactors = FALSE
)

mixed_lv_cell <- function(cell_id, cell_kind, family_ids, link_ids = 0L,
                          n_units = 240L, n_repeats = 1L,
                          calibration_selected = FALSE,
                          contract_note = "") {
  family_ids <- as.integer(family_ids)
  link_ids <- rep_len(as.integer(link_ids), length(family_ids))
  data.frame(
    cell_id = cell_id,
    cell_kind = cell_kind,
    route_key = paste(paste(family_ids, link_ids, sep = ":"), collapse = "+"),
    family_ids = paste(family_ids, collapse = ","),
    link_ids = paste(link_ids, collapse = ","),
    n_units = as.integer(n_units),
    n_repeats = as.integer(n_repeats),
    rank = 1L,
    unique = FALSE,
    calibration_selected = isTRUE(calibration_selected),
    contract_note = contract_note,
    stringsAsFactors = FALSE
  )
}

mixed_lv_cells <- function() {
  delta_note <- paste(
    "Native shared-eta constrained dual effect: B_lv acts on occurrence log-odds",
    "and positive-part log mean; it is not an unconditional response-mean effect."
  )
  pure <- list(
    mixed_lv_cell("p00-gaussian", "pure", 0L),
    mixed_lv_cell("p01-binomial-logit", "pure", 1L, 0L),
    mixed_lv_cell("p01-binomial-probit", "pure", 1L, 1L),
    mixed_lv_cell("p01-binomial-cloglog", "pure", 1L, 2L),
    mixed_lv_cell("p02-poisson", "pure", 2L),
    mixed_lv_cell("p03-lognormal", "pure", 3L),
    mixed_lv_cell("p04-Gamma", "pure", 4L),
    mixed_lv_cell("p05-nbinom2", "pure", 5L, n_units = 300L),
    mixed_lv_cell("p06-tweedie", "pure", 6L),
    mixed_lv_cell("p07-Beta", "pure", 7L),
    mixed_lv_cell("p08-betabinomial", "pure", 8L),
    mixed_lv_cell("p09-student", "pure", 9L),
    mixed_lv_cell("p10-truncated-poisson", "pure", 10L, n_units = 300L,
      contract_note = "B_lv is a parent log-rate effect."),
    mixed_lv_cell("p11-truncated-nbinom2", "pure", 11L, n_units = 300L,
      contract_note = "B_lv is a parent log-mean effect."),
    mixed_lv_cell("p12-delta-lognormal", "pure", 12L, n_units = 800L,
      contract_note = delta_note),
    mixed_lv_cell("p13-delta-Gamma", "pure", 13L, n_units = 400L,
      contract_note = delta_note),
    mixed_lv_cell("p14-ordinal-probit", "pure", 14L, n_units = 400L),
    mixed_lv_cell("p15-nbinom1", "pure", 15L),
    mixed_lv_cell("p16-multinomial", "pure", 16L, n_units = 240L,
      n_repeats = 5L, contract_note = "Score labelled K-1 contrasts." )
  )
  mixed <- list(
    mixed_lv_cell("m01-gaussian__binomial-logit", "mixed", c(0L, 1L),
      c(0L, 0L), n_units = 240L, calibration_selected = TRUE),
    mixed_lv_cell("m01-gaussian__binomial-probit", "mixed", c(0L, 1L), c(0L, 1L), n_units = 240L),
    mixed_lv_cell("m01-gaussian__binomial-cloglog", "mixed", c(0L, 1L), c(0L, 2L), n_units = 240L),
    mixed_lv_cell("m02-gaussian__poisson", "mixed", c(0L, 2L), n_units = 240L, calibration_selected = TRUE),
    mixed_lv_cell("m03-poisson__lognormal", "mixed", c(2L, 3L), n_units = 240L),
    mixed_lv_cell("m04-gaussian__Gamma", "mixed", c(0L, 4L), n_units = 240L, calibration_selected = TRUE),
    mixed_lv_cell("m05-gaussian__nbinom2", "mixed", c(0L, 5L), n_units = 300L,
      calibration_selected = TRUE),
    mixed_lv_cell("m06-gaussian__tweedie", "mixed", c(0L, 6L), n_units = 240L),
    mixed_lv_cell("m07-gaussian__Beta", "mixed", c(0L, 7L), n_units = 240L, calibration_selected = TRUE),
    mixed_lv_cell("m08-gaussian__betabinomial", "mixed", c(0L, 8L), n_units = 240L),
    mixed_lv_cell("m09-gaussian__student", "mixed", c(0L, 9L), n_units = 240L),
    mixed_lv_cell("m10-gaussian__truncated-poisson", "mixed", c(0L, 10L), n_units = 300L),
    mixed_lv_cell("m11-gaussian__truncated-nbinom2", "mixed", c(0L, 11L), n_units = 300L),
    mixed_lv_cell("m12-gaussian__delta-lognormal", "mixed", c(0L, 12L),
      n_units = 800L, contract_note = delta_note),
    mixed_lv_cell("m13-gaussian__delta-Gamma", "mixed", c(0L, 13L), n_units = 400L,
      calibration_selected = TRUE, contract_note = delta_note),
    mixed_lv_cell("m14-gaussian__ordinal-probit", "mixed", c(0L, 14L), n_units = 400L,
      calibration_selected = TRUE),
    mixed_lv_cell("m15-gaussian__nbinom1", "mixed", c(0L, 15L), n_units = 240L),
    mixed_lv_cell("m16-gaussian__multinomial", "mixed", c(0L, 16L),
      n_units = 240L, n_repeats = 5L, calibration_selected = TRUE),
    mixed_lv_cell("m17-poisson__Gamma__Beta-sentinel", "sentinel", c(2L, 4L, 7L), n_units = 240L)
  )
  do.call(rbind, c(pure, mixed))
}

mixed_lv_validate_manifest <- function(cells = mixed_lv_cells()) {
  if (nrow(cells) != 38L || anyDuplicated(cells$cell_id) ||
      anyDuplicated(cells$route_key)) {
    stop("manifest_bijection_failure: expected 38 unique cell and route keys")
  }
  expected_pure <- c("0:0", "1:0", "1:1", "1:2", paste0(2:16, ":0"))
  observed_pure <- cells$route_key[cells$cell_kind == "pure"]
  if (!setequal(observed_pure, expected_pure)) {
    stop("manifest_bijection_failure: pure routes do not cover the frozen family/link surface")
  }
  if (!identical(c(sum(cells$cell_kind == "pure"),
                   sum(cells$cell_kind == "mixed"),
                   sum(cells$cell_kind == "sentinel")), c(19L, 18L, 1L))) {
    stop("manifest_bijection_failure: route-kind denominator changed")
  }
  invisible(TRUE)
}

mixed_lv_validate_target <- function(target) {
  if (target %in% MIXED_LV_FORBIDDEN_TARGETS ||
      !(target %in% MIXED_LV_SCIENTIFIC_TARGETS)) {
    stop("forbidden rotation-dependent or unknown scientific target: ", target)
  }
  invisible(TRUE)
}

mixed_lv_repo_root <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(".", file.path("..", ".."), workspace)
  ok <- vapply(candidates, function(x) !is.na(x) &&
    file.exists(file.path(x, "DESCRIPTION")) &&
    file.exists(file.path(x, "R", "lv-predictor.R")), logical(1L))
  if (!any(ok)) stop("cannot resolve gllvmTMB repository root for source gate")
  normalizePath(candidates[ok][[1L]], mustWork = TRUE)
}

mixed_lv_observe_source_manifest <- function(root = mixed_lv_repo_root()) {
  transform(MIXED_LV_SOURCE_MANIFEST,
    observed_md5 = unname(tools::md5sum(file.path(root, path))))
}

mixed_lv_validate_source_manifest <- function(observed = mixed_lv_observe_source_manifest()) {
  required <- c("path", "md5", "observed_md5")
  if (!all(required %in% names(observed)) ||
      nrow(observed) != nrow(MIXED_LV_SOURCE_MANIFEST) ||
      anyNA(observed$observed_md5) ||
      !all(observed$md5 == observed$observed_md5)) {
    stop("source_hash_mismatch: candidate source paths do not match the frozen manifest")
  }
  invisible(TRUE)
}

mixed_lv_validate_source_identity <- function(head, observed = mixed_lv_observe_source_manifest()) {
  if (!identical(as.character(head), MIXED_LV_PINNED_HEAD)) {
    stop("source_head_mismatch: candidate HEAD differs from the frozen manifest")
  }
  mixed_lv_validate_source_manifest(observed)
}

mixed_lv_harness_manifest <- function(root = mixed_lv_repo_root()) {
  paths <- file.path("dev", "mixed-lv-family-wide",
    c(
      "00-manifest.R", "01-run.R", "02-summarise.R",
      "03-totoro-launch.sh", "04-totoro-detached.sh",
      "05-totoro-run.R", "06-totoro-collect.R"
    ))
  data.frame(path = paths,
    md5 = unname(tools::md5sum(file.path(root, paths))), stringsAsFactors = FALSE)
}

mixed_lv_task_grid <- function(campaign_kind = c(
                                 "recovery", "pure_recovery", "calibration"
                               ),
                               n_reps = NULL,
                               cells = mixed_lv_cells()) {
  campaign_kind <- match.arg(campaign_kind)
  mixed_lv_validate_manifest(cells)
  expected <- if (campaign_kind == "calibration") {
    MIXED_LV_THRESHOLDS$calibration_reps
  } else MIXED_LV_THRESHOLDS$recovery_reps
  if (!is.null(n_reps)) {
    valid_n <- length(n_reps) == 1L && is.finite(n_reps) &&
      n_reps == as.integer(n_reps) && identical(as.integer(n_reps), expected)
    if (!valid_n) stop(campaign_kind, " production evidence requires exactly ", expected, " replicates")
  }
  if (campaign_kind == "calibration") {
    cells <- cells[cells$calibration_selected, , drop = FALSE]
  } else if (campaign_kind == "pure_recovery") {
    cells <- cells[cells$cell_kind == "pure", , drop = FALSE]
  } else {
    cells <- cells[cells$cell_kind != "pure", , drop = FALSE]
  }
  rows <- lapply(seq_len(nrow(cells)), function(i) {
    data.frame(
      task_id = (i - 1L) * expected + seq_len(expected),
      cell_id = cells$cell_id[[i]],
      route_key = cells$route_key[[i]],
      n_units = cells$n_units[[i]], n_repeats = cells$n_repeats[[i]],
      campaign_kind = campaign_kind,
      rep = seq_len(expected),
      rep_seed = MIXED_LV_SEED_BASE +
        switch(campaign_kind,
          recovery = 0L,
          calibration = 100000000L,
          pure_recovery = 200000000L
        ) +
        i * 10000L + seq_len(expected),
      evidence_eligible = TRUE,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

mixed_lv_canary_grid <- function(n_reps = 3L) {
  n_reps <- as.integer(n_reps)
  if (length(n_reps) != 1L || is.na(n_reps) || n_reps < 1L || n_reps > 3L) {
    stop("route-health canary permits at most three attempts")
  }
  data.frame(
    task_id = seq_len(n_reps),
    cell_id = "m01-gaussian__binomial-logit",
    route_key = "0:0+1:0",
    campaign_kind = "canary",
    rep = seq_len(n_reps),
    rep_seed = MIXED_LV_SEED_BASE + seq_len(n_reps),
    evidence_eligible = FALSE,
    stringsAsFactors = FALSE
  )
}

mixed_lv_assert_evidence_rows <- function(rows) {
  if (any(rows$campaign_kind == "canary") || any(!rows$evidence_eligible)) {
    stop("canary_not_evidence: route-health rows cannot enter retained evidence")
  }
  invisible(TRUE)
}
