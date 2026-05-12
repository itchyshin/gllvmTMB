## Shared weights-shape normalisation for the three public data-entry paths.
##
## The engine always consumes a long-format per-observation vector. This
## helper keeps the user-facing shape rules in one place so `gllvmTMB()`,
## `gllvmTMB_wide()`, and `traits(...)` cannot drift apart.

normalise_weights <- function(
  weights,
  response_shape = c("long", "wide_matrix", "wide_df"),
  n_obs,
  n_units = NULL,
  n_traits = NULL,
  na_mask = NULL
) {
  response_shape <- match.arg(response_shape)
  n_obs <- .weights_count(n_obs, "n_obs")

  if (is.null(weights)) {
    return(NULL)
  }

  if (!is.numeric(weights)) {
    cli::cli_abort(c(
      "{.arg weights} must be numeric.",
      "i" = "Got class {.cls {class(weights)[1]}}."
    ))
  }

  switch(
    response_shape,
    long = .normalise_weights_long(weights, n_obs),
    wide_matrix = .normalise_weights_wide_matrix(
      weights = weights,
      n_obs = n_obs,
      n_units = n_units,
      n_traits = n_traits,
      na_mask = na_mask
    ),
    wide_df = .normalise_weights_wide_df(
      weights = weights,
      n_obs = n_obs,
      n_units = n_units,
      n_traits = n_traits,
      na_mask = na_mask
    )
  )
}

.normalise_weights_long <- function(weights, n_obs) {
  w_dim <- dim(weights)
  if (!is.null(w_dim)) {
    cli::cli_abort(c(
      "{.arg weights} must be a length-{n_obs} numeric vector in the long-format API.",
      "i" = "Got {.code dim(weights)} = c({paste(w_dim, collapse = ', ')}).",
      "i" = "For per-cell weights aligned with a wide response matrix, use {.fn gllvmTMB_wide}."
    ))
  }
  if (length(weights) != n_obs) {
    cli::cli_abort(c(
      "{.arg weights} must be a length-{n_obs} numeric vector in the long-format API.",
      "i" = "Got length {length(weights)}."
    ))
  }
  .validate_observed_weights(as.numeric(weights))
}

.normalise_weights_wide_matrix <- function(
  weights,
  n_obs,
  n_units,
  n_traits,
  na_mask = NULL
) {
  n_units <- .weights_count(n_units, "n_units")
  n_traits <- .weights_count(n_traits, "n_traits")
  mask <- .weights_na_mask(na_mask, n_units, n_traits)

  w_dim <- dim(weights)
  matrix_shape <- FALSE
  if (is.null(w_dim)) {
    if (length(weights) == 1L) {
      w_mat <- matrix(weights, nrow = n_units, ncol = n_traits)
    } else if (length(weights) == n_units) {
      w_mat <- matrix(
        rep(as.numeric(weights), times = n_traits),
        nrow = n_units,
        ncol = n_traits
      )
    } else {
      cli::cli_abort(c(
        "{.arg weights} length does not match {.arg Y} shape.",
        "i" = "Vector {.arg weights} must have length {.code nrow(Y)} ({n_units}); got length {length(weights)}.",
        "i" = "For per-cell weights pass a matrix of {.code dim(Y)}; for a single broadcast value pass a scalar."
      ))
    }
  } else if (length(w_dim) == 2L) {
    matrix_shape <- TRUE
    if (!identical(as.integer(w_dim), c(n_units, n_traits))) {
      cli::cli_abort(c(
        "{.arg weights} matrix shape must equal {.code dim(Y)}.",
        "i" = "Got {.code dim(weights)} = c({w_dim[1]}, {w_dim[2]}); expected c({n_units}, {n_traits})."
      ))
    }
    w_mat <- weights
  } else {
    cli::cli_abort(c(
      "{.arg weights} must be a vector, matrix, or scalar.",
      "i" = "Got an array with {length(w_dim)} dimensions."
    ))
  }

  if (!is.null(mask) && matrix_shape) {
    na_w <- is.na(w_mat)
    if (any(na_w & !mask)) {
      cli::cli_abort(c(
        "{.arg weights} has NA where {.arg Y} is observed.",
        "i" = "Each NA in {.arg weights} must align with an NA cell in {.arg Y}."
      ))
    }
    if (any(mask & !na_w)) {
      cli::cli_abort(c(
        "{.arg weights} has a value where {.arg Y} is NA.",
        "i" = "Each NA cell in {.arg Y} must also be NA in {.arg weights}."
      ))
    }
  }

  observed <- if (is.null(mask)) {
    rep(TRUE, n_units * n_traits)
  } else {
    !as.numeric(mask)
  }
  w_long <- as.numeric(w_mat)[observed]
  if (length(w_long) != n_obs) {
    cli::cli_abort(c(
      "Internal weights normalisation error.",
      "i" = "Expected {n_obs} observed weights; got {length(w_long)}."
    ))
  }
  .validate_observed_weights(w_long)
}

