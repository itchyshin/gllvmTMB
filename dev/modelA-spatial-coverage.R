#!/usr/bin/env Rscript
## ADEMP coverage — Model A B_lv with the SPATIAL orthogonal source (the source cell not
## yet frontier-tested at the time of writing: phylo/kernel/animal already verified in
## modelA-source-coverage.R). Model A = latent(0+trait|unit, d=K, lv=~x) + spatial_latent(...)
## [spatial term has NO lv -- it is a nuisance/orthogonal source, like kernel/animal K].
## Spatial "source covariance" = exp(-dist/range) Matern-ish draw (NOT the engine's own SPDE
## prior); the target of THIS study is B_lv (Model A's ordinary-latent trait effect), not the
## spatial term's own shape recovery (that is covered separately by
## test-spatial-latent-recovery.R). Gaussian. Confirms the certified-Gaussian recovery +
## interval machinery composes with a coords/mesh-based random effect, source-agnostic.
## Same interval trio as modelA-source-coverage.R: Wald + profile-chisq(hero) + t-df(sensitivity).
## Usage: Rscript modelA-spatial-coverage.R run <cell_id> <task_id> <reps>
##        Rscript modelA-spatial-coverage.R summarise <results_dir>
suppressMessages({ library(gllvmTMB) })

## cell = spatial rank x scale; smoke small, scale on Totoro.
CELLS <- list(
  `spatial-S100-K1` = list(S = 100L, T = 4L, K_B = 1L, K_src = 1L, lambda = 0.6,
                            range = 0.3, cutoff = 0.12),
  `spatial-S160-K2` = list(S = 160L, T = 6L, K_B = 2L, K_src = 1L, lambda = 0.5,
                            range = 0.3, cutoff = 0.1)
)

make_truth <- function(cell, design_seed = 20260716L) {
  set.seed(design_seed)
  S <- cell$S; T <- cell$T; K_B <- cell$K_B; d_src <- cell$K_src
  coords <- cbind(lon = stats::runif(S), lat = stats::runif(S))
  Dmat <- as.matrix(stats::dist(coords))
  Lspa <- t(chol(exp(-Dmat / cell$range) + 1e-8 * diag(S)))
  LambdaB <- matrix(stats::runif(T * K_B, -1, 1), T, K_B)
  LambdaB[upper.tri(LambdaB)] <- 0; diag(LambdaB) <- abs(diag(LambdaB)) + 0.3
  alpha <- matrix(stats::runif(K_B, 0.5, 1.0), 1L, K_B)
  LambdaSrc <- matrix(stats::runif(T * d_src, -1, 1) * sqrt(cell$lambda), T, d_src)
  beta <- stats::rnorm(T, 0, 0.5); x <- stats::rnorm(S)
  site_ids <- paste0("s", seq_len(S))
  df_mesh_skeleton <- data.frame(
    site = factor(rep(site_ids, times = T), levels = site_ids),
    lon = rep(coords[, 1], times = T), lat = rep(coords[, 2], times = T))
  mesh <- gllvmTMB::make_mesh(df_mesh_skeleton, c("lon", "lat"), cutoff = cell$cutoff)
  list(coords = coords, Lspa = Lspa, LambdaB = LambdaB, alpha = alpha, LambdaSrc = LambdaSrc,
       beta = beta, x = x, B_lv = LambdaB %*% t(alpha), S = S, T = T, K_B = K_B, K_src = d_src,
       ids = site_ids, mesh = mesh)
}

