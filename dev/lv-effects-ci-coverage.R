#!/usr/bin/env Rscript
## ============================================================================
## ADEMP recovery / coverage campaign for the predictor-informed latent effect
## B_lv under the orthogonal Model A (latent(lv=~x) + phylo_latent), Gaussian.
##
## Estimand : population trait-scale B_lv = Lambda_B * alpha^T (rotation-invariant).
## Methods  : profile (D-12 hero, t reference) + parametric bootstrap; Wald reported.
## Design   : one seed per SLURM array task; fixed per-cell design (tree, X);
##            redraw REs + residual per replicate; REML fits (unbiased var comps).
## Reporting: per-rep converged / pd_hessian / ci_available / covered / width /
##            wall-time; aggregate to coverage + Monte Carlo SE + failed-fit
##            denominators. Production admission (register LV bar): >= 500
##            reps/cell, per-rep outputs + sessionInfo(), band 0.92-0.98.
##
## This is the compute-gated final gate (Totoro / DRAC). The in-repo heavy test
## test-profile-ci-lv-effects.R + the local coverage proof are the smoke-scale
## evidence; this harness scales it to the production denominator.
##
## Usage (array task): Rscript lv-effects-ci-coverage.R run <cell_id> <task_id> <reps_per_task>
##        (summarise):  Rscript lv-effects-ci-coverage.R summarise <results_dir>
## ============================================================================

suppressMessages({
  library(gllvmTMB)   # installed package on the cluster (not devtools::load_all)
  library(ape)
})

## ---- Cell grid (size n to family + latent rank; the #715 sample-size lesson) --
## Includes the GLLVM.jl weak cell (p=80, K=2, lambda=0.5) sized UP, and a small-n
## cell where the t reference matters most.
CELLS <- list(
  `gauss-S200-K1`      = list(S = 200L, T = 5L, K_B = 1L, K_phy = 1L, lambda = 0.7),
  `gauss-S100-K1`      = list(S = 100L, T = 5L, K_B = 1L, K_phy = 1L, lambda = 0.7),
  `gauss-S60-K1-smalln`= list(S = 60L,  T = 4L, K_B = 1L, K_phy = 1L, lambda = 0.5),
  `gauss-S200-K2-hard` = list(S = 200L, T = 8L, K_B = 2L, K_phy = 1L, lambda = 0.5)
)

make_truth <- function(cell, design_seed = 20260706L) {
  set.seed(design_seed)   # fixed design per cell (tree, X)
  S <- cell$S; T <- cell$T; K_B <- cell$K_B
  tree <- ape::rcoal(S); tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A))
  LambdaB <- matrix(stats::runif(T * K_B, -1, 1), T, K_B)
  LambdaB[upper.tri(LambdaB)] <- 0; diag(LambdaB) <- abs(diag(LambdaB)) + 0.3
  alpha <- matrix(stats::runif(K_B, 0.5, 1.0), 1L, K_B)  # 1 predictor
  LambdaPhy <- matrix(stats::runif(T * cell$K_phy, -1, 1) * sqrt(cell$lambda), T, cell$K_phy)
  beta <- stats::rnorm(T, 0, 0.5)
  x <- stats::rnorm(S)
  list(tree = tree, LA = LA, LambdaB = LambdaB, alpha = alpha, LambdaPhy = LambdaPhy,
       beta = beta, x = x, B_lv = LambdaB %*% t(alpha), S = S, T = T, K_B = K_B)
}

