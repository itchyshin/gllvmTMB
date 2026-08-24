## Response-column SPDE slope contract (Design 130).
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula term | DGP draw | Extractor | Truth |
## |--------|--------------|----------|-----------|-------|
## | K_column(kappa) | spatial_slope(x + z | trait) | B = L_K Z L_Sigma' | source$K_column | exact projected correlation |
## | Sigma_predictor | spatial_slope(x + z | trait) | same B draw | extract_Sigma(level="column_slope")$Sigma | planted P x P covariance |
## | x_i' b_t | spatial_slope(x + z | trait) | row-specific x,z times B[t,] | fitted predictor contribution | no intercept column |
## | kappa | spatial_slope(x + z | trait) | Q(kappa) projected at trait coordinates | source$kappa | sqrt(8) / range |

.spatial_column_fixture <- function(seed = 1301L, n_unit = 18L,
                                    n_rep = 2L) {
  set.seed(seed)
  locations <- expand.grid(
    east_km = 0:2,
    north_km = 0:1,
    KEEP.OUT.ATTRS = FALSE
  )
  locations$trait <- paste0("t", seq_len(nrow(locations)))
  locations <- locations[c("trait", "east_km", "north_km")]
  mesh <- make_mesh(
    locations, c("east_km", "north_km"), cutoff = 0.15,
    id_col = "trait"
  )
  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(n_unit))),
    trait = factor(locations$trait, levels = locations$trait),
    rep = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  loc_index <- match(as.character(dat$trait), locations$trait)
  bx <- scale(locations$east_km, scale = FALSE)[, 1L] * 0.28
  bz <- scale(locations$north_km, scale = FALSE)[, 1L] * -0.32
  dat$value <- 0.12 * as.integer(dat$trait) +
    dat$x * bx[loc_index] + dat$z * bz[loc_index] +
    stats::rnorm(nrow(dat), sd = 0.3)
  list(data = dat, locations = locations, mesh = mesh)
}

.fit_spatial_column <- function(fx, formula) {
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
  if (!identical(fit$opt$convergence, 0L)) {
    stop("spatial column-slope fixture did not converge", call. = FALSE)
  }
  fit
}

.projected_spde_correlation <- function(mesh, kappa, labels) {
  order <- match(labels, mesh$row_labels)
  A <- as.matrix(mesh$A_st[order, , drop = FALSE])
  Q <- kappa^4 * as.matrix(mesh$spde$c0) +
    2 * kappa^2 * as.matrix(mesh$spde$g1) +
    as.matrix(mesh$spde$g2)
  C_raw <- A %*% solve(Q, t(A))
  inv_sd <- 1 / sqrt(diag(C_raw))
  K <- C_raw * tcrossprod(inv_sd)
  diag(K) <- 1
  K
}

test_that("make_mesh id_col is opt-in and retains unique projection labels", {
  skip_if_not_installed("fmesher")
  locations <- data.frame(
    trait = paste0("t", 1:4),
    x = c(0, 1, 0, 1),
    y = c(0, 0, 1, 1)
  )
  ordinary <- make_mesh(locations, c("x", "y"), cutoff = 0.1)
  expect_identical(
    names(ordinary),
    c("loc_xy", "xy_cols", "mesh", "spde", "loc_centers", "A_st")
  )
  labelled <- make_mesh(
    locations, c("x", "y"), cutoff = 0.1, id_col = "trait"
  )
  expect_identical(labelled$id_col, "trait")
  expect_identical(labelled$row_labels, locations$trait)
  formal_names <- names(formals(make_mesh))
  expect_lt(match("...", formal_names), match("id_col", formal_names))
  expect_error(
    make_mesh(
      transform(locations, trait = c("t1", "t1", "t3", "t4")),
      c("x", "y"), cutoff = 0.1, id_col = "trait"
    ),
    "uniquely|Duplicated"
  )
})

