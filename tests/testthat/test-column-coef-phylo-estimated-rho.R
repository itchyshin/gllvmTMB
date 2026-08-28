## Public fixed and estimated phylogenetic response-column coefficients.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula / parameter | TMB data or report | Independent truth |
## |--------|---------------------|--------------------|-------------------|
## | R | phylo_coef source correlation | column_coef_source_U/lambda | D^-1 K D^-1 |
## | rho | rho = NULL / eta_column_coef_rho | column_coef_rho | plogis(eta) |
## | K_rho | rho K + (1-rho)diag(K) | extract_Sigma()$K_rho | direct mixture |
## | K_rho^-1 | spectral precision | U/lambda/inv_d quadratic | solve(K_rho) |
## | log|K_rho| | spectral determinant | column_coef_logdet_K_rho | determinant(K_rho) |
## | Sigma_coef | coefficient covariance | Sigma_b_dep | L L^T |

.make_public_phylo_coef_fixture <- function(seed = 13141L,
                                            n_traits = 7L,
                                            n_unit = 18L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  x_by_unit <- stats::rnorm(n_unit)
  data$x <- x_by_unit[as.integer(data$unit)]
  data$value <- 0.2 + stats::rnorm(nrow(data), sd = 0.45)
  d <- seq(0.65, 1.35, length.out = n_traits)
  R <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2.3)
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  wide <- tidyr::pivot_wider(
    data,
    id_cols = c("unit", "x"),
    names_from = "trait",
    values_from = "value"
  )
  wide <- as.data.frame(wide)
  data <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(traits),
    names_to = "trait",
    values_to = "value"
  )
  data <- as.data.frame(data)
  data$trait <- factor(data$trait, levels = traits)
  rownames(data) <- NULL
  list(data = data, wide = wide, traits = traits, K = K)
}

.fit_public_phylo_coef <- function(fx, formula) {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}

test_that("spectral source data reproduce the raw covariance mixture", {
  fx <- .make_public_phylo_coef_fixture()
  source <- gllvmTMB:::.resolve_phylo_coef_spectral_source(
    phylo_tree = NULL,
    phylo_vcv = fx$K,
    data = fx$data,
    group = "trait"
  )
  expect_identical(source$labels, fx$traits)
  for (rho in c(0.13, 0.47, 0.91)) {
    s <- (1 - rho) + rho * source$lambda
    Q <- diag(1 / source$d) %*% source$U %*%
      diag(1 / s) %*% t(source$U) %*% diag(1 / source$d)
    K_rho <- rho * fx$K + (1 - rho) * diag(diag(fx$K))
    expect_equal(unname(Q), unname(solve(K_rho)), tolerance = 1e-10)
    expect_equal(
      2 * sum(log(source$d)) + sum(log(s)),
      as.numeric(determinant(K_rho, logarithm = TRUE)$modulus),
      tolerance = 1e-10
    )
  }
})

test_that("public fixed phylo_coef fits without a private rewrite", {
  fx <- .make_public_phylo_coef_fixture()
  fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = 0.37)
  )
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(got$source$type, "phylo")
  expect_identical(got$rho_status, "fixed")
  expect_identical(got$rho, 0.37)
  expect_equal(
    got$K_rho,
    0.37 * fx$K + 0.63 * diag(diag(fx$K)),
    tolerance = 1e-10
  )
})

test_that("rho NULL activates one interior TMB parameter and reports its mixture", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 9L, n_unit = 22L)
  fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = NULL)
  )
  expect_identical(fit$tmb_data$use_column_coef_estimated_rho, 1L)
  expect_true("eta_column_coef_rho" %in% names(fit$opt$par))
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))

  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(got$rho_status, "estimated")
  expect_true(is.numeric(got$rho) && length(got$rho) == 1L)
  expect_gt(got$rho, 0)
  expect_lt(got$rho, 1)
  expect_equal(
    got$K_rho,
    got$rho * fx$K + (1 - got$rho) * diag(diag(fx$K)),
    tolerance = 1e-8
  )
})

test_that("estimated rho rejects sources with no correlation contrast", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 5L, n_unit = 14L)
  diagonal_K <- diag(seq(0.7, 1.3, length.out = length(fx$traits)))
  dimnames(diagonal_K) <- list(fx$traits, fx$traits)
  expect_error(
    .fit_public_phylo_coef(
      fx,
      value ~ 1 + phylo_coef(0 + x | trait, vcv = diagonal_K,
                             rho = NULL)
    ),
    class = "gllvmTMB_column_coef_rho_unidentified"
  )
})

