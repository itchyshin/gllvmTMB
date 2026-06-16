# ---------------------------------------------------------------------------
# R -> Julia bridge: run the fast GLLVM.jl engine from R via JuliaCall.
#
# `gllvmTMB(..., engine = "julia")` routes here: we marshal the response matrix +
# model spec to GLLVM.jl's flat `bridge_fit` contract, run the Julia fitter, and
# unmarshal the result into a gllvmTMB-compatible list. JuliaCall is a SUGGESTED
# dependency — everything here errors cleanly if it (or the GLLVM.jl path) is absent.
#
# Contract + family mapping: GLLVM.jl docs/dev-log/2026-06-10-bridge-fit-contract-and-r-wiring.md.
# ---------------------------------------------------------------------------

# session cache so JuliaCall + GLLVM.jl load only once
.gllvm_jl_env <- new.env(parent = emptyenv())

# Bridge family strings admitted by the lean R bridge. Keep this conservative:
# the paired Julia checkout may expose broader low-level rows before R-side
# labels, scale maps, CI status, and parity evidence are ready (gllvmTMB#488).
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
.GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES <- c(
  "negbinomial",
  "nb1",
  "beta",
  "gamma"
)
.GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES <- c(
  "negbinomial",
  "nb1",
  "beta"
)
.GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES <- c(
  "ordinal",
  "ordinal_probit"
)
.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial"
)
.GLLVM_JULIA_RESIDUAL_FAMILIES <- .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES
.GLLVM_JULIA_MASK_FAMILIES <- c(
  "poisson",
  "binomial",
  "negbinomial",
  "nb1",
  "beta",
  "gamma",
  .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
)
.GLLVM_JULIA_X_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "beta",
  "gamma"
)
.GLLVM_JULIA_MIXED_FAMILY <- "mixed-family vector"
.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial"
)
.GLLVM_JULIA_CI_NO_X_FAMILIES <- setdiff(
  .GLLVM_JULIA_BRIDGE_FAMILIES,
  c(
    .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES,
    .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
  )
)
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

#' Current R-side capability ledger for the Julia bridge
#'
#' `gllvm_julia_capabilities()` reports the rows currently admitted by the lean
#' R `engine = "julia"` bridge before any JuliaCall setup. It is deliberately
#' conservative: the paired `GLLVM.jl` checkout may expose broader engine rows
#' before R-side payload labels, public-scale maps, confidence-interval status,
#' and native `gllvmTMB` parity evidence are complete.
#'
#' @return A data frame with one row per admitted bridge family plus the narrow
#'   mixed-family vector route. Boolean columns mark the current R-side fit,
#'   transport, no-X CI, and post-fit cells. CI columns are deliberately named
#'   `ci_no_x_*`: they do not imply masked, mixed-family, or non-Gaussian-X
#'   intervals. `status` is `"partial"` for every current row, with the boundary
#'   recorded in `notes`.
#' @examples
#' head(gllvm_julia_capabilities())
#' @export
gllvm_julia_capabilities <- function() {
  families <- .GLLVM_JULIA_BRIDGE_FAMILIES
  notes <- vapply(families, .gllvm_julia_capability_note, character(1))
  out <- data.frame(
    family = families,
    fit_no_x = TRUE,
    fixed_effect_X = families %in% .GLLVM_JULIA_X_FAMILIES,
    missing_response = families %in% .GLLVM_JULIA_MASK_FAMILIES,
    cbind_binomial = FALSE,
    ci_no_x_wald = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_profile = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_bootstrap = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    postfit_coef = TRUE,
    postfit_fit_stats = TRUE,
    postfit_summary = TRUE,
    postfit_predict = families %in% .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES,
    postfit_residuals = families %in% .GLLVM_JULIA_RESIDUAL_FAMILIES,
    postfit_simulate = FALSE,
    postfit_ordination = FALSE,
    status = "partial",
    notes = notes,
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
    postfit_predict = FALSE,
    postfit_residuals = FALSE,
    postfit_simulate = FALSE,
    postfit_ordination = FALSE,
    status = "partial",
    notes = paste(
      "complete balanced no-X/no-mask/no-CI mixed-family point route;",
      "coef() and summary() are routed;",
      "predict/fitted/residuals/simulate/extractor parity remain gated;",
      "component families:",
      paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", ")
    ),
    stringsAsFactors = FALSE
  )
  rbind(out, mixed)
}

.gllvm_julia_capability_note <- function(family) {
  mask_clause <- if (family %in% .GLLVM_JULIA_MASK_FAMILIES) {
    "response masks are routed for no-X point fits; "
  } else {
    "response masks remain gated; "
  }
  x_clause <- if (family %in% .GLLVM_JULIA_X_FAMILIES) {
    "fixed-effect X point fits are routed for complete responses; "
  } else {
    "fixed-effect X remains gated; "
  }
  ci_x_followup <- if (family %in% .GLLVM_JULIA_X_FAMILIES) {
    "CI and native parity promotion are follow-ups"
  } else {
    "CI, X, and native parity promotion are follow-ups"
  }
  ci_clause <- if (family %in% .GLLVM_JULIA_CI_NO_X_FAMILIES) {
    paste0(
      "direct gllvm_julia_fit() no-X Wald/profile/bootstrap CI payloads ",
      "are routed; gllvmTMB() fits retain bridge input for post-fit ",
      "confint() recomputation; "
    )
  } else {
    ""
  }
  predict_clause <- if (family %in% .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES) {
    "in-sample predict()/fitted() are routed from retained score payloads; "
  } else if (family %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
    paste0(
      "prediction remains gated until ordinal score/probability payloads ",
      "are admitted; "
    )
  } else {
    paste0(
      "predict()/fitted() remain gated for current grouped-dispersion ",
      "rows without retained score payloads; "
    )
  }
  residual_clause <- if (family %in% .GLLVM_JULIA_RESIDUAL_FAMILIES) {
    paste0(
      "in-sample response/Pearson residuals are routed from retained ",
      "fitted values; simulate/extractor parity remain gated; "
    )
  } else {
    paste0(
      "response/Pearson residuals remain gated; ",
      "simulate/extractor parity remain gated; "
    )
  }
  postfit_clause <- if (family %in% .GLLVM_JULIA_CI_NO_X_FAMILIES) {
    paste0(
      "coef(), summary(), and no-X confint() are routed; ",
      predict_clause,
      residual_clause
    )
  } else {
    paste0(
      "coef() and summary() are routed; ",
      predict_clause,
      "confint() remains gated until CI endpoints are admitted; ",
      residual_clause
    )
  }
  if (family %in% .GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES) {
    return(paste0(
      "single reduced-rank point route; default no-X Julia payload uses ",
      "per-trait grouped dispersion; ",
      mask_clause,
      x_clause,
      postfit_clause,
      ci_x_followup
    ))
  }
  if (identical(family, "gamma")) {
    return(paste0(
      "single reduced-rank point route; default no-X Julia payload uses ",
      "shared Gamma grouped dispersion to match current native scalar-CV ",
      "Gamma; per-trait Gamma is a native-expansion follow-up; ",
      mask_clause,
      x_clause,
      postfit_clause,
      "CI and native parity promotion are follow-ups"
    ))
  }
  if (family %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
    return(paste0(
      "single reduced-rank point route; default no-X Julia payload uses ",
      "per-trait ordinal cutpoints; ",
      mask_clause,
      x_clause,
      postfit_clause,
      "CI, X, and native parity promotion are follow-ups"
    ))
  }
  paste0(
    "single reduced-rank point route; ",
    mask_clause,
    x_clause,
    ci_clause,
    postfit_clause,
    "broader structures and native parity promotion remain gated"
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
      "engine = 'julia': family must resolve to one supported family name.",
      call. = FALSE
    )
  }
  switch(
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
    {
      stop(
        "engine = 'julia': unsupported family '",
        fam,
        "'. Supported: gaussian, poisson, ",
        "binomial, nbinom2, nbinom1, beta, gamma, ordinal, ordinal_probit ",
        "(or a narrow list for mixed gaussian/poisson/binomial responses).",
        call. = FALSE
      )
    }
  )
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

