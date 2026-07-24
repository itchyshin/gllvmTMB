root <- normalizePath(file.path(getwd()), mustWork = TRUE)
if (!file.exists(file.path(root, "R", "charts.R"))) {
  root <- normalizePath(
    file.path(root, "dev", "design99-exact-reference"),
    mustWork = TRUE
  )
}
source(file.path(root, "R", "charts.R"))
source(file.path(root, "R", "fixture.R"))
source(file.path(root, "R", "optimizers.R"))

near <- function(x, y, tol, label) {
  err <- max(abs(x - y))
  if (!is.finite(err) || err > tol) {
    stop(sprintf("%s: %.17g > %.17g", label, err, tol), call. = FALSE)
  }
}

truth <- list(
  beta = c(-.40, -.15, .05, .20, .35, .50),
  Lambda = rbind(
    c(.50, .10),
    c(.20, .45),
    c(-.30, .25),
    c(.20, -.55),
    c(.30, .35),
    c(-.25, -.30)
  )
)
for (chart in c("C12", "C34")) {
  for (cap in c(4, 8)) {
    theta <- d99_chart_pack(truth$beta, truth$Lambda, chart, cap)
    value <- d99_chart_unpack(theta, chart, cap)
    near(value$beta, truth$beta, 1e-12, paste(chart, cap, "beta round trip"))
    near(
      tcrossprod(value$Lambda),
      tcrossprod(truth$Lambda),
      1e-12,
      paste(chart, cap, "Sigma round trip")
    )
    xi <- d99_chart_to_xi(theta, chart, cap)
    near(
      d99_chart_from_xi(xi, chart, cap),
      theta,
      1e-12,
      paste(chart, cap, "chart xi round trip")
    )
    J <- d99_chart_jacobian(theta, chart, cap)
    coef <- seq_len(18L) / 19
    analytic <- drop(crossprod(J, coef))
    numeric <- d99_symmetric_gradient(
      function(z) {
        sum(
          c(
            d99_chart_unpack(z, chart, cap)$beta,
            as.vector(t(d99_chart_unpack(z, chart, cap)$Lambda))
          ) *
            coef
        )
      },
      theta
    )
    near(analytic, numeric, 1e-6, paste(chart, cap, "chain Jacobian"))
    xi_jacobian <- d99_xi_jacobian(xi, chart, cap)
    numeric_xi <- d99_symmetric_gradient(
      function(z) {
        unpacked <- d99_chart_unpack(
          d99_chart_from_xi(z, chart, cap),
          chart,
          cap
        )
        sum(c(unpacked$beta, as.vector(t(unpacked$Lambda))) * coef)
      },
      xi
    )
    near(
      drop(crossprod(xi_jacobian, coef)),
      numeric_xi,
      1e-6,
      paste(chart, cap, "xi chain Jacobian")
    )
    if (!isTRUE(d99_chart_interior(theta, chart, cap)$ok)) {
      stop("Truth chart coordinate should be interior.", call. = FALSE)
    }
  }
}

set.seed(101)
synthetic_y <- matrix(
  rbinom(48L * 6L, size = 1L, prob = .45),
  nrow = 48L,
  ncol = 6L
)
codes <- d99_fixture_pattern_code(synthetic_y)
near(
  d99_fixture_decode_pattern(codes),
  synthetic_y,
  0,
  "synthetic pattern coding"
)
counts <- d99_fixture_pattern_counts(synthetic_y)
if (sum(counts) != nrow(synthetic_y) || length(counts) != 64L) {
  stop("Pattern compression did not retain all 64 cells.", call. = FALSE)
}

starts_a <- d99_starts(synthetic_y)
starts_b <- d99_starts(synthetic_y)
near(
  starts_a$spectral$Lambda,
  starts_b$spectral$Lambda,
  0,
  "spectral start determinism"
)
if (!identical(d99_start_hashes(synthetic_y), d99_start_hashes(synthetic_y))) {
  stop("Start hashes are not deterministic.", call. = FALSE)
}
for (chart in c("C12", "C34")) {
  for (cap in c(4, 8)) {
    theta_start <- d99_start_coordinates(synthetic_y, chart, cap)
    if (!identical(names(theta_start), c("fixed", "spectral", "truth"))) {
      stop("Frozen start names changed.", call. = FALSE)
    }
    if (any(vapply(theta_start, length, integer(1)) != 17L)) {
      stop("Frozen starts must have 17 coordinates.", call. = FALSE)
    }
    stress <- d99_stress_coordinates(chart, cap, base = truth)
    if (length(stress) != 17L || any(!is.finite(stress))) {
      stop("Stress coordinate is malformed.", call. = FALSE)
    }
  }
}

cat("gate1-charts: PASS (synthetic NON_EVIDENCE only)\n")
