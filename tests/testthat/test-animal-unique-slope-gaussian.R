## Design 55 A3 + Design 56 9.5d + issue #354 part (b) --
## animal_unique(1 + x | id) Gaussian.
##
## animal_unique(1 + x | id, pedigree = ped) is the CORRELATED intercept+slope
## additive-genetic reaction norm; it routes through the phylo_unique augmented
## engine. The equivalent explicit forms for pedigree data are:
##   phylo_unique(1 + x | id, vcv = pedigree_to_A(ped))          (dense A)
##   phylo_unique(1 + x | id, vcv = pedigree_to_Ainv_sparse(ped)) (sparse Ainv)
##
## This cell tests:
##   - Gaussian recovery on a pedigree-derived A: sigma2_alpha (additive
##     genetic intercept variance), sigma2_beta (random-regression slope
##     variance), rho_ab (intercept-slope correlation).
##   - Byte-equivalence between phylo_unique(1+x|id, vcv = pedigree_to_A(ped))
##     and phylo_unique(1+x|id, vcv = A_dense) per Design 14 sec. 5
##     (same point estimates, same logLik to 1e-6).
##   - animal_unique(1 + x | id, pedigree = ped) routes to the phylo_unique
##     augmented engine, byte-identical to the explicit phylo_unique call.

skip_if_no_pedigree_helpers <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
}

## ---------------------------------------------------------------------------
## Pedigree + fixture helper
## ---------------------------------------------------------------------------
make_animal_unique_slope_fixture <- function(
  seed      = 5640L,
  n_id      = 80L,
  n_traits  = 3L,
  n_rep     = 6L
) {
  set.seed(seed)
  ped <- data.frame(
    id   = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 8L), rep(paste0("i", rep(1:4, length.out = n_id - 8L)), 1L)),
    dam  = c(rep(NA, 8L), rep(paste0("i", rep(5:8, length.out = n_id - 8L)), 1L)),
    stringsAsFactors = FALSE
  )
  A_dense <- gllvmTMB::pedigree_to_A(ped)
  id_labels <- rownames(A_dense)

  sigma2_int_true  <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L, ncol = 2L
  )

  raw <- matrix(stats::rnorm(n_id * 2L), nrow = n_id, ncol = 2L)
  ab  <- (t(chol(A_dense)) %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- id_labels

  id_rep <- expand.grid(
    species = factor(id_labels, levels = id_labels),
    rep     = seq_len(n_rep)
  )
  id_rep$x <- stats::rnorm(nrow(id_rep))
  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    id_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  mu_t     <- c(2, 1, 0.5)[as.integer(df_long$trait)]
  alpha_id <- ab[as.character(df_long$species), "alpha"]
  beta_id  <- ab[as.character(df_long$species), "beta"]
  df_long$value <- mu_t + alpha_id + beta_id * df_long$x +
    stats::rnorm(nrow(df_long), sd = 0.3)

  list(
    ped = ped, A = A_dense, df_long = df_long,
    Sigma_b_true      = Sigma_b_true,
    sigma2_int_true   = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true          = rho_true
  )
}

phase56_Sigma_b_unique <- function(fit) {
  sd_b <- as.numeric(fit$report$sd_b)
  rho  <- as.numeric(fit$report$cor_b)
  matrix(
    c(sd_b[1L]^2,
      rho * sd_b[1L] * sd_b[2L],
      rho * sd_b[1L] * sd_b[2L],
      sd_b[2L]^2),
    nrow = 2L, ncol = 2L,
    dimnames = list(c("intercept", "slope"), c("intercept", "slope"))
  )
}

## ======================================================================
## 1. Gaussian recovery via phylo_unique(vcv = pedigree_to_A(ped))
## ======================================================================
test_that("phylo_unique(1+x|id, vcv=pedigree_to_A(ped)) recovers G + cov on Gaussian", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()

  fx  <- make_animal_unique_slope_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = fx$A),
    data = fx$df_long, unit = "species", control = ctl
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$pd_hessian))

  Sigma_hat         <- phase56_Sigma_b_unique(fit)
  sigma2_int_hat    <- unname(Sigma_hat["intercept", "intercept"])
  sigma2_slope_hat  <- unname(Sigma_hat["slope", "slope"])
  rho_hat           <- unname(stats::cov2cor(Sigma_hat)["intercept", "slope"])

  ## Each component within 20% relative error; correlation within 0.30
  ## absolute (same band as test-relmat-unique-slope-gaussian.R).
  expect_lte(
    abs(sigma2_int_hat   - fx$sigma2_int_true)   / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )
  expect_lte(abs(rho_hat - fx$rho_true), 0.30)
})

## ======================================================================
## 2. Byte-equivalence: pedigree_to_A(ped) dense path == direct A dense
##    (Design 14 sec. 5 contract)
## ======================================================================
test_that("phylo_unique(vcv = pedigree_to_A(ped)) == phylo_unique(vcv = A_dense) byte-identical", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()

  fx  <- make_animal_unique_slope_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)

  ## Path 1: user passes the pre-computed dense A.
  fit_A <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = fx$A),
    data = fx$df_long, unit = "species", control = ctl
  )))
  ## Path 2: build A inside the call from the pedigree.
  A_from_ped <- gllvmTMB::pedigree_to_A(fx$ped)
  fit_ped <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = A_from_ped),
    data = fx$df_long, unit = "species", control = ctl
  )))

  expect_equal(
    as.numeric(logLik(fit_A)),
    as.numeric(logLik(fit_ped)),
    tolerance = 1e-6
  )
  expect_equal(
    fit_A$opt$objective,
    fit_ped$opt$objective,
    tolerance = 1e-8
  )
  expect_equal(fit_A$report$sd_b,  fit_ped$report$sd_b,  tolerance = 1e-8)
  expect_equal(fit_A$report$cor_b, fit_ped$report$cor_b, tolerance = 1e-8)
})

## ======================================================================
## 3. Routing (issue #354 part b): animal_unique(1 + x | id, pedigree = ped)
##    now ROUTES to the phylo_unique augmented engine (correlated intercept +
##    slope reaction norm) instead of aborting. It is byte-identical to the
##    equivalent phylo_unique sparse-Ainv pedigree call.
## ======================================================================
test_that("animal_unique(1 + x | id) routes to the phylo_unique augmented engine", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()

  fx  <- make_animal_unique_slope_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)

  ## Long-form augmented bar; the wide form 1 + x | id is the byte-identical
  ## equivalent (Design 55 sec.3 wide<->long contract).
  fit_au <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      animal_unique(0 + trait + (0 + trait):x | species, pedigree = fx$ped),
    data = fx$df_long, unit = "species", control = ctl
  )))
  Ainv_ped <- gllvmTMB::pedigree_to_Ainv_sparse(fx$ped)
  fit_pu <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species, vcv = Ainv_ped),
    data = fx$df_long, unit = "species", control = ctl
  )))

  expect_equal(fit_au$opt$convergence, 0L)
  ## Correlated augmented engine (free intercept-slope correlation), NOT dep.
  expect_identical(fit_au$tmb_data$use_phylo_slope_correlated, 1L)
  expect_false(isTRUE(fit_au$use$phylo_dep_slope))
  ## Byte-identical to the explicit phylo_unique sparse-Ainv call.
  expect_equal(as.numeric(logLik(fit_au)), as.numeric(logLik(fit_pu)),
               tolerance = 1e-6)
  expect_equal(fit_au$report$sd_b,  fit_pu$report$sd_b,  tolerance = 1e-6)
  expect_equal(fit_au$report$cor_b, fit_pu$report$cor_b, tolerance = 1e-6)
})
