## Tests for print / summary label plumbing:
##   - unit_col propagates to the B-tier print label
##   - unit_obs_col propagates to the W-tier print label
##   - The W-tier line is suppressed when no W-tier covstruct is active
##   - Hard-coded "species" / "site_species" do NOT appear for 1-level fits

## Helper: small 1-level morphometric-style fit (no W-tier)
make_morph_fit <- function(n_ind = 40, n_tr = 3, seed = 42) {
  set.seed(seed)
  df <- gllvmTMB::simulate_site_trait(
    n_sites = n_ind, n_species = 1, n_traits = n_tr,
    mean_species_per_site = 1, seed = seed
  )$data
  ## Rename 'site' -> 'individual' to mimic a morphometrics study
  df$individual <- df$site
  df$site <- NULL
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1) +
              unique(0 + trait | individual),
      data = df, unit = "individual"
    )
  ))
}

## Helper: small 2-level fit (with W-tier, custom unit_obs column)
make_two_level_fit <- function(seed = 7) {
  set.seed(seed)
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 20, n_species = 3, n_traits = 3,
    mean_species_per_site = 3, seed = seed
  )$data
  ## rename site_species -> obs
  df$obs <- df$site_species
  df$site_species <- NULL
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | site,  d = 1) +
              unique(0 + trait | site) +
              latent(0 + trait | obs, d = 1) +
              unique(0 + trait | obs),
      data = df, unit = "site", unit_obs = "obs"
    )
  ))
}

test_that("1-level morphometric print: uses unit column name, no species/site_species", {
  skip_on_cran()
  fit <- make_morph_fit()

  out <- paste(capture.output(print(fit)), collapse = "\n")

  ## Should contain the user's unit column label
  expect_match(out, "individual")

  ## Must NOT contain the default ecology labels for the W-tier
  expect_false(grepl("species\\s*=", out),
               info = "Print should not show 'species = N' for a 1-level fit")
  expect_false(grepl("site_species\\s*=", out),
               info = "Print should not show 'site_species = N' for a 1-level fit")
})

test_that("1-level morphometric print: unit_obs_col stored on fit object", {
  skip_on_cran()
  fit <- make_morph_fit()
  ## unit_obs_col is stored (even if W-tier is not active, it records what was passed)
  expect_true(!is.null(fit$unit_obs_col),
              info = "unit_obs_col should be stored on the fit object")
})

test_that("2-level fit print: uses custom unit_obs_col label for W-tier", {
  skip_on_cran()
  fit <- make_two_level_fit()

  out <- paste(capture.output(print(fit)), collapse = "\n")

  ## Should contain the user's within-unit column name 'obs'
  expect_match(out, "obs\\s*=")

  ## Must NOT show the default 'site_species' label
  expect_false(grepl("site_species\\s*=", out),
               info = "Print should use user's unit_obs_col, not 'site_species'")
})

test_that("2-level fit: unit_obs_col is stored correctly", {
  skip_on_cran()
  fit <- make_two_level_fit()
  expect_equal(fit$unit_obs_col, "obs")
})

test_that("summary() print for 1-level fit also omits species/site_species line", {
  skip_on_cran()
  fit   <- make_morph_fit()
  sout  <- paste(capture.output(print(summary(fit))), collapse = "\n")

  expect_false(grepl("species\\s*=", sout),
               info = "summary print should not show 'species = N' for a 1-level fit")
  expect_false(grepl("site_species\\s*=", sout),
               info = "summary print should not show 'site_species = N' for a 1-level fit")
  expect_match(sout, "individual")
})

test_that("summary() print for 2-level fit uses unit_obs_col label", {
  skip_on_cran()
  fit  <- make_two_level_fit()
  sout <- paste(capture.output(print(summary(fit))), collapse = "\n")

  expect_match(sout, "obs\\s*=")
  expect_false(grepl("site_species\\s*=", sout))
})
