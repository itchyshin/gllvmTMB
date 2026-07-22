## Direct profile-target inventory for `gllvmTMB_multi` fits.
##
## A "profile target" is anything a user might want a profile-
## likelihood confidence interval on. Direct targets correspond to
## a single TMB-parameter element and can be profiled via
## `TMB::tmbprofile()` (wrapped by `tmbprofile_wrapper()`). Derived
## Nonlinear derived targets are intentionally absent because their former
## penalty-profile routes are withheld. The simple two-component phylogenetic
## signal route is documented separately.
##
## The controlled vocabularies on `target_type`, `profile_note`, and
## `transformation` are mirrored from drmTMB so the broader TMB-
## package family stays consistent. gllvmTMB-specific additions:
##   - `transformation`: `lambda_packed` (packed lower-triangular
##     Lambda entries), `ordinal_threshold` (cumulative threshold
##     increments).
##   - `profile_note`: `latent_rotation_ambiguous` -- for cases
##     where a derived rotation-invariant quantity (e.g.
##     communality) is mathematically identifiable but the
##     underlying `Lambda` entry is not.

## ---- Registry of direct TMB parameters ----------------------------------

## One entry per TMB parameter we expose as a profile target. Maps the
## raw TMB name to a user-facing parm-label, the target class, and the
## natural-scale transformation. New families / covstructs add rows
## here.
##
## Each row has:
##   tmb_parameter      : TMB-side name appearing in names(fit$opt$par)
##   label_prefix       : user-facing parm-label root (the engine
##                        appends [t] / [t, k] for vector / matrix
##                        elements)
##   target_class       : fixed_effect / variance / dispersion /
##                        loading_packed / threshold / scaling
##   transformation     : linear_predictor / exp / logit /
##                        logit_p_tweedie / lambda_packed /
##                        ordinal_threshold
.profile_target_registry <- list(
  ## Fixed effects -------------------------------------------------
  list(
    tmb_parameter = "b_fix",
    label_prefix = "b_fix",
    target_class = "fixed_effect",
    transformation = "linear_predictor"
  ),

  ## Gaussian residual SD ----------------------------------------
  list(
    tmb_parameter = "log_sigma_eps",
    label_prefix = "sigma_eps",
    target_class = "variance",
    transformation = "exp"
  ),

  ## Unique-variance diagonals (theta_diag_*) --------------------
  ## These are log-SDs of the per-trait unique-variance. The
  ## natural-scale label is sd_<tier>[t].
  list(
    tmb_parameter = "theta_diag_B",
    label_prefix = "sd_B",
    target_class = "variance",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "theta_diag_W",
    label_prefix = "sd_W",
    target_class = "variance",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "theta_diag_species",
    label_prefix = "sd_phy_unique",
    target_class = "variance",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "theta_diag_species",
    label_prefix = "sd_cluster",
    target_class = "variance",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "theta_diag_cluster2",
    label_prefix = "sd_cluster2",
    target_class = "variance",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_sd_phy_diag",
    label_prefix = "sd_phy_diag",
    target_class = "variance",
    transformation = "exp"
  ),

  ## Latent loadings (packed lower-triangular) -------------------
  list(
    tmb_parameter = "theta_rr_B",
    label_prefix = "Lambda_B_packed",
    target_class = "loading_packed",
    transformation = "lambda_packed"
  ),
  list(
    tmb_parameter = "theta_rr_W",
    label_prefix = "Lambda_W_packed",
    target_class = "loading_packed",
    transformation = "lambda_packed"
  ),
  list(
    tmb_parameter = "theta_rr_phy",
    label_prefix = "Lambda_phy_packed",
    target_class = "loading_packed",
    transformation = "lambda_packed"
  ),
  list(
    tmb_parameter = "theta_rr_spde_lv",
    label_prefix = "Lambda_spde_packed",
    target_class = "loading_packed",
    transformation = "lambda_packed"
  ),

  ## Phylogenetic + spatial scaling parameters -------------------
  list(
    tmb_parameter = "loglambda_phy",
    label_prefix = "lambda_phy",
    target_class = "scaling",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_tau_spde",
    label_prefix = "tau_spde",
    target_class = "scaling",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_kappa_spde",
    label_prefix = "kappa_spde",
    target_class = "scaling",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_sigma_slope",
    label_prefix = "sigma_phy_slope",
    target_class = "variance",
    transformation = "exp"
  ),

  ## Random intercept components ---------------------------------
  list(
    tmb_parameter = "log_sigma_re_int",
    label_prefix = "sigma_re_int",
    target_class = "variance",
    transformation = "exp"
  ),

  ## Dispersion / shape parameters (per-family) ------------------
  list(
    tmb_parameter = "log_phi_nbinom2",
    label_prefix = "phi_nbinom2",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_nbinom1",
    label_prefix = "phi_nbinom1",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_gamma",
    label_prefix = "phi_gamma",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_tweedie",
    label_prefix = "phi_tweedie",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "logit_p_tweedie",
    label_prefix = "p_tweedie",
    target_class = "dispersion",
    transformation = "logit_p_tweedie"
  ),
  list(
    tmb_parameter = "log_phi_beta",
    label_prefix = "phi_beta",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_betabinom",
    label_prefix = "phi_betabinom",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_sigma_student",
    label_prefix = "sigma_student",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_df_student",
    label_prefix = "df_student",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_truncnb2",
    label_prefix = "phi_truncnb2",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_sigma_lognormal_delta",
    label_prefix = "sigma_lognormal_delta",
    target_class = "dispersion",
    transformation = "exp"
  ),
  list(
    tmb_parameter = "log_phi_gamma_delta",
    label_prefix = "phi_gamma_delta",
    target_class = "dispersion",
    transformation = "exp"
  ),

  ## Ordinal threshold increments --------------------------------
  list(
    tmb_parameter = "ordinal_log_increments",
    label_prefix = "ordinal_increment",
    target_class = "threshold",
    transformation = "ordinal_threshold"
  )
)

