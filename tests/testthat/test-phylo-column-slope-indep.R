## Column-predictor phylogenetic slopes: a response-column tree times a
## diagonal covariance over predictors.  This is deliberately distinct from
## the older intercept-plus-slope `phylo_indep(1 + x | species)` route.

.make_column_slope_fixture <- function(seed = 1196L) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(3L))
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(18L))),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  ## Intentionally unrelated to `trait`: this is the PR-0 routing bite.
  dat$cluster <- factor(rep(c("c1", "c2"), length.out = nrow(dat)))
  dat$lat <- stats::rnorm(nrow(dat))
  dat$temp <- stats::rnorm(nrow(dat))
  dat$value <- 0.3 * (dat$trait == "t2") + stats::rnorm(nrow(dat), sd = 0.5)
  A <- diag(length(trait_levels))
  dimnames(A) <- list(trait_levels, trait_levels)
  list(data = dat, A = A, traits = trait_levels)
}

.fit_column_slope <- function(fx, formula = NULL, family = stats::gaussian()) {
  if (is.null(formula)) {
    formula <- value ~ 0 + trait + phylo_indep(0 + lat + temp | trait, vcv = fx$A)
  }
  suppressMessages(gllvmTMB::gllvmTMB(
    formula, data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    family = family, control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
}

## Symbolic <-> implementation alignment for the retained recovery cell:
##
## | Symbol | Formula term | DGP draw | Extractor | Truth |
## |--------|--------------|----------|-----------|-------|
## | B[,lat] | phylo_indep(0 + lat + temp | trait) | L_A z_lat * .60 | extract_Sigma(level = "column_slope") | .60^2 |
## | B[,temp] | phylo_indep(0 + lat + temp | trait) | L_A z_temp * .35 | extract_Sigma(level = "column_slope") | .35^2 |
##
## With b = vec(t(B)) (trait-major), L_A L_A' = A, so
## Cov(b) = A x diag(.60^2, .35^2). The native predictor-major storage is
## the corresponding permutation of this same covariance.
.make_column_slope_recovery_fixture <- function(
    seed, n_traits = 20L, n_unit = 50L,
    sd_slope = c(lat = 0.60, temp = 0.35), residual_sd = 0.25) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  A <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 3)
  dimnames(A) <- list(trait_levels, trait_levels)
  B <- t(chol(A + diag(1e-8, n_traits))) %*%
    matrix(stats::rnorm(n_traits * length(sd_slope)), n_traits, length(sd_slope))
  B <- sweep(B, 2L, sd_slope, "*")
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$cluster <- factor(rep(c("c1", "c2"), length.out = nrow(dat)))
  dat$lat <- stats::rnorm(nrow(dat))
  dat$temp <- stats::rnorm(nrow(dat))
  trait_id <- as.integer(dat$trait)
  dat$value <- 0.15 * trait_id + B[trait_id, 1L] * dat$lat +
    B[trait_id, 2L] * dat$temp + stats::rnorm(nrow(dat), sd = residual_sd)
  list(data = dat, A = A, B = B, sd_slope = sd_slope)
}

test_that("column slopes use predictor-only design and the RHS trait map", {
  fx <- .make_column_slope_fixture()
  fit <- .fit_column_slope(fx)

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_column_slope, 1L)
  expect_identical(fit$tmb_data$n_aug_phy_slope, length(fx$traits))
  expect_identical(fit$tmb_data$n_aug_phy, nlevels(fx$data$cluster))
  expect_identical(
    fit$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$trait) - 1L
  )
  expect_equal(unname(fit$tmb_data$Z_phy_aug[, , 1L]),
               unname(as.matrix(fx$data[c("lat", "temp")])))
  ## A diagonal Cholesky map leaves exactly P log-SDs free.
  expect_identical(sum(names(fit$opt$par) == "theta_dep_chol"), 2L)
  Sigma <- as.matrix(fit$report$Sigma_b_dep)
  expect_equal(Sigma[row(Sigma) != col(Sigma)], rep(0, 2L), tolerance = 1e-12)

  ext <- extract_Sigma(fit, level = "column_slope")
  expect_identical(ext$predictors, c("lat", "temp"))
  expect_identical(ext$column_labels, fx$traits)
  expect_identical(ext$source$type, "phylo")
  expect_identical(ext$source$grouping, "trait")
  expect_identical(ext$source$labels, fx$traits)
  expect_identical(dim(ext$Sigma), c(2L, 2L))
  expect_equal(ext$Sigma[1L, 2L], 0, tolerance = 1e-12)
  expect_error(extract_Sigma(fit, level = "phy"), "column_slope")
  expect_error(slope_sd_ci(fit), "does not yet provide intervals")
})

