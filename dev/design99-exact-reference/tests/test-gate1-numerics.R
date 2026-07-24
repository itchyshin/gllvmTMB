root <- normalizePath("dev/design99-exact-reference", mustWork = TRUE)
source(file.path(root, "R", "numerics.R"))
source(file.path(root, "R", "aghq.R"))
source(file.path(root, "R", "independent-oracle.R"))

d99_expect_error_message <- function(expr, pattern) {
  captured <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
  testthat::expect_s3_class(captured, "error")
  testthat::expect_match(conditionMessage(captured), pattern)
}

d99_test_parameters <- function() {
  list(
    beta = c(-0.6, -0.25, -0.05, 0.15, 0.4, 0.65),
    Lambda = rbind(
      c(0.7, 0),
      c(0.15, 0.55),
      c(-0.45, 0.2),
      c(0.2, -0.6),
      c(0.18, 0.42),
      c(-0.3, -0.35)
    )
  )
}

d99_test_counts <- function() {
  counts <- rep(0, 64)
  counts[c(1L, 3L, 8L, 19L, 34L, 64L)] <- c(7, 4, 3, 8, 5, 2)
  counts
}

d99_test_variant_log_prob <- function(
  y,
  beta,
  Lambda,
  gh,
  prior_constant = TRUE,
  normal_ratio = TRUE,
  jacobian = TRUE,
  node_multiplier = 1
) {
  mode <- d99_conditional_mode(y, beta, Lambda)
  R <- chol(mode$Q)
  A <- t(chol(solve(mode$Q)))
  tensor <- d99_gh_tensor(gh)
  z <- tensor$nodes * node_multiplier
  u <- sweep(z %*% t(A), 2L, mode$u, "+")
  eta <- sweep(u %*% t(Lambda), 2L, beta, "+")
  log_kernel <- rowSums(sweep(eta, 2L, y, "*") - d99_softplus(eta)) -
    0.5 * rowSums(u^2)
  if (prior_constant) {
    log_kernel <- log_kernel - log(2 * pi)
  }
  correction <- if (normal_ratio) log(2 * pi) + 0.5 * rowSums(z^2) else 0
  if (jacobian) {
    correction <- correction - sum(log(diag(R)))
  }
  d99_logsumexp(tensor$log_weights + log_kernel + correction)
}

d99_test_direct_adaptive_log_prob <- function(y, beta, Lambda, gh) {
  mode <- d99_conditional_mode(y, beta, Lambda)
  R <- chol(mode$Q)
  A <- t(chol(solve(mode$Q)))
  tensor <- d99_gh_tensor(gh)
  out <- vapply(
    seq_len(nrow(tensor$nodes)),
    function(i) {
      z <- tensor$nodes[i, ]
      u <- mode$u + as.numeric(A %*% z)
      d99_log_kernel(u, y, beta, Lambda) +
        log(2 * pi) +
        0.5 * sum(z^2) -
        sum(log(diag(R))) +
        tensor$log_weights[i]
    },
    numeric(1)
  )
  d99_logsumexp(out)
}

d99_test_gaussian_integral <- function(
  gh,
  centre = c(0.3, -0.4),
  Q = matrix(c(2.1, 0.25, 0.25, 1.6), 2)
) {
  R <- chol(Q)
  A <- t(chol(solve(Q)))
  tensor <- d99_gh_tensor(gh)
  u <- sweep(tensor$nodes %*% t(A), 2L, centre, "+")
  log_kernel <- -0.5 *
    rowSums(
      (u - matrix(centre, nrow(u), 2, byrow = TRUE)) *
        ((u - matrix(centre, nrow(u), 2, byrow = TRUE)) %*% Q)
    )
  d99_logsumexp(
    tensor$log_weights +
      log_kernel +
      log(2 * pi) +
      0.5 * rowSums(tensor$nodes^2) -
      sum(log(diag(R)))
  )
}

