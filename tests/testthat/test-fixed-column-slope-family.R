## Fixed-source response-column slopes.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula term | DGP draw | Extractor | Truth |
## |--------|--------------|----------|-----------|-------|
## | B[,x] | slope(x + z | trait) | row draw from N(0, Sigma_predictor) | extract_Sigma(level="column_slope") | Sigma["x","x"] |
## | B[,z] | slope(x + z | trait) | same row draw, correlated with B[,x] | extract_Sigma(level="column_slope") | Sigma["z","z"] and Sigma["x","z"] |
##
## With b = vec(B^T) in trait-major order, the contract is
## Cov(b) = K_column %x% Sigma_predictor.  `slope()` fixes K_column = I;
## phylo/animal/kernel helpers replace I with their labelled fixed source.

.make_fixed_column_slope_fixture <- function(
    seed = 130L, n_traits = 4L, n_unit = 14L, n_rep = 2L) {
  set.seed(seed)
  tr <- paste0("t", seq_len(n_traits))
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(tr, levels = tr),
    rep = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  dat$value <- 0.15 * as.integer(dat$trait) +
    stats::rnorm(nrow(dat), sd = 0.45)
  K <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2)
  dimnames(K) <- list(tr, tr)
  list(data = dat, K = K, traits = tr)
}

.fit_fixed_column_slope <- function(fx, formula, family = stats::gaussian()) {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = family,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
}

.free_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) {
    if (is.null(x)) NULL else as.integer(x)
  })
}

test_that("ordinary column slopes use a trait-major slope-only design oracle", {
  fx <- .make_fixed_column_slope_fixture()
  fit <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + slope(x + z || trait)
  )

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_column_slope, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)
  expect_identical(fit$tmb_data$n_aug_phy_slope, length(fx$traits))
  expect_equal(unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
               diag(length(fx$traits)))
  expect_identical(
    fit$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$trait) - 1L
  )
  ## No random-intercept column: the complete block-local design is x, z.
  expect_equal(fit$tmb_data$Z_phy_aug[, , 1L],
               cbind(x = fx$data$x, z = fx$data$z),
               ignore_attr = TRUE)

  ext <- extract_Sigma(fit, level = "column_slope")
  expect_identical(dim(ext$Sigma), c(2L, 2L))
  expect_identical(rownames(ext$Sigma), c("x", "z"))
  expect_identical(ext$source$type, "ordinary")
  expect_identical(ext$source$labels, fx$traits)
  expect_identical(ext$column_labels, fx$traits)

  ## Public trait-major oracle: block (i,j) is I[i,j] * Sigma_predictor.
  coefficient_cov <- kronecker(diag(length(fx$traits)), ext$Sigma)
  expect_equal(
    coefficient_cov[seq(1L, 2L * length(fx$traits) - 1L, by = 2L),
                    seq(1L, 2L * length(fx$traits) - 1L, by = 2L)],
    ext$Sigma[1L, 1L] * diag(length(fx$traits))
  )
  expect_equal(coefficient_cov[row(coefficient_cov) != col(coefficient_cov)],
               rep(0, nrow(coefficient_cov)^2 - nrow(coefficient_cov)))
})

test_that("one-predictor bars are objective- and extractor-equivalent by source", {
  fx <- .make_fixed_column_slope_fixture(seed = 131L, n_traits = 3L)
  forms <- list(
    ordinary = list(
      value ~ 0 + trait + slope(x | trait),
      value ~ 0 + trait + slope(x || trait)
    ),
    phylo = list(
      value ~ 0 + trait + phylo_slope(x | trait, vcv = fx$K),
      value ~ 0 + trait + phylo_slope(x || trait, vcv = fx$K)
    ),
    animal = list(
      value ~ 0 + trait + animal_slope(x | trait, A = fx$K),
      value ~ 0 + trait + animal_slope(x || trait, A = fx$K)
    )
  )

  for (source in names(forms)) {
    full <- .fit_fixed_column_slope(fx, forms[[source]][[1L]])
    diagonal <- .fit_fixed_column_slope(fx, forms[[source]][[2L]])
    expect_equal(full$opt$convergence, 0L, info = source)
    expect_equal(diagonal$opt$convergence, 0L, info = source)
    expect_identical(full$opt$objective, diagonal$opt$objective, info = source)
    expect_identical(names(full$opt$par), names(diagonal$opt$par), info = source)
    expect_identical(.free_map_signature(full), .free_map_signature(diagonal),
                     info = source)
    expect_identical(
      extract_Sigma(full, level = "column_slope"),
      extract_Sigma(diagonal, level = "column_slope"),
      info = source
    )
    expect_identical(
      extract_Sigma(full, level = "column_slope")$source$type,
      source
    )
  }
})

