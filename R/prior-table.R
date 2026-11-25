.gllvmTMB_abort_prior_table <- function(message, ..., next_step =
    "Check the prior-table documentation, correct this row, and refit.") {
  cli::cli_abort(c(message, ">" = next_step), ...)
}

.gllvmTMB_parse_prior_table <- function(x) {
  if (!is.data.frame(x) || anyDuplicated(names(x))) {
    .gllvmTMB_abort_prior_table("prior table must be a data frame with unique columns")
  }
  required <- c("prior", "class")
  optional <- c("coef", "dpar", "scale", "group", "block", "resp",
                "trait", "kernel")
  if (!all(required %in% names(x)) || any(!names(x) %in% c(required, optional))) {
    .gllvmTMB_abort_prior_table("invalid prior table columns")
  }
  if (any(!vapply(x, is.character, logical(1))) || anyNA(x)) {
    .gllvmTMB_abort_prior_table("prior table requires nonmissing character rows")
  }
  if (!nrow(x)) return(list())
  number <- "[+-]?(?:(?:[0-9]+(?:\\.[0-9]*)?)|(?:\\.[0-9]+))(?:[eE][+-]?[0-9]+)?"
  pattern <- paste0("^\\s*(normal|student_t|ridge|gamma)\\s*\\(\\s*",
    "(", number, ")\\s*(?:,\\s*(", number, ")\\s*)?",
    "(?:,\\s*(", number, ")\\s*)?\\)\\s*$")
  rows <- lapply(seq_len(nrow(x)), function(i) {
    cls <- x$class[[i]]
    coef <- if ("coef" %in% names(x)) x$coef[[i]] else ""
    trait <- if ("trait" %in% names(x)) x$trait[[i]] else ""
    kernel <- if ("kernel" %in% names(x)) x$kernel[[i]] else ""
    dpar <- if ("dpar" %in% names(x) && nzchar(x$dpar[[i]])) {
      x$dpar[[i]]
    } else if (cls %in% c("residual_sd", "unique_variance")) {
      ""
    } else {
      "mu"
    }
    scale <- if ("scale" %in% names(x)) x$scale[[i]] else ""
    selectors <- intersect(c("group", "block", "resp"), names(x))
    if (any(vapply(selectors, function(nm) nzchar(x[[nm]][[i]]), logical(1)))) {
      .gllvmTMB_abort_prior_table("GLLVM prior tables do not support group, block, or resp selectors")
    }
    match <- regmatches(x$prior[[i]], regexec(pattern, x$prior[[i]], perl = TRUE))[[1L]]
    if (!length(match)) {
      if (grepl("^\\s*[A-Za-z][A-Za-z0-9_]*\\s*\\(", x$prior[[i]]) &&
          !grepl("^\\s*(normal|student_t|ridge|gamma)\\s*\\(", x$prior[[i]])) {
        .gllvmTMB_abort_prior_table("unsupported prior distribution")
      }
      .gllvmTMB_abort_prior_table("invalid prior syntax")
    }
    kind <- match[[2L]]
    args_text <- match[3:5]
    args_text <- args_text[nzchar(args_text)]
    args <- suppressWarnings(as.numeric(args_text))
    arity <- switch(kind, normal = 2L, student_t = 3L, ridge = 1L,
                    gamma = 2L)
    if (length(args) != arity || any(!is.finite(args))) {
      .gllvmTMB_abort_prior_table("invalid prior parameters or arity")
    }
    if (cls == "fixef") {
      if (!dpar %in% "mu") .gllvmTMB_abort_prior_table("GLLVM fixed-effect prior table supports dpar=mu only")
      if (!nzchar(coef) || coef == "all") .gllvmTMB_abort_prior_table("fixef rows require an exact coefficient name")
      if (!nzchar(scale)) scale <- "link"
      if (scale != "link") .gllvmTMB_abort_prior_table("fixef rows require scale=link")
      if (!kind %in% c("normal", "student_t", "ridge")) .gllvmTMB_abort_prior_table("unsupported fixef prior")
      if (kind == "normal" && args[[2L]] <= 0) .gllvmTMB_abort_prior_table("normal prior scale must be positive")
      if (kind == "student_t" && (args[[2L]] <= 0 || args[[3L]] <= 0)) {
        .gllvmTMB_abort_prior_table("Student-t scale and df must be positive")
      }
      if (kind == "ridge" && args[[1L]] < 0) .gllvmTMB_abort_prior_table("ridge lambda must be nonnegative")
    } else if (cls == "loading") {
      if (!dpar %in% "mu") .gllvmTMB_abort_prior_table("GLLVM loading prior table supports dpar=mu only")
      if (kind != "ridge" || coef != "all") {
        .gllvmTMB_abort_prior_table("loading rows require ridge(lambda) and coef=all")
      }
      if (scale != "loading_coef") .gllvmTMB_abort_prior_table("loading rows require scale=loading_coef")
      if (args[[1L]] < 0) .gllvmTMB_abort_prior_table("ridge lambda must be nonnegative")
    } else if (cls == "residual_sd") {
      if (kind != "gamma") .gllvmTMB_abort_prior_table("residual_sd rows require gamma(mean, shape)")
      if (dpar != "sigma") .gllvmTMB_abort_prior_table("residual_sd rows require dpar=sigma")
      if (coef != "(Intercept)") .gllvmTMB_abort_prior_table("residual_sd rows require coef=(Intercept)")
      if (scale != "natural_sd") .gllvmTMB_abort_prior_table("residual_sd rows require scale=natural_sd")
      if (args[[1L]] <= 0 || args[[2L]] <= 1) {
        .gllvmTMB_abort_prior_table("Gamma residual-SD mean must be positive and shape must exceed one")
      }
      rate <- args[[2L]] / args[[1L]]
      if (!is.finite(rate) || rate <= 0) {
        .gllvmTMB_abort_prior_table("Gamma residual-SD parameters must imply a finite positive rate")
      }
      if (nzchar(trait) || nzchar(kernel)) {
        .gllvmTMB_abort_prior_table("trait and kernel selectors are only supported for unique_variance rows")
      }
    } else if (cls == "unique_variance") {
      if (kind != "gamma") {
        .gllvmTMB_abort_prior_table("unique_variance rows require a Gamma prior on the natural SD")
      }
      if (nzchar(dpar) || nzchar(coef)) {
        .gllvmTMB_abort_prior_table("unique_variance rows do not use dpar or coef selectors")
      }
      if (!nzchar(trait)) {
        .gllvmTMB_abort_prior_table("unique_variance rows require a nonempty trait selector")
      }
      if (scale != "natural_sd") {
        .gllvmTMB_abort_prior_table("unique_variance rows require scale=natural_sd")
      }
      if (args[[1L]] <= 0 || args[[2L]] <= 1) {
        .gllvmTMB_abort_prior_table("unique-variance Gamma mean must be positive and shape must exceed one")
      }
      rate <- args[[2L]] / args[[1L]]
      if (!is.finite(rate) || rate <= 0) {
        .gllvmTMB_abort_prior_table("unique-variance Gamma parameters must imply a finite positive rate")
      }
    } else {
      .gllvmTMB_abort_prior_table("unsupported prior class")
    }
    list(prior = x$prior[[i]], class = cls, kind = kind, coef = coef,
         dpar = dpar, scale = scale, args = args, trait = trait,
         kernel = kernel,
         measure = if (cls == "unique_variance") "natural_sd" else NULL)
  })
  fixed <- Filter(function(row) row$class == "fixef", rows)
  if (anyDuplicated(vapply(fixed, `[[`, character(1), "coef"))) {
    .gllvmTMB_abort_prior_table("duplicate fixed-effect prior target")
  }
  loading <- Filter(function(row) row$class == "loading", rows)
  if (length(loading) > 1L) .gllvmTMB_abort_prior_table("duplicate loading prior target")
  residual_sd <- Filter(function(row) row$class == "residual_sd", rows)
  if (length(residual_sd) > 1L) .gllvmTMB_abort_prior_table("duplicate residual-SD prior target")
  unique_variance <- Filter(function(row) row$class == "unique_variance", rows)
  unique_keys <- vapply(unique_variance, function(row) {
    paste(row$kernel, row$trait, sep = "\r")
  }, character(1))
  if (anyDuplicated(unique_keys) ||
      (any(!nzchar(vapply(unique_variance, `[[`, character(1), "kernel"))) &&
       anyDuplicated(vapply(unique_variance, `[[`, character(1), "trait")))) {
    .gllvmTMB_abort_prior_table("duplicate unique-variance prior target")
  }
  rows
}

