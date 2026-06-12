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
