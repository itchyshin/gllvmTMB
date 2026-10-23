## Edge-case pins for three exported utilities whose own test files are thin:
## add_utm_columns(), profile_cross_rho_ci() and plot_anisotropy2().
## Everything here asserts what the code does today; refusals are cli_abort()
## conditions (class "rlang_error", no package-specific subclass).

expect_refusal <- function(expr, message, advice) {
  err <- tryCatch(expr, error = function(e) e)
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), message, fixed = TRUE)
  if (!missing(advice)) {
    expect_match(conditionMessage(err), advice, fixed = TRUE)
  }
}

## ---- add_utm_columns() -----------------------------------------------------

test_that("add_utm_columns() refuses ll_names that are not two existing columns", {
  skip_if_not_installed("sf")
  d <- data.frame(lon = c(-130, -131.4), lat = c(52.1, 53.4))
  advice <- "Pass two column names that both exist"

  expect_refusal(
    add_utm_columns(d, c("longitude", "latitude")),
    "`ll_names` must name two distinct columns in `dat`.",
    advice
  )
  expect_refusal(add_utm_columns(d, c("lon", "nope")), "`ll_names`", advice)
  expect_refusal(add_utm_columns(d, "lon"), "`ll_names`", advice)
  expect_refusal(add_utm_columns(d, c("lon", "lon")), "`ll_names`", advice)
  expect_refusal(add_utm_columns(d, c(1, 2)), "`ll_names`", advice)
})

test_that("add_utm_columns() refuses an empty or non-data-frame input", {
  skip_if_not_installed("sf")
  advice <- "with at least one row"
  expect_refusal(
    add_utm_columns(data.frame(lon = numeric(), lat = numeric()), c("lon", "lat")),
    "`dat` must be a non-empty data frame.",
    advice
  )
  expect_refusal(
    add_utm_columns(list(lon = 1, lat = 2), c("lon", "lat")),
    "`dat` must be a non-empty data frame.",
    advice
  )
})

test_that("add_utm_columns() refuses bad utm_names", {
  skip_if_not_installed("sf")
  d <- data.frame(lon = c(-130, -131.4), lat = c(52.1, 53.4))
  advice <- "Pass e.g. `utm_names = c(\"X\", \"Y\")`"
  expect_refusal(
    add_utm_columns(d, c("lon", "lat"), utm_names = "X"),
    "`utm_names` must contain two distinct output names.",
    advice
  )
  expect_refusal(
    add_utm_columns(d, c("lon", "lat"), utm_names = c("X", "X")),
    "`utm_names`",
    advice
  )
  expect_refusal(
    add_utm_columns(d, c("lon", "lat"), utm_names = c(1, 2)),
    "`utm_names`",
    advice
  )
  # existing column clash has no advice line
  expect_refusal(
    add_utm_columns(d, c("lon", "lat"), utm_names = c("lon", "Y")),
    "Choose `utm_names` that are not already present in `dat`."
  )
})

test_that("add_utm_columns() refuses NA, Inf and non-numeric coordinates", {
  skip_if_not_installed("sf")
  msg <- "Longitude and latitude columns must be finite numeric values."
  advice <- "drop or impute rows with NA/Inf coordinates first"

  d_na <- data.frame(lon = c(-130, NA), lat = c(52.1, 53.4))
  expect_refusal(add_utm_columns(d_na, c("lon", "lat")), msg, advice)

  d_inf <- data.frame(lon = c(-130, -131), lat = c(52.1, Inf))
  expect_refusal(add_utm_columns(d_inf, c("lon", "lat")), msg, advice)

  d_chr <- data.frame(lon = c("-130", "-131"), lat = c(52.1, 53.4))
  expect_refusal(add_utm_columns(d_chr, c("lon", "lat")), msg, advice)
})

test_that("add_utm_columns() out-of-range coordinates are refused by the default CRS", {
  skip_if_not_installed("sf")
  advice <- "names the longitude column first and the latitude column second"
  msg <- "Longitude must lie in [-180, 180] and latitude in [-90, 90]."

  expect_refusal(
    add_utm_columns(data.frame(lon = c(190, 191), lat = c(10, 11)), c("lon", "lat")),
    msg,
    advice
  )
  expect_refusal(
    add_utm_columns(data.frame(lon = c(10, 11), lat = c(95, 96)), c("lon", "lat")),
    msg,
    advice
  )
  # same refusal straight from get_crs()
  expect_refusal(
    get_crs(data.frame(lon = -181, lat = 0), c("lon", "lat")),
    msg,
    advice
  )
})

