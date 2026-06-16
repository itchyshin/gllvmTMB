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
.GLLVM_JULIA_MIXED_FAMILY <- "mixed-family vector"
.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial"
)
.GLLVM_JULIA_CI_NO_X_FAMILIES <- setdiff(
  .GLLVM_JULIA_BRIDGE_FAMILIES,
  .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES
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
gllvm_julia_setup <- function(jl_path = getOption("gllvmTMB.GLLVM.jl.path", Sys.getenv("GLLVM_JL_PATH", "")),
                              julia_home = getOption("gllvmTMB.julia_home", Sys.getenv("JULIA_HOME", ""))) {
  if (isTRUE(.gllvm_jl_env$ready)) return(invisible(TRUE))
  if (!requireNamespace("JuliaCall", quietly = TRUE)) {
    stop("engine = 'julia' requires the 'JuliaCall' package. Install it with install.packages('JuliaCall').",
         call. = FALSE)
  }
  if (identical(jl_path, "")) {
    stop("engine = 'julia': set the GLLVM.jl project path via ",
         "options(gllvmTMB.GLLVM.jl.path = '/path/to/GLLVM.jl') or the GLLVM_JL_PATH env var.",
         call. = FALSE)
  }
  if (identical(julia_home, "")) {
    JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
  } else {
    JuliaCall::julia_setup(JULIA_HOME = julia_home, installJulia = FALSE, verbose = FALSE)
  }
  JuliaCall::julia_command(sprintf('import Pkg; Pkg.activate("%s"); using GLLVM', jl_path))
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
  out <- data.frame(
    family = families,
    fit_no_x = TRUE,
    fixed_effect_X = families == "gaussian",
    missing_response = FALSE,
    cbind_binomial = FALSE,
    ci_no_x_wald = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_profile = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    ci_no_x_bootstrap = families %in% .GLLVM_JULIA_CI_NO_X_FAMILIES,
    postfit_coef = FALSE,
    postfit_fit_stats = TRUE,
    postfit_summary = FALSE,
    postfit_predict = FALSE,
    postfit_residuals = FALSE,
    postfit_simulate = FALSE,
    postfit_ordination = FALSE,
    status = "partial",
    notes = ifelse(
      families %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES,
      paste(
        "single reduced-rank no-X point route; default Julia payload uses",
        "per-trait grouped dispersion; CI, masks, X, and native parity",
        "promotion are follow-ups"
      ),
      paste(
        "single reduced-rank no-X point route; broader structures, masks,",
        "post-fit methods, and native parity promotion remain gated"
      )
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
    postfit_coef = FALSE,
    postfit_fit_stats = TRUE,
    postfit_summary = FALSE,
    postfit_predict = FALSE,
    postfit_residuals = FALSE,
    postfit_simulate = FALSE,
    postfit_ordination = FALSE,
    status = "partial",
    notes = paste(
      "complete balanced no-X/no-mask/no-CI mixed-family point route;",
      "component families:",
      paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", ")
    ),
    stringsAsFactors = FALSE
  )
  rbind(out, mixed)
}

# Map one R family (a `family` object or a string) to the GLLVM.jl bridge key.
.gllvm_julia_family_scalar <- function(family) {
  if (inherits(family, "family")) family <- family$family
  fam <- tolower(as.character(family))
  if (length(fam) != 1L || is.na(fam)) {
    stop("engine = 'julia': family must resolve to one supported family name.",
         call. = FALSE)
  }
  switch(fam,
    gaussian = "gaussian", normal = "gaussian",
    poisson = "poisson",
    binomial = "binomial", bernoulli = "binomial",
    negbinomial = "negbinomial", nbinom2 = "negbinomial", nb2 = "negbinomial",
    nbinom1 = "nb1", nb1 = "nb1",
    beta = "beta", gamma = "gamma",
    ordinal = "ordinal", ordinal_probit = "ordinal_probit",
    {
      stop("engine = 'julia': unsupported family '", fam, "'. Supported: gaussian, poisson, ",
           "binomial, nbinom2, nbinom1, beta, gamma, ordinal, ordinal_probit ",
           "(or a narrow list for mixed gaussian/poisson/binomial responses).",
           call. = FALSE)
    })
}

# Map an R family (a `family` object, a string, a character vector, or a list of
# one family per trait) to the GLLVM.jl bridge family string(s).
.gllvm_julia_family <- function(family) {
  if (is.list(family) && !inherits(family, "family")) {
    fam <- vapply(family, .gllvm_julia_family_scalar, character(1))
    bad <- setdiff(fam, .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES)
    if (length(bad)) {
      stop("engine = 'julia': mixed-family vectors currently support ",
           paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", "),
           "; unsupported component(s): ",
           paste(unique(bad), collapse = ", "), ".",
           call. = FALSE)
    }
    return(unname(fam))
  }
  if (is.character(family) && length(family) > 1L) {
    fam <- vapply(family, .gllvm_julia_family_scalar, character(1))
    bad <- setdiff(fam, .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES)
    if (length(bad)) {
      stop("engine = 'julia': mixed-family vectors currently support ",
           paste(.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES, collapse = ", "),
           "; unsupported component(s): ",
           paste(unique(bad), collapse = ", "), ".",
           call. = FALSE)
    }
    return(unname(fam))
  }
  .gllvm_julia_family_scalar(family)
}

