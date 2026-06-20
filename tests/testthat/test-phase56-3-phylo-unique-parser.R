make_phase56_3_phylo_fixture <- function(seed = 563) {
  set.seed(seed)
  n_sp <- 8L
  n_traits <- 2L
  n_rep <- 3L
  sp <- paste0("sp", seq_len(n_sp))
  tr <- paste0("t", seq_len(n_traits))
  df <- expand.grid(
    species = factor(sp, levels = sp),
    trait = factor(tr, levels = tr),
    rep = seq_len(n_rep)
  )
  df$x <- stats::rnorm(nrow(df))
  mu <- c(0.4, -0.2)[as.integer(df$trait)]
  alpha <- stats::rnorm(n_sp, sd = 0.25)
  beta <- stats::rnorm(n_sp, sd = 0.20)
  names(alpha) <- names(beta) <- sp
  df$value <- mu + alpha[as.character(df$species)] +
    beta[as.character(df$species)] * df$x +
    stats::rnorm(nrow(df), sd = 0.15)
  Cphy <- diag(n_sp)
  dimnames(Cphy) <- list(sp, sp)
  list(data = df, Cphy = Cphy)
}

test_that("Phase 56.3 parser classifies phylo_unique augmented LHS forms", {
  withr::local_options(lifecycle_verbosity = "quiet")
  Cphy <- diag(2)
  dimnames(Cphy) <- list(c("sp1", "sp2"), c("sp1", "sp2"))

  wide_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = Cphy)
  )
  wide <- gllvmTMB:::parse_multi_formula(wide_formula)$covstructs[[1L]]
  expect_identical(wide$kind, "phylo_slope")
  expect_true(isTRUE(wide$extra$.phylo_unique_augmented))
  expect_identical(wide$extra$lhs_form, "wide_intercept_slope")
  expect_identical(wide$extra$slope_col, "x")

  long_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = Cphy)
  )
  long <- gllvmTMB:::parse_multi_formula(long_formula)$covstructs[[1L]]
  expect_identical(long$kind, "phylo_slope")
  expect_true(isTRUE(long$extra$.phylo_unique_augmented))
  expect_identical(long$extra$lhs_form, "long_intercept_slope")
  expect_identical(long$extra$slope_col, "x")
})

test_that("Phase 56.3 keeps phylo_unique(0 + trait | species) on the legacy unique path", {
  withr::local_options(lifecycle_verbosity = "quiet")
  Cphy <- diag(2)
  dimnames(Cphy) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + phylo_unique(0 + trait | species, vcv = Cphy)
  )
  cs <- gllvmTMB:::parse_multi_formula(formula)$covstructs[[1L]]
  expect_identical(cs$kind, "phylo_rr")
  expect_true(isTRUE(cs$extra$.phylo_unique))
  expect_null(cs$extra$.phylo_unique_augmented)
})

test_that("Phase 56.3 builds two-column Z_phy_aug for wide augmented phylo_unique", {
  withr::local_options(lifecycle_verbosity = "quiet")
  testthat::skip_on_cran()
  fx <- make_phase56_3_phylo_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = fx$Cphy),
    data = fx$data,
    unit = "species",
    cluster = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)
  expect_equal(dim(fit$tmb_data$Z_phy_aug), c(nrow(fx$data), 2L, 1L))
  expect_equal(drop(fit$tmb_data$Z_phy_aug[, 1L, 1L]), rep(1, nrow(fx$data)))
  expect_equal(drop(fit$tmb_data$Z_phy_aug[, 2L, 1L]), fx$data$x)
  expect_true(any(names(fit$tmb_obj$env$last.par.best) == "b_phy_aug"))
})

test_that("Phase 56.3 builds equivalent Z_phy_aug for long augmented phylo_unique", {
  withr::local_options(lifecycle_verbosity = "quiet")
  testthat::skip_on_cran()
  fx <- make_phase56_3_phylo_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = fx$Cphy),
    data = fx$data,
    unit = "species",
    cluster = "species",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)
  expect_equal(dim(fit$tmb_data$Z_phy_aug), c(nrow(fx$data), 2L, 1L))
  expect_equal(drop(fit$tmb_data$Z_phy_aug[, 1L, 1L]), rep(1, nrow(fx$data)))
  expect_equal(drop(fit$tmb_data$Z_phy_aug[, 2L, 1L]), fx$data$x)
})

test_that("Phase 56.3 keeps unsupported phylo_unique augmented LHS fail-loud", {
  withr::local_options(lifecycle_verbosity = "quiet")
  Cphy <- diag(2)
  dimnames(Cphy) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_unique(1 + x + z | species, vcv = Cphy)
    ),
    regexp = "Phase 56\\.3 accepts only|augmented LHS"
  )
})
