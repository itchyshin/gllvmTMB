## #1976: spatial_latent()-only fits expose projected LV scores for ordination helpers.

test_that("getLV and extract_ordination return spatial_latent scores when rr_B is absent (#1976)", {
  skip_on_cran()
  if (!requireNamespace("fmesher", quietly = TRUE)) {
    skip("fmesher required")
  }
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)

  set.seed(112704L)
  n <- 16L
  coords <- data.frame(
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
  df <- expand.grid(
    site = coords$site,
    trait = c("t1", "t2", "t3"),
    stringsAsFactors = FALSE
  )
  df$lon <- coords$lon[match(df$site, coords$site)]
  df$lat <- coords$lat[match(df$site, coords$site)]
  df$unit <- df$site
  set.seed(99L)
  df$value <- stats::rnorm(nrow(df), 0.2 * as.numeric(factor(df$trait)), 0.4)
  df$site <- factor(df$site)
  df$trait <- factor(df$trait, levels = c("t1", "t2", "t3"))
  df$unit <- factor(df$unit, levels = levels(df$site))
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.11, extend = 0.1)
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait | unit, mesh = mesh, d = 1),
    data = df,
    unit = "site",
    family = stats::gaussian(),
    silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_true(isTRUE(fit$use$spatial_latent))
  expect_false(is.null(getLV(fit)))
  ord <- extract_ordination(fit, level = "unit")
  expect_false(is.null(ord))
  expect_equal(nrow(ord$scores), n)
  expect_equal(ncol(ord$scores), 1L)
  expect_equal(nrow(ord$loadings), 3L)
  expect_equal(ncol(ord$loadings), 1L)
  expect_no_error(gllvmTMB::ordiplot(fit, axes = 1L, biplot = FALSE))
})