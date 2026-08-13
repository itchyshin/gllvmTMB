## Private Gate-B spatial iSDM smoke fixture: smallest admissible family.
## Paper 1: S = 3, C = 360, r = 3.  It is not a recovery panel or a
## scalability experiment.

## Fresh replacement attempt identifier. This differs from the consumed 86201
## root but keeps the approved Paper-1 DGP constants unchanged.
spatial_isdm_gate_b_seed <- 86202L

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
      bias_Sigma = tcrossprod(tr$gamma_bias_field),
      field_draw_seeds = c(ecological = seed + 1L, gbif_bias = seed + 2L),
      constants = tr
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

spatial_isdm_gate_b_required_ledger_fields <- function() c(
  "schema", "attempt_id", "status", "terminal", "started_at", "finished_at",
  "raw_starts", "selected_fit", "fit_error", "objective", "optimizer_code",
  "gradient", "gradient_by_block", "pd_hessian", "boundary_flags", "warnings",
  "source_map", "field_outputs", "versions", "timing", "peak_rss_kb"
)

spatial_isdm_gate_b_new_ledger <- function(attempt_id, source_map, versions) {
  list(
    schema = "SPATIAL_ISDM_GATE_B2_ALL_ATTEMPT_V1",
    attempt_id = attempt_id, status = "ATTEMPT_STARTED", terminal = FALSE,
    started_at = as.character(Sys.time()), finished_at = NA_character_,
    raw_starts = list(n_init = 1L, init_jitter = 0), selected_fit = NA_integer_,
    fit_error = NA_character_, objective = NA_real_, optimizer_code = NA_integer_,
    gradient = numeric(), gradient_by_block = list(), pd_hessian = NA,
    boundary_flags = character(), warnings = character(), source_map = source_map,
    field_outputs = list(ecological = NULL, gbif_bias = NULL, kappa = NA_real_),
    versions = versions, timing = list(fit_elapsed_s = NA_real_), peak_rss_kb = NA_real_
  )
}

spatial_isdm_gate_b_validate_terminal_ledger <- function(ledger) {
  required <- spatial_isdm_gate_b_required_ledger_fields()
  if (!is.list(ledger) || !identical(names(ledger), required) || !isTRUE(ledger$terminal) ||
      !ledger$status %in% c("FIT_RETURNED", "FIT_ERROR", "RUNNER_ERROR", "INTERRUPTED") ||
      !is.character(ledger$attempt_id) || length(ledger$attempt_id) != 1L ||
      !is.list(ledger$raw_starts) || !is.list(ledger$source_map) ||
      !is.list(ledger$field_outputs) || !is.list(ledger$versions) || !is.list(ledger$timing)) {
    stop("invalid terminal spatial iSDM all-attempt ledger", call. = FALSE)
  }
  invisible(TRUE)
}
