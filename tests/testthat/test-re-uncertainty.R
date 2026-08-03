# getREsd(): standard errors for random-effect blocks with a point
# estimate but no uncertainty accessor. Generalises getLV(se = TRUE)'s
# sdreport()-diag.cov.random mechanism (see test-getlv-se.R for that path).

## Independent second route for the delta-method SE: the raw Laplace GMRF
## Hessian (`obj$env$spHess(random = TRUE)`), inverted. This is a genuinely
## different TMB code path from `sd_report$diag.cov.random` -- it gives the
## CONDITIONAL (fixed-effect-uncertainty-free) variance of the random
## effect, whereas `sd_report$diag.cov.random` additionally propagates
## fixed-effect uncertainty via the generalized delta method. The two
## should agree in ORDER (reported >= gmrf-only) but need not be numerically
## close; used here only as a structural cross-check that getREsd() is
## reading the correct block/index, not as a magnitude check.
.gmrf_only_se <- function(fit, par_name) {
  obj <- fit$tmb_obj
  last_par <- obj$env$last.par.best
  ran_idx <- obj$env$random
  stopifnot(identical(names(last_par)[ran_idx], names(fit$sd_report$par.random)))
  H <- obj$env$spHess(par = last_par, random = TRUE)
  cov_cond <- as.matrix(Matrix::solve(H))
  se_cond <- sqrt(pmax(diag(cov_cond), 0))
  idx <- which(names(fit$sd_report$par.random) == par_name)
  se_cond[idx]
}

test_that("getREsd() reads diag_unit (s_B) / diag_species (q_sp) / re_int (u_re_int) SEs", {
  skip_on_cran()
  set.seed(1)
  n_sites <- 15L; n_species <- 3L; n_traits <- 2L
  site <- factor(rep(paste0("s", seq_len(n_sites)), each = n_species))
  species <- factor(rep(paste0("sp", seq_len(n_species)), times = n_sites))
  grp <- factor(rep(c("A", "B", "C"), length.out = n_sites * n_species))
  base <- data.frame(site = site, species = species, grp = grp)
  df <- do.call(rbind, replicate(n_traits, base, simplify = FALSE))
  df$trait <- factor(rep(paste0("t", seq_len(n_traits)), each = nrow(base)))
  set.seed(2)
  df$value <- rnorm(nrow(df))

  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | species) +
      (1 | grp),
    data = df, trait = "trait", unit = "site", family = gaussian()
  ))
  expect_equal(fit$opt$convergence, 0L)

  se_B <- getREsd(fit, block = "diag_unit")
  expect_equal(dim(se_B), c(fit$n_traits, fit$n_sites))
  expect_true(all(is.finite(se_B) & se_B > 0))

  se_sp <- getREsd(fit, block = "diag_species")
  expect_equal(dim(se_sp), c(fit$n_traits, fit$n_species))
  expect_true(all(is.finite(se_sp) & se_sp >= 0))

  se_re <- getREsd(fit, block = "re_int")
  expect_type(se_re, "list")
  expect_named(se_re, "grp")
  expect_length(se_re[["grp"]], fit$re_int$n_groups[1])
  expect_true(all(is.finite(se_re[["grp"]]) & se_re[["grp"]] > 0))

  ## Independent second route: the raw GMRF (conditional-only) Hessian
  ## must give a SMALLER SE than sdreport's fixed-effect-uncertainty
  ## -propagated SE, for every diag_unit entry -- confirms getREsd() is
  ## reading the correct par.random slice, not a plausible-looking wrong
  ## one (a wrong slice would not systematically satisfy this ordering).
  se_gmrf <- .gmrf_only_se(fit, "s_B")
  expect_true(all(as.numeric(se_B) >= se_gmrf - 1e-8))

  ## Existing getLV() behaviour is untouched.
  expect_null(getLV(fit, level = "unit", se = TRUE))

  ## Absent block raises a named, class-tagged error.
  expect_error(
    getREsd(fit, block = "phylo"),
    class = "gllvmTMB_getREsd_block_absent"
  )
})