test_that("column slope grammar rejects an intercept, trait basis, and wrong RHS", {
  fx <- .make_column_slope_fixture()
  common <- list(data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
                 control = gllvmTMB::gllvmTMBcontrol(se = FALSE))
  expect_error(do.call(gllvmTMB::gllvmTMB, c(list(
    value ~ 0 + trait + phylo_indep(1 + lat | trait, vcv = fx$A)
  ), common)), "predictor-only")
  expect_error(do.call(gllvmTMB::gllvmTMB, c(list(
    value ~ 0 + trait + phylo_indep(0 + trait + lat | trait, vcv = fx$A)
  ), common)), "LHS richer")
  expect_error(do.call(gllvmTMB::gllvmTMB, c(list(
    value ~ 0 + trait + phylo_indep(0 + lat + temp | cluster, vcv = fx$A)
  ), common)), "resolved response-column")
})

test_that("column slopes are Gaussian-only", {
  fx <- .make_column_slope_fixture()
  fx$data$value <- rpois(nrow(fx$data), lambda = 2)
  expect_error(
    .fit_column_slope(fx, family = stats::poisson()),
    "Gaussian responses only"
  )
})

test_that("column slopes reject transformed, factor, and non-finite predictors", {
  fx <- .make_column_slope_fixture()
  common <- list(data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
                 control = gllvmTMB::gllvmTMBcontrol(se = FALSE))
  expect_error(do.call(gllvmTMB::gllvmTMB, c(list(
    value ~ 0 + trait + phylo_indep(0 + I(lat^2) | trait, vcv = fx$A)
  ), common)), "LHS richer")
  fx$data$method <- factor(rep(c("a", "b"), length.out = nrow(fx$data)))
  expect_error(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + method | trait, vcv = fx$A),
    data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ), "numeric")
  fx$data$lat[1L] <- NA_real_
  expect_error(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + lat | trait, vcv = fx$A),
    data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ), "finite")
})

test_that("column slopes refuse a second phylogenetic indexing axis", {
  fx <- .make_column_slope_fixture()
  A_cluster <- diag(2L)
  dimnames(A_cluster) <- list(levels(fx$data$cluster), levels(fx$data$cluster))
  suppressWarnings(
    expect_error(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_indep(0 + lat | trait, vcv = fx$A) +
        phylo_indep(0 + trait | cluster, vcv = A_cluster),
      data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ), "cannot yet be combined")
  )
})

test_that("Gaussian column slopes recover diagonal predictor covariance", {
  skip_if_not_heavy()
  seeds <- c(1196L, 2201L, 3301L, 4401L)
  estimates <- matrix(NA_real_, nrow = length(seeds), ncol = 2L,
                      dimnames = list(NULL, c("lat", "temp")))

  for (i in seq_along(seeds)) {
    fx <- .make_column_slope_recovery_fixture(seeds[[i]])
    fit <- .fit_column_slope(fx)
    expect_equal(fit$opt$convergence, 0L)
    Sigma <- extract_Sigma(fit, level = "column_slope")$Sigma
    ## Matrix oracle in public trait-major ordering: covariance blocks are
    ## A[t,t'] * Sigma, so each predictor has source covariance A and every
    ## cross-predictor element is structurally zero.
    coefficient_cov <- kronecker(fx$A, Sigma)
    n_traits <- nrow(fx$A)
    expect_equal(as.matrix(fit$tmb_data$Ainv_phy_slope),
                 solve(fx$A + diag(1e-8, n_traits)), tolerance = 1e-8)
    expect_equal(fit$tmb_data$phylo_slope_aug_id,
                 as.integer(fx$data$trait) - 1L)
    expect_equal(coefficient_cov[seq(2L, 2L * n_traits, by = 2L),
                                 seq(1L, 2L * n_traits - 1L, by = 2L)],
                 matrix(0, n_traits, n_traits), tolerance = 1e-12)
    expect_equal(unname(coefficient_cov[seq(1L, 2L * n_traits - 1L, by = 2L),
                                         seq(1L, 2L * n_traits - 1L, by = 2L)]),
                 unname(Sigma[1L, 1L] * fx$A), tolerance = 1e-12)
    ## Negative control: the same correlated-source draw fits materially worse
    ## when the RHS source is forcibly replaced by an identity matrix.
    if (i == 1L) {
      fx_identity <- fx
      fx_identity$A <- diag(n_traits)
      dimnames(fx_identity$A) <- dimnames(fx$A)
      fit_identity <- .fit_column_slope(fx_identity)
      expect_gt(fit_identity$opt$objective, fit$opt$objective + 1)
    }
    estimates[i, ] <- sqrt(diag(Sigma))
  }

  ratio <- colMeans(estimates) / fx$sd_slope
  ## Calibrated by the four fixed draws above: mean ratios were ~0.91 for
  ## both slopes. The [0.70, 1.30] band is deliberately broad enough for
  ## platform rounding but would reject a zeroed or substantially mis-scaled
  ## covariance route.
  expect_true(all(is.finite(ratio)))
  expect_true(all(ratio >= 0.70 & ratio <= 1.30))
})