testthat::test_that("normalized Gaussian-Hermite rules meet frozen moments and tensor order", {
  for (H in c(9L, 15L, 21L, 31L)) {
    gh <- d99_gh_rule(H)
    testthat::expect_equal(sum(gh$weights), 1, tolerance = 1e-14)
    testthat::expect_equal(sum(gh$weights * gh$nodes), 0, tolerance = 1e-14)
    testthat::expect_equal(sum(gh$weights * gh$nodes^2), 1, tolerance = 1e-13)
    tensor <- d99_gh_tensor(gh)
    testthat::expect_equal(
      tensor$nodes[1, ],
      rep(gh$nodes[1], 2L),
      tolerance = 0
    )
    testthat::expect_equal(
      tensor$nodes[2, ],
      c(gh$nodes[2], gh$nodes[1]),
      tolerance = 0
    )
    testthat::expect_equal(sum(tensor$weights), 1, tolerance = 1e-14)
    testthat::expect_identical(gh$tensor_order, "first-coordinate-fastest")
  }
})

testthat::test_that("softplus, Gaussian transformation, and independent objective agree", {
  parameters <- d99_test_parameters()
  gh <- d99_gh_rule(31L)
  testthat::expect_equal(
    d99_softplus(c(-1000, 0, 1000)),
    c(0, log(2), 1000),
    tolerance = 1e-12
  )
  testthat::expect_equal(
    d99_test_gaussian_integral(gh),
    log(2 * pi) - 0.5 * log(det(matrix(c(2.1, 0.25, 0.25, 1.6), 2))),
    tolerance = 1e-12
  )
  y <- d99_pattern_matrix()[42L, ]
  testthat::expect_equal(
    d99_aghq_pattern(y, parameters$beta, parameters$Lambda, gh)$log_prob,
    d99_test_direct_adaptive_log_prob(
      y,
      parameters$beta,
      parameters$Lambda,
      gh
    ),
    tolerance = 1e-11
  )
})

testthat::test_that("pattern coding is frozen, compressed, and permutation invariant", {
  patterns <- d99_pattern_matrix()
  testthat::expect_equal(d99_pattern_code(patterns), 0:63, tolerance = 0)
  set.seed(19)
  y <- patterns[sample.int(64L, 137L, replace = TRUE), , drop = FALSE]
  counts <- d99_pattern_counts(y)
  evaluated <- d99_aghq_eval(
    counts,
    d99_test_parameters()$beta,
    d99_test_parameters()$Lambda,
    d99_gh_rule(21L)
  )
  rowwise <- sum(evaluated$log_prob[d99_pattern_code(y) + 1L])
  compressed <- evaluated$loglik
  testthat::expect_equal(rowwise, compressed, tolerance = 1e-12)
  testthat::expect_equal(
    d99_pattern_counts(y[sample.int(nrow(y)), , drop = FALSE]),
    counts,
    tolerance = 0
  )
})

testthat::test_that("conditional modes meet gradient, decrement, and curvature thresholds", {
  parameters <- d99_test_parameters()
  for (index in c(1L, 7L, 31L, 64L)) {
    mode <- d99_conditional_mode(
      d99_pattern_matrix()[index, ],
      parameters$beta,
      parameters$Lambda
    )
    testthat::expect_lt(mode$gradient_inf, 1e-10)
    testthat::expect_lt(mode$decrement, 1e-12)
    testthat::expect_gte(mode$min_eigenvalue, 1 - 1e-10)
    testthat::expect_equal(all(diff(mode$steps) <= 0), TRUE)
  }
})

