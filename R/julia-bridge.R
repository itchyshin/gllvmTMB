# ---------------------------------------------------------------------------
# R -> Julia bridge: run the experimental GLLVM.jl bridge fitting path from R.
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
  "binomial",
  "negbinomial",
  "nb1",
  "beta",
  "gamma"
)
.GLLVM_JULIA_PREDICT_FAMILIES <- c(
  .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES,
  .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
)
.GLLVM_JULIA_RESIDUAL_FAMILIES <- .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES
.GLLVM_JULIA_SIMULATE_FAMILIES <- .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES
.GLLVM_JULIA_ORDINATION_FAMILIES <- .GLLVM_JULIA_BRIDGE_FAMILIES
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
  .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
)
.GLLVM_JULIA_MASK_CI_FAMILIES <- setdiff(
  .GLLVM_JULIA_MASK_FAMILIES,
  .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
)
.GLLVM_JULIA_X_CI_FAMILIES <- .GLLVM_JULIA_X_FAMILIES
.GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS <- c(
  "fit_no_x",
  "fixed_effect_X",
  "missing_response",
  "cbind_binomial",
  "ci_no_x_wald",
  "ci_no_x_profile",
  "ci_no_x_bootstrap",
  "ci_mask_wald",
  "ci_mask_profile",
  "ci_mask_bootstrap",
  "ci_x_wald",
  "ci_x_profile",
  "ci_x_bootstrap",
  "postfit_coef",
  "postfit_fit_stats",
  "postfit_summary",
  "postfit_predict",
  "postfit_residuals",
  "postfit_simulate",
  "postfit_ordination"
)

.gllvm_julia_gate_registry <- function() {
  data.frame(
    gate_id = c(
      "GJL-GATE-FAMILY",
      "GJL-GATE-MIXED-CI",
      "GJL-GATE-ORDINAL-CI",
      "GJL-GATE-MASK-X-CI",
      "GJL-GATE-X-CI",
      "GJL-GATE-NEWDATA-PREDICT",
      "GJL-GATE-PROB-CLASS-NONORDINAL",
      "GJL-GATE-ORDINAL-RESIDUAL",
      "GJL-GATE-NEWDATA-SIMULATE",
      "GJL-GATE-UNCONDITIONAL-SIMULATE",
      "GJL-GATE-ORDINAL-SIMULATE",
      "GJL-GATE-NO-CI-PAYLOAD",
      "GJL-GATE-CORRELATION-INTERVALS",
      "GJL-GATE-STRUCTURED-TERMS",
      "GJL-GATE-MULTI-RR",
      "GJL-GATE-MASK-X",
      "GJL-GATE-X-FAMILY",
      "GJL-GATE-X-DESIGN"
    ),
    status = "gated",
    source = c(
      "family mapping",
      "direct wrapper CI",
      "direct wrapper CI",
      "direct wrapper CI",
      "direct wrapper CI",
      "postfit prediction",
      "postfit prediction",
      "postfit residuals",
      "postfit simulation",
      "postfit simulation",
      "postfit simulation",
      "postfit confint",
      "correlation extractor",
      "main dispatch",
      "main dispatch",
      "main dispatch",
      "main dispatch",
      "main dispatch"
    ),
    reason = c(
      "R bridge lacks payload labels, scale maps, or tests for the family.",
      "Mixed-family CI/status payloads are not specified.",
      "Per-trait ordinal CI endpoints are not routed.",
      "Masks combined with fixed-effect X have no CI/status contract.",
      "Fixed-effect-X CI endpoints are admitted for a smaller family set.",
      "Only retained in-sample score/fitted payloads are routed.",
      "Probability/class output is ordinal-only.",
      "Ordinal residual semantics are not specified.",
      "Only retained in-sample fitted payloads are simulated.",
      "Unconditional random-effect redraws are not routed.",
      "Ordinal simulation semantics are not specified.",
      "The object has no stored or recomputable CI payload.",
      "Correlation interval helpers need endpoint/status semantics.",
      "Structured covariance terms need Julia structured-fit payloads.",
      "Multiple reduced-rank latent blocks are not routed.",
      "Response masks plus fixed-effect X are not routed.",
      "Fixed-effect X is admitted for complete one-part rows only.",
      "Non-Gaussian X rows require the canonical 0 + trait design."
    ),
    representative_test = "tests/testthat/test-julia-bridge.R",
    issue = "gllvmTMB#488",
    validation_row = c(
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01A",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01",
      "JUL-01"
    ),
    stringsAsFactors = FALSE
  )
}

#' Current R-side gate registry for the Julia bridge
#'
#' `gllvm_julia_gate_registry()` reports the deliberate `engine = "julia"`
#' refusals that are part of the R bridge contract. It is a read-only audit
#' table for interpreting `GJL-GATE-*` error IDs; it does not widen the bridge
#' or load Julia.
#'
#' @return A data frame with gate id, status, source, reason, representative
#'   test file, GitHub issue, and validation-row linkage. Rows with
#'   `validation_row = "JUL-01"` belong to the lean bridge admission surface;
#'   rows with `validation_row = "JUL-01A"` belong to raw unit-tier
#'   covariance/extractor boundaries.
#' @examples
#' head(gllvm_julia_gate_registry())
#' @export
gllvm_julia_gate_registry <- function() {
  .gllvm_julia_gate_registry()
}

.gllvm_julia_gate_message <- function(gate_id, ...) {
  registry <- .gllvm_julia_gate_registry()
  if (!gate_id %in% registry$gate_id) {
    stop("Unknown Julia bridge gate id: ", gate_id, call. = FALSE)
  }
  paste0("[", gate_id, "] ", paste0(...))
}

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
#'   transport, no-X CI, masked no-X CI, complete-response fixed-effect-X CI,
#'   and post-fit cells. CI columns are deliberately scoped: `ci_no_x_*` does
#'   not imply masked, mixed-family, or fixed-effect-X intervals; `ci_mask_*`
#'   covers only no-X response-mask rows; and `ci_x_*` covers only
#'   complete-response fixed-effect-X rows. `status` is `"partial"` for every
#'   current row, with the boundary recorded in `notes`.
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
    cbind_binomial = families == "binomial",
    ci_no_x_wald = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_profile = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_bootstrap = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_mask_wald = families %in% .GLLVM_JULIA_MASK_CI_FAMILIES,
    ci_mask_profile = families %in% .GLLVM_JULIA_MASK_CI_FAMILIES,
    ci_mask_bootstrap = families %in% .GLLVM_JULIA_MASK_CI_FAMILIES,
    ci_x_wald = families %in% .GLLVM_JULIA_X_CI_FAMILIES,
    ci_x_profile = families %in% .GLLVM_JULIA_X_CI_FAMILIES,
    ci_x_bootstrap = families %in% .GLLVM_JULIA_X_CI_FAMILIES,
    postfit_coef = TRUE,
    postfit_fit_stats = TRUE,
    postfit_summary = TRUE,
    postfit_predict = families %in% .GLLVM_JULIA_PREDICT_FAMILIES,
    postfit_residuals = families %in% .GLLVM_JULIA_RESIDUAL_FAMILIES,
    postfit_simulate = families %in% .GLLVM_JULIA_SIMULATE_FAMILIES,
    postfit_ordination = families %in% .GLLVM_JULIA_ORDINATION_FAMILIES,
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
    ci_mask_wald = FALSE,
    ci_mask_profile = FALSE,
    ci_mask_bootstrap = FALSE,
    ci_x_wald = FALSE,
    ci_x_profile = FALSE,
    ci_x_bootstrap = FALSE,
    postfit_coef = TRUE,
    postfit_fit_stats = TRUE,
    postfit_summary = TRUE,
    postfit_predict = TRUE,
    postfit_residuals = TRUE,
    postfit_simulate = TRUE,
    postfit_ordination = TRUE,
    status = "partial",
    notes = paste(
      "complete balanced no-X/no-mask/no-CI mixed-family route;",
      "coef(), summary(), in-sample predict()/fitted(),",
      "response/Pearson residuals, conditional simulate(), and raw unit-tier",
      "covariance/ordination accessors are routed from retained payloads;",
      "CI, masks, fixed-effect X, newdata, and richer extractor parity remain gated;",
      "component families:",
      paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", ")
    ),
    stringsAsFactors = FALSE
  )
  rbind(out, mixed)
}

