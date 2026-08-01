test_that("UTM conversion works", {
  skip_on_cran()
  skip_if_not_installed("sf")

  d <- data.frame(lat = c(52.1, 53.4), lon = c(-130.0, -131.4))
  x <- add_utm_columns(d, c("lon", "lat"))
  expect_equal(class(x), "data.frame")
  expect_true("X" %in% names(x))
  expect_true("Y" %in% names(x))
  metres <- add_utm_columns(d, c("lon", "lat"), units = "m")
  expect_equal(metres$X / x$X, rep(1000, nrow(d)), tolerance = 1e-8)

  expect_error(add_utm_columns(d, c("xx", "lat"))) # column missing
  d$X <- 1
  expect_error(add_utm_columns(d, c("lon", "lat"))) # X already there
  d$X <- NULL

  dd <- d
  names(dd) <- c("lon", "lat")
  expect_warning(add_utm_columns(dd, c("lat", "lon"))) # reversed
  expect_error(add_utm_columns(dd, c("lat", "lon", "x"))) # too many

  # CRS:
  expect_identical(get_crs(d, c("lon", "lat")), 32609)
  expect_error(get_crs(d, c("longitude", "latitude")), "columns")
  expect_error(
    get_crs(data.frame(lon = 190, lat = 0), c("lon", "lat")),
    "Longitude"
  )

  # multiple utm zones:
  d <- data.frame(lat = c(52.1, 53.4, 53), lon = c(-130.0, -131.4, -120))
  expect_warning(get_crs(d, c("lon", "lat")), regexp = "zones")

  # N and S
  d <- data.frame(lat = c(52.1, 53.4, -53), lon = c(-130.0, -131.4, -130))
  expect_warning(get_crs(d, c("lon", "lat")), regexp = "North")
})