.gllvmTMB_adapt_prior_table <- function(control) {
  table <- control$prior_table
  if (is.null(table)) return(control)
  if (!is.null(control$prior_table_resolved)) {
    if (identical(control$prior_table_adapted_from, table)) return(control)
    .gllvmTMB_abort_prior_table("prior table changed after its controls were resolved")
  }
  rows <- .gllvmTMB_parse_prior_table(table)
  if (!length(rows)) {
    control$prior_table <- NULL
    control$prior_table_resolved <- NULL
    control$prior_table_adapted_from <- NULL
    return(control)
  }
  fixed <- Filter(function(row) row$class == "fixef", rows)
  loading <- Filter(function(row) row$class == "loading", rows)
  residual_sd <- Filter(function(row) row$class == "residual_sd", rows)
  unique_variance <- Filter(function(row) row$class == "unique_variance", rows)
  if (length(fixed) && !is.null(control$fixed_effect_priors)) {
    .gllvmTMB_abort_prior_table("prior table and fixed_effect_priors cannot both supply fixed-effect targets")
  }
  if (length(loading) && (isTRUE(control$loading_ridge_explicit) ||
                          isTRUE(control$aghq_ridge_explicit))) {
    .gllvmTMB_abort_prior_table("prior table and legacy loading ridge cannot both supply loading targets")
  }
  if (length(fixed)) {
    control$fixed_effect_priors <- data.frame(
      coefficient = vapply(fixed, `[[`, character(1), "coef"),
      mean = vapply(fixed, function(row) if (row$kind == "ridge") 0 else row$args[[1L]], numeric(1)),
      sd = vapply(fixed, function(row) switch(row$kind,
        normal = row$args[[2L]], student_t = row$args[[2L]],
        ridge = if (row$args[[1L]] == 0) Inf else 1 / sqrt(row$args[[1L]])), numeric(1)),
      distribution = vapply(fixed, `[[`, character(1), "kind"),
      df = vapply(fixed, function(row) if (row$kind == "student_t") row$args[[3L]] else NA_real_, numeric(1)),
      stringsAsFactors = FALSE
    )
  }
  if (length(loading)) {
    lambda <- loading[[1L]]$args[[1L]]
    tau <- if (lambda == 0) Inf else 1 / sqrt(lambda)
    control$aghq_ridge <- tau
    control$aghq_ridge_explicit <- TRUE
    control$loading_ridge <- tau
    control$loading_ridge_explicit <- TRUE
  }
  if (length(residual_sd)) {
    row <- residual_sd[[1L]]
    control$residual_sd_prior <- list(
      prior = row$prior,
      dpar = row$dpar,
      coef = row$coef,
      scale = row$scale,
      mean = row$args[[1L]],
      shape = row$args[[2L]],
      rate = row$args[[2L]] / row$args[[1L]],
      measure = "natural_sd",
      jacobian = "none"
    )
  }
  if (length(unique_variance)) {
    if (!is.null(control$kernel_psi_sd_prior)) {
      .gllvmTMB_abort_prior_table("prior table and kernel_psi_sd_prior cannot both supply unique-variance targets")
    }
    control$kernel_psi_sd_prior <- data.frame(
      kernel = vapply(unique_variance, `[[`, character(1), "kernel"),
      trait = vapply(unique_variance, `[[`, character(1), "trait"),
      shape = vapply(unique_variance, function(row) row$args[[2L]], numeric(1)),
      rate = vapply(unique_variance, function(row) row$args[[2L]] / row$args[[1L]], numeric(1)),
      stringsAsFactors = FALSE
    )
  }
  control$prior_table_resolved <- rows
  control$prior_table_adapted_from <- table
  control
}

