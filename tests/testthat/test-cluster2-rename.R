## cluster2: a SECOND independent diagonal grouping slot, distinct from
## `cluster`. It lets a user fit two crossed (or nested) plain diagonal
## per-trait variance components at once (e.g. `cluster = "site"` AND
## `cluster2 = "year"`). It is a byte-for-byte structural copy of the
## `cluster` (`diag_species` / `q_sp`) tier, renamed to the second
## grouping (`diag_cluster2` / `r_c2`), so it is family-agnostic: the
## contribution is added to `eta` before family dispatch (no per-family
## C++ branching). See issue #342 (and sub-issues #355, #356).
##
## NOTE on grouping disjointness: a `unique(0 + trait | G)` term routes to
## whichever engine slot G matches -- `unit` (default "site"), `unit_obs`
## (default "site_species"), `cluster` (default "species"), or now
## `cluster2`. For a term to land in the cluster2 slot ALONE, G must equal
## the `cluster2` column and must NOT equal the unit / unit_obs / cluster
## columns. The fixtures below keep the four slot columns disjoint.
##
## These tests verify:
##   * EQUIVALENCE GATE: a model with `cluster2` on a grouping G is
##     byte-identical (logLik + extract_Sigma) to the existing
##     `cluster`/diag tier on the SAME grouping G -- proving cluster2 is
##     a faithful copy.
##   * `cluster2 = "..."` is accepted; `fit$cluster2_col` is stored;
##     the `diag_cluster2` flag and `sd_c2` report light up.
##   * `extract_Sigma(level = "cluster2", part = "unique")$s` has length
##     n_traits.
##   * CROSSED RECOVERY: a Gaussian DGP with TWO independent diagonal
##     groupings (site var + year var, known values) fits with
##     `cluster + cluster2`, conv == 0, PD Hessian, recovers BOTH.
##   * `cluster2 = NULL` (default) leaves the tier silently inactive
##     (regression guard).
##   * family-agnostic smoke: also parses + fits for poisson.

## Crossed (site x species x year) fixture with four disjoint grouping
## columns: site (unit), site_species (unit_obs), species (cluster), and
## year (a fourth crossed factor available for the cluster2 slot).
make_crossed <- function(seed = 42, n_sites = 24, n_species = 4,
                         n_traits = 4, n_years = 6) {
  set.seed(seed)
  grid <- expand.grid(
    site    = factor(seq_len(n_sites)),
    species = factor(seq_len(n_species)),
    trait   = factor(letters[seq_len(n_traits)])
  )
  grid$year <- factor(((as.integer(grid$site) - 1L) %% n_years) + 1L)
  grid$site_species <- factor(paste(grid$site, grid$species, sep = "_"))
  grid$value <- rnorm(nrow(grid))
  grid
}

test_that("`cluster2 = ...` argument is accepted and the tier lights up", {
  df <- make_crossed()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            unique(0 + trait | year),
    data = df,
    cluster2 = "year"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$cluster2_col, "year")
  expect_true(isTRUE(fit$use$diag_cluster2))
  expect_length(as.numeric(fit$report$sd_c2), 4L)
  ## extract_Sigma at level = "cluster2" returns the unique() diagonal.
  ext <- gllvmTMB::extract_Sigma(fit, level = "cluster2", part = "unique")
  expect_equal(length(ext$s), 4L)
})

test_that("EQUIVALENCE GATE: cluster2 on G == cluster on G (byte-identical)", {
  df <- make_crossed(seed = 7)
  ## Same grouping G = "species", same single `unique(0 + trait | species)`
  ## term, routed once through the `cluster` slot (default) and once through
  ## the `cluster2` slot (with `cluster` pointed at an unused disjoint
  ## column so it does NOT also fire on "species"). Because cluster2 is a
  ## renamed copy of the cluster diag block, the objective and the extracted
  ## variances must match to < 1e-6.
  fit_cluster <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | species),
    data = df, cluster = "species"
  )))
  fit_cluster2 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | species),
    data = df,
    cluster  = "year",      # disjoint, no diag term on it -> inactive
    cluster2 = "species"
  )))
  expect_equal(fit_cluster$opt$convergence, 0L)
  expect_equal(fit_cluster2$opt$convergence, 0L)
  ## The cluster slot must be inactive in the cluster2 fit, and vice versa.
  expect_false(isTRUE(fit_cluster$use$diag_cluster2))
  expect_true(isTRUE(fit_cluster$use$diag_species))
  expect_true(isTRUE(fit_cluster2$use$diag_cluster2))
  expect_false(isTRUE(fit_cluster2$use$diag_species))
  ## logLik byte-identical to < 1e-6.
  expect_equal(as.numeric(fit_cluster$opt$objective),
               as.numeric(fit_cluster2$opt$objective),
               tolerance = 1e-6)
  ## extract_Sigma diagonals byte-identical to < 1e-6.
  s_cluster  <- gllvmTMB::extract_Sigma(fit_cluster,  level = "cluster",  part = "unique")$s
  s_cluster2 <- gllvmTMB::extract_Sigma(fit_cluster2, level = "cluster2", part = "unique")$s
  expect_equal(length(s_cluster2), length(s_cluster))
  expect_equal(unname(s_cluster2), unname(s_cluster), tolerance = 1e-6)
})

