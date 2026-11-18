## Fixed-rho phylogenetic response-column coefficients.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula term | DGP / source | Engine object | Truth |
## |--------|--------------|--------------|---------------|-------|
## | K_rho | phylo_coef(..., rho=rho) | rho K + (1-rho) diag(K) | solve(Ainv_phy_slope) | exact K_rho |
## | B[,1] | phylo_coef(1 + x | trait) | matrix-normal intercept deviation | report$b_phy_aug_physical[,1,1] | Sigma_coef[1,1] |
## | B[,2] | phylo_coef(1 + x | trait) | matrix-normal slope deviation | report$b_phy_aug_physical[,2,1] | Sigma_coef[2,2] |
## | Sigma_coef[1,2] | single bar | shared coefficient covariance | Sigma_b_dep[1,2] | planted covariance |
##
## With trait-major b = vec(B^T), Cov(b) = K_rho %x% Sigma_coef and
## eta[o] gains z[o,] B[trait[o],]. rho is fixed R data in this slice.
## The physical report applies to standardized tapes; centred fallback tapes
## retain physical B in b_phy_aug. Standardized b_phy_aug itself contains U.

.make_phylo_coef_fixture <- function(seed = 13121L, n_traits = 6L,
                                     n_unit = 18L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  data <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(traits, levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- stats::rnorm(nrow(data))
  data$z <- stats::rnorm(nrow(data))
  data$value <- 0.2 + stats::rnorm(nrow(data), sd = 0.45)

  d <- seq(0.65, 1.35, length.out = n_traits)
  R <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2.5)
  K <- outer(d, d) * R
  dimnames(K) <- list(traits, traits)

  tree <- NULL
  if (requireNamespace("ape", quietly = TRUE)) {
    tree <- ape::rcoal(n_traits)
    tree$tip.label <- traits
  }
  list(data = data, traits = traits, K = K, tree = tree)
}

.rewrite_private_phylo_coef <- function(formula, data, trait = "trait") {
  spec <- gllvmTMB:::.parse_column_coef_formula(
    formula = formula,
    trait_col = trait,
    row_vars = names(data),
    column_vars = character(),
    response_vars = all.vars(formula[[2L]])
  )
  formula[[3L]] <- gllvmTMB:::.column_coef_rewrite_fixed_phylo(
    formula[[3L]], spec, data = data, envir = environment(formula)
  )
  formula
}

.fit_private_phylo_coef <- function(fx, formula) {
  formula <- .rewrite_private_phylo_coef(formula, fx$data)
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

.fit_released_phylo_slope <- function(fx, formula) {
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

.free_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) {
    if (is.null(x)) NULL else as.integer(x)
  })
}

.expect_route_identical <- function(coef_fit, slope_fit) {
  expect_identical(coef_fit$tmb_data, slope_fit$tmb_data)
  expect_identical(coef_fit$tmb_obj$env$random,
                   slope_fit$tmb_obj$env$random)
  expect_identical(names(coef_fit$opt$par), names(slope_fit$opt$par))
  expect_identical(.free_map_signature(coef_fit),
                   .free_map_signature(slope_fit))

  common <- slope_fit$opt$par
  expect_identical(coef_fit$tmb_obj$fn(common),
                   slope_fit$tmb_obj$fn(common))
  expect_identical(coef_fit$tmb_obj$gr(common),
                   slope_fit$tmb_obj$gr(common))
  expect_identical(coef_fit$opt$objective, slope_fit$opt$objective)
  expect_identical(coef_fit$opt$par, slope_fit$opt$par)
  expect_identical(coef_fit$report, slope_fit$report)
  expect_identical(
    suppressMessages(stats::fitted(coef_fit)),
    suppressMessages(stats::fitted(slope_fit))
  )
}

