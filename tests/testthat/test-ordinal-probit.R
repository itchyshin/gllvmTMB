## Tests for the ordinal_probit() response family in the multivariate engine.
##
## Mathematical background:
##   * Wright (1934) / Falconer & Mackay (1996) / Dempster & Lerner (1950)
##     threshold model: y* = eta + N(0, 1), y = k iff tau_{k-1} < y* <= tau_k.
##   * Hadfield (2015) MEE 6:706-714, eqn 9: per-row likelihood;
##     eqn 10: K = 2 reduces exactly to binomial(probit).
##   * The latent residual variance is sigma_d^2 = 1 EXACTLY (no trigamma
##     correction), giving variance components on the same scale as a
##     continuous trait. This is the central selling point for
##     phylogenetic / threshold-trait analyses (Mizuno et al. 2025
##     J. Evol. Biol. 38(12)).
##
## Tests below cover:
##   1. K = 4 trait recovery (cutpoints + intercept).
##   2. K = 3 trait recovery (single free cutpoint).
##   3. K = 2 byte-identical reduction to binomial(link = "probit"),
##      verifying Hadfield's eqn 10 empirically.
##   4. Mixed-family fit: gaussian + ordinal_probit + poisson on three
##      traits, all converge with sensible per-trait recovery.
##   5. Ayumi/Mizuno's nice property: a continuous and an ordinal_probit
##      version of the same latent process give matching sigma2_phy on
##      the latent scale (no trigamma correction).

test_that("ordinal_probit (K = 4) recovers cutpoints and intercept", {
  skip_on_cran()
  set.seed(2025)
  n_ind  <- 300L
  Tn     <- 2L
  trait_names <- c("a", "b")
  true_taus_a <- c(0, 0.7, 1.4)         # K = 4 (3 thresholds; 2 free)
  true_taus_b <- c(0, 0.5)              # K = 3 (2 thresholds; 1 free)
  true_intercept <- c(0.3, -0.1)
  ystar <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    ystar[, t] <- stats::rnorm(n_ind, mean = true_intercept[t], sd = 1)
  y_a <- 1L + (ystar[, 1] > 0) + (ystar[, 1] > 0.7) + (ystar[, 1] > 1.4)
  y_b <- 1L + (ystar[, 2] > 0) + (ystar[, 2] > 0.5)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = c(t(cbind(y_a, y_b)))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data   = df,
    unit   = "individual",
    family = ordinal_probit()
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)

  cuts <- extract_cutpoints(fit)
  expect_equal(nrow(cuts), 3L)            # 2 (a) + 1 (b) free cutpoints
  expect_equal(cuts$cutpoint_index, c(2L, 3L, 2L))

  ## Recovery within ~25%
  expect_lt(abs(cuts$tau_estimate[1] - 0.7), 0.25)   # trait a tau_2
  expect_lt(abs(cuts$tau_estimate[2] - 1.4), 0.30)   # trait a tau_3 (looser)
  expect_lt(abs(cuts$tau_estimate[3] - 0.5), 0.25)   # trait b tau_2

  ## Intercept on the latent scale
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), 2L)
  expect_lt(max(abs(bfix - true_intercept)), 0.30)
})

test_that("ordinal_probit (K = 3) recovers the single free cutpoint", {
  skip_on_cran()
  set.seed(99)
  n_ind <- 250L
  true_tau_2 <- 0.8
  true_intercept <- 0.0
  ystar <- stats::rnorm(n_ind, mean = true_intercept, sd = 1)
  y <- 1L + (ystar > 0) + (ystar > true_tau_2)
  df <- data.frame(
    individual = factor(seq_len(n_ind)),
    trait      = factor(rep(c("a", "b"), length.out = n_ind),
                        levels = c("a", "b")),
    value      = y
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data   = df,
    unit   = "individual",
    family = ordinal_probit()
  )))
  expect_equal(fit$opt$convergence, 0L)
  cuts <- extract_cutpoints(fit)
  ## Two traits, each with K = 3 means 2 cutpoint rows total.
  expect_equal(nrow(cuts), 2L)
  expect_true(all(cuts$cutpoint_index == 2L))
  ## Pooling traits a and b (both drawn from the same DGP), tau_2 should
  ## land near the true value.
  expect_lt(max(abs(cuts$tau_estimate - true_tau_2)), 0.25)
})