.gllvm_julia_as_vector <- function(
  x,
  mode = c("numeric", "integer", "character")
) {
  mode <- match.arg(mode)
  out <- unlist(x, use.names = FALSE)
  switch(
    mode,
    numeric = as.numeric(out),
    integer = as.integer(out),
    character = as.character(out)
  )
}

.gllvm_julia_n_traits <- function(res) {
  if (!is.null(res$n_traits)) {
    return(as.integer(res$n_traits)[1L])
  }
  if (!is.null(res$trait_names)) {
    return(length(.gllvm_julia_as_vector(res$trait_names, "character")))
  }
  if (!is.null(res$loadings)) {
    return(nrow(as.matrix(res$loadings)))
  }
  if (!is.null(res$Sigma)) {
    return(nrow(as.matrix(res$Sigma)))
  }
  if (!is.null(res$dispersion)) {
    return(length(.gllvm_julia_as_vector(res$dispersion, "numeric")))
  }
  0L
}

.gllvm_julia_trait_names <- function(res, p = .gllvm_julia_n_traits(res)) {
  if (!is.null(res$trait_names)) {
    out <- .gllvm_julia_as_vector(res$trait_names, "character")
    if (length(out) == p) return(out)
  }
  if (!is.null(names(res$dispersion)) && length(names(res$dispersion)) == p) {
    return(names(res$dispersion))
  }
  paste0("trait", seq_len(p))
}

.gllvm_julia_public_dispersion <- function(family, values) {
  if (family == "negbinomial") {
    return(1 / sqrt(values))
  }
  if (family == "nb1") {
    return(values)
  }
  if (family %in% c("beta", "gamma")) {
    return(1 / sqrt(values))
  }
  values
}

.gllvm_julia_public_dispersion_parameter <- function(family) {
  switch(
    family,
    negbinomial = "sigma",
    nb1 = "phi",
    beta = "sigma",
    gamma = "sigma",
    "dispersion"
  )
}

.gllvm_julia_normalise_result <- function(res) {
  p <- .gllvm_julia_n_traits(res)
  if (p > 0L) {
    traits <- .gllvm_julia_trait_names(res, p)
    res$trait_names <- traits
    if (!is.null(res$alpha) && length(res$alpha) == p) {
      res$alpha <- .gllvm_julia_as_vector(res$alpha, "numeric")
      names(res$alpha) <- traits
    }
    if (!is.null(res$communality) && length(res$communality) == p) {
      res$communality <- .gllvm_julia_as_vector(res$communality, "numeric")
      names(res$communality) <- traits
    }
    if (!is.null(res$beta_cov) && length(res$beta_cov) == p) {
      res$beta_cov <- .gllvm_julia_as_vector(res$beta_cov, "numeric")
      names(res$beta_cov) <- traits
    }
    if (!is.null(res$loadings) && nrow(as.matrix(res$loadings)) == p) {
      res$loadings <- as.matrix(res$loadings)
      rownames(res$loadings) <- traits
    }
    if (!is.null(res$Sigma) && nrow(as.matrix(res$Sigma)) == p) {
      res$Sigma <- as.matrix(res$Sigma)
      dimnames(res$Sigma) <- list(traits, traits)
    }
    if (!is.null(res$correlation) && nrow(as.matrix(res$correlation)) == p) {
      res$correlation <- as.matrix(res$correlation)
      dimnames(res$correlation) <- list(traits, traits)
    }
  } else {
    traits <- character()
  }

  if (!is.null(res$unit_names)) {
    res$unit_names <- .gllvm_julia_as_vector(res$unit_names, "character")
  }

  fam <- if (!is.null(res$family)) {
    .gllvm_julia_as_vector(res$family, "character")[1L]
  } else {
    NA_character_
  }
  if (
    !is.na(fam) &&
      fam %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES &&
      (!is.null(res$dispersion_group) || !is.null(res$dispersion))
  ) {
    dispersion <- if (!is.null(res$dispersion)) {
      .gllvm_julia_as_vector(res$dispersion, "numeric")
    } else {
      numeric()
    }
    if (length(dispersion) == 1L && p > 1L) {
      dispersion <- rep(dispersion, p)
    }
    if (p > 0L && length(dispersion) == p) {
      names(dispersion) <- traits
    }

    if (!is.null(res$dispersion_group)) {
      group <- .gllvm_julia_as_vector(res$dispersion_group, "numeric")
    } else {
      group <- dispersion
    }
    if (!is.null(res$dispersion_group_id)) {
      group_id <- .gllvm_julia_as_vector(res$dispersion_group_id, "integer")
    } else {
      group_id <- seq_along(dispersion)
    }
    if (p > 0L && length(group_id) != p) {
      stop(
        "engine = 'julia': grouped-dispersion payload has ",
        length(group_id),
        " group ids for ",
        p,
        " traits.",
        call. = FALSE
      )
    }
    if (length(group) && any(!is.finite(group) | group <= 0)) {
      stop(
        "engine = 'julia': grouped-dispersion payload must be finite and positive.",
        call. = FALSE
      )
    }
    if (
      length(group_id) && (min(group_id) < 1L || max(group_id) > length(group))
    ) {
      stop(
        "engine = 'julia': grouped-dispersion ids are out of range.",
        call. = FALSE
      )
    }

    group_names <- names(res$dispersion_group)
    if (
      is.null(group_names) ||
        length(group_names) != length(group) ||
        any(!nzchar(group_names))
    ) {
      group_names <- if (
        length(group) == p && identical(group_id, seq_len(p))
      ) {
        traits
      } else {
        paste0("group", seq_along(group))
      }
    }
    names(group) <- group_names
    names(group_id) <- traits

    if (length(group_id) && length(group)) {
      dispersion <- group[group_id]
      names(dispersion) <- traits
    }
    public_group <- .gllvm_julia_public_dispersion(fam, group)
    names(public_group) <- group_names
    public <- .gllvm_julia_public_dispersion(fam, dispersion)
    names(public) <- names(dispersion)

    res$dispersion <- dispersion
    res$dispersion_group <- group
    res$dispersion_group_id <- group_id
    res$dispersion_engine <- dispersion
    res$dispersion_group_engine <- group
    res$dispersion_public <- public
    res$dispersion_group_public <- public_group
    res$dispersion_public_parameter <- .gllvm_julia_public_dispersion_parameter(
      fam
    )
    if (fam == "negbinomial") {
      res$dispersion_gllvm_phi <- 1 / dispersion
      res$dispersion_group_gllvm_phi <- 1 / group
    }
  } else if (!is.null(res$dispersion) && p > 0L) {
    dispersion <- .gllvm_julia_as_vector(res$dispersion, "numeric")
    if (length(dispersion) == 1L && p > 1L) {
      dispersion <- rep(dispersion, p)
    }
    if (length(dispersion) == p) {
      names(dispersion) <- traits
      res$dispersion <- dispersion
    }
  }
  if (
    !is.na(fam) &&
      fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES &&
      !is.null(res$cutpoints)
  ) {
    cutpoints <- as.matrix(res$cutpoints)
    storage.mode(cutpoints) <- "numeric"
    if (p > 0L && nrow(cutpoints) != p && ncol(cutpoints) == p) {
      cutpoints <- t(cutpoints)
    }
    if (p > 0L && nrow(cutpoints) != p) {
      stop(
        "engine = 'julia': ordinal cutpoint payload has ",
        nrow(cutpoints),
        " trait row(s) for ",
        p,
        " traits.",
        call. = FALSE
      )
    }
    if (!is.null(res$n_categories)) {
      n_categories <- .gllvm_julia_as_vector(res$n_categories, "integer")
    } else {
      n_categories <- rowSums(!is.na(cutpoints)) + 1L
    }
    if (p > 0L && length(n_categories) != p) {
      stop(
        "engine = 'julia': ordinal category-count payload has ",
        length(n_categories),
        " value(s) for ",
        p,
        " traits.",
        call. = FALSE
      )
    }
    if (any(is.na(n_categories) | n_categories < 2L)) {
      stop(
        "engine = 'julia': ordinal category counts must be integers >= 2.",
        call. = FALSE
      )
    }
    if (ncol(cutpoints) < max(n_categories - 1L)) {
      stop(
        "engine = 'julia': ordinal cutpoint matrix has too few threshold columns.",
        call. = FALSE
      )
    }
    for (i in seq_along(n_categories)) {
      active <- seq_len(n_categories[[i]] - 1L)
      vals <- cutpoints[i, active]
      if (any(!is.finite(vals))) {
        stop(
          "engine = 'julia': active ordinal cutpoints must be finite.",
          call. = FALSE
        )
      }
      if (length(vals) > 1L && any(diff(vals) <= 0)) {
        stop(
          "engine = 'julia': ordinal cutpoints must be strictly increasing by trait.",
          call. = FALSE
        )
      }
      inactive <- setdiff(seq_len(ncol(cutpoints)), active)
      if (length(inactive)) cutpoints[i, inactive] <- NaN
    }
    if (p > 0L) {
      rownames(cutpoints) <- traits
      names(n_categories) <- traits
    }
    colnames(cutpoints) <- paste0("cutpoint", seq_len(ncol(cutpoints)))
    res$cutpoints <- cutpoints
    res$n_categories <- n_categories
    res$cutpoint_mode <- if (!is.null(res$cutpoint_mode)) {
      .gllvm_julia_as_vector(res$cutpoint_mode, "character")[1L]
    } else {
      "per_trait"
    }
    if (!is.null(res$cutpoint_link)) {
      res$cutpoint_link <- .gllvm_julia_as_vector(
        res$cutpoint_link,
        "character"
      )[1L]
    }
  }
  res <- .gllvm_julia_normalise_ci(res)
  res
}