test_that("estimated rho accepts tree and labelled sparse-precision sources", {
  skip_if_not_installed("ape")
  skip_if_not_installed("Matrix")

  fx <- .make_public_phylo_coef_fixture(n_traits = 6L, n_unit = 16L)
  sparse_Q <- Matrix::Matrix(solve(fx$K), sparse = TRUE)
  dimnames(sparse_Q) <- dimnames(fx$K)
  sparse_fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(0 + x | trait, vcv = sparse_Q, rho = NULL)
  )
  sparse_got <- gllvmTMB::extract_Sigma(sparse_fit, level = "column_coef")
  expect_identical(sparse_got$rho_status, "estimated")
  expect_true(is.finite(sparse_got$rho))
  expect_equal(
    sparse_got$K_rho,
    sparse_got$rho * fx$K +
      (1 - sparse_got$rho) * diag(diag(fx$K)),
    tolerance = 1e-8
  )

  set.seed(13143)
  tree <- ape::rcoal(length(fx$traits))
  tree$tip.label <- fx$traits
  tree_fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(0 + x | trait, tree = tree, rho = NULL)
  )
  tree_got <- gllvmTMB::extract_Sigma(tree_fit, level = "column_coef")
  expect_identical(tree_got$rho_status, "estimated")
  expect_true(is.finite(tree_got$rho))
  expect_identical(dim(tree_got$K_rho), c(6L, 6L))
  expect_identical(rownames(tree_got$K_rho), fx$traits)
  expect_equal(tree_got$K_rho, t(tree_got$K_rho), tolerance = 1e-10)
})

test_that("estimated rho is exposed through the transformed sdreport", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 6L, n_unit = 18L)
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + phylo_coef(0 + x | trait, vcv = fx$K, rho = NULL),
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE),
    silent = TRUE
  ))
  expect_null(fit$sdreport_error)
  expect_s3_class(fit$sd_report, "sdreport")
  report <- summary(fit$sd_report, "report")
  expect_true("column_coef_rho" %in% rownames(report))
  rho_row <- report["column_coef_rho", , drop = FALSE]
  expect_true(all(is.finite(rho_row)))
  expect_equal(
    unname(rho_row[1L, "Estimate"]),
    gllvmTMB::extract_Sigma(fit, level = "column_coef")$rho,
    tolerance = 1e-8
  )
})

test_that("estimated-rho objective has finite-difference gradient oracles away from the optimum", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 8L, n_unit = 20L)
  fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = NULL)
  )
  par <- fit$opt$par
  pos <- which(names(par) == "eta_column_coef_rho")
  expect_length(pos, 1L)
  h <- 1e-4
  for (eta in c(-1.2, -0.15, 0.9)) {
    probe <- par
    probe[[pos]] <- eta
    upper <- lower <- probe
    upper[[pos]] <- upper[[pos]] + h
    lower[[pos]] <- lower[[pos]] - h
    fd <- as.numeric(
      (fit$tmb_obj$fn(upper) - fit$tmb_obj$fn(lower)) / (2 * h)
    )
    ad <- as.numeric(fit$tmb_obj$gr(probe)[[pos]])
    expect_lt(abs(ad - fd), 5e-4)
  }
})

test_that("estimated and fixed engines agree at the same interior rho", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 7L, n_unit = 18L)
  rho <- 0.41
  fixed <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = rho)
  )
  estimated <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = NULL)
  )
  fixed_joint <- fixed$tmb_obj$env$last.par.best
  estimated_joint <- estimated$tmb_obj$env$last.par.best
  for (nm in unique(names(fixed_joint))) {
    fixed_pos <- which(names(fixed_joint) == nm)
    estimated_pos <- which(names(estimated_joint) == nm)
    if (length(fixed_pos) == length(estimated_pos)) {
      estimated_joint[estimated_pos] <- fixed_joint[fixed_pos]
    }
  }
  estimated_joint[which(names(estimated_joint) == "eta_column_coef_rho")] <-
    stats::qlogis(rho)
  expect_equal(
    as.numeric(estimated$tmb_obj$env$f(estimated_joint)),
    as.numeric(fixed$tmb_obj$env$f(fixed_joint)),
    tolerance = 1e-8
  )
})

test_that("public rho-one no-intercept calls preserve released slope TMB bytes", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 6L, n_unit = 16L)
  for (bar in c("|", "||")) {
    coef_formula <- stats::as.formula(sprintf(
      "value ~ 1 + phylo_coef(0 + x %s trait, vcv = fx$K, rho = 1)", bar
    ))
    slope_formula <- stats::as.formula(sprintf(
      "value ~ 1 + phylo_slope(x %s trait, vcv = fx$K)", bar
    ))
    environment(coef_formula) <- environment()
    environment(slope_formula) <- environment()
    coef_fit <- expect_warning(.fit_public_phylo_coef(fx, coef_formula), NA)
    slope_fit <- expect_warning(.fit_public_phylo_coef(fx, slope_formula), NA)
    expect_identical(coef_fit$tmb_data, slope_fit$tmb_data)
    expect_identical(coef_fit$tmb_map, slope_fit$tmb_map)
    expect_identical(coef_fit$random, slope_fit$random)
    expect_identical(coef_fit$opt$objective, slope_fit$opt$objective)
    expect_identical(coef_fit$opt$par, slope_fit$opt$par)
    expect_identical(coef_fit$report, slope_fit$report)
    expect_identical(
      suppressMessages(stats::fitted(coef_fit)),
      suppressMessages(stats::fitted(slope_fit))
    )
    got <- gllvmTMB::extract_Sigma(coef_fit, level = "column_coef")
    expect_identical(got$rho_status, "fixed")
    expect_identical(got$rho, 1)
  }
})

