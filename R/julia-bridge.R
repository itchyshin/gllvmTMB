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
#' @param ci_method Confidence-interval method routed to the Julia engine: one of
#'   `"none"` (default, no CIs), `"wald"`, `"profile"`, or `"bootstrap"`. When not
#'   `"none"`, the returned object gains the bridge `ci_*` fields (`ci_method`,
#'   `ci_level`, `ci_param_names`, `ci_estimate`, `ci_lower`, `ci_upper`,
#'   `ci_note`), reusing GLLVM.jl's native CI engines (no CI math in R).
#' @param ci_level Nominal coverage for the CIs (default `0.95`).
#' @param ci_nboot Parametric-bootstrap replicates when `ci_method = "bootstrap"`
#'   (default `200L`).
#' @param ci_seed Bootstrap RNG seed (default `0L`; fixed for reproducibility).
#' @param ... Passed to [gllvm_julia_setup()] (`jl_path`, `julia_home`).
#' @return A list of class `gllvmTMB_julia` with the bridge contract fields
#'   (`loadings`, `Sigma`, `correlation`, `loglik`, `aic`, `bic`, `converged`, ...).
#'   When `ci_method != "none"` the object also carries the bridge `ci_*` fields.
#' @export
gllvm_julia_fit <- function(y, family = "gaussian", num.lv = 2L, N = NULL, X = NULL,
                            units_are_rows = FALSE,
                            ci_method = c("none", "wald", "profile", "bootstrap"),
                            ci_level = 0.95, ci_nboot = 200L, ci_seed = 0L, ...) {
  ci_method <- match.arg(ci_method)
  gllvm_julia_setup(...)
  fam <- .gllvm_julia_family(family)
  y <- as.matrix(y)
  if (isTRUE(units_are_rows)) y <- t(y)
  if (any(fam %in% c("poisson", "binomial", "nbinom2", "nb1"))) storage.mode(y) <- "integer"
  args <- list("GLLVM.bridge_fit", y = y, family = fam, d = as.integer(num.lv))
  if (!is.null(N)) args$N <- N
  if (!is.null(X)) args$X <- X
  ## CI routing: pass a Julia options Dict only when CIs are requested, so the
  ## default ci_method = "none" leaves the bridge call byte-identical to before.
  if (!identical(ci_method, "none")) {
    args$options <- JuliaCall::julia_call("Dict",
      JuliaCall::julia_call("=>", "ci_method", ci_method),
      JuliaCall::julia_call("=>", "ci_level", as.numeric(ci_level)),
      JuliaCall::julia_call("=>", "ci_nboot", as.integer(ci_nboot)),
      JuliaCall::julia_call("=>", "ci_seed", as.integer(ci_seed)))
  }
  res <- do.call(JuliaCall::julia_call, args)
  res$engine <- "julia"
  ## Stash the marshalled fit inputs so confint() can re-fit on the SAME data with
  ## a different ci_method without the caller re-supplying y / N / X.
  res$y <- y
  res$N <- N
  res$X <- X
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
#'   `"<a> %"` / `"<1-a> %"` in the `stats::confint()` convention.
#' @export
#' @method confint gllvmTMB_julia
confint.gllvmTMB_julia <- function(object, parm = NULL, level = 0.95,
                                   method = c("wald", "profile", "bootstrap"), ...) {
  method <- match.arg(method)

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
      stop("confint.gllvmTMB_julia: this object carries no cached CI fields for ",
           "method = '", method, "' (level ", level, ") and no stored response ",
           "matrix to re-fit. Re-fit with gllvm_julia_fit(..., ci_method = '",
           method, "').", call. = FALSE)
    }
    refit <- gllvm_julia_fit(
      y, family = object$family[1], num.lv = object$d, N = object$N, X = object$X,
      ci_method = method, ci_level = level, ...)
    object$ci_method      <- refit$ci_method
    object$ci_level       <- refit$ci_level
    object$ci_param_names <- refit$ci_param_names
    object$ci_estimate    <- refit$ci_estimate
    object$ci_lower       <- refit$ci_lower
    object$ci_upper       <- refit$ci_upper
    object$ci_note        <- refit$ci_note
  }

  nms <- as.character(object$ci_param_names)
  a <- (1 - level) / 2
  pct <- paste(format(100 * c(a, 1 - a), trim = TRUE, scientific = FALSE,
                      digits = 3), "%")
  ci <- matrix(c(object$ci_lower, object$ci_upper), ncol = 2,
               dimnames = list(nms, pct))

  if (!is.null(parm)) {
    sel <- if (is.numeric(parm)) parm else match(parm, nms)
    if (anyNA(sel)) {
      stop("confint.gllvmTMB_julia: unknown parm: ",
           paste(parm[is.na(sel)], collapse = ", "), call. = FALSE)
    }
    ci <- ci[sel, , drop = FALSE]
  }
  ci
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
