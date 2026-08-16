## Rung-1 P3CA/Rphylopars head-to-head -- G2 FULL GRID (approved shape).
## Sources dev/missing-accuracy-rung1-phylo-h2h.R for the DGP/mask/arm
## helpers (its own __main__ block is gated behind P3CA_RUN_PRERUN and is
## unaffected by sourcing here).
##
## Design: 6 cells x 10 seeds. Two run modes, selected by env var so the
## cheap 3-arm grid (foreground) and the expensive Rphylopars cameo
## (background) can run as separate processes without colliding on one CSV:
##   RUN_FAST_GRID=1        -> gllvmTMB-primary, gllvmTMB-lean, p3ca_reimpl,
##                              all 6 cells x 10 seeds (60 x 3 = 180 fits).
##   RUN_RPHYLOPARS_CAMEO=1 -> Rphylopars only, first 2 seeds/cell (12 fits),
##                              600s cap per fit, labelled a SUBSET.

suppressPackageStartupMessages({
  library(gllvmTMB); library(ape); library(phytools); library(Rphylopars)
})
source("dev/missing-accuracy-rung1-phylo-h2h.R")

n <- 50L; p <- 25L; q <- 3L

cells <- list(
  list(id = 1L, label = "DGP-a lambda=0.6 MCAR5",   dgp = "a", lambda = 0.6,  mech = "mcar"),
  list(id = 2L, label = "DGP-a lambda=0.6 clade",    dgp = "a", lambda = 0.6,  mech = "clade"),
  list(id = 3L, label = "DGP-a lambda=0.98 MCAR5",  dgp = "a", lambda = 0.98, mech = "mcar"),
  list(id = 4L, label = "DGP-a lambda=0.98 clade",   dgp = "a", lambda = 0.98, mech = "clade"),
  list(id = 5L, label = "DGP-b MCAR5",                dgp = "b", lambda = NA,   mech = "mcar"),
  list(id = 6L, label = "DGP-b clade",                dgp = "b", lambda = NA,   mech = "clade")
)
seeds_for_cell <- function(cell_id) 1000L * cell_id + seq_len(10L)

build_replicate <- function(cell, seed) {
  tree <- phytools::pbtree(n = n, seed = seed)
  tree$tip.label <- paste0("sp", seq_len(n))
  dgp <- if (cell$dgp == "a") {
    simulate_dgp_a(tree, p = p, q_true = q, lambda_true = cell$lambda, seed = seed)
  } else {
    simulate_dgp_b(tree, p = p, q_true = q, seed = seed)
  }
  mask <- if (cell$mech == "mcar") {
    mask_mcar05(n, p, seed = seed)
  } else {
    mask_clade(tree, p, seed = seed)
  }
  Y_masked <- dgp$Y; Y_masked[mask] <- NA
  list(tree = tree, dgp = dgp, mask = mask, Y_masked = Y_masked, Y_true = dgp$Y)
}

row_from_arm <- function(cell, seed, arm, out) {
  data.frame(
    cell = cell$label, dgp = cell$dgp, lambda_target = cell$lambda,
    mechanism = cell$mech, seed = seed, arm = arm,
    mse = out$mse, error = ifelse(is.na(out$error), "", out$error),
    wall_s = out$wall_s, n_joined = out$n_joined,
    lambda_hat = if (!is.null(out$lambda_hat)) out$lambda_hat else NA_real_,
    stringsAsFactors = FALSE
  )
}

append_row <- function(row, path) {
  write.table(row, path, sep = ",", row.names = FALSE,
              col.names = !file.exists(path), append = file.exists(path))
}

## ===========================================================================
## FAST GRID: 3 arms x 6 cells x 10 seeds, foreground.
## ===========================================================================
if (identical(Sys.getenv("RUN_FAST_GRID"), "1")) {
  out_csv <- "dev/missing-accuracy/rung1-cells-fastgrid.csv"
  if (file.exists(out_csv)) file.remove(out_csv)
  t_start <- Sys.time()
  for (cell in cells) {
    for (seed in seeds_for_cell(cell$id)) {
      rep_data <- build_replicate(cell, seed)
      a1 <- run_arm_gllvmTMB(rep_data$Y_masked, rep_data$tree, unique_flag = TRUE,
                              rep_data$mask, rep_data$Y_true)
      append_row(row_from_arm(cell, seed, "gllvmTMB-primary", a1), out_csv)
      a2 <- run_arm_gllvmTMB(rep_data$Y_masked, rep_data$tree, unique_flag = FALSE,
                              rep_data$mask, rep_data$Y_true)
      append_row(row_from_arm(cell, seed, "gllvmTMB-lean (misspecified-lean)", a2), out_csv)
      a3 <- run_arm_p3ca(rep_data$Y_masked, rep_data$dgp$C_base, rep_data$mask, rep_data$Y_true)
      append_row(row_from_arm(cell, seed, "p3ca_reimpl", a3), out_csv)
      cat(sprintf("[%s] seed=%d  primary=%.4f(%.2fs) lean=%.4f(%.2fs) p3ca=%.4f(%.2fs)\n",
                   cell$label, seed, a1$mse, a1$wall_s, a2$mse, a2$wall_s, a3$mse, a3$wall_s))
    }
  }
  cat("FAST GRID DONE in", as.numeric(Sys.time() - t_start, units = "secs"), "s\n")
}

## ===========================================================================
## RPHYLOPARS CAMEO: first 2 seeds/cell, 12 fits, 600s cap, background.
## ===========================================================================
if (identical(Sys.getenv("RUN_RPHYLOPARS_CAMEO"), "1")) {
  out_csv <- "dev/missing-accuracy/rung1-cells-cameo.csv"
  if (file.exists(out_csv)) file.remove(out_csv)
  t_start <- Sys.time()
  for (cell in cells) {
    for (seed in seeds_for_cell(cell$id)[1:2]) {
      rep_data <- build_replicate(cell, seed)
      a4 <- run_arm_rphylopars(rep_data$Y_masked, rep_data$tree, rep_data$mask, rep_data$Y_true)
      append_row(row_from_arm(cell, seed, "Rphylopars (cameo subset, n=2 seeds/cell)", a4), out_csv)
      cat(sprintf("[%s] seed=%d  rphylopars=%.4f(%.2fs) err=%s\n",
                   cell$label, seed, a4$mse, a4$wall_s, a4$error))
    }
  }
  cat("RPHYLOPARS CAMEO DONE in", as.numeric(Sys.time() - t_start, units = "secs"), "s\n")
}