test_that("getREsd() reads diag_unit_obs (s_W) SEs, cross-checked against the GMRF-only route", {
  skip_on_cran()
  set.seed(3)
  n_sites <- 10L; n_species <- 4L; n_traits <- 2L
  site <- factor(rep(paste0("s", seq_len(n_sites)), each = n_species))
  species <- factor(rep(paste0("sp", seq_len(n_species)), times = n_sites))
  base <- data.frame(site = site, species = species)
  df <- do.call(rbind, replicate(n_traits, base, simplify = FALSE))
  df$trait <- factor(rep(paste0("t", seq_len(n_traits)), each = nrow(base)))
  set.seed(4)
  df$value <- rnorm(nrow(df))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site_species),
    data = df, trait = "trait", unit = "site", cluster = "species",
    family = gaussian()
  )))
  expect_equal(fit$opt$convergence, 0L)

  se_W <- getREsd(fit, block = "diag_unit_obs")
  expect_equal(dim(se_W), c(fit$n_traits, fit$n_site_species))
  expect_true(all(is.finite(se_W) & se_W > 0))

  se_gmrf <- .gmrf_only_se(fit, "s_W")
  expect_true(all(as.numeric(se_W) >= se_gmrf - 1e-8))
})

test_that("getREsd() reads phylo (p_phy) SEs, cross-checked against the GMRF-only route", {
  skip_on_cran()
  testthat::skip_if_not_installed("ape")
  set.seed(5)
  n_sp <- 6
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = 12, n_species = n_sp, n_traits = 2,
    mean_species_per_site = 4,
    Cphy = Cphy, sigma2_phy = c(0.6, 0.6), seed = 5
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))

  fit <- gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
                  data = df)
  expect_equal(fit$opt$convergence, 0L)

  se_phy <- getREsd(fit, block = "phylo")
  expect_equal(dim(se_phy), c(fit$n_species, fit$n_traits))
  expect_true(all(is.finite(se_phy) & se_phy > 0))

  se_gmrf <- .gmrf_only_se(fit, "p_phy")
  expect_true(all(as.numeric(se_phy) >= se_gmrf - 1e-8))
})

test_that("getREsd() reads equalto (e_eq) SEs, cross-checked against the known sampling SD", {
  skip_on_cran()
  set.seed(909)
  n_eff <- 15
  n_trait <- 2
  df <- expand.grid(
    site  = factor(seq_len(n_eff)),
    trait = factor(paste0("t", seq_len(n_trait)))
  )
  df$value <- rnorm(nrow(df), sd = 0.5)
  df$sampling_var <- runif(nrow(df), min = 0.02, max = 0.08)
  df$obs <- factor(seq_len(nrow(df)))
  V <- diag(df$sampling_var)

  fit <- gllvmTMB(
    value ~ 0 + trait + meta_V(V = V, type = "exact"),
    data = df, trait = "trait", unit = "site", known_V = V
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$equalto))

  se_eq <- getREsd(fit, block = "equalto")
  expect_length(se_eq, nrow(df))
  expect_true(all(is.finite(se_eq) & se_eq > 0))

  ## Independent second route: the known per-row sampling SD is a Wald
  ## shrinkage TARGET, not a coincidence -- e_eq's posterior SE should sit
  ## below sqrt(known sampling_var) (standard Bayesian/empirical-Bayes
  ## shrinkage), never dramatically above it.
  expect_true(all(se_eq <= sqrt(df$sampling_var) + 1e-8))
})

test_that("getREsd() rejects a non-gllvmTMB_multi fit", {
  expect_error(
    getREsd(list(), block = "phylo"),
    class = "gllvmTMB_getREsd_bad_fit"
  )
})

test_that("getREsd() call signature (fit, block=) is unchanged by later additions", {
  skip_on_cran()
  set.seed(1)
  n_sites <- 15L; n_species <- 3L; n_traits <- 2L
  site <- factor(rep(paste0("s", seq_len(n_sites)), each = n_species))
  species <- factor(rep(paste0("sp", seq_len(n_species)), times = n_sites))
  grp <- factor(rep(c("A", "B", "C"), length.out = n_sites * n_species))
  base <- data.frame(site = site, species = species, grp = grp)
  df <- do.call(rbind, replicate(n_traits, base, simplify = FALSE))
  df$trait <- factor(rep(paste0("t", seq_len(n_traits)), each = nrow(base)))
  set.seed(2)
  df$value <- rnorm(nrow(df))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + (1 | grp),
    data = df, trait = "trait", unit = "site", family = gaussian()
  ))
  ## Positional call (fit, block) and named call (fit, block = ) must agree,
  ## and repeated calls must be deterministic (same fit, same numbers).
  se_positional <- getREsd(fit, "diag_unit")
  se_named <- getREsd(fit, block = "diag_unit")
  expect_identical(se_positional, se_named)
  expect_identical(getREsd(fit, "diag_unit"), getREsd(fit, "diag_unit"))
})
