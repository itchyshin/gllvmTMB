## Domain-growth campaign (design Amendment A2) -- stage 3: build per-level
## geometry bundles through the sealed lineage's own developer entry point
## (.gll_isdm_fit), gated by an anchor rebuild that must reproduce the sealed
## objective at the sealed theta to < 1e-6.
## Usage: Rscript 3_build_geometry.R <out_dir> [scales...]   (default 1 1.5 2 2.5)
suppressMessages({library(Matrix)})

args <- commandArgs(trailingOnly = TRUE)
out_dir <- args[1]
scales <- if (length(args) > 1) as.numeric(args[-1]) else c(1, 1.5, 2, 2.5)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

QFIXED <- "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde"
V2 <- file.path(QFIXED, "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V2")
V3 <- file.path(QFIXED, "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3")
suppressMessages(devtools::load_all(QFIXED, quiet = TRUE))   # sealed R-side + DLL lineage

ctrl <- readRDS(file.path(V2, "control.rds"))
fx   <- readRDS(file.path(V2, "fixture.rds"))
s3   <- readRDS(file.path(V3, "v2-materialized-state.rds"))
K    <- fx$truth$constants
KAPPA <- unname(fx$truth$kappa)          # fixed range 0.22 across ALL levels

fast_ctrl <- ctrl
fast_ctrl$optArgs$control <- list(iter.max = 3, eval.max = 6)  # template builds only
fast_ctrl$se <- FALSE
fast_ctrl$.internal_continuation <- NULL

build_model <- function(rows, X, B, mesh, control) {
  gllvmTMB:::.gll_isdm_fit(rows = rows, X = X, B = B, d = 1L,
    control = control, mesh = mesh, spatial = TRUE, silent = TRUE)
}

## ---------- ANCHOR GATE: sealed rows/X/B must reproduce the sealed objective
cat("=== anchor rebuild gate ===\n")
mesh0 <- make_mesh(fx$mesh_data, c("lon", "lat"), cutoff = K$mesh_cutoff)
rows0 <- fx$rows; rows0$value <- readRDS(file.path(V2, "fit.rds"))$data$value
fit0  <- build_model(rows0, fx$X, fx$B, mesh0, fast_ctrl)
th    <- unname(s3$theta)
g_obj <- abs(fit0$tmb_obj$fn(th) - s3$objective)
cat(sprintf("  objective at sealed theta: diff %.3e\n", g_obj))
stopifnot(length(fit0$tmb_obj$par) == 22, g_obj < 1e-6)
cat("  ANCHOR GATE PASSED\n")

## anchor discrete normalisation target (exact)
rep0 <- which(rows0$source == "gbif" & rows0$trait == names(K$alpha)[1])
A_cells0 <- fit0$mesh$A_st[rep0, ]
M0 <- fit0$tmb_data$spde_M0; M1 <- fit0$tmb_data$spde_M1; M2 <- fit0$tmb_data$spde_M2
Qa <- KAPPA^4 * M0 + 2 * KAPPA^2 * M1 + M2
sd_cell0 <- sqrt(mean(rowSums((A_cells0 %*% chol2inv(chol(as.matrix(Qa)))) * A_cells0)))
target_sd <- sqrt(4 * pi) * KAPPA * sd_cell0
cat(sprintf("  anchor target_SD = %.6f (nodes %d)\n", target_sd, nrow(M0)))

## ---------- per-level skeleton: the sealed recipe, scaled ----------
skeleton_s <- function(s) {
  n_lon <- as.integer(round(20 * s)); n_lat <- as.integer(round(18 * s))
  grid <- expand.grid(lon = seq(0, s, length.out = n_lon),
                      lat = seq(0, s, length.out = n_lat))
  grid <- grid[order(grid$lat, grid$lon), , drop = FALSE]; rownames(grid) <- NULL
  n_cell <- nrow(grid)
  species <- names(K$alpha); cells <- paste0("cell_", seq_len(n_cell))
  x <- as.numeric(scale(grid$lon))
  b <- as.numeric(scale(sin(2 * pi * grid$lat) + 0.35 * cos(2 * pi * grid$lon)))
  a_g <- exp(seq(log(0.8), log(2.0), length.out = n_cell))
  a_s <- exp(seq(log(0.6), log(1.4), length.out = n_cell))
  base <- expand.grid(cell_id = cells, trait = species,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  base <- base[order(match(base$cell_id, cells), match(base$trait, species)), , drop = FALSE]
  rownames(base) <- NULL
  ci <- match(base$cell_id, cells)
  gbif <- transform(base, source = "gbif", survey_event_id = NA_character_,
    branch = "count", support = a_g[ci], lon = grid$lon[ci], lat = grid$lat[ci],
    value = NA_integer_, visit = NA_integer_)
  pa <- lapply(1:3, function(v) transform(base, source = "survey",
    survey_event_id = paste0("pa_v", v, "_", base$cell_id), branch = "pa",
    support = a_s[ci], lon = grid$lon[ci], lat = grid$lat[ci],
    value = NA_integer_, visit = as.integer(v)))
  rows <- do.call(rbind, c(list(gbif), pa)); rownames(rows) <- NULL
  rci <- as.integer(match(rows$cell_id, cells))
  list(rows = rows, n_cell = n_cell, cells = cells, x = x, b = b,
       X = matrix(x[rci], ncol = 1L, dimnames = list(NULL, "env")),
       B = matrix(ifelse(rows$source == "gbif", b[rci], NA_real_),
                  ncol = 1L, dimnames = list(NULL, "bias")),
       mesh_data = rows[, c("lon", "lat")],
       cellIx = rci, spIx = as.integer(match(rows$trait, species)))
}

for (s in scales) {
  cat(sprintf("=== level s=%.2f ===\n", s))
  sk <- skeleton_s(s)
  set.seed(1L)
  sk$rows$value <- ifelse(sk$rows$source == "gbif",
                          rpois(nrow(sk$rows), 1L), rbinom(nrow(sk$rows), 1L, 0.5))
  mesh_s <- make_mesh(sk$mesh_data, c("lon", "lat"), cutoff = K$mesh_cutoff)
  tfit <- build_model(sk$rows, sk$X, sk$B, mesh_s, fast_ctrl)
  stopifnot(identical(as.double(tfit$tmb_data$y), as.double(sk$rows$value)))  # row map gate
  M0s <- tfit$tmb_data$spde_M0; M1s <- tfit$tmb_data$spde_M1; M2s <- tfit$tmb_data$spde_M2
  rep_s <- which(sk$rows$source == "gbif" & sk$rows$trait == names(K$alpha)[1])
  A_cells <- tfit$mesh$A_st[rep_s, ]
  Qs <- KAPPA^4 * M0s + 2 * KAPPA^2 * M1s + M2s
  chol_s <- chol(as.matrix(Qs))
  sd_cell <- sqrt(mean(rowSums((A_cells %*% chol2inv(chol_s)) * A_cells)))
  c_use <- target_sd / sd_cell
  cat(sprintf("  cells %d  nodes %d  sd_cell %.5f  c_use %.3f\n",
      sk$n_cell, nrow(M0s), sd_cell, c_use))
  bundle <- list(
    schema = "PAPER1_DOMAIN_GROWTH_A2_BUNDLE_V1", scale = s,
    n_cell = sk$n_cell, n_nodes = nrow(M0s),
    data = tfit$tmb_data, parameters = tfit$tmb_params, map = tfit$tmb_map,
    random = tfit$random, chol_q = chol_s, A_cells = A_cells,  # keep SPARSE (A3: ~1 GB dense at s=7.5)
    c_use = c_use, constants = K, x_cell = sk$x, b_cell = sk$b,
    cellIx = sk$cellIx, spIx = sk$spIx,
    gbif = sk$rows$source == "gbif", support = sk$rows$support,
    gamma_row = unname(K$gbif_fixed_bias[as.character(sk$rows$trait)]),
    truth = list(lambda_bias = c_use * unname(K$v_bias),
                 q = log(KAPPA), gamma = unname(K$gbif_fixed_bias),
                 target_sd = target_sd),
    n_par = length(tfit$tmb_obj$par))
  saveRDS(bundle, file.path(out_dir, sprintf("bundle_s%s.rds", format(s))))
  cat(sprintf("  bundle written: bundle_s%s.rds  ||lam_bias(s)|| = %.3f  n_par %d\n",
      format(s), sqrt(sum(bundle$truth$lambda_bias^2)), bundle$n_par))
}
cat("done\n")
