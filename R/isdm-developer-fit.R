## -------------------------------------------------------------------------
## Developer-only two-source integrated-SDM route.
##
## This is deliberately unexported. It maps the validated iSDM row contract
## onto the native long-table engine, retaining the existing public guard that
## family/link cannot vary within a trait. Only this helper marks the narrow
## Poisson-log / Bernoulli-cloglog exception used for iSDM development.
## -------------------------------------------------------------------------

.isdm_formula <- function(x_names, b_names, d, spatial = FALSE) {
  spatial_term <- if (isTRUE(spatial)) {
    sprintf("spatial_latent(1 + isdm_gbif | cell_id, d = %d)", d)
  } else {
    sprintf("latent(0 + trait | cell_id, d = %d)", d)
  }
  terms <- c(
    "0 + trait",
    paste0("trait:", x_names),
    "trait:isdm_gbif",
    paste0("trait:", b_names),
    "offset(log_support)",
    ## spatial_latent() is deliberately loadings-only.  The independent
    ## cell-by-species term is the declared ecological e_cs / Psi companion;
    ## it is not a second spatial field and has no GBIF-bias slope.
    if (isTRUE(spatial)) "indep(0 + trait | cell_id)" else NULL,
    spatial_term
  )
  stats::as.formula(
    paste("value ~", paste(terms, collapse = " + ")),
    env = parent.frame()
  )
}

## An identity sentinel, not a public-data attribute, admits the narrow
## PA-cloglog augmented-SPDE exception.  It is namespace-internal and not a
## supported public opt-in; .gll_isdm_fit() is its only intended constructor.
.isdm_spatial_admission_token <- local({
  token <- new.env(parent = emptyenv())
  function() token
})

.isdm_spatial_eta <- function(eta_ecological, eta_gbif_field, isdm_gbif) {
  n <- length(eta_ecological)
  if (length(eta_gbif_field) != n || length(isdm_gbif) != n ||
      any(!is.finite(eta_ecological)) || any(!is.finite(eta_gbif_field)) ||
      any(!isdm_gbif %in% c(0L, 1L))) {
    .isdm_abort(
      "spatial iSDM predictors must be finite and source-gated with binary isdm_gbif."
    )
  }
  as.numeric(eta_ecological) + as.numeric(isdm_gbif) * as.numeric(eta_gbif_field)
}

.isdm_validate_spatial_mesh <- function(mesh, n_obs) {
  has_projection <- !is.null(mesh) && !is.null(mesh$A_st) &&
    (is.matrix(mesh$A_st) || inherits(mesh$A_st, "Matrix"))
  if (!has_projection) {
    .isdm_abort("spatial = TRUE requires a gllvmTMB mesh with an A_st projection.")
  }
  if (nrow(mesh$A_st) != n_obs) {
    .isdm_abort(
      "spatial iSDM mesh$A_st must have one projection row per prepared observation."
    )
  }
  invisible(TRUE)
}

.isdm_developer_data <- function(rows, X, B) {
  contract <- .prepare_isdm_contract(rows = rows, X = X, B = B)
  dat <- contract$rows
  dat$trait <- factor(dat$trait)
  dat$cell_id <- factor(dat$cell_id)
  dat$isdm_gbif <- as.integer(dat$source == "gbif")

  x_names <- paste0("isdm_x_", make.names(colnames(contract$X), unique = TRUE))
  b_names <- paste0(
    "isdm_gbif_b_",
    make.names(colnames(contract$B), unique = TRUE)
  )
  for (k in seq_along(x_names)) dat[[x_names[[k]]]] <- contract$X[, k]

  ## B is NA by contract on surveys. Materialise the source gate once here:
  ## every survey row receives structural zero, not a fitted/estimated gate.
  for (k in seq_along(b_names)) {
    dat[[b_names[[k]]]] <- ifelse(
      dat$isdm_gbif == 1L,
      contract$B[, k],
      0
    )
  }
  list(data = dat, x_names = x_names, b_names = b_names)
}

#' Developer-only two-source iSDM fit
#' @keywords internal
#' @noRd
.gll_isdm_fit <- function(rows, X, B, d = 1L, control = gllvmTMBcontrol(),
                          silent = TRUE, mesh = NULL, spatial = FALSE) {
  if (!is.numeric(d) || length(d) != 1L || !is.finite(d) || d < 1L ||
      d != as.integer(d)) {
    .isdm_abort("d must be one positive integer ecological latent rank.")
  }
  if (!identical(control$aghq, FALSE)) {
    .isdm_abort(
      "the private iSDM route currently uses the Laplace objective only; AGHQ is not admitted."
    )
  }
  prepared <- .isdm_developer_data(rows = rows, X = X, B = B)
  dat <- prepared$data
  if (!is.logical(spatial) || length(spatial) != 1L || is.na(spatial)) {
    .isdm_abort("spatial must be one non-missing logical value.")
  }
  if (isTRUE(spatial)) .isdm_validate_spatial_mesh(mesh, nrow(dat))
  formula <- .isdm_formula(
    prepared$x_names, prepared$b_names, as.integer(d), spatial = spatial
  )

  has_pa <- any(dat$branch == "pa")
  if (isTRUE(spatial) && !has_pa) {
    .isdm_abort(
      "the private spatial iSDM route admits only the exact GBIF Poisson/log plus survey PA-cloglog contract."
    )
  }
  if (has_pa) {
    dat$isdm_family <- factor(
      ifelse(dat$source == "gbif", "gbif", "survey_pa"),
      levels = c("gbif", "survey_pa")
    )
    family <- list(gbif = stats::poisson(), survey_pa = stats::binomial(link = "cloglog"))
    attr(family, "family_var") <- "isdm_family"
    attr(family, "gllvmTMB_internal_isdm") <- TRUE
    if (isTRUE(spatial)) {
      attr(family, "gllvmTMB_internal_isdm_spatial_token") <-
        .isdm_spatial_admission_token()
    }
  } else {
    family <- stats::poisson()
  }
  attr(family, "gllvmTMB_internal_isdm_report") <- TRUE

  fit_args <- list(
    formula = formula,
    data = dat,
    trait = "trait",
    unit = "cell_id",
    family = family,
    control = control,
    silent = silent
  )
  if (isTRUE(spatial)) fit_args$mesh <- mesh
  fit <- do.call(gllvmTMB, fit_args)
  fit$isdm_developer <- list(
    survey_branch = if (has_pa) "pa_cloglog" else "count_poisson",
    source_gate_column = "isdm_gbif",
    ecological_columns = prepared$x_names,
    gbif_bias_columns = prepared$b_names,
    spatial = isTRUE(spatial),
    spatial_source_map = if (isTRUE(spatial)) {
      list(
        ecological_column = "(Intercept)",
        gbif_bias_column = "isdm_gbif",
        shared_mesh_range_rank = TRUE,
        pa_gbif_field_structural_zero = TRUE
      )
    } else NULL,
    relative_intensity_only = TRUE,
    public_api = FALSE
  )
  fit
}
