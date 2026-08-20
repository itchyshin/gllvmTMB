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
  expect_identical(dim(ext$Sigma), c(2L, 2L))
  expect_equal(ext$Sigma[1L, 2L], 0, tolerance = 1e-12)
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
  suppressWarnings(expect_error(gllvmTMB::gllvmTMB(
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
  expect_error(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_indep(0 + lat | trait, vcv = fx$A) +
      phylo_indep(0 + trait | cluster, vcv = A_cluster),
    data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ), "cannot yet be combined"))
})