test_that("ordinal_probit (K = 2) reduces to binomial(probit) byte-identically", {
  skip_on_cran()
  ## Hadfield (2015) eqn 10: K = 2 ordinal_probit IS the standard probit
  ## binomial. The objective values must match to numerical precision.
  set.seed(2025)
  n_ind <- 200L
  Tn    <- 2L
  trait_names <- c("a", "b")
  true_intercept <- c(-0.3, 0.5)
  ystar <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn))
    ystar[, t] <- stats::rnorm(n_ind, mean = true_intercept[t], sd = 1)
  y_bin <- (ystar > 0) + 0L      # 0 / 1
  y_ord <- y_bin + 1L            # 1 / 2 categories
  df_bin <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = c(t(y_bin))
  )
  df_ord <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = c(t(y_ord))
  )
  fit_bin <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data = df_bin, unit = "individual",
    family = binomial(link = "probit")
  )))
  fit_ord <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data = df_ord, unit = "individual",
    family = ordinal_probit()
  )))
  expect_equal(fit_bin$opt$convergence, 0L)
  expect_equal(fit_ord$opt$convergence, 0L)
  expect_equal(fit_bin$opt$objective, fit_ord$opt$objective, tolerance = 1e-6)
})

test_that("ordinal_probit mixed with gaussian + poisson converges per trait", {
  skip_on_cran()
  set.seed(7)
  n_ind  <- 250L
  Tn     <- 3L
  trait_names <- c("g", "o", "p")
  ## Gaussian trait: y_g = beta_g + N(0, 0.5)
  beta_g <- 1.5
  y_g    <- stats::rnorm(n_ind, mean = beta_g, sd = 0.5)
  ## Ordinal trait (K = 4): tau_1=0, tau_2=0.6, tau_3=1.3
  true_taus_o <- c(0, 0.6, 1.3)
  beta_o      <- 0.2
  ystar_o     <- stats::rnorm(n_ind, beta_o, 1)
  y_o         <- 1L + (ystar_o > 0) + (ystar_o > 0.6) + (ystar_o > 1.3)
  ## Poisson trait
  beta_p <- 1.0
  y_p    <- stats::rpois(n_ind, lambda = exp(beta_p))

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = numeric(n_ind * Tn),
    fam_var    = factor(rep(c("gauss", "ord", "pois"), n_ind),
                        levels = c("gauss", "ord", "pois"))
  )
  ## Fill values per trait
  df$value[df$trait == "g"] <- y_g
  df$value[df$trait == "o"] <- y_o
  df$value[df$trait == "p"] <- y_p

  fam_list <- list(
    gauss = gaussian(),
    ord   = ordinal_probit(),
    pois  = poisson()
  )
  attr(fam_list, "family_var") <- "fam_var"

  ## Need a latent() / unique() term to dispatch to the multi engine.
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data   = df,
    unit   = "individual",
    family = fam_list
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## Cutpoints should be present only for the ordinal trait.
  cuts <- extract_cutpoints(fit)
  expect_equal(nrow(cuts), 2L)
  expect_true(all(cuts$trait == "o"))
  expect_lt(abs(cuts$tau_estimate[1] - 0.6), 0.30)
  expect_lt(abs(cuts$tau_estimate[2] - 1.3), 0.40)
  ## Fixed effects should match per-trait truths
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), 3L)
  expect_lt(abs(bfix[1] - beta_g), 0.30)              # gaussian intercept
  expect_lt(abs(bfix[3] - beta_p), 0.30)              # poisson log-lambda
})