testthat::test_that("conditional modes never accept a step after failed backtracking", {
  original_kernel <- d99_log_kernel
  original_increment <- d99_log_kernel_increment
  original_derivatives <- d99_kernel_derivatives
  attempted_steps <- 0L
  on.exit(
    {
      assign("d99_log_kernel", original_kernel, envir = globalenv())
      assign(
        "d99_log_kernel_increment",
        original_increment,
        envir = globalenv()
      )
      assign(
        "d99_kernel_derivatives",
        original_derivatives,
        envir = globalenv()
      )
    },
    add = TRUE
  )
  assign("d99_log_kernel", function(u, y, beta, Lambda) 0, envir = globalenv())
  assign(
    "d99_log_kernel_increment",
    function(u, step, y, beta, Lambda) {
      attempted_steps <<- attempted_steps + 1L
      -1
    },
    envir = globalenv()
  )
  assign(
    "d99_kernel_derivatives",
    function(u, y, beta, Lambda) {
      list(
        gradient = c(1, 0),
        Q = diag(2),
        probability = rep(0.5, 6),
        eta = rep(0, 6)
      )
    },
    envir = globalenv()
  )
  d99_expect_error_message(
    d99_conditional_mode(
      rep(0, 6),
      rep(0, 6),
      matrix(0, 6, 2),
      max_iterations = 1L,
      max_halvings = 30L
    ),
    "backtracking did not find a strict increase"
  )
  testthat::expect_equal(attempted_steps, 31L)
})

testthat::test_that("all response probabilities and invariant score derivatives normalize", {
  parameters <- d99_test_parameters()
  gh <- d99_gh_rule(31L)
  for (multiplier in c(0.6, 1, 1.4)) {
    result <- d99_aghq_eval(
      rep(1, 64L),
      parameters$beta * multiplier,
      parameters$Lambda * multiplier,
      gh
    )
    testthat::expect_equal(sum(result$prob), 1, tolerance = 1e-10)
    testthat::expect_equal(
      colSums(result$prob * result$score_by_pattern),
      rep(0, 18L),
      tolerance = 1e-8
    )
  }
})

testthat::test_that("finite-rule and Fisher scores converge but are not silently identical", {
  parameters <- d99_test_parameters()
  counts <- rep(0, 64L)
  counts[19L] <- 7
  coordinate <- c(parameters$beta, as.vector(t(parameters$Lambda)))
  objective_gradient <- function(gh) {
    numDeriv::grad(
      func = function(theta) {
        d99_aghq_eval(
          counts,
          theta[1:6],
          matrix(theta[-(1:6)], 6L, 2L, byrow = TRUE),
          gh,
          all_patterns = FALSE
        )$loglik
      },
      x = coordinate,
      method = "Richardson",
      method.args = list(
        eps = 1e-5,
        d = 1e-4,
        zero.tol = sqrt(.Machine$double.eps),
        r = 4,
        v = 2
      )
    )
  }
  H9 <- d99_gh_rule(9L)
  H31 <- d99_gh_rule(31L)
  difference_H9 <- max(abs(
    objective_gradient(H9) -
      d99_aghq_eval(
        counts,
        parameters$beta,
        parameters$Lambda,
        H9,
        all_patterns = FALSE
      )$score
  ))
  difference_H31 <- max(abs(
    objective_gradient(H31) -
      d99_aghq_eval(
        counts,
        parameters$beta,
        parameters$Lambda,
        H31,
        all_patterns = FALSE
      )$score
  ))
  testthat::expect_gt(difference_H9, 1e-8)
  testthat::expect_lt(difference_H31, 1e-6)
})

testthat::test_that("H21 and H31 are stable and the direct oracle carries tail bounds", {
  parameters <- d99_test_parameters()
  counts <- d99_test_counts()
  H21 <- d99_aghq_eval(
    counts,
    parameters$beta,
    parameters$Lambda,
    d99_gh_rule(21L)
  )
  H31 <- d99_aghq_eval(
    counts,
    parameters$beta,
    parameters$Lambda,
    d99_gh_rule(31L)
  )
  testthat::expect_lt(abs(H31$loglik - H21$loglik) / sum(counts), 1e-8)
  testthat::expect_lt(max(abs(H31$score - H21$score)) / sum(counts), 1e-6)
  oracle <- d99_oracle_cubature_pattern(
    d99_pattern_matrix()[19L, ],
    parameters$beta,
    parameters$Lambda
  )
  testthat::expect_gt(oracle$lower_bound, 0)
  testthat::expect_lt(oracle$tail$B0 / oracle$lower_bound, 1e-8)
  testthat::expect_equal(length(oracle$score), 18L)
  testthat::expect_equal(length(oracle$tail$invariant), 18L)
})