test_that("rho parameter is mapped off for released slope fits", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 6L, n_unit = 16L)
  fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_slope(x | trait, vcv = fx$K)
  )
  expect_false("eta_column_coef_rho" %in% names(fit$opt$par))
})

test_that("tree-backed rho-one extraction returns the aligned marginal tip block", {
  skip_if_not_installed("ape")
  set.seed(13151)
  tree <- ape::rcoal(6)
  tree$tip.label <- paste0("t", seq_len(6))
  fx <- .make_public_phylo_coef_fixture(n_traits = 6L, n_unit = 16L)
  fit <- .fit_public_phylo_coef(
    fx,
    value ~ 1 + phylo_coef(0 + x | trait, tree = tree, rho = 1)
  )
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(dim(got$K_rho), c(6L, 6L))
  expect_identical(rownames(got$K_rho), fx$traits)
  expect_identical(colnames(got$K_rho), fx$traits)
  expect_true(all(is.finite(got$K_rho)))
  expect_equal(got$K_rho, t(got$K_rho), tolerance = 1e-10)
})

test_that("estimated phylo coefficients have matched long and wide entry points", {
  fx <- .make_public_phylo_coef_fixture(n_traits = 4L, n_unit = 16L)
  long <- .fit_public_phylo_coef(
    fx,
    value ~ 0 + phylo_coef(1 + x | trait, vcv = fx$K, rho = NULL)
  )
  wide_formula <- stats::as.formula(paste0(
    "traits(", paste(fx$traits, collapse = ", "),
    ") ~ 0 + phylo_coef(1 + x | trait, vcv = fx$K, rho = NULL)"
  ))
  environment(wide_formula) <- environment()
  wide <- suppressMessages(gllvmTMB::gllvmTMB(
    wide_formula,
    data = fx$wide,
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  expect_identical(wide$tmb_data, long$tmb_data)
  expect_identical(wide$tmb_map, long$tmb_map)
  expect_identical(wide$random, long$random)
  expect_identical(wide$opt$objective, long$opt$objective)
  expect_identical(wide$opt$par, long$opt$par)
  expect_identical(
    suppressMessages(stats::fitted(wide)),
    suppressMessages(stats::fitted(long))
  )
  expect_identical(
    gllvmTMB::extract_Sigma(wide, level = "column_coef"),
    gllvmTMB::extract_Sigma(long, level = "column_coef")
  )
})

test_that("estimated rho and coefficient covariance recover a deterministic Gaussian DGP", {
  set.seed(13171)
  n_traits <- 30L
  n_unit <- 70L
  traits <- paste0("t", seq_len(n_traits))
  d <- seq(0.8, 1.25, length.out = n_traits)
  R <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2.8)
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)
  rho_truth <- 0.58
  K_rho <- rho_truth * K + (1 - rho_truth) * diag(diag(K))
  Sigma_truth <- diag(c(0.16, 0.12, 0.10, 0.08))
  Z <- scale(
    matrix(stats::rnorm(n_traits * 4L), n_traits, 4L),
    center = TRUE,
    scale = FALSE
  )
  Z <- Z %*% solve(chol(stats::cov(Z)))
  B <- t(chol(K_rho)) %*% Z %*% chol(Sigma_truth)
  expect_lt(
    max(abs(crossprod(B, solve(K_rho, B)) / (n_traits - 1L) -
      Sigma_truth)),
    1e-10
  )
  grid <- seq(-1.5, 1.5, length.out = n_unit)
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(n_unit))),
    x1 = grid,
    x2 = sin(pi * grid),
    x3 = cos(pi * grid)
  )
  for (j in seq_len(n_traits)) {
    wide[[traits[[j]]]] <- 0.25 + B[j, 1L] + B[j, 2L] * wide$x1 +
      B[j, 3L] * wide$x2 + B[j, 4L] * wide$x3 +
      stats::rnorm(n_unit, sd = 0.08)
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(traits),
    names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + phylo_coef(1 + x1 + x2 + x3 || trait, vcv = K, rho = NULL),
    data = long,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  gradient <- fit$tmb_obj$gr(fit$opt$par)
  joint <- fit$tmb_obj$env$last.par.best
  b_hat_vector <- unname(joint[names(joint) == "b_phy_aug"])
  B_hat <- array(b_hat_vector, dim = c(n_traits, 4L))
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(gradient)))
  expect_lt(max(abs(gradient)), 1e-2)
  expect_lt(abs(got$rho - rho_truth), 0.15)
  expect_lt(max(abs(unname(diag(got$Sigma)) - diag(Sigma_truth))), 0.06)
  expect_equal(got$Sigma[lower.tri(got$Sigma)], rep(0, 6), tolerance = 1e-12)
  expect_identical(dim(B_hat), c(n_traits, 4L))
  expect_gt(stats::cor(as.numeric(B_hat), as.numeric(B)), 0.95)
  expect_lt(sqrt(mean((B_hat - B)^2)), 0.08)
})