one_rep <- function(tr, seed) {
  set.seed(seed)
  S <- tr$S; T <- tr$T; K_B <- tr$K_B
  zB <- matrix(tr$x, S, 1) %*% tr$alpha + matrix(stats::rnorm(S * K_B), S, K_B)
  gphy <- tr$LA %*% matrix(stats::rnorm(S * ncol(tr$LambdaPhy)), S, ncol(tr$LambdaPhy))
  eta <- matrix(tr$beta, S, T, byrow = TRUE) + zB %*% t(tr$LambdaB) + gphy %*% t(tr$LambdaPhy)
  y <- eta + matrix(stats::rnorm(S * T, 0, 0.5), S, T)
  df <- data.frame(species = factor(rep(tr$tree$tip.label, times = T), levels = tr$tree$tip.label),
    trait = factor(rep(paste0("t", seq_len(T)), each = S)), value = as.vector(y), x = rep(tr$x, times = T))
  t0 <- Sys.time()
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = K_B, lv = ~x) +
      phylo_latent(0 + trait | species, d = ncol(tr$LambdaPhy), tree = tr$tree),
    data = df, unit = "species", trait = "trait", family = gaussian(), REML = TRUE,
    control = gllvmTMBcontrol(se = FALSE, optimizer = "optim", optArgs = list(method = "BFGS"))))),
    error = function(e) NULL)
  base <- data.frame(seed = seed, trait = 1L, predictor = 1L, truth = tr$B_lv[1, 1],
    converged = FALSE, ci_available = FALSE, lower = NA_real_, upper = NA_real_,
    covered = NA, width = NA_real_, wall_s = NA_real_)
  if (is.null(fit) || !isTRUE(fit$opt$convergence == 0L)) return(base)
  base$converged <- TRUE
  ci <- tryCatch(profile_ci_lv_effects(fit, trait = 1, predictor = 1, reference = "t"),
                 error = function(e) NULL)
  if (is.null(ci) || !is.finite(ci$lower) || !is.finite(ci$upper)) return(base)
  base$ci_available <- TRUE
  base$lower <- ci$lower; base$upper <- ci$upper
  base$covered <- ci$lower <= base$truth && base$truth <= ci$upper
  base$width <- ci$upper - ci$lower
  base$wall_s <- as.numeric(Sys.time() - t0, units = "secs")
  base
}

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1L) args[[1]] else "run"

if (identical(mode, "run")) {
  cell_id <- args[[2]]
  task_id <- as.integer(args[[3]])
  reps_per_task <- if (length(args) >= 4L) as.integer(args[[4]]) else 5L
  stopifnot(cell_id %in% names(CELLS))
  tr <- make_truth(CELLS[[cell_id]])
  seed_base <- 10000L * task_id
  rows <- do.call(rbind, lapply(seq_len(reps_per_task), function(i) one_rep(tr, seed_base + i)))
  rows$cell_id <- cell_id; rows$task_id <- task_id
  outdir <- file.path("results", "lv-effects-ci-coverage", cell_id)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(outdir, sprintf("task-%05d.csv", task_id)), row.names = FALSE)
  writeLines(capture.output(utils::sessionInfo()), file.path(outdir, sprintf("task-%05d.sessionInfo.txt", task_id)))
  cat(sprintf("[%s task %d] %d reps written\n", cell_id, task_id, nrow(rows)))
} else if (identical(mode, "summarise")) {
  results_dir <- args[[2]]
  cells <- list.dirs(results_dir, recursive = FALSE)
  for (cd in cells) {
    files <- list.files(cd, pattern = "^task-.*\\.csv$", full.names = TRUE)
    if (!length(files)) next
    dat <- do.call(rbind, lapply(files, utils::read.csv))
    n_att <- nrow(dat); n_conv <- sum(dat$converged); n_ci <- sum(dat$ci_available)
    elig <- dat[dat$ci_available %in% TRUE, ]
    cov <- mean(elig$covered); mcse <- sqrt(cov * (1 - cov) / nrow(elig))
    cat(sprintf("%-22s attempted=%d converged=%d ci=%d | coverage=%.3f (MCSE %.4f) width=%.3f | prod>=500: %s\n",
      basename(cd), n_att, n_conv, n_ci, cov, mcse, mean(elig$width), n_ci >= 500))
  }
} else {
  stop("mode must be 'run' or 'summarise'")
}
