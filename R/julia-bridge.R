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

# Map an R family (a `family` object, a string, or a list of them for mixed) to the
# GLLVM.jl bridge family string(s).
.gllvm_julia_family <- function(family) {
  if (is.list(family) && !inherits(family, "family")) {
    return(vapply(family, .gllvm_julia_family, character(1)))
  }
  if (inherits(family, "family")) family <- family$family
  fam <- tolower(as.character(family))
  out <- switch(fam,
    gaussian = "gaussian", normal = "gaussian",
    poisson = "poisson",
    binomial = "binomial", bernoulli = "binomial",
    negbinomial = "nbinom2", nbinom2 = "nbinom2", nb2 = "nbinom2",
    nbinom1 = "nb1", nb1 = "nb1",
    beta = "beta", gamma = "gamma",
    ordinal = "ordinal", lognormal = "lognormal",
    NA_character_)
  if (is.na(out)) {
    stop("engine = 'julia': unsupported family '", fam, "'. Supported: gaussian, poisson, ",
         "binomial, nbinom2, nbinom1, beta, gamma, ordinal, lognormal (or a list for mixed).",
         call. = FALSE)
  }
  out
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
  if (any(fam %in% c("poisson", "binomial", "nbinom2", "nb1"))) storage.mode(y) <- "integer"
  args <- list("GLLVM.bridge_fit", y = y, family = fam, d = as.integer(num.lv))
  if (!is.null(N)) args$N <- N
  if (!is.null(X)) args$X <- X
  res <- do.call(JuliaCall::julia_call, args)
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

  ## --- fixed effects: only the per-trait intercept (0 + trait) is mapped; the
  ## bridge fits per-trait intercepts internally. Reject extra covariates. ---
  Xfix <- stats::model.matrix(parsed$fixed, mf)
  trait_dummies <- paste0(trait, traits)
  extra_cols <- setdiff(colnames(Xfix), trait_dummies)
  if (length(extra_cols) > 0 || ncol(Xfix) != p) {
    stop("engine = 'julia' maps only the per-trait intercept (0 + ", trait,
         ") mean structure; found fixed term(s): ",
         paste(c(extra_cols, if (ncol(Xfix) != p) "(non-per-trait-intercept design)"),
               collapse = ", "),
         ". Use engine = 'tmb' for fixed-effect covariates.", call. = FALSE)
  }

  ## --- binomial trials: pivot per-row n_trials (weights API) else Bernoulli ---
  fam_str <- .gllvm_julia_family(family)
  Narg <- NULL
  if (any(fam_str == "binomial")) {
    if (!is.null(weights) && is.numeric(weights) && length(weights) == length(yv)) {
      Narg <- matrix(1, p, n)
      Narg[cbind(as.integer(ft), as.integer(fu))] <- as.numeric(weights)
    } else {
      Narg <- 1L
    }
  }

  fit <- gllvm_julia_fit(Y, family = family, num.lv = K, N = Narg)
  fit$call         <- call
  fit$trait_levels <- traits
  fit$unit_levels  <- units
  fit
}
