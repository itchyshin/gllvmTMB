# ---------------------------------------------------------------------------
# R -> Julia bridge: run the fast GLLVM.jl engine from R via JuliaCall.
#
# `gllvmTMB(..., engine = "julia")` routes here: we marshal the response matrix +
# model spec to GLLVM.jl's flat `bridge_fit` contract, run the Julia fitter, and
# unmarshal the result into a gllvmTMB-compatible list. JuliaCall is a SUGGESTED
# dependency — everything here errors cleanly if it (or the GLLVM.jl path) is absent.
#
# Contract + family mapping: GLLVM.jl `src/bridge.jl` on the paired checkout.
# ---------------------------------------------------------------------------

# session cache so JuliaCall + GLLVM.jl load only once
.gllvm_jl_env <- new.env(parent = emptyenv())

#' Set up JuliaCall and load the GLLVM.jl engine (once per R session).
#'
#' @param jl_path Path to the GLLVM.jl project that provides `bridge_fit`
#'   (default: option `gllvmTMB.GLLVM.jl.path` or env `GLLVM_JL_PATH`).
#' @param julia_home Julia `bin` directory (default: option `gllvmTMB.julia_home`
#'   or env `JULIA_HOME`; if unset, JuliaCall auto-discovers).
#' @return Invisibly `TRUE` once ready.
#' @export
gllvm_julia_setup <- function(
  jl_path = getOption(
    "gllvmTMB.GLLVM.jl.path",
    Sys.getenv("GLLVM_JL_PATH", "")
  ),
  julia_home = getOption("gllvmTMB.julia_home", Sys.getenv("JULIA_HOME", ""))
) {
  if (isTRUE(.gllvm_jl_env$ready)) {
    return(invisible(TRUE))
  }
  if (!requireNamespace("JuliaCall", quietly = TRUE)) {
    stop(
      "engine = 'julia' requires the 'JuliaCall' package. Install it with install.packages('JuliaCall').",
      call. = FALSE
    )
  }
  if (identical(jl_path, "")) {
    stop(
      "engine = 'julia': set the GLLVM.jl project path via ",
      "options(gllvmTMB.GLLVM.jl.path = '/path/to/GLLVM.jl') or the GLLVM_JL_PATH env var.",
      call. = FALSE
    )
  }
  if (identical(julia_home, "")) {
    JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
  } else {
    JuliaCall::julia_setup(
      JULIA_HOME = julia_home,
      installJulia = FALSE,
      verbose = FALSE
    )
  }
  JuliaCall::julia_command(sprintf(
    'import Pkg; Pkg.activate("%s"); using GLLVM',
    jl_path
  ))
  .gllvm_jl_env$ready <- TRUE
  invisible(TRUE)
}

# Bridge family strings that the current R admission gate sends to
# `GLLVM.bridge_fit`. Keep this intentionally narrower than the paired Julia
# bridge until metadata, labels, parity, and CI-status rows are validated
# (gllvmTMB#488).
.GLLVM_JULIA_BRIDGE_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "nb1",
  "beta",
  "gamma",
  "ordinal",
  "ordinal_probit"
)
.GLLVM_JULIA_MIXED_FAMILY <- "mixed-family vector"
.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "beta",
  "gamma"
)
.GLLVM_JULIA_PLANNED_FAMILIES <- character()
.GLLVM_JULIA_X_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "beta",
  "gamma"
)
.GLLVM_JULIA_MASK_FAMILIES <- c(
  "poisson",
  "binomial",
  "negbinomial",
  "nb1",
  "beta",
  "gamma",
  "ordinal",
  "ordinal_probit"
)
.GLLVM_JULIA_CI_NO_X_FAMILIES <- .GLLVM_JULIA_BRIDGE_FAMILIES
## Scalar-mean post-fit (residuals = response - mu, parametric simulate) is the
## Gaussian/GLM in-sample contract; ordinal has no scalar response mean on the
## bridge payload, so it is excluded here.
.GLLVM_JULIA_POSTFIT_IN_SAMPLE_FAMILIES <- setdiff(
  .GLLVM_JULIA_BRIDGE_FAMILIES,
  c("ordinal", "ordinal_probit")
)
.GLLVM_JULIA_POSTFIT_SIMULATE_FAMILIES <- .GLLVM_JULIA_POSTFIT_IN_SAMPLE_FAMILIES
## predict() IS wired for ordinal: type = "prob" (per-category probabilities) and
## type = "class" (modal category) ride the cutpoints/n_categories bridge payload.
.GLLVM_JULIA_POSTFIT_PREDICT_FAMILIES <- .GLLVM_JULIA_BRIDGE_FAMILIES

.GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS <- c(
  "fit_no_x",
  "fixed_effect_X",
  "missing_response",
  "cbind_binomial",
  "ci_no_x_wald",
  "ci_no_x_profile",
  "ci_no_x_bootstrap",
  "postfit_coef",
  "postfit_fit_stats",
  "postfit_summary",
  "postfit_predict",
  "postfit_residuals",
  "postfit_simulate",
  "postfit_ordination"
)