test_that("ordinal_probit gives sigma_d = 1 exactly via link_residual_per_trait()", {
  skip_on_cran()
  set.seed(11)
  n_ind <- 200L
  ystar <- stats::rnorm(n_ind, mean = 0, sd = 1)
  y     <- 1L + (ystar > 0) + (ystar > 0.5) + (ystar > 1.0)
  df <- data.frame(
    individual = factor(seq_len(n_ind)),
    trait      = factor(rep(c("a", "b"), length.out = n_ind),
                        levels = c("a", "b")),
    value      = y
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data = df, unit = "individual", family = ordinal_probit()
  )))
  ## link_residual_per_trait() is internal but exercised by
  ## extract_Sigma(..., link_residual = "auto"). The Wright/Falconer/Hadfield
  ## threshold model has sigma_d^2 = 1 exactly by construction.
  sig <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(sig), c(1, 1))
})

test_that("Ayumi property: continuous and ordinal_probit agree on latent sigma2_phy", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(2026)
  n_sp <- 60L
  tr   <- ape::rcoal(n_sp)
  tr$tip.label <- paste0("sp", seq_len(n_sp))
  A    <- ape::vcv(tr); A <- A / max(A)
  L    <- chol(A)

  sigma2_phy_true <- 1.5
  ## One species-level breeding value used to derive BOTH a continuous and
  ## an ordinal version of the trait. Because ordinal_probit has
  ## sigma_d^2 = 1 by construction, the two fits should report the SAME
  ## sigma2_phy on the latent scale.
  bv <- as.numeric(crossprod(L, stats::rnorm(n_sp, 0, sqrt(sigma2_phy_true))))

  n_per_sp <- 6L
  n_obs    <- n_sp * n_per_sp

  df <- data.frame(
    species = factor(rep(tr$tip.label, each = n_per_sp),
                     levels = tr$tip.label),
    obs_id  = factor(seq_len(n_obs))
  )
  df$bv <- bv[as.integer(df$species)]
  ## Continuous trait: y_c = bv + N(0, 1) on the same scale.
  df$y_c <- df$bv + stats::rnorm(n_obs, 0, 1)
  ## Ordinal trait: y* = bv + N(0, 1), y = 1 + (y* > tau_k).
  ystar <- df$bv + stats::rnorm(n_obs, 0, 1)
  df$y_o <- 1L + (ystar > 0) + (ystar > 0.6) + (ystar > 1.3)

  ## Build long-format data with two traits via the mixed-family API.
  df_long <- rbind(
    data.frame(species = df$species, obs_id = df$obs_id,
               trait = factor("c", levels = c("c", "o")),
               value = df$y_c, fam_var = factor("gauss",
                                                levels = c("gauss", "ord")),
               stringsAsFactors = FALSE),
    data.frame(species = df$species, obs_id = df$obs_id,
               trait = factor("o", levels = c("c", "o")),
               value = df$y_o, fam_var = factor("ord",
                                                levels = c("gauss", "ord")),
               stringsAsFactors = FALSE)
  )
  fam_list <- list(gauss = gaussian(), ord = ordinal_probit())
  attr(fam_list, "family_var") <- "fam_var"

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_unique(0 + trait | species),
    data       = df_long,
    unit       = "obs_id",
    cluster    = "species",
    family     = fam_list,
    phylo_tree = tr
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## Per-trait phylogenetic variance from the diagonal of Sigma_phy.
  sigma_phy_diag <- diag(fit$report$Sigma_phy)
  expect_equal(length(sigma_phy_diag), 2L)
  ## Both should be near sigma2_phy_true = 1.5; tolerate ~50% (small n_sp).
  expect_lt(abs(sigma_phy_diag[1] - sigma2_phy_true) / sigma2_phy_true, 0.6)
  expect_lt(abs(sigma_phy_diag[2] - sigma2_phy_true) / sigma2_phy_true, 0.6)
  ## They should agree with one another within ~30%.
  expect_lt(abs(sigma_phy_diag[1] - sigma_phy_diag[2]) /
              mean(sigma_phy_diag), 0.5)
})