## ---- Derived targets registry ------------------------------------------

## Nonlinear derived-target penalty profiles and the diagonal-only ratio once
## labelled repeatability are withheld from the public release. Keep this
## registry empty so profile_targets() is an honest inventory of direct TMB
## parameter targets only. The separate two-component phylogenetic-signal helper
## remains documented at its own entry point rather than being generalized here.
.derived_target_registry <- list()

## ---- Internal helpers ---------------------------------------------------

## Apply the per-row natural-scale transformation. Returns the
## "estimate" column entry from the "link_estimate" column entry.
.profile_target_transform <- function(link_estimate, transformation) {
  switch(
    transformation,
    "linear_predictor" = link_estimate,
    "exp" = exp(link_estimate),
    "logit" = stats::plogis(link_estimate),
    "logit_p_tweedie" = 1 + stats::plogis(link_estimate),
    "lambda_packed" = link_estimate,
    "ordinal_threshold" = exp(link_estimate),
    NA_real_
  )
}

## Construct the per-element parm label. For scalar parameters
## (length 1), return the bare `label_prefix`; for vector parameters,
## return `label_prefix[index]`.
.profile_target_label <- function(prefix, index, block_length) {
  if (block_length == 1L) prefix else sprintf("%s[%d]", prefix, index)
}

## Find a registry entry by TMB name; NULL if not registered.
.profile_target_lookup <- function(tmb_name) {
  hits <- .profile_target_lookup_all(tmb_name)
  if (length(hits) == 0L) {
    return(NULL)
  }
  hits[[1L]]
}

## Find all registry entries by TMB name. Some TMB blocks have a legacy
## label plus a clearer tier label; keep both as direct profile aliases.
.profile_target_lookup_all <- function(tmb_name) {
  hits <- list()
  for (entry in .profile_target_registry) {
    if (entry$tmb_parameter == tmb_name) {
      hits[[length(hits) + 1L]] <- entry
    }
  }
  hits
}

