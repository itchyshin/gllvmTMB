d99_chart_spec <- function(chart = c("C12", "C34"), cap = c(4, 8)) {
  chart <- match.arg(chart)
  cap <- as.numeric(cap)[1L]
  if (!cap %in% c(4, 8)) {
    stop("Design 99 permits only cap4 or cap8.", call. = FALSE)
  }
  anchors <- if (identical(chart, "C12")) c(1L, 2L) else c(3L, 4L)
  list(
    chart = chart,
    cap = cap,
    anchors = anchors,
    free_angles = setdiff(seq_len(6L), anchors)
  )
}

d99_logit <- function(x) {
  if (any(!is.finite(x) | x <= 0 | x >= 1)) {
    stop("logit input must be strictly inside (0, 1).", call. = FALSE)
  }
  log(x) - log1p(-x)
}

d99_inv_logit <- function(x) plogis(x)

d99_atanh_strict <- function(x) {
  if (any(!is.finite(x) | abs(x) >= 1)) {
    stop("atanh input must be strictly inside (-1, 1).", call. = FALSE)
  }
  0.5 * (log1p(x) - log1p(-x))
}

d99_chart_unpack <- function(theta, chart = c("C12", "C34"), cap = c(4, 8)) {
  spec <- d99_chart_spec(chart, cap)
  theta <- as.numeric(theta)
  if (length(theta) != 17L || any(!is.finite(theta))) {
    stop("A Design-99 chart coordinate has 17 finite entries.", call. = FALSE)
  }
  b <- theta[seq_len(6L)]
  rho <- theta[6L + seq_len(6L)]
  gamma <- theta[12L + seq_len(5L)]
  beta <- 6 * tanh(b / 6)
  radius <- spec$cap * plogis(rho)
  alpha <- numeric(6L)
  alpha[spec$anchors[1L]] <- 0
  alpha[spec$anchors[2L]] <- pi * plogis(gamma[1L])
  alpha[spec$free_angles] <- pi * tanh(gamma[-1L])
  Lambda <- cbind(radius * cos(alpha), radius * sin(alpha))
  list(
    beta = beta,
    Lambda = Lambda,
    radius = radius,
    alpha = alpha,
    theta = theta,
    chart = spec$chart,
    cap = spec$cap,
    anchors = spec$anchors,
    free_angles = spec$free_angles
  )
}

d99_chart_align <- function(Lambda, chart = c("C12", "C34"), tol = 1e-12) {
  spec <- d99_chart_spec(chart)
  Lambda <- as.matrix(Lambda)
  if (!identical(dim(Lambda), c(6L, 2L)) || any(!is.finite(Lambda))) {
    stop("Lambda must be a finite 6 by 2 matrix.", call. = FALSE)
  }
  a <- spec$anchors[1L]
  b <- spec$anchors[2L]
  radius_a <- sqrt(sum(Lambda[a, ]^2))
  minor <- det(Lambda[c(a, b), , drop = FALSE])
  if (radius_a <= tol || abs(minor) <= tol) {
    stop("The requested ordered anchor pair is singular.", call. = FALSE)
  }
  e1 <- Lambda[a, ] / radius_a
  e2 <- c(-e1[2L], e1[1L])
  if (sum(Lambda[b, ] * e2) <= tol) {
    e2 <- -e2
  }
  R <- cbind(e1, e2)
  aligned <- Lambda %*% R
  if (
    aligned[a, 1L] <= tol ||
      abs(aligned[a, 2L]) > 100 * tol ||
      aligned[b, 2L] <= tol
  ) {
    stop("Anchor alignment failed.", call. = FALSE)
  }
  list(Lambda = aligned, rotation = R, minor = minor, anchors = spec$anchors)
}

d99_chart_pack <- function(
  beta,
  Lambda,
  chart = c("C12", "C34"),
  cap = c(4, 8),
  tol = 1e-12
) {
  spec <- d99_chart_spec(chart, cap)
  beta <- as.numeric(beta)
  if (length(beta) != 6L || any(!is.finite(beta)) || any(abs(beta) >= 6)) {
    stop("beta must be finite and strictly inside (-6, 6).", call. = FALSE)
  }
  aligned <- d99_chart_align(Lambda, spec$chart, tol = tol)$Lambda
  radius <- sqrt(rowSums(aligned^2))
  if (any(radius <= tol) || any(radius >= spec$cap)) {
    stop("Loading radii must be strictly inside (0, cap).", call. = FALSE)
  }
  alpha <- atan2(aligned[, 2L], aligned[, 1L])
  a <- spec$anchors[1L]
  b <- spec$anchors[2L]
  alpha[a] <- 0
  if (alpha[b] <= tol || alpha[b] >= pi - tol) {
    stop(
      "The ordered anchor angle is not strictly inside (0, pi).",
      call. = FALSE
    )
  }
  free <- alpha[spec$free_angles]
  if (any(abs(free) >= pi - tol)) {
    stop(
      "A free loading angle is outside its open chart interval.",
      call. = FALSE
    )
  }
  b_coord <- 6 * d99_atanh_strict(beta / 6)
  rho <- d99_logit(radius / spec$cap)
  gamma_b <- d99_logit(alpha[b] / pi)
  gamma_free <- d99_atanh_strict(free / pi)
  c(b_coord, rho, gamma_b, gamma_free)
}

