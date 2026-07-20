test_that("R2 q = 1/q = 2 fixed-coordinate references satisfy their identities", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  results <- o3_r2_run_default()

  for (result in results) {
    expect_equal(result$convergence, 0L)
    expect_lt(abs(result$laplace_difference), 1e-6)
    expect_lt(result$terminal_difference, 1e-4)
    expect_lte(max(abs(result$permutation_unit)), 1e-10)
    expect_lte(max(abs(result$permutation_row)), 1e-10)
    expect_lte(max(abs(result$permutation_unit_moment)), 1e-10)
    expect_lte(max(abs(result$permutation_row_moment)), 1e-10)
    expect_true(all(result$diagnostics$chol_ok))
    expect_equal(
      result$diagnostics$normalized_weight_sum,
      rep(1, nrow(result$diagnostics)), tolerance = 1e-12
    )
    expect_true(all(is.finite(result$posterior_moments$value)))
    covariance <- subset(result$posterior_moments, moment == "covariance")
    mean <- subset(result$posterior_moments, moment == "mean")
    count_key <- interaction(result$posterior_moments$unit_id,
                             result$posterior_moments$nodes)
    expect_true(all(table(count_key[result$posterior_moments$moment == "mean"]) == result$q))
    expect_true(all(table(count_key[result$posterior_moments$moment == "covariance"]) == result$q^2))
    expect_true(all(mean$row %in% seq_len(result$q)))
    expect_true(all(is.na(mean$col)))
    for (key in unique(interaction(covariance$unit_id, covariance$nodes))) {
      block <- covariance[interaction(covariance$unit_id, covariance$nodes) == key, ]
      V <- matrix(block$value, result$q, result$q)
      expect_equal(V, t(V), tolerance = 1e-14)
      expect_gte(min(eigen(V, symmetric = TRUE, only.values = TRUE)$values), -1e-12)
    }
    expect_true(all(is.finite(result$diagnostics$min_eigen)))
    expect_gt(min(result$diagnostics$min_eigen), 0)
    expect_lte(result$max_condition, 1e8)
  }
})

test_that("R2 receipt writer emits an interpretable local-only evidence bundle", {
  skip_on_cran()
  source(test_path("helper-aghq-o3.R"))

  result <- o3_r2_run_fixture("baseline_q1", 1L, 20260719L)
  out <- tempfile("aghq-r2-receipt-")
  receipt <- o3_r2_write_receipt(list(result), out)
  expect_true(all(file.exists(file.path(out, c(
    "manifest.csv", "unit_diagnostics.csv", "posterior_moments.csv",
    "fixture_summary.csv", "truth.rds", "README.md"
  )))))
  expect_identical(receipt$fixture_summary$status, "pass")
  expect_identical(receipt$condition_reject$status, "condition_exceeds_limit")
  manifest <- utils::read.csv(file.path(out, "manifest.csv"), stringsAsFactors = FALSE)
  expect_true(all(c("tmb_version", "node_vector") %in% names(manifest)))
  expect_identical(
    manifest$posterior_moment_source[manifest$fixture_id == "baseline_q1"],
    "normalized_adaptive_ghq_at_held_fitted_coordinates"
  )
  expect_identical(
    manifest$posterior_coordinate[manifest$fixture_id == "baseline_q1"],
    "standard_normal_latent_score_u"
  )
  expect_true(all(is.finite(receipt$fixture_summary$fit_gradient_norm)))
  expect_true(all(receipt$fixture_summary$fit_gradient_norm >= 0))
  expect_match(
    manifest$condition_parameters[manifest$fixture_id == "condition_reject_q2"],
    "Lambda=\\(\\(50000,0\\),\\(50000,1\\)\\)"
  )
  diagnostics <- utils::read.csv(file.path(out, "unit_diagnostics.csv"), stringsAsFactors = FALSE)
  expect_true("condition_reject_q2" %in% diagnostics$fixture_id)
  moments <- utils::read.csv(file.path(out, "posterior_moments.csv"), stringsAsFactors = FALSE)
  expect_true(all(c("mean", "covariance") %in% moments$moment))
  expect_true(all(is.finite(moments$value)))
  expect_true(all(c(
    "normalization", "normalized_weight_sum", "source", "coordinate",
    "package_commit", "source_helper_sha", "terminal_node"
  ) %in% names(moments)))
  expect_true(all(moments$normalization == "log_sum_exp_normalized_adaptive_weights"))
  expect_equal(moments$normalized_weight_sum, rep(1, nrow(moments)),
               tolerance = 1e-12)
  expect_true(any(moments$terminal_node))
  truth <- readRDS(file.path(out, "truth.rds"))
  expect_identical(truth$condition_reject_q2$y, c(50, 50))
  expect_equal(truth$condition_reject_q2$loading[1, 1], 50000)
})

