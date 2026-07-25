# Design-100-B private direct-2D worker kernel.
#
# This source is intentionally inert: it defines one fixed direct quadrature
# kernel but does not read a fixture, create a UUID, launch a process, write a
# record, optimize, or select an information ladder.  A separately approved
# launcher must bind an input manifest and the receipt contract before calling
# d100b_direct2d_evaluate().

d100b_direct2d_coordinate_rule <- function() {
  # Ordered nodes and normalized N(0, 1) weights for the one fixed H = 5 rule.
  # Tensor enumeration is column-major; the first coordinate varies fastest.
  list(
    rule_id = "normal-gh5-original-u-v1",
    nodes = c(
      -2.8569700138728056, -1.3556261799742660, 0,
      1.3556261799742660, 2.8569700138728056
    ),
    weights = c(
      0.0112574113277207, 0.2220759220056136, 0.5333333333333333,
      0.2220759220056136, 0.0112574113277207
    )
  )
}

d100b_direct2d_pattern_set <- function() {
  # These are fixed response-pattern definitions only: no counts, parameters,
  # fitted values, seed, UUID, or realised fixture is present in this source.
  list(
    list(pattern_id = "pattern-001", code = 0L, bits = c(0L, 0L, 0L, 0L, 0L, 0L)),
    list(pattern_id = "pattern-002", code = 21L, bits = c(0L, 1L, 0L, 1L, 0L, 1L)),
    list(pattern_id = "pattern-003", code = 42L, bits = c(1L, 0L, 1L, 0L, 1L, 0L)),
    list(pattern_id = "pattern-004", code = 63L, bits = c(1L, 1L, 1L, 1L, 1L, 1L))
  )
}

d100b_softplus <- function(x) {
  pmax(x, 0) + log1p(exp(-abs(x)))
}

d100b_validate_theta <- function(theta) {
  if (!is.list(theta) || !identical(sort(names(theta)), c("beta", "lambda"))) {
    stop("theta must contain exactly beta and lambda", call. = FALSE)
  }
  beta <- theta$beta
  lambda <- theta$lambda
  if (!is.numeric(beta) || length(beta) != 6L || any(!is.finite(beta)) ||
      !is.matrix(lambda) || !is.numeric(lambda) ||
      !identical(dim(lambda), c(6L, 2L)) || any(!is.finite(lambda))) {
    stop("theta must be finite beta[6] and lambda[6, 2]", call. = FALSE)
  }
  list(beta = as.numeric(beta), lambda = unclass(lambda))
}

d100b_pattern_by_id <- function(pattern_id) {
  patterns <- d100b_direct2d_pattern_set()
  found <- vapply(patterns, function(pattern) identical(pattern$pattern_id, pattern_id), logical(1))
  if (sum(found) != 1L) stop("unknown frozen Design-100-B pattern", call. = FALSE)
  patterns[[which(found)]]
}

#' Evaluate exactly one frozen direct-2D pattern integral.
#'
#' This is a private numerical kernel, not an optimiser or likelihood API.
#' It uses the fixed original-u 5 x 5 rule and returns one pattern probability.
#' A caller must have passed the separately approved launch/receipt gate before
#' this function can be reached; that gate is deliberately not created here.
d100b_direct2d_evaluate <- function(theta, pattern_id) {
  theta <- d100b_validate_theta(theta)
  pattern <- d100b_pattern_by_id(pattern_id)
  rule <- d100b_direct2d_coordinate_rule()
  grid <- expand.grid(u1 = rule$nodes, u2 = rule$nodes, KEEP.OUT.ATTRS = FALSE)
  weights <- as.vector(outer(rule$weights, rule$weights))
  log_kernel <- vapply(seq_len(nrow(grid)), function(row) {
    u <- c(grid$u1[[row]], grid$u2[[row]])
    eta <- theta$beta + as.vector(theta$lambda %*% u)
    sum(pattern$bits * eta - d100b_softplus(eta))
  }, numeric(1))
  probability <- sum(weights * exp(log_kernel))
  if (!is.finite(probability) || probability <= 0 || probability >= 1) {
    stop("direct-2D pattern probability is outside (0, 1)", call. = FALSE)
  }
  list(
    worker_id = "direct-2d-original-u-v1",
    rule_id = rule$rule_id,
    pattern_id = pattern$pattern_id,
    pattern_code = pattern$code,
    probability = probability,
    log_probability = log(probability)
  )
}

d100b_direct2d_worker_description <- function() {
  list(
    worker_id = "direct-2d-original-u-v1",
    dimension = 2L,
    coordinate_system = "original_u",
    rule = d100b_direct2d_coordinate_rule(),
    patterns = vapply(d100b_direct2d_pattern_set(), `[[`, character(1), "pattern_id"),
    scope = "one pattern probability only; no fixture, optimizer, ladder, or record writing"
  )
}
