## -------------------------------------------------------------------------
## Developer-only two-source integrated-SDM route.
##
## This is deliberately unexported. It maps the validated iSDM row contract
## onto the native long-table engine, retaining the existing public guard that
## family/link cannot vary within a trait. Only this helper marks the narrow
## Poisson-log / Bernoulli-cloglog exception used for iSDM development.
## -------------------------------------------------------------------------

.isdm_formula <- function(x_names, b_names, d) {
  terms <- c(
    "0 + trait",
    paste0("trait:", x_names),
    "trait:isdm_gbif",
    paste0("trait:", b_names),
    "offset(log_support)",
    sprintf("latent(0 + trait | cell_id, d = %d)", d)
  )
  stats::as.formula(
    paste("value ~", paste(terms, collapse = " + ")),
    env = parent.frame()
  )
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
                          silent = TRUE) {
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
  formula <- .isdm_formula(prepared$x_names, prepared$b_names, as.integer(d))

  has_pa <- any(dat$branch == "pa")
  if (has_pa) {
    dat$isdm_family <- factor(
      ifelse(dat$source == "gbif", "gbif", "survey_pa"),
      levels = c("gbif", "survey_pa")
    )
    family <- list(gbif = stats::poisson(), survey_pa = stats::binomial(link = "cloglog"))
    attr(family, "family_var") <- "isdm_family"
    attr(family, "gllvmTMB_internal_isdm") <- TRUE
  } else {
    family <- stats::poisson()
  }
  attr(family, "gllvmTMB_internal_isdm_report") <- TRUE

  fit <- gllvmTMB(
    formula = formula,
    data = dat,
    trait = "trait",
    unit = "cell_id",
    family = family,
    control = control,
    silent = silent
  )
  fit$isdm_developer <- list(
    survey_branch = if (has_pa) "pa_cloglog" else "count_poisson",
    source_gate_column = "isdm_gbif",
    ecological_columns = prepared$x_names,
    gbif_bias_columns = prepared$b_names,
    relative_intensity_only = TRUE,
    public_api = FALSE
  )
  fit
}
