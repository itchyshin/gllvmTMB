## PR-0: the legacy slope-only phylogenetic field is indexed by the RHS of
## phylo_slope(), not by the unrelated top-level cluster tier.

.make_phylo_slope_rhs_fixture <- function(seed = 1196L) {
  set.seed(seed)
  phy_id <- paste0("p", seq_len(6L))
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(5L))),
    trait = factor(c("t1", "t2")),
    phy_id = factor(phy_id, levels = phy_id),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$cluster <- factor(ifelse(dat$phy_id %in% phy_id[seq_len(3L)], "c1", "c2"))
  dat$site_species <- interaction(dat$unit, dat$trait, drop = TRUE)
  dat$x <- rnorm(nrow(dat))
  slope <- stats::rnorm(length(phy_id), sd = 0.35)
  dat$value <- 0.2 * (dat$trait == "t2") +
    slope[as.integer(dat$phy_id)] * dat$x + rnorm(nrow(dat), sd = 0.4)
  A <- diag(length(phy_id))
  dimnames(A) <- list(phy_id, phy_id)
  list(data = dat, A = A)
}

test_that("phylo_slope() uses its RHS map, not top-level cluster", {
  fx <- .make_phylo_slope_rhs_fixture()

  fit_rhs <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | phy_id, vcv = fx$A),
    data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
  fit_same <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | phy_id, vcv = fx$A),
    data = fx$data, trait = "trait", unit = "unit", cluster = "phy_id",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))

  ## The unrelated cluster tier stays two-level, whereas the slope field is
  ## keyed to all six RHS levels.  The two calls have the same fitted model.
  expect_identical(fit_rhs$tmb_data$n_aug_phy_slope, 6L)
  expect_identical(fit_rhs$tmb_data$n_aug_phy, 2L)
  expect_identical(
    fit_rhs$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$phy_id) - 1L
  )
  expect_identical(
    fit_rhs$tmb_data$species_aug_id,
    as.integer(fx$data$cluster) - 1L
  )
  ## When the historical top-level cluster and the formula RHS agree, the
  ## dedicated route uses the same observed six-level slope map.
  expect_identical(fit_same$tmb_data$n_aug_phy_slope, 6L)
  expect_identical(
    fit_same$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$phy_id) - 1L
  )
  expect_equal(fit_rhs$opt$objective, fit_same$opt$objective, tolerance = 1e-10)
})

test_that("phylo_slope() rejects a non-column RHS", {
  fx <- .make_phylo_slope_rhs_fixture()
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_slope(x | interaction(phy_id, trait), vcv = fx$A),
      data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ),
    "bare grouping column"
  )
})

test_that("phylo_slope() maps a tree's augmented nodes from its RHS", {
  testthat::skip_if_not_installed("ape")
  fx <- .make_phylo_slope_rhs_fixture()
  tree <- ape::rcoal(6L)
  tree$tip.label <- levels(fx$data$phy_id)

  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | phy_id, tree = tree),
    data = fx$data, trait = "trait", unit = "unit", cluster = "cluster",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))

  tip_index <- match(as.character(fx$data$phy_id), rownames(fit$tmb_data$Ainv_phy_slope))
  expect_gt(fit$tmb_data$n_aug_phy_slope, nlevels(fx$data$phy_id))
  expect_identical(fit$tmb_data$n_aug_phy, 2L)
  expect_identical(fit$tmb_data$phylo_slope_aug_id, as.integer(tip_index - 1L))
  expect_equal(fit$opt$convergence, 0L)
})