test_that("add_utm_columns() adds numeric columns with the expected names and units", {
  skip_if_not_installed("sf")
  d <- data.frame(
    id = 1:3,
    lon = c(-130, -131.4, -129.5),
    lat = c(52.1, 53.4, 52.8)
  )
  km <- suppressMessages(add_utm_columns(d, c("lon", "lat")))
  expect_identical(names(km), c("id", "lon", "lat", "X", "Y"))
  expect_identical(km[c("id", "lon", "lat")], d)
  expect_type(km$X, "double")
  expect_type(km$Y, "double")
  expect_true(all(is.finite(km$X) & is.finite(km$Y)))
  # kilometres: eastings inside the 0-1000 km band, northings near 5,800 km
  expect_true(all(km$X > 0 & km$X < 1000))
  expect_true(all(km$Y > 5500 & km$Y < 6000))

  m <- suppressMessages(add_utm_columns(d, c("lon", "lat"), units = "m"))
  expect_equal(m$X, km$X * 1000, tolerance = 1e-9)
  expect_equal(m$Y, km$Y * 1000, tolerance = 1e-9)

  custom <- suppressMessages(
    add_utm_columns(d, c("lon", "lat"), utm_names = c("east", "north"))
  )
  expect_identical(names(custom), c("id", "lon", "lat", "east", "north"))
  expect_equal(custom$east, km$X)
  expect_equal(custom$north, km$Y)

  expect_error(
    suppressMessages(add_utm_columns(d, c("lon", "lat"), units = "miles")),
    "should be one of"
  )
})

test_that("add_utm_columns() reports the inferred zone as a message", {
  skip_if_not_installed("sf")
  d <- data.frame(lon = c(-130, -131.4), lat = c(52.1, 53.4))
  expect_message(
    add_utm_columns(d, c("lon", "lat")),
    "Using UTM zone 9N (EPSG:32609).",
    fixed = TRUE
  )
})

test_that("add_utm_columns() honours a non-default utm_crs and ll_crs", {
  skip_if_not_installed("sf")
  d <- data.frame(lon = c(-130, -131.4), lat = c(52.1, 53.4))
  default <- suppressMessages(add_utm_columns(d, c("lon", "lat")))

  # an explicit utm_crs equal to the inferred one is a no-op; no zone message
  expect_no_message(
    same <- add_utm_columns(d, c("lon", "lat"), utm_crs = 32609)
  )
  expect_equal(same, default)

  # a different zone moves the coordinates
  other <- add_utm_columns(d, c("lon", "lat"), utm_crs = 32610)
  expect_false(isTRUE(all.equal(other$X, default$X)))
  expect_true(all(is.finite(other$X)))

  # input already in Web Mercator (metres), declared through ll_crs
  merc <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(d, coords = c("lon", "lat"), crs = 4326),
    3857
  ))
  dm <- data.frame(mx = merc[, 1], my = merc[, 2])
  from_merc <- add_utm_columns(
    dm,
    c("mx", "my"),
    ll_crs = 3857,
    utm_crs = 32609
  )
  expect_identical(names(from_merc), c("mx", "my", "X", "Y"))
  expect_equal(from_merc$X, default$X, tolerance = 1e-6)
  expect_equal(from_merc$Y, default$Y, tolerance = 1e-6)
})

test_that("zone choice is stable for points straddling a zone edge", {
  # UTM zone 31 covers 0-6 E, zone 32 covers 6-12 E.
  just_below <- data.frame(lon = 5.9999, lat = 50)
  just_above <- data.frame(lon = 6.0001, lat = 50)
  expect_identical(suppressMessages(get_crs(just_below, c("lon", "lat"))), 32631)
  expect_identical(suppressMessages(get_crs(just_above, c("lon", "lat"))), 32632)

  # the boundary itself belongs to the upper zone; -180 to zone 1; 180 to 60
  expect_identical(suppressMessages(get_crs(data.frame(lon = 6, lat = 50), c("lon", "lat"))), 32632)
  expect_identical(suppressMessages(get_crs(data.frame(lon = -180, lat = 10), c("lon", "lat"))), 32601)
  expect_identical(suppressMessages(get_crs(data.frame(lon = 180, lat = 10), c("lon", "lat"))), 32660)
  expect_identical(suppressMessages(get_crs(data.frame(lon = 6, lat = -10), c("lon", "lat"))), 32732)

  # a straddling set warns and takes the most frequent zone
  d <- data.frame(lon = c(5.9999, 6.0001, 6.0002), lat = 50)
  expect_warning(
    expect_message(get_crs(d, c("lon", "lat")), "zone 32N"),
    "Coordinates span multiple UTM zones; using the most frequent zone."
  )
  # a 1-1 tie goes to the lower zone today
  tie <- rbind(just_below, just_above)
  crs1 <- suppressMessages(suppressWarnings(get_crs(tie, c("lon", "lat"))))
  crs2 <- suppressMessages(suppressWarnings(get_crs(tie[2:1, ], c("lon", "lat"))))
  expect_identical(crs1, 32631)
  expect_identical(crs2, crs1)

  skip_if_not_installed("sf")
  out <- suppressMessages(suppressWarnings(add_utm_columns(d, c("lon", "lat"))))
  expect_true(all(is.finite(out$X) & is.finite(out$Y)))
  # all rows share one zone, so the lowest-longitude point sits west of the others
  expect_true(out$X[[1L]] < out$X[[2L]])
})