test_that("identity kernel is exactly the ordinary column source", {
  fx <- .make_fixed_column_slope_fixture(seed = 132L, n_traits = 3L)
  I <- diag(length(fx$traits))
  dimnames(I) <- list(fx$traits, fx$traits)
  ordinary <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + slope(x + z | trait)
  )
  kernel <- .fit_fixed_column_slope(
    fx,
    value ~ 0 + trait + kernel_slope(x + z | trait, K = I, name = "identity")
  )

  expect_identical(ordinary$opt$objective, kernel$opt$objective)
  expect_identical(names(ordinary$opt$par), names(kernel$opt$par))
  expect_identical(.free_map_signature(ordinary), .free_map_signature(kernel))
  expect_equal(ordinary$tmb_data$Ainv_phy_slope,
               kernel$tmb_data$Ainv_phy_slope, tolerance = 0)
  expect_identical(
    extract_Sigma(ordinary, level = "column_slope")$Sigma,
    extract_Sigma(kernel, level = "column_slope")$Sigma
  )
  ext <- extract_Sigma(kernel, level = "column_slope")
  expect_identical(ext$source$type, "kernel")
  expect_identical(ext$source$name, "identity")
  expect_identical(ext$source$scale, "as_supplied")
})

test_that("kernel labels, not storage order, control the response-column map", {
  fx <- .make_fixed_column_slope_fixture(seed = 133L)
  perm <- rev(seq_along(fx$traits))
  K_perm <- fx$K[perm, perm, drop = FALSE]
  aligned <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + kernel_slope(x + z | trait, K = fx$K)
  )
  permuted <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + kernel_slope(x + z | trait, K = K_perm)
  )

  expect_identical(aligned$opt$objective, permuted$opt$objective)
  expect_equal(aligned$tmb_data$Ainv_phy_slope,
               permuted$tmb_data$Ainv_phy_slope, tolerance = 0)
  expect_identical(
    extract_Sigma(aligned, level = "column_slope")$Sigma,
    extract_Sigma(permuted, level = "column_slope")$Sigma
  )
  expect_identical(
    extract_Sigma(permuted, level = "column_slope")$source$labels,
    fx$traits
  )
})

test_that("column-slope helpers reject malformed sources and unsupported routes", {
  fx <- .make_fixed_column_slope_fixture(seed = 134L, n_traits = 3L)
  no_names <- unname(fx$K)
  bad_labels <- fx$K
  dimnames(bad_labels) <- list(paste0("bad", 1:3), paste0("bad", 1:3))
  nonsymmetric <- fx$K
  nonsymmetric[1L, 2L] <- nonsymmetric[1L, 2L] + 0.2
  indefinite <- fx$K
  indefinite[1L, 1L] <- -1

  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + kernel_slope(x | trait, K = no_names)
    ), "row and column names"
  )
  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + kernel_slope(x | trait, K = bad_labels)
    ), "match the response-column levels exactly"
  )
  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + kernel_slope(x | trait, K = nonsymmetric)
    ), "must be symmetric"
  )
  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + kernel_slope(x | trait, K = indefinite)
    ), "positive definite"
  )
  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + slope(1 + x | trait)
    ), "no intercept"
  )
  expect_error(
    .fit_fixed_column_slope(
      fx, value ~ 0 + trait + slope(x | unit)
    ), "response-column factor"
  )
  fx_count <- fx
  fx_count$data$value <- stats::rpois(nrow(fx_count$data), 2)
  expect_error(
    .fit_fixed_column_slope(
      fx_count, value ~ 0 + trait + slope(x | trait), stats::poisson()
    ), "Gaussian responses only"
  )

  wide <- data.frame(unit = factor(paste0("u", 1:6)), x = stats::rnorm(6),
                     y1 = stats::rnorm(6), y2 = stats::rnorm(6))
  expect_error(
    gllvmTMB::gllvmTMB(
      traits(y1, y2) ~ 1 + slope(x | trait), data = wide, unit = "unit"
    ), "require long-format data",
    class = "gllvmTMB_column_slope_wide_unsupported"
  )
})