#' Current R-side capability ledger for the Julia bridge
#'
#' `gllvm_julia_capabilities()` reports the cells admitted by the R
#' `engine = "julia"` bridge before any JuliaCall setup. The table is a
#' conservative R-side ledger, not a promise that every paired `GLLVM.jl`
#' checkout can run every row; live tests still use the checkout supplied via
#' `GLLVM_JL_PATH`.
#'
#' @return A data frame with one row per bridge family plus the narrow
#'   mixed-family vector route. Boolean columns mark currently admitted fit,
#'   transport, no-X CI, and in-sample post-fit method cells. CI columns are
#'   deliberately named `ci_no_x_*`: they do not imply masked, mixed-family, or
#'   non-Gaussian-X intervals. `status` is one of `"partial"` or `"planned"`,
#'   and `notes` records the main boundary.
#' @export
gllvm_julia_capabilities <- function() {
  families <- .GLLVM_JULIA_BRIDGE_FAMILIES
  out <- data.frame(
    family = families,
    fit_no_x = TRUE,
    fixed_effect_X = families %in% .GLLVM_JULIA_X_FAMILIES,
    missing_response = families %in% .GLLVM_JULIA_MASK_FAMILIES,
    cbind_binomial = families == "binomial",
    ci_no_x_wald = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_profile = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_bootstrap = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    postfit_coef = TRUE,
    postfit_fit_stats = TRUE,
    postfit_summary = TRUE,
    postfit_predict = families %in% .GLLVM_JULIA_POSTFIT_PREDICT_FAMILIES,
    postfit_residuals = families %in% .GLLVM_JULIA_POSTFIT_IN_SAMPLE_FAMILIES,
    postfit_simulate = families %in% .GLLVM_JULIA_POSTFIT_SIMULATE_FAMILIES,
    postfit_ordination = TRUE,
    status = "partial",
    notes = ifelse(
      families == "ordinal" | families == "ordinal_probit",
      paste(
        "fit/nobs/mask/CI/ordination/predict route; predict(type='prob'|'class')",
        "uses the cutpoints payload; residual/simulate/augment still need a",
        "response-scale mean"
      ),
      "single reduced-rank latent block; broader structures and parity remain gated"
    ),
    stringsAsFactors = FALSE
  )
  mixed <- data.frame(
    family = .GLLVM_JULIA_MIXED_FAMILY,
    fit_no_x = TRUE,
    fixed_effect_X = FALSE,
    missing_response = FALSE,
    cbind_binomial = FALSE,
    ci_no_x_wald = FALSE,
    ci_no_x_profile = FALSE,
    ci_no_x_bootstrap = FALSE,
    postfit_coef = TRUE,
    postfit_fit_stats = TRUE,
    postfit_summary = TRUE,
    postfit_predict = TRUE,
    postfit_residuals = TRUE,
    postfit_simulate = TRUE,
    postfit_ordination = TRUE,
    status = "partial",
    notes = paste(
      "complete balanced trait-aligned no-X/no-mask/no-CI mixed-family",
      "fits only; component families:",
      paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", ")
    ),
    stringsAsFactors = FALSE
  )
  planned <- data.frame(
    family = .GLLVM_JULIA_PLANNED_FAMILIES,
    fit_no_x = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    fixed_effect_X = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    missing_response = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    cbind_binomial = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    ci_no_x_wald = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    ci_no_x_profile = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    ci_no_x_bootstrap = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_coef = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_fit_stats = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_summary = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_predict = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_residuals = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_simulate = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    postfit_ordination = rep(FALSE, length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    status = rep("planned", length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    notes = character(length(.GLLVM_JULIA_PLANNED_FAMILIES)),
    stringsAsFactors = FALSE
  )
  rbind(out, mixed, planned)
}

.gllvm_julia_capability_logical <- function(x, name, n) {
  value <- x[[name]]
  if (is.null(value)) {
    return(rep(FALSE, n))
  }
  value <- as.logical(unlist(value, use.names = FALSE))
  if (length(value) == 1L && n != 1L) {
    value <- rep(value, n)
  }
  if (length(value) != n) {
    stop(
      "GLLVM.bridge_capabilities returned column '",
      name,
      "' with length ",
      length(value),
      "; expected ",
      n,
      ".",
      call. = FALSE
    )
  }
  value
}

.gllvm_julia_capability_frame <- function(x) {
  family <- as.character(unlist(x$family, use.names = FALSE))
  out <- data.frame(family = family, stringsAsFactors = FALSE)
  for (col in .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS) {
    out[[col]] <- .gllvm_julia_capability_logical(x, col, length(family))
  }
  data.frame(
    out,
    status = as.character(unlist(x$status, use.names = FALSE)),
    notes = as.character(unlist(x$notes, use.names = FALSE)),
    stringsAsFactors = FALSE
  )
}

.gllvm_julia_engine_capabilities <- function(...) {
  gllvm_julia_setup(...)
  .gllvm_julia_capability_frame(
    JuliaCall::julia_call("GLLVM.bridge_capabilities")
  )
}

# Map one R family (a `family` object or a string) to the GLLVM.jl bridge key.
.gllvm_julia_family_scalar <- function(family) {
  if (inherits(family, "family")) {
    family <- family$family
  }
  fam <- tolower(as.character(family))
  if (length(fam) != 1L || is.na(fam)) {
    stop(
      "engine = 'julia': family must resolve to a single supported family name.",
      call. = FALSE
    )
  }
  out <- switch(
    fam,
    gaussian = "gaussian",
    normal = "gaussian",
    poisson = "poisson",
    binomial = "binomial",
    bernoulli = "binomial",
    negbinomial = "negbinomial",
    nbinom2 = "negbinomial",
    nb2 = "negbinomial",
    nbinom1 = "nb1",
    nb1 = "nb1",
    beta = "beta",
    gamma = "gamma",
    ordinal = "ordinal",
    ordinal_probit = "ordinal_probit",
    NA_character_
  )
  if (is.na(out)) {
    stop(
      "engine = 'julia': unsupported family '",
      fam,
      "'. Supported: gaussian, poisson, ",
      "binomial, nbinom2, nbinom1, beta, gamma, ordinal, ordinal_probit.",
      call. = FALSE
    )
  }
  out
}

# Map an R family (a `family` object, a string, a character vector, or a list of
# one family per trait) to the GLLVM.jl bridge family string(s).
.gllvm_julia_family <- function(family) {
  if (is.list(family) && !inherits(family, "family")) {
    fam <- vapply(family, .gllvm_julia_family_scalar, character(1))
    bad <- setdiff(fam, .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES)
    if (length(bad)) {
      stop(
        "engine = 'julia': mixed-family vectors currently support ",
        paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", "),
        "; unsupported component(s): ",
        paste(unique(bad), collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    return(unname(fam))
  }
  if (is.character(family) && length(family) > 1L) {
    fam <- vapply(family, .gllvm_julia_family_scalar, character(1))
    bad <- setdiff(fam, .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES)
    if (length(bad)) {
      stop(
        "engine = 'julia': mixed-family vectors currently support ",
        paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", "),
        "; unsupported component(s): ",
        paste(unique(bad), collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    return(unname(fam))
  }
  .gllvm_julia_family_scalar(family)
}

.gllvm_julia_is_mixed_family <- function(family) {
  length(family) > 1L
}

.gllvm_julia_mixed_ci_status <- function(method = "ci") {
  method <- as.character(method)[1L]
  if (is.na(method) || identical(method, "none")) {
    return("ci_unavailable_mixed_family")
  }
  paste0(method, "_unavailable_mixed_family")
}

.gllvm_julia_mixed_ci_note <- function() {
  paste(
    "confidence intervals for mixed-family Julia-engine fits are not routed",
    "yet. Refit with engine = 'tmb' for native mixed-family inference."
  )
}

.gllvm_julia_stop_mixed_ci <- function(prefix, method) {
  stop(
    prefix,
    ": ci_status = '",
    .gllvm_julia_mixed_ci_status(method),
    "'; ",
    .gllvm_julia_mixed_ci_note(),
    call. = FALSE
  )
}

.gllvm_julia_non_gaussian_x_ci_status <- function(method = "ci") {
  method <- as.character(method)[1L]
  if (is.na(method) || identical(method, "none")) {
    return("ci_unavailable_non_gaussian_x")
  }
  paste0(method, "_unavailable_non_gaussian_x")
}

.gllvm_julia_non_gaussian_x_ci_note <- function() {
  paste(
    "confidence intervals for non-Gaussian fixed-effect-X Julia-engine fits",
    "are not routed through the Julia bridge yet. Use ci_method = 'none' for",
    "point estimates or engine = 'tmb'."
  )
}

.gllvm_julia_stop_non_gaussian_x_ci <- function(prefix, method) {
  stop(
    prefix,
    ": ci_status = '",
    .gllvm_julia_non_gaussian_x_ci_status(method),
    "'; ",
    .gllvm_julia_non_gaussian_x_ci_note(),
    call. = FALSE
  )
}

.gllvm_julia_reml_ci_status <- function(method = "ci") {
  method <- as.character(method)[1L]
  if (is.na(method) || identical(method, "none")) {
    return("ci_unavailable_reml")
  }
  paste0(method, "_unavailable_reml")
}

.gllvm_julia_reml_ci_note <- function() {
  paste(
    "confidence intervals for Gaussian REML Julia-engine fits are not routed",
    "through the Julia bridge yet. Use REML = FALSE for ML intervals or",
    "engine = 'tmb'."
  )
}

.gllvm_julia_stop_reml_ci <- function(prefix, method) {
  stop(
    prefix,
    ": ci_status = '",
    .gllvm_julia_reml_ci_status(method),
    "'; ",
    .gllvm_julia_reml_ci_note(),
    call. = FALSE
  )
}

.gllvm_julia_mixed_selector <- function(family, data, trait, trait_factor) {
  if (!is.list(family) || inherits(family, "family")) {
    return(list(family = .gllvm_julia_family(family), selector = NULL))
  }

  fam_var <- attr(family, "family_var") %||% "family"
  if (!fam_var %in% names(data)) {
    stop(
      "engine = 'julia': mixed-family list needs a '",
      fam_var,
      "' column in data. Set attr(family, 'family_var') or use engine = 'tmb'.",
      call. = FALSE
    )
  }
  fam_levels <- if (is.factor(data[[fam_var]])) {
    levels(data[[fam_var]])
  } else {
    sort(unique(as.character(data[[fam_var]])))
  }
  if (length(fam_levels) != length(family)) {
    stop(
      "engine = 'julia': length(family) must match the number of levels in '",
      fam_var,
      "'.",
      call. = FALSE
    )
  }
  family_names <- names(family)
  has_family_names <- !is.null(family_names) && any(nzchar(family_names))
  if (has_family_names) {
    if (any(!nzchar(family_names))) {
      stop(
        "engine = 'julia': named mixed-family lists must name every entry.",
        call. = FALSE
      )
    }
    if (!setequal(family_names, fam_levels)) {
      stop(
        "engine = 'julia': names of the mixed-family list must match levels of '",
        fam_var,
        "'.",
        call. = FALSE
      )
    }
    family <- family[match(fam_levels, family_names)]
  }

  family_by_level <- stats::setNames(
    vapply(family, .gllvm_julia_family_scalar, character(1)),
    fam_levels
  )
  bad <- setdiff(unname(family_by_level), .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES)
  if (length(bad)) {
    stop(
      "engine = 'julia': mixed-family lists currently support ",
      paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", "),
      "; unsupported component(s): ",
      paste(unique(bad), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  fam_idx <- match(as.character(data[[fam_var]]), fam_levels)
  row_family <- unname(family_by_level)[fam_idx]
  trait_levels <- levels(trait_factor)
  family_by_trait <- vapply(
    seq_along(trait_levels),
    function(i) {
      vals <- unique(row_family[as.integer(trait_factor) == i])
      vals <- vals[!is.na(vals)]
      if (length(vals) != 1L) {
        stop(
          "engine = 'julia': mixed-family bridge requires each trait to map ",
          "to exactly one family; trait '",
          trait_levels[i],
          "' maps to ",
          length(vals),
          " families. Use engine = 'tmb'.",
          call. = FALSE
        )
      }
      vals
    },
    character(1)
  )
  names(family_by_trait) <- trait_levels

  resolved_names <- names(family)
  if (is.null(resolved_names) || any(!nzchar(resolved_names))) {
    resolved_names <- fam_levels
  }
  selector <- list(
    family_var = fam_var,
    levels = fam_levels,
    list_names_matched = has_family_names,
    family_names = resolved_names,
    family_by_level = family_by_level,
    row_index = as.integer(fam_idx),
    row_level = as.character(data[[fam_var]]),
    family_by_trait = family_by_trait
  )
  list(family = unname(family_by_trait), selector = selector)
}

# Convert selected long-format fixed-effect design columns into the p x n x q
# array expected by GLLVM.bridge_fit. Rows are indexed by (trait, unit).
.gllvm_julia_design_array <- function(
  Xfix,
  cols,
  trait_index,
  unit_index,
  p,
  n
) {
  cols <- as.character(cols)
  Xsel <- Xfix[, cols, drop = FALSE]
  if (anyNA(Xsel)) {
    stop(
      "engine = 'julia': fixed-effect covariate design contains NA; ",
      "missing predictors are not wired on the Julia bridge yet. ",
      "Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  out <- array(
    0,
    dim = c(p, n, ncol(Xsel)),
    dimnames = list(NULL, NULL, colnames(Xsel))
  )
  for (k in seq_len(ncol(Xsel))) {
    out[cbind(trait_index, unit_index, k)] <- as.numeric(Xsel[, k])
  }
  storage.mode(out) <- "double"
  out
}

.gllvm_julia_mask <- function(mask, y) {
  if (is.null(mask)) {
    return(NULL)
  }
  mask <- as.matrix(mask)
  if (!identical(dim(mask), dim(y))) {
    stop(
      "engine = 'julia': mask must have the same p x n shape as y.",
      call. = FALSE
    )
  }
  if (anyNA(mask)) {
    stop("engine = 'julia': mask cannot contain NA.", call. = FALSE)
  }
  mask <- matrix(
    as.logical(mask),
    nrow = nrow(mask),
    ncol = ncol(mask),
    dimnames = dimnames(mask)
  )
  if (!any(mask)) {
    stop(
      "engine = 'julia': mask has no observed responses.",
      call. = FALSE
    )
  }
  if (all(mask)) {
    return(NULL)
  }
  mask
}

.gllvm_julia_mask_sentinel <- function(family) {
  switch(
    family,
    poisson = 0,
    binomial = 0,
    negbinomial = 0,
    beta = 0.5,
    gamma = 1,
    ordinal = 1,
    ordinal_probit = 1,
    0
  )
}

.gllvm_julia_has_masked_response <- function(mask) {
  !is.null(mask) && any(!as.logical(mask))
}

.gllvm_julia_masked_ci_status <- function(method = "ci") {
  method <- as.character(method)[1L]
  if (is.na(method) || identical(method, "none")) {
    return("ci_unavailable_masked_response")
  }
  paste0(method, "_unavailable_masked_response")
}

.gllvm_julia_masked_ci_note <- function() {
  paste(
    "confidence intervals for masked response fits are not routed through",
    "the Julia bridge yet. Use ci_method = 'none' for point estimates or",
    "engine = 'tmb'."
  )
}

.gllvm_julia_stop_masked_ci <- function(prefix, method) {
  stop(
    prefix,
    ": ci_status = '",
    .gllvm_julia_masked_ci_status(method),
    "'; ",
    .gllvm_julia_masked_ci_note(),
    call. = FALSE
  )
}

.gllvm_julia_sanitize_masked_y <- function(y, mask, family) {
  if (is.null(mask)) {
    return(y)
  }
  if (anyNA(y[mask])) {
    stop(
      "engine = 'julia': observed response cells contain NA; only masked ",
      "response cells may be missing.",
      call. = FALSE
    )
  }
  y[!mask] <- .gllvm_julia_mask_sentinel(family)
  y
}

.gllvm_julia_trait_families <- function(object) {
  fam <- object$families %||% object$family
  fam <- as.character(fam)
  p <- as.integer(object$n_traits %||% length(fam))
  if (length(fam) == 1L) {
    fam <- rep(fam, p)
  }
  if (length(fam) != p) {
    stop(
      "gllvmTMB_julia object carries incompatible family metadata.",
      call. = FALSE
    )
  }
  fam
}

.gllvm_julia_is_mixed_object <- function(object) {
  identical(object$model, "mixed_rr") ||
    length(unique(.gllvm_julia_trait_families(object))) > 1L
}

## Implied between-/within-trait residual covariance from the cached bridge
## point estimates, mirroring the native extract_Sigma_B() / extract_Sigma_W()
## return shape (a list with `Sigma` and `R`). The bridge payload carries a
## SINGLE shared loading block Lambda (p x K) and a scalar Gaussian residual SD
## sigma_eps, so:
##   * level "B" (level = "unit"): Sigma_B = Lambda Lambda^T for ALL admitted
##     one-part families -- a deterministic function of the cached point-estimate
##     loadings. For a mixed-family object Lambda is shared across the latent
##     block, so Sigma_B is still well-defined. R_B = cov2cor(Sigma_B).
##   * level "W" (level = "unit_obs"): only Gaussian has a residual scale on the
##     bridge payload (sigma_eps^2 * I). Non-Gaussian families have no within-unit
##     residual covariance defined on the payload, so we error with a clear
##     bridge-specific message rather than fabricate one.
## `$trait_names` supplies the dimnames.
.gllvm_julia_residual_sigma <- function(object, level) {
  traits <- .gllvm_julia_trait_names(object)
  p <- length(traits)
  if (identical(level, "B")) {
    Lambda <- as.matrix(object$loadings)
    if (length(Lambda) == 0L) {
      return(NULL)
    }
    Sigma <- Lambda %*% t(Lambda)
    Sigma <- as.matrix(Sigma)
    rownames(Sigma) <- colnames(Sigma) <- traits
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) Sigma / outer(D, D) else NA * Sigma
    rownames(R) <- colnames(R) <- traits
    return(list(Sigma = Sigma, R = R))
  }
  ## level == "W": within-unit residual covariance.
  fam <- .gllvm_julia_trait_families(object)
  if (!all(fam == "gaussian")) {
    bad <- unique(fam[fam != "gaussian"])
    cli::cli_abort(c(
      paste0(
        "getResidualCov(): within-unit residual covariance is not defined ",
        "for a {.val {bad[1]}} engine = {.val julia} bridge fit."
      ),
      "i" = "Only Gaussian bridge fits carry a residual scale (sigma_eps^2 I) at {.code level = \"unit_obs\"}.",
      ">" = "Use {.code level = \"unit\"} for the between-trait covariance {.code Lambda Lambda^T}."
    ))
  }
  sigma_eps <- as.numeric(object$sigma_eps)
  if (
    length(sigma_eps) != 1L || !is.finite(sigma_eps)
  ) {
    cli::cli_abort(c(
      "getResidualCov(): Gaussian bridge fit carries no finite {.code sigma_eps} for {.code level = \"unit_obs\"}.",
      ">" = "Use {.code level = \"unit\"} for the between-trait covariance {.code Lambda Lambda^T}."
    ))
  }
  Sigma <- diag(sigma_eps^2, nrow = p)
  rownames(Sigma) <- colnames(Sigma) <- traits
  R <- diag(1, nrow = p)
  rownames(R) <- colnames(R) <- traits
  list(Sigma = Sigma, R = R)
}

#' Fit a GLLVM with the Julia engine (GLLVM.jl `bridge_fit`).
#'
#' @param y Response matrix, p x n (traits x units), or n x p (set `units_are_rows`).
#' @param family A family object/string, or a list of them (one per trait -> mixed).
#' @param num.lv Number of latent variables (K).
#' @param N Binomial trials (matrix or scalar), or `NULL`.
#' @param X Optional fixed-effect covariate array with shape p x n x q. Gaussian
#'   fits expect the full mean design, including per-trait intercept planes;
#'   supported non-Gaussian fits expect the extra covariate planes only.
#' @param mask Optional logical p x n observation mask (`TRUE` = observed). Masked
#'   response cells are ignored by the Julia likelihood; currently supported only
#'   for one-part non-Gaussian no-X fits and `ci_method = "none"`.
#' @param units_are_rows If `TRUE`, `y` is n x p and is transposed to p x n.
#' @param ci_method Confidence-interval method routed to the Julia engine: one of
#'   `"none"` (default, no CIs), `"wald"`, `"profile"`, or `"bootstrap"`. When not
#'   `"none"`, the returned object gains the bridge `ci_*` fields (`ci_method`,
#'   `ci_level`, `ci_param_names`, `ci_estimate`, `ci_lower`, `ci_upper`,
#'   `ci_note`), reusing GLLVM.jl's native CI engines (no CI math in R).
#'   Unsupported mixed-family, masked-response, and non-Gaussian fixed-effect-X
#'   cells deliberately return method-specific unavailable CI-status strings
#'   until those interval routes are implemented.
#' @param reml Logical; route Gaussian no-X fits through GLLVM.jl's restricted
#'   maximum-likelihood path. REML is Gaussian-only and is not routed for
#'   fixed-effect covariates, response masks, mixed-family rows, or non-Gaussian
#'   families.
#' @param ci_level Nominal coverage for the CIs (default `0.95`).
#' @param ci_nboot Parametric-bootstrap replicates when `ci_method = "bootstrap"`
#'   (default `200L`).
#' @param ci_seed Bootstrap RNG seed (default `0L`; fixed for reproducibility).
#' @param ... Passed to [gllvm_julia_setup()] (`jl_path`, `julia_home`).
#' @return A list of class `gllvmTMB_julia` with the bridge contract fields
#'   (`loadings`, `Sigma`, `correlation`, `loglik`, `aic`, `bic`, `converged`, ...).
#'   When `ci_method != "none"` the object also carries the bridge `ci_*` fields.
#' @export
gllvm_julia_fit <- function(
  y,
  family = "gaussian",
  num.lv = 2L,
  N = NULL,
  X = NULL,
  mask = NULL,
  units_are_rows = FALSE,
  ci_method = c("none", "wald", "profile", "bootstrap"),
  reml = FALSE,
  ci_level = 0.95,
  ci_nboot = 200L,
  ci_seed = 0L,
  ...
) {
  ci_method <- match.arg(ci_method)
  fam <- .gllvm_julia_family(family)
  y <- as.matrix(y)
  mask <- .gllvm_julia_mask(mask, y)
  if (isTRUE(units_are_rows)) {
    y <- t(y)
    if (!is.null(mask)) {
      mask <- t(mask)
    }
  }
  mixed_family <- .gllvm_julia_is_mixed_family(fam)
  if (mixed_family) {
    if (length(fam) != nrow(y)) {
      stop(
        "engine = 'julia': mixed-family vector length must equal the number ",
        "of response traits (rows of y).",
        call. = FALSE
      )
    }
    if (!is.null(mask)) {
      stop(
        "engine = 'julia': missing-response masks are not wired for ",
        "mixed-family Julia fits yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!is.null(X)) {
      stop(
        "engine = 'julia': fixed-effect covariates X are not wired for ",
        "mixed-family Julia fits yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!identical(ci_method, "none")) {
      .gllvm_julia_stop_mixed_ci("engine = 'julia'", ci_method)
    }
    if (anyNA(y)) {
      stop(
        "engine = 'julia': mixed-family Julia fits currently require a ",
        "complete response matrix. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
  }
  if (!is.null(mask)) {
    if (!(fam %in% .GLLVM_JULIA_MASK_FAMILIES)) {
      stop(
        "engine = 'julia': missing-response masks are wired only for ",
        paste(.GLLVM_JULIA_MASK_FAMILIES, collapse = ", "),
        " on this bridge branch; use engine = 'tmb' for family '",
        fam,
        "'.",
        call. = FALSE
      )
    }
    if (!is.null(X)) {
      stop(
        "engine = 'julia': missing-response masks with fixed-effect ",
        "covariates X are not wired yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!identical(ci_method, "none")) {
      .gllvm_julia_stop_masked_ci("engine = 'julia'", ci_method)
    }
    y <- .gllvm_julia_sanitize_masked_y(y, mask, fam)
  } else if (anyNA(y)) {
    stop(
      "engine = 'julia': y contains NA response cells but no observed-cell ",
      "mask was supplied; pass mask = !is.na(y) for supported no-X ",
      "non-Gaussian bridge families, or use engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (as.integer(num.lv) < 1L) {
    stop(
      "engine = 'julia': this GLLVM.jl bridge branch requires num.lv >= 1.",
      call. = FALSE
    )
  }
  if (isTRUE(reml)) {
    if (mixed_family || !identical(fam, "gaussian")) {
      stop(
        "engine = 'julia': REML is Gaussian-only on the Julia bridge; ",
        "use REML = FALSE or engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!is.null(mask)) {
      stop(
        "engine = 'julia': Gaussian REML with response masks is not routed ",
        "through the Julia bridge yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!is.null(X)) {
      stop(
        "engine = 'julia': Gaussian REML with fixed-effect covariates X is ",
        "not routed through the Julia bridge yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!identical(ci_method, "none")) {
      .gllvm_julia_stop_reml_ci("gllvm_julia_fit", ci_method)
    }
  }
  if (!is.null(X)) {
    if (!is.array(X) || length(dim(X)) != 3L) {
      stop(
        "engine = 'julia': X must be a p x n x q numeric array.",
        call. = FALSE
      )
    }
    if (!(fam %in% .GLLVM_JULIA_X_FAMILIES)) {
      stop(
        "engine = 'julia': fixed-effect covariates X are not wired for family '",
        fam,
        "' on this bridge branch. Supported X families: ",
        paste(.GLLVM_JULIA_X_FAMILIES, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    storage.mode(X) <- "double"
    if (anyNA(X)) {
      stop(
        "engine = 'julia': fixed-effect covariate array X contains NA; ",
        "missing predictors are not wired on the Julia bridge yet. ",
        "Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!identical(ci_method, "none") && !identical(fam, "gaussian")) {
      .gllvm_julia_stop_non_gaussian_x_ci("engine = 'julia'", ci_method)
    }
  }
  trait_names <- rownames(y)
  unit_names <- colnames(y)
  if (
    !mixed_family &&
      fam %in% c("poisson", "binomial", "negbinomial", "nb1", "ordinal")
  ) {
    storage.mode(y) <- "integer"
  }
  gllvm_julia_setup(...)
  args <- list("GLLVM.bridge_fit", y = y, family = fam, d = as.integer(num.lv))
  if (!is.null(N)) {
    args$N <- N
  }
  if (!is.null(X)) {
    args$X <- X
  }
  if (!is.null(mask)) {
    args$mask <- mask
  }
  if (!is.null(trait_names)) {
    args$trait_names <- trait_names
  }
  if (!is.null(unit_names)) {
    args$unit_names <- unit_names
  }
  ## Pass a Julia options Dict only when a non-default bridge option is
  ## requested, so ordinary ML fits keep the bridge call byte-identical to before.
  option_pairs <- list()
  if (!identical(ci_method, "none")) {
    option_pairs <- c(
      option_pairs,
      list(
        JuliaCall::julia_call("=>", "ci_method", ci_method),
        JuliaCall::julia_call("=>", "ci_level", as.numeric(ci_level)),
        JuliaCall::julia_call("=>", "ci_nboot", as.integer(ci_nboot)),
        JuliaCall::julia_call("=>", "ci_seed", as.integer(ci_seed))
      )
    )
  }
  if (isTRUE(reml)) {
    option_pairs <- c(
      option_pairs,
      list(JuliaCall::julia_call("=>", "reml", TRUE))
    )
  }
  if (length(option_pairs) > 0L) {
    args$options <- do.call(
      JuliaCall::julia_call,
      c(list("Dict"), option_pairs)
    )
  }
  res <- do.call(JuliaCall::julia_call, args)
  res$engine <- "julia"
  res$reml <- isTRUE(reml)
  ## Stash the marshalled fit inputs so confint() can re-fit on the SAME data with
  ## a different ci_method without the caller re-supplying y / N / X.
  res$y <- y
  res$N <- N
  res$X <- X
  res$observed_mask <- mask
  if (.gllvm_julia_has_masked_response(mask)) {
    res$ci_status <- .gllvm_julia_masked_ci_status("none")
    res$ci_note <- .gllvm_julia_masked_ci_note()
  } else if (mixed_family) {
    res$ci_status <- .gllvm_julia_mixed_ci_status("none")
    res$ci_note <- .gllvm_julia_mixed_ci_note()
  } else if (!is.null(X) && !identical(fam, "gaussian")) {
    res$ci_status <- .gllvm_julia_non_gaussian_x_ci_status("none")
    res$ci_note <- .gllvm_julia_non_gaussian_x_ci_note()
  }
  class(res) <- c("gllvmTMB_julia", "list")
  res
}

#' @export
logLik.gllvmTMB_julia <- function(object, ...) {
  val <- object$loglik
  attr(val, "df") <- object$df
  attr(val, "nobs") <- object$nobs
  class(val) <- "logLik"
  val
}

#' @export
print.gllvmTMB_julia <- function(x, ...) {
  cat("gllvmTMB fit (engine = 'julia', via GLLVM.jl)\n")
  cat(sprintf(
    "  family: %s | K = %d | %d traits x %d units\n",
    paste(unique(x$family), collapse = ","),
    x$d,
    x$n_traits,
    x$n_units
  ))
  cat(sprintf(
    "  logLik = %.4f | AIC = %.2f | BIC = %.2f | converged = %s\n",
    x$loglik,
    x$aic,
    x$bic,
    x$converged
  ))
  invisible(x)
}

.gllvm_julia_re_zero <- function(re_form) {
  (is.logical(re_form) && length(re_form) == 1L && is.na(re_form)) ||
    (inherits(re_form, "formula") && identical(deparse(re_form), "~0"))
}

.gllvm_julia_trait_names <- function(object) {
  n <- length(object$alpha %||% numeric())
  object$trait_names %||% paste0("trait", seq_len(n))
}

.gllvm_julia_unit_names <- function(object) {
  n <- object$n_units %||% ncol(object$y %||% matrix(ncol = 0L))
  object$unit_names %||% paste0("unit", seq_len(n))
}

.gllvm_julia_gamma_names <- function(object) {
  gamma_names <- dimnames(object$X)[[3]]
  if (is.null(gamma_names)) {
    gamma_names <- paste0("x", seq_along(object$gamma))
  }
  gamma_names
}

.gllvm_julia_coef_table <- function(object) {
  traits <- .gllvm_julia_trait_names(object)
  rows <- list()
  if (!is.null(object$alpha)) {
    rows[[length(rows) + 1L]] <- data.frame(
      component = "alpha",
      term = sprintf("alpha[%s]", traits),
      estimate = as.numeric(object$alpha),
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(object$gamma)) {
    gamma_names <- .gllvm_julia_gamma_names(object)
    rows[[length(rows) + 1L]] <- data.frame(
      component = "gamma",
      term = sprintf("gamma[%s]", gamma_names),
      estimate = as.numeric(object$gamma),
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(object$beta_cov)) {
    rows[[length(rows) + 1L]] <- data.frame(
      component = "beta_cov",
      term = sprintf("beta_cov[%s]", traits),
      estimate = as.numeric(object$beta_cov),
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(object$mean_coef)) {
    mean_names <- .gllvm_julia_gamma_names(object)
    rows[[length(rows) + 1L]] <- data.frame(
      component = "mean_coef",
      term = sprintf("mean_coef[%s]", mean_names),
      estimate = as.numeric(object$mean_coef),
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(object$dispersion) && any(is.finite(object$dispersion))) {
    rows[[length(rows) + 1L]] <- data.frame(
      component = "dispersion",
      term = sprintf("dispersion[%s]", traits),
      estimate = as.numeric(object$dispersion),
      stringsAsFactors = FALSE
    )
  }
  if (
    !is.null(object$sigma_eps) &&
      length(object$sigma_eps) == 1L &&
      is.finite(object$sigma_eps)
  ) {
    rows[[length(rows) + 1L]] <- data.frame(
      component = "sigma_eps",
      term = "sigma_eps",
      estimate = as.numeric(object$sigma_eps),
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) {
    return(data.frame(
      component = character(),
      term = character(),
      estimate = numeric()
    ))
  }
  do.call(rbind, rows)
}

## ---- ordinal (cumulative-link) in-sample prediction ----------------------
##
## The ordinal bridge fit carries the C-1 ordered cutpoints (`cutpoints`) and the
## category count (`n_categories`) so the per-category probabilities can be formed
## in R from the cached point estimates:
##   eta = Lambda %*% t(scores)               (no intercept: the cutpoints carry
##                                             the category levels)
##   P(y = c) = F(tau_c - eta) - F(tau_{c-1} - eta),   tau_0 = -Inf, tau_C = +Inf,
## with F the cumulative link CDF (logistic for "ordinal", standard Normal for
## "ordinal_probit"). The rotated loadings/scores product equals the engine's
## unrotated Lambda %*% Z' (rotation is orthogonal), so these probabilities match
## the engine's predict(type = :prob) to machine precision.

.gllvm_julia_is_ordinal_object <- function(object) {
  fam <- .gllvm_julia_trait_families(object)
  all(fam %in% c("ordinal", "ordinal_probit"))
}

.gllvm_julia_ordinal_cutpoints <- function(object) {
  tau <- object$cutpoints
  if (is.null(tau)) {
    stop(
      "predict.gllvmTMB_julia: this ordinal bridge object does not carry the ",
      "`cutpoints` payload; re-fit with the current engine = 'julia' bridge.",
      call. = FALSE
    )
  }
  tau <- as.numeric(tau)
  if (!length(tau) || any(!is.finite(tau)) || is.unsorted(tau, strictly = TRUE)) {
    stop(
      "predict.gllvmTMB_julia: ordinal `cutpoints` must be a finite, strictly ",
      "increasing vector of length C - 1.",
      call. = FALSE
    )
  }
  tau
}

## Category count C: prefer the explicit payload, fall back to length(cutpoints)+1.
.gllvm_julia_ordinal_C <- function(object, tau) {
  C <- object$n_categories %||% (length(tau) + 1L)
  C <- as.integer(C)
  if (length(C) != 1L || is.na(C) || C < 2L || C != length(tau) + 1L) {
    stop(
      "predict.gllvmTMB_julia: ordinal `n_categories` (", C, ") is inconsistent ",
      "with length(cutpoints) + 1 (", length(tau) + 1L, ").",
      call. = FALSE
    )
  }
  C
}

## Cumulative-link CDF F for the ordinal fit (logit -> logistic, probit -> Phi).
## The authoritative selector is the `link` payload ("LogitLink"/"ProbitLink");
## the family string ("ordinal_probit") is the fallback when `link` is absent.
.gllvm_julia_ordinal_cdf <- function(object) {
  link <- object$link
  if (!is.null(link)) {
    link <- as.character(link)
    if (any(link == "ProbitLink")) return(stats::pnorm)
    if (any(link == "LogitLink")) return(stats::plogis)
  }
  fam <- .gllvm_julia_trait_families(object)
  if (any(fam == "ordinal_probit")) stats::pnorm else stats::plogis
}

## In-sample link-scale eta (p x n) for an ordinal fit: the conditional latent
## reconstruction Lambda %*% t(scores). re_form = ~0 drops the latent block (eta=0).
.gllvm_julia_ordinal_eta <- function(object, include_latent = TRUE) {
  L <- as.matrix(object$loadings)
  scores <- as.matrix(object$scores)
  p <- object$n_traits %||% nrow(L)
  n <- object$n_units %||% nrow(scores)
  if (!is.numeric(p) || !is.numeric(n) || p < 1L || n < 1L) {
    stop(
      "predict.gllvmTMB_julia: object does not carry valid trait/unit dimensions.",
      call. = FALSE
    )
  }
  if (include_latent) {
    if (!length(L) || !length(scores) || ncol(L) != ncol(scores)) {
      stop(
        "predict.gllvmTMB_julia: object does not carry compatible loadings and ",
        "scores for conditional in-sample ordinal prediction.",
        call. = FALSE
      )
    }
    eta <- L %*% t(scores)
  } else {
    eta <- matrix(0, p, n)
  }
  dimnames(eta) <- list(
    .gllvm_julia_trait_names(object),
    .gllvm_julia_unit_names(object)
  )
  eta
}

## Per-category probability array P[t, u, c] (p x n x C) under the cumulative link.
.gllvm_julia_ordinal_prob_array <- function(object, include_latent = TRUE) {
  tau <- .gllvm_julia_ordinal_cutpoints(object)
  C <- .gllvm_julia_ordinal_C(object, tau)
  Fcdf <- .gllvm_julia_ordinal_cdf(object)
  eta <- .gllvm_julia_ordinal_eta(object, include_latent = include_latent)
  p <- nrow(eta)
  n <- ncol(eta)
  P <- array(0, dim = c(p, n, C))
  for (c in seq_len(C)) {
    Fhi <- if (c == C) 1 else Fcdf(tau[c] - eta)
    Flo <- if (c == 1L) 0 else Fcdf(tau[c - 1L] - eta)
    P[, , c] <- Fhi - Flo
  }
  dimnames(P) <- list(
    .gllvm_julia_trait_names(object),
    .gllvm_julia_unit_names(object),
    paste0("cat", seq_len(C))
  )
  P
}

## Modal category M[t, u] in {1, ..., C} = which.max over the probability axis.
## Flatten the (p, n) cells to rows and the C categories to columns, then take the
## per-row argmax (first category wins ties, matching the engine's predict :class).
.gllvm_julia_ordinal_class <- function(object, include_latent = TRUE) {
  P <- .gllvm_julia_ordinal_prob_array(object, include_latent = include_latent)
  d <- dim(P)
  flat <- matrix(P, nrow = d[1] * d[2], ncol = d[3]) # cells x categories
  M <- matrix(max.col(flat, ties.method = "first"), nrow = d[1], ncol = d[2])
  dimnames(M) <- dimnames(P)[c(1L, 2L)]
  M
}

## Long (one row per trait x unit) data frame of ordinal per-category
## probabilities: id columns + one column `P(y=c)` per category.
.gllvm_julia_ordinal_long_prob <- function(object, include_latent = TRUE) {
  P <- .gllvm_julia_ordinal_prob_array(object, include_latent = include_latent)
  C <- dim(P)[3]
  cat_labels <- seq_len(C)
  out <- NULL
  for (c in seq_len(C)) {
    col <- .gllvm_julia_long_values(object, P[, , c], "prob")
    if (is.null(out)) {
      out <- col[setdiff(names(col), "prob")]
    }
    out[[paste0("P(y=", cat_labels[c], ")")]] <- col$prob
  }
  out
}

.gllvm_julia_eta_matrix <- function(object, include_latent = TRUE) {
  fam <- .gllvm_julia_trait_families(object)
  if (any(fam %in% c("ordinal", "ordinal_probit"))) {
    stop(
      "predict.gllvmTMB_julia: ordinal link/response-scale predictions are not ",
      "wired; use type = \"prob\" for per-category probabilities or type = ",
      "\"class\" for the modal category.",
      call. = FALSE
    )
  }
  L <- as.matrix(object$loadings)
  scores <- as.matrix(object$scores)
  p <- object$n_traits %||% nrow(L)
  n <- object$n_units %||% nrow(scores)
  if (!is.numeric(p) || !is.numeric(n) || p < 1L || n < 1L) {
    stop(
      "predict.gllvmTMB_julia: object does not carry valid trait/unit dimensions.",
      call. = FALSE
    )
  }
  if (include_latent) {
    if (!length(L) || !length(scores) || ncol(L) != ncol(scores)) {
      stop(
        "predict.gllvmTMB_julia: object does not carry compatible loadings and ",
        "scores for conditional in-sample prediction.",
        call. = FALSE
      )
    }
    eta <- L %*% t(scores)
  } else {
    eta <- matrix(0, p, n)
  }
  if (
    identical(object$model, "gaussian_x_rr") &&
      !is.null(object$X) &&
      is.null(object$mean_coef) &&
      is.null(object$beta_cov) &&
      is.null(object$gamma)
  ) {
    stop(
      "predict.gllvmTMB_julia: Gaussian covariate predictions are not wired ",
      "yet because this bridge payload does not carry the full mean ",
      "coefficient vector.",
      call. = FALSE
    )
  }
  used_full_mean <- FALSE
  if (identical(object$model, "gaussian_x_rr") && !is.null(object$mean_coef)) {
    X <- object$X
    mean_coef <- as.numeric(object$mean_coef)
    if (
      !is.array(X) || length(dim(X)) != 3L || dim(X)[3] != length(mean_coef)
    ) {
      stop(
        "predict.gllvmTMB_julia: object carries incompatible X/mean_coef fields.",
        call. = FALSE
      )
    }
    for (k in seq_along(mean_coef)) {
      eta <- eta + X[,, k] * mean_coef[k]
    }
    used_full_mean <- TRUE
  }
  if (!used_full_mean && !is.null(object$beta_cov)) {
    eta <- eta + matrix(as.numeric(object$beta_cov), p, n)
  } else if (
    !used_full_mean && !is.null(object$alpha) && all(is.finite(object$alpha))
  ) {
    eta <- eta + matrix(as.numeric(object$alpha), p, n)
  }
  if (!used_full_mean && !is.null(object$X) && !is.null(object$gamma)) {
    X <- object$X
    gamma <- as.numeric(object$gamma)
    if (!is.array(X) || length(dim(X)) != 3L || dim(X)[3] != length(gamma)) {
      stop(
        "predict.gllvmTMB_julia: object carries incompatible X/gamma fields.",
        call. = FALSE
      )
    }
    for (k in seq_along(gamma)) {
      eta <- eta + X[,, k] * gamma[k]
    }
  }
  dimnames(eta) <- list(
    .gllvm_julia_trait_names(object),
    .gllvm_julia_unit_names(object)
  )
  eta
}

.gllvm_julia_inverse_link_family <- function(fam, eta) {
  switch(
    fam,
    gaussian = eta,
    poisson = exp(eta),
    binomial = stats::plogis(eta),
    negbinomial = exp(eta),
    nb1 = exp(eta),
    beta = stats::plogis(eta),
    gamma = exp(eta),
    stop(
      "predict.gllvmTMB_julia: response-scale predictions are not wired for ",
      "family '",
      fam,
      "'.",
      call. = FALSE
    )
  )
}

.gllvm_julia_inverse_link <- function(object, eta) {
  fam <- .gllvm_julia_trait_families(object)
  if (length(unique(fam)) == 1L) {
    if (fam[1] %in% c("ordinal", "ordinal_probit")) {
      stop(
        "predict.gllvmTMB_julia: ordinal predictions are not wired yet because ",
        "the Julia bridge payload does not carry cutpoints/probabilities.",
        call. = FALSE
      )
    }
    return(.gllvm_julia_inverse_link_family(fam[1], eta))
  }
  out <- eta
  for (i in seq_len(nrow(eta))) {
    out[i, ] <- .gllvm_julia_inverse_link_family(fam[i], eta[i, ])
  }
  out
}

.gllvm_julia_pearson_variance <- function(object, fit) {
  fam <- .gllvm_julia_trait_families(object)
  if (any(fam %in% c("ordinal", "ordinal_probit"))) {
    stop(
      "residuals.gllvmTMB_julia: Pearson residuals are not defined for ",
      "ordinal families because the Julia bridge payload does not carry ",
      "response-scale means and variances.",
      call. = FALSE
    )
  }
  mu_vec <- .gllvm_julia_matrix_values(object, fit)
  n_rows <- length(mu_vec)
  # mu_vec, fam_row, and the returned variance share the long-row order
  # produced by .gllvm_julia_long_values(), so residuals() can scale the
  # already-flattened residual column directly.
  fam_row <- .gllvm_julia_row_family(object, n_rows)
  variance <- numeric(n_rows)
  for (f in unique(fam_row)) {
    rows <- fam_row == f
    variance[rows] <- switch(
      f,
      gaussian = {
        mixed_object <- .gllvm_julia_is_mixed_object(object)
        sigma <- if (mixed_object) {
          .gllvm_julia_row_dispersion(object, f, n_rows, rows = rows)
        } else {
          rep(as.numeric(object$sigma_eps)[1L], sum(rows))
        }
        if (any(!is.finite(sigma)) || any(sigma < 0)) {
          msg <- if (mixed_object) {
            "residuals.gllvmTMB_julia: Gaussian Pearson residuals need finite non-negative sigma values."
          } else {
            "residuals.gllvmTMB_julia: Gaussian Pearson residuals need a finite non-negative sigma_eps payload."
          }
          stop(msg, call. = FALSE)
        }
        sigma^2
      },
      poisson = mu_vec[rows],
      binomial = {
        prob <- mu_vec[rows]
        size <- if (is.null(object$N)) {
          rep(1L, sum(rows))
        } else {
          .gllvm_julia_matrix_values(object, object$N)[rows]
        }
        if (any(!is.finite(size)) || any(size < 0)) {
          stop(
            "residuals.gllvmTMB_julia: Binomial trial sizes must be finite ",
            "and non-negative.",
            call. = FALSE
          )
        }
        as.numeric(size) * prob * (1 - prob)
      },
      nb1 = {
        phi <- .gllvm_julia_row_dispersion(object, f, n_rows, rows = rows)
        mu_vec[rows] * (1 + phi)
      },
      negbinomial = {
        size <- .gllvm_julia_row_dispersion(object, f, n_rows, rows = rows)
        mu_vec[rows] + mu_vec[rows]^2 / size
      },
      beta = {
        phi <- .gllvm_julia_row_dispersion(object, f, n_rows, rows = rows)
        mu_vec[rows] * (1 - mu_vec[rows]) / (phi + 1)
      },
      gamma = {
        alpha <- .gllvm_julia_row_dispersion(object, f, n_rows, rows = rows)
        mu_vec[rows]^2 / alpha
      },
      stop(
        "residuals.gllvmTMB_julia: Pearson residuals are not wired for ",
        "family '",
        f,
        "'.",
        call. = FALSE
      )
    )
  }
  variance
}

.gllvm_julia_long_values <- function(object, values, value_name) {
  values <- as.matrix(values)
  if (!is.null(object$.trait_index) && !is.null(object$.unit_index)) {
    out <- data.frame(
      .row = seq_along(object$.trait_index),
      stringsAsFactors = FALSE
    )
    unit_col <- object$unit_col %||% "unit"
    trait_col <- object$trait_col %||% "trait"
    out[[unit_col]] <- .gllvm_julia_unit_names(object)[object$.unit_index]
    out[[trait_col]] <- .gllvm_julia_trait_names(object)[object$.trait_index]
    out[[value_name]] <- as.numeric(values[cbind(
      object$.trait_index,
      object$.unit_index
    )])
    return(out)
  }
  grid <- expand.grid(
    trait = .gllvm_julia_trait_names(object),
    unit = .gllvm_julia_unit_names(object),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  data.frame(
    unit = grid$unit,
    trait = grid$trait,
    setNames(list(as.numeric(values)), value_name),
    stringsAsFactors = FALSE
  )
}

.gllvm_julia_matrix_values <- function(object, values) {
  if (length(values) == 1L && is.null(dim(values))) {
    n <- if (!is.null(object$.trait_index)) {
      length(object$.trait_index)
    } else {
      as.integer(object$n_traits %||% 1L) * as.integer(object$n_units %||% 1L)
    }
    return(rep(as.numeric(values), n))
  }
  values <- as.matrix(values)
  if (!is.null(object$.trait_index) && !is.null(object$.unit_index)) {
    return(as.numeric(values[cbind(object$.trait_index, object$.unit_index)]))
  }
  as.numeric(values)
}

.gllvm_julia_row_family <- function(object, n_rows) {
  fam <- .gllvm_julia_trait_families(object)
  if (!is.null(object$.trait_index)) {
    out <- fam[object$.trait_index]
  } else {
    p <- as.integer(object$n_traits %||% length(fam))
    n <- as.integer(object$n_units %||% ceiling(n_rows / max(p, 1L)))
    out <- rep(fam, times = n)
  }
  if (length(out) != n_rows) {
    stop(
      "gllvmTMB_julia object carries incompatible row/family metadata.",
      call. = FALSE
    )
  }
  out
}

.gllvm_julia_row_dispersion <- function(object, family, n_rows, rows = NULL) {
  dispersion <- as.numeric(object$dispersion)
  if (!length(dispersion) || !any(is.finite(dispersion))) {
    stop(
      "simulate.gllvmTMB_julia: family '",
      family,
      "' needs a finite positive dispersion payload.",
      call. = FALSE
    )
  }

  if (!is.null(object$.trait_index)) {
    out <- dispersion[object$.trait_index]
  } else {
    p <- as.integer(object$n_traits %||% length(dispersion))
    n <- as.integer(object$n_units %||% ceiling(n_rows / max(p, 1L)))
    if (length(dispersion) == 1L) {
      out <- rep(dispersion, n_rows)
    } else if (length(dispersion) == p) {
      out <- rep(dispersion, times = n)
    } else if (length(dispersion) == n_rows) {
      out <- dispersion
    } else {
      stop(
        "simulate.gllvmTMB_julia: family '",
        family,
        "' carries an incompatible dispersion payload.",
        call. = FALSE
      )
    }
  }

  if (!is.null(rows)) {
    out <- out[rows]
  }
  out <- as.numeric(out)
  expected <- if (is.null(rows)) n_rows else sum(rows)
  if (length(out) != expected || any(!is.finite(out)) || any(out <= 0)) {
    stop(
      "simulate.gllvmTMB_julia: family '",
      family,
      "' needs finite positive dispersion values.",
      call. = FALSE
    )
  }
  out
}

.gllvm_julia_check_nsim <- function(nsim) {
  if (length(nsim) != 1L || is.na(nsim) || nsim < 1L) {
    stop(
      "simulate.gllvmTMB_julia: nsim must be a positive integer.",
      call. = FALSE
    )
  }
  as.integer(nsim)
}

#' Post-fit methods for Julia-engine GLLVM fits
#'
#' Basic inspection methods for objects returned by [gllvm_julia_fit()] or
#' [gllvmTMB()] with `engine = "julia"`. These methods expose the flat bridge
#' payload in ordinary R shapes; they do not perform new Julia computations.
#'
#' @param object,x A `gllvmTMB_julia` object.
#' @param data Optional original training data for `augment()`. When supplied,
#'   it must have the same row count as the in-sample bridge rows.
#' @param nsim For `simulate()`, number of conditional response draws.
#' @param seed Optional RNG seed for `simulate()`.
#' @param newdata Optional new data. Currently unsupported for Julia-engine fits;
#'   only in-sample predictions are returned.
#' @param effects For `tidy()`, one of `"fixed"`, `"ran_pars"`, or `"cutpoint"`;
#'   only `"fixed"` is currently wired for Julia-engine fits.
#' @param conf.int For `tidy()`, whether to add confidence limits. Currently
#'   unsupported for Julia-engine fits; use [confint()] where routed.
#' @param conf.level Confidence level requested by `conf.int`.
#' @param type Prediction scale. For families with a scalar response mean,
#'   `"link"` returns the fitted linear predictor and `"response"` returns the
#'   inverse-link mean. For ordinal (cumulative-link) fits `predict()` instead
#'   takes `"prob"` (per-category probabilities `P(y = c)`, one column per
#'   category, default) or `"class"` (the modal category in `1:C`); `"link"` and
#'   `"response"` are rejected because an ordinal fit has no scalar mean. For
#'   `augment()`, only `"response"` is currently routed; use
#'   `predict(type = "link")` for link-scale fitted values. For `residuals()`,
#'   `"response"` returns observed minus fitted and `"pearson"` divides that by
#'   the per-family response-scale standard deviation; residuals are not routed
#'   for ordinal bridge fits.
#' @param re_form Random-effect formula controlling whether conditional latent
#'   scores are included. Use `~ 0` or `NA` for fixed-effects-only predictions.
#'   For `augment()`, only the default conditional `~ .` route is currently
#'   supported so `.fitted` and `.resid` share one prediction contract.
#' @param digits Decimal digits to print.
#' @param ... Currently unused.
#' @return `coef()` returns a named list of bridge coefficients. `tidy()` returns
#'   a coefficient data frame with `term`, `estimate`, and `component` columns for
#'   the currently routed fixed-effect bridge payload. `glance()` returns one row
#'   of cached fit statistics. `augment()` returns in-sample row diagnostics with
#'   `.observed`, `.fitted`, `.resid`, and `.status` columns. `simulate()` returns
#'   an `n_obs x nsim` matrix of conditional in-sample draws for routed
#'   Gaussian, Poisson, Binomial, NB2, NB1, Beta, and Gamma bridge fits,
#'   including trait-aligned complete mixed-family objects over those routed
#'   component families.
#'   `predict()` and
#'   `residuals()` return data frames in the original
#'   training-row order when the
#'   object came from `gllvmTMB(..., engine = "julia")`. `fitted()` returns a
#'   trait x unit matrix. `nobs()` returns the number of likelihood-contributing
#'   cells. `vcov()` currently errors with an explicit status because covariance
#'   matrices are not routed through the Julia bridge yet. `summary()` returns a
#'   list of class `summary.gllvmTMB_julia`. `print()` methods return the input
#'   invisibly.
#' @name gllvmTMB_julia-methods
NULL

#' @rdname gllvmTMB_julia-methods
#' @export
coef.gllvmTMB_julia <- function(object, ...) {
  traits <- .gllvm_julia_trait_names(object)
  out <- list()
  if (!is.null(object$alpha)) {
    out$alpha <- stats::setNames(as.numeric(object$alpha), traits)
  }
  if (!is.null(object$loadings)) {
    L <- as.matrix(object$loadings)
    rownames(L) <- traits
    colnames(L) <- paste0("LV", seq_len(ncol(L)))
    out$loadings <- L
  }
  if (!is.null(object$gamma)) {
    gamma_names <- .gllvm_julia_gamma_names(object)
    out$gamma <- stats::setNames(as.numeric(object$gamma), gamma_names)
  }
  if (!is.null(object$beta_cov)) {
    out$beta_cov <- stats::setNames(as.numeric(object$beta_cov), traits)
  }
  if (!is.null(object$mean_coef)) {
    mean_names <- .gllvm_julia_gamma_names(object)
    out$mean_coef <- stats::setNames(as.numeric(object$mean_coef), mean_names)
  }
  if (!is.null(object$dispersion) && any(is.finite(object$dispersion))) {
    out$dispersion <- stats::setNames(as.numeric(object$dispersion), traits)
  }
  if (
    !is.null(object$sigma_eps) &&
      length(object$sigma_eps) == 1L &&
      is.finite(object$sigma_eps)
  ) {
    out$sigma_eps <- as.numeric(object$sigma_eps)
  }
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
tidy.gllvmTMB_julia <- function(
  x,
  effects = c("fixed", "ran_pars", "cutpoint"),
  conf.int = FALSE,
  conf.level = 0.95,
  ...
) {
  effects <- match.arg(effects)
  if (!identical(effects, "fixed")) {
    stop(
      "tidy.gllvmTMB_julia: only effects = 'fixed' is routed through the ",
      "Julia bridge yet. Use coef(), summary(), or engine = 'tmb' for broader ",
      "tidy output.",
      call. = FALSE
    )
  }
  if (isTRUE(conf.int)) {
    stop(
      "tidy.gllvmTMB_julia: conf.int = TRUE is not routed through the Julia ",
      "bridge yet. Use confint() for supported interval output.",
      call. = FALSE
    )
  }
  tab <- .gllvm_julia_coef_table(x)
  data.frame(
    term = tab$term,
    estimate = tab$estimate,
    component = tab$component,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' @rdname gllvmTMB_julia-methods
#' @exportS3Method stats::nobs
nobs.gllvmTMB_julia <- function(object, ...) {
  as.integer(object$nobs %||% length(object$y))
}

#' @rdname gllvmTMB_julia-methods
#' @exportS3Method stats::vcov
vcov.gllvmTMB_julia <- function(object, ...) {
  stop(
    "vcov.gllvmTMB_julia: covariance matrices are not routed through the ",
    "Julia bridge yet; use confint(..., method = 'wald'|'profile'|'bootstrap') ",
    "for interval output on supported cells.",
    call. = FALSE
  )
}

#' @rdname gllvmTMB_julia-methods
#' @export
augment.gllvmTMB_julia <- function(
  x,
  data = NULL,
  newdata = NULL,
  type = c("response", "link"),
  re_form = ~.,
  ...
) {
  if (!is.null(newdata)) {
    stop(
      "augment.gllvmTMB_julia: newdata augmentation is not wired yet; ",
      "only in-sample rows are currently supported.",
      call. = FALSE
    )
  }
  type <- match.arg(type)
  if (!identical(type, "response")) {
    stop(
      "augment.gllvmTMB_julia: only type = 'response' is routed yet; ",
      "use predict(type = 'link') for link-scale fitted values.",
      call. = FALSE
    )
  }
  if (!inherits(re_form, "formula") || !identical(deparse(re_form), "~.")) {
    stop(
      "augment.gllvmTMB_julia: only re_form = ~ . is routed yet so ",
      ".fitted and .resid use the same conditional prediction contract; ",
      "use predict() directly for fixed-effects-only fitted values.",
      call. = FALSE
    )
  }

  rr <- residuals(x, type = "response", ...)
  pr <- predict(x, type = "response", re_form = ~., ...)
  if (nrow(rr) != nrow(pr)) {
    stop(
      "augment.gllvmTMB_julia: internal row mismatch between residuals() ",
      "and predict().",
      call. = FALSE
    )
  }

  aug <- data.frame(
    .observed = rr$observed,
    .fitted = pr$est,
    .resid = rr$residual,
    .status = rr$status,
    stringsAsFactors = FALSE
  )

  if (!is.null(data)) {
    data <- as.data.frame(data)
    if (nrow(data) != nrow(aug)) {
      stop(
        "augment.gllvmTMB_julia: data must have the same number of rows as ",
        "the in-sample bridge payload.",
        call. = FALSE
      )
    }
    return(cbind(data, aug))
  }

  id_cols <- setdiff(
    names(rr),
    c("residual", "observed", "fitted", "type", "status")
  )
  cbind(rr[id_cols], aug)
}

#' @rdname gllvmTMB_julia-methods
#' @export
glance.gllvmTMB_julia <- function(x, ...) {
  data.frame(
    logLik = as.numeric(x$loglik),
    AIC = as.numeric(x$aic),
    BIC = as.numeric(x$bic),
    df = as.numeric(x$df),
    nobs = as.integer(x$nobs),
    converged = isTRUE(x$converged),
    iterations = as.integer(x$iterations %||% NA_integer_),
    engine = x$engine %||% "julia",
    family = paste(unique(x$family), collapse = ","),
    model = x$model %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

#' @rdname gllvmTMB_julia-methods
#' @export
simulate.gllvmTMB_julia <- function(
  object,
  nsim = 1,
  seed = NULL,
  re_form = ~.,
  ...
) {
  nsim <- .gllvm_julia_check_nsim(nsim)
  if (.gllvm_julia_has_masked_response(object$observed_mask)) {
    stop(
      "simulate.gllvmTMB_julia: masked-response simulations are not routed ",
      "through the Julia bridge yet; use engine = 'tmb' or fit complete data.",
      call. = FALSE
    )
  }

  mu <- fitted(object, type = "response", re_form = re_form)
  mu_vec <- .gllvm_julia_matrix_values(object, mu)
  if (any(!is.finite(mu_vec))) {
    stop(
      "simulate.gllvmTMB_julia: fitted response means are not finite.",
      call. = FALSE
    )
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }

  out <- matrix(NA_real_, nrow = length(mu_vec), ncol = nsim)
  fam_row <- .gllvm_julia_row_family(object, length(mu_vec))
  for (j in seq_len(nsim)) {
    draw <- numeric(length(mu_vec))
    for (fam in unique(fam_row)) {
      rows <- fam_row == fam
      draw[rows] <- switch(
        fam,
        gaussian = {
          mixed_object <- .gllvm_julia_is_mixed_object(object)
          sigma <- if (mixed_object) {
            .gllvm_julia_row_dispersion(
              object,
              fam,
              length(mu_vec),
              rows = rows
            )
          } else {
            rep(as.numeric(object$sigma_eps)[1L], sum(rows))
          }
          if (any(!is.finite(sigma)) || any(sigma < 0)) {
            msg <- if (mixed_object) {
              "simulate.gllvmTMB_julia: Gaussian simulations need finite non-negative sigma values."
            } else {
              "simulate.gllvmTMB_julia: Gaussian simulations need a finite non-negative sigma_eps payload."
            }
            stop(msg, call. = FALSE)
          }
          stats::rnorm(sum(rows), mean = mu_vec[rows], sd = sigma)
        },
        poisson = {
          if (any(mu_vec[rows] < 0)) {
            stop(
              "simulate.gllvmTMB_julia: Poisson fitted means must be non-negative.",
              call. = FALSE
            )
          }
          stats::rpois(sum(rows), lambda = mu_vec[rows])
        },
        binomial = {
          if (any(mu_vec[rows] < -1e-12 | mu_vec[rows] > 1 + 1e-12)) {
            stop(
              "simulate.gllvmTMB_julia: Binomial fitted probabilities must be ",
              "inside [0, 1].",
              call. = FALSE
            )
          }
          prob <- pmin(pmax(mu_vec[rows], 0), 1)
          size <- if (is.null(object$N)) {
            rep(1L, sum(rows))
          } else {
            .gllvm_julia_matrix_values(object, object$N)[rows]
          }
          if (any(!is.finite(size)) || any(size < 0)) {
            stop(
              "simulate.gllvmTMB_julia: Binomial trial sizes must be finite ",
              "and non-negative.",
              call. = FALSE
            )
          }
          stats::rbinom(sum(rows), size = as.integer(size), prob = prob)
        },
        nb1 = {
          if (any(mu_vec[rows] < 0)) {
            stop(
              "simulate.gllvmTMB_julia: NB1 fitted means must be non-negative.",
              call. = FALSE
            )
          }
          phi <- .gllvm_julia_row_dispersion(
            object,
            fam,
            length(mu_vec),
            rows = rows
          )
          stats::rnbinom(
            sum(rows),
            mu = mu_vec[rows],
            size = mu_vec[rows] / phi
          )
        },
        negbinomial = {
          if (any(mu_vec[rows] < 0)) {
            stop(
              "simulate.gllvmTMB_julia: NB2 fitted means must be non-negative.",
              call. = FALSE
            )
          }
          size <- .gllvm_julia_row_dispersion(
            object,
            fam,
            length(mu_vec),
            rows = rows
          )
          stats::rnbinom(sum(rows), mu = mu_vec[rows], size = size)
        },
        beta = {
          if (any(mu_vec[rows] <= 0 | mu_vec[rows] >= 1)) {
            stop(
              "simulate.gllvmTMB_julia: Beta fitted means must be inside (0, 1).",
              call. = FALSE
            )
          }
          phi <- .gllvm_julia_row_dispersion(
            object,
            fam,
            length(mu_vec),
            rows = rows
          )
          stats::rbeta(
            sum(rows),
            shape1 = mu_vec[rows] * phi,
            shape2 = (1 - mu_vec[rows]) * phi
          )
        },
        gamma = {
          if (any(mu_vec[rows] <= 0)) {
            stop(
              "simulate.gllvmTMB_julia: Gamma fitted means must be positive.",
              call. = FALSE
            )
          }
          alpha <- .gllvm_julia_row_dispersion(
            object,
            fam,
            length(mu_vec),
            rows = rows
          )
          stats::rgamma(sum(rows), shape = alpha, scale = mu_vec[rows] / alpha)
        },
        stop(
          "simulate.gllvmTMB_julia: family '",
          fam,
          "' is not routed through Julia-engine simulation yet. Supported: ",
          "gaussian, poisson, binomial, negbinomial, nb1, beta, gamma.",
          call. = FALSE
        )
      )
    }
    out[, j] <- draw
  }
  colnames(out) <- paste0("sim_", seq_len(nsim))
  attr(out, "seed") <- seed
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
predict.gllvmTMB_julia <- function(
  object,
  newdata = NULL,
  type = NULL,
  re_form = ~.,
  ...
) {
  if (!is.null(newdata)) {
    stop(
      "predict.gllvmTMB_julia: newdata predictions are not wired yet; ",
      "only in-sample predictions are currently supported.",
      call. = FALSE
    )
  }
  include_latent <- !.gllvm_julia_re_zero(re_form)

  ## Ordinal (cumulative-link) fits have no scalar response mean, so they take a
  ## distinct prediction vocabulary: type = "prob" (per-category probabilities) or
  ## type = "class" (modal category). The cutpoints/probabilities ride the bridge
  ## payload; eta is the cached conditional reconstruction Lambda %*% t(scores).
  ## "link"/"response" are accepted only to emit a directed error pointing at the
  ## ordinal vocabulary, mirroring the families that do carry a scalar mean.
  if (.gllvm_julia_is_ordinal_object(object)) {
    type <- if (is.null(type)) {
      "prob"
    } else {
      match.arg(type, c("prob", "class", "link", "response"))
    }
    if (type %in% c("link", "response")) {
      stop(
        "predict.gllvmTMB_julia: ordinal link/response-scale predictions are ",
        "not wired; use type = \"prob\" for per-category probabilities or ",
        "type = \"class\" for the modal category.",
        call. = FALSE
      )
    }
    if (identical(type, "prob")) {
      return(.gllvm_julia_ordinal_long_prob(object, include_latent = include_latent))
    }
    cls <- .gllvm_julia_ordinal_class(object, include_latent = include_latent)
    return(.gllvm_julia_long_values(object, cls, "class"))
  }

  type <- if (is.null(type)) "link" else match.arg(type, c("link", "response"))
  eta <- .gllvm_julia_eta_matrix(object, include_latent = include_latent)
  values <- if (identical(type, "link")) {
    eta
  } else {
    .gllvm_julia_inverse_link(object, eta)
  }
  .gllvm_julia_long_values(object, values, "est")
}

#' @rdname gllvmTMB_julia-methods
#' @export
fitted.gllvmTMB_julia <- function(
  object,
  type = c("response", "link"),
  re_form = ~.,
  ...
) {
  type <- match.arg(type)
  eta <- .gllvm_julia_eta_matrix(
    object,
    include_latent = !.gllvm_julia_re_zero(re_form)
  )
  if (identical(type, "link")) {
    eta
  } else {
    .gllvm_julia_inverse_link(object, eta)
  }
}

#' @rdname gllvmTMB_julia-methods
#' @export
residuals.gllvmTMB_julia <- function(
  object,
  type = c("response", "pearson"),
  ...
) {
  type <- match.arg(type)
  observed <- object$y
  if (is.null(observed)) {
    stop(
      "residuals.gllvmTMB_julia: object does not carry the response matrix.",
      call. = FALSE
    )
  }
  fit <- fitted(object, type = "response")
  mask <- object$observed_mask
  residual <- observed - fit
  if (!is.null(mask)) {
    observed[!mask] <- NA_real_
    residual[!mask] <- NA_real_
  }
  out <- .gllvm_julia_long_values(object, residual, "residual")
  if (identical(type, "pearson")) {
    variance <- .gllvm_julia_pearson_variance(object, fit)
    out$residual <- out$residual / sqrt(variance)
  }
  out$observed <- .gllvm_julia_long_values(
    object,
    observed,
    "observed"
  )$observed
  out$fitted <- .gllvm_julia_long_values(object, fit, "fitted")$fitted
  out$type <- type
  if (!is.null(mask)) {
    if (!is.null(object$.trait_index) && !is.null(object$.unit_index)) {
      row_mask <- mask[cbind(object$.trait_index, object$.unit_index)]
    } else {
      row_mask <- as.vector(mask)
    }
    out$status <- ifelse(row_mask, "ok", "masked")
  } else {
    out$status <- "ok"
  }
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
summary.gllvmTMB_julia <- function(object, ...) {
  out <- list(
    header = list(
      family = paste(unique(object$family), collapse = ","),
      model = object$model %||% NA_character_,
      d = object$d,
      n_traits = object$n_traits,
      n_units = object$n_units,
      logLik = object$loglik,
      AIC = object$aic,
      BIC = object$bic,
      df = object$df,
      nobs = object$nobs,
      converged = object$converged,
      iterations = object$iterations
    ),
    coefficients = .gllvm_julia_coef_table(object),
    coef = coef(object),
    note = object$note %||% ""
  )
  class(out) <- "summary.gllvmTMB_julia"
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
print.summary.gllvmTMB_julia <- function(x, digits = 3, ...) {
  h <- x$header
  cat("gllvmTMB Julia-engine summary\n")
  cat(sprintf(
    "  family: %s | model: %s | K = %d | %d traits x %d units\n",
    h$family,
    h$model,
    h$d,
    h$n_traits,
    h$n_units
  ))
  cat(sprintf(
    "  logLik = %.*f | AIC = %.*f | BIC = %.*f | converged = %s\n",
    digits,
    h$logLik,
    digits,
    h$AIC,
    digits,
    h$BIC,
    h$converged
  ))
  if (nrow(x$coefficients) > 0L) {
    cat("\nCoefficients:\n")
    tab <- x$coefficients
    tab$estimate <- round(tab$estimate, digits)
    print(tab, row.names = FALSE)
  }
  if (!is.null(x$coef$loadings)) {
    cat("\nLoadings:\n")
    print(round(x$coef$loadings, digits))
  }
  if (!identical(x$note, "")) {
    cat("\nNote: ", x$note, "\n", sep = "")
  }
  invisible(x)
}

#' Confidence intervals for a Julia-engine GLLVM fit
#'
#' Surfaces the GLLVM.jl engine's confidence intervals (computed by its native
#' Wald / profile-likelihood / parametric-bootstrap engines) as a standard R
#' `confint()` matrix. If `object` does not already carry CI fields for the
#' requested `method`/`level`, the fit is re-run through the bridge with the
#' matching `ci_method` (no CI math is implemented in R).
#'
#' @param object A `gllvmTMB_julia` object from [gllvm_julia_fit()].
#' @param parm Parameters to return: a character vector of bridge parameter names
#'   (e.g. `"sigma_eps"`, `"Lambda_B[1,1]"`) or an integer index. `NULL` (default)
#'   returns every parameter.
#' @param level Nominal coverage (default `0.95`). A re-fit is triggered if the
#'   object's cached CI level differs.
#' @param method One of `"wald"` (default), `"profile"`, or `"bootstrap"`.
#' @param ... Forwarded to [gllvm_julia_fit()] on a re-fit (e.g. `ci_nboot`,
#'   `ci_seed`, `jl_path`, `julia_home`).
#' @return A numeric matrix with one row per parameter (rownames = bridge
#'   parameter names) and two columns giving the lower/upper bounds, labelled
#'   `"<a> %"` / `"<1-a> %"` in the `stats::confint()` convention. Successful
#'   matrices carry a row-named `ci_status` attribute using the same vocabulary
#'   as native `gllvmTMB` interval helpers.
#'   Mixed-family, masked-response, non-Gaussian fixed-effect-X, and Gaussian
#'   REML Julia bridge objects fail before refitting with method-specific
#'   unavailable CI-status strings.
#' @export
#' @method confint gllvmTMB_julia
confint.gllvmTMB_julia <- function(
  object,
  parm = NULL,
  level = 0.95,
  method = c("wald", "profile", "bootstrap"),
  ...
) {
  method <- match.arg(method)
  if (.gllvm_julia_is_mixed_object(object)) {
    .gllvm_julia_stop_mixed_ci("confint.gllvmTMB_julia", method)
  }
  if (.gllvm_julia_has_masked_response(object$observed_mask)) {
    .gllvm_julia_stop_masked_ci("confint.gllvmTMB_julia", method)
  }
  if (!is.null(object$X) && !identical(object$family[1], "gaussian")) {
    .gllvm_julia_stop_non_gaussian_x_ci("confint.gllvmTMB_julia", method)
  }
  if (isTRUE(object$reml)) {
    .gllvm_julia_stop_reml_ci("confint.gllvmTMB_julia", method)
  }

  ## Decide whether the cached CI payload already matches the request. The bridge
  ## stamps the actually-run method/level onto ci_method/ci_level, so we re-fit
  ## only when those differ (or when no CI fields are present at all).
  has_ci <- !is.null(object$ci_method) && !is.null(object$ci_lower)
  ci_ok <- has_ci &&
    identical(as.character(object$ci_method), method) &&
    isTRUE(all.equal(as.numeric(object$ci_level), as.numeric(level)))

  if (!ci_ok) {
    ## Re-fit on the SAME data with the requested CI method. The bridge needs the
    ## raw response (+ trials N when binomial); we reconstruct the call inputs
    ## from the cached fit. A re-fit requires the original response matrix, kept
    ## on the object by the dispatcher; if absent, error clearly rather than fake.
    y <- object$y
    if (is.null(y)) {
      stop(
        "confint.gllvmTMB_julia: this object carries no cached CI fields for ",
        "method = '",
        method,
        "' (level ",
        level,
        ") and no stored response ",
        "matrix to re-fit. Re-fit with gllvm_julia_fit(..., ci_method = '",
        method,
        "').",
        call. = FALSE
      )
    }
    refit <- gllvm_julia_fit(
      y,
      family = object$family[1],
      num.lv = object$d,
      N = object$N,
      X = object$X,
      mask = object$observed_mask,
      ci_method = method,
      reml = isTRUE(object$reml),
      ci_level = level,
      ...
    )
    object$ci_method <- refit$ci_method
    object$ci_level <- refit$ci_level
    object$ci_param_names <- refit$ci_param_names
    object$ci_estimate <- refit$ci_estimate
    object$ci_lower <- refit$ci_lower
    object$ci_upper <- refit$ci_upper
    object$ci_status <- refit$ci_status
    object$ci_note <- refit$ci_note
  }

  status <- if (is.null(object$ci_status)) {
    "ok"
  } else {
    as.character(object$ci_status)
  }
  if (!identical(status, "ok")) {
    note <- if (is.null(object$ci_note)) {
      "no CI note returned by the Julia bridge"
    } else {
      object$ci_note
    }
    stop(
      "confint.gllvmTMB_julia: GLLVM.jl bridge returned CI status '",
      status,
      "' for method = '",
      method,
      "': ",
      note,
      call. = FALSE
    )
  }

  nms <- as.character(object$ci_param_names)
  a <- (1 - level) / 2
  pct <- paste(
    format(100 * c(a, 1 - a), trim = TRUE, scientific = FALSE, digits = 3),
    "%"
  )
  ci <- matrix(
    c(object$ci_lower, object$ci_upper),
    ncol = 2,
    dimnames = list(nms, pct)
  )

  if (!is.null(parm)) {
    sel <- if (is.numeric(parm)) parm else match(parm, nms)
    if (anyNA(sel)) {
      stop(
        "confint.gllvmTMB_julia: unknown parm: ",
        paste(parm[is.na(sel)], collapse = ", "),
        call. = FALSE
      )
    }
    ci <- ci[sel, , drop = FALSE]
  }
  .gtmb_attach_ci_status(ci, method)
}

# ---------------------------------------------------------------------------
# engine = "julia" dispatch for the main gllvmTMB() entry point.
#
# Called from gllvmTMB() AFTER desugar_brms_sugar() + parse_multi_formula(), so
# the user grammar (latent/dep/indep/unique -> rr/diag/...) is already interpreted
# exactly as the TMB engine interprets it. We map the unconstrained-ordination
# core that GLLVM.jl's bridge_fit currently exposes (a single reduced-rank latent
# block + per-trait intercepts, every family) and reject anything else loudly with
# a pointer to engine = "tmb" -- never a silent approximation.
# ---------------------------------------------------------------------------
.gllvmTMB_julia_dispatch <- function(
  parsed,
  data,
  trait,
  unit_internal,
  family,
  weights = NULL,
  REML = FALSE,
  call = NULL,
  is_y_observed = NULL
) {
  cs <- parsed$covstructs
  kinds <- if (length(cs)) {
    vapply(cs, function(z) z$kind, character(1))
  } else {
    character(0)
  }

  ## --- capability guard: only the reduced-rank latent block (rr) is mapped ---
  unsupported <- setdiff(unique(kinds), "rr")
  if (length(unsupported) > 0) {
    stop(
      "engine = 'julia' does not yet support covariance term(s): ",
      paste(unsupported, collapse = ", "),
      ". Use engine = 'tmb' for structured / grouped / phylo / spatial terms.",
      call. = FALSE
    )
  }
  rr_terms <- cs[kinds == "rr"]
  if (length(rr_terms) > 1L) {
    stop(
      "engine = 'julia' supports a single reduced-rank latent block; found ",
      length(rr_terms),
      ". Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  K <- if (length(rr_terms) == 1L) {
    dval <- rr_terms[[1L]]$extra$d
    as.integer(if (is.null(dval)) 1L else dval)
  } else {
    stop(
      "engine = 'julia' requires exactly one reduced-rank latent block ",
      "(`latent(..., d = K)`); use engine = 'tmb' for fixed-effect-only fits.",
      call. = FALSE
    )
  }
  if (K < 1L) {
    stop("engine = 'julia' requires latent dimension d >= 1.", call. = FALSE)
  }
  ## --- response: pivot long (trait, unit) -> a p x n matrix ---
  mf <- stats::model.frame(
    parsed$fixed,
    data = data,
    na.action = stats::na.pass
  )
  yraw <- stats::model.response(mf)
  ft <- factor(data[[trait]])
  fu <- factor(data[[unit_internal]])
  family_resolved <- .gllvm_julia_mixed_selector(family, data, trait, ft)
  fam_str <- family_resolved$family
  is_mixed_family <- .gllvm_julia_is_mixed_family(fam_str)
  if (is_mixed_family && isTRUE(REML)) {
    stop(
      "engine = 'julia': REML is Gaussian-only; mixed-family Julia fits ",
      "must use REML = FALSE.",
      call. = FALSE
    )
  }
  if (!is_mixed_family && isTRUE(REML) && !identical(fam_str, "gaussian")) {
    stop(
      "engine = 'julia': REML is Gaussian-only on the Julia bridge; ",
      "use REML = FALSE or engine = 'tmb'.",
      call. = FALSE
    )
  }
  row_observed <- if (is.null(is_y_observed)) {
    rep(TRUE, length(ft))
  } else {
    if (length(is_y_observed) != length(ft)) {
      stop(
        "engine = 'julia': observed-response mask length mismatch.",
        call. = FALSE
      )
    }
    as.integer(is_y_observed) != 0L
  }

  cbind_binomial <- is.matrix(yraw) && ncol(yraw) == 2L
  if (cbind_binomial) {
    if (is_mixed_family) {
      stop(
        "engine = 'julia': cbind(successes, failures) mixed-family fits ",
        "are not wired yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!identical(fam_str, "binomial")) {
      stop(
        "engine = 'julia': cbind(successes, failures) responses are wired ",
        "only for family = binomial(). Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    succ <- as.numeric(yraw[, 1L])
    fail <- as.numeric(yraw[, 2L])
    obs <- row_observed
    if (any(!is.finite(succ[obs])) || any(!is.finite(fail[obs]))) {
      stop(
        "engine = 'julia': observed cbind(successes, failures) cells must be finite.",
        call. = FALSE
      )
    }
    if (any(succ[obs] < 0) || any(fail[obs] < 0)) {
      stop(
        "engine = 'julia': cbind(successes, failures) columns must be non-negative.",
        call. = FALSE
      )
    }
    trials_row <- succ + fail
    if (any(trials_row[obs] <= 0)) {
      stop(
        "engine = 'julia': cbind(successes, failures) rows with zero trials ",
        "are not allowed.",
        call. = FALSE
      )
    }
    yv <- succ
    yv[!obs] <- 0
    trials_row[!obs] <- 1
  } else {
    yv <- as.numeric(yraw)
    trials_row <- NULL
  }
  if (length(yv) != length(ft) || length(yv) != length(fu)) {
    stop(
      "engine = 'julia': response / trait / unit length mismatch.",
      call. = FALSE
    )
  }
  traits <- levels(ft)
  units <- levels(fu)
  p <- length(traits)
  n <- length(units)
  Y <- matrix(NA_real_, p, n, dimnames = list(traits, units))
  filled <- matrix(FALSE, p, n, dimnames = list(traits, units))
  Mask <- matrix(FALSE, p, n, dimnames = list(traits, units))
  Y[cbind(as.integer(ft), as.integer(fu))] <- yv
  filled[cbind(as.integer(ft), as.integer(fu))] <- TRUE
  Mask[cbind(as.integer(ft), as.integer(fu))] <- row_observed
  if (any(!filled)) {
    stop(
      "engine = 'julia' currently requires a complete (balanced) trait x unit ",
      "table; found ",
      sum(!filled),
      " empty cell(s). Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  has_masked_response <- any(!Mask)
  if (has_masked_response) {
    if (is_mixed_family) {
      stop(
        "engine = 'julia': missing-response masks are not wired for ",
        "mixed-family Julia fits yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!(fam_str %in% .GLLVM_JULIA_MASK_FAMILIES)) {
      stop(
        "engine = 'julia': missing-response masks are wired only for ",
        paste(.GLLVM_JULIA_MASK_FAMILIES, collapse = ", "),
        " on this bridge branch; use engine = 'tmb' for family '",
        fam_str,
        "'.",
        call. = FALSE
      )
    }
    Y <- .gllvm_julia_sanitize_masked_y(Y, Mask, fam_str)
  } else {
    Mask <- NULL
    if (anyNA(Y)) {
      stop(
        "engine = 'julia' currently requires a complete (balanced) trait x unit ",
        "table; found ",
        sum(is.na(Y)),
        " empty cell(s). Use engine = 'tmb'.",
        call. = FALSE
      )
    }
  }

  ## --- fixed effects: the per-trait intercept (0 + trait) is mapped to the
  ## bridge's internal per-trait intercept for non-Gaussian X fits. Gaussian X
  ## fits are different: GLLVM.jl expects the FULL mean design, so we include the
  ## trait-intercept planes plus the extra covariate planes. ---
  Xfix <- stats::model.matrix(parsed$fixed, mf)
  trait_dummies <- paste0(trait, traits)
  extra_cols <- setdiff(colnames(Xfix), trait_dummies)
  has_only_trait_intercept <- (length(extra_cols) == 0 && ncol(Xfix) == p)

  Xarg <- NULL
  if (!has_only_trait_intercept) {
    if (is_mixed_family) {
      stop(
        "engine = 'julia': fixed-effect covariates are not wired for ",
        "mixed-family Julia fits yet. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!all(trait_dummies %in% colnames(Xfix))) {
      stop(
        "engine = 'julia' requires a per-trait intercept design (`0 + ",
        trait,
        "`) before adding covariates. Use engine = 'tmb' for this ",
        "fixed-effect design.",
        call. = FALSE
      )
    }
    if (length(extra_cols) == 0L) {
      stop(
        "engine = 'julia' could not isolate fixed-effect covariate columns ",
        "from the fixed-effect design. Use engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (!(fam_str %in% .GLLVM_JULIA_X_FAMILIES)) {
      stop(
        "engine = 'julia': fixed-effect covariates are not wired for family '",
        fam_str,
        "' on this bridge branch. Supported X families: ",
        paste(.GLLVM_JULIA_X_FAMILIES, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    x_cols <- if (identical(fam_str, "gaussian")) {
      c(trait_dummies, extra_cols)
    } else {
      extra_cols
    }
    Xarg <- .gllvm_julia_design_array(
      Xfix,
      x_cols,
      as.integer(ft),
      as.integer(fu),
      p,
      n
    )
  }
  if (!is.null(Mask) && !is.null(Xarg)) {
    stop(
      "engine = 'julia': missing-response masks with fixed-effect covariates ",
      "are not wired yet. Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (isTRUE(REML) && !is.null(Xarg)) {
    stop(
      "engine = 'julia': Gaussian REML with fixed-effect covariates is not ",
      "routed through the Julia bridge yet. Use engine = 'tmb'.",
      call. = FALSE
    )
  }

  ## --- binomial trials: pivot per-row n_trials (weights API) else Bernoulli ---
  Narg <- NULL
  if (is_mixed_family && !is.null(weights)) {
    stop(
      "engine = 'julia': binomial trial weights are not wired for ",
      "mixed-family Julia fits yet. Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (any(fam_str == "binomial")) {
    if (!is.null(trials_row)) {
      Narg <- matrix(1, p, n, dimnames = list(traits, units))
      Narg[cbind(as.integer(ft), as.integer(fu))] <- trials_row
    } else if (
      !is.null(weights) && is.numeric(weights) && length(weights) == length(yv)
    ) {
      Narg <- matrix(1, p, n, dimnames = list(traits, units))
      Narg[cbind(as.integer(ft), as.integer(fu))] <- as.numeric(weights)
    } else {
      Narg <- 1L
    }
  }

  fit <- gllvm_julia_fit(
    Y,
    family = fam_str,
    num.lv = K,
    N = Narg,
    X = Xarg,
    mask = Mask,
    reml = isTRUE(REML)
  )
  fit$call <- call
  fit$trait_levels <- traits
  fit$unit_levels <- units
  fit$trait_col <- trait
  fit$unit_col <- unit_internal
  fit$.trait_index <- as.integer(ft)
  fit$.unit_index <- as.integer(fu)
  if (!is.null(family_resolved$selector)) {
    fit$family_input <- family
    fit$family_selector <- family_resolved$selector
    fit$family_by_trait <- stats::setNames(fam_str, traits)
  }
  fit
}