d99_chart_to_xi <- function(theta, chart = c("C12", "C34"), cap = c(4, 8)) {
  x <- d99_chart_unpack(theta, chart, cap)
  c(x$beta, log(x$radius), x$alpha[x$anchors[2L]], x$alpha[x$free_angles])
}

d99_chart_from_xi <- function(xi, chart = c("C12", "C34"), cap = c(4, 8)) {
  spec <- d99_chart_spec(chart, cap)
  xi <- as.numeric(xi)
  if (length(xi) != 17L || any(!is.finite(xi))) {
    stop("xi must have 17 finite entries.", call. = FALSE)
  }
  beta <- xi[seq_len(6L)]
  radius <- exp(xi[6L + seq_len(6L)])
  alpha <- numeric(6L)
  alpha[spec$anchors[1L]] <- 0
  alpha[spec$anchors[2L]] <- xi[13L]
  alpha[spec$free_angles] <- xi[13L + seq_along(spec$free_angles)]
  Lambda <- cbind(radius * cos(alpha), radius * sin(alpha))
  d99_chart_pack(beta, Lambda, spec$chart, spec$cap)
}

d99_chart_jacobian <- function(theta, chart = c("C12", "C34"), cap = c(4, 8)) {
  x <- d99_chart_unpack(theta, chart, cap)
  J <- matrix(0, nrow = 18L, ncol = 17L)
  J[cbind(seq_len(6L), seq_len(6L))] <- 1 - tanh(theta[seq_len(6L)] / 6)^2
  rho <- theta[6L + seq_len(6L)]
  dr <- x$cap * plogis(rho) * (1 - plogis(rho))
  gamma <- theta[13L:17L]
  dalpha <- c(
    pi * plogis(gamma[1L]) * (1 - plogis(gamma[1L])),
    pi * (1 - tanh(gamma[-1L])^2)
  )
  for (t in seq_len(6L)) {
    rows <- 6L + (2L * t - 1L:0L)
    # Row-major loading-score order: lambda_t1 then lambda_t2.
    J[rows, 6L + t] <- dr[t] * c(cos(x$alpha[t]), sin(x$alpha[t]))
    angle_col <- if (t == x$anchors[1L]) {
      NA_integer_
    } else {
      12L + if (t == x$anchors[2L]) 1L else 1L + match(t, x$free_angles)
    }
    if (!is.na(angle_col)) {
      J[rows, angle_col] <- x$radius[t] *
        c(-sin(x$alpha[t]), cos(x$alpha[t])) *
        dalpha[angle_col - 12L]
    }
  }
  J
}

d99_xi_jacobian <- function(xi, chart = c("C12", "C34"), cap = c(4, 8)) {
  spec <- d99_chart_spec(chart, cap)
  theta <- d99_chart_from_xi(xi, spec$chart, spec$cap)
  x <- d99_chart_unpack(theta, spec$chart, spec$cap)
  J <- matrix(0, nrow = 18L, ncol = 17L)
  J[cbind(seq_len(6L), seq_len(6L))] <- 1
  for (t in seq_len(6L)) {
    rows <- 6L + (2L * t - 1L:0L)
    J[rows, 6L + t] <- x$Lambda[t, ]
    angle_col <- if (t == spec$anchors[1L]) {
      NA_integer_
    } else {
      12L + if (t == spec$anchors[2L]) 1L else 1L + match(t, spec$free_angles)
    }
    if (!is.na(angle_col)) {
      J[rows, angle_col] <- x$radius[t] *
        c(-sin(x$alpha[t]), cos(x$alpha[t]))
    }
  }
  J
}