## ---- profile_cross_rho_ci() ------------------------------------------------

parabola_profile <- function(rho = seq(-0.8, 0.8, by = 0.2), centre = 0, scale = 10) {
  data.frame(rho = rho, delta_deviance = scale * (rho - centre)^2)
}

test_that("profile_cross_rho_ci() refuses a profile without the required columns", {
  msg <- "`profile` must be a data frame from `profile_cross_rho()`."
  advice <- "It needs the rho and delta_deviance columns."
  expect_refusal(profile_cross_rho_ci(list(rho = 1, delta_deviance = 0)), msg, advice)
  expect_refusal(profile_cross_rho_ci(data.frame(rho = 1:3)), msg, advice)
  expect_refusal(
    profile_cross_rho_ci(data.frame(rho = 1:3, dev = 1:3)),
    msg,
    advice
  )
})

test_that("profile_cross_rho_ci() refuses a level outside (0, 1)", {
  prof <- parabola_profile()
  msg <- "`level` must be a single number in (0, 1)."
  for (bad in list(0, 1, 1.5, -0.1, NA_real_, c(0.9, 0.95), "0.95")) {
    expect_refusal(profile_cross_rho_ci(prof, level = bad), msg)
  }
})

test_that("profile_cross_rho_ci() needs two finite profile points", {
  one <- data.frame(rho = 0, delta_deviance = 0)
  expect_refusal(
    profile_cross_rho_ci(one),
    "Need at least two finite profile points to form an interval; got 1."
  )
  nonfinite <- data.frame(rho = c(0, 0.5, 1), delta_deviance = c(0, NA, Inf))
  expect_refusal(
    profile_cross_rho_ci(nonfinite),
    "Need at least two finite profile points to form an interval; got 1."
  )
  empty <- data.frame(rho = numeric(), delta_deviance = numeric())
  expect_refusal(
    profile_cross_rho_ci(empty),
    "Need at least two finite profile points to form an interval; got 0."
  )
})

test_that("profile_cross_rho_ci() does not read an is_best column", {
  prof <- parabola_profile()
  base <- profile_cross_rho_ci(prof)

  # no is_best column at all (the fixture above has none)
  expect_false("is_best" %in% names(prof))
  expect_identical(base$estimate, 0)

  # an is_best column that marks nothing, or the wrong row, changes nothing
  none <- cbind(prof, is_best = FALSE)
  wrong <- cbind(prof, is_best = seq_len(nrow(prof)) == 1L)
  expect_identical(profile_cross_rho_ci(none), base)
  expect_identical(profile_cross_rho_ci(wrong), base)
})

test_that("profile_cross_rho_ci() interpolates a quadratic and orders unsorted input", {
  prof <- parabola_profile()
  ci <- profile_cross_rho_ci(prof)
  expect_named(
    ci,
    c("estimate", "lower", "upper", "level", "lower_bounded", "upper_bounded", "threshold")
  )
  expect_equal(ci$threshold, stats::qchisq(0.95, 1))
  expect_true(ci$lower_bounded && ci$upper_bounded)
  expect_true(ci$lower < 0 && ci$upper > 0)
  expect_equal(profile_cross_rho_ci(prof[nrow(prof):1, ]), ci)
})

test_that("profile_cross_rho_ci() flat profile gives the grid edges, flagged unbounded", {
  flat <- data.frame(rho = c(-0.5, 0, 0.5, 0.9), delta_deviance = 0)
  ci <- profile_cross_rho_ci(flat)
  # which.min takes the first tie, i.e. the lowest rho
  expect_identical(ci$estimate, -0.5)
  expect_identical(ci$lower, -0.5)
  expect_identical(ci$upper, 0.9)
  expect_false(ci$lower_bounded)
  expect_false(ci$upper_bounded)
  expect_false(anyNA(unlist(ci)))
})