## Validate the controlled vocabularies. Errors with a typed
## abort class on the first violation. Mirrors drmTMB's
## `validate_profile_targets()` discipline.
.validate_profile_targets <- function(df) {
  required_cols <- c(
    "parm",
    "target_class",
    "tmb_parameter",
    "index",
    "estimate",
    "link_estimate",
    "scale",
    "transformation",
    "target_type",
    "profile_ready",
    "profile_note"
  )
  missing_cols <- setdiff(required_cols, colnames(df))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      c(
        "Internal: {.fn profile_targets} output missing columns.",
        "x" = "Missing: {.val {missing_cols}}"
      ),
      class = "gllvmTMB_profile_targets_invalid"
    )
  }

  ok_target_type <- "direct"
  ok_profile_note <- c(
    "ready",
    "tmb_object_required",
    "missing_tmb_parameter",
    "latent_rotation_ambiguous"
  )
  ok_transformation <- c(
    "linear_predictor",
    "exp",
    "logit",
    "logit_p_tweedie",
    "lambda_packed",
    "ordinal_threshold"
  )

  bad_tt <- setdiff(df$target_type, ok_target_type)
  if (length(bad_tt) > 0L) {
    cli::cli_abort(
      c(
        "Internal: invalid {.field target_type} values.",
        "x" = "Got: {.val {bad_tt}}",
        "i" = "Allowed: {.val {ok_target_type}}"
      ),
      class = "gllvmTMB_profile_targets_invalid"
    )
  }

  bad_pn <- setdiff(df$profile_note, ok_profile_note)
  if (length(bad_pn) > 0L) {
    cli::cli_abort(
      c(
        "Internal: invalid {.field profile_note} values.",
        "x" = "Got: {.val {bad_pn}}",
        "i" = "Allowed: {.val {ok_profile_note}}"
      ),
      class = "gllvmTMB_profile_targets_invalid"
    )
  }

  bad_tx <- setdiff(df$transformation, ok_transformation)
  if (length(bad_tx) > 0L) {
    cli::cli_abort(
      c(
        "Internal: invalid {.field transformation} values.",
        "x" = "Got: {.val {bad_tx}}",
        "i" = "Allowed: {.val {ok_transformation}}"
      ),
      class = "gllvmTMB_profile_targets_invalid"
    )
  }

  ## No duplicate parm labels.
  dup_parm <- df$parm[duplicated(df$parm)]
  if (length(dup_parm) > 0L) {
    cli::cli_abort(
      c(
        "Internal: duplicate {.field parm} labels in profile_targets output.",
        "x" = "Duplicate: {.val {dup_parm}}"
      ),
      class = "gllvmTMB_profile_targets_invalid"
    )
  }

  invisible(df)
}

## ---- Main: profile_targets() -------------------------------------------

