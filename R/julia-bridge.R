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

# Bridge family strings that the current GLLVM.jl `bridge_fit` accepts. Keep this
# intentionally narrow until missing-response masks and mixed-family metadata are
# merged and parity-tested (gllvmTMB#488).
.GLLVM_JULIA_BRIDGE_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "beta",
  "gamma",
  "ordinal"
)
.GLLVM_JULIA_X_FAMILIES <- c(
  "gaussian",
  "poisson",
  "binomial",
  "negbinomial",
  "beta",
  "gamma"
)

# Map an R family (a `family` object, a string, or a list of them for mixed) to the
# GLLVM.jl bridge family string(s).
.gllvm_julia_family <- function(family) {
  if (is.list(family) && !inherits(family, "family")) {
    stop(
      "engine = 'julia': mixed-family vectors are not wired on this ",
      "GLLVM.jl bridge branch yet. Use engine = 'tmb' for mixed-family fits.",
      call. = FALSE
    )
  }
  if (inherits(family, "family")) {
    family <- family$family
  }
  fam <- tolower(as.character(family))
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
    beta = "beta",
    gamma = "gamma",
    ordinal = "ordinal",
    NA_character_
  )
  if (is.na(out)) {
    stop(
      "engine = 'julia': unsupported family '",
      fam,
      "'. Supported: gaussian, poisson, ",
      "binomial, nbinom2, beta, gamma, ordinal.",
      call. = FALSE
    )
  }
  out
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