.normalise_weights_wide_df <- function(
  weights,
  n_obs,
  n_units,
  n_traits,
  na_mask = NULL
) {
  n_units <- .weights_count(n_units, "n_units")
  n_traits <- .weights_count(n_traits, "n_traits")
  mask <- .weights_na_mask(na_mask, n_units, n_traits)

  w_dim <- dim(weights)
  if (!is.null(w_dim)) {
    cli::cli_abort(c(
      "{.arg weights} must be NULL or a length-{n_units} numeric vector when using {.fn traits} on the formula LHS.",
      "i" = "For per-cell weight matrices use {.fn gllvmTMB_wide}; the matrix-in entry point is the only place per-cell weights are supported."
    ))
  }
  if (length(weights) != n_units) {
    cli::cli_abort(c(
      "{.arg weights} must be NULL or a length-{n_units} numeric vector when using {.fn traits} on the formula LHS.",
      "i" = "Got length {length(weights)}.",
      "i" = "For per-cell weight matrices use {.fn gllvmTMB_wide}."
    ))
  }

  observed <- if (is.null(mask)) {
    rep(TRUE, n_units * n_traits)
  } else {
    !as.vector(t(mask))
  }
  w_long <- rep(as.numeric(weights), each = n_traits)[observed]
  if (length(w_long) != n_obs) {
    cli::cli_abort(c(
      "Internal weights normalisation error.",
      "i" = "Expected {n_obs} observed weights; got {length(w_long)}."
    ))
  }
  .validate_observed_weights(w_long)
}

.validate_observed_weights <- function(weights) {
  if (length(weights) > 0L) {
    if (any(!is.finite(weights))) {
      cli::cli_abort("{.arg weights} must be finite at observed cells.")
    }
    if (any(weights < 0)) {
      cli::cli_abort("{.arg weights} must be non-negative.")
    }
  }
  as.numeric(weights)
}

.weights_count <- function(x, arg_name) {
  if (is.null(x) || length(x) != 1L || is.na(x) || x < 0) {
    cli::cli_abort(
      "Internal error: {.arg {arg_name}} must be a non-negative scalar."
    )
  }
  as.integer(x)
}

.weights_na_mask <- function(na_mask, n_units, n_traits) {
  if (is.null(na_mask)) {
    return(NULL)
  }
  mask <- as.matrix(na_mask)
  if (!identical(dim(mask), c(n_units, n_traits))) {
    cli::cli_abort(c(
      "Internal error: {.arg na_mask} must have the response shape.",
      "i" = "Got {.code dim(na_mask)} = c({paste(dim(mask), collapse = ', ')}); expected c({n_units}, {n_traits})."
    ))
  }
  if (!is.logical(mask)) {
    mask <- matrix(as.logical(mask), nrow = n_units, ncol = n_traits)
  }
  if (anyNA(mask)) {
    cli::cli_abort("Internal error: {.arg na_mask} cannot contain NA.")
  }
  mask
}