one_rep <- function(tr, seed) {
  set.seed(seed)
  S <- tr$S; T <- tr$T; K_B <- tr$K_B; d_src <- tr$K_src
  zB <- matrix(tr$x, S, 1) %*% tr$alpha + matrix(stats::rnorm(S * K_B), S, K_B)
  gsrc <- tr$Lspa %*% matrix(stats::rnorm(S * d_src), S, d_src)
  eta <- matrix(tr$beta, S, T, byrow = TRUE) + zB %*% t(tr$LambdaB) + gsrc %*% t(tr$LambdaSrc)
  y <- eta + matrix(stats::rnorm(S * T, 0, 0.5), S, T)
  df <- data.frame(site = factor(rep(tr$ids, times = T), levels = tr$ids),
    trait = factor(rep(paste0("t", seq_len(T)), each = S)), value = as.vector(y),
    x = rep(tr$x, times = T), lon = rep(tr$coords[, 1], times = T),
    lat = rep(tr$coords[, 2], times = T))
  form <- eval(bquote(value ~ 0 + trait + latent(0 + trait | site, d = .(K_B), lv = ~x) +
    spatial_latent(0 + trait | coords, d = .(d_src))))
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
    form, data = df, unit = "site", trait = "trait", family = gaussian(), mesh = tr$mesh,
    REML = TRUE,
    control = gllvmTMBcontrol(se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS"))))),
    error = function(e) NULL)
  truth <- tr$B_lv[1, 1]
  base <- data.frame(seed = seed, truth = truth, converged = FALSE, b_err = NA_real_,
    wald_cov = NA, prof_cov = NA, tdf_cov = NA)
  if (is.null(fit) || !isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$sd_report$pdHess)) return(base)
  base$converged <- TRUE
  eff <- tryCatch(extract_lv_effects(fit, type = "trait_effect"), error = function(e) NULL)
  if (!is.null(eff)) {
    base$b_err <- max(abs(matrix(eff$estimate, nrow = fit$n_traits) - tr$B_lv))
    base$wald_cov <- eff$lower[1] <= truth && truth <= eff$upper[1]
  }
  pc <- tryCatch(gllvmTMB:::profile_ci_lv_effects(fit, trait = 1, predictor = 1, reference = "chisq"),
                 error = function(e) NULL)
  if (!is.null(pc) && is.finite(pc$lower) && is.finite(pc$upper))
    base$prof_cov <- pc$lower <= truth && truth <= pc$upper
  pt <- tryCatch(gllvmTMB:::profile_ci_lv_effects(fit, trait = 1, predictor = 1,
                   reference = "t", df = tr$S - tr$K_B - 1L), error = function(e) NULL)
  if (!is.null(pt) && is.finite(pt$lower) && is.finite(pt$upper))
    base$tdf_cov <- pt$lower <= truth && truth <= pt$upper
  base
}

args <- commandArgs(trailingOnly = TRUE); mode <- if (length(args) >= 1L) args[[1]] else "run"
if (identical(mode, "run")) {
  cell_id <- args[[2]]; task_id <- as.integer(args[[3]]); reps <- if (length(args) >= 4L) as.integer(args[[4]]) else 5L
  stopifnot(cell_id %in% names(CELLS)); tr <- make_truth(CELLS[[cell_id]]); seed_base <- 10000L * task_id
  rows <- do.call(rbind, lapply(seq_len(reps), function(i) one_rep(tr, seed_base + i)))
  rows$cell_id <- cell_id
  outdir <- file.path("results", "modelA-spatial-coverage", cell_id); dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(outdir, sprintf("task-%05d.csv", task_id)), row.names = FALSE)
  cat(sprintf("[%s task %d] %d reps: converged=%d prof_ci=%d meanBerr=%.3f\n", cell_id, task_id, nrow(rows),
    sum(rows$converged), sum(!is.na(rows$prof_cov)), mean(rows$b_err, na.rm = TRUE)))
} else if (identical(mode, "summarise")) {
  for (cd in list.dirs(args[[2]], recursive = FALSE)) {
    files <- list.files(cd, pattern = "^task-.*\\.csv$", full.names = TRUE); if (!length(files)) next
    dat <- do.call(rbind, lapply(files, utils::read.csv))
    for (m in c("wald", "prof", "tdf")) { cc <- dat[[paste0(m, "_cov")]]; e <- cc[!is.na(cc)]
      cat(sprintf("%-16s %-5s n=%3d coverage=%.3f prod>=500:%s\n", basename(cd), m, length(e), mean(e), length(e) >= 500)) }
  }
} else stop("mode must be 'run' or 'summarise'")
