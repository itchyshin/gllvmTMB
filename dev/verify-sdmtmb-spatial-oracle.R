#!/usr/bin/env Rscript

# Deliberately outside testthat and package dependencies. This is a
# post-implementation black-box comparison only; fmesher/Lindgren's SPDE
# specification remains the arbiter of any discrepancy.
oracle_library <- Sys.getenv("SDMTMB_ORACLE_LIB", unset = "")
if (nzchar(oracle_library)) {
  .libPaths(c(oracle_library, .libPaths()))
}
if (!requireNamespace("sdmTMB", quietly = TRUE)) {
  stop(
    "Set SDMTMB_ORACLE_LIB to an isolated library containing sdmTMB before running this oracle.",
    call. = FALSE
  )
}

pkgload::load_all(".", quiet = TRUE)
tolerance <- 1e-10
coordinates <- data.frame(
  x = c(0, 0.2, 0.8, 1, 0.1, 0.9),
  y = c(0, 1, 0, 1, 0.4, 0.6)
)

native <- gllvmTMB::make_mesh(coordinates, c("x", "y"), cutoff = 0.1)
oracle <- sdmTMB::make_mesh(coordinates, c("x", "y"), cutoff = 0.1)
stopifnot(isTRUE(all.equal(
  as.matrix(native$A_st), as.matrix(oracle$A_st), tolerance = tolerance
)))
for (name in c("c0", "g1", "g2")) {
  stopifnot(isTRUE(all.equal(
    as.matrix(native$spde[[name]]), as.matrix(oracle$spde[[name]]), tolerance = tolerance
  )))
}

lon_lat <- data.frame(lon = c(-130, -131.4), lat = c(53.5, 54.1))
native_crs <- gllvmTMB::add_utm_columns(lon_lat, ll_names = c("lon", "lat"))
oracle_crs <- sdmTMB::add_utm_columns(lon_lat, ll_names = c("lon", "lat"))
stopifnot(isTRUE(all.equal(native_crs$X, oracle_crs$X, tolerance = tolerance)))
stopifnot(isTRUE(all.equal(native_crs$Y, oracle_crs$Y, tolerance = tolerance)))

message(sprintf(
  "PASS: sdmTMB black-box mesh/FEM/CRS comparison (sdmTMB %s; tolerance %.0e).",
  as.character(utils::packageVersion("sdmTMB")), tolerance
))
