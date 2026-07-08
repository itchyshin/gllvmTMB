## H^2's denominator is the SPECIES-level latent variance: only components whose
## grouping is the `cluster` column may enter `V_eta` (maintainer ruling 2026-07-08).
##
## Before that ruling, `extract_phylo_signal()` read the per-trait Psi from
## `extract_Sigma(level = "unit", part = "unique")` unconditionally. In a crossed
## `site x species` design -- the very configuration the `q_it` framework prescribes,
## and the one `test-phylo-signal-ci.R` uses -- `use$diag_B` is FALSE there, so the
## extractor returned NULL, `Psi = 0`, and **H^2 = 1.00 was reported for every trait**
## while the estimated `q_it` variance (`sd_q`) sat unread at the cluster tier.
##
## Two independent code paths compute H^2 (`extract_phylo_signal()` in
## R/extract-omega.R and `.phylo_signal_H2_from_report()` in R/phylo-signal-ci.R).
## They disagreed. They must not.

.psl_fixture <- function(seed = 7L) {
  set.seed(seed)
  n_sp <- 40L
  n_sites <- 30L
  Tn <- 4L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  ## sigma2_phy = 1.5, q_it = 0.7, nothing else  =>  true H^2 = 1.5 / 2.2 = 0.6818
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = n_sp, n_traits = Tn,
    mean_species_per_site = n_sp, Cphy = Cphy,
    sigma2_phy = rep(1.5, Tn), sigma2_sp = rep(0.7, Tn),
    Lambda_B = matrix(0, Tn, 1L), psi_B = rep(0, Tn), sigma2_eps = 0, seed = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  df$value <- stats::rbinom(length(df$value), 1L, stats::pnorm(df$value))
  list(df = df, tree = tree, Tn = Tn, truth_H2 = 1.5 / 2.2)
}

.psl_fit_crossed <- function(fx) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species) + unique(0 + trait | species),
    data = fx$df, phylo_tree = fx$tree, cluster = "species",
    family = stats::binomial(link = "probit"), silent = TRUE
  )))
}

test_that("crossed design: q_it enters V_eta, so H2 is not identically 1", {
  skip_on_cran()
  skip_if_not_installed("ape")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fx <- .psl_fixture()
  fit <- .psl_fit_crossed(fx)

  ## Sanity: this really is the crossed design, and q_it really is estimated.
  expect_false(identical(as.character(fit$unit_col), as.character(fit$cluster_col)))
  expect_true(isTRUE(fit$use$diag_species))
  expect_true(all(as.numeric(fit$report$sd_q) > 0))

  h <- suppressMessages(gllvmTMB::extract_phylo_signal(fit))
  ## The regression: every H2 was exactly 1 and every Psi exactly 0.
  expect_true(all(h$H2 < 1))
  expect_true(all(h$Psi > 0))
  ## And the point estimates should sit around the truth rather than at the boundary.
  expect_lt(abs(mean(h$H2) - fx$truth_H2), 0.15)
})

test_that("the two H2 code paths agree on the same crossed fit", {
  skip_on_cran()
  skip_if_not_installed("ape")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fx <- .psl_fixture()
  fit <- .psl_fit_crossed(fx)

  h_extract <- suppressMessages(gllvmTMB::extract_phylo_signal(fit))$H2
  obj <- fit$tmb_obj
  rep_b <- obj$report(obj$env$last.par.best)
  uic <- gllvmTMB:::.phylo_signal_unit_is_cluster(fit)
  h_ci <- gllvmTMB:::.phylo_signal_H2_from_report(rep_b, T = fx$Tn, unit_is_cluster = uic)

  expect_false(uic)
  expect_equal(as.numeric(h_extract), as.numeric(h_ci), tolerance = 1e-10)
})

test_that("unit == cluster: the species-level Psi is the unit-tier Psi", {
  skip_on_cran()
  skip_if_not_installed("ape")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(20260708)
  S <- 30L; T_ <- 4L
  tree <- ape::rcoal(S); tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A))
  LamPhy <- matrix(c(0.9, -0.6, 0.5, 0.7), T_, 1)
  LamB   <- matrix(c(0.8, 0.6, -0.4, 0.3), T_, 1)
  beta <- stats::rnorm(T_, 0, 0.4)
  eta <- matrix(beta, S, T_, byrow = TRUE) +
    (LA %*% matrix(stats::rnorm(S), S, 1)) %*% t(LamPhy) +
    matrix(stats::rnorm(S), S, 1) %*% t(LamB)
  y <- eta + matrix(stats::rnorm(S * T_, 0, 0.5), S, T_)
  df <- data.frame(
    species = factor(rep(tree$tip.label, times = T_), levels = tree$tip.label),
    trait   = factor(rep(paste0("t", seq_len(T_)), each = S)),
    value   = as.vector(y)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = 1) +
      phylo_latent(0 + trait | species, d = 1, tree = tree),
    data = df, unit = "species", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_true(identical(as.character(fit$unit_col), as.character(fit$cluster_col)))
  expect_true(gllvmTMB:::.phylo_signal_unit_is_cluster(fit))
  ## Tier-claiming: only the unit-tier diagonal exists here.
  expect_false(isTRUE(fit$use$diag_species))

  h <- suppressMessages(gllvmTMB::extract_phylo_signal(fit))
  ## Psi must be the whole unit-tier Psi, and the three proportions sum to 1.
  psi_unit <- as.numeric(
    suppressMessages(gllvmTMB::extract_Sigma(fit, level = "unit", part = "unique"))$s
  )
  expect_equal(h$Psi * h$V_eta, psi_unit, tolerance = 1e-8)
  expect_equal(h$H2 + h$C2_non + h$Psi, rep(1, T_), tolerance = 1e-8)
})