test_that("R2 fixture truth uses standard-normal score coordinates", {
  source(test_path("helper-aghq-o3.R"))

  for (q in 1:2) {
    fixture <- .o3_r2_fixture_data(q, 20260718L + q)
    truth <- fixture$truth
    expect_identical(
      truth$score_convention,
      "u ~ N(0, I); score scales absorbed into Lambda_B"
    )
    expect_equal(
      truth$Lambda_B,
      sweep(truth$generating_Lambda_B, 2L, truth$score_scale, "*")
    )
    expect_equal(truth$Sigma_B, tcrossprod(truth$Lambda_B))
    eta_standardized <- truth$beta[as.integer(fixture$data$trait)] + rowSums(
      truth$Lambda_B[as.integer(fixture$data$trait), , drop = FALSE] *
        truth$standardized_score[as.integer(fixture$data$unit), , drop = FALSE]
    )
    eta_generating <- truth$beta[as.integer(fixture$data$trait)] + rowSums(
      truth$generating_Lambda_B[as.integer(fixture$data$trait), , drop = FALSE] *
        sweep(truth$standardized_score, 2L, truth$score_scale, "*")[
          as.integer(fixture$data$unit), , drop = FALSE
        ]
    )
    expect_equal(eta_standardized, eta_generating, tolerance = 1e-15)
  }
})

test_that("R2 normalized AGHQ moments agree with independent weighted moments", {
  source(test_path("helper-aghq-o3.R"))

  cases <- list(
    list(y = c(3, 8), n = c(12, 12), eta = c(-0.2, 0.35),
         loading = matrix(c(0.56, -0.35), ncol = 1L), nodes = 25L),
    list(y = c(3, 8), n = c(12, 12), eta = c(-0.25, 0.3),
         loading = matrix(c(0.56, 0, 0.175, 0.2475), 2L, 2L, byrow = TRUE),
         nodes = 9L)
  )
  for (case in cases) {
    ans <- .o3_r2_log_integral(
      case$y, case$n, case$eta, case$loading, case$nodes
    )
    mode <- .o3_r2_mode(case$y, case$n, case$eta, case$loading)
    rule <- .o3_gh(case$nodes)
    q <- ncol(case$loading)
    grid <- as.matrix(do.call(expand.grid, rep(list(rule$x), q)))
    log_weight <- rowSums(vapply(
      seq_len(q), function(j) log(rule$w[match(grid[, j], rule$x)]),
      numeric(nrow(grid))
    ))
    u <- sweep(sqrt(2) * t(backsolve(mode$R, t(grid))), 2L, mode$mode, "+")
    log_mass <- apply(u, 1L, mode$log_density) + log_weight + rowSums(grid^2)
    weight <- exp(log_mass - max(log_mass))
    weight <- weight / sum(weight)
    expected_mean <- colSums(u * weight)
    centered <- sweep(u, 2L, expected_mean, "-")
    expected_covariance <- crossprod(centered, centered * weight)

    expect_equal(ans$normalized_weight_sum, 1, tolerance = 1e-14)
    expect_equal(ans$posterior_mean, expected_mean, tolerance = 1e-13)
    expect_equal(ans$posterior_covariance, expected_covariance,
                 tolerance = 1e-13)
  }
})

test_that("R2 receipt writer rejects q >= 3", {
  source(test_path("helper-aghq-o3.R"))

  result <- o3_r2_run_fixture("baseline_q1", 1L, 20260719L)
  result$q <- 3L
  expect_error(
    o3_r2_write_receipt(list(result), tempfile("aghq-r2-q3-")),
    "q = 1 or q = 2"
  )
  expect_error(
    o3_r2_run_fixture("forbidden_q3", 3L, 20260726L),
    "q %in% 1:2"
  )
})

test_that("R2 rejects a finite q = 2 condition-threshold fixture before quadrature", {
  source(test_path("helper-aghq-o3.R"))

  guard <- o3_r2_condition_reject()
  expect_identical(guard$status, "condition_exceeds_limit")
  expect_true(isTRUE(guard$chol_ok))
  expect_true(is.finite(guard$min_eigen))
  expect_gt(guard$min_eigen, 0)
  expect_gt(guard$condition, 1e8)
})