d99_chart_log_jacobian <- function(
  theta,
  chart = c("C12", "C34"),
  cap = c(4, 8)
) {
  x <- d99_chart_unpack(theta, chart, cap)
  beta_deriv <- 1 - tanh(theta[seq_len(6L)] / 6)^2
  # These are rho -> log(r), not rho -> r, derivatives.
  rho_deriv <- 1 - plogis(theta[7L:12L])
  gamma <- theta[13L:17L]
  alpha_deriv <- c(
    pi * plogis(gamma[1L]) * (1 - plogis(gamma[1L])),
    pi * (1 - tanh(gamma[-1L])^2)
  )
  # determinant for chart -> (beta, log radius, free angles); useful and stable.
  sum(log(beta_deriv)) + sum(log(rho_deriv)) + sum(log(alpha_deriv))
}

d99_chart_roundtrip <- function(
  beta,
  Lambda,
  chart = c("C12", "C34"),
  cap = c(4, 8),
  tol = 1e-12
) {
  theta <- d99_chart_pack(beta, Lambda, chart, cap)
  x <- d99_chart_unpack(theta, chart, cap)
  list(
    theta = theta,
    beta_error = max(abs(beta - x$beta)),
    sigma_error = max(abs(tcrossprod(Lambda) - tcrossprod(x$Lambda))),
    value = x
  )
}

d99_chart_interior <- function(theta, chart = c("C12", "C34"), cap = c(4, 8)) {
  x <- d99_chart_unpack(theta, chart, cap)
  list(
    ok = max(abs(x$beta)) < 4.8 &&
      max(x$radius) < 3.2 &&
      min(x$radius) > 0.02 &&
      sin(x$alpha[x$anchors[2L]]) > 0.05 &&
      max(abs(theta)) < 12,
    max_abs_beta = max(abs(x$beta)),
    max_radius = max(x$radius),
    min_radius = min(x$radius),
    anchor_sine = sin(x$alpha[x$anchors[2L]]),
    max_abs_theta = max(abs(theta))
  )
}

d99_invariants <- function(beta, Lambda, gh = NULL) {
  ans <- list(
    beta = as.numeric(beta),
    Sigma = tcrossprod(Lambda),
    eig_positive = sort(
      eigen(tcrossprod(Lambda), symmetric = TRUE, only.values = TRUE)$values,
      decreasing = TRUE
    )[1:2]
  )
  if (!is.null(gh)) {
    ans$population_probability <- d99_population_probability(beta, Lambda, gh)
  }
  ans
}

d99_population_probability <- function(beta, Lambda, gh) {
  nodes <- gh$nodes
  weights <- gh$weights
  grid <- expand.grid(z1 = nodes, z2 = nodes, KEEP.OUT.ATTRS = FALSE)
  weights2 <- rep(weights, times = length(weights)) *
    rep(weights, each = length(weights))
  eta <- grid[[1L]] %o% Lambda[, 1L] + grid[[2L]] %o% Lambda[, 2L]
  colSums(plogis(sweep(eta, 2L, beta, "+")) * weights2)
}

d99_invariant_agreement <- function(left, right, gh = NULL) {
  a <- if (!is.null(left$Sigma)) {
    left
  } else {
    d99_invariants(left$beta, left$Lambda, gh)
  }
  b <- if (!is.null(right$Sigma)) {
    right
  } else {
    d99_invariants(right$beta, right$Lambda, gh)
  }
  out <- list(
    beta_max = max(abs(a$beta - b$beta)),
    Sigma_max = max(abs(a$Sigma - b$Sigma)),
    eigen_max = max(abs(a$eig_positive - b$eig_positive))
  )
  if (
    !is.null(a$population_probability) && !is.null(b$population_probability)
  ) {
    out$population_probability_max <- max(abs(
      a$population_probability - b$population_probability
    ))
  }
  out
}

d99_pairwise_invariant_metrics <- function(endpoints) {
  if (length(endpoints) < 2L) {
    return(list(
      beta_max = 0,
      Sigma_max = 0,
      eigen_max = 0,
      population_probability_max = 0
    ))
  }
  pairs <- utils::combn(seq_along(endpoints), 2L)
  metrics <- apply(pairs, 2L, function(index) {
    value <- d99_invariant_agreement(
      endpoints[[index[1L]]],
      endpoints[[index[2L]]]
    )
    c(
      beta_max = value$beta_max,
      Sigma_max = value$Sigma_max,
      eigen_max = value$eigen_max,
      population_probability_max = if (
        is.null(value$population_probability_max)
      ) {
        NA_real_
      } else {
        value$population_probability_max
      }
    )
  })
  apply(metrics, 1L, function(value) {
    if (any(!is.finite(value))) Inf else max(value)
  })
}