test_that("profile_cross_rho_ci() crossing outside the grid reports the edge, not NA", {
  # curve never reaches the 0.95 threshold (3.84) inside the grid
  shallow <- parabola_profile(scale = 1)
  ci <- profile_cross_rho_ci(shallow)
  expect_identical(ci$lower, min(shallow$rho))
  expect_identical(ci$upper, max(shallow$rho))
  expect_false(ci$lower_bounded)
  expect_false(ci$upper_bounded)

  # one-sided: best point at the lower edge, curve crosses only on the right
  rising <- data.frame(rho = c(0, 0.25, 0.5, 0.75), delta_deviance = c(0, 1, 5, 9))
  one <- profile_cross_rho_ci(rising)
  expect_identical(one$estimate, 0)
  expect_identical(one$lower, 0)
  expect_false(one$lower_bounded)
  expect_true(one$upper_bounded)
  expect_true(one$upper > 0.25 && one$upper < 0.5)

  # a higher level moves the threshold beyond a curve that crossed at 0.95
  cross95 <- profile_cross_rho_ci(parabola_profile(scale = 10), level = 0.95)
  cross999 <- profile_cross_rho_ci(parabola_profile(scale = 10), level = 0.9999)
  expect_true(cross95$upper_bounded)
  expect_false(cross999$upper_bounded)
  expect_identical(cross999$upper, 0.8)
})

test_that("profile_cross_rho_ci() clamps bounds to [-1, 1] and ignores non-finite rows", {
  wide <- data.frame(rho = c(-2, 0, 2), delta_deviance = 0)
  ci <- profile_cross_rho_ci(wide)
  expect_identical(ci$lower, -1)
  expect_identical(ci$upper, 1)
  expect_identical(ci$estimate, -2) # the estimate itself is not clamped

  prof <- parabola_profile()
  dirty <- rbind(prof, data.frame(rho = c(NA, 0.3), delta_deviance = c(1, NA)))
  expect_identical(profile_cross_rho_ci(dirty), profile_cross_rho_ci(prof))
})

## ---- plot_anisotropy2() ----------------------------------------------------

## Same minimal fixture as tests/testthat/test-anisotropy.R.
fake_aniso_fit <- function(
  kappa = 2,
  family = gaussian(),
  use = list(spde = TRUE)
) {
  structure(
    list(
      report = list(kappa = kappa),
      family = family,
      use = use,
      mesh = list(xy_cols = c("east_km", "north_km"))
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

test_that("plot_anisotropy2() draws with base graphics and returns an invisible list", {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit(grDevices::dev.off(), add = TRUE)

  res <- withVisible(plot_anisotropy2(fake_aniso_fit(kappa = 4)))
  expect_false(res$visible)
  out <- res$value
  expect_type(out, "list")
  expect_false(inherits(out, "ggplot"))
  expect_named(out, c("data", "range", "kappa", "H", "anisotropy_estimated"))
  expect_equal(out$range, sqrt(8) / 4)
  expect_equal(out$kappa, 4)
  expect_identical(out$H, diag(2L))
  expect_false(out$anisotropy_estimated)
  expect_s3_class(out$data, "data.frame")
  expect_equal(nrow(out$data), 361L)
  expect_equal(unique(out$data$axis_x), "east_km")
  expect_equal(unique(out$data$axis_y), "north_km")
})

test_that("plot_anisotropy2() falls back to x/y axis labels without mesh columns", {
  fit <- fake_aniso_fit()
  fit$mesh <- list()
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  out <- plot_anisotropy2(fit)
  expect_equal(unique(out$data$axis_x), "x")
  expect_equal(unique(out$data$axis_y), "y")
})

test_that("plot_anisotropy2() refuses a non-spatial or unsupported fit", {
  expect_refusal(
    plot_anisotropy2(structure(list(), class = "gllvmTMB")),
    "`object` must be a fitted <gllvmTMB_multi> model."
  )
  expect_refusal(
    plot_anisotropy2(data.frame(a = 1)),
    "`object` must be a fitted <gllvmTMB_multi> model."
  )
  expect_refusal(
    plot_anisotropy2(fake_aniso_fit(use = list(spde = FALSE))),
    "does not contain a fitted gllvmTMB spatial field"
  )
  expect_refusal(
    plot_anisotropy2(fake_aniso_fit(
      family = structure(list(delta = TRUE), class = "family")
    )),
    "not supported for delta spatial models"
  )
  st <- fake_aniso_fit()
  st$use$spatiotemporal <- TRUE
  expect_refusal(plot_anisotropy2(st), "not supported for spatiotemporal models")
  for (bad in list(NA_real_, 0, -1, Inf)) {
    expect_refusal(
      plot_anisotropy2(fake_aniso_fit(kappa = bad)),
      "one finite positive spatial kappa estimate"
    )
  }
})

test_that("plot_anisotropy2() refuses any model other than 1", {
  msg <- "`model` must be 1; gllvmTMB fits one shared spatial range parameter."
  fit <- fake_aniso_fit()
  for (bad in list(2, 0, NA_real_, "1", c(1, 1), NULL)) {
    expect_refusal(plot_anisotropy2(fit, model = bad), msg)
  }
})