testthat::test_that("nested, cubature, and AGH scores meet certified quotient intervals", {
  parameters <- d99_test_parameters()
  parameters$Lambda[,] <- 0
  y <- d99_pattern_matrix()[19L, ]
  chart_jacobian <- diag(18L)[, -18L, drop = FALSE]
  chart_jacobian[18L, 17L] <- 0.35
  original_mode <- d99_conditional_mode
  original_tensor <- d99_gh_tensor
  on.exit(
    {
      assign("d99_conditional_mode", original_mode, envir = globalenv())
      assign("d99_gh_tensor", original_tensor, envir = globalenv())
    },
    add = TRUE
  )
  forbidden <- function(...) stop("AGH adaptation helper called", call. = FALSE)
  assign("d99_conditional_mode", forbidden, envir = globalenv())
  assign("d99_gh_tensor", forbidden, envir = globalenv())
  comparator <- d99_oracle_fixed_coordinate_comparator(
    y,
    parameters$beta,
    parameters$Lambda,
    chart_jacobian
  )
  assign("d99_conditional_mode", original_mode, envir = globalenv())
  assign("d99_gh_tensor", original_tensor, envir = globalenv())
  cubature <- comparator$cubature
  nested <- comparator$nested
  agh <- d99_aghq_pattern(
    y,
    parameters$beta,
    parameters$Lambda,
    d99_gh_rule(31L)
  )
  agh_chart_score <- as.numeric(crossprod(chart_jacobian, agh$score))
  testthat::expect_equal(nested$log_prob, cubature$log_prob, tolerance = 1e-8)
  testthat::expect_equal(
    all(cubature$chart_score_lower <= agh_chart_score),
    TRUE
  )
  testthat::expect_equal(
    all(cubature$chart_score_upper >= agh_chart_score),
    TRUE
  )
  testthat::expect_equal(all(nested$chart_score_lower <= agh_chart_score), TRUE)
  testthat::expect_equal(all(nested$chart_score_upper >= agh_chart_score), TRUE)
  testthat::expect_equal(
    all(
      pmax(cubature$chart_score_lower, nested$chart_score_lower) <=
        pmin(cubature$chart_score_upper, nested$chart_score_upper)
    ),
    TRUE
  )
  testthat::expect_lt(max(cubature$chart_tail_bounds), 5e-7)
  testthat::expect_identical(comparator$implementation, "direct-original-u")
  testthat::expect_identical(comparator$success, TRUE)
  testthat::expect_identical(comparator$error, NULL)
  testthat::expect_identical(cubature$backend_status$return_code, 0L)
  testthat::expect_identical(nested$backend_status$message, "OK")
  testthat::expect_gt(nested$backend_status$checked_results, 19L)
})

testthat::test_that("oracle backends fail closed on non-success statuses", {
  parameters <- d99_test_parameters()
  y <- d99_pattern_matrix()[19L, ]
  original_cubature <- d99_oracle_run_cubature
  original_integrate <- d99_oracle_run_integrate
  on.exit(
    {
      assign("d99_oracle_run_cubature", original_cubature, envir = globalenv())
      assign(
        "d99_oracle_run_integrate",
        original_integrate,
        envir = globalenv()
      )
    },
    add = TRUE
  )
  assign(
    "d99_oracle_run_cubature",
    function(...) {
      list(
        integral = rep(0.1, 19L),
        error = rep(1e-13, 19L),
        returnCode = 17L
      )
    },
    envir = globalenv()
  )
  d99_expect_error_message(
    d99_oracle_cubature_pattern(
      y,
      parameters$beta,
      parameters$Lambda,
      diag(18L)
    ),
    "returnCode must be 0; received 17"
  )
  assign("d99_oracle_run_cubature", original_cubature, envir = globalenv())
  assign(
    "d99_oracle_run_integrate",
    function(...) {
      list(value = 0.1, abs.error = 1e-13, message = "roundoff detected")
    },
    envir = globalenv()
  )
  d99_expect_error_message(
    d99_oracle_nested_pattern(
      y,
      parameters$beta,
      parameters$Lambda,
      diag(18L)
    ),
    "message must be exactly 'OK'.*roundoff detected"
  )
})