test_that("public fixed-rho phylo_coef enters the admitted engine", {
  fx <- .make_phylo_coef_fixture()
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = 0.37),
    data = fx$data, trait = "trait", unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_true(isTRUE(fit$use$response_column_coef))
  expect_identical(fit$use$response_column_coef_source, "phylo")
  expect_identical(fit$use$response_column_coef_rho_status, "fixed")
  expect_identical(
    gllvmTMB::extract_Sigma(fit, level = "column_coef")$rho,
    0.37
  )
})

test_that("raw-scale K_rho oracle is exact and does not snap near one", {
  fx <- .make_phylo_coef_fixture()
  for (rho in c(0, 0.37, 0.999)) {
    resolved <- gllvmTMB:::.resolve_phylo_coef_precision(
      phylo_tree = NULL,
      phylo_vcv = fx$K,
      data = fx$data,
      group = "trait",
      rho = rho
    )
    K_rho <- rho * fx$K + (1 - rho) * diag(diag(fx$K))
    expect_equal(unname(as.matrix(resolved$Ainv)),
                 unname(solve(K_rho)), tolerance = 1e-12)
    expect_equal(resolved$log_det,
                 as.numeric(determinant(K_rho, logarithm = TRUE)$modulus),
                 tolerance = 1e-12)
    expect_equal(resolved$K_rho, K_rho, tolerance = 0)
  }

  near_one <- gllvmTMB:::.resolve_phylo_coef_precision(
    NULL, fx$K, fx$data, "trait", rho = 0.999
  )
  expect_false(identical(near_one$K_rho, fx$K))

  scaled <- gllvmTMB:::.resolve_phylo_coef_precision(
    NULL, 3.7 * fx$K, fx$data, "trait", rho = 0.37
  )
  base <- gllvmTMB:::.resolve_phylo_coef_precision(
    NULL, fx$K, fx$data, "trait", rho = 0.37
  )
  expect_equal(scaled$K_rho, 3.7 * base$K_rho, tolerance = 1e-12)
})

test_that("rho one rewrites exactly to released phylo_slope syntax", {
  fx <- .make_phylo_coef_fixture()
  formula <- value ~ 0 + trait +
    phylo_coef(0 + x + z || trait, vcv = fx$K, rho = 1)
  rewritten <- .rewrite_private_phylo_coef(formula, fx$data)

  expect_identical(
    rewritten[[3L]],
    (value ~ 0 + trait + phylo_slope(x + z || trait, vcv = fx$K))[[3L]]
  )
})