## The exact-zero two-kernel Gaussian route is developed independently from
## this prior table. Refuse every prior/penalty there until joint compatibility
## has its own dense-Gaussian oracle and fit checks. Call from both the public
## wrapper and the lower-level fitter so internal dispatch cannot bypass it.
.gllvmTMB_guard_exact_zero_priors <- function(control, known_sigma_eps) {
  exact_zero <- is.numeric(known_sigma_eps) && length(known_sigma_eps) == 1L &&
    is.finite(known_sigma_eps) && known_sigma_eps == 0
  explicit_ridge <- !is.null(control$loading_ridge) ||
    (isTRUE(control$aghq_ridge_explicit) &&
       is.numeric(control$aghq_ridge) && length(control$aghq_ridge) == 1L &&
       is.finite(control$aghq_ridge))
  active <- (is.data.frame(control$prior_table) && nrow(control$prior_table) > 0L) ||
    length(control$prior_table_resolved %||% list()) > 0L ||
    !is.null(control$fixed_effect_priors) ||
    !is.null(control$kernel_psi_sd_prior) ||
    !is.null(control$residual_sd_prior) || explicit_ridge
  if (exact_zero && active) {
    cli::cli_abort(c(
      "Priors and penalties are not yet supported by the exact-zero observation-SD route.",
      "i" = "The two-kernel exact marginal likelihood has not been validated with prior terms.",
      ">" = "Use a positive {.arg known_sigma_eps} or remove all prior and penalty rows."
    ), class = "gllvmTMB_exact_gaussian_prior_unsupported")
  }
  invisible(NULL)
}