testthat::test_that("quotient certification rejects unsafe denominators and chart tails", {
  signed <- d99_oracle_quotient_intervals(
    denominator = 2,
    denominator_error = 0.1,
    denominator_tail = 0,
    numerator = c(-1, 1, numeric(16L)),
    numerator_error = c(0.2, 0.2, numeric(16L)),
    numerator_tail = numeric(18L),
    chart_jacobian = diag(18L)
  )
  testthat::expect_equal(signed$lower[1:2], c(-1.2 / 1.9, 0.8 / 2.1))
  testthat::expect_equal(signed$upper[1:2], c(-0.8 / 2.1, 1.2 / 1.9))
  d99_expect_error_message(
    d99_oracle_quotient_intervals(
      denominator = 1e-24,
      denominator_error = 0,
      denominator_tail = d99_oracle_tail_bounds()$B0,
      numerator = numeric(18L),
      numerator_error = numeric(18L),
      numerator_tail = d99_oracle_tail_bounds()$invariant,
      chart_jacobian = diag(18L)
    ),
    "denominator is not strictly positive"
  )
  d99_expect_error_message(
    d99_oracle_quotient_intervals(
      denominator = 0.1,
      denominator_error = 1e-13,
      denominator_tail = d99_oracle_tail_bounds()$B0,
      numerator = numeric(18L),
      numerator_error = numeric(18L),
      numerator_tail = d99_oracle_tail_bounds()$invariant,
      chart_jacobian = diag(18L) * 1e16
    ),
    "tail bound must be below 5e-7"
  )
})

testthat::test_that("malformed inputs and frozen convention sentinels fail visibly", {
  parameters <- d99_test_parameters()
  gh <- d99_gh_rule(15L)
  y <- d99_pattern_matrix()[19L, ]
  bad_gh <- gh
  bad_gh$nodes <- rev(bad_gh$nodes)
  d99_expect_error_message(d99_validate_gh(bad_gh), "ascending")
  d99_expect_error_message(
    d99_aghq_eval(rep(0, 63L), parameters$beta, parameters$Lambda, gh),
    "length 64"
  )
  d99_expect_error_message(
    d99_pattern_code(matrix(c(0, 1), nrow = 1L)),
    "six columns"
  )
  correct <- d99_aghq_pattern(
    y,
    parameters$beta,
    parameters$Lambda,
    gh
  )$log_prob
  testthat::expect_gt(
    abs(
      correct -
        d99_test_variant_log_prob(
          y,
          parameters$beta,
          parameters$Lambda,
          gh,
          prior_constant = FALSE
        )
    ),
    1
  )
  testthat::expect_gt(
    abs(
      correct -
        d99_test_variant_log_prob(
          y,
          parameters$beta,
          parameters$Lambda,
          gh,
          normal_ratio = FALSE
        )
    ),
    1e-4
  )
  testthat::expect_gt(
    abs(
      correct -
        d99_test_variant_log_prob(
          y,
          parameters$beta,
          parameters$Lambda,
          gh,
          jacobian = FALSE
        )
    ),
    1e-4
  )
  testthat::expect_gt(
    abs(
      correct -
        d99_test_variant_log_prob(
          y,
          parameters$beta,
          parameters$Lambda,
          gh,
          node_multiplier = sqrt(2)
        )
    ),
    1e-4
  )
})
