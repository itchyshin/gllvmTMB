#!/usr/bin/env Rscript
## ADEMP coverage campaign — rank-2 (K_B=2) Gaussian Model A, B_lv = Lambda_B alpha^T.
## Extends the certified rank-1 Model A (LV-09) to the rank-2 hard cell.
## Corrected vs dev/lv-effects-ci-coverage.R for the current package:
##   - profile via gllvmTMB:::profile_ci_lv_effects (internal) with reference="chisq"
##     (B_lv has NO auto t-df; chisq is the hero). t-df sensitivity (df=S-d-1) recorded too.
##   - Wald natural-scale delta-SE recorded as the interior fallback.
## One seed per SLURM array task (Totoro/DRAC). Smoke locally, scale on Totoro (>=500/cell).
## Usage: Rscript modelA-rank2-coverage.R run <cell_id> <task_id> <reps>
##        Rscript modelA-rank2-coverage.R summarise <results_dir>
suppressMessages({ library(gllvmTMB); library(ape) })

CELLS <- list(
  `gauss-S200-K2-hard` = list(S = 200L, T = 8L, K_B = 2L, K_phy = 1L, lambda = 0.5),
  `gauss-S120-K2-smoke`= list(S = 120L, T = 6L, K_B = 2L, K_phy = 1L, lambda = 0.6)
)

make_truth <- function(cell, design_seed = 20260716L) {
  set.seed(design_seed)
  S <- cell$S; T <- cell$T; K_B <- cell$K_B
  tree <- ape::rcoal(S); tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A))
  LambdaB <- matrix(stats::runif(T * K_B, -1, 1), T, K_B)
  LambdaB[upper.tri(LambdaB)] <- 0; diag(LambdaB) <- abs(diag(LambdaB)) + 0.3
  alpha <- matrix(stats::runif(K_B, 0.5, 1.0), 1L, K_B)
  LambdaPhy <- matrix(stats::runif(T * cell$K_phy, -1, 1) * sqrt(cell$lambda), T, cell$K_phy)
  beta <- stats::rnorm(T, 0, 0.5); x <- stats::rnorm(S)
  list(tree = tree, LA = LA, LambdaB = LambdaB, alpha = alpha, LambdaPhy = LambdaPhy,
       beta = beta, x = x, B_lv = LambdaB %*% t(alpha), S = S, T = T, K_B = K_B, K_phy = cell$K_phy)
}

one_rep <- function(tr, seed) {
  set.seed(seed)
  S <- tr$S; T <- tr$T; K_B <- tr$K_B; d_phy <- tr$K_phy; tree <- tr$tree
  zB <- matrix(tr$x, S, 1) %*% tr$alpha + matrix(stats::rnorm(S * K_B), S, K_B)
  gphy <- tr$LA %*% matrix(stats::rnorm(S * d_phy), S, d_phy)
  eta <- matrix(tr$beta, S, T, byrow = TRUE) + zB %*% t(tr$LambdaB) + gphy %*% t(tr$LambdaPhy)
  y <- eta + matrix(stats::rnorm(S * T, 0, 0.5), S, T)
  df <- data.frame(species = factor(rep(tree$tip.label, times = T), levels = tree$tip.label),
    trait = factor(rep(paste0("t", seq_len(T)), each = S)), value = as.vector(y), x = rep(tr$x, times = T))
  d_B <- K_B
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = d_B, lv = ~x) +
      phylo_latent(0 + trait | species, d = d_phy, tree = tree),
    data = df, unit = "species", trait = "trait", family = gaussian(), REML = TRUE,
    control = gllvmTMBcontrol(se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS"))))),
    error = function(e) NULL)
  ## target B_lv[trait=1, predictor=1]; rotation-invariant population quantity
  truth <- tr$B_lv[1, 1]
  base <- data.frame(seed = seed, truth = truth, converged = FALSE,
    wald_lo = NA_real_, wald_hi = NA_real_, wald_cov = NA,
    prof_lo = NA_real_, prof_hi = NA_real_, prof_cov = NA,
    tdf_lo = NA_real_, tdf_hi = NA_real_, tdf_cov = NA)
  if (is.null(fit) || !isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$sd_report$pdHess)) return(base)
  base$converged <- TRUE
  eff <- tryCatch(extract_lv_effects(fit, type = "trait_effect"), error = function(e) NULL)
  if (!is.null(eff)) {
    r <- which(matrix(seq_len(nrow(eff)), nrow = fit$n_traits)[1, ] == 1L)[1]  # trait1,pred1 row
    base$wald_lo <- eff$lower[1]; base$wald_hi <- eff$upper[1]
    base$wald_cov <- eff$lower[1] <= truth && truth <= eff$upper[1]
  }
  pc <- tryCatch(gllvmTMB:::profile_ci_lv_effects(fit, trait = 1, predictor = 1, reference = "chisq"),
                 error = function(e) NULL)
  if (!is.null(pc) && is.finite(pc$lower) && is.finite(pc$upper)) {
    base$prof_lo <- pc$lower; base$prof_hi <- pc$upper
    base$prof_cov <- pc$lower <= truth && truth <= pc$upper
  }
  pt <- tryCatch(gllvmTMB:::profile_ci_lv_effects(fit, trait = 1, predictor = 1,
                   reference = "t", df = tr$S - tr$K_B - 1L), error = function(e) NULL)
  if (!is.null(pt) && is.finite(pt$lower) && is.finite(pt$upper)) {
    base$tdf_lo <- pt$lower; base$tdf_hi <- pt$upper
    base$tdf_cov <- pt$lower <= truth && truth <= pt$upper
  }
  base
}

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1L) args[[1]] else "run"
if (identical(mode, "run")) {
  cell_id <- args[[2]]; task_id <- as.integer(args[[3]])
  reps <- if (length(args) >= 4L) as.integer(args[[4]]) else 5L
  stopifnot(cell_id %in% names(CELLS))
  tr <- make_truth(CELLS[[cell_id]]); seed_base <- 10000L * task_id
  rows <- do.call(rbind, lapply(seq_len(reps), function(i) one_rep(tr, seed_base + i)))
  rows$cell_id <- cell_id; rows$task_id <- task_id
  outdir <- file.path("results", "modelA-rank2-coverage", cell_id)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(outdir, sprintf("task-%05d.csv", task_id)), row.names = FALSE)
  writeLines(capture.output(utils::sessionInfo()), file.path(outdir, sprintf("task-%05d.sessionInfo.txt", task_id)))
  cat(sprintf("[%s task %d] %d reps: converged=%d prof_ci=%d\n", cell_id, task_id, nrow(rows),
    sum(rows$converged), sum(!is.na(rows$prof_cov))))
} else if (identical(mode, "summarise")) {
  cells <- list.dirs(args[[2]], recursive = FALSE)
  for (cd in cells) {
    files <- list.files(cd, pattern = "^task-.*\\.csv$", full.names = TRUE)
    if (!length(files)) next
    dat <- do.call(rbind, lapply(files, utils::read.csv))
    for (m in c("wald", "prof", "tdf")) {
      cc <- dat[[paste0(m, "_cov")]]; e <- cc[!is.na(cc)]
      cov <- mean(e); mcse <- sqrt(cov * (1 - cov) / length(e))
      cat(sprintf("%-22s %-5s n=%3d coverage=%.3f (MCSE %.4f) prod>=500:%s\n",
        basename(cd), m, length(e), cov, mcse, length(e) >= 500))
    }
  }
} else stop("mode must be 'run' or 'summarise'")
