#!/usr/bin/env Rscript
## ============================================================================
## ADEMP recovery / coverage campaign for the predictor-informed latent effect
## B_lv under the orthogonal Model A (latent(lv=~x) + phylo_latent), Gaussian.
##
## Estimand : population trait-scale B_lv = Lambda_B alpha^T -- the ROTATION-
##            INVARIANT per-(trait, predictor) entries. profile_ci_lv_effects()
##            is both the D-12 hero method AND the method that targets these
##            entries directly (extract_lv_effects() is axis-scale / rotation-
##            dependent, so it is NOT a B_lv-entry interval -- a delta-method
##            per-entry Wald arm is a documented follow-up, not this run).
## Method   : profile (t reference), ALL T*K_B entries per rep (not just [1,1]).
## Design   : fixed per-cell design (tree, X); redraw REs + residual per rep;
##            REML fits. One seed batch per array/xargs task.
## Fit gate : the SCALE-FREE convergence verdict max|grad|/(1+|obj|) < 1e-3
##            (fit_health$converged; computed inline so this runs against any
##            build, incl. plain `main`). NOT fit$opt$convergence -- a raw PORT
##            code that flips with LC_COLLATE -- and NOT pd_hessian (an eigen-
##            value sign, noise near zero). See brain LESSONS 0c / #733.
## Report   : per-rep x per-entry converged / pd_hessian / ci_available /
##            covered / width / wall_s; aggregate to per-entry + pooled coverage
##            with Monte Carlo SE and explicit failed-fit denominators.
##            Production admission (register LV bar): >= 500 reps/cell, per-rep
##            outputs + sessionInfo(), coverage band 0.92-0.98.
##
## POST-#733 NOTE: the aliased-diagonal fix means Model A now fits with a PD
## Hessian at unit == cluster; pd_hessian is recorded as a diagnostic but is NOT
## the fit gate (the verdict is).
##
## Usage (task):      Rscript lv-effects-ci-coverage.R run <cell_id> <task_id> <reps_per_task>
##       (summarise): Rscript lv-effects-ci-coverage.R summarise <results_dir>
##       (bench):     Rscript lv-effects-ci-coverage.R bench <cell_id> <n_reps>
## ============================================================================

suppressMessages({
  library(gllvmTMB)   # installed package (cluster: R CMD INSTALL from a current checkout)
  library(ape)
})

G_TOL <- 1e-3         # scale-free convergence tolerance (mirrors .gllvmTMB_converged_gtol)

## ---- Cell grid (size n to family + latent rank; the #715 sample-size lesson) --
## Includes the GLLVM.jl weak cell (p=80, K=2, lambda=0.5) sized UP as the
## never-yet-run rank-2 cell, and a small-n cell where the t reference matters most.
CELLS <- list(
  `gauss-S200-K1`      = list(S = 200L, T = 5L, K_B = 1L, K_phy = 1L, lambda = 0.7),
  `gauss-S100-K1`      = list(S = 100L, T = 5L, K_B = 1L, K_phy = 1L, lambda = 0.7),
  `gauss-S60-K1-smalln`= list(S = 60L,  T = 4L, K_B = 1L, K_phy = 1L, lambda = 0.5),
  `gauss-S400-K1`      = list(S = 400L, T = 5L, K_B = 1L, K_phy = 1L, lambda = 0.7),  # n-ladder top
  `gauss-S200-K2-hard` = list(S = 200L, T = 8L, K_B = 2L, K_phy = 1L, lambda = 0.5)   # NEVER RUN
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

`%||%` <- function(a, b) if (is.null(a)) b else a

## Inline scale-free convergence verdict (portable; no dependency on the
## fit_health$converged field, which lives on the not-yet-merged branch).
.converged <- function(fit) {
  g <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
  o <- tryCatch(fit$opt$objective, error = function(e) NA_real_)
  if (is.na(g) || is.na(o)) return(FALSE)
  isTRUE(g / (1 + abs(o)) < G_TOL)
}

## One replicate: fit once, gate on the verdict, then profile ALL T*K_B entries.
## Returns one row PER ENTRY (long). A failed fit still returns one row per entry
## (converged = FALSE) so the failed-fit denominator is exact.
one_rep <- function(tr, seed) {
  set.seed(seed)
  S <- tr$S; T <- tr$T; K_B <- tr$K_B
  ## B_lv = Lambda_B alpha^T is T x n_predictors. With a single predictor
  ## (lv = ~x) alpha is 1 x K_B, so B_lv is T x 1 for ANY latent rank K_B --
  ## the number of assessed entries is T * n_pred, NOT T * K_B.
  n_pred <- ncol(tr$B_lv)
  entries <- expand.grid(trait = seq_len(T), predictor = seq_len(n_pred))
  truth_vec <- tr$B_lv[cbind(entries$trait, entries$predictor)]
  na_rows <- data.frame(
    seed = seed, trait = entries$trait, predictor = entries$predictor,
    truth = truth_vec, converged = FALSE, pd_hessian = NA,
    ci_available = FALSE, lower = NA_real_, upper = NA_real_,
    covered = NA, width = NA_real_, df = NA_real_, wall_s = NA_real_)

  t0 <- Sys.time()
  zB <- matrix(tr$x, S, 1) %*% tr$alpha + matrix(stats::rnorm(S * K_B), S, K_B)
  gphy <- tr$LA %*% matrix(stats::rnorm(S * ncol(tr$LambdaPhy)), S, ncol(tr$LambdaPhy))
  eta <- matrix(tr$beta, S, T, byrow = TRUE) + zB %*% t(tr$LambdaB) + gphy %*% t(tr$LambdaPhy)
  y <- eta + matrix(stats::rnorm(S * T, 0, 0.5), S, T)
  df <- data.frame(
    species = factor(rep(tr$tree$tip.label, times = T), levels = tr$tree$tip.label),
    trait = factor(rep(paste0("t", seq_len(T)), each = S)),
    value = as.vector(y), x = rep(tr$x, times = T))

  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = K_B, lv = ~x) +
      phylo_latent(0 + trait | species, d = ncol(tr$LambdaPhy), tree = tr$tree),
    data = df, unit = "species", trait = "trait", family = gaussian(), REML = TRUE,
    control = gllvmTMBcontrol(se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS"))))),
    error = function(e) NULL)
  wall <- as.numeric(Sys.time() - t0, units = "secs")
  na_rows$wall_s <- wall
  if (is.null(fit) || !.converged(fit)) return(na_rows)

  na_rows$converged <- TRUE
  na_rows$pd_hessian <- isTRUE(fit$fit_health$pd_hessian %||% fit$sd_report$pdHess)
  ci <- tryCatch(
    suppressMessages(profile_ci_lv_effects(fit, trait = NULL, predictor = NULL, reference = "t")),
    error = function(e) NULL)
  if (is.null(ci)) return(na_rows)
  ## ci has one row per (trait, predictor); align to `entries` order.
  key_ci <- paste(sub("^trait", "", ci$trait), sub("^lv", "", ci$predictor), sep = ":")
  key_en <- paste(entries$trait, entries$predictor, sep = ":")
  m <- match(key_en, key_ci)
  ok <- !is.na(m) & is.finite(ci$lower[m]) & is.finite(ci$upper[m])
  na_rows$ci_available[ok] <- TRUE
  na_rows$lower[ok] <- ci$lower[m][ok]
  na_rows$upper[ok] <- ci$upper[m][ok]
  na_rows$df[ok] <- ci$df[m][ok]
  na_rows$covered[ok] <- na_rows$lower[ok] <= na_rows$truth[ok] &
    na_rows$truth[ok] <= na_rows$upper[ok]
  na_rows$width[ok] <- na_rows$upper[ok] - na_rows$lower[ok]
  na_rows
}

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) >= 1L) args[[1]] else "run"