#' List profile-ready confidence-interval targets for a fitted model
#'
#' `profile_targets()` is an advanced inventory for users who need to
#' diagnose or script profile confidence intervals. Most users should
#' start with [confint.gllvmTMB_multi()] or a report-ready extractor
#' such as [extract_correlations()]. This helper tells you which
#' `parm` labels can be profiled directly.
#'
#' The returned tidy data frame has one row per profile target and
#' records whether the target is profile-ready and, if not, why.
#' Direct targets correspond to a single TMB parameter element (for
#' example `b_fix[1]`, `sigma_eps`, or `sd_B[2]`) and can be passed to
#' `confint(fit, parm = ..., method = "profile")`. Nonlinear derived targets
#' are excluded because their former penalty-profile routes are withheld.
#'
#' Scope: the controlled vocabulary and direct-profile routing is
#' covered for fitted models with retained TMB objects. Broader
#' target-explicit profile calibration remains future work.
#'
#' The output uses a controlled vocabulary for direct target classes,
#' transformations, and readiness notes.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param ready_only If `TRUE`, return only rows with
#'   `profile_ready = TRUE`. Default `FALSE` returns the full
#'   inventory.
#'
#' @return A data frame with one row per target and the following
#'   columns:
#'   \describe{
#'     \item{`parm`}{User-facing target label, e.g. `b_fix[1]`,
#'       `sigma_eps`, or `sd_B[2]`.}
#'     \item{`target_class`}{One of `fixed_effect`, `variance`,
#'       `dispersion`, `loading_packed`, `threshold`, or `scaling`.}
#'     \item{`tmb_parameter`}{TMB-side parameter name (matches
#'       `names(fit$opt$par)`).}
#'     \item{`index`}{1-based index within the TMB parameter vector.
#'       `NA` for scalars.}
#'     \item{`estimate`}{Point estimate on the natural scale (e.g.
#'       `sigma_eps = exp(log_sigma_eps)`).}
#'     \item{`link_estimate`}{Point estimate on the optimisation
#'       scale (the TMB internal scale).}
#'     \item{`scale`}{Either `"natural"` (after applying the
#'       transformation) or `"link"` (for raw packed entries).}
#'     \item{`transformation`}{One of `linear_predictor`, `exp`,
#'       `logit`, `logit_p_tweedie`, `lambda_packed`,
#'       or `ordinal_threshold`.}
#'     \item{`target_type`}{Always `"direct"` for currently returned rows.}
#'     \item{`profile_ready`}{`TRUE` iff the target can be passed
#'       directly to `confint(fit, parm = ..., method = "profile")`.}
#'     \item{`profile_note`}{One of `ready`, `tmb_object_required`,
#'       `missing_tmb_parameter`, or `latent_rotation_ambiguous`.}
#'   }
#'
#' @seealso [confint.gllvmTMB_multi()] for the routing of
#'   `method = c("wald", "profile")`,
#'   [tmbprofile_wrapper()] for direct-parameter profiling. For nonlinear
#'   summaries, consult the relevant extractor; a method token does not imply
#'   that a profile interval is currently available.
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'                 data  = sim$data,
#'                 trait = "trait",
#'                 unit  = "site")
#' targets <- profile_targets(fit)
#' head(targets)
#' profile_targets(fit, ready_only = TRUE)
#' }
#'
#' @export
profile_targets <- function(object, ready_only = FALSE) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }

  has_tmb_obj <- !is.null(object$tmb_obj)
  par <- object$opt$par
  par_names <- names(par)

  ## Walk opt$par element by element, grouping consecutive entries
  ## with the same name (the TMB convention is one repeated name
  ## per parameter block).
  rows <- list()
  for (tmb_name in unique(par_names)) {
    entries <- .profile_target_lookup_all(tmb_name)
    if (length(entries) == 0L) {
      next
    } # not in registry; skip silently
    idx_block <- which(par_names == tmb_name)
    block_length <- length(idx_block)
    for (entry in entries) {
      for (k in seq_along(idx_block)) {
        i <- idx_block[k]
        link_est <- unname(par[i])
        est <- .profile_target_transform(link_est, entry$transformation)
        parm_label <- .profile_target_label(entry$label_prefix, k, block_length)
        scale_str <- if (
          entry$transformation %in%
            c("lambda_packed")
        ) {
          "link"
        } else {
          "natural"
        }
        profile_note <- if (has_tmb_obj) "ready" else "tmb_object_required"
        rows[[length(rows) + 1L]] <- data.frame(
          parm = parm_label,
          target_class = entry$target_class,
          tmb_parameter = tmb_name,
          index = if (block_length == 1L) NA_integer_ else k,
          estimate = est,
          link_estimate = link_est,
          scale = scale_str,
          transformation = entry$transformation,
          target_type = "direct",
          profile_ready = has_tmb_obj,
          profile_note = profile_note,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(rows) == 0L) {
    out <- data.frame(
      parm = character(0),
      target_class = character(0),
      tmb_parameter = character(0),
      index = integer(0),
      estimate = numeric(0),
      link_estimate = numeric(0),
      scale = character(0),
      transformation = character(0),
      target_type = character(0),
      profile_ready = logical(0),
      profile_note = character(0)
    )
  } else {
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
  }

  .validate_profile_targets(out)

  if (isTRUE(ready_only)) {
    out <- out[which(out$profile_ready), , drop = FALSE]
  }

  out
}
