#' Add UTM coordinates to a data frame
#'
#' Transform longitude/latitude columns to an equal-distance UTM coordinate
#' reference system with [sf::st_transform()].
#'
#' @param dat Data frame containing longitude and latitude columns.
#' @param ll_names Character names of longitude then latitude columns.
#' @param ll_crs Input coordinate reference system.
#' @param utm_names Names for the two new coordinate columns.
#' @param utm_crs Output UTM CRS; by default inferred with [get_crs()].
#' @param units Output coordinate units: kilometres or metres.
#' @return A copy of `dat` with the requested UTM coordinate columns.
#' @export
#'
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' d <- data.frame(lat = c(52.1, 53.4), lon = c(-130, -131.4))
#' add_utm_columns(d, c("lon", "lat"))
add_utm_columns <- function(
  dat,
  ll_names = c("longitude", "latitude"),
  ll_crs = 4326,
  utm_names = c("X", "Y"),
  utm_crs = get_crs(dat, ll_names),
  units = c("km", "m")
) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg sf} package must be installed to transform coordinates.",
      ">" = "Run {.code install.packages(\"sf\")}, then retry."
    ))
  }
  .gllvm_validate_coordinate_names(dat, ll_names, "ll_names")
  if (
    !is.character(utm_names) ||
      length(utm_names) != 2L ||
      anyDuplicated(utm_names)
  ) {
    cli::cli_abort(c(
      "{.arg utm_names} must contain two distinct output names.",
      ">" = "Pass e.g. {.code utm_names = c(\"X\", \"Y\")} (the default)."
    ))
  }
  if (any(utm_names %in% names(dat))) {
    cli::cli_abort(
      "Choose {.arg utm_names} that are not already present in {.arg dat}."
    )
  }
  if (
    grepl("lat", ll_names[[1L]], ignore.case = TRUE) ||
      grepl("lon", ll_names[[2L]], ignore.case = TRUE)
  ) {
    cli::cli_warn("{.arg ll_names} should be longitude followed by latitude.")
  }
  units <- match.arg(units)
  coordinates <- as.matrix(dat[, ll_names, drop = FALSE])
  if (!is.numeric(coordinates) || any(!is.finite(coordinates))) {
    cli::cli_abort(c(
      "Longitude and latitude columns must be finite numeric values.",
      ">" = "Check {.arg ll_names} points at the right columns, and drop or impute rows with NA/Inf coordinates first."
    ))
  }
  points <- sf::st_as_sf(dat, coords = ll_names, crs = ll_crs, remove = FALSE)
  transformed <- sf::st_coordinates(sf::st_transform(points, utm_crs))
  multiplier <- if (identical(units, "km")) 1 / 1000 else 1
  dat[[utm_names[[1L]]]] <- transformed[, 1L] * multiplier
  dat[[utm_names[[2L]]]] <- transformed[, 2L] * multiplier
  dat
}

#' Infer a UTM coordinate reference system
#'
#' @param dat Data frame containing longitude and latitude columns.
#' @param ll_names Character names of longitude then latitude columns.
#' @return An EPSG code for the predominant UTM zone.
#' @export
get_crs <- function(dat, ll_names = c("longitude", "latitude")) {
  .gllvm_validate_coordinate_names(dat, ll_names, "ll_names")
  longitude <- dat[[ll_names[[1L]]]]
  latitude <- dat[[ll_names[[2L]]]]
  if (
    !is.numeric(longitude) ||
      !is.numeric(latitude) ||
      any(!is.finite(longitude)) ||
      any(!is.finite(latitude)) ||
      any(longitude < -180 | longitude > 180) ||
      any(latitude < -90 | latitude > 90)
  ) {
    cli::cli_abort(c(
      "Longitude must lie in [-180, 180] and latitude in [-90, 90].",
      ">" = "Check {.arg ll_names} names the longitude column first and the latitude column second, in that order."
    ))
  }
  zone <- floor((longitude + 180) / 6) + 1L
  zone[zone == 61L] <- 60L
  northern <- latitude >= 0
  if (length(unique(zone)) > 1L) {
    cli::cli_warn(
      "Coordinates span multiple UTM zones; using the most frequent zone."
    )
  }
  if (length(unique(northern)) > 1L) {
    cli::cli_warn(
      "North and south latitudes detected; using the predominant hemisphere."
    )
  }
  predominant_zone <- as.integer(names(sort(table(zone), decreasing = TRUE))[[
    1L
  ]])
  predominant_north <- as.logical(names(sort(
    table(northern),
    decreasing = TRUE
  ))[[1L]])
  epsg <- if (predominant_north) {
    32600L + predominant_zone
  } else {
    32700L + predominant_zone
  }
  cli::cli_inform(
    "Using UTM zone {predominant_zone}{if (predominant_north) 'N' else 'S'} (EPSG:{epsg})."
  )
  as.numeric(epsg)
}

.gllvm_validate_coordinate_names <- function(dat, coordinate_names, argument) {
  if (!is.data.frame(dat) || !nrow(dat)) {
    cli::cli_abort(c(
      "{.arg dat} must be a non-empty data frame.",
      ">" = "Pass the data frame that holds your coordinate columns, with at least one row."
    ))
  }
  if (
    !is.character(coordinate_names) ||
      length(coordinate_names) != 2L ||
      anyDuplicated(coordinate_names) ||
      !all(coordinate_names %in% names(dat))
  ) {
    cli::cli_abort(c(
      "{.arg {argument}} must name two distinct columns in {.arg dat}.",
      ">" = "Pass two column names that both exist in {.arg dat}, e.g. {.code ll_names = c(\"longitude\", \"latitude\")}."
    ))
  }
  invisible(NULL)
}
