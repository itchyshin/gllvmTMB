.make_spatial_coef_fixture <- function(seed = 13301L, n_unit = 16L,
                                       n_rep = 1L) {
  set.seed(seed)
  locations <- expand.grid(
    east_km = 0:2,
    north_km = 0:1,
    KEEP.OUT.ATTRS = FALSE
  )
  locations$trait <- paste0("plant_", sprintf("%02d", seq_len(nrow(locations))))
  locations$pathway <- factor(rep(c("C3", "C4"), each = 3L),
                              levels = c("C3", "C4"))
  locations <- locations[c("trait", "pathway", "east_km", "north_km")]
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
  dat$moisture <- stats::rnorm(nrow(dat))
  dat$z <- stats::rnorm(nrow(dat))
  trait_id <- as.integer(dat$trait)
  east <- scale(locations$east_km, scale = FALSE)[, 1L]
  north <- scale(locations$north_km, scale = FALSE)[, 1L]
  dat$value <- 0.2 + east[trait_id] * 0.22 +
    dat$moisture * north[trait_id] * -0.28 +
    dat$z * east[trait_id] * 0.12 + stats::rnorm(nrow(dat), sd = 0.32)
  list(data = dat, locations = locations, mesh = mesh)
}

.make_spatial_coef_wide_fixture <- function(seed = 13303L, n_unit = 18L) {
  set.seed(seed)
  locations <- expand.grid(
    east_km = 0:2,
    north_km = 0:1,
    KEEP.OUT.ATTRS = FALSE
  )
  locations$trait <- paste0("plant_", sprintf("%02d", seq_len(nrow(locations))))
  locations$pathway <- factor(rep(c("C3", "C4"), each = 3L),
                              levels = c("C3", "C4"))
  locations <- locations[c("trait", "pathway", "east_km", "north_km")]
  mesh <- make_mesh(
    locations, c("east_km", "north_km"), cutoff = 0.15,
    id_col = "trait"
  )
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(n_unit))),
    moisture = as.numeric(scale(seq_len(n_unit))),
    z = stats::rnorm(n_unit)
  )
  alpha_pathway <- c(C3 = 0.35, C4 = 0.70)
  beta_pathway <- c(C3 = -0.20, C4 = 0.25)
  alpha_dev <- as.numeric(scale(locations$east_km, scale = FALSE)) * 0.18
  beta_dev <- as.numeric(scale(locations$north_km, scale = FALSE)) * -0.22
  for (j in seq_len(nrow(locations))) {
    pathway <- as.character(locations$pathway[[j]])
    wide[[locations$trait[[j]]]] <-
      alpha_pathway[[pathway]] + alpha_dev[[j]] +
      (beta_pathway[[pathway]] + beta_dev[[j]]) * wide$moisture +
      stats::rnorm(n_unit, sd = 0.25)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(locations$trait),
    names_to = "trait", values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = locations$trait)
  list(
    long = long, wide = wide, locations = locations, mesh = mesh,
    column_data = locations[c("trait", "pathway")]
  )
}

.fit_spatial_coef <- function(fx, formula, data = fx$data, trait = "trait") {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula, data = data, trait = trait, unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
}

.spatial_coef_map_signature <- function(fit) {
  lapply(fit$tmb_obj$env$map, function(x) if (is.null(x)) NULL else as.integer(x))
}

.expect_spatial_endpoint_identical <- function(coef_fit, slope_fit) {
  expect_identical(coef_fit$tmb_data, slope_fit$tmb_data)
  expect_identical(coef_fit$tmb_obj$env$random, slope_fit$tmb_obj$env$random)
  expect_identical(names(coef_fit$opt$par), names(slope_fit$opt$par))
  expect_identical(.spatial_coef_map_signature(coef_fit),
                   .spatial_coef_map_signature(slope_fit))
  common <- slope_fit$opt$par
  expect_identical(coef_fit$tmb_obj$fn(common), slope_fit$tmb_obj$fn(common))
  expect_identical(coef_fit$tmb_obj$gr(common), slope_fit$tmb_obj$gr(common))
  expect_identical(coef_fit$opt$objective, slope_fit$opt$objective)
  expect_identical(coef_fit$opt$par, slope_fit$opt$par)
  expect_identical(coef_fit$report, slope_fit$report)
  expect_identical(suppressMessages(stats::fitted(coef_fit)),
                   suppressMessages(stats::fitted(slope_fit)))
}

.spatial_coef_projected_correlation <- function(mesh, kappa, labels) {
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
