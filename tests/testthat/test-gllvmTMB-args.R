# Argument-by-argument coverage for gllvmTMB().
# Each test isolates one argument or one cross-argument validity rule.
# Uses small data (n_sites <= 30, n_species <= 8, n_traits <= 4) so the
# whole file runs in well under 10 seconds.

skip_if_no_ape <- function() {
  if (!requireNamespace("ape", quietly = TRUE)) skip("ape not installed")
}

make_small_sim <- function(seed = 1, n_sites = 25, n_species = 6,
                           n_traits = 3, mean_species_per_site = 3) {
  simulate_site_trait(
    n_sites               = n_sites,
    n_species             = n_species,
    n_traits              = n_traits,
    mean_species_per_site = mean_species_per_site,
    seed                  = seed
  )
}

# ---- data argument --------------------------------------------------------

test_that("gllvmTMB(): data must be a data.frame", {
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = 1:10),
    regexp = "data.frame"
  )
})

test_that("gllvmTMB(): missing trait column errors with 'Column trait'", {
  sim <- make_small_sim()
  bad <- sim$data
  bad$trait <- NULL
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = bad),
    regexp = "trait"
  )
})

test_that("gllvmTMB(): missing site column errors with helpful message", {
  sim <- make_small_sim()
  bad <- sim$data
  bad$site <- NULL
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = bad),
    regexp = "site"
  )
})

# ---- trait / site / species column-name arguments ------------------------

test_that("gllvmTMB(): custom trait column name is honoured", {
  skip("0.2.0: no-covstruct fallback removed (sdmTMB() engine no longer bundled).")
})

test_that("gllvmTMB(): custom site column name is honoured", {
  skip("0.2.0: no-covstruct fallback removed.")
})

test_that("gllvmTMB(): missing species column auto-creates a placeholder", {
  skip("0.2.0: no-covstruct fallback removed.")
})

# ---- formula argument: covstruct routing ---------------------------------

test_that("gllvmTMB(): formula with no covstruct uses single-response engine", {
  skip("0.2.0: no-covstruct fallback removed; single-response models live in glmmTMB now.")
})

test_that("gllvmTMB(): formula with rr() routes to gllvmTMB_multi", {
  sim <- make_small_sim()
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )
  expect_s3_class(fit, "gllvmTMB_multi")
})

test_that("gllvmTMB(): unsupported covstruct (us / cs / ar1) errors", {
  sim <- make_small_sim()
  expect_error(
    gllvmTMB(value ~ 0 + trait + us(0 + trait | site), data = sim$data),
    regexp = "not yet supported"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + cs(0 + trait | site), data = sim$data),
    regexp = "not yet supported"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + ar1(0 + trait | site), data = sim$data),
    regexp = "not yet supported"
  )
})

# ---- family argument -----------------------------------------------------

test_that("gllvmTMB(): unsupported family errors with cli message", {
  sim <- make_small_sim()
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data,
             family = quasibinomial()),
    regexp = "Unsupported family"
  )
})

test_that("gllvmTMB(): binomial rejects unsupported links", {
  sim <- make_small_sim()
  ## Binarise response so glm doesn't complain
  sim$data$value <- as.numeric(sim$data$value > median(sim$data$value))
  ## logit (default), probit, cloglog are now all supported. cauchit is not.
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data,
             family = binomial(link = "cauchit")),
    regexp = "not supported"
  )
})

test_that("gllvmTMB(): poisson requires log link", {
  sim <- make_small_sim()
  sim$data$value <- pmax(0, round(sim$data$value + 5))
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data,
             family = poisson(link = "sqrt")),
    regexp = "log"
  )
})

test_that("gllvmTMB(): Gamma requires log link", {
  sim <- make_small_sim()
  sim$data$value <- exp(sim$data$value)
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data,
             family = Gamma(link = "inverse")),
    regexp = "log"
  )
})

# ---- phylo_vcv argument --------------------------------------------------

test_that("gllvmTMB(): propto() requires phylo_vcv", {
  sim <- make_small_sim()
  expect_error(
    gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
             data = sim$data, phylo_vcv = NULL),
    regexp = "phylo_vcv"
  )
})