if (identical(mode, "run")) {
  cell_id <- args[[2]]; task_id <- as.integer(args[[3]])
  reps_per_task <- if (length(args) >= 4L) as.integer(args[[4]]) else 5L
  stopifnot(cell_id %in% names(CELLS))
  outdir <- file.path("results", "lv-effects-ci-coverage", cell_id)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  outfile <- file.path(outdir, sprintf("task-%05d.csv", task_id))
  if (file.exists(outfile)) {
    cat(sprintf("[%s task %d] exists -- skip (resume)\n", cell_id, task_id)); quit(save = "no")
  }
  tr <- make_truth(CELLS[[cell_id]])
  seed_base <- 10000L * task_id
  rows <- do.call(rbind, lapply(seq_len(reps_per_task), function(i) one_rep(tr, seed_base + i)))
  rows$cell_id <- cell_id; rows$task_id <- task_id
  utils::write.csv(rows, outfile, row.names = FALSE)
  writeLines(capture.output(utils::sessionInfo()),
             file.path(outdir, sprintf("task-%05d.sessionInfo.txt", task_id)))
  cat(sprintf("[%s task %d] %d reps x %d entries = %d rows\n",
              cell_id, task_id, reps_per_task, nrow(rows) / reps_per_task, nrow(rows)))

} else if (identical(mode, "bench")) {
  cell_id <- args[[2]]; n <- if (length(args) >= 3L) as.integer(args[[3]]) else 3L
  tr <- make_truth(CELLS[[cell_id]])
  t0 <- Sys.time()
  r <- do.call(rbind, lapply(seq_len(n), function(i) one_rep(tr, 999000L + i)))
  dt <- as.numeric(Sys.time() - t0, units = "secs")
  cat(sprintf("[bench %s] %d reps in %.1fs = %.1fs/rep | converged %.0f%% | mean entry width %.3f\n",
      cell_id, n, dt, dt / n, 100 * sum(r$converged) / nrow(r),
      mean(r$width[r$ci_available %in% TRUE], na.rm = TRUE)))

} else if (identical(mode, "summarise")) {
  results_dir <- args[[2]]
  for (cd in list.dirs(results_dir, recursive = FALSE)) {
    files <- list.files(cd, pattern = "^task-.*\\.csv$", full.names = TRUE)
    if (!length(files)) next
    dat <- do.call(rbind, lapply(files, utils::read.csv))
    n_rep <- length(unique(dat$seed))
    elig <- dat[dat$ci_available %in% TRUE, ]
    cov <- mean(elig$covered); mcse <- sqrt(cov * (1 - cov) / nrow(elig))
    conv_rate <- sum(dat$converged) / nrow(dat)
    cat(sprintf("%-22s reps=%d entries/rep=%d | conv=%.3f pd=%.3f ci=%d | POOLED cov=%.3f (MCSE %.4f) width=%.3f | prod>=500reps: %s\n",
      basename(cd), n_rep, nrow(dat) / n_rep, conv_rate,
      mean(dat$pd_hessian, na.rm = TRUE), nrow(elig), cov, mcse,
      mean(elig$width), n_rep >= 500))
    per <- aggregate(covered ~ trait + predictor, data = elig, FUN = mean)
    per$n <- aggregate(covered ~ trait + predictor, data = elig, FUN = length)$covered
    cat("   per-entry coverage: ",
        paste(sprintf("[t%d,p%d]=%.3f(n%d)", per$trait, per$predictor, per$covered, per$n),
              collapse = " "), "\n")
  }
} else {
  stop("mode must be 'run', 'bench', or 'summarise'")
}
