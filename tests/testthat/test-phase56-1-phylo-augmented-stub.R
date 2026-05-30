test_that("Phase 56.1 augmented phylo slope stubs stay dormant by default", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")

  set.seed(56)
  n_sp <- 10
  n_traits <- 2
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait = factor(
      paste0("t", seq_len(n_traits)),
      levels = paste0("t", seq_len(n_traits))
    ),
    rep = seq_len(2)
  )
  df$x <- rnorm(nrow(df))
  df$value <- 0.2 + 0.4 * df$x + rnorm(nrow(df), sd = 0.2)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | species),
    data = df,
    phylo_tree = tree,
    unit = "species"
  )))

  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 0L)
  expect_identical(fit$tmb_data$n_lhs_cols, 1L)
  expect_equal(dim(fit$tmb_data$Z_phy_aug), c(nrow(df), 1L, 1L))
  expect_equal(drop(fit$tmb_data$Z_phy_aug[, 1L, 1L]), fit$tmb_data$x_phy_slope)
  expect_true(any(names(fit$tmb_obj$env$last.par.best) == "b_phy_slope"))

  ## The phylo_dep slope path stays dormant on the legacy phylo_slope route:
  ## the dep flag is off, theta_dep_chol is length-0, and the public use flag
  ## is FALSE (distinct from the intercept-only phylo_dep RR flag).
  expect_identical(fit$tmb_data$use_phylo_dep_slope, 0L)
  expect_length(fit$tmb_params$theta_dep_chol, 0L)
  expect_false(isTRUE(fit$use$phylo_dep_slope))

  ## Exercise the compiled dormant branch directly. Parser/R activation waits
  ## for Phases 56.2-56.3, so we flip only the internal TMB flag here.
  tmb_data <- fit$tmb_data
  tmb_params <- fit$tmb_params
  tmb_map <- fit$tmb_map
  tmb_data$use_phylo_slope_correlated <- 1L
  tmb_params$b_phy_aug <- array(0.0, dim = c(tmb_data$n_aug_phy, 1L, 1L))
  tmb_params$log_sd_b <- 0.0
  tmb_params$atanh_cor_b <- numeric(0)
  tmb_map$b_phy_slope <- factor(rep(
    NA_integer_,
    length(tmb_params$b_phy_slope)
  ))
  tmb_map$log_sigma_slope <- factor(NA_integer_)
  tmb_map$b_phy_aug <- NULL
  tmb_map$log_sd_b <- NULL
  tmb_map$atanh_cor_b <- NULL
  obj <- TMB::MakeADFun(
    data = tmb_data,
    parameters = tmb_params,
    map = tmb_map,
    random = "b_phy_aug",
    DLL = "gllvmTMB",
    silent = TRUE
  )
  expect_true(is.finite(obj$fn(obj$par)))
  expect_true(all(is.finite(obj$gr(obj$par))))

  tmb_data <- fit$tmb_data
  tmb_params <- fit$tmb_params
  tmb_map <- fit$tmb_map
  tmb_data$use_phylo_slope_correlated <- 1L
  tmb_data$n_lhs_cols <- 2L
  z_phy_aug <- array(0.0, dim = c(nrow(df), 2L, 1L))
  z_phy_aug[, 1L, 1L] <- 1.0
  z_phy_aug[, 2L, 1L] <- fit$tmb_data$x_phy_slope
  tmb_data$Z_phy_aug <- z_phy_aug
  tmb_params$b_phy_aug <- array(0.0, dim = c(tmb_data$n_aug_phy, 2L, 1L))
  tmb_params$log_sd_b <- c(0.0, 0.0)
  tmb_params$atanh_cor_b <- 0.0
  tmb_map$b_phy_slope <- factor(rep(
    NA_integer_,
    length(tmb_params$b_phy_slope)
  ))
  tmb_map$log_sigma_slope <- factor(NA_integer_)
  tmb_map$b_phy_aug <- NULL
  tmb_map$log_sd_b <- NULL
  tmb_map$atanh_cor_b <- NULL
  obj <- TMB::MakeADFun(
    data = tmb_data,
    parameters = tmb_params,
    map = tmb_map,
    random = "b_phy_aug",
    DLL = "gllvmTMB",
    silent = TRUE
  )
  expect_true(is.finite(obj$fn(obj$par)))
  expect_true(all(is.finite(obj$gr(obj$par))))
})
