## Independent dense Gaussian oracle for the exact two-kernel covariance.
## Run from the package root with:
##   Rscript --vanilla dev/two-kernel-zero-observation/dense-gaussian-oracle.R

covariance_parts <- function(Lambda, psi_variance) {
  stopifnot(is.matrix(Lambda), is.numeric(psi_variance),
            nrow(Lambda) == length(psi_variance),
            all(is.finite(Lambda)), all(is.finite(psi_variance)),
            all(psi_variance >= 0))
  shared <- tcrossprod(Lambda)
  unique <- diag(psi_variance, nrow = length(psi_variance))
  list(shared = shared, unique = unique, total = shared + unique)
}

observed_covariance <- function(unit_id, trait_id, K_phy, K_tip,
                                Sigma_phy, Sigma_tip,
                                V_known = NULL) {
  stopifnot(length(unit_id) == length(trait_id),
            nrow(K_phy) == ncol(K_phy),
            identical(dim(K_phy), dim(K_tip)),
            identical(dim(Sigma_phy), dim(Sigma_tip)),
            all(unit_id >= 1L & unit_id <= nrow(K_phy)),
            all(trait_id >= 1L & trait_id <= nrow(Sigma_phy)))
  selected <- (trait_id - 1L) * nrow(K_phy) + unit_id
  full <- kronecker(Sigma_phy, K_phy) + kronecker(Sigma_tip, K_tip)
  V <- full[selected, selected, drop = FALSE]
  if (!is.null(V_known)) {
    stopifnot(is.matrix(V_known), identical(dim(V_known), dim(V)),
              isTRUE(all.equal(V_known, t(V_known), tolerance = 1e-12)))
    V <- V + V_known
  }
  V
}

dense_nll <- function(y, mean, V) {
  stopifnot(length(y) == length(mean), nrow(V) == length(y),
            ncol(V) == length(y), all(is.finite(y)), all(is.finite(mean)))
  R <- chol(V)
  residual <- y - mean
  whitened <- backsolve(R, residual, transpose = TRUE)
  alpha <- backsolve(R, whitened)
  nll <- 0.5 * (length(y) * log(2 * pi) +
                  2 * sum(log(diag(R))) + sum(whitened^2))
  score_V <- 0.5 * (chol2inv(R) - tcrossprod(alpha))
  list(nll = unname(nll), score_mean = -alpha, score_V = score_V)
}

parameter_objective <- function(parameter, template) {
  parts_phy <- covariance_parts(parameter$Lambda_phy,
                                parameter$psi_phy_variance)
  parts_tip <- covariance_parts(parameter$Lambda_tip,
                                parameter$psi_tip_variance)
  mean <- parameter$intercept[template$trait_id]
  V <- observed_covariance(
    template$unit_id, template$trait_id, template$K_phy, template$K_tip,
    parts_phy$total, parts_tip$total, template$V_known
  )
  dense_nll(template$y, mean, V)$nll
}

analytic_parameter_gradient <- function(parameter, template) {
  parts_phy <- covariance_parts(parameter$Lambda_phy,
                                parameter$psi_phy_variance)
  parts_tip <- covariance_parts(parameter$Lambda_tip,
                                parameter$psi_tip_variance)
  mean <- parameter$intercept[template$trait_id]
  V <- observed_covariance(
    template$unit_id, template$trait_id, template$K_phy, template$K_tip,
    parts_phy$total, parts_tip$total, template$V_known
  )
  fit <- dense_nll(template$y, mean, V)
  score <- fit$score_V
  n_unit <- nrow(template$K_phy)
  selected <- (template$trait_id - 1L) * n_unit + template$unit_id
  score_sigma <- function(K, Sigma) {
    out <- matrix(0, nrow(Sigma), ncol(Sigma))
    for (a in seq_len(nrow(Sigma))) {
      for (b in seq_len(ncol(Sigma))) {
        direction <- matrix(0, nrow(Sigma), ncol(Sigma))
        direction[a, b] <- 1
        dV <- kronecker(direction, K)[selected, selected, drop = FALSE]
        out[a, b] <- sum(score * dV)
      }
    }
    out
  }
  grad_sigma_phy <- score_sigma(template$K_phy, parts_phy$total)
  grad_sigma_tip <- score_sigma(template$K_tip, parts_tip$total)
  list(
    intercept = vapply(seq_along(parameter$intercept), function(j) {
      sum(fit$score_mean[template$trait_id == j])
    }, numeric(1)),
    Lambda_phy = 2 * grad_sigma_phy %*% parameter$Lambda_phy,
    Lambda_tip = 2 * grad_sigma_tip %*% parameter$Lambda_tip,
    psi_phy_variance = diag(grad_sigma_phy),
    psi_tip_variance = diag(grad_sigma_tip)
  )
}

