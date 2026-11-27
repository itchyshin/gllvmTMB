## #1975: simulate(newdata =) must draw from the fitted family, not Gaussian link noise.

.skip_spatial_heavy <- function() {
  skip_on_cran()
  if (!requireNamespace("fmesher", quietly = TRUE)) skip("fmesher required")
}

.spatial_latent_issue_coords <- function() {
  n <- 16L
  data.frame(
    site = seq_len(n),
    lon = c(
      0.22, 0.31, 0.44, 0.51, 0.58, 0.61, 0.65, 0.69,
      0.72, 0.75, 0.78, 0.55, 0.48, 0.41, 0.35, 0.28
    ),
    lat = c(
      0.25, 0.32, 0.38, 0.42, 0.48, 0.52, 0.55, 0.58,
      0.62, 0.66, 0.70, 0.45, 0.40, 0.36, 0.30, 0.27
    )
  )
}

.spatial_latent_issue_df <- function(family, value) {
  coords <- .spatial_latent_issue_coords()
  df <- expand.grid(
    site = coords$site,
    trait = c("t1", "t2", "t3"),
    stringsAsFactors = FALSE
  )
  df$lon <- coords$lon[match(df$site, coords$site)]
  df$lat <- coords$lat[match(df$site, coords$site)]
  df$unit <- df$site
  df$value <- value
  df$site <- factor(df$site)
  df$trait <- factor(df$trait, levels = c("t1", "t2", "t3"))
  df$unit <- factor(df$unit, levels = levels(df$site))
  list(data = df, coords = coords)
}

.spatial_latent_issue_fit <- function(family, value) {
  prep <- .spatial_latent_issue_df(family, value)
  df <- prep$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.11, extend = 0.1)
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait | unit, mesh = mesh, d = 1),
    data = df,
    unit = "site",
    family = family,
    silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("simulate(newdata) draws non-negative integer Poisson responses (#1975)", {
  .skip_spatial_heavy()
  set.seed(112704L)
  value <- c(
    2L, 1L, 3L, 0L, 2L, 1L, 4L, 2L, 1L, 3L, 2L, 0L, 1L, 2L, 3L, 1L,
    1L, 2L, 1L, 3L, 2L, 0L, 1L, 2L, 3L, 1L, 2L, 2L, 1L, 0L, 2L, 1L,
    0L, 1L, 2L, 1L, 3L, 2L, 1L, 0L, 2L, 3L, 1L, 2L, 1L, 2L, 0L, 1L
  )
  fit <- .spatial_latent_issue_fit(stats::poisson(), value)
  newdata <- fit$data
  newdata <- newdata[newdata$trait == "t1", ][1:4, c("site", "unit", "trait", "lon", "lat"), drop = FALSE]
  cache_key <- "gllvmTMB.warned_simulate_newdata_gaussian_fallback"
  withr::local_options(stats::setNames(list(NULL), cache_key))
  set.seed(11L)
  expect_no_warning(
    sim <- simulate(fit, newdata = newdata, nsim = 5L)
  )
  sim1 <- sim[, 1L]
  expect_true(all(sim1 == round(sim1)))
  expect_true(all(sim1 >= 0))
  expect_false(any(sim1 != round(sim1)))
})

test_that("simulate(newdata) draws valid binomial counts in [0, size] (#1975)", {
  .skip_spatial_heavy()
  set.seed(112704L)
  value <- as.integer(stats::rbinom(48L, 1L, 0.45))
  fit <- .spatial_latent_issue_fit(stats::binomial(), value)
  newdata <- fit$data[fit$data$trait == "t1", ][1:4, c("site", "unit", "trait", "lon", "lat"), drop = FALSE]
  set.seed(12L)
  expect_no_warning(
    sim <- simulate(fit, newdata = newdata, nsim = 8L)
  )
  sim1 <- sim[, 1L]
  expect_true(all(sim1 %in% c(0L, 1L)))
  expect_gte(min(sim1), 0)
  expect_lte(max(sim1), 1)
})