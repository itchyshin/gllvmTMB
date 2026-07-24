d99_softplus <- function(x) {
  if (any(!is.finite(x))) {
    stop("`x` must be finite.", call. = FALSE)
  }
  pmax(x, 0) + log1p(exp(-abs(x)))
}

d99_logsumexp <- function(x) {
  if (!length(x) || any(is.na(x)) || any(x == Inf)) {
    stop(
      "`x` must be a non-empty numeric vector without NA or +Inf.",
      call. = FALSE
    )
  }
  maximum <- max(x)
  if (is.infinite(maximum)) {
    return(-Inf)
  }
  maximum + log(sum(exp(x - maximum)))
}

d99_sha256 <- function(x) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop(
      "Package `digest` is required for quadrature checksums.",
      call. = FALSE
    )
  }
  digest::digest(
    serialize(x, NULL, version = 2),
    algo = "sha256",
    serialize = FALSE
  )
}

d99_gh_rule <- function(order) {
  if (
    length(order) != 1L ||
      !is.finite(order) ||
      order < 1L ||
      order != as.integer(order)
  ) {
    stop("`order` must be one positive integer.", call. = FALSE)
  }
  if (!requireNamespace("statmod", quietly = TRUE)) {
    stop(
      "Package `statmod` is required for normalized Gaussian-Hermite rules.",
      call. = FALSE
    )
  }
  raw_rule <- statmod::gauss.quad.prob(as.integer(order), dist = "normal")
  permutation <- order(raw_rule$nodes)
  nodes <- as.numeric(raw_rule$nodes[permutation])
  weights <- as.numeric(raw_rule$weights[permutation])
  rule <- list(
    order = as.integer(order),
    nodes = nodes,
    weights = weights,
    node_hash = d99_sha256(nodes),
    weight_hash = d99_sha256(weights)
  )
  tensor <- d99_gh_tensor(rule)
  rule$tensor_hash <- d99_sha256(tensor$nodes)
  rule$tensor_order <- "first-coordinate-fastest"
  d99_validate_gh(rule)
  rule
}

d99_validate_gh <- function(gh, order = NULL) {
  required <- c("order", "nodes", "weights")
  if (!is.list(gh) || !all(required %in% names(gh))) {
    stop("`gh` must contain `order`, `nodes`, and `weights`.", call. = FALSE)
  }
  H <- gh$order
  if (length(H) != 1L || !is.finite(H) || H < 1L || H != as.integer(H)) {
    stop("`gh$order` must be one positive integer.", call. = FALSE)
  }
  H <- as.integer(H)
  if (!is.null(order) && !identical(H, as.integer(order))) {
    stop("`gh$order` does not match the requested order.", call. = FALSE)
  }
  nodes <- as.numeric(gh$nodes)
  weights <- as.numeric(gh$weights)
  if (
    length(nodes) != H ||
      length(weights) != H ||
      any(!is.finite(nodes)) ||
      any(!is.finite(weights))
  ) {
    stop(
      "Quadrature nodes and weights must be finite vectors of length `order`.",
      call. = FALSE
    )
  }
  if (
    any(diff(nodes) <= 0) || any(weights <= 0) || abs(sum(weights) - 1) > 1e-13
  ) {
    stop(
      "Quadrature rule must have ascending nodes, positive weights, and unit weight sum.",
      call. = FALSE
    )
  }
  if (!is.null(gh$node_hash) && !identical(gh$node_hash, d99_sha256(nodes))) {
    stop("Quadrature node checksum mismatch.", call. = FALSE)
  }
  if (
    !is.null(gh$weight_hash) && !identical(gh$weight_hash, d99_sha256(weights))
  ) {
    stop("Quadrature weight checksum mismatch.", call. = FALSE)
  }
  tensor <- d99_gh_tensor(list(order = H, nodes = nodes, weights = weights))
  if (
    !is.null(gh$tensor_hash) &&
      !identical(gh$tensor_hash, d99_sha256(tensor$nodes))
  ) {
    stop("Quadrature tensor checksum mismatch.", call. = FALSE)
  }
  if (
    !is.null(gh$tensor_order) &&
      !identical(gh$tensor_order, "first-coordinate-fastest")
  ) {
    stop(
      "Quadrature tensor order must be first-coordinate-fastest.",
      call. = FALSE
    )
  }
  invisible(list(order = H, nodes = nodes, weights = weights, tensor = tensor))
}

d99_gh_tensor <- function(gh) {
  H <- as.integer(gh$order)
  list(
    nodes = cbind(
      rep(as.numeric(gh$nodes), H),
      rep(as.numeric(gh$nodes), each = H)
    ),
    log_weights = rep(log(as.numeric(gh$weights)), H) +
      rep(log(as.numeric(gh$weights)), each = H),
    weights = rep(as.numeric(gh$weights), H) *
      rep(as.numeric(gh$weights), each = H)
  )
}

d99_pattern_matrix <- function() {
  codes <- 0:63
  vapply(
    5:0,
    function(power) as.integer((codes %/% (2^power)) %% 2L),
    integer(64L)
  )
}

d99_pattern_code <- function(y) {
  y <- as.matrix(y)
  storage.mode(y) <- "double"
  if (ncol(y) != 6L || any(!is.finite(y)) || any(y != 0 & y != 1)) {
    stop("`y` must be a finite binary matrix with six columns.", call. = FALSE)
  }
  as.integer(y %*% (2^(5:0)))
}

d99_pattern_counts <- function(y) {
  tabulate(d99_pattern_code(y) + 1L, nbins = 64L)
}

d99_validate_counts <- function(counts) {
  if (
    length(counts) != 64L ||
      any(!is.finite(counts)) ||
      any(counts < 0) ||
      any(counts != round(counts))
  ) {
    stop(
      "`counts` must be a non-negative integer vector of length 64.",
      call. = FALSE
    )
  }
  as.numeric(counts)
}

d99_validate_parameters <- function(beta, Lambda) {
  if (length(beta) != 6L || any(!is.finite(beta))) {
    stop("`beta` must be a finite vector of length six.", call. = FALSE)
  }
  Lambda <- as.matrix(Lambda)
  storage.mode(Lambda) <- "double"
  if (!identical(dim(Lambda), c(6L, 2L)) || any(!is.finite(Lambda))) {
    stop("`Lambda` must be a finite 6 by 2 matrix.", call. = FALSE)
  }
  list(beta = as.numeric(beta), Lambda = Lambda)
}