#' Fit a GLLVM with the Julia engine (GLLVM.jl `bridge_fit`).
#'
#' @param y Response matrix, p x n (traits x units), or n x p (set `units_are_rows`).
#' @param family A family object/string, or a list of them (one per trait -> mixed).
#' @param num.lv Number of latent variables (K).
#' @param N Binomial trials (matrix or scalar), or `NULL`.
#' @param X Optional fixed-effect covariate array with shape p x n x q. Gaussian
#'   fits expect the full mean design, including per-trait intercept planes;
#'   supported non-Gaussian fits expect the extra covariate planes only.
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
gllvm_julia_fit <- function(
  y,
  family = "gaussian",
  num.lv = 2L,
  N = NULL,
  X = NULL,
  units_are_rows = FALSE,
  ci_method = c("none", "wald", "profile", "bootstrap"),
  ci_level = 0.95,
  ci_nboot = 200L,
  ci_seed = 0L,
  ...
) {
  ci_method <- match.arg(ci_method)
  fam <- .gllvm_julia_family(family)
  y <- as.matrix(y)
  if (isTRUE(units_are_rows)) {
    y <- t(y)
  }
  if (anyNA(y)) {
    stop(
      "engine = 'julia': missing-response masks are not wired yet; ",
      "y must be complete. Use engine = 'tmb' for missing responses.",
      call. = FALSE
    )
  }
  if (as.integer(num.lv) < 1L) {
    stop(
      "engine = 'julia': this GLLVM.jl bridge branch requires num.lv >= 1.",
      call. = FALSE
    )
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
      stop(
        "engine = 'julia': confidence intervals for non-Gaussian covariate ",
        "fits are not routed through the Julia bridge yet. Re-fit with ",
        "ci_method = 'none' or use engine = 'tmb'.",
        call. = FALSE
      )
    }
  }
  trait_names <- rownames(y)
  unit_names <- colnames(y)
  if (fam %in% c("poisson", "binomial", "negbinomial", "ordinal")) {
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
  if (!is.null(trait_names)) {
    args$trait_names <- trait_names
  }
  if (!is.null(unit_names)) {
    args$unit_names <- unit_names
  }
  ## CI routing: pass a Julia options Dict only when CIs are requested, so the
  ## default ci_method = "none" leaves the bridge call byte-identical to before.
  if (!identical(ci_method, "none")) {
    args$options <- JuliaCall::julia_call(
      "Dict",
      JuliaCall::julia_call("=>", "ci_method", ci_method),
      JuliaCall::julia_call("=>", "ci_level", as.numeric(ci_level)),
      JuliaCall::julia_call("=>", "ci_nboot", as.integer(ci_nboot)),
      JuliaCall::julia_call("=>", "ci_seed", as.integer(ci_seed))
    )
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

.gllvm_julia_eta_matrix <- function(object, include_latent = TRUE) {
  fam <- as.character(object$family[1])
  if (identical(fam, "ordinal")) {
    stop(
      "predict.gllvmTMB_julia: ordinal predictions are not wired yet because ",
      "the Julia bridge payload does not carry cutpoints/probabilities.",
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
    if (!is.array(X) || length(dim(X)) != 3L || dim(X)[3] != length(mean_coef)) {
      stop(
        "predict.gllvmTMB_julia: object carries incompatible X/mean_coef fields.",
        call. = FALSE
      )
    }
    for (k in seq_along(mean_coef)) {
      eta <- eta + X[, , k] * mean_coef[k]
    }
    used_full_mean <- TRUE
  }
  if (!used_full_mean && !is.null(object$beta_cov)) {
    eta <- eta + matrix(as.numeric(object$beta_cov), p, n)
  } else if (!used_full_mean && !is.null(object$alpha) && all(is.finite(object$alpha))) {
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
      eta <- eta + X[, , k] * gamma[k]
    }
  }
  dimnames(eta) <- list(.gllvm_julia_trait_names(object), .gllvm_julia_unit_names(object))
  eta
}

.gllvm_julia_inverse_link <- function(object, eta) {
  fam <- as.character(object$family[1])
  switch(
    fam,
    gaussian = eta,
    poisson = exp(eta),
    binomial = stats::plogis(eta),
    negbinomial = exp(eta),
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
    out[[value_name]] <- as.numeric(values[cbind(object$.trait_index, object$.unit_index)])
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

#' Post-fit methods for Julia-engine GLLVM fits
#'
#' Basic inspection methods for objects returned by [gllvm_julia_fit()] or
#' [gllvmTMB()] with `engine = "julia"`. These methods expose the flat bridge
#' payload in ordinary R shapes; they do not perform new Julia computations.
#'
#' @param object,x A `gllvmTMB_julia` object.
#' @param newdata Optional new data. Currently unsupported for Julia-engine fits;
#'   only in-sample predictions are returned.
#' @param type Prediction scale. `"link"` returns the fitted linear predictor and
#'   `"response"` returns the inverse-link mean.
#' @param re_form Random-effect formula controlling whether conditional latent
#'   scores are included. Use `~ 0` or `NA` for fixed-effects-only predictions.
#' @param digits Decimal digits to print.
#' @param ... Currently unused.
#' @return `coef()` returns a named list of bridge coefficients. `predict()` and
#'   `residuals()` return data frames in the original training-row order when the
#'   object came from `gllvmTMB(..., engine = "julia")`. `fitted()` returns a
#'   trait x unit matrix. `summary()` returns a list of class
#'   `summary.gllvmTMB_julia`. `print()` methods return the input invisibly.
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
predict.gllvmTMB_julia <- function(
  object,
  newdata = NULL,
  type = c("link", "response"),
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
  type <- match.arg(type)
  eta <- .gllvm_julia_eta_matrix(
    object,
    include_latent = !.gllvm_julia_re_zero(re_form)
  )
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
  type = c("response"),
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
  out <- .gllvm_julia_long_values(object, observed - fit, "residual")
  out$observed <- .gllvm_julia_long_values(object, observed, "observed")$observed
  out$fitted <- .gllvm_julia_long_values(object, fit, "fitted")$fitted
  out$type <- type
  out$status <- "ok"
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
#'   `"<a> %"` / `"<1-a> %"` in the `stats::confint()` convention.
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
      ci_method = method,
      ci_level = level,
      ...
    )
    object$ci_method <- refit$ci_method
    object$ci_level <- refit$ci_level
    object$ci_param_names <- refit$ci_param_names
    object$ci_estimate <- refit$ci_estimate
    object$ci_lower <- refit$ci_lower
    object$ci_upper <- refit$ci_upper
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
.gllvmTMB_julia_dispatch <- function(
  parsed,
  data,
  trait,
  unit_internal,
  family,
  weights = NULL,
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
  if (!is.null(is_y_observed) && any(as.integer(is_y_observed) == 0L)) {
    stop(
      "engine = 'julia': missing-response masks are not wired yet; ",
      "use engine = 'tmb' for missing = miss_control(response = 'include').",
      call. = FALSE
    )
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
  Y <- matrix(NA_real_, p, n, dimnames = list(traits, units))
  Y[cbind(as.integer(ft), as.integer(fu))] <- yv
  if (anyNA(Y)) {
    stop(
      "engine = 'julia' currently requires a complete (balanced) trait x unit ",
      "table; found ",
      sum(is.na(Y)),
      " empty cell(s). Use engine = 'tmb'.",
      call. = FALSE
    )
  }

  ## --- fixed effects: the per-trait intercept (0 + trait) is mapped to the
  ## bridge's internal per-trait intercept for non-Gaussian X fits. Gaussian X
  ## fits are different: GLLVM.jl expects the FULL mean design, so we include the
  ## trait-intercept planes plus the extra covariate planes. ---
  fam_str <- .gllvm_julia_family(family)
  Xfix <- stats::model.matrix(parsed$fixed, mf)
  trait_dummies <- paste0(trait, traits)
  extra_cols <- setdiff(colnames(Xfix), trait_dummies)
  has_only_trait_intercept <- (length(extra_cols) == 0 && ncol(Xfix) == p)

  Xarg <- NULL
  if (!has_only_trait_intercept) {
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

  fit <- gllvm_julia_fit(Y, family = family, num.lv = K, N = Narg, X = Xarg)
  fit$call <- call
  fit$trait_levels <- traits
  fit$unit_levels <- units
  fit$trait_col <- trait
  fit$unit_col <- unit_internal
  fit$.trait_index <- as.integer(ft)
  fit$.unit_index <- as.integer(fu)
  fit
}