.gllvm_julia_as_vector <- function(x, mode = c("numeric", "integer", "character")) {
  mode <- match.arg(mode)
  out <- unlist(x, use.names = FALSE)
  switch(mode,
    numeric = as.numeric(out),
    integer = as.integer(out),
    character = as.character(out))
}

.gllvm_julia_n_traits <- function(res) {
  if (!is.null(res$n_traits)) return(as.integer(res$n_traits)[1L])
  if (!is.null(res$trait_names)) return(length(.gllvm_julia_as_vector(res$trait_names, "character")))
  if (!is.null(res$loadings)) return(nrow(as.matrix(res$loadings)))
  if (!is.null(res$Sigma)) return(nrow(as.matrix(res$Sigma)))
  if (!is.null(res$dispersion)) return(length(.gllvm_julia_as_vector(res$dispersion, "numeric")))
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
  if (family == "negbinomial") return(1 / sqrt(values))
  if (family == "nb1") return(values)
  if (family %in% c("beta", "gamma")) return(1 / sqrt(values))
  values
}

.gllvm_julia_public_dispersion_parameter <- function(family) {
  switch(family,
    negbinomial = "sigma",
    nb1 = "phi",
    beta = "sigma",
    gamma = "sigma",
    "dispersion")
}

.gllvm_julia_normalise_result <- function(res) {
  p <- .gllvm_julia_n_traits(res)
  if (p > 0L) {
    traits <- .gllvm_julia_trait_names(res, p)
    res$trait_names <- traits
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

  fam <- if (!is.null(res$family)) .gllvm_julia_as_vector(res$family, "character")[1L] else NA_character_
  if (!is.na(fam) && fam %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES &&
      (!is.null(res$dispersion_group) || !is.null(res$dispersion))) {
    dispersion <- if (!is.null(res$dispersion)) {
      .gllvm_julia_as_vector(res$dispersion, "numeric")
    } else {
      numeric()
    }
    if (length(dispersion) == 1L && p > 1L) dispersion <- rep(dispersion, p)
    if (p > 0L && length(dispersion) == p) names(dispersion) <- traits

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
      stop("engine = 'julia': grouped-dispersion payload has ",
           length(group_id), " group ids for ", p, " traits.",
           call. = FALSE)
    }
    if (length(group) && any(!is.finite(group) | group <= 0)) {
      stop("engine = 'julia': grouped-dispersion payload must be finite and positive.",
           call. = FALSE)
    }
    if (length(group_id) && (min(group_id) < 1L || max(group_id) > length(group))) {
      stop("engine = 'julia': grouped-dispersion ids are out of range.",
           call. = FALSE)
    }

    group_names <- names(res$dispersion_group)
    if (is.null(group_names) || length(group_names) != length(group) ||
        any(!nzchar(group_names))) {
      group_names <- if (length(group) == p && identical(group_id, seq_len(p))) {
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
    res$dispersion_public_parameter <- .gllvm_julia_public_dispersion_parameter(fam)
    if (fam == "negbinomial") {
      res$dispersion_gllvm_phi <- 1 / dispersion
      res$dispersion_group_gllvm_phi <- 1 / group
    }
  } else if (!is.null(res$dispersion) && p > 0L) {
    dispersion <- .gllvm_julia_as_vector(res$dispersion, "numeric")
    if (length(dispersion) == 1L && p > 1L) dispersion <- rep(dispersion, p)
    if (length(dispersion) == p) {
      names(dispersion) <- traits
      res$dispersion <- dispersion
    }
  }
  res
}

#' Fit a GLLVM with the Julia engine (GLLVM.jl `bridge_fit`).
#'
#' @param y Response matrix, p x n (traits x units), or n x p (set `units_are_rows`).
#' @param family A family object/string, or a list of them (one per trait -> mixed).
#' @param num.lv Number of latent variables (K).
#' @param N Binomial trials (matrix or scalar), or `NULL`.
#' @param X Gaussian-only fixed-effect design (p x n x q array), or `NULL`.
#' @param units_are_rows If `TRUE`, `y` is n x p and is transposed to p x n.
#' @param ... Passed to [gllvm_julia_setup()] (`jl_path`, `julia_home`).
#' @return A list of class `gllvmTMB_julia` with the bridge contract fields
#'   (`loadings`, `Sigma`, `correlation`, `loglik`, `aic`, `bic`, `converged`, ...).
#' @export
gllvm_julia_fit <- function(y, family = "gaussian", num.lv = 2L, N = NULL, X = NULL,
                            units_are_rows = FALSE, ...) {
  gllvm_julia_setup(...)
  fam <- .gllvm_julia_family(family)
  y <- as.matrix(y)
  if (isTRUE(units_are_rows)) y <- t(y)
  if (any(fam %in% c("poisson", "binomial", "negbinomial", "nb1"))) storage.mode(y) <- "integer"
  args <- list("GLLVM.bridge_fit", y = y, family = fam, d = as.integer(num.lv))
  if (!is.null(rownames(y))) args$trait_names <- rownames(y)
  if (!is.null(colnames(y))) args$unit_names <- colnames(y)
  if (!is.null(N)) args$N <- N
  if (!is.null(X)) args$X <- X
  res <- do.call(JuliaCall::julia_call, args)
  res <- .gllvm_julia_normalise_result(res)
  res$engine <- "julia"
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
  cat(sprintf("  family: %s | K = %d | %d traits x %d units\n",
              paste(unique(x$family), collapse = ","), x$d, x$n_traits, x$n_units))
  cat(sprintf("  logLik = %.4f | AIC = %.2f | BIC = %.2f | converged = %s\n",
              x$loglik, x$aic, x$bic, x$converged))
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
.gllvmTMB_julia_dispatch <- function(parsed, data, trait, unit_internal, family,
                                     weights = NULL, call = NULL) {
  cs    <- parsed$covstructs
  kinds <- if (length(cs)) vapply(cs, function(z) z$kind, character(1)) else character(0)

  ## --- capability guard: only the reduced-rank latent block (rr) is mapped ---
  unsupported <- setdiff(unique(kinds), "rr")
  if (length(unsupported) > 0) {
    stop("engine = 'julia' does not yet support covariance term(s): ",
         paste(unsupported, collapse = ", "),
         ". Use engine = 'tmb' for structured / grouped / phylo / spatial terms.",
         call. = FALSE)
  }
  rr_terms <- cs[kinds == "rr"]
  if (length(rr_terms) > 1L) {
    stop("engine = 'julia' supports a single reduced-rank latent block; found ",
         length(rr_terms), ". Use engine = 'tmb'.", call. = FALSE)
  }
  K <- if (length(rr_terms) == 1L) {
    dval <- rr_terms[[1L]]$extra$d
    as.integer(if (is.null(dval)) 1L else dval)
  } else 0L

  ## --- response: pivot long (trait, unit) -> a p x n matrix ---
  mf  <- stats::model.frame(parsed$fixed, data = data, na.action = stats::na.pass)
  yraw <- stats::model.response(mf)
  if (is.matrix(yraw) && ncol(yraw) == 2L) {
    stop("engine = 'julia' does not yet support cbind(successes, failures) ",
         "binomial responses; use a 0/1 Bernoulli response or engine = 'tmb'.",
         call. = FALSE)
  }
  yv <- as.numeric(yraw)
  ft <- factor(data[[trait]])
  fu <- factor(data[[unit_internal]])
  if (length(yv) != length(ft) || length(yv) != length(fu)) {
    stop("engine = 'julia': response / trait / unit length mismatch.", call. = FALSE)
  }
  traits <- levels(ft); units <- levels(fu)
  p <- length(traits); n <- length(units)
  Y <- matrix(NA_real_, p, n, dimnames = list(traits, units))
  Y[cbind(as.integer(ft), as.integer(fu))] <- yv
  if (anyNA(Y)) {
    stop("engine = 'julia' currently requires a complete (balanced) trait x unit ",
         "table; found ", sum(is.na(Y)), " empty cell(s). Use engine = 'tmb'.",
         call. = FALSE)
  }

  ## --- fixed effects: the per-trait intercept (0 + trait) is always mapped to
  ## the bridge's internal per-trait intercept. Extra fixed-effect covariates
  ## (e.g. `env`) are mapped for the Gaussian family only, by pivoting the long
  ## design matrix into a p x n x q array X and passing it to bridge_fit; the
  ## Julia Gaussian fitter carries the FULL mean structure (intercept dummies +
  ## covariates) in X. Non-Gaussian X stays a loud reject. ---
  fam_str <- .gllvm_julia_family(family)
  Xfix <- stats::model.matrix(parsed$fixed, mf)
  trait_dummies <- paste0(trait, traits)
  extra_cols <- setdiff(colnames(Xfix), trait_dummies)
  has_only_trait_intercept <- (length(extra_cols) == 0 && ncol(Xfix) == p)

  Xarg <- NULL
  if (!has_only_trait_intercept) {
    if (!all(fam_str == "gaussian")) {
      stop("engine = 'julia' maps fixed-effect covariates for the gaussian family ",
           "only; found fixed term(s): ",
           paste(c(extra_cols,
                   if (ncol(Xfix) != p && length(extra_cols) == 0)
                     "(non-per-trait-intercept design)"),
                 collapse = ", "),
           ". Use engine = 'tmb' for non-Gaussian fixed-effect covariates.",
           call. = FALSE)
    }
    ## Pivot the long (N = p*n row) design matrix into a p x n x q array. For each
    ## long row i with (trait ft[i], unit fu[i]), Xarg[ft[i], fu[i], k] = Xfix[i, k].
    ## Column order follows model.matrix() (intercept dummies first, then covariates);
    ## the marginal loglik is invariant to fixed-effect column order.
    q <- ncol(Xfix)
    Xarg <- array(0, dim = c(p, n, q),
                  dimnames = list(traits, units, colnames(Xfix)))
    idx3 <- cbind(rep(as.integer(ft), times = q),
                  rep(as.integer(fu), times = q),
                  rep(seq_len(q), each = length(yv)))
    Xarg[idx3] <- as.numeric(Xfix)
  }

  ## --- binomial trials: pivot per-row n_trials (weights API) else Bernoulli ---
  Narg <- NULL
  if (any(fam_str == "binomial")) {
    if (!is.null(weights) && is.numeric(weights) && length(weights) == length(yv)) {
      Narg <- matrix(1, p, n)
      Narg[cbind(as.integer(ft), as.integer(fu))] <- as.numeric(weights)
    } else {
      Narg <- 1L
    }
  }

  fit <- gllvm_julia_fit(Y, family = family, num.lv = K, N = Narg, X = Xarg)
  fit$call         <- call
  fit$trait_levels <- traits
  fit$unit_levels  <- units
  fit
}