.gllvm_julia_normalise_ci <- function(res) {
  if (is.null(res$ci_method)) {
    return(res)
  }

  res$ci_method <- .gllvm_julia_as_vector(res$ci_method, "character")[1L]
  res$ci_level <- as.numeric(.gllvm_julia_as_vector(
    res$ci_level %||% NA_real_,
    "numeric"
  )[1L])
  res$ci_param_names <- .gllvm_julia_as_vector(
    res$ci_param_names %||% character(),
    "character"
  )
  res$ci_estimate <- .gllvm_julia_as_vector(
    res$ci_estimate %||% numeric(),
    "numeric"
  )
  res$ci_lower <- .gllvm_julia_as_vector(res$ci_lower %||% numeric(), "numeric")
  res$ci_upper <- .gllvm_julia_as_vector(res$ci_upper %||% numeric(), "numeric")
  res$ci_note <- .gllvm_julia_as_vector(res$ci_note %||% "", "character")[1L]

  n <- length(res$ci_param_names)
  if (
    !identical(length(res$ci_estimate), n) ||
      !identical(length(res$ci_lower), n) ||
      !identical(length(res$ci_upper), n)
  ) {
    stop(
      "engine = 'julia': CI payload vectors must have matching lengths.",
      call. = FALSE
    )
  }
  if (n > 0L) {
    names(res$ci_estimate) <- res$ci_param_names
    names(res$ci_lower) <- res$ci_param_names
    names(res$ci_upper) <- res$ci_param_names
  }
  res$ci_status <- if (n > 0L) {
    "available"
  } else if (nzchar(res$ci_note)) {
    "unavailable"
  } else {
    "empty"
  }
  res
}

.gllvm_julia_mask_placeholder <- function(family) {
  switch(
    family,
    poisson = 0,
    binomial = 0,
    negbinomial = 0,
    nb1 = 0,
    beta = 0.5,
    gamma = 1,
    ordinal = 1,
    ordinal_probit = 1,
    stop(
      "engine = 'julia': response masks are not routed for family '",
      family,
      "'.",
      call. = FALSE
    )
  )
}

