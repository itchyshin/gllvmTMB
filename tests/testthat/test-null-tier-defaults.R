## `unit_obs` and `cluster` are OPTIONAL grouping slots. Their defaults
## changed from the concrete strings `"site_species"` / `"species"` to
## `NULL`, which resolves internally to the same concrete strings. This
## file guards the resolution: bit-identical fits, graceful absence of the
## `species` / `site_species` columns (the systematic-map shape -- one row
## per unit x trait, no sites, no species), and the argument-naming fix to
## the "column not found" error. See docs/dev-log/after-task/ for the
## motivating user-harm story (an external systematic-map user manufactured
## meaningless `site_species` / `cluster` columns to satisfy defaults that
## read as mandatory).

## Small site x trait fixture, deliberately WITHOUT a `species` or
## `site_species` column -- exactly the systematic-map shape.
.null_tier_fixture <- function(seed = 20260819, n_site = 12, n_trait = 4) {
  set.seed(seed)
  dat <- expand.grid(
    site = factor(seq_len(n_site)),
    trait = factor(paste0("sp", seq_len(n_trait))),
    KEEP.OUT.ATTRS = FALSE
  )
  dat <- dat[order(dat$site, dat$trait), ]
  dat$value <- rnorm(nrow(dat), mean = as.numeric(dat$trait) * 0.3, sd = 1)
  dat
}

.null_tier_formula <- value ~ 0 + trait + latent(0 + trait | site, d = 1)

test_that("unit_obs = NULL / cluster = NULL explicit gives the same fit as omitting them and as the old string defaults", {
  dat <- .null_tier_fixture()

  fit_old_explicit <- suppressMessages(suppressWarnings(gllvmTMB(
    .null_tier_formula,
    data = dat,
    family = gaussian(),
    unit = "site",
    unit_obs = "site_species",
    cluster = "species"
  )))
  fit_omitted <- suppressMessages(suppressWarnings(gllvmTMB(
    .null_tier_formula,
    data = dat,
    family = gaussian(),
    unit = "site"
  )))
  fit_explicit_null <- suppressMessages(suppressWarnings(gllvmTMB(
    .null_tier_formula,
    data = dat,
    family = gaussian(),
    unit = "site",
    unit_obs = NULL,
    cluster = NULL
  )))

  expect_identical(logLik(fit_omitted), logLik(fit_old_explicit))
  expect_identical(logLik(fit_explicit_null), logLik(fit_old_explicit))
  expect_identical(fit_omitted$opt$par, fit_old_explicit$opt$par)
  expect_identical(fit_explicit_null$opt$par, fit_old_explicit$opt$par)
})

test_that("NULL tier defaults preserve active unit_obs and cluster routes", {
  dat <- gllvmTMB::simulate_site_trait(
    n_sites = 16,
    n_species = 4,
    n_traits = 3,
    mean_species_per_site = 4,
    seed = 1191
  )$data
  form <- value ~ 0 +
    trait +
    indep(0 + trait | site_species) +
    indep(0 + trait | species)
  ctrl <- gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE)

  fit_old_explicit <- suppressMessages(suppressWarnings(gllvmTMB(
    form,
    data = dat,
    family = gaussian(),
    unit = "site",
    unit_obs = "site_species",
    cluster = "species",
    control = ctrl
  )))
  fit_omitted <- suppressMessages(suppressWarnings(gllvmTMB(
    form,
    data = dat,
    family = gaussian(),
    unit = "site",
    control = ctrl
  )))
  fit_explicit_null <- suppressMessages(suppressWarnings(gllvmTMB(
    form,
    data = dat,
    family = gaussian(),
    unit = "site",
    unit_obs = NULL,
    cluster = NULL,
    control = ctrl
  )))

  expect_true(isTRUE(fit_omitted$use$diag_W))
  expect_true(isTRUE(fit_omitted$use$diag_species))
  expect_identical(logLik(fit_omitted), logLik(fit_old_explicit))
  expect_identical(logLik(fit_explicit_null), logLik(fit_old_explicit))
  expect_identical(fit_omitted$opt$par, fit_old_explicit$opt$par)
  expect_identical(fit_explicit_null$opt$par, fit_old_explicit$opt$par)
})

test_that("a data frame with no `site_species` and no `species` column fits without error (systematic-map shape)", {
  dat <- .null_tier_fixture()
  expect_false("species" %in% names(dat))
  expect_false("site_species" %in% names(dat))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    .null_tier_formula,
    data = dat,
    family = gaussian(),
    unit = "site"
  )))
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a missing `trait` column aborts naming the `trait` argument", {
  dat <- .null_tier_fixture()
  names(dat)[names(dat) == "trait"] <- "resp"

  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat, unit = "site"),
    regexp = "trait.*=.*\"trait\".*is not a column"
  )
})

test_that("a missing `unit` column aborts naming the `unit` argument", {
  dat <- .null_tier_fixture()
  names(dat)[names(dat) == "site"] <- "loc"

  ## #1196 (2026-09-02): `unit` no longer defaults to "site" -- omitting
  ## it on data with no "site" column now aborts with the "unit is
  ## required" message (R/gllvmTMB.R), not the old #1191
  ## "unit = \"site\" is not a column" message that only fired when
  ## "site" WAS the (implicit) argument value being looked up.
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat),
    regexp = "unit = \\.\\.\\.`? is required"
  )
})

test_that("a non-default `unit_obs` absent from data still aborts with the existing helpful message", {
  dat <- .null_tier_fixture()

  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat, unit = "site", unit_obs = "nope"),
    regexp = "unit_obs.*=.*\"nope\".*is not a column"
  )
})