test_that("spatial_slope uses a normalized trait-labelled SPDE and no intercept", {
  skip_if_not_installed("fmesher")
  fx <- .spatial_column_fixture()
  column_mesh <- fx$mesh
  fit <- .fit_spatial_column(
    fx,
    value ~ 0 + trait + spatial_slope(x + z || trait, mesh = column_mesh)
  )

  expect_identical(fit$tmb_data$use_spatial_column_slope, 1L)
  expect_identical(fit$tmb_data$use_spde_slope, 1L)
  expect_identical(fit$tmb_data$use_spde_dep_slope, 1L)
  expect_identical(fit$tmb_data$use_phylo_column_slope, 0L)
  expect_identical(fit$tmb_data$n_lhs_cols_spde, 2L)
  spde_chol_map <- fit$tmb_obj$env$map$theta_spde_dep_chol
  expect_identical(sum(!is.na(as.integer(spde_chol_map))), 2L)
  expect_identical(length(spde_chol_map), 3L)
  expect_equal(
    fit$tmb_data$Z_spde_aug,
    cbind(x = fx$data$x, z = fx$data$z),
    ignore_attr = TRUE
  )

  K_oracle <- .projected_spde_correlation(
    fx$mesh, as.numeric(fit$report$kappa_s), levels(fx$data$trait)
  )
  expect_equal(fit$report$spatial_column_K, K_oracle, tolerance = 1e-8)
  expect_identical(diag(fit$report$spatial_column_K), rep(1, 6L))

  ext <- extract_Sigma(fit, level = "column_slope")
  expect_identical(ext$source$type, "spatial")
  expect_identical(ext$predictors, c("x", "z"))
  expect_identical(ext$column_labels, levels(fx$data$trait))
  expect_identical(ext$source$normalization,
                   "exact_projected_unit_diagonal")
  expect_equal(ext$source$practical_range,
               sqrt(8) / ext$source$kappa)
  expected_coordinates <- as.matrix(fx$locations[, 2:3])
  rownames(expected_coordinates) <- fx$locations$trait
  expect_equal(ext$source$coordinates, expected_coordinates)
  expect_equal(unname(ext$Sigma[1, 2]), 0, tolerance = 1e-12)
  expect_error(
    extract_Sigma(fit, level = "spatial"),
    "column_slope"
  )
  kappa_index <- which(names(fit$opt$par) == "log_kappa_spde")
  expect_length(kappa_index, 1L)
  gradient <- fit$tmb_obj$gr(fit$opt$par)
  expect_true(is.finite(gradient[kappa_index]))
})

test_that("one-predictor spatial bars are the same fitted model", {
  skip_if_not_installed("fmesher")
  fx <- .spatial_column_fixture(seed = 1302L)
  column_mesh <- fx$mesh
  dep <- .fit_spatial_column(
    fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
  )
  indep <- .fit_spatial_column(
    fx, value ~ 0 + trait + spatial_slope(x || trait, mesh = column_mesh)
  )
  expect_equal(dep$opt$objective, indep$opt$objective, tolerance = 1e-10)
  expect_identical(names(dep$opt$par), names(indep$opt$par))
  expect_equal(unname(dep$opt$par), unname(indep$opt$par), tolerance = 1e-10)
  expect_equal(
    extract_Sigma(dep, level = "column_slope"),
    extract_Sigma(indep, level = "column_slope"),
    tolerance = 1e-10
  )
})

test_that("spatial column labels align independently of coordinate-table order", {
  skip_if_not_installed("fmesher")
  fx <- .spatial_column_fixture(seed = 1303L)
  perm <- c(6L, 2L, 4L, 1L, 5L, 3L)
  permuted_mesh <- make_mesh(
    fx$locations[perm, ], c("east_km", "north_km"),
    mesh = fx$mesh$mesh, id_col = "trait"
  )
  column_mesh <- fx$mesh
  aligned <- .fit_spatial_column(
    fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
  )
  column_mesh <- permuted_mesh
  permuted <- .fit_spatial_column(
    fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
  )
  expect_equal(aligned$opt$objective, permuted$opt$objective, tolerance = 1e-9)
  expect_equal(
    extract_Sigma(aligned, level = "column_slope"),
    extract_Sigma(permuted, level = "column_slope"),
    tolerance = 1e-8
  )
})