.gllvm_julia_fill_masked_response <- function(Y, family, mask) {
  if (!any(!mask)) {
    return(Y)
  }
  if (length(family) != 1L) {
    stop(
      "engine = 'julia' does not yet route response masks for mixed-family ",
      "vectors. Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (!(family %in% .GLLVM_JULIA_MASK_FAMILIES)) {
    stop(
      "engine = 'julia' response masks are currently routed for ",
      paste(.GLLVM_JULIA_MASK_FAMILIES, collapse = ", "),
      "; family '",
      family,
      "' remains gated. Use engine = 'tmb'.",
      call. = FALSE
    )
  }
  out <- Y
  out[!mask] <- .gllvm_julia_mask_placeholder(family)
  out
}

.gllvm_julia_coef_payload <- function(object) {
  out <- list()
  if (!is.null(object$alpha)) {
    out$alpha <- object$alpha
  }
  if (!is.null(object$mean_coef)) {
    out$mean_coef <- object$mean_coef
  }
  if (!is.null(object$beta_cov)) {
    out$beta_cov <- object$beta_cov
  }
  if (!is.null(object$gamma)) {
    out$gamma <- object$gamma
  }
  if (!is.null(object$loadings)) {
    out$loadings <- as.matrix(object$loadings)
  }
  if (!is.null(object$dispersion) && any(is.finite(object$dispersion))) {
    out$dispersion <- object$dispersion
  }
  if (!is.null(object$dispersion_public)) {
    out$dispersion_public <- object$dispersion_public
  }
  if (!is.null(object$dispersion_group)) {
    out$dispersion_group <- object$dispersion_group
  }
  if (!is.null(object$cutpoints)) {
    out$cutpoints <- as.matrix(object$cutpoints)
  }
  out
}

.gllvm_julia_ci_payload <- function(object) {
  if (is.null(object$ci_method)) {
    return(NULL)
  }
  data.frame(
    term = object$ci_param_names %||% character(),
    estimate = object$ci_estimate %||% numeric(),
    conf.low = object$ci_lower %||% numeric(),
    conf.high = object$ci_upper %||% numeric(),
    method = object$ci_method %||% NA_character_,
    level = object$ci_level %||% NA_real_,
    status = object$ci_status %||% NA_character_,
    note = object$ci_note %||% "",
    stringsAsFactors = FALSE
  )
}

.gllvm_julia_refit_ci <- function(object, method, level, ci_nboot, ci_seed) {
  bridge_input <- object$bridge_input
  if (is.null(bridge_input)) {
    stop(
      "This Julia bridge fit does not retain the bridge input needed to ",
      "compute confidence intervals post-fit. Refit with the current ",
      "`gllvmTMB(..., engine = \"julia\")` or call `gllvm_julia_fit(..., ",
      "ci_method = \"",
      method,
      "\")` directly.",
      call. = FALSE
    )
  }
  setup_args <- bridge_input$setup_args %||% list()
  bridge_input$setup_args <- NULL
  args <- bridge_input
  args$ci_method <- method
  args$ci_level <- level
  args$ci_nboot <- ci_nboot
  args$ci_seed <- ci_seed
  for (nm in names(setup_args)) {
    args[[nm]] <- setup_args[[nm]]
  }
  do.call(gllvm_julia_fit, args)
}

.gllvm_julia_training_y <- function(object) {
  y <- object$bridge_input$y %||% NULL
  if (!is.null(y)) {
    y <- as.matrix(y)
    storage.mode(y) <- "numeric"
    return(y)
  }
  p <- .gllvm_julia_n_traits(object)
  n <- if (!is.null(object$n_units)) {
    as.integer(object$n_units)[1L]
  } else if (!is.null(object$scores)) {
    nrow(as.matrix(object$scores))
  } else {
    0L
  }
  matrix(
    NA_real_,
    nrow = p,
    ncol = n,
    dimnames = list(
      .gllvm_julia_trait_names(object, p),
      object$unit_names %||% paste0("unit", seq_len(n))
    )
  )
}

.gllvm_julia_alpha <- function(object, p) {
  alpha <- object$alpha %||% rep(0, p)
  alpha <- as.numeric(alpha)
  if (length(alpha) == 1L && p > 1L) {
    alpha <- rep(alpha, p)
  }
  if (length(alpha) != p) {
    stop(
      "engine = 'julia': alpha payload length does not match the trait count.",
      call. = FALSE
    )
  }
  fam <- object$families %||% object$family %||% character()
  if (all(fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES)) {
    alpha[!is.finite(alpha)] <- 0
  }
  if (any(!is.finite(alpha))) {
    stop(
      "engine = 'julia': alpha payload must be finite for prediction.",
      call. = FALSE
    )
  }
  alpha
}

.gllvm_julia_latent_eta <- function(object, p, n) {
  loadings <- object$loadings %||% matrix(numeric(), nrow = p, ncol = 0L)
  scores <- object$scores %||% matrix(numeric(), nrow = n, ncol = 0L)
  loadings <- as.matrix(loadings)
  scores <- as.matrix(scores)
  storage.mode(loadings) <- "numeric"
  storage.mode(scores) <- "numeric"
  if (nrow(loadings) != p) {
    stop(
      "engine = 'julia': loading payload row count does not match traits.",
      call. = FALSE
    )
  }
  if (ncol(loadings) == 0L) {
    return(matrix(0, nrow = p, ncol = n))
  }
  if (
    nrow(scores) != n && ncol(scores) == n && nrow(scores) == ncol(loadings)
  ) {
    scores <- t(scores)
  }
  if (nrow(scores) != n) {
    stop(
      "engine = 'julia': score payload row count does not match units.",
      call. = FALSE
    )
  }
  if (ncol(loadings) != ncol(scores)) {
    stop(
      "engine = 'julia': loading and score payload dimensions do not match.",
      call. = FALSE
    )
  }
  loadings %*% t(scores)
}

.gllvm_julia_x_eta <- function(object, p, n) {
  X <- object$bridge_input$X %||% NULL
  if (is.null(X)) {
    return(NULL)
  }
  X <- as.array(X)
  if (length(dim(X)) != 3L || dim(X)[1L] != p || dim(X)[2L] != n) {
    stop(
      "engine = 'julia': retained X payload dimensions do not match the fit.",
      call. = FALSE
    )
  }
  q <- dim(X)[3L]
  if (!is.null(object$mean_coef)) {
    beta <- as.numeric(object$mean_coef)
    label <- "mean_coef"
  } else if (!is.null(object$gamma)) {
    beta <- as.numeric(object$gamma)
    label <- "gamma"
  } else {
    return(NULL)
  }
  if (length(beta) != q) {
    stop(
      "engine = 'julia': ",
      label,
      " payload length does not match retained X.",
      call. = FALSE
    )
  }
  eta <- matrix(0, nrow = p, ncol = n)
  for (k in seq_len(q)) {
    eta <- eta + X[,, k, drop = TRUE] * beta[[k]]
  }
  eta
}

.gllvm_julia_link_predictor <- function(object) {
  y <- .gllvm_julia_training_y(object)
  p <- nrow(y)
  n <- ncol(y)
  traits <- .gllvm_julia_trait_names(object, p)
  units <- object$unit_names %||% colnames(y) %||% paste0("unit", seq_len(n))
  eta <- .gllvm_julia_latent_eta(object, p, n)
  x_eta <- .gllvm_julia_x_eta(object, p, n)
  if (!is.null(x_eta) && !is.null(object$mean_coef)) {
    eta <- eta + x_eta
  } else {
    alpha <- if (!is.null(object$beta_cov)) {
      as.numeric(object$beta_cov)
    } else {
      .gllvm_julia_alpha(object, p)
    }
    if (length(alpha) == 1L && p > 1L) {
      alpha <- rep(alpha, p)
    }
    if (length(alpha) != p || any(!is.finite(alpha))) {
      stop(
        "engine = 'julia': intercept payload is invalid for prediction.",
        call. = FALSE
      )
    }
    eta <- eta + matrix(alpha, nrow = p, ncol = n)
    if (!is.null(x_eta)) {
      eta <- eta + x_eta
    }
  }
  dimnames(eta) <- list(traits, units)
  eta
}

.gllvm_julia_response_predictor <- function(object, eta) {
  families <- object$families %||% object$family %||% character()
  if (length(families) == 1L && nrow(eta) > 1L) {
    families <- rep(families, nrow(eta))
  }
  links <- object$link %||% rep(NA_character_, nrow(eta))
  if (length(links) == 1L && nrow(eta) > 1L) {
    links <- rep(links, nrow(eta))
  }
  if (length(families) != nrow(eta) || length(links) != nrow(eta)) {
    stop(
      "engine = 'julia': family/link payload length does not match traits.",
      call. = FALSE
    )
  }
  missing_link <- is.na(links) | !nzchar(links)
  if (any(missing_link)) {
    links[missing_link] <- vapply(
      families[missing_link],
      .gllvm_julia_default_link,
      character(1)
    )
  }
  out <- eta
  for (i in seq_len(nrow(eta))) {
    fam <- families[[i]]
    link <- links[[i]]
    if (fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
      stop(
        "engine = 'julia': response-scale ordinal predictions are not routed ",
        "yet; use `type = \"link\"`.",
        call. = FALSE
      )
    }
    out[i, ] <- switch(
      link,
      IdentityLink = eta[i, ],
      LogLink = exp(eta[i, ]),
      LogitLink = stats::plogis(eta[i, ]),
      ProbitLink = stats::pnorm(eta[i, ]),
      stop(
        "engine = 'julia': unsupported prediction link '",
        link,
        "'.",
        call. = FALSE
      )
    )
  }
  out
}

.gllvm_julia_default_link <- function(family) {
  switch(
    family,
    gaussian = "IdentityLink",
    poisson = "LogLink",
    binomial = "LogitLink",
    negbinomial = "LogLink",
    nb1 = "LogLink",
    beta = "LogitLink",
    gamma = "LogLink",
    ordinal = "ProbitLink",
    ordinal_probit = "ProbitLink",
    NA_character_
  )
}

.gllvm_julia_prediction_frame <- function(mat) {
  out <- as.data.frame(as.table(mat), stringsAsFactors = FALSE)
  names(out) <- c("trait", "unit", "est")
  out
}

.gllvm_julia_family_vector <- function(object, p) {
  families <- object$families %||%
    object$bridge_input$family %||%
    object$family %||%
    character()
  families <- .gllvm_julia_as_vector(families, "character")
  if (length(families) == 1L && p > 1L) {
    families <- rep(families, p)
  }
  if (length(families) != p) {
    stop(
      "engine = 'julia': family payload length does not match traits.",
      call. = FALSE
    )
  }
  families
}

.gllvm_julia_response_mask <- function(object, p, n) {
  mask <- object$response_mask %||% object$bridge_input$mask %||% NULL
  if (is.null(mask)) {
    return(matrix(TRUE, nrow = p, ncol = n))
  }
  mask <- as.matrix(mask)
  if (!identical(dim(mask), c(p, n))) {
    stop(
      "engine = 'julia': response-mask payload dimensions do not match the fit.",
      call. = FALSE
    )
  }
  storage.mode(mask) <- "logical"
  mask
}

.gllvm_julia_trials_matrix <- function(object, p, n) {
  trials <- object$bridge_input$N %||% NULL
  if (is.null(trials)) {
    return(matrix(1, nrow = p, ncol = n))
  }
  if (length(trials) == 1L) {
    out <- matrix(as.numeric(trials), nrow = p, ncol = n)
  } else {
    out <- as.matrix(trials)
    if (identical(dim(out), c(n, p))) {
      out <- t(out)
    }
  }
  if (!identical(dim(out), c(p, n))) {
    stop(
      "engine = 'julia': binomial trial-count payload dimensions do not ",
      "match the fit.",
      call. = FALSE
    )
  }
  storage.mode(out) <- "numeric"
  if (any(!is.finite(out) | out <= 0)) {
    stop(
      "engine = 'julia': binomial trial counts must be positive and finite.",
      call. = FALSE
    )
  }
  out
}

.gllvm_julia_dispersion_vector <- function(object, p) {
  dispersion <- object$dispersion_engine %||% object$dispersion %||% NA_real_
  dispersion <- as.numeric(dispersion)
  if (length(dispersion) == 1L && p > 1L) {
    dispersion <- rep(dispersion, p)
  }
  if (length(dispersion) != p) {
    dispersion <- rep(NA_real_, p)
  }
  dispersion
}

.gllvm_julia_residual_variance <- function(object, families, mu) {
  p <- nrow(mu)
  n <- ncol(mu)
  dispersion <- .gllvm_julia_dispersion_vector(object, p)
  var <- matrix(NA_real_, nrow = p, ncol = n, dimnames = dimnames(mu))
  for (i in seq_len(p)) {
    fam <- families[[i]]
    var[i, ] <- switch(
      fam,
      gaussian = {
        sigma <- as.numeric(object$sigma_eps %||% NA_real_)[1L]
        if (!is.finite(sigma) || sigma <= 0) {
          stop(
            "engine = 'julia': Gaussian Pearson residuals need a positive ",
            "`sigma_eps` payload.",
            call. = FALSE
          )
        }
        rep(sigma^2, n)
      },
      poisson = mu[i, ],
      binomial = {
        trials <- .gllvm_julia_trials_matrix(object, p, n)
        mu[i, ] * (1 - mu[i, ]) / trials[i, ]
      },
      negbinomial = {
        size <- dispersion[[i]]
        if (!is.finite(size) || size <= 0) {
          stop(
            "engine = 'julia': NB2 Pearson residuals need positive ",
            "per-trait `r` dispersion.",
            call. = FALSE
          )
        }
        mu[i, ] + mu[i, ]^2 / size
      },
      nb1 = {
        phi <- dispersion[[i]]
        if (!is.finite(phi) || phi <= 0) {
          stop(
            "engine = 'julia': NB1 Pearson residuals need positive ",
            "per-trait `phi` dispersion.",
            call. = FALSE
          )
        }
        mu[i, ] * (1 + phi)
      },
      beta = {
        phi <- dispersion[[i]]
        if (!is.finite(phi) || phi <= 0) {
          stop(
            "engine = 'julia': Beta Pearson residuals need positive ",
            "per-trait `phi` dispersion.",
            call. = FALSE
          )
        }
        mu[i, ] * (1 - mu[i, ]) / (phi + 1)
      },
      gamma = {
        alpha <- dispersion[[i]]
        if (!is.finite(alpha) || alpha <= 0) {
          stop(
            "engine = 'julia': Gamma Pearson residuals need positive ",
            "shape dispersion.",
            call. = FALSE
          )
        }
        mu[i, ]^2 / alpha
      },
      stop(
        "engine = 'julia': response/Pearson residuals are not routed for ",
        "family '",
        fam,
        "'.",
        call. = FALSE
      )
    )
  }
  if (any(!is.finite(var) | var <= 0, na.rm = TRUE)) {
    stop(
      "engine = 'julia': residual variance contains non-positive or ",
      "non-finite entries.",
      call. = FALSE
    )
  }
  var
}

.gllvm_julia_observed_response <- function(object, families, y) {
  out <- y
  binomial_rows <- families == "binomial"
  if (any(binomial_rows)) {
    trials <- .gllvm_julia_trials_matrix(object, nrow(y), ncol(y))
    out[binomial_rows, ] <- y[binomial_rows, , drop = FALSE] /
      trials[binomial_rows, , drop = FALSE]
  }
  out
}

.gllvm_julia_print_matrix <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0L) {
    return(invisible(NULL))
  }
  print(round(x, digits))
  invisible(x)
}

