## Frontier campaign -- stage 0: build the inputs bundle from the sealed roots.
## Read-only on all sealed roots. The bundle is derived data (gitignored);
## this script is the committed, reproducible path to it.
## Design: dev/isdm-package-recovery/2026-08-15-paper1-gbif-effort-frontier-campaign-design.md
suppressMessages(library(Matrix))

QFIXED <- "/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde"
V3 <- file.path(QFIXED, "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3")
V2 <- file.path(QFIXED, "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V2")
out_dir <- Sys.getenv("FRONTIER_OUT", "/private/tmp/gllvmtmb-isdm-range-amplitude-chart/dev/isdm-package-recovery/results/frontier")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

s  <- readRDS(file.path(V3, "v2-materialized-state.rds"))
fx <- readRDS(file.path(V2, "fixture.rds"))
tr <- fx$truth; rows <- fx$rows; d <- s$data

## ---- validation gates: the redraw machinery must reproduce the sealed fields
chol_q <- chol(as.matrix(tr$Q))
node_draw <- function(seed) {
  set.seed(seed)
  as.double(backsolve(chol_q, rnorm(nrow(chol_q))))
}
g1a <- max(abs(node_draw(tr$draw_seeds[["ecological_field"]]) - unname(tr$node_field_ecological)))
g1b <- max(abs(node_draw(tr$draw_seeds[["bias_field"]])       - unname(tr$node_field_bias)))
cat(sprintf("G1 node-field redraw: eco %.2e  bias %.2e\n", g1a, g1b))
stopifnot(g1a < 1e-10, g1b < 1e-10)

set.seed(tr$draw_seeds[["trait_residual"]])
res_re <- sapply(tr$constants$psi_sd, function(sd) rnorm(length(tr$cells), sd = sd))
g2 <- max(abs(res_re - unname(tr$trait_residual)))
cat(sprintf("G2 trait-residual redraw: %.2e\n", g2)); stopifnot(g2 < 1e-10)

unit_eco <- tr$c_ref * as.double(as.matrix(tr$A_unique) %*% unname(tr$node_field_ecological))
eta_re <- sweep(outer(tr$x, tr$constants$beta), 2L, tr$constants$alpha, "+") +
  outer(unit_eco, tr$constants$v_ecological) + unname(tr$trait_residual)
g3 <- max(abs(eta_re - unname(tr$eta_ecological)))
cat(sprintf("G3 eta reconstruction: %.2e\n", g3)); stopifnot(g3 < 1e-10)

cellIx <- match(rows$cell, tr$cells); spIx <- match(rows$trait, tr$species)
gbif <- rows$source == "gbif"
stopifnot(identical(which(gbif), which(d$Z_spde_lat[, 2] == 1)))

bundle <- list(
  schema = "PAPER1_GBIF_EFFORT_FRONTIER_V1_BUNDLE_V1",
  data = d, parameters = s$parameters, map = s$map, random = s$random,
  chol_q = chol_q, A_unique = as.matrix(tr$A_unique), c_ref = tr$c_ref,
  constants = tr$constants, x_cell = tr$x, b_cell = tr$b,
  n_cells = length(tr$cells), cellIx = cellIx, spIx = spIx, gbif = gbif,
  support = rows$support, gamma_row = unname(tr$constants$gbif_fixed_bias[rows$trait]),
  truth = list(lambda_bias = unname(tr$lambda_bias),
               lambda_eco = unname(tr$lambda_ecological),
               q = unname(tr$q), gamma = unname(tr$constants$gbif_fixed_bias)),
  provenance = list(
    state_md5   = unname(tools::md5sum(file.path(V3, "v2-materialized-state.rds"))),
    fixture_md5 = unname(tools::md5sum(file.path(V2, "fixture.rds"))),
    cpp_md5     = unname(tools::md5sum(file.path(QFIXED, "src", "gllvmTMB.cpp"))),
    built = "2026-08-15", gates = c(g1a = g1a, g1b = g1b, g2 = g2, g3 = g3))
)
saveRDS(bundle, file.path(out_dir, "bundle.rds"))
cat("bundle written:", file.path(out_dir, "bundle.rds"), "\n")
cat("provenance:", paste(names(bundle$provenance)[1:3],
    unlist(bundle$provenance[1:3]), collapse = "  "), "\n")