test_that("rho one hard dispatch validates its dense source first", {
  fx <- .make_phylo_coef_fixture()

  nonsymmetric <- fx$K
  nonsymmetric[1L, 2L] <- nonsymmetric[1L, 2L] + 0.2
  expect_error(
    .fit_private_phylo_coef(
      fx,
      value ~ 0 + trait +
        phylo_coef(0 + x | trait, vcv = nonsymmetric, rho = 1)
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  indefinite <- fx$K
  indefinite[1L, 1L] <- -1
  expect_error(
    .fit_private_phylo_coef(
      fx,
      value ~ 0 + trait +
        phylo_coef(0 + x | trait, vcv = indefinite, rho = 1)
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
})

test_that("fixed-rho source validation is exact and label-safe", {
  fx <- .make_phylo_coef_fixture()

  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, NULL, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, unname(fx$K), fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_labels"
  )

  wrong_labels <- fx$K
  dimnames(wrong_labels) <- list(
    paste0("wrong", seq_len(nrow(wrong_labels))),
    paste0("wrong", seq_len(ncol(wrong_labels)))
  )
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, wrong_labels, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_labels"
  )

  nonsymmetric <- fx$K
  nonsymmetric[1L, 2L] <- nonsymmetric[1L, 2L] + 0.2
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, nonsymmetric, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  indefinite <- fx$K
  indefinite[1L, 1L] <- -1
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, indefinite, fx$data, "trait", rho = 1
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, indefinite, fx$data, "trait", rho = 0
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  augmented_labels <- c(fx$traits, "internal-node")
  bad_augmented <- Matrix::Diagonal(
    n = length(augmented_labels),
    x = c(rep(1, length(fx$traits)), -1)
  )
  dimnames(bad_augmented) <- list(augmented_labels, augmented_labels)
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, bad_augmented, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  nonfinite_augmented <- bad_augmented
  diag(nonfinite_augmented) <- c(
    rep(1, length(fx$traits)), NA_real_
  )
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, nonfinite_augmented, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  singular_augmented <- bad_augmented
  diag(singular_augmented) <- c(rep(1, length(fx$traits)), 0)
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, singular_augmented, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  asymmetric_augmented <- Matrix::Diagonal(
    n = length(augmented_labels), x = 1
  )
  dimnames(asymmetric_augmented) <- list(
    augmented_labels, augmented_labels
  )
  asymmetric_augmented[1L, 2L] <- 0.2
  expect_error(
    gllvmTMB:::.resolve_phylo_coef_precision(
      NULL, asymmetric_augmented, fx$data, "trait", rho = 0.37
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
})

test_that("interior tree rho is built on response-column tip covariance", {
  skip_if_not_installed("ape")
  fx <- .make_phylo_coef_fixture(seed = 13126L)
  rho <- 0.37
  resolved <- gllvmTMB:::.resolve_phylo_coef_precision(
    phylo_tree = fx$tree,
    phylo_vcv = NULL,
    data = fx$data,
    group = "trait",
    rho = rho
  )
  K_tip <- ape::vcv.phylo(fx$tree, corr = TRUE)[fx$traits, fx$traits]
  K_rho <- rho * K_tip + (1 - rho) * diag(diag(K_tip))
  expect_identical(resolved$n_aug, length(fx$traits))
  expect_identical(rownames(resolved$K_rho), fx$traits)
  expect_equal(resolved$K_rho, K_rho, tolerance = 1e-12)
  expect_equal(as.matrix(resolved$Ainv), solve(K_rho), tolerance = 1e-10)
})

test_that("permuted dense labels and sparse precision resolve identically", {
  fx <- .make_phylo_coef_fixture()
  perm <- rev(fx$traits)
  K_perm <- fx$K[perm, perm]
  dense <- gllvmTMB:::.resolve_phylo_coef_precision(
    NULL, K_perm, fx$data, "trait", rho = 0.37
  )
  sparse_Q <- Matrix::Matrix(solve(fx$K), sparse = TRUE)
  sparse <- gllvmTMB:::.resolve_phylo_coef_precision(
    NULL, sparse_Q, fx$data, "trait", rho = 0.37
  )
  expect_equal(dense$K_rho, sparse$K_rho, tolerance = 1e-10)
  expect_equal(as.matrix(dense$Ainv), as.matrix(sparse$Ainv),
               tolerance = 1e-10)
  expect_identical(rownames(dense$K_rho), fx$traits)
})

test_that("rho one is exactly released phylo_slope for both bars and dense VCV", {
  fx <- .make_phylo_coef_fixture(seed = 13122L)
  pairs <- list(
    list(
      coef = value ~ 0 + trait +
        phylo_coef(0 + x + z | trait, vcv = fx$K, rho = 1),
      slope = value ~ 0 + trait +
        phylo_slope(x + z | trait, vcv = fx$K)
    ),
    list(
      coef = value ~ 0 + trait +
        phylo_coef(0 + x + z || trait, vcv = fx$K, rho = 1),
      slope = value ~ 0 + trait +
        phylo_slope(x + z || trait, vcv = fx$K)
    )
  )
  for (pair in pairs) {
    expect_no_warning(coef_fit <- .fit_private_phylo_coef(fx, pair$coef))
    expect_no_warning(slope_fit <- .fit_released_phylo_slope(fx, pair$slope))
    .expect_route_identical(coef_fit, slope_fit)

    ## Exact endpoint identity deliberately inherits the released dense-VCV
    ## route's historical 1e-8 conditioning. Interior fixed rho has no ridge.
    K_endpoint <- fx$K + diag(1e-8, nrow(fx$K))
    endpoint_precision <- unname(as.matrix(coef_fit$tmb_data$Ainv_phy_slope))
    expect_equal(endpoint_precision, unname(solve(K_endpoint)),
                 tolerance = 1e-12)
    expect_equal(
      coef_fit$tmb_data$log_det_A_phy_slope,
      as.numeric(determinant(K_endpoint, logarithm = TRUE)$modulus),
      tolerance = 1e-12
    )
    expect_gt(max(abs(endpoint_precision - unname(solve(fx$K)))), 1e-10)
  }
})

test_that("rho one is exactly released phylo_slope for both bars and tree", {
  skip_if_not_installed("ape")
  fx <- .make_phylo_coef_fixture(seed = 13123L)
  pairs <- list(
    list(
      coef = value ~ 0 + trait +
        phylo_coef(0 + x | trait, tree = fx$tree, rho = 1),
      slope = value ~ 0 + trait +
        phylo_slope(x | trait, tree = fx$tree)
    ),
    list(
      coef = value ~ 0 + trait +
        phylo_coef(0 + x || trait, tree = fx$tree, rho = 1),
      slope = value ~ 0 + trait +
        phylo_slope(x || trait, tree = fx$tree)
    )
  )
  for (pair in pairs) {
    expect_no_warning(coef_fit <- .fit_private_phylo_coef(fx, pair$coef))
    expect_no_warning(slope_fit <- .fit_released_phylo_slope(fx, pair$slope))
    .expect_route_identical(coef_fit, slope_fit)
  }
})

test_that("interior rho uses ordered intercept-slope matrix-normal design", {
  fx <- .make_phylo_coef_fixture(seed = 13124L, n_traits = 8L)
  expect_no_warning(
    full <- .fit_private_phylo_coef(
      fx,
      value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = 0.37)
    )
  )
  expect_no_warning(
    diagonal <- .fit_private_phylo_coef(
      fx,
      value ~ 1 + phylo_coef(1 + x || trait, vcv = fx$K, rho = 0.37)
    )
  )
  expect_no_warning(
    intercept_endpoint <- .fit_private_phylo_coef(
      fx,
      value ~ 1 + phylo_coef(1 + x | trait, vcv = fx$K, rho = 1)
    )
  )

  K_rho <- 0.37 * fx$K + 0.63 * diag(diag(fx$K))
  expect_equal(unname(as.matrix(full$tmb_data$Ainv_phy_slope)),
               unname(solve(K_rho)), tolerance = 1e-12)
  expect_equal(full$tmb_data$log_det_A_phy_slope,
               as.numeric(determinant(K_rho, logarithm = TRUE)$modulus),
               tolerance = 1e-12)
  expect_equal(full$tmb_data$Z_phy_aug[, , 1L],
               cbind(`(Intercept)` = 1, x = fx$data$x),
               ignore_attr = TRUE)
  expect_identical(full$use$response_column_coef_basis,
                   c("(Intercept)", "x"))
  expect_identical(full$use$response_column_coef_rho, 0.37)
  expect_true(all(is.finite(full$tmb_obj$gr(full$opt$par))))
  expect_true(all(is.finite(diagonal$tmb_obj$gr(diagonal$opt$par))))
  expect_equal(diagonal$report$Sigma_b_dep[1L, 2L], 0, tolerance = 0)
  expect_equal(
    unname(as.matrix(intercept_endpoint$tmb_data$Ainv_phy_slope)),
    unname(solve(fx$K)), tolerance = 1e-12
  )
  expect_identical(intercept_endpoint$use$response_column_coef_rho, 1)
})