test_that("spatial_slope rejects unlabelled, mismatched, and duplicate coordinates", {
  skip_if_not_installed("fmesher")
  fx <- .spatial_column_fixture(seed = 1304L)

  column_mesh <- make_mesh(
    fx$locations, c("east_km", "north_km"),
    mesh = fx$mesh$mesh
  )
  expect_error(
    .fit_spatial_column(
      fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
    ),
    "labelled response-column mesh"
  )

  wrong <- fx$locations
  wrong$trait[1L] <- "extra"
  column_mesh <- make_mesh(
    wrong, c("east_km", "north_km"),
    mesh = fx$mesh$mesh, id_col = "trait"
  )
  expect_error(
    .fit_spatial_column(
      fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
    ),
    "match the response-column levels exactly"
  )

  duplicate_xy <- fx$locations
  duplicate_xy[2L, c("east_km", "north_km")] <-
    duplicate_xy[1L, c("east_km", "north_km")]
  column_mesh <- make_mesh(
    duplicate_xy, c("east_km", "north_km"),
    mesh = fx$mesh$mesh, id_col = "trait"
  )
  expect_error(
    .fit_spatial_column(
      fx, value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh)
    ),
    "unique coordinate pair"
  )
})

test_that("spatial_slope is Gaussian long-format only", {
  skip_if_not_installed("fmesher")
  fx <- .spatial_column_fixture(seed = 1305L)
  fx$data$value <- stats::rpois(nrow(fx$data), lambda = 2)
  column_mesh <- fx$mesh
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + spatial_slope(x | trait, mesh = column_mesh),
      data = fx$data, trait = "trait", unit = "unit", family = poisson()
    )),
    "Gaussian-only"
  )
})

test_that("spatial_slope recovers a small known Gaussian matrix-normal DGP", {
  skip_if_not_installed("fmesher")
  set.seed(1306L)
  locations <- expand.grid(
    east_km = 0:4,
    north_km = 0:4,
    KEEP.OUT.ATTRS = FALSE
  )
  locations$trait <- paste0("t", seq_len(nrow(locations)))
  locations <- locations[c("trait", "east_km", "north_km")]
  column_mesh <- make_mesh(
    locations, c("east_km", "north_km"), cutoff = 0.18,
    id_col = "trait"
  )
  range_true <- 2.4
  kappa_true <- sqrt(8) / range_true
  K_true <- .projected_spde_correlation(
    column_mesh, kappa_true, locations$trait
  )
  Sigma_true <- matrix(c(0.36, 0.09, 0.09, 0.16), 2L, 2L)
  B <- t(chol(K_true)) %*% matrix(stats::rnorm(50L), 25L, 2L) %*%
    chol(Sigma_true)

  dat <- expand.grid(
    unit = factor(paste0("u", seq_len(32L))),
    trait = factor(locations$trait, levels = locations$trait),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$x <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  trait_index <- as.integer(dat$trait)
  dat$value <- 0.08 * trait_index +
    dat$x * B[trait_index, 1L] + dat$z * B[trait_index, 2L] +
    stats::rnorm(nrow(dat), sd = 0.12)
  fx <- list(data = dat, locations = locations, mesh = column_mesh)

  fit <- .fit_spatial_column(
    fx,
    value ~ 0 + trait + spatial_slope(x + z | trait, mesh = column_mesh)
  )
  ext <- extract_Sigma(fit, level = "column_slope")
  variance_ratio <- diag(ext$Sigma) / diag(Sigma_true)
  range_ratio <- ext$source$practical_range / range_true

  expect_true(all(variance_ratio > 0.2 & variance_ratio < 5))
  expect_gt(ext$Sigma[1L, 2L], 0)
  expect_true(range_ratio > 0.25 && range_ratio < 4)
  expect_equal(diag(ext$source$K_column), rep(1, 25L))
})