finite_difference <- function(parameter, template, field, index = NULL,
                              step = 1e-6, one_sided = FALSE) {
  plus <- minus <- parameter
  if (is.null(index)) {
    plus[[field]] <- parameter[[field]] + step
    if (one_sided) {
      return((parameter_objective(plus, template) -
                parameter_objective(parameter, template)) / step)
    }
    minus[[field]] <- parameter[[field]] - step
  } else {
    plus[[field]][index] <- parameter[[field]][index] + step
    if (one_sided) {
      return((parameter_objective(plus, template) -
                parameter_objective(parameter, template)) / step)
    }
    minus[[field]][index] <- parameter[[field]][index] - step
  }
  (parameter_objective(plus, template) -
     parameter_objective(minus, template)) / (2 * step)
}

assert_close <- function(actual, expected, tolerance, label) {
  error <- max(abs(actual - expected))
  if (!is.finite(error) || error > tolerance) {
    stop(sprintf("%s: max absolute gap %.6g exceeds %.6g",
                 label, error, tolerance), call. = FALSE)
  }
  error
}

run_oracle_checks <- function() {
  n_unit <- 5L
  n_trait <- 4L
  unit <- seq_len(n_unit)
  K_phy <- 0.42 ^ abs(outer(unit, unit, `-`))
  K_tip <- diag(n_unit) + 0.18 * (matrix(1, n_unit, n_unit) - diag(n_unit))
  L_phy <- matrix(c(0.72, 0.31, -0.24, 0.16, 0.28, 0.54, -0.33, 0.21),
                  nrow = n_trait, ncol = 2L)
  L_tip <- matrix(c(0.23, -0.18, 0.62, 0.37), nrow = n_trait, ncol = 1L)
  parameter <- list(
    intercept = c(0.11, -0.07, 0.16, -0.12),
    Lambda_phy = L_phy,
    Lambda_tip = L_tip,
    psi_phy_variance = c(0, 0.08, 0.04, 0.07),
    psi_tip_variance = c(0.06, 0.09, 0.05, 0.11)
  )
  phy_parts <- covariance_parts(L_phy, parameter$psi_phy_variance)
  tip_parts <- covariance_parts(L_tip, parameter$psi_tip_variance)

  ## The observed cells are a sparse, non-rectangular subset of the full grid.
  ## Every unit-trait cell is unique; multiple units contribute to each trait.
  unit_id <- c(1L, 2L, 4L, 1L, 3L, 5L, 2L, 4L, 5L, 1L, 3L, 4L)
  trait_id <- c(1L, 1L, 1L, 2L, 2L, 2L, 3L, 3L, 3L, 4L, 4L, 4L)
  y <- c(0.31, -0.42, 0.18, 0.07, 0.51, -0.26,
         -0.13, 0.37, 0.24, 0.49, -0.05, -0.32)
  if (anyDuplicated(data.frame(unit_id, trait_id))) {
    stop("fixture unexpectedly contains duplicate observed cells", call. = FALSE)
  }
  V_zero <- observed_covariance(unit_id, trait_id, K_phy, K_tip,
                                phy_parts$total, tip_parts$total)
  V_with_zero <- observed_covariance(
    unit_id, trait_id, K_phy, K_tip, phy_parts$total, tip_parts$total,
    matrix(0, length(y), length(y))
  )
  zero_covariance_gap <- assert_close(V_zero, V_with_zero, 0,
                                       "exact zero is omitted")
  mean <- parameter$intercept[trait_id]
  zero_fit <- dense_nll(y, mean, V_zero)

  error_variance <- 0.037
  V_positive <- observed_covariance(
    unit_id, trait_id, K_phy, K_tip, phy_parts$total, tip_parts$total,
    diag(error_variance, length(y))
  )
  positive_increment_gap <- assert_close(
    V_positive - V_zero, diag(error_variance, length(y)), 1e-14,
    "positive known error is added as variance"
  )
  positive_fit <- dense_nll(y, mean, V_positive)
  if (!is.finite(positive_fit$nll) ||
      isTRUE(all.equal(zero_fit$nll, positive_fit$nll, tolerance = 1e-12))) {
    stop("positive-error control did not change the finite Gaussian objective",
         call. = FALSE)
  }

  ## Independently select entries from the full vec(trait x unit) covariance.
  full <- kronecker(phy_parts$total, K_phy) +
    kronecker(tip_parts$total, K_tip)
  selected <- (trait_id - 1L) * n_unit + unit_id
  manual_selected <- outer(selected, selected, function(i, j) full[cbind(i, j)])
  mask_gap <- assert_close(V_zero, manual_selected, 0,
                           "structural-mask principal submatrix")

  gradient <- analytic_parameter_gradient(parameter, list(
    y = y, unit_id = unit_id, trait_id = trait_id,
    K_phy = K_phy, K_tip = K_tip, V_known = NULL
  ))
  gradient_gaps <- c(
    intercept = max(vapply(seq_along(parameter$intercept), function(j) {
      assert_close(gradient$intercept[j], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "intercept", j
      ), 2e-6, "intercept gradient")
    }, numeric(1))),
    Lambda_phy = max(vapply(seq_along(parameter$Lambda_phy), function(j) {
      assert_close(gradient$Lambda_phy[j], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "Lambda_phy", j
      ), 3e-6, "phy loading gradient")
    }, numeric(1))),
    Lambda_tip = max(vapply(seq_along(parameter$Lambda_tip), function(j) {
      assert_close(gradient$Lambda_tip[j], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "Lambda_tip", j
      ), 3e-6, "tip loading gradient")
    }, numeric(1))),
    psi_phy_interior = max(vapply(2:4, function(j) {
      assert_close(gradient$psi_phy_variance[j], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "psi_phy_variance", j
      ), 3e-6, "phy Psi variance gradient")
    }, numeric(1))),
    psi_tip = max(vapply(seq_along(parameter$psi_tip_variance), function(j) {
      assert_close(gradient$psi_tip_variance[j], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "psi_tip_variance", j
      ), 3e-6, "tip Psi variance gradient")
    }, numeric(1))),
    psi_phy_zero_right = assert_close(
      gradient$psi_phy_variance[1], finite_difference(
        parameter, list(y = y, unit_id = unit_id, trait_id = trait_id,
                        K_phy = K_phy, K_tip = K_tip, V_known = NULL),
        "psi_phy_variance", 1, step = 1e-7, one_sided = TRUE
      ), 4e-5, "zero-boundary one-sided Psi gradient"
    )
  )

  positive_template <- list(
    y = y, unit_id = unit_id, trait_id = trait_id,
    K_phy = K_phy, K_tip = K_tip,
    V_known = diag(error_variance, length(y))
  )
  positive_gradient <- analytic_parameter_gradient(parameter, positive_template)
  positive_gradient_gaps <- c(
    intercept = assert_close(
      positive_gradient$intercept[2],
      finite_difference(parameter, positive_template, "intercept", 2),
      2e-6, "positive-error intercept gradient"
    ),
    Lambda_phy = assert_close(
      positive_gradient$Lambda_phy[1],
      finite_difference(parameter, positive_template, "Lambda_phy", 1),
      3e-6, "positive-error phy loading gradient"
    ),
    Lambda_tip = assert_close(
      positive_gradient$Lambda_tip[2],
      finite_difference(parameter, positive_template, "Lambda_tip", 2),
      3e-6, "positive-error tip loading gradient"
    ),
    psi_phy = assert_close(
      positive_gradient$psi_phy_variance[2],
      finite_difference(parameter, positive_template, "psi_phy_variance", 2),
      3e-6, "positive-error phy Psi gradient"
    ),
    psi_tip = assert_close(
      positive_gradient$psi_tip_variance[3],
      finite_difference(parameter, positive_template, "psi_tip_variance", 3),
      3e-6, "positive-error tip Psi gradient"
    )
  )

  ## The named components are oracle quantities only, not package extractors.
  extraction_identity_gap <- max(
    assert_close(phy_parts$shared + phy_parts$unique, phy_parts$total,
                 0, "phy shared + unique = total"),
    assert_close(tip_parts$shared + tip_parts$unique, tip_parts$total,
                 0, "tip shared + unique = total"),
    assert_close(phy_parts$unique, diag(parameter$psi_phy_variance),
                 0, "phy unique equals diagonal Psi variance"),
    assert_close(tip_parts$unique, diag(parameter$psi_tip_variance),
                 0, "tip unique equals diagonal Psi variance")
  )

  cat(sprintf("PASS exact-zero dense NLL: %.12f\n", zero_fit$nll))
  cat(sprintf("PASS positive-error dense NLL: %.12f\n", positive_fit$nll))
  cat(sprintf("PASS maximum analytic-vs-finite-difference gradient gap: %.6g\n",
              max(gradient_gaps)))
  cat(sprintf("PASS positive-error gradient control maximum gap: %.6g\n",
              max(positive_gradient_gaps)))
  cat(sprintf("PASS named covariance identity gap: %.6g\n",
              extraction_identity_gap))
  cat(sprintf("PASS zero omission gap: %.6g; positive variance increment gap: %.6g; mask gap: %.6g\n",
              zero_covariance_gap, positive_increment_gap, mask_gap))
  invisible(list(zero_nll = zero_fit$nll, positive_nll = positive_fit$nll,
                 gradient_gaps = gradient_gaps,
                 extraction_identity_gap = extraction_identity_gap))
}

run_oracle_checks()