.gllvm_julia_capabilities_df <- function(caps, source = "capability surface") {
  out <- if (is.data.frame(caps)) {
    caps
  } else if (is.list(caps)) {
    as.data.frame(unclass(caps), stringsAsFactors = FALSE)
  } else {
    as.data.frame(caps, stringsAsFactors = FALSE)
  }
  required <- c(
    "family",
    .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS,
    "status",
    "notes"
  )
  missing <- setdiff(required, names(out))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.arg {source}} is missing required bridge capability columns.",
      "x" = "Missing: {paste(missing, collapse = ', ')}"
    ))
  }
  out <- out[, required]
  out$family <- as.character(out$family)
  out$status <- as.character(out$status)
  out$notes <- as.character(out$notes)
  for (col in .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS) {
    out[[col]] <- as.logical(out[[col]])
  }
  out
}

.gllvm_julia_expected_capability_drifts <- function() {
  ## No registered drifts remain: the cbind(successes, failures) binomial route
  ## is now marshalled and parity-tested, so the R and engine capability
  ## surfaces agree. Keep returning the canonical 0-row frame so the drift
  ## matcher's `allowed$<col>[m]` lookups stay well-typed.
  data.frame(
    family = character(0),
    capability = character(0),
    direction = character(0),
    gate_id = character(0),
    issue = character(0),
    validation_row = character(0),
    reason = character(0),
    stringsAsFactors = FALSE
  )
}