test_that("`cluster2 = NULL` (default) leaves the tier silently inactive", {
  df <- make_crossed(seed = 11)
  ## No cluster2 argument, a `cluster`-tier diag term only. The cluster2
  ## flag must be FALSE and the fit must be byte-identical to a fit that
  ## passes `cluster2 = NULL` explicitly (regression guard).
  fit_default <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | species),
    data = df, cluster = "species"
  )))
  fit_explicit_null <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | species),
    data = df, cluster = "species", cluster2 = NULL
  )))
  expect_false(isTRUE(fit_default$use$diag_cluster2))
  expect_null(fit_default$cluster2_col)
  expect_identical(fit_default$opt$objective, fit_explicit_null$opt$objective)
})

test_that("extract_Sigma(level = 'cluster2') errors cleanly when tier absent", {
  df <- make_crossed(seed = 13)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | species),
    data = df, cluster = "species"
  )))
  expect_error(
    gllvmTMB::extract_Sigma(fit, level = "cluster2", part = "unique"),
    regexp = "cluster2|no .*term"
  )
})

test_that("family-agnostic smoke: cluster2 parses + fits for poisson", {
  set.seed(202)
  grid <- make_crossed(seed = 202, n_sites = 20, n_species = 4,
                       n_traits = 3, n_years = 5)
  grid$value <- rpois(nrow(grid), lambda = 2)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | year),
    data    = grid,
    family  = poisson(),
    cluster2 = "year"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$diag_cluster2))
  expect_true(all(is.finite(as.numeric(fit$report$sd_c2))))
})

test_that("CROSSED RECOVERY: two independent diagonal groupings recover", {
  skip_if_not_heavy()
  set.seed(2024)
  ## Gaussian DGP with TWO crossed diagonal per-trait variance components:
  ##   site-level   intercept (cluster  slot) sd_site = 0.9 per trait
  ##   year-level   intercept (cluster2 slot) sd_year = 0.5 per trait
  ## crossed (every site appears in several years and vice versa).
  n_sites <- 40; n_years <- 25; n_traits <- 3
  sigma_site <- 0.9
  sigma_year <- 0.5
  sigma_resid <- 0.4
  traits <- letters[seq_len(n_traits)]

  ## site x year crossed design (full grid -> each (site, year) once).
  grid <- expand.grid(
    site  = factor(seq_len(n_sites)),
    year  = factor(seq_len(n_years)),
    trait = factor(traits)
  )
  ## per-trait random intercepts for each grouping.
  re_site <- matrix(rnorm(n_sites * n_traits, 0, sigma_site),
                    n_sites, n_traits)
  re_year <- matrix(rnorm(n_years * n_traits, 0, sigma_year),
                    n_years, n_traits)
  si <- as.integer(grid$site)
  yi <- as.integer(grid$year)
  ti <- as.integer(grid$trait)
  mu <- 1.0   # shared trait intercept
  grid$value <- mu +
    re_site[cbind(si, ti)] +
    re_year[cbind(yi, ti)] +
    rnorm(nrow(grid), 0, sigma_resid)
  ## Route the two diag terms through the `cluster` (site) and `cluster2`
  ## (year) slots ONLY. Point `unit` / `unit_obs` at disjoint throwaway
  ## id columns that carry NO diag term, so neither the site nor the year
  ## term collides with the unit / unit_obs slot.
  grid$obs  <- factor(seq_len(nrow(grid)))
  grid$obs2 <- factor(seq_len(nrow(grid)))

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            unique(0 + trait | site) +
            unique(0 + trait | year),
    data     = grid,
    family   = gaussian(),
    unit     = "obs",
    unit_obs = "obs2",
    cluster  = "site",
    cluster2 = "year"
  )))

  expect_equal(fit$opt$convergence, 0L)
  ## PD Hessian (when sdreport succeeded).
  if (!is.null(fit$sd_report) && !is.null(fit$sd_report$pdHess)) {
    expect_true(isTRUE(fit$sd_report$pdHess))
  }
  ## Recover both variance components (mean across traits) within band.
  sd_site_hat <- mean(as.numeric(fit$report$sd_q))
  sd_year_hat <- mean(as.numeric(fit$report$sd_c2))
  expect_equal(sd_site_hat, sigma_site, tolerance = 0.30)
  expect_equal(sd_year_hat, sigma_year, tolerance = 0.30)
})