test_that("ordinary Gaussian column slopes recover a known full covariance", {
  set.seed(135L)
  n_traits <- 24L
  n_unit <- 36L
  tr <- paste0("t", seq_len(n_traits))
  Sigma_true <- matrix(
    c(0.36, 0.09, 0.09, 0.16), 2L, 2L,
    dimnames = list(c("x", "z"), c("x", "z"))
  )
  B <- matrix(stats::rnorm(n_traits * 2L), n_traits, 2L) %*% chol(Sigma_true)
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(tr, levels = tr),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  ti <- as.integer(dat$trait)
  dat$value <- 0.1 * ti + B[ti, 1L] * dat$x + B[ti, 2L] * dat$z +
    stats::rnorm(nrow(dat), sd = 0.18)
  fx <- list(data = dat)

  fit <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + slope(x + z | trait)
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
  ## Fixed-parameter gradient at the generating covariance/residual scale.
  ## theta_dep_chol packs log diagonals first, then strict-lower entries.
  truth_par <- fit$opt$par
  L_true <- t(chol(Sigma_true))
  theta_true <- c(log(diag(L_true)), L_true[2L, 1L])
  truth_par[names(truth_par) == "theta_dep_chol"] <- theta_true
  truth_par[names(truth_par) == "log_sigma_eps"] <- log(0.18)
  expect_true(all(is.finite(fit$tmb_obj$gr(truth_par))))
  Sigma_hat <- extract_Sigma(fit, level = "column_slope")$Sigma
  expect_lt(max(abs(Sigma_hat - Sigma_true)), 0.14)
  expect_true(all(eigen(Sigma_hat, symmetric = TRUE, only.values = TRUE)$values > 0))
})

test_that("structured fixed sources recover the same known full covariance", {
  set.seed(137L)
  n_traits <- 30L
  n_unit <- 36L
  tr <- paste0("t", seq_len(n_traits))
  Sigma_true <- matrix(
    c(0.36, 0.09, 0.09, 0.16), 2L, 2L,
    dimnames = list(c("x", "z"), c("x", "z"))
  )
  K <- 0.15^abs(outer(seq_len(n_traits), seq_len(n_traits), "-"))
  dimnames(K) <- list(tr, tr)
  Z <- matrix(stats::rnorm(n_traits * 2L), n_traits, 2L)
  B <- t(chol(K)) %*% Z %*% chol(Sigma_true)
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(tr, levels = tr),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  ti <- as.integer(dat$trait)
  dat$value <- 0.1 * ti + B[ti, 1L] * dat$x + B[ti, 2L] * dat$z +
    stats::rnorm(nrow(dat), sd = 0.18)
  fx <- list(data = dat, K = K)
  forms <- list(
    phylo = value ~ 0 + trait + phylo_slope(x + z | trait, vcv = K),
    animal = value ~ 0 + trait + animal_slope(x + z | trait, A = K),
    kernel = value ~ 0 + trait + kernel_slope(x + z | trait, K = K)
  )

  estimates <- lapply(names(forms), function(source) {
    fit <- .fit_fixed_column_slope(fx, forms[[source]])
    expect_equal(fit$opt$convergence, 0L, info = source)
    expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))), info = source)
    ext <- extract_Sigma(fit, level = "column_slope")
    expect_identical(ext$source$type, source)
    expect_lt(max(abs(ext$Sigma - Sigma_true)), 0.15, label = source)
    ext$Sigma
  })
  ## Phylogenetic and animal inputs share their protected 1e-8 ridge; the
  ## exact dense-kernel route differs only below a scientifically relevant
  ## numerical scale for this well-conditioned fixture.
  expect_equal(estimates[[1L]], estimates[[2L]], tolerance = 0)
  expect_equal(estimates[[1L]], estimates[[3L]], tolerance = 1e-5)
})

test_that("legacy non-trait phylo and animal slopes retain their scalar route", {
  fx <- .make_fixed_column_slope_fixture(seed = 136L, n_traits = 3L)
  fx$data$source_id <- factor(rep(fx$traits, length.out = nrow(fx$data)),
                              levels = fx$traits)
  phy <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + phylo_slope(x | source_id, vcv = fx$K)
  )
  animal <- .fit_fixed_column_slope(
    fx, value ~ 0 + trait + animal_slope(x | source_id, A = fx$K)
  )

  expect_identical(phy$tmb_data$use_phylo_column_slope, 0L)
  expect_identical(animal$tmb_data$use_phylo_column_slope, 0L)
  expect_true("log_sigma_slope" %in% names(phy$opt$par))
  expect_false("theta_dep_chol" %in% names(phy$opt$par))
  expect_identical(phy$opt$objective, animal$opt$objective)
  expect_identical(names(phy$opt$par), names(animal$opt$par))
  expect_identical(.free_map_signature(phy), .free_map_signature(animal))

  expect_snapshot(list(
    use_phylo_slope = phy$tmb_data$use_phylo_slope,
    use_phylo_column_slope = phy$tmb_data$use_phylo_column_slope,
    use_phylo_slope_correlated = phy$tmb_data$use_phylo_slope_correlated,
    parameter_names = names(phy$opt$par),
    random = phy$random
  ))
})