.gllvm_julia_capability_drift <- function(
  r_caps = gllvm_julia_capabilities(),
  julia_caps
) {
  r_caps <- .gllvm_julia_capabilities_df(r_caps, source = "r_caps")
  julia_caps <- .gllvm_julia_capabilities_df(julia_caps, source = "julia_caps")
  rows <- list()
  families <- union(r_caps$family, julia_caps$family)
  for (family in families) {
    r_i <- match(family, r_caps$family)
    j_i <- match(family, julia_caps$family)
    if (is.na(r_i) || is.na(j_i)) {
      rows[[length(rows) + 1L]] <- data.frame(
        family = family,
        capability = "family",
        direction = if (is.na(r_i)) {
          "julia_broader_than_r"
        } else {
          "r_broader_than_julia"
        },
        stringsAsFactors = FALSE
      )
      next
    }
    for (capability in .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS) {
      r_value <- isTRUE(r_caps[[capability]][[r_i]])
      j_value <- isTRUE(julia_caps[[capability]][[j_i]])
      if (identical(r_value, j_value)) {
        next
      }
      rows[[length(rows) + 1L]] <- data.frame(
        family = family,
        capability = capability,
        direction = if (j_value) {
          "julia_broader_than_r"
        } else {
          "r_broader_than_julia"
        },
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    return(data.frame(
      family = character(0),
      capability = character(0),
      direction = character(0),
      status = character(0),
      gate_id = character(0),
      issue = character(0),
      validation_row = character(0),
      reason = character(0)
    ))
  }
  drift <- do.call(rbind, rows)
  allowed <- .gllvm_julia_expected_capability_drifts()
  drift_key <- paste(
    drift$family,
    drift$capability,
    drift$direction,
    sep = "\r"
  )
  allowed_key <- paste(
    allowed$family,
    allowed$capability,
    allowed$direction,
    sep = "\r"
  )
  m <- match(drift_key, allowed_key)
  drift$status <- ifelse(is.na(m), "unregistered", "gated")
  drift$gate_id <- ifelse(is.na(m), NA_character_, allowed$gate_id[m])
  drift$issue <- ifelse(is.na(m), NA_character_, allowed$issue[m])
  drift$validation_row <- ifelse(
    is.na(m),
    NA_character_,
    allowed$validation_row[m]
  )
  drift$reason <- ifelse(is.na(m), NA_character_, allowed$reason[m])
  drift
}

.gllvm_julia_capability_note <- function(family) {
  mask_clause <- if (family %in% .GLLVM_JULIA_MASK_CI_FAMILIES) {
    paste0(
      "response masks and masked no-X Wald/profile/bootstrap CI payloads ",
      "are routed; "
    )
  } else if (family %in% .GLLVM_JULIA_MASK_FAMILIES) {
    "response masks are routed for no-X point fits; ordinal masked CIs remain gated; "
  } else {
    "response masks remain gated; "
  }
  x_clause <- if (family %in% .GLLVM_JULIA_X_FAMILIES) {
    "fixed-effect X point fits are routed for complete responses; "
  } else {
    "fixed-effect X remains gated; "
  }
  x_ci_clause <- if (family %in% .GLLVM_JULIA_X_CI_FAMILIES) {
    paste0(
      "complete-response fixed-effect-X Wald/profile/bootstrap CI payloads ",
      "are routed; "
    )
  } else {
    ""
  }
  ci_x_followup <- if (family %in% .GLLVM_JULIA_X_CI_FAMILIES) {
    "native parity promotion remains a follow-up"
  } else if (family %in% .GLLVM_JULIA_CI_NO_X_FAMILIES) {
    "X, X-row CI, and native parity promotion are follow-ups"
  } else if (family %in% .GLLVM_JULIA_X_FAMILIES) {
    "no-X CI, X-row CI, and native parity promotion are follow-ups"
  } else {
    "CI, X, and native parity promotion are follow-ups"
  }
  ci_clause <- if (family %in% .GLLVM_JULIA_CI_NO_X_FAMILIES) {
    paste0(
      "direct gllvm_julia_fit() and gllvmTMB(..., engine = \"julia\") ",
      "complete-response no-X Wald/profile/bootstrap CI payloads are routed; ",
      "gllvmTMB() fits retain bridge input for post-fit confint() ",
      "recomputation; "
    )
  } else {
    ""
  }
  predict_clause <- if (family %in% .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES) {
    "in-sample predict()/fitted() are routed from retained score payloads; "
  } else if (family %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
    paste0(
      "in-sample ordinal link, probability, and modal-class predictions ",
      "are routed from retained score/cutpoint payloads; "
    )
  } else {
    paste0(
      "predict()/fitted() remain gated until retained score payloads ",
      "are admitted; "
    )
  }
  residual_clause <- if (family %in% .GLLVM_JULIA_RESIDUAL_FAMILIES) {
    paste0(
      "in-sample response/Pearson residuals are routed from retained ",
      "fitted values; "
    )
  } else {
    "response/Pearson residuals remain gated; "
  }
  simulate_clause <- if (family %in% .GLLVM_JULIA_SIMULATE_FAMILIES) {
    "in-sample conditional simulate() is routed from fitted values; "
  } else {
    "simulate() remains gated; "
  }
  extractor_clause <- if (family %in% .GLLVM_JULIA_ORDINATION_FAMILIES) {
    paste0(
      "unit-tier covariance honors native link_residual scale semantics and ",
      "raw ordination accessors are routed; richer extractor parity remains ",
      "gated; "
    )
  } else {
    "extractor parity remains gated; "
  }
  postfit_clause <- if (family %in% .GLLVM_JULIA_CI_NO_X_FAMILIES) {
    paste0(
      "coef(), summary(), and no-X confint() are routed; ",
      predict_clause,
      residual_clause,
      simulate_clause,
      extractor_clause
    )
  } else {
    paste0(
      "coef() and summary() are routed; ",
      predict_clause,
      "confint() remains gated until CI endpoints are admitted; ",
      residual_clause,
      simulate_clause,
      extractor_clause
    )
  }
  if (family %in% .GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES) {
    return(paste0(
      "single reduced-rank point route; default no-X Julia payload uses ",
      "per-trait grouped dispersion; ",
      mask_clause,
      x_clause,
      x_ci_clause,
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
      x_ci_clause,
      postfit_clause,
      ci_x_followup
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
    x_ci_clause,
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
        .gllvm_julia_gate_message(
          "GJL-GATE-FAMILY",
          "engine = 'julia': unsupported family '",
          fam,
          "'. Supported: gaussian, poisson, ",
          "binomial, nbinom2, nbinom1, beta, gamma, ordinal, ordinal_probit ",
          "(or a narrow list for mixed gaussian/poisson/binomial responses)."
        ),
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
  if (!is.null(object$mean_coef_status)) {
    out$mean_coef_status <- object$mean_coef_status
  }
  if (!is.null(object$beta_cov)) {
    out$beta_cov <- object$beta_cov
  }
  if (!is.null(object$gamma)) {
    out$gamma <- object$gamma
  }
  if (!is.null(object$gamma_status)) {
    out$gamma_status <- object$gamma_status
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

.gllvm_julia_unit_names <- function(object, n) {
  unit_names <- object$unit_names %||% character()
  unit_names <- .gllvm_julia_as_vector(unit_names, "character")
  if (length(unit_names) == n) {
    return(unit_names)
  }
  paste0("unit", seq_len(n))
}

.gllvm_julia_unit_count <- function(object) {
  if (!is.null(object$n_units)) {
    return(as.integer(object$n_units)[1L])
  }
  if (!is.null(object$unit_names)) {
    return(length(.gllvm_julia_as_vector(object$unit_names, "character")))
  }
  if (!is.null(object$scores)) {
    return(nrow(as.matrix(object$scores)))
  }
  0L
}

.gllvm_julia_extractor_family_check <- function(object, p, what) {
  families <- .gllvm_julia_family_vector(object, p)
  invisible(families)
}

.gllvm_julia_cov2cor <- function(Sigma, traits) {
  D <- sqrt(diag(Sigma))
  R <- if (all(is.finite(D)) && all(D > 0)) {
    Sigma / outer(D, D)
  } else {
    NA_real_ * Sigma
  }
  dimnames(R) <- list(traits, traits)
  R
}

.gllvm_julia_extract_sigma <- function(
  fit,
  level,
  part,
  link_residual,
  .skip_warn = FALSE
) {
  if (length(level) > 1L) {
    level <- match.arg(
      level,
      c(
        "unit",
        "unit_slope",
        "unit_obs",
        "phy",
        "phy_slope",
        "spatial",
        "spde_slope",
        "cluster",
        "cluster2",
        "B",
        "B_slope",
        "W",
        "spde"
      )
    )
  }
  level <- .normalise_level(level, arg_name = "level", .skip_warn = .skip_warn)
  part <- match.arg(part, c("total", "shared", "unique"))
  link_residual <- match.arg(link_residual, c("auto", "none"))

  if (level == "W") {
    return(NULL)
  }
  if (level != "B") {
    cli::cli_abort(c(
      "engine = 'julia': {.fn extract_Sigma} currently routes only the ordinary {.val unit} tier.",
      "i" = "Structured tiers, augmented slopes, and cluster tiers remain on the TMB engine path."
    ))
  }

  p <- .gllvm_julia_n_traits(fit)
  families <- .gllvm_julia_family_vector(fit, p)
  traits <- .gllvm_julia_trait_names(fit, p)

  loadings <- fit$loadings %||% matrix(numeric(), nrow = p, ncol = 0L)
  loadings <- as.matrix(loadings)
  storage.mode(loadings) <- "numeric"
  if (nrow(loadings) != p) {
    cli::cli_abort(
      "engine = 'julia': loading payload row count does not match traits."
    )
  }
  shared <- loadings %*% t(loadings)
  shared <- (shared + t(shared)) / 2
  dimnames(shared) <- list(traits, traits)

  retained_sigma <- fit$Sigma %||% NULL
  has_retained_sigma <- !is.null(retained_sigma)
  if (is.null(retained_sigma)) {
    retained_sigma <- shared
  } else {
    retained_sigma <- as.matrix(retained_sigma)
    storage.mode(retained_sigma) <- "numeric"
    if (!identical(dim(retained_sigma), c(p, p))) {
      cli::cli_abort(
        "engine = 'julia': Sigma payload dimensions do not match traits."
      )
    }
    retained_sigma <- (retained_sigma + t(retained_sigma)) / 2
    dimnames(retained_sigma) <- list(traits, traits)
  }

  retained_R <- fit$correlation %||% NULL
  if (is.null(retained_R)) {
    retained_R <- .gllvm_julia_cov2cor(retained_sigma, traits)
  } else {
    retained_R <- as.matrix(retained_R)
    storage.mode(retained_R) <- "numeric"
    if (!identical(dim(retained_R), c(p, p))) {
      cli::cli_abort(
        "engine = 'julia': correlation payload dimensions do not match traits."
      )
    }
    dimnames(retained_R) <- list(traits, traits)
  }
  auto_sigma <- retained_sigma
  auto_R <- retained_R
  gaussian_noop <- families %in% c("gaussian", "lognormal")
  if (any(gaussian_noop)) {
    diag(auto_sigma)[gaussian_noop] <- diag(shared)[gaussian_noop]
    auto_R <- .gllvm_julia_cov2cor(auto_sigma, traits)
  }

  note <- c(
    "engine = 'julia': extract_Sigma() reports the ordinary unit tier only; unique(), unit_obs, and structured tiers are not present in this bridge row."
  )
  if (link_residual == "auto") {
    note <- c(
      note,
      if (has_retained_sigma) {
        "engine = 'julia': link_residual = 'auto' uses the retained GLLVM.jl Sigma/correlation payload on the engine-provided latent or link-residual scale."
      } else {
        "engine = 'julia': link_residual = 'auto' has no retained Sigma payload for this row, so the shared Lambda Lambda^T block is returned."
      }
    )
    if (any(gaussian_noop)) {
      note <- c(
        note,
        "engine = 'julia': Gaussian/lognormal rows follow gllvmTMB's native link-residual no-op, so retained response-scale residual diagonals are not added for those traits."
      )
    }
  } else {
    note <- c(
      note,
      "engine = 'julia': link_residual = 'none' returns Lambda Lambda^T from the retained loadings; any retained link-residual or response-scale diagonal in the raw Julia Sigma payload is not added."
    )
  }
  for (msg in note) {
    cli::cli_inform(msg)
  }

  if (part == "unique") {
    s <- setNames(rep(0, p), traits)
    return(list(s = s, level = "unit", part = "unique", note = note))
  }
  if (part == "shared") {
    return(list(Sigma = shared, level = "unit", part = "shared", note = note))
  }
  if (link_residual == "none") {
    R <- .gllvm_julia_cov2cor(shared, traits)
    return(list(
      Sigma = shared,
      R = R,
      level = "unit",
      part = "total",
      note = note
    ))
  }
  list(
    Sigma = auto_sigma,
    R = auto_R,
    level = "unit",
    part = "total",
    note = note
  )
}

.gllvm_julia_extract_ordination <- function(fit, level) {
  if (length(level) > 1L) {
    level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  }
  level <- .normalise_level(level, arg_name = "level", .skip_warn = TRUE)
  if (level == "W") {
    return(NULL)
  }
  if (level != "B") {
    cli::cli_abort(c(
      "engine = 'julia': {.fn extract_ordination} currently routes only the ordinary {.val unit} tier.",
      "i" = "Within-unit, structured-tier, and augmented-slope ordinations remain on the TMB engine path."
    ))
  }

  p <- .gllvm_julia_n_traits(fit)
  .gllvm_julia_extractor_family_check(fit, p, "ordination")
  n <- .gllvm_julia_unit_count(fit)
  traits <- .gllvm_julia_trait_names(fit, p)
  units <- .gllvm_julia_unit_names(fit, n)

  loadings <- fit$loadings %||% matrix(numeric(), nrow = p, ncol = 0L)
  loadings <- as.matrix(loadings)
  storage.mode(loadings) <- "numeric"
  if (nrow(loadings) != p) {
    cli::cli_abort(
      "engine = 'julia': loading payload row count does not match traits."
    )
  }
  if (ncol(loadings) == 0L) {
    return(NULL)
  }
  rownames(loadings) <- traits
  colnames(loadings) <- paste0("LV", seq_len(ncol(loadings)))

  scores <- fit$scores %||% NULL
  if (is.null(scores)) {
    cli::cli_abort(
      "engine = 'julia': raw ordination extraction needs a retained score payload."
    )
  }
  scores <- as.matrix(scores)
  storage.mode(scores) <- "numeric"
  if (
    nrow(scores) != n && ncol(scores) == n && nrow(scores) == ncol(loadings)
  ) {
    scores <- t(scores)
  }
  if (nrow(scores) != n) {
    cli::cli_abort(
      "engine = 'julia': score payload row count does not match units."
    )
  }
  if (ncol(scores) != ncol(loadings)) {
    cli::cli_abort(
      "engine = 'julia': loading and score payload dimensions do not match."
    )
  }
  rownames(scores) <- units
  colnames(scores) <- colnames(loadings)

  list(scores = scores, loadings = loadings, row_id = units)
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
        "engine = 'julia': ordinal predictions are category probabilities, ",
        "not scalar inverse-link means; use `predict(type = \"response\")` ",
        "or `fitted(type = \"prob\")`.",
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

.gllvm_julia_is_ordinal_fit <- function(object, p = NULL) {
  families <- object$families %||% object$family %||% character()
  families <- .gllvm_julia_as_vector(families, "character")
  if (!is.null(p) && length(families) == 1L && p > 1L) {
    families <- rep(families, p)
  }
  length(families) > 0L &&
    all(families %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES)
}

.gllvm_julia_ordinal_links <- function(object, p) {
  links <- object$link %||% object$cutpoint_link %||% character()
  links <- .gllvm_julia_as_vector(links, "character")
  if (!length(links) || all(is.na(links) | !nzchar(links))) {
    families <- object$families %||% object$family %||% "ordinal_probit"
    families <- .gllvm_julia_as_vector(families, "character")
    if (length(families) == 1L && p > 1L) {
      families <- rep(families, p)
    }
    links <- vapply(families, .gllvm_julia_default_link, character(1))
  }
  if (length(links) == 1L && p > 1L) {
    links <- rep(links, p)
  }
  if (length(links) != p) {
    stop(
      "engine = 'julia': ordinal link payload length does not match traits.",
      call. = FALSE
    )
  }
  links
}

.gllvm_julia_ordinal_cdf <- function(x, link) {
  switch(
    link,
    LogitLink = stats::plogis(x),
    ProbitLink = stats::pnorm(x),
    stop(
      "engine = 'julia': unsupported ordinal prediction link '",
      link,
      "'.",
      call. = FALSE
    )
  )
}

.gllvm_julia_ordinal_probabilities <- function(object, eta) {
  p <- nrow(eta)
  n <- ncol(eta)
  if (!.gllvm_julia_is_ordinal_fit(object, p)) {
    stop(
      "engine = 'julia': ordinal probability prediction needs an ordinal ",
      "bridge fit.",
      call. = FALSE
    )
  }
  cutpoints <- object$cutpoints %||% NULL
  n_categories <- object$n_categories %||% NULL
  if (is.null(cutpoints) || is.null(n_categories)) {
    stop(
      "engine = 'julia': ordinal probability prediction needs retained ",
      "cutpoint and category-count payloads.",
      call. = FALSE
    )
  }
  cutpoints <- as.matrix(cutpoints)
  storage.mode(cutpoints) <- "numeric"
  n_categories <- as.integer(n_categories)
  if (nrow(cutpoints) != p || length(n_categories) != p) {
    stop(
      "engine = 'julia': ordinal cutpoint/category payload dimensions do ",
      "not match fitted values.",
      call. = FALSE
    )
  }
  if (any(n_categories < 2L)) {
    stop(
      "engine = 'julia': ordinal category counts must be at least 2.",
      call. = FALSE
    )
  }
  links <- .gllvm_julia_ordinal_links(object, p)
  max_category <- max(n_categories)
  out <- array(
    NA_real_,
    dim = c(p, n, max_category),
    dimnames = list(
      rownames(eta) %||% paste0("trait", seq_len(p)),
      colnames(eta) %||% paste0("unit", seq_len(n)),
      as.character(seq_len(max_category))
    )
  )
  for (i in seq_len(p)) {
    ncat <- n_categories[[i]]
    tau <- cutpoints[i, seq_len(ncat - 1L), drop = TRUE]
    if (any(!is.finite(tau)) || (length(tau) > 1L && any(diff(tau) <= 0))) {
      stop(
        "engine = 'julia': ordinal cutpoints must be finite and ordered by ",
        "trait for probability prediction.",
        call. = FALSE
      )
    }
    for (j in seq_len(n)) {
      eta_ij <- eta[i, j]
      prob <- numeric(ncat)
      for (category in seq_len(ncat)) {
        upper <- if (category == ncat) {
          1
        } else {
          .gllvm_julia_ordinal_cdf(tau[[category]] - eta_ij, links[[i]])
        }
        lower <- if (category == 1L) {
          0
        } else {
          .gllvm_julia_ordinal_cdf(tau[[category - 1L]] - eta_ij, links[[i]])
        }
        prob[[category]] <- upper - lower
      }
      prob <- pmax(prob, 0)
      total <- sum(prob)
      if (is.finite(total) && total > 0) {
        prob <- prob / total
      } else {
        prob[] <- NA_real_
      }
      out[i, j, seq_len(ncat)] <- prob
    }
  }
  out
}

.gllvm_julia_ordinal_modal_class <- function(prob) {
  out <- apply(prob, c(1L, 2L), function(x) {
    if (all(is.na(x))) {
      return(NA_integer_)
    }
    which.max(replace(x, is.na(x), -Inf))
  })
  dimnames(out) <- dimnames(prob)[1:2]
  out
}

.gllvm_julia_ordinal_probability_frame <- function(prob) {
  idx <- which(!is.na(prob), arr.ind = TRUE)
  data.frame(
    trait = dimnames(prob)[[1L]][idx[, 1L]],
    unit = dimnames(prob)[[2L]][idx[, 2L]],
    category = as.integer(dimnames(prob)[[3L]][idx[, 3L]]),
    prob = prob[idx],
    row.names = NULL,
    stringsAsFactors = FALSE
  )
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
    ordinal = "LogitLink",
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
          sigma <- dispersion[[i]]
        }
        if (!is.finite(sigma) || sigma <= 0) {
          stop(
            "engine = 'julia': Gaussian Pearson residuals need a positive ",
            "`sigma_eps` or per-trait mixed-family dispersion payload.",
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

.gllvm_julia_simulation_draw <- function(object, families, mu) {
  p <- nrow(mu)
  n <- ncol(mu)
  dispersion <- .gllvm_julia_dispersion_vector(object, p)
  trials <- if (any(families == "binomial")) {
    .gllvm_julia_trials_matrix(object, p, n)
  } else {
    NULL
  }
  out <- matrix(NA_real_, nrow = p, ncol = n, dimnames = dimnames(mu))
  for (i in seq_len(p)) {
    fam <- families[[i]]
    m <- mu[i, ]
    out[i, ] <- switch(
      fam,
      gaussian = {
        sigma <- as.numeric(object$sigma_eps %||% NA_real_)[1L]
        if (!is.finite(sigma) || sigma <= 0) {
          sigma <- dispersion[[i]]
        }
        if (!is.finite(sigma) || sigma <= 0) {
          stop(
            "engine = 'julia': Gaussian simulate() needs a positive ",
            "`sigma_eps` or per-trait mixed-family dispersion payload.",
            call. = FALSE
          )
        }
        stats::rnorm(n, mean = m, sd = sigma)
      },
      poisson = stats::rpois(n, lambda = m),
      binomial = {
        size <- trials[i, ]
        if (any(abs(size - round(size)) > sqrt(.Machine$double.eps))) {
          stop(
            "engine = 'julia': binomial simulate() needs integer trial counts.",
            call. = FALSE
          )
        }
        stats::rbinom(n, size = as.integer(round(size)), prob = m)
      },
      negbinomial = {
        size <- dispersion[[i]]
        if (!is.finite(size) || size <= 0) {
          stop(
            "engine = 'julia': NB2 simulate() needs positive per-trait ",
            "`r` dispersion.",
            call. = FALSE
          )
        }
        stats::rnbinom(n, mu = m, size = size)
      },
      nb1 = {
        phi <- dispersion[[i]]
        if (!is.finite(phi) || phi <= 0) {
          stop(
            "engine = 'julia': NB1 simulate() needs positive per-trait ",
            "`phi` dispersion.",
            call. = FALSE
          )
        }
        stats::rnbinom(n, mu = m, size = m / phi)
      },
      beta = {
        phi <- dispersion[[i]]
        if (!is.finite(phi) || phi <= 0) {
          stop(
            "engine = 'julia': Beta simulate() needs positive per-trait ",
            "`phi` dispersion.",
            call. = FALSE
          )
        }
        eps <- sqrt(.Machine$double.eps)
        m <- pmin(pmax(m, eps), 1 - eps)
        stats::rbeta(n, shape1 = m * phi, shape2 = (1 - m) * phi)
      },
      gamma = {
        shape <- dispersion[[i]]
        if (!is.finite(shape) || shape <= 0) {
          stop(
            "engine = 'julia': Gamma simulate() needs positive shape ",
            "dispersion.",
            call. = FALSE
          )
        }
        stats::rgamma(n, shape = shape, scale = m / shape)
      },
      stop(
        "engine = 'julia': simulate() is not routed for family '",
        fam,
        "'.",
        call. = FALSE
      )
    )
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
#' @param coef_fixed Optional logical vector of length `dim(X)[3]`. `TRUE`
#'   entries are fixed at zero by the Julia bridge. Most R users should prefer
#'   the named `Xcoef_fixed` argument to [gllvmTMB()], which is translated to
#'   this positional mask after the expanded fixed-effect design is known.
#' @param mask Optional logical response-observation mask with the same orientation
#'   as `y`; `TRUE` cells contribute to the likelihood and `FALSE` cells are
#'   ignored. Currently routed for one-part no-X non-Gaussian point fits, with
#'   masked no-X CI payloads for Poisson, Bernoulli binomial, NB2, NB1, Beta,
#'   and Gamma.
#' @param units_are_rows If `TRUE`, `y` is n x p and is transposed to p x n.
#' @param ci_method Confidence-interval route for admitted no-X bridge rows:
#'   Gaussian, Poisson, Bernoulli binomial, and grouped-dispersion NB2, NB1,
#'   Beta, and Gamma. One of `"none"` (default), `"wald"`, `"profile"`, or
#'   `"bootstrap"`. Response-mask CIs are routed for the same non-ordinal
#'   non-Gaussian rows when `X = NULL`; complete-response fixed-effect-X CIs
#'   are routed for Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and
#'   Gamma. Per-trait ordinal rows, NB1-X rows, mixed-family vectors, and
#'   response masks combined with fixed-effect X remain loud gates.
#' @param ci_level Nominal confidence level when `ci_method != "none"`.
#' @param ci_nboot Number of parametric bootstrap replicates when
#'   `ci_method = "bootstrap"`.
#' @param ci_seed Seed passed to the Julia bootstrap CI route.
#' @param ... Passed to [gllvm_julia_setup()] (`jl_path`, `julia_home`).
#' @return A list of class `gllvmTMB_julia` with the bridge contract fields
#'   (`loadings`, `Sigma`, `correlation`, `loglik`, `aic`, `bic`,
#'   `converged`, ...). If `ci_method != "none"` and the row is admitted, the
#'   list also carries flat CI fields consumed by `confint()`.
#' @examples
#' \dontrun{
#' # Requires a local GLLVM.jl install (see [gllvm_julia_setup()]).
#' # `y` is traits x units (p x n): two Gaussian traits, 40 units, K = 2.
#' set.seed(1)
#' y <- matrix(rnorm(2 * 40), nrow = 2)
#' fit <- gllvm_julia_fit(y, family = "gaussian", num.lv = 2)
#' fit$loglik
#' fit$Sigma
#'
#' # Wald confidence intervals for an admitted no-X row:
#' fit_ci <- gllvm_julia_fit(
#'   y, family = "gaussian", num.lv = 2, ci_method = "wald"
#' )
#' }
#' @export
gllvm_julia_fit <- function(
  y,
  family = "gaussian",
  num.lv = 2L,
  N = NULL,
  X = NULL,
  coef_fixed = NULL,
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
        .gllvm_julia_gate_message(
          "GJL-GATE-MIXED-CI",
          "engine = 'julia': confidence intervals for mixed-family vectors ",
          "are not routed yet. Use `ci_method = \"none\"` or engine = 'tmb'."
        ),
        call. = FALSE
      )
    }
    if (fam %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) {
      stop(
        .gllvm_julia_gate_message(
          "GJL-GATE-ORDINAL-CI",
          "engine = 'julia': confidence intervals for per-trait ordinal ",
          "bridge rows are not routed yet. Use `ci_method = \"none\"` or ",
          "engine = 'tmb'."
        ),
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
  if (ci_method != "none" && !is.null(X) && !is.null(mask)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-MASK-X-CI",
        "engine = 'julia': confidence intervals for fixed-effect-X bridge ",
        "fits with response masks are not routed yet. Use `ci_method = ",
        "\"none\"`, drop `X`, or engine = 'tmb'."
      ),
      call. = FALSE
    )
  }
  if (
    ci_method != "none" &&
      !is.null(X) &&
      !(length(fam) == 1L && fam %in% .GLLVM_JULIA_X_CI_FAMILIES)
  ) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-X-CI",
        "engine = 'julia': confidence intervals for fixed-effect-X bridge ",
        "rows are routed only for Gaussian, Poisson, Bernoulli binomial, ",
        "NB2, Beta, and Gamma complete-response fits. NB1-X, ordinal-X, ",
        "mixed-family-X, and masks+X remain gated. Use `ci_method = \"none\"` ",
        "or engine = 'tmb'."
      ),
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
  coef_fixed_option <- NULL
  if (!is.null(coef_fixed)) {
    if (is.null(X)) {
      stop(
        "engine = 'julia': `coef_fixed` can only be used when `X` is supplied.",
        call. = FALSE
      )
    }
    q <- dim(X)[3L]
    if (is.null(q) || length(coef_fixed) != q) {
      stop(
        "engine = 'julia': `coef_fixed` must have one entry per X column.",
        call. = FALSE
      )
    }
    coef_fixed <- as.logical(coef_fixed)
    if (any(is.na(coef_fixed))) {
      stop(
        "engine = 'julia': `coef_fixed` must be TRUE/FALSE with no missing values.",
        call. = FALSE
      )
    }
    fixed_idx <- which(coef_fixed)
    if (length(fixed_idx)) {
      ## JuliaCall simplifies length-1 R vectors to scalar Julia values. Use
      ## GLLVM.jl's index=>0 dictionary route so one-column masks stay vectors
      ## semantically and multi-column masks use the same transport.
      coef_fixed_option <- stats::setNames(
        as.list(rep(0, length(fixed_idx))),
        as.character(fixed_idx)
      )
    }
  }
  if (!is.null(mask)) {
    args$mask <- mask
  }
  bridge_options <- list()
  if (ci_method != "none") {
    bridge_options <- c(
      bridge_options,
      list(
        ci_method = ci_method,
        ci_level = as.numeric(ci_level),
        ci_nboot = as.integer(ci_nboot),
        ci_seed = as.integer(ci_seed)
      )
    )
  }
  if (!is.null(coef_fixed_option)) {
    bridge_options$coef_fixed <- coef_fixed_option
  }
  if (length(bridge_options)) {
    args$options <- bridge_options
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
    if (
      !is.null(res$gamma_status) &&
        length(res$gamma_status) == length(x_names)
    ) {
      res$gamma_status <- .gllvm_julia_as_vector(res$gamma_status, "character")
      names(res$gamma_status) <- x_names
    }
    if (!is.null(res$mean_coef) && length(res$mean_coef) == length(x_names)) {
      res$mean_coef <- .gllvm_julia_as_vector(res$mean_coef, "numeric")
      names(res$mean_coef) <- x_names
    }
    if (
      !is.null(res$mean_coef_status) &&
        length(res$mean_coef_status) == length(x_names)
    ) {
      res$mean_coef_status <- .gllvm_julia_as_vector(
        res$mean_coef_status,
        "character"
      )
      names(res$mean_coef_status) <- x_names
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
  if (!is.null(coef_fixed)) {
    res$bridge_input$coef_fixed <- coef_fixed
  }
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
#' retained-payload reconstructions only. Simulation is conditional on retained
#' fitted values for admitted one-family rows and complete balanced mixed-family
#' rows. Unit-tier covariance honors native `link_residual` scale semantics,
#' and raw ordination accessors are routed; richer extractor parity remains a
#' separate bridge row.
#' Confidence intervals are
#' routed for admitted no-X Gaussian, Poisson, Bernoulli binomial, NB2, NB1,
#' Beta, and Gamma rows; response-mask CIs are routed for the same non-Gaussian
#' rows when `X = NULL`; complete-response fixed-effect-X CIs are routed for
#' Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and Gamma rows. They may
#' be requested at fit time through
#' `gllvmTMB(ci_method = ...)`, or retrieved and recomputed through `confint()`.
#'
#' @param object,x A fit returned by `gllvmTMB(..., engine = "julia")` or
#'   [gllvm_julia_fit()].
#' @param parm Optional integer or character vector of CI terms for `confint()`.
#' @param nsim Number of replicate response vectors to draw for `simulate()`.
#' @param seed Optional RNG seed for `simulate()`.
#' @param newdata Unsupported for Julia bridge fits; current prediction and
#'   simulation methods return in-sample values from the retained bridge payload.
#' @param condition_on_RE Logical for `simulate()`. The Julia bridge currently
#'   routes only conditional, in-sample simulation from retained fitted values,
#'   so `FALSE` stops with a not-yet-routed message.
#' @param type Prediction or residual scale. For `predict()` and `fitted()`,
#'   `"link"` returns the fitted linear predictor and `"response"` applies the
#'   inverse link for supported non-ordinal bridge families. For per-trait
#'   ordinal bridge fits, `"response"` and `"prob"` return fitted category
#'   probabilities and `"class"` returns the modal category. For `residuals()`,
#'   `"response"` returns observed-minus-fitted residuals on the response scale
#'   and `"pearson"` divides by the family-specific standard deviation.
#'   Binomial rows use the observed proportion, `y / N`, on the response scale.
#' @param level Confidence level requested by `confint()`. Stored Julia bridge
#'   payloads can only be read at their stored level; post-fit requests recompute
#'   the admitted Julia CI payload at the requested level.
#' @param method CI route for `confint()`. `"stored"` reads an existing payload.
#'   `"wald"`, `"profile"`, and `"bootstrap"` recompute from retained bridge
#'   input for admitted no-X Gaussian, Poisson, Bernoulli binomial, NB2, NB1,
#'   Beta, and Gamma rows, including masked non-Gaussian rows when `X = NULL`.
#'   Complete-response fixed-effect-X recomputation is routed for Gaussian,
#'   Poisson, Bernoulli binomial, NB2, Beta, and Gamma rows.
#'   If omitted, `confint()` reads a stored payload when present and otherwise
#'   uses `"wald"` for current fits that retain their bridge input.
#' @param ci_nboot Number of parametric bootstrap replicates when
#'   `method = "bootstrap"`.
#' @param ci_seed Seed passed to the Julia bootstrap CI route.
#' @param digits Number of digits printed by summary methods.
#' @param ... Unused.
#' @return `logLik()` returns a `"logLik"` object. `coef()` returns a named list
#'   of available point-estimate components. `confint()` returns a conventional
#'   confidence-interval matrix for stored or recomputed Julia CI payloads.
#'   `predict()` returns an in-sample data frame. Non-ordinal rows use
#'   `trait`, `unit`, and `est` columns; ordinal probability rows use `trait`,
#'   `unit`, `category`, and `prob`; ordinal class rows use `trait`, `unit`,
#'   and `est`. `fitted()` returns the in-sample fitted matrix with traits in
#'   rows and units in columns for non-ordinal rows, and an array of
#'   category probabilities or a modal-class matrix for ordinal rows.
#'   `residuals()` returns an in-sample residual matrix with the same shape as
#'   `fitted()` for non-ordinal rows and keeps masked response cells as
#'   `NA`. `simulate()` returns an `n_obs x nsim` matrix in the same trait-major
#'   cell order as `predict()` and keeps masked response cells as `NA`.
#'   `summary()` returns a list with header, coefficients, covariance, and
#'   status fields.
#' @importFrom stats coef fitted setNames
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
  type = c("link", "response", "prob", "class"),
  ...
) {
  type <- match.arg(type)
  if (!is.null(newdata)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-NEWDATA-PREDICT",
        "engine = 'julia': `newdata` prediction is not routed yet; current ",
        "`predict.gllvmTMB_julia()` returns in-sample fitted values only."
      ),
      call. = FALSE
    )
  }
  eta <- .gllvm_julia_link_predictor(object)
  if (type == "link") {
    return(.gllvm_julia_prediction_frame(eta))
  }
  if (.gllvm_julia_is_ordinal_fit(object, nrow(eta))) {
    prob <- .gllvm_julia_ordinal_probabilities(object, eta)
    if (type %in% c("response", "prob")) {
      return(.gllvm_julia_ordinal_probability_frame(prob))
    }
    return(.gllvm_julia_prediction_frame(
      .gllvm_julia_ordinal_modal_class(prob)
    ))
  }
  if (type %in% c("prob", "class")) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-PROB-CLASS-NONORDINAL",
        "engine = 'julia': `type = \"",
        type,
        "\"` is only routed for ordinal bridge fits."
      ),
      call. = FALSE
    )
  }
  .gllvm_julia_prediction_frame(.gllvm_julia_response_predictor(object, eta))
}

#' @rdname gllvmTMB_julia-methods
#' @export
fitted.gllvmTMB_julia <- function(
  object,
  type = c("response", "link", "prob", "class"),
  ...
) {
  type <- match.arg(type)
  eta <- .gllvm_julia_link_predictor(object)
  if (type == "link") {
    return(eta)
  }
  if (.gllvm_julia_is_ordinal_fit(object, nrow(eta))) {
    prob <- .gllvm_julia_ordinal_probabilities(object, eta)
    if (type %in% c("response", "prob")) {
      return(prob)
    }
    return(.gllvm_julia_ordinal_modal_class(prob))
  }
  if (type %in% c("prob", "class")) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-PROB-CLASS-NONORDINAL",
        "engine = 'julia': `type = \"",
        type,
        "\"` is only routed for ordinal bridge fits."
      ),
      call. = FALSE
    )
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
  unsupported <- setdiff(unique(families), .GLLVM_JULIA_RESIDUAL_FAMILIES)
  if (length(unsupported)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-ORDINAL-RESIDUAL",
        "engine = 'julia': response/Pearson residuals are not routed for ",
        "family '",
        paste(unsupported, collapse = ", "),
        "'. Ordinal bridge fits currently expose link-scale fitted values only."
      ),
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
simulate.gllvmTMB_julia <- function(
  object,
  nsim = 1,
  seed = NULL,
  newdata = NULL,
  condition_on_RE = TRUE,
  ...
) {
  nsim_value <- suppressWarnings(as.numeric(nsim))
  if (
    length(nsim) != 1L ||
      length(nsim_value) != 1L ||
      is.na(nsim_value) ||
      !is.finite(nsim_value) ||
      nsim_value < 1L ||
      nsim_value != floor(nsim_value)
  ) {
    stop("`nsim` must be a positive integer.", call. = FALSE)
  }
  nsim <- as.integer(nsim_value)
  if (!is.null(newdata)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-NEWDATA-SIMULATE",
        "engine = 'julia': `newdata` simulation is not routed yet; current ",
        "`simulate.gllvmTMB_julia()` draws in-sample values only."
      ),
      call. = FALSE
    )
  }
  if (!isTRUE(condition_on_RE)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-UNCONDITIONAL-SIMULATE",
        "engine = 'julia': unconditional random-effect redraws are not routed ",
        "yet; current `simulate.gllvmTMB_julia()` is conditional on retained ",
        "score/fitted-value payloads."
      ),
      call. = FALSE
    )
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }

  y <- .gllvm_julia_training_y(object)
  p <- nrow(y)
  n <- ncol(y)
  families <- .gllvm_julia_family_vector(object, p)
  unsupported <- setdiff(unique(families), .GLLVM_JULIA_SIMULATE_FAMILIES)
  if (length(unsupported)) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-ORDINAL-SIMULATE",
        "engine = 'julia': conditional simulate() is not routed for family '",
        paste(unsupported, collapse = ", "),
        "'. Current Julia bridge simulation covers admitted non-ordinal rows only."
      ),
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
  mask <- .gllvm_julia_response_mask(object, p, n)
  obs_names <- as.vector(outer(
    rownames(mu) %||% paste0("trait", seq_len(p)),
    colnames(mu) %||% paste0("unit", seq_len(n)),
    paste,
    sep = ":"
  ))
  out <- matrix(
    NA_real_,
    nrow = p * n,
    ncol = nsim,
    dimnames = list(obs_names, paste0("sim_", seq_len(nsim)))
  )
  for (j in seq_len(nsim)) {
    draw <- .gllvm_julia_simulation_draw(object, families, mu)
    draw[!mask] <- NA_real_
    out[, j] <- as.vector(draw)
  }
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
      .gllvm_julia_gate_message(
        "GJL-GATE-NO-CI-PAYLOAD",
        "No Julia bridge CI payload is present; call `confint(..., ",
        "method = \"wald\")`, `\"profile\"`, or `\"bootstrap\"` on a current ",
        "`gllvmTMB(..., engine = \"julia\")` fit, or refit with ",
        "`gllvm_julia_fit(..., ci_method = \"wald\")` for admitted no-X ",
        "Gaussian, Poisson, Bernoulli binomial, NB2, NB1, Beta, or Gamma rows ",
        "or admitted complete-response fixed-effect-X rows."
      ),
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
  REML = FALSE,
  Xcoef_fixed = NULL,
  ci_method = "none",
  ci_level = 0.95,
  ci_nboot = 200L,
  ci_seed = 0L,
  call = NULL
) {
  cs <- parsed$covstructs

  ## engine = 'julia' is reduced-rank only and cannot carry the trait-specific Psi
  ## that ordinary latent() now adds by default (unique = TRUE). Drop the
  ## AUTO-emitted residual-Psi companion for the Julia path and fit the reduced-rank
  ## latent block the bridge supports; an EXPLICIT diagonal term (indep()/unique())
  ## is not auto-flagged, so it still trips the structured-terms gate below.
  if (length(cs)) {
    is_auto_psi <- vapply(cs, function(z) {
      identical(z$kind, "diag") && isTRUE(z$extra$.auto_unique)
    }, logical(1))
    if (any(is_auto_psi)) {
      cli::cli_warn(
        c(
          "engine = 'julia' does not support the trait-specific {.field Psi} that ordinary {.fn latent} now carries by default.",
          "i" = "Fitting the reduced-rank latent block only. Use {.code engine = \"tmb\"} for the {.eq Lambda Lambda^T + Psi} decomposition, or pass {.code latent(..., unique = FALSE)} to silence this note."
        ),
        .frequency = "once",
        .frequency_id = "gllvmTMB-julia-auto-psi-dropped"
      )
      cs <- cs[!is_auto_psi]
      parsed$covstructs <- cs
    }
  }

  kinds <- if (length(cs)) {
    vapply(cs, function(z) z$kind, character(1))
  } else {
    character(0)
  }

  ## --- capability guard: only the reduced-rank latent block (rr) is mapped ---
  unsupported <- setdiff(unique(kinds), "rr")
  if (length(unsupported) > 0) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-STRUCTURED-TERMS",
        "engine = 'julia' does not yet support covariance term(s): ",
        paste(unsupported, collapse = ", "),
        ". Use engine = 'tmb' for structured / grouped / phylo / spatial terms."
      ),
      call. = FALSE
    )
  }
  rr_terms <- cs[kinds == "rr"]
  if (length(rr_terms) > 1L) {
    stop(
      .gllvm_julia_gate_message(
        "GJL-GATE-MULTI-RR",
        "engine = 'julia' supports a single reduced-rank latent block; found ",
        length(rr_terms),
        ". Use engine = 'tmb'."
      ),
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
  fam_str <- .gllvm_julia_family(family)
  cbind_trials <- NULL
  if (is.matrix(yraw) && ncol(yraw) == 2L) {
    if (!any(fam_str == "binomial")) {
      stop(
        .gllvm_julia_gate_message(
          "GJL-GATE-FAMILY",
          "engine = 'julia' only admits two-column cbind(successes, failures) ",
          "responses with a binomial family; the supplied response has two ",
          "columns but the family maps to '",
          paste(fam_str, collapse = ", "),
          "'. Use a single-column response or engine = 'tmb'."
        ),
        call. = FALSE
      )
    }
    ## col 1 = successes, col 2 = failures -> total trials per row = rowSums.
    cbind_trials <- rowSums(yraw)
    yraw <- yraw[, 1L]
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
      .gllvm_julia_gate_message(
        "GJL-GATE-MASK-X",
        "engine = 'julia' does not yet route response masks with fixed-effect ",
        "covariates. Use a complete response table or engine = 'tmb'."
      ),
      call. = FALSE
    )
  }
  if (has_missing_response) {
    Y <- .gllvm_julia_fill_masked_response(Y, fam_str, response_mask)
  }

  Xarg <- NULL
  x_cols <- character(0)
  if (!has_only_trait_intercept) {
    if (length(fam_str) != 1L || !(fam_str %in% .GLLVM_JULIA_X_FAMILIES)) {
      stop(
        .gllvm_julia_gate_message(
          "GJL-GATE-X-FAMILY",
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
          ". Use engine = 'tmb' for this fixed-effect design."
        ),
        call. = FALSE
      )
    }
    if (fam_str != "gaussian" && !all(trait_dummies %in% colnames(Xfix))) {
      stop(
        .gllvm_julia_gate_message(
          "GJL-GATE-X-DESIGN",
          "engine = 'julia' fixed-effect covariates for non-Gaussian rows ",
          "currently require the canonical `0 + trait + ...` design so the ",
          "Julia bridge can use its internal per-trait intercepts. Use ",
          "`0 + trait` or engine = 'tmb'."
        ),
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

  xcoef_fixed <- .normalise_Xcoef_fixed(NULL, x_cols, REML = REML)
  coef_fixed_arg <- NULL
  if (!is.null(Xcoef_fixed)) {
    if (is.null(Xarg)) {
      cli::cli_abort(c(
        "{.arg Xcoef_fixed} for {.code engine = \"julia\"} currently requires an admitted fixed-effect covariate design.",
        "i" = "Use expanded covariate columns such as {.code traitb:x}. Per-trait intercept pinning remains on the native {.code engine = \"tmb\"} path."
      ))
    }
    xcoef_fixed <- .normalise_Xcoef_fixed(
      Xcoef_fixed,
      x_cols,
      REML = REML
    )
    coef_fixed_arg <- xcoef_fixed$status == "fixed"
  }

  ## --- binomial trials: cbind(successes, failures) totals take precedence, then
  ## per-row n_trials (weights API), else Bernoulli (N = 1). ---
  Narg <- NULL
  if (any(fam_str == "binomial")) {
    if (!is.null(cbind_trials)) {
      Narg <- matrix(1, p, n)
      Narg[cbind(as.integer(ft), as.integer(fu))] <- as.numeric(cbind_trials)
    } else if (
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
    coef_fixed = coef_fixed_arg,
    mask = if (has_missing_response) response_mask else NULL,
    ci_method = ci_method,
    ci_level = ci_level,
    ci_nboot = ci_nboot,
    ci_seed = ci_seed
  )
  fit$call <- call
  fit$trait_levels <- traits
  fit$unit_levels <- units
  fit$X_fix_names <- x_cols
  fit$Xcoef_fixed <- xcoef_fixed
  fit$missing_response <- has_missing_response
  if (has_missing_response) {
    fit$response_mask <- response_mask
  }
  fit
}
