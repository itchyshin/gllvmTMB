## Private Gate-B spatial iSDM smoke fixture: smallest admissible family.
## Paper 1: S = 3, C = 360, r = 3.  It is not a recovery panel or a
## scalability experiment.

spatial_isdm_gate_b_seed <- 86201L

spatial_isdm_gate_b_constants <- function() {
  list(
    alpha = c(sp1 = -1.40, sp2 = -1.15, sp3 = -1.55),
    beta = c(sp1 = -0.45, sp2 = 0.35, sp3 = 0.60),
    lambda_ecological = c(sp1 = 0.70, sp2 = -0.55, sp3 = 0.45),
    gamma_bias_field = c(sp1 = 0.45, sp2 = -0.35, sp3 = 0.30),
    psi_sd = c(sp1 = 0.35, sp2 = 0.30, sp3 = 0.40),
    gbif_fixed_bias = c(sp1 = 0.30, sp2 = -0.20, sp3 = 0.15),
    field_range = 0.22,
    field_sd = 0.55,
    ## The augmented spatial_latent engine has independent intercept and
    ## isdm_gbif field columns; their DGP must match that zero cross-field
    ## correlation for any future recovery claim.
    field_correlation = 0,
    mesh_cutoff = 0.085
  )
}

.spatial_isdm_gate_b_field <- function(coords, range, sd, seed) {
  set.seed(seed)
  distance <- as.matrix(stats::dist(coords))
  covariance <- sd^2 * exp(-distance / range) + diag(1e-8, nrow(coords))
  as.numeric(t(chol(covariance)) %*% stats::rnorm(nrow(coords)))
}

spatial_isdm_gate_b_make_fixture <- function(seed = spatial_isdm_gate_b_seed) {
  stopifnot(identical(as.integer(seed), spatial_isdm_gate_b_seed))
  tr <- spatial_isdm_gate_b_constants()
  grid <- expand.grid(lon = seq(0, 1, length.out = 20L), lat = seq(0, 1, length.out = 18L))
  grid <- grid[order(grid$lat, grid$lon), , drop = FALSE]
  rownames(grid) <- NULL
  n_cell <- nrow(grid)
  species <- names(tr$alpha)
  cells <- paste0("cell_", seq_len(n_cell))
  coords <- as.matrix(grid[, c("lon", "lat")])
  x <- as.numeric(scale(grid$lon))
  b <- as.numeric(scale(sin(2 * pi * grid$lat) + 0.35 * cos(2 * pi * grid$lon)))
  u <- .spatial_isdm_gate_b_field(coords, tr$field_range, tr$field_sd, seed + 1L)
  h_independent <- .spatial_isdm_gate_b_field(coords, tr$field_range, tr$field_sd, seed + 2L)
  h <- tr$field_correlation * u + sqrt(1 - tr$field_correlation^2) * h_independent
  set.seed(seed + 3L)
  eps <- sapply(tr$psi_sd, function(sd) stats::rnorm(n_cell, sd = sd))
  eta_ecological <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") +
    outer(u, tr$lambda_ecological) + eps
  eta_gbif_field <- outer(h, tr$gamma_bias_field)
  a_g <- exp(seq(log(0.8), log(2.0), length.out = n_cell))
  a_s <- exp(seq(log(0.6), log(1.4), length.out = n_cell))
  base <- expand.grid(cell_id = cells, trait = species,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  base <- base[order(match(base$cell_id, cells), match(base$trait, species)), , drop = FALSE]
  cell_index <- match(base$cell_id, cells)
  trait_index <- match(base$trait, species)
  eta_e <- eta_ecological[cbind(cell_index, trait_index)]
  eta_h <- eta_gbif_field[cbind(cell_index, trait_index)]
  eta_fixed_bias <- b[cell_index] * unname(tr$gbif_fixed_bias[base$trait])
  gbif <- transform(base,
    source = "gbif", survey_event_id = NA_character_, branch = "count",
    support = a_g[cell_index], lon = grid$lon[cell_index], lat = grid$lat[cell_index],
    value = stats::rpois(nrow(base), a_g[cell_index] * exp(eta_e + eta_fixed_bias + eta_h)),
    visit = NA_integer_
  )
  pa <- lapply(seq_len(3L), function(v) transform(base,
    source = "survey", survey_event_id = paste0("pa_v", v, "_", cell_id), branch = "pa",
    support = a_s[cell_index], lon = grid$lon[cell_index], lat = grid$lat[cell_index],
    value = stats::rbinom(nrow(base), 1L, -expm1(-a_s[cell_index] * exp(eta_e))), visit = v
  ))
  rows <- do.call(rbind, c(list(gbif), pa))
  row_cell <- match(rows$cell_id, cells)
  row_trait <- match(rows$trait, species)
  list(
    rows = rows,
    X = matrix(x[row_cell], ncol = 1L, dimnames = list(NULL, "env")),
    B = matrix(ifelse(rows$source == "gbif", b[row_cell], NA_real_), ncol = 1L,
               dimnames = list(NULL, "bias")),
    mesh_data = rows[, c("lon", "lat")],
    truth = list(
      seed = seed, n_cell = n_cell, n_species = length(species), n_visit = 3L,
      cells = cells, species = species, coordinates = grid, x = x, b = b,
      ecological_field = u, gbif_bias_field = h, eta_ecological = eta_ecological,
      eta_gbif_field = eta_gbif_field, psi_variance = tr$psi_sd^2,
      shared_Sigma = tcrossprod(tr$lambda_ecological),
      bias_Sigma = tcrossprod(tr$gamma_bias_field), constants = tr
    )
  )
}

spatial_isdm_gate_b_validate_fixture <- function(fixture, mesh) {
  rows <- fixture$rows
  truth <- fixture$truth
  survey <- rows$source == "survey"
  stopifnot(
    identical(truth$seed, spatial_isdm_gate_b_seed),
    identical(truth$n_cell, 360L), identical(truth$n_species, 3L),
    identical(truth$n_visit, 3L), nrow(rows) == 4320L,
    all(rows$branch[survey] == "pa"), all(rows$branch[!survey] == "count"),
    all(is.na(fixture$B[survey, 1L])), all(is.finite(fixture$B[!survey, 1L])),
    all(table(rows$cell_id[survey], rows$trait[survey]) == 3L),
    nrow(mesh$A_st) == nrow(rows), ncol(mesh$A_st) > 2L,
    isTRUE(all.equal(truth$constants$field_range, 0.22)),
    isTRUE(all.equal(truth$constants$field_correlation, 0))
  )
  invisible(TRUE)
}