#' Fit a GLLVM with the Julia engine (GLLVM.jl `bridge_fit`).
#'
#' @param y Response matrix, p x n (traits x units), or n x p (set `units_are_rows`).
#' @param family A family object/string, or a list of them (one per trait -> mixed).
#' @param num.lv Number of latent variables (K).
#' @param N Binomial trials (matrix or scalar), or `NULL`.
#' @param X Fixed-effect design (p x n x q array), or `NULL`. Routed for
#'   Gaussian and selected one-part non-Gaussian bridge families.
#' @param mask Optional logical response-observation mask with the same orientation
#'   as `y`; `TRUE` cells contribute to the likelihood and `FALSE` cells are
#'   ignored. Currently routed for one-part no-X non-Gaussian point fits only.
#' @param units_are_rows If `TRUE`, `y` is n x p and is transposed to p x n.
#' @param ci_method Confidence-interval route for no-X Gaussian, Poisson, and
#'   Bernoulli binomial bridge rows. One of `"none"` (default), `"wald"`,
#'   `"profile"`, or `"bootstrap"`. Grouped-dispersion rows, per-trait ordinal
#'   rows, response masks, mixed-family vectors, and fixed-effect-X rows remain
#'   loud gates.
#' @param ci_level Nominal confidence level when `ci_method != "none"`.
#' @param ci_nboot Number of parametric bootstrap replicates when
#'   `ci_method = "bootstrap"`.
#' @param ci_seed Seed passed to the Julia bootstrap CI route.
#' @param ... Passed to [gllvm_julia_setup()] (`jl_path`, `julia_home`).
#' @return A list of class `gllvmTMB_julia` with the bridge contract fields
#'   (`loadings`, `Sigma`, `correlation`, `loglik`, `aic`, `bic`,
#'   `converged`, ...). If `ci_method != "none"` and the row is admitted, the
#'   list also carries flat CI fields consumed by `confint()`.
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
  ci_level = 0.95,
  ci_nboot = 200L,
  ci_seed = 0L,
  ...
) {
  ci_method <- match.arg(ci_method)
  setup_args <- list(...)
  if (
    !is.numeric(ci_level) ||
      length(ci_level) != 1L ||
      !is.finite(ci_level) ||
      ci_level <= 0 ||
      ci_level >= 1
  ) {
    stop(
      "engine = 'julia': `ci_level` must be a finite number between 0 and 1.",
      call. = FALSE
    )
  }
  if (
    !is.numeric(ci_nboot) ||
      length(ci_nboot) != 1L ||
      !is.finite(ci_nboot) ||
      ci_nboot < 1
  ) {
    stop(
      "engine = 'julia': `ci_nboot` must be a positive integer.",
      call. = FALSE
    )
  }
  if (!is.numeric(ci_seed) || length(ci_seed) != 1L || !is.finite(ci_seed)) {
    stop(
      "engine = 'julia': `ci_seed` must be one finite numeric seed.",
      call. = FALSE
    )
  }
  fam <- .gllvm_julia_family(family)
  if (ci_method != "none") {
    if (length(fam) != 1L) {
      stop(
        "engine = 'julia': confidence intervals for mixed-family vectors ",
        "are not routed yet. Use `ci_method = \"none\"` or engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (fam %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES) {
      stop(
        "engine = 'julia': confidence intervals for grouped-dispersion ",
        "bridge rows are not routed yet. Use `ci_method = \"none\"` or ",
        "engine = 'tmb'.",
        call. = FALSE
      )
    }
    if (fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
      stop(
        "engine = 'julia': confidence intervals for per-trait ordinal ",
        "bridge rows are not routed yet. Use `ci_method = \"none\"` or ",
        "engine = 'tmb'.",
        call. = FALSE
      )
    }
  }
  y <- as.matrix(y)
  if (isTRUE(units_are_rows)) {
    y <- t(y)
  }
  if (!is.null(mask)) {
    mask <- as.matrix(mask)
    if (isTRUE(units_are_rows)) {
      mask <- t(mask)
    }
    if (!identical(dim(mask), dim(y))) {
      stop(
        "engine = 'julia': `mask` must have the same dimensions as `y` ",
        "after applying `units_are_rows`.",
        call. = FALSE
      )
    }
    storage.mode(mask) <- "logical"
  }
  if (ci_method != "none" && !is.null(mask)) {
    stop(
      "engine = 'julia': confidence intervals for response-mask bridge ",
      "fits are not routed yet. Use `ci_method = \"none\"` or engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (ci_method != "none" && !is.null(X)) {
    stop(
      "engine = 'julia': confidence intervals for fixed-effect-X bridge ",
      "fits are not routed yet. Use `ci_method = \"none\"` or engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (any(fam %in% c("poisson", "binomial", "negbinomial", "nb1"))) {
    storage.mode(y) <- "integer"
  }
  args <- list("GLLVM.bridge_fit", y = y, family = fam, d = as.integer(num.lv))
  if (!is.null(rownames(y))) {
    args$trait_names <- rownames(y)
  }
  if (!is.null(colnames(y))) {
    args$unit_names <- colnames(y)
  }
  if (!is.null(N)) {
    args$N <- N
  }
  if (!is.null(X)) {
    args$X <- X
  }
  if (!is.null(mask)) {
    args$mask <- mask
  }
  if (ci_method != "none") {
    args$options <- list(
      ci_method = ci_method,
      ci_level = as.numeric(ci_level),
      ci_nboot = as.integer(ci_nboot),
      ci_seed = as.integer(ci_seed)
    )
  }
  do.call(gllvm_julia_setup, setup_args)
  res <- do.call(JuliaCall::julia_call, args)
  res <- .gllvm_julia_normalise_result(res)
  if (!is.null(X)) {
    x_names <- dimnames(X)[[3L]]
    if (!is.null(res$gamma) && length(res$gamma) == length(x_names)) {
      res$gamma <- .gllvm_julia_as_vector(res$gamma, "numeric")
      names(res$gamma) <- x_names
    }
    if (!is.null(res$mean_coef) && length(res$mean_coef) == length(x_names)) {
      res$mean_coef <- .gllvm_julia_as_vector(res$mean_coef, "numeric")
      names(res$mean_coef) <- x_names
    }
  }
  res$engine <- "julia"
  res$missing_response <- !is.null(mask) && any(!mask)
  res$bridge_input <- list(
    y = y,
    family = fam,
    num.lv = as.integer(num.lv),
    N = N,
    X = X,
    mask = mask,
    units_are_rows = FALSE,
    setup_args = setup_args
  )
  if (!is.null(mask)) {
    res$response_mask <- mask
  }
  class(res) <- c("gllvmTMB_julia", "list")
  res
}

#' Methods for Julia bridge fits
#'
#' Small S3 surface for fits returned by `gllvmTMB(..., engine = "julia")` or
#' [gllvm_julia_fit()]. These methods expose the flat bridge payload that has
#' already passed the R admission gates. They are point-estimate summaries:
#' prediction and ordinary response/Pearson residuals are in-sample
#' retained-payload reconstructions only, while simulation and extractor parity
#' remain separate bridge rows. Confidence intervals are routed only for
#' admitted no-X Gaussian, Poisson, and Bernoulli binomial rows.
#'
#' @param object,x A fit returned by `gllvmTMB(..., engine = "julia")` or
#'   [gllvm_julia_fit()].
#' @param parm Optional integer or character vector of CI terms for `confint()`.
#' @param newdata Unsupported for Julia bridge fits; current prediction methods
#'   return in-sample fitted values from the retained bridge payload.
#' @param type Prediction or residual scale. For `predict()` and `fitted()`,
#'   `"link"` returns the fitted linear predictor and `"response"` applies the
#'   inverse link for supported scalar-response families. Per-trait ordinal
#'   response probabilities/classes remain gated; ordinal prediction also needs
#'   a retained score payload and is currently link-scale only. For
#'   `residuals()`, `"response"` returns observed-minus-fitted residuals on the
#'   response scale and `"pearson"` divides by the family-specific standard
#'   deviation. Binomial rows use the observed proportion, `y / N`, on the
#'   response scale.
#' @param level Confidence level requested by `confint()`. Stored Julia bridge
#'   payloads can only be read at their stored level; post-fit requests recompute
#'   the admitted Julia CI payload at the requested level.
#' @param method CI route for `confint()`. `"stored"` reads an existing payload.
#'   `"wald"`, `"profile"`, and `"bootstrap"` recompute from retained bridge
#'   input for admitted no-X Gaussian, Poisson, and Bernoulli binomial rows. If
#'   omitted, `confint()` reads a stored payload when present and otherwise uses
#'   `"wald"` for current fits that retain their bridge input.
#' @param ci_nboot Number of parametric bootstrap replicates when
#'   `method = "bootstrap"`.
#' @param ci_seed Seed passed to the Julia bootstrap CI route.
#' @param digits Number of digits printed by summary methods.
#' @param ... Unused.
#' @return `logLik()` returns a `"logLik"` object. `coef()` returns a named list
#'   of available point-estimate components. `confint()` returns a conventional
#'   confidence-interval matrix for stored or recomputed Julia CI payloads.
#'   `predict()` returns an in-sample data frame with `trait`, `unit`, and `est`
#'   columns. `fitted()` returns the in-sample fitted matrix with traits in rows
#'   and units in columns. `residuals()` returns an in-sample residual matrix
#'   with the same shape as `fitted()` for scalar-response rows and keeps masked
#'   response cells as `NA`. `summary()` returns a list with header,
#'   coefficients, covariance, and status fields.
#' @name gllvmTMB_julia-methods
#' @export
logLik.gllvmTMB_julia <- function(object, ...) {
  val <- object$loglik
  attr(val, "df") <- object$df
  attr(val, "nobs") <- object$nobs
  class(val) <- "logLik"
  val
}

#' @rdname gllvmTMB_julia-methods
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

#' @rdname gllvmTMB_julia-methods
#' @export
coef.gllvmTMB_julia <- function(object, ...) {
  .gllvm_julia_coef_payload(object)
}

#' @rdname gllvmTMB_julia-methods
#' @export
predict.gllvmTMB_julia <- function(
  object,
  newdata = NULL,
  type = c("link", "response"),
  ...
) {
  type <- match.arg(type)
  if (!is.null(newdata)) {
    stop(
      "engine = 'julia': `newdata` prediction is not routed yet; current ",
      "`predict.gllvmTMB_julia()` returns in-sample fitted values only.",
      call. = FALSE
    )
  }
  eta <- .gllvm_julia_link_predictor(object)
  pred <- if (type == "link") {
    eta
  } else {
    .gllvm_julia_response_predictor(object, eta)
  }
  .gllvm_julia_prediction_frame(pred)
}

#' @rdname gllvmTMB_julia-methods
#' @export
fitted.gllvmTMB_julia <- function(
  object,
  type = c("response", "link"),
  ...
) {
  type <- match.arg(type)
  eta <- .gllvm_julia_link_predictor(object)
  if (type == "link") {
    return(eta)
  }
  .gllvm_julia_response_predictor(object, eta)
}

#' @rdname gllvmTMB_julia-methods
#' @export
residuals.gllvmTMB_julia <- function(
  object,
  type = c("response", "pearson"),
  ...
) {
  type <- match.arg(type)
  y <- .gllvm_julia_training_y(object)
  p <- nrow(y)
  n <- ncol(y)
  families <- .gllvm_julia_family_vector(object, p)
  if (length(unique(families)) > 1L) {
    stop(
      "engine = 'julia': mixed-family residuals are not routed yet; ",
      "use engine = 'tmb' or inspect fitted values directly.",
      call. = FALSE
    )
  }
  unsupported <- setdiff(unique(families), .GLLVM_JULIA_RESIDUAL_FAMILIES)
  if (length(unsupported)) {
    stop(
      "engine = 'julia': response/Pearson residuals are not routed for ",
      "family '",
      paste(unsupported, collapse = ", "),
      "'. Ordinal bridge fits currently expose link-scale fitted values only.",
      call. = FALSE
    )
  }
  mu <- fitted(object, type = "response")
  if (!identical(dim(mu), c(p, n))) {
    stop(
      "engine = 'julia': fitted-value dimensions do not match the retained ",
      "response payload.",
      call. = FALSE
    )
  }
  observed <- .gllvm_julia_observed_response(object, families, y)
  out <- observed - mu
  dimnames(out) <- dimnames(mu)
  mask <- .gllvm_julia_response_mask(object, p, n)
  out[!mask] <- NA_real_
  if (type == "response") {
    return(out)
  }
  var <- .gllvm_julia_residual_variance(object, families, mu)
  out <- out / sqrt(var)
  out[!mask] <- NA_real_
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
confint.gllvmTMB_julia <- function(
  object,
  parm,
  level = 0.95,
  method = c("stored", "wald", "profile", "bootstrap"),
  ci_nboot = 200L,
  ci_seed = 0L,
  ...
) {
  payload <- .gllvm_julia_ci_payload(object)
  if (missing(method)) {
    method <- if (is.null(payload) && !is.null(object$bridge_input)) {
      "wald"
    } else {
      "stored"
    }
  } else {
    method <- match.arg(method)
  }
  if (method != "stored") {
    object <- .gllvm_julia_refit_ci(
      object,
      method = method,
      level = level,
      ci_nboot = ci_nboot,
      ci_seed = ci_seed
    )
    payload <- .gllvm_julia_ci_payload(object)
  }
  if (is.null(payload)) {
    stop(
      "No Julia bridge CI payload is present; call `confint(..., ",
      "method = \"wald\")`, `\"profile\"`, or `\"bootstrap\"` on a current ",
      "`gllvmTMB(..., engine = \"julia\")` fit, or refit with ",
      "`gllvm_julia_fit(..., ci_method = \"wald\")` for admitted no-X ",
      "Gaussian, Poisson, or Bernoulli binomial rows.",
      call. = FALSE
    )
  }
  stored_level <- unique(payload$level)
  if (
    length(stored_level) == 1L &&
      is.finite(stored_level) &&
      !isTRUE(all.equal(level, stored_level))
  ) {
    stop(
      "Julia bridge CI payload was computed at level = ",
      stored_level,
      "; `confint()` cannot recompute a different level from the stored fit.",
      call. = FALSE
    )
  }
  if (!nrow(payload)) {
    note <- object$ci_note %||% "no CI endpoints were returned"
    stop("Julia bridge CI payload has no endpoints: ", note, call. = FALSE)
  }
  if (!missing(parm)) {
    if (is.numeric(parm)) {
      payload <- payload[parm, , drop = FALSE]
    } else {
      idx <- match(parm, payload$term)
      payload <- payload[idx, , drop = FALSE]
    }
  }
  out <- as.matrix(payload[, c("conf.low", "conf.high"), drop = FALSE])
  rownames(out) <- payload$term
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  attr(out, "ci_method") <- unique(payload$method)
  attr(out, "ci_status") <- unique(payload$status)
  attr(out, "ci_note") <- unique(payload$note)
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
summary.gllvmTMB_julia <- function(object, ...) {
  out <- list(
    header = list(
      engine = object$engine %||% "julia",
      family = object$family %||% NA_character_,
      families = object$families %||% object$family %||% NA_character_,
      model = object$model %||% NA_character_,
      d = object$d %||% NA_integer_,
      n_traits = object$n_traits %||% NA_integer_,
      n_units = object$n_units %||% NA_integer_,
      nobs = object$nobs %||% NA_integer_,
      df = object$df %||% NA_integer_,
      logLik = object$loglik %||% NA_real_,
      AIC = object$aic %||% NA_real_,
      BIC = object$bic %||% NA_real_,
      converged = object$converged %||% NA,
      message = object$message %||% NA_character_,
      missing_response = isTRUE(object$missing_response)
    ),
    coefficients = coef(object),
    covariance = list(
      Sigma = object$Sigma,
      correlation = object$correlation,
      communality = object$communality
    ),
    status = list(
      partial = TRUE,
      note = object$note %||% "",
      ci_status = object$ci_status %||% NULL,
      ci_method = object$ci_method %||% NULL,
      ci_level = object$ci_level %||% NULL,
      ci_note = object$ci_note %||% NULL
    )
  )
  class(out) <- "summary.gllvmTMB_julia"
  out
}

#' @rdname gllvmTMB_julia-methods
#' @export
print.summary.gllvmTMB_julia <- function(x, digits = 3, ...) {
  h <- x$header
  cat("gllvmTMB Julia bridge summary\n")
  cat(sprintf(
    "  family: %s | model: %s | K = %d | %d traits x %d units\n",
    paste(unique(h$families), collapse = ","),
    h$model,
    h$d,
    h$n_traits,
    h$n_units
  ))
  cat(sprintf(
    "  logLik = %.4f | df = %d | nobs = %d | AIC = %.2f | BIC = %.2f\n",
    h$logLik,
    h$df,
    h$nobs,
    h$AIC,
    h$BIC
  ))
  cat(sprintf(
    "  converged = %s | missing response mask = %s\n",
    h$converged,
    h$missing_response
  ))

  co <- x$coefficients
  if (!is.null(co$alpha)) {
    cat("\nTrait intercept / mean parameter:\n")
    alpha <- data.frame(
      trait = names(co$alpha) %||% paste0("trait", seq_along(co$alpha)),
      alpha = as.numeric(co$alpha),
      row.names = NULL
    )
    alpha$alpha <- round(alpha$alpha, digits)
    print(alpha, row.names = FALSE)
  }
  if (!is.null(co$loadings) && length(co$loadings) > 0L) {
    cat("\nLoadings:\n")
    .gllvm_julia_print_matrix(co$loadings, digits)
  }
  if (!is.null(co$dispersion)) {
    cat("\nDispersion (engine scale):\n")
    .gllvm_julia_print_matrix(as.matrix(co$dispersion), digits)
  }
  if (!is.null(co$dispersion_public)) {
    cat("\nDispersion (public scale):\n")
    .gllvm_julia_print_matrix(as.matrix(co$dispersion_public), digits)
    note <- x$status$note
    if (!is.null(note) && nzchar(note)) cat("  Note:", note, "\n")
  }
  if (!is.null(co$cutpoints)) {
    cat("\nOrdinal cutpoints:\n")
    .gllvm_julia_print_matrix(co$cutpoints, digits)
  }
  if (!is.null(x$covariance$correlation)) {
    cat("\nTrait correlation:\n")
    .gllvm_julia_print_matrix(x$covariance$correlation, digits)
  }
  invisible(x)
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
  call = NULL
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
    0L
  }

  ## --- response: pivot long (trait, unit) -> a p x n matrix ---
  mf <- stats::model.frame(
    parsed$fixed,
    data = data,
    na.action = stats::na.pass
  )
  yraw <- stats::model.response(mf)
  if (is.matrix(yraw) && ncol(yraw) == 2L) {
    stop(
      "engine = 'julia' does not yet support cbind(successes, failures) ",
      "binomial responses; use a 0/1 Bernoulli response or engine = 'tmb'.",
      call. = FALSE
    )
  }
  yv <- as.numeric(yraw)
  ft <- factor(data[[trait]])
  fu <- factor(data[[unit_internal]])
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
  fam_str <- .gllvm_julia_family(family)
  Y <- matrix(NA_real_, p, n, dimnames = list(traits, units))
  Y[cbind(as.integer(ft), as.integer(fu))] <- yv
  response_mask <- !is.na(Y)
  has_missing_response <- any(!response_mask)

  ## --- fixed effects: the per-trait intercept (0 + trait) is always mapped to
  ## the bridge's internal per-trait intercept. Extra fixed-effect covariates
  ## (e.g. `env`) are mapped for admitted X families by pivoting the long
  ## design matrix into a p x n x q array X and passing it to bridge_fit. The
  ## Julia Gaussian fitter carries the full mean structure. The non-Gaussian
  ## covariate fitter already has per-trait intercepts, so R sends only the
  ## fixed-effect columns beyond the canonical `0 + trait` intercept block. ---
  Xfix <- stats::model.matrix(parsed$fixed, mf)
  trait_dummies <- paste0(trait, traits)
  extra_cols <- setdiff(colnames(Xfix), trait_dummies)
  has_only_trait_intercept <- (length(extra_cols) == 0 && ncol(Xfix) == p)
  if (has_missing_response && !has_only_trait_intercept) {
    stop(
      "engine = 'julia' does not yet route response masks with fixed-effect ",
      "covariates. Use a complete response table or engine = 'tmb'.",
      call. = FALSE
    )
  }
  if (has_missing_response) {
    Y <- .gllvm_julia_fill_masked_response(Y, fam_str, response_mask)
  }

  Xarg <- NULL
  if (!has_only_trait_intercept) {
    if (length(fam_str) != 1L || !(fam_str %in% .GLLVM_JULIA_X_FAMILIES)) {
      stop(
        "engine = 'julia' maps fixed-effect covariates for ",
        paste(.GLLVM_JULIA_X_FAMILIES, collapse = ", "),
        " complete one-part rows only; found fixed term(s): ",
        paste(
          c(
            extra_cols,
            if (ncol(Xfix) != p && length(extra_cols) == 0) {
              "(non-per-trait-intercept design)"
            }
          ),
          collapse = ", "
        ),
        ". Use engine = 'tmb' for this fixed-effect design.",
        call. = FALSE
      )
    }
    if (fam_str != "gaussian" && !all(trait_dummies %in% colnames(Xfix))) {
      stop(
        "engine = 'julia' fixed-effect covariates for non-Gaussian rows ",
        "currently require the canonical `0 + trait + ...` design so the ",
        "Julia bridge can use its internal per-trait intercepts. Use ",
        "`0 + trait` or engine = 'tmb'.",
        call. = FALSE
      )
    }
    ## Pivot the long (N = p*n row) design matrix into a p x n x q array. For each
    ## long row i with (trait ft[i], unit fu[i]), Xarg[ft[i], fu[i], k] = Xfix[i, k].
    ## Gaussian keeps the full model matrix. Non-Gaussian rows drop the trait
    ## dummy columns because GLLVM.jl's covariate fitter estimates those as beta_cov.
    x_cols <- if (fam_str == "gaussian") colnames(Xfix) else extra_cols
    q <- length(x_cols)
    Xarg <- array(0, dim = c(p, n, q), dimnames = list(traits, units, x_cols))
    Xbridge <- Xfix[, x_cols, drop = FALSE]
    idx3 <- cbind(
      rep(as.integer(ft), times = q),
      rep(as.integer(fu), times = q),
      rep(seq_len(q), each = length(yv))
    )
    Xarg[idx3] <- as.numeric(Xbridge)
  }

  ## --- binomial trials: pivot per-row n_trials (weights API) else Bernoulli ---
  Narg <- NULL
  if (any(fam_str == "binomial")) {
    if (
      !is.null(weights) && is.numeric(weights) && length(weights) == length(yv)
    ) {
      Narg <- matrix(1, p, n)
      Narg[cbind(as.integer(ft), as.integer(fu))] <- as.numeric(weights)
    } else {
      Narg <- 1L
    }
  }

  fit <- gllvm_julia_fit(
    Y,
    family = family,
    num.lv = K,
    N = Narg,
    X = Xarg,
    mask = if (has_missing_response) response_mask else NULL
  )
  fit$call <- call
  fit$trait_levels <- traits
  fit$unit_levels <- units
  fit$missing_response <- has_missing_response
  if (has_missing_response) {
    fit$response_mask <- response_mask
  }
  fit
}