.gllvmTMB_residual_sd_prior_route <- function(prior, engine, estimator,
                                               REML, control) {
  if (is.null(prior)) return(invisible(NULL))
  if (!identical(engine, "tmb") || !identical(estimator, "ml") ||
      isTRUE(REML) ||
      !identical(control$integration %||% "laplace", "laplace") ||
      isTRUE(control$aghq)) {
    cli::cli_abort(c(
      "The prior-table residual-SD Gamma prior requires native TMB ML Laplace estimation with REML = FALSE.",
      "i" = "Julia, MSPL, REML, AGHQ, and variational fits are outside this slice.",
      ">" = "Use engine = 'tmb', estimator = 'ml', REML = FALSE, and integration = 'laplace'."
    ), class = "gllvmTMB_prior_table_residual_sd_route_unsupported")
  }
  invisible(NULL)
}

## Add a normalized Gamma density on the natural residual SD. The optimizer
## parameter is eta = log(sigma), but the density is with respect to d sigma;
## therefore no log-SD Jacobian is added.
.gllvmTMB_attach_residual_sd_prior <- function(obj, prior) {
  if (is.null(prior)) return(obj)
  idx <- which(names(obj$par) == "log_sigma_eps")
  if (length(idx) != 1L) {
    .gllvmTMB_abort_prior_table(
      "The prior-table residual-SD target requires exactly one free intercept-only Gaussian sigma parameter.",
      class = "gllvmTMB_prior_table_residual_sd_route_unsupported"
    )
  }
  if (!is.null(obj$residual_sd_prior)) {
    .gllvmTMB_abort_prior_table("This objective already has a residual-SD prior attached.")
  }
  shape <- prior$shape
  rate <- prior$rate
  base_fn <- obj$fn
  base_gr <- obj$gr
  base_he <- obj$he
  penalty <- function(p) {
    sigma <- exp(p[[idx]])
    -stats::dgamma(sigma, shape = shape, rate = rate, log = TRUE)
  }
  obj$fn <- function(p = obj$par, ...) base_fn(p, ...) + penalty(p)
  obj$gr <- function(p = obj$par, ...) {
    g <- base_gr(p, ...)
    sigma <- exp(p[[idx]])
    g[[idx]] <- g[[idx]] + rate * sigma - (shape - 1)
    g
  }
  if (is.function(base_he)) obj$he <- function(p = obj$par, ...) {
    H <- base_he(p, ...)
    sigma <- exp(p[[idx]])
    H[idx, idx] <- H[idx, idx] + rate * sigma
    H
  }
  obj$residual_sd_prior <- list(
    specification = prior,
    indices = idx,
    penalty = penalty,
    likelihood_fn = base_fn,
    likelihood_gr = base_gr,
    likelihood_he = base_he,
    target_class = "residual_sd",
    measure = "natural_sd",
    jacobian = "none",
    interpretation = "local_approximate_posterior_curvature_at_map",
    calibrated_sampling_covariance = FALSE
  )
  obj
}