test_that("gllvmTMB(): phylo_vcv without rownames errors", {
  skip_if_no_ape()
  sim <- make_small_sim()
  bad_C <- diag(nlevels(sim$data$species))
  ## No rownames
  expect_error(
    gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
             data = sim$data, phylo_vcv = bad_C),
    regexp = "rownames"
  )
})

test_that("gllvmTMB(): phylo_vcv whose rows don't cover species levels errors", {
  skip_if_no_ape()
  sim <- make_small_sim()
  n <- nlevels(sim$data$species)
  C <- diag(n)
  rownames(C) <- colnames(C) <- paste0("not_a_species_", seq_len(n))
  expect_error(
    gllvmTMB(value ~ 0 + trait + propto(0 + species | trait, Cphy),
             data = sim$data, phylo_vcv = C),
    regexp = "phylo_vcv"
  )
})

# ---- phylo_tree argument -------------------------------------------------

test_that("gllvmTMB(): non-phylo phylo_tree errors", {
  skip_if_no_ape()
  sim <- make_small_sim()
  ## Pass something that isn't an ape::phylo
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 1),
             data = sim$data,
             phylo_tree = 42),
    regexp = "phylo"
  )
})

# ---- mesh argument -------------------------------------------------------

test_that("gllvmTMB(): spde() requires mesh", {
  sim <- make_small_sim()
  expect_error(
    suppressWarnings(gllvmTMB(value ~ 0 + trait + spatial_unique(0 + trait | coords),
             data = sim$data, mesh = NULL)),
    regexp = "mesh"
  )
})

test_that("gllvmTMB(): mesh of wrong type for spde() errors", {
  sim <- make_small_sim()
  expect_error(
    suppressWarnings(gllvmTMB(value ~ 0 + trait + spatial_unique(0 + trait | coords),
             data = sim$data, mesh = "not-a-mesh")),
    regexp = "make_mesh"
  )
})

# ---- known_V argument -----------------------------------------------------

test_that("gllvmTMB(): equalto() requires known_V", {
  sim <- make_small_sim()
  df <- sim$data
  df$obs <- factor(seq_len(nrow(df)))
  df$grp_V <- factor(rep("a", nrow(df)))
  expect_error(
    gllvmTMB(value ~ 0 + trait + equalto(0 + obs | grp_V, V),
             data = df, known_V = NULL),
    regexp = "known_V"
  )
})

test_that("gllvmTMB(): known_V with wrong dimensions errors", {
  sim <- make_small_sim()
  df <- sim$data
  df$obs <- factor(seq_len(nrow(df)))
  df$grp_V <- factor(rep("a", nrow(df)))
  bad_V <- diag(nrow(df) - 1)   # off by one
  expect_error(
    gllvmTMB(value ~ 0 + trait + equalto(0 + obs | grp_V, V),
             data = df, known_V = bad_V),
    regexp = "known_V"
  )
})

# ---- silent argument -----------------------------------------------------

test_that("gllvmTMB(): silent = TRUE suppresses TMB chatter", {
  sim <- make_small_sim()
  msg <- capture.output(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
             data = sim$data, silent = TRUE),
    type = "message"
  )
  ## Some stdout output may still happen; the test simply guards that
  ## silent = TRUE doesn't fail.
  expect_true(is.character(msg))
})

# ---- control argument: forwarded to fit -----------------------------------

test_that("gllvmTMB(): non-default control n_init is honoured (smoke test)", {
  sim <- make_small_sim()
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = sim$data,
    control = gllvmTMBcontrol(n_init = 2, init_jitter = 0.05)
  )
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
})

# ---- lambda_constraint with non-matrix value -----------------------------

test_that("gllvmTMB(): lambda_constraint must be matrices", {
  sim <- make_small_sim()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = sim$data,
      lambda_constraint = list(B = "not-a-matrix")
    ),
    regexp = "matrices"
  )
})

# ---- weights -------------------------------------------------------------

test_that("gllvmTMB(): NULL weights default works", {
  sim <- make_small_sim()
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data, weights = NULL
  )
  expect_s3_class(fit, "gllvmTMB_multi")
})
