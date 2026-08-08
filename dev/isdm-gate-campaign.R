## dev/isdm-gate-campaign.R
##
## THE GATE. Full campaign for the mixed-curvature loading question:
## is planted Lambda recoverable when ONE species' loading is informed by two
## likelihoods of very different curvature (Poisson-log + Bernoulli-cloglog)?
## And if recovery degrades, is that non-identifiability or weak estimability?
##
## Pre-registration lives in dev/isdm-gate-findings.md and was written BEFORE
## this ran. Harness reused from dev/isdm-gate-harness.R (not rebuilt).
##
## Usage:  Rscript dev/isdm-gate-campaign.R [stage ...]
##   stages: grid d2 d3 d4 d5 d6 d7 analyse   (default: all)
##
## Lane rule: this worktree only. Nothing in R/, src/, tests/ is touched.
## Uses the INSTALLED gllvmTMB (library(), not load_all()).

source("dev/isdm-gate-harness.R")

ARGS <- commandArgs(trailingOnly = TRUE)
STAGES <- if (length(ARGS)) ARGS else c("grid", "d2", "d3", "d4", "d5", "d6", "d7", "analyse")
do_stage <- function(s) s %in% STAGES

N_SEEDS   <- 200L
N_CORES   <- max(1L, min(18L, parallel::detectCores() - 2L))
RES_RDS   <- "dev/isdm-gate-results.rds"
RES_CSV   <- "dev/isdm-gate-results.csv"
INSTR_RDS <- "dev/isdm-gate-instruments.rds"
FINDINGS  <- "dev/isdm-gate-findings.md"

## Pre-declared boundary criterion (also in the pre-registration).
PSI_ABS_THRESH <- 1e-4
PSI_REL_THRESH <- 0.01
LOADING_RUNAWAY <- 25

hr <- function(x) cat("\n", strrep("=", 12), " ", x, " ", strrep("=", 12), "\n", sep = "")

## =========================================================================
## Shared small utilities
## =========================================================================

## Reflection-permitting (Procrustes over O(1)) alignment: at d = 1 the optimal
## orthogonal transform is a sign.
align_sign <- function(lam_hat, lam_true) {
  ok <- is.finite(lam_hat) & is.finite(lam_true)
  if (!any(ok)) return(NA_real_)
  s <- sign(sum(lam_hat[ok] * lam_true[ok]))
  if (s == 0) s <- 1
  s
}
lambda_rmse_aligned <- function(lam_hat, lam_true) {
  s <- align_sign(lam_hat, lam_true)
  if (is.na(s)) return(NA_real_)
  ok <- is.finite(lam_hat) & is.finite(lam_true)
  sqrt(mean((s * lam_hat[ok] - lam_true[ok])^2))
}
## min over sign of RMS distance between two loading vectors
lambda_dist <- function(a, b) {
  min(sqrt(mean((a - b)^2)), sqrt(mean((-a - b)^2)))
}

mcse_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2) return(NA_real_)
  stats::sd(x) / sqrt(length(x))
}
mcse_prop <- function(k, n) if (n < 1) NA_real_ else sqrt((k / n) * (1 - k / n) / n)

par_lambda <- function(p) unname(p[names(p) == "theta_rr_B"])
par_psi <- function(p) {
  td <- unname(p[names(p) == "theta_diag_B"])
  if (!length(td)) return(rep(NA_real_, T_SP))
  exp(2 * td)
}

rebuild_obj <- function(fit) {
  TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
                 map = fit$tmb_map, random = fit$random,
                 DLL = "gllvmTMB", silent = TRUE)
}

## =========================================================================
## STAGE grid: extended scorer + the 24,000-fit grid
## =========================================================================

## Overrides the harness's score_fit() (run_one() resolves it from globalenv).
## Additions over the harness version: sign-aligned Lambda RMSE (the PRIMARY
## gate metric), the per-species lambda_hat / psi_hat vectors, and the attained
## negative log-likelihood.
score_fit <- function(fit, cell_type, n_units, prevalence, seed, arm,
                      planted = PLANTED, elapsed_sec = NA_real_) {
  Tn <- length(planted$Lambda)
  nm_lam <- paste0("lam", seq_len(Tn))
  nm_psi <- paste0("psi", seq_len(Tn))

  base <- data.frame(
    cell = cell_type, n_units = n_units, prevalence = prevalence, seed = seed,
    arm = arm, elapsed_sec = elapsed_sec,
    fit_error = NA_character_,
    convergence = NA_integer_, pdHess = NA, diag_B_skip = NA_integer_,
    nll = NA_real_,
    lambda_rmse = NA_real_, lambda_cor = NA_real_, lambda_sign = NA_real_,
    off_diag_rmse = NA_real_, off_diag_cor = NA_real_, diag_rmse = NA_real_,
    comm_rmse = NA_real_, comm_cor = NA_real_,
    n_heywood_psi = NA_integer_, n_heywood_loading = NA_integer_,
    stringsAsFactors = FALSE
  )
  base[nm_lam] <- NA_real_
  base[nm_psi] <- NA_real_

  if (inherits(fit, "condition")) {
    base$fit_error <- conditionMessage(fit)
    return(base)
  }

  base$convergence <- fit$opt$convergence
  base$pdHess <- isTRUE(fit$sd_report$pdHess)
  base$nll <- fit$opt$objective
  base$diag_B_skip <- if (!is.null(fit$tmb_data$diag_B_skip)) {
    as.integer(sum(fit$tmb_data$diag_B_skip))
  } else NA_integer_

  Lambda_true <- planted$Lambda
  psi_true <- planted$psi
  Sigma_true <- outer(Lambda_true, Lambda_true) + diag(psi_true)
  R_true <- stats::cov2cor(Sigma_true)

  ## ---- Lambda: the PRIMARY metric -------------------------------------
  Lambda_hat <- tryCatch(extract_loadings(fit, level = "unit"), error = function(e) e)
  if (!inherits(Lambda_hat, "condition")) {
    lam <- as.numeric(Lambda_hat[, 1])
    base[nm_lam] <- as.list(lam)
    base$lambda_rmse <- lambda_rmse_aligned(lam, Lambda_true)
    base$lambda_cor <- .sign_free_cor(lam, Lambda_true)
    base$lambda_sign <- align_sign(lam, Lambda_true)
    base$n_heywood_loading <- sum(abs(lam) > LOADING_RUNAWAY)
  } else {
    base$fit_error <- paste("extract_loadings failed:", conditionMessage(Lambda_hat))
    return(base)
  }

  ## ---- Sigma / R: SECONDARY (PP vs PB only; see pre-registration) ------
  Sigma_res <- tryCatch(
    extract_Sigma(fit, level = "unit", part = "total", link_residual = "none"),
    error = function(e) e)
  if (!inherits(Sigma_res, "condition")) {
    off_true <- R_true[upper.tri(R_true)]
    off_hat <- Sigma_res$R[upper.tri(Sigma_res$R)]
    base$off_diag_rmse <- .rmse(off_hat, off_true)
    ok <- is.finite(off_hat) & is.finite(off_true)
    base$off_diag_cor <- if (sum(ok) >= 2) stats::cor(off_hat[ok], off_true[ok]) else NA_real_
    base$diag_rmse <- .rmse(diag(Sigma_res$Sigma), diag(Sigma_true))
  }

  ## ---- psi / communality / boundary rate (U1 only; BB pins psi off) ----
  if (arm == "U1") {
    psi_res <- tryCatch(
      extract_Sigma(fit, level = "unit", part = "unique", link_residual = "none"),
      error = function(e) e)
    if (!inherits(psi_res, "condition")) {
      psi_hat <- if (is.list(psi_res) && !is.null(psi_res$s)) psi_res$s else as.numeric(psi_res)
      base[nm_psi] <- as.list(as.numeric(psi_hat))
      lam <- as.numeric(Lambda_hat[, 1])
      comm_hat <- lam^2 / (lam^2 + psi_hat)
      comm_true <- Lambda_true^2 / (Lambda_true^2 + psi_true)
      base$comm_rmse <- .rmse(comm_hat, comm_true)
      ok <- is.finite(comm_hat) & is.finite(comm_true)
      base$comm_cor <- if (sum(ok) >= 2) stats::cor(comm_hat[ok], comm_true[ok]) else NA_real_
      med_psi <- stats::median(psi_hat[is.finite(psi_hat)])
      base$n_heywood_psi <- sum(is.finite(psi_hat) &
        (psi_hat < PSI_ABS_THRESH |
           (is.finite(med_psi) && med_psi > 0 & psi_hat / med_psi < PSI_REL_THRESH)))
    }
  }
  base
}

build_config <- function(seeds = seq_len(N_SEEDS)) {
  expand.grid(cell = CELL_TYPES, n_units = N_LADDER, prevalence = PREVALENCE_LADDER,
              seed = seeds, arm = c("U1", "U0"),
              stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
}

if (do_stage("grid")) {
  hr("STAGE grid")
  cfg_all <- build_config()
  cat(sprintf("Grid: %d fits; %d cores\n", nrow(cfg_all), N_CORES))

  ## ---- EARLY ABORT CHECK: run the first small batch and look at it ------
  hr("early-abort check (first 12 configs)")
  early <- run_grid(cfg_all[seq_len(12), , drop = FALSE], n_cores = N_CORES,
                    backend = "mclapply")
  print(early[, c("cell", "n_units", "prevalence", "seed", "arm",
                  "lambda_rmse", "lambda_cor", "n_heywood_psi", "fit_error")])
  bad <- all(is.na(early$lambda_rmse)) ||
    nrow(early) == 0 ||
    any(is.finite(early$lambda_rmse) & early$lambda_rmse > 1e3)
  if (bad) stop("EARLY ABORT: first batch empty, all-NA, or out of range.")
  cat("early-abort check PASSED\n")

  ## ---- full grid, chunked by n so timing stays homogeneous per chunk ----
  chunks <- split(cfg_all, cfg_all$n_units)
  out <- vector("list", length(chunks))
  for (i in seq_along(chunks)) {
    t0 <- Sys.time()
    out[[i]] <- run_grid(chunks[[i]], n_cores = N_CORES, backend = "mclapply")
    el <- as.numeric(Sys.time() - t0, units = "mins")
    cat(sprintf("  n=%-5s %5d fits  %6.2f min  (%d errors)\n",
                names(chunks)[i], nrow(chunks[[i]]), el,
                sum(!is.na(out[[i]]$fit_error))))
    saveRDS(do.call(rbind, out[seq_len(i)]), RES_RDS)  # checkpoint
  }
  results <- do.call(rbind, out)
  rownames(results) <- NULL
  saveRDS(results, RES_RDS)
  utils::write.csv(results, RES_CSV, row.names = FALSE)
  cat(sprintf("\nSaved %d rows to %s / %s\n", nrow(results), RES_RDS, RES_CSV))
}

## =========================================================================
## Instrument stages. Each writes into a growing list saved to INSTR_RDS.
## =========================================================================

instr <- if (file.exists(INSTR_RDS)) readRDS(INSTR_RDS) else list()
save_instr <- function() saveRDS(instr, INSTR_RDS)

## ---- D2: within-dataset multistart --------------------------------------
## ONE dataset, K dispersed starts on the SAME objective. Solutions that differ
## materially at essentially the same logL are a flat ridge -- non-identifiability
## demonstrated within one dataset, with sampling noise removed.
multistart_one <- function(cell, n_units, prevalence, seed, arm = "U1", K = 14L,
                           mstart_seed = 101L) {
  df <- simulate_cell(cell, n_units, prevalence, seed)
  fit <- fit_cell(df, arm = arm)
  p_hat <- fit$opt$par
  npar <- length(p_hat)
  idx_lam <- which(names(p_hat) == "theta_rr_B")

  set.seed(mstart_seed)
  starts <- list()
  starts[["mle"]] <- p_hat
  starts[["pkg_default"]] <- rebuild_obj(fit)$par
  ## reflection of the loadings
  pf <- p_hat; pf[idx_lam] <- -pf[idx_lam]; starts[["reflect"]] <- pf
  ## loadings shrunk / inflated (walks the lambda-vs-psi trade-off)
  ps <- p_hat; ps[idx_lam] <- 0.2 * ps[idx_lam]; starts[["shrink"]] <- ps
  pb <- p_hat; pb[idx_lam] <- 3.0 * pb[idx_lam]; starts[["inflate"]] <- pb
  for (s in c(0.3, 0.6, 1.0)) {
    for (r in 1:3) {
      starts[[sprintf("jit%.1f_%d", s, r)]] <- p_hat + stats::rnorm(npar, 0, s)
    }
  }
  starts <- starts[seq_len(min(K, length(starts)))]

  res <- lapply(names(starts), function(nm) {
    o <- rebuild_obj(fit)   # fresh object: no inner-solution path dependence
    fitk <- tryCatch(
      nlminb(starts[[nm]], o$fn, o$gr, control = list(iter.max = 1000, eval.max = 2000)),
      error = function(e) e)
    if (inherits(fitk, "condition")) {
      return(list(start = nm, nll = NA_real_, conv = NA_integer_,
                  lam = rep(NA_real_, T_SP), psi = rep(NA_real_, T_SP)))
    }
    pk <- fitk$par; names(pk) <- names(p_hat)
    list(start = nm, nll = fitk$objective, conv = fitk$convergence,
         lam = par_lambda(pk), psi = par_psi(pk))
  })

  nll <- vapply(res, function(z) z$nll, numeric(1))
  lam <- do.call(rbind, lapply(res, function(z) z$lam))
  ok <- is.finite(nll)
  best <- min(nll[ok])
  ## pairwise sign-aligned Lambda distances
  K2 <- nrow(lam)
  D <- matrix(NA_real_, K2, K2)
  for (a in seq_len(K2)) for (b in seq_len(K2)) {
    if (all(is.finite(lam[a, ])) && all(is.finite(lam[b, ]))) D[a, b] <- lambda_dist(lam[a, ], lam[b, ])
  }
  ## the decisive quantity: max Lambda gap among solutions at MATCHED logL
  matched <- which(ok & abs(nll - best) < 1e-4)
  gap_matched <- if (length(matched) >= 2) max(D[matched, matched], na.rm = TRUE) else 0
  list(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed, arm = arm,
       starts = vapply(res, function(z) z$start, character(1)),
       nll = nll, conv = vapply(res, function(z) z$conv, integer(1)),
       lam = lam, psi = do.call(rbind, lapply(res, function(z) z$psi)),
       best_nll = best, nll_spread = diff(range(nll[ok])),
       n_matched = length(matched), gap_matched = gap_matched,
       max_pairwise_gap = max(D, na.rm = TRUE),
       rmse_per_start = apply(lam, 1, lambda_rmse_aligned, lam_true = PLANTED$Lambda))
}

if (do_stage("d2")) {
  hr("STAGE d2: within-dataset multistart")
  d2 <- list()
  ## hard setting: low prevalence, moderate n. Three datasets per cell so a
  ## single lucky dataset cannot carry the verdict.
  for (cl in c("PB", "PP")) {
    for (sd in 1:3) {
      key <- sprintf("%s_seed%d", cl, sd)
      d2[[key]] <- multistart_one(cl, n_units = 200, prevalence = 0.1, seed = sd, arm = "U1")
      cat(sprintf("  %-10s best_nll=%.4f  nll_spread=%.3g  n_matched=%d  gap_matched=%.4g  max_gap=%.4g\n",
                  key, d2[[key]]$best_nll, d2[[key]]$nll_spread,
                  d2[[key]]$n_matched, d2[[key]]$gap_matched, d2[[key]]$max_pairwise_gap))
    }
  }
  instr$d2 <- d2; save_instr()
}

## ---- D3: observed-information eigen-spectrum -----------------------------
info_spectrum <- function(cell, n_units, prevalence, seed, arm = "U1") {
  df <- simulate_cell(cell, n_units, prevalence, seed)
  fit <- fit_cell(df, arm = arm)
  p <- fit$opt$par
  o <- rebuild_obj(fit)
  H <- optimHess(p, o$fn, o$gr)   # exact TMB gradients -> observed information
  H <- (H + t(H)) / 2
  ev <- eigen(H, symmetric = TRUE)
  v_min <- ev$vectors[, which.min(ev$values)]
  names(v_min) <- names(p)
  ## cross-check against the package's own Hessian (inverse of cov.fixed)
  xchk <- NA_real_
  if (!is.null(fit$sd_report$cov.fixed)) {
    I2 <- tryCatch(solve(fit$sd_report$cov.fixed), error = function(e) NULL)
    if (!is.null(I2) && all(dim(I2) == dim(H))) xchk <- max(abs(I2 - H))
  }
  ## pre-registered prediction: the soft direction lies near the
  ## lambda_j^2 + psi_j = const manifold for a Bernoulli-dominated species.
  ## The (lambda_j, theta_diag_B_j) tangent of that manifold, per species.
  lam <- par_lambda(p); psi <- par_psi(p)
  idx_lam <- which(names(p) == "theta_rr_B"); idx_td <- which(names(p) == "theta_diag_B")
  manifold_cos <- rep(NA_real_, T_SP)
  if (length(idx_td) == T_SP) {
    for (j in seq_len(T_SP)) {
      ## d(lambda^2 + psi) = 0  =>  2 lam dlam + 2 psi dtheta = 0
      u <- rep(0, length(p)); u[idx_lam[j]] <- psi[j]; u[idx_td[j]] <- -lam[j]
      if (sum(u^2) > 0) manifold_cos[j] <- abs(sum(u * v_min)) / sqrt(sum(u^2))
    }
  }
  list(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed, arm = arm,
       par = p, eigenvalues = ev$values, cond = max(ev$values) / min(ev$values),
       v_min = v_min, xcheck_max_abs_diff = xchk,
       lam = lam, psi = psi, manifold_cos = manifold_cos,
       convergence = fit$opt$convergence, pdHess = isTRUE(fit$sd_report$pdHess))
}

if (do_stage("d3")) {
  hr("STAGE d3: observed-information eigen-spectrum")
  d3 <- list()
  for (cl in c("PB", "PP")) {
    for (pv in c(0.1, 0.6)) {
      for (sd in 1:3) {
        key <- sprintf("%s_p%.1f_seed%d", cl, pv, sd)
        d3[[key]] <- info_spectrum(cl, 400, pv, sd, arm = "U1")
        z <- d3[[key]]
        cat(sprintf("  %-14s lmin=%.4g lmax=%.4g cond=%.4g  argmax|v_min|=%s  xchk=%.2g\n",
                    key, min(z$eigenvalues), max(z$eigenvalues), z$cond,
                    names(z$v_min)[which.max(abs(z$v_min))], z$xcheck_max_abs_diff))
      }
    }
  }
  instr$d3 <- d3; save_instr()
}

## ---- D4: profile likelihood on communality h_j^2 -------------------------
## EXACT profile: h_j^2 = c is imposed by setting psi_j = lambda_j^2 (1-c)/c,
## i.e. theta_diag_B[j] = 0.5 log(lambda_j^2 (1-c)/c), and maximising over the
## remaining 17 free parameters.
profile_communality <- function(cell, n_units, prevalence, seed, j,
                                grid = seq(0.04, 0.96, length.out = 24), arm = "U1") {
  df <- simulate_cell(cell, n_units, prevalence, seed)
  fit <- fit_cell(df, arm = arm)
  p_hat <- fit$opt$par
  idx_lam <- which(names(p_hat) == "theta_rr_B")
  idx_td <- which(names(p_hat) == "theta_diag_B")
  if (length(idx_td) != T_SP) return(NULL)
  fix_i <- idx_td[j]; lam_i <- idx_lam[j]
  free_idx <- setdiff(seq_along(p_hat), fix_i)

  prof <- vapply(grid, function(cc) {
    o <- rebuild_obj(fit)
    f <- function(q) {
      p <- numeric(length(p_hat)); p[free_idx] <- q
      lam_j2 <- max(p[lam_i]^2, 1e-10)
      p[fix_i] <- 0.5 * log(lam_j2 * (1 - cc) / cc)
      v <- try(o$fn(p), silent = TRUE)
      if (inherits(v, "try-error") || !is.finite(v)) return(1e10)
      v
    }
    r <- tryCatch(nlminb(p_hat[free_idx], f, control = list(iter.max = 500, eval.max = 1000)),
                  error = function(e) NULL)
    if (is.null(r)) NA_real_ else r$objective
  }, numeric(1))

  h2_hat <- {
    lam <- par_lambda(p_hat); psi <- par_psi(p_hat)
    lam[j]^2 / (lam[j]^2 + psi[j])
  }
  h2_true <- PLANTED$Lambda[j]^2 / (PLANTED$Lambda[j]^2 + PLANTED$psi[j])
  ## profile interval: 1.92 drop in logL = 1.92 rise in nll
  nll_min <- min(prof, na.rm = TRUE)
  inside <- grid[is.finite(prof) & (prof - nll_min) <= 1.920729]
  list(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed, species = j,
       grid = grid, nll = prof, nll_min = nll_min,
       h2_hat = h2_hat, h2_true = unname(h2_true),
       ci = if (length(inside)) range(inside) else c(NA_real_, NA_real_),
       ci_width = if (length(inside)) diff(range(inside)) else NA_real_,
       curvature_range = diff(range(prof[is.finite(prof)])))
}

if (do_stage("d4")) {
  hr("STAGE d4: profile likelihood on communality")
  d4 <- list()
  for (cl in c("PB", "PP")) {
    for (j in c(1L, 2L)) {   # sp1 = small loading (hard), sp2 = large loading
      for (pv in c(0.1, 0.6)) {
        key <- sprintf("%s_sp%d_p%.1f", cl, j, pv)
        d4[[key]] <- profile_communality(cl, 400, pv, seed = 1, j = j)
        z <- d4[[key]]
        if (!is.null(z)) cat(sprintf("  %-14s h2_true=%.3f h2_hat=%.3f  CI=[%.2f,%.2f] width=%.2f  nll_range=%.3g\n",
                                     key, z$h2_true, z$h2_hat, z$ci[1], z$ci[2], z$ci_width, z$curvature_range))
      }
    }
  }
  instr$d4 <- d4; save_instr()
}

## ---- D5: arm-stratified information --------------------------------------
## TRAP handled as pre-registered: a block-2-only fit in PB is all-Bernoulli, so
## the psi-pinning of R/fit-multi.R:4976 would fire and estimate a DIFFERENT
## model. We therefore force unique = FALSE UNIFORMLY across joint / block1 /
## block2 so all three fit the same model class.
## NOTE: fit_cell() cannot be reused here -- it always builds a TWO-entry family
## list, and gllvmTMB requires length(family) == number of distinct levels of the
## family_var. So the single-block fitter is built explicitly.
fit_block_subset <- function(df, blocks) {
  sub <- df[df$block %in% blocks, , drop = FALSE]
  sub$block <- droplevels(sub$block)
  fams <- c(block1 = attr(df, "fam1"), block2 = attr(df, "fam2"))
  keep <- levels(sub$block)
  family_list <- lapply(fams[keep], .family_obj)
  names(family_list) <- keep
  attr(family_list, "family_var") <- "block"
  form <- stats::as.formula(
    "value ~ 0 + trait + latent(0 + trait | cell, d = 1, unique = FALSE)")
  gllvmTMB(form, data = sub, trait = "trait", unit = "cell", cluster = "trait",
           family = family_list, silent = TRUE)
}

## Information about lambda_j is compared at a COMMON parameter point -- the
## JOINT fit's MLE -- for all three fits. Evaluating each arm's Hessian at its
## OWN MLE (an earlier version of this function) does not compare information
## content: the three MLEs sit at different points, and profile information is
## not comparable across points. Exact additivity is NOT expected even at a
## common point, because the joint model shares ONE latent u under ONE integral,
## so its marginal log-likelihood is not the sum of the two block marginals.
arm_information <- function(cell, n_units, prevalence, seed) {
  df <- simulate_cell(cell, n_units, prevalence, seed)
  fit_j <- tryCatch(fit_block_subset(df, c("block1", "block2")), error = function(e) e)
  if (inherits(fit_j, "condition")) return(NULL)
  p_common <- fit_j$opt$par

  get1 <- function(blocks, label) {
    fit <- tryCatch(fit_block_subset(df, blocks), error = function(e) e)
    if (inherits(fit, "condition")) {
      return(list(label = label, lam = rep(NA_real_, T_SP), info = rep(NA_real_, T_SP),
                  rmse = NA_real_, err = conditionMessage(fit)))
    }
    o <- rebuild_obj(fit)
    same_shape <- length(o$par) == length(p_common) &&
      identical(names(o$par), names(p_common))
    info <- rep(NA_real_, T_SP)
    if (same_shape) {
      H <- tryCatch(optimHess(p_common, o$fn, o$gr), error = function(e) NULL)
      if (!is.null(H)) {
        H <- (H + t(H)) / 2
        Hi <- tryCatch(solve(H), error = function(e) NULL)
        idx <- which(names(p_common) == "theta_rr_B")
        if (!is.null(Hi)) info <- 1 / diag(Hi)[idx]
      }
    }
    lam <- par_lambda(fit$opt$par)
    list(label = label, lam = lam, info = info, same_shape = same_shape,
         rmse = lambda_rmse_aligned(lam, PLANTED$Lambda), err = NA_character_)
  }
  list(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed,
       joint = get1(c("block1", "block2"), "joint"),
       b1 = get1("block1", "block1_only"),
       b2 = get1("block2", "block2_only"))
}

if (do_stage("d5")) {
  hr("STAGE d5: arm-stratified information (unique = FALSE uniformly)")
  d5 <- list()
  seeds5 <- 1:60
  for (cl in c("PB", "PP")) {
    for (pv in c(0.1, 0.6)) {
      key <- sprintf("%s_p%.1f", cl, pv)
      rows <- parallel::mclapply(seeds5, function(s)
        tryCatch(arm_information(cl, 400, pv, s), error = function(e) NULL),
        mc.cores = N_CORES)
      rows <- Filter(Negate(is.null), rows)
      d5[[key]] <- rows
      infj <- colMeans(do.call(rbind, lapply(rows, function(z) z$joint$info)), na.rm = TRUE)
      inf1 <- colMeans(do.call(rbind, lapply(rows, function(z) z$b1$info)), na.rm = TRUE)
      inf2 <- colMeans(do.call(rbind, lapply(rows, function(z) z$b2$info)), na.rm = TRUE)
      cat(sprintf("  %-10s  mean info about lambda (species-averaged): joint=%.3g  b1=%.3g  b2=%.3g  (b2 share=%.1f%%)\n",
                  key, mean(infj), mean(inf1), mean(inf2),
                  100 * mean(inf2) / (mean(inf1) + mean(inf2))))
    }
  }
  instr$d5 <- d5; save_instr()
}

## ---- D6: permutation placebo ---------------------------------------------
## Permute the Bernoulli block's responses across units (within species). If
## Lambda-hat is essentially unchanged, the Bernoulli arm was inert and any PASS
## is vacuous. REQUIRED check.
permute_block2 <- function(df, seed) {
  set.seed(seed + 900000L)
  out <- df
  is2 <- out$block == "block2"
  for (sp in levels(out$trait)) {
    k <- which(is2 & out$trait == sp)
    out$value[k] <- out$value[sample(k)]
  }
  for (a in c("cell_type", "fam1", "fam2", "n_units", "prevalence", "t_val", "seed")) {
    attr(out, a) <- attr(df, a)
  }
  out
}

placebo_one <- function(cell, n_units, prevalence, seed, arm = "U1") {
  df <- simulate_cell(cell, n_units, prevalence, seed)
  f0 <- tryCatch(fit_cell(df, arm = arm), error = function(e) e)
  f1 <- tryCatch(fit_cell(permute_block2(df, seed), arm = arm), error = function(e) e)
  g <- function(f) if (inherits(f, "condition")) rep(NA_real_, T_SP) else par_lambda(f$opt$par)
  l0 <- g(f0); l1 <- g(f1)
  data.frame(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed,
             rmse_orig = lambda_rmse_aligned(l0, PLANTED$Lambda),
             rmse_perm = lambda_rmse_aligned(l1, PLANTED$Lambda),
             dist_orig_perm = if (all(is.finite(c(l0, l1)))) lambda_dist(l0, l1) else NA_real_,
             cor_perm = .sign_free_cor(l1, PLANTED$Lambda),
             stringsAsFactors = FALSE)
}

if (do_stage("d6")) {
  hr("STAGE d6: permutation placebo (Bernoulli block permuted across units)")
  d6 <- list()
  for (pv in c(0.1, 0.3, 0.6, 0.9)) {
    rows <- parallel::mclapply(1:60, function(s)
      tryCatch(placebo_one("PB", 400, pv, s), error = function(e) NULL), mc.cores = N_CORES)
    tab <- do.call(rbind, Filter(Negate(is.null), rows))
    d6[[sprintf("p%.1f", pv)]] <- tab
    cat(sprintf("  p=%.1f  rmse_orig=%.4f (MCSE %.4f)  rmse_perm=%.4f (MCSE %.4f)  dist=%.4f (MCSE %.4f)\n",
                pv, mean(tab$rmse_orig, na.rm = TRUE), mcse_mean(tab$rmse_orig),
                mean(tab$rmse_perm, na.rm = TRUE), mcse_mean(tab$rmse_perm),
                mean(tab$dist_orig_perm, na.rm = TRUE), mcse_mean(tab$dist_orig_perm)))
  }
  instr$d6 <- d6; save_instr()
}

## ---- D7: Laplace-accuracy control (AGHQ) ---------------------------------
if (do_stage("d7")) {
  hr("STAGE d7: Laplace-accuracy control via AGHQ")
  d7 <- list()
  probe <- function(cell, n_units, prevalence, seed, arm, aghq_k) {
    ctl <- if (is.null(aghq_k)) NULL else gllvmTMBcontrol(aghq = aghq_k)
    df <- simulate_cell(cell, n_units, prevalence, seed)
    fit <- tryCatch(fit_cell(df, arm = arm, control = ctl), error = function(e) e)
    if (inherits(fit, "condition")) {
      return(data.frame(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed,
                        arm = arm, aghq = ifelse(is.null(aghq_k), 0L, aghq_k),
                        aghq_used = NA, rmse = NA_real_, err = conditionMessage(fit),
                        stringsAsFactors = FALSE))
    }
    ## Read the package's OWN verdict. An earlier version of this probe inferred
    ## "used" from the presence of `k`, which reported TRUE for the U1 arm where
    ## AGHQ had in fact declined to Laplace. `fit$aghq$used` is the only
    ## trustworthy field.
    used <- tryCatch(isTRUE(fit$aghq$used), error = function(e) NA)
    data.frame(cell = cell, n_units = n_units, prevalence = prevalence, seed = seed,
               arm = arm, aghq = ifelse(is.null(aghq_k), 0L, aghq_k), aghq_used = used,
               rmse = lambda_rmse_aligned(par_lambda(fit$opt$par), PLANTED$Lambda),
               err = NA_character_, stringsAsFactors = FALSE)
  }
  ## eligibility probe first (one fit, both arms, k = 5)
  elig <- rbind(probe("PB", 200, 0.1, 1, "U1", 5L), probe("PB", 200, 0.1, 1, "U0", 5L))
  print(elig)
  d7$eligibility <- elig
  ## a raw look at what the fit object records about aghq
  df1 <- simulate_cell("PB", 200, 0.1, 1)
  f_ag <- tryCatch(fit_cell(df1, arm = "U0", control = gllvmTMBcontrol(aghq = 5L)),
                   error = function(e) e)
  d7$aghq_field <- if (inherits(f_ag, "condition")) conditionMessage(f_ag) else utils::capture.output(str(f_ag$aghq))
  cat("fit$aghq (U0, k=5):\n"); print(d7$aghq_field)

  for (arm in c("U1", "U0")) {
    for (pv in c(0.1, 0.6)) {
      rows <- parallel::mclapply(1:40, function(s) {
        rbind(probe("PB", 200, pv, s, arm, NULL), probe("PB", 200, pv, s, arm, 5L))
      }, mc.cores = N_CORES)
      tab <- do.call(rbind, Filter(function(z) is.data.frame(z), rows))
      d7[[sprintf("%s_p%.1f", arm, pv)]] <- tab
      agg <- tapply(tab$rmse, tab$aghq, function(x) c(mean(x, na.rm = TRUE), mcse_mean(x)))
      cat(sprintf("  arm=%s p=%.1f  Laplace RMSE=%.4f (MCSE %.4f)  AGHQ5 RMSE=%.4f (MCSE %.4f)\n",
                  arm, pv, agg[["0"]][1], agg[["0"]][2], agg[["5"]][1], agg[["5"]][2]))
    }
  }
  instr$d7 <- d7; save_instr()
}

cat("\nInstrument stages complete. Saved to", INSTR_RDS, "\n")

## =========================================================================
## STAGE analyse: D1 slopes, boundary rates, tables, and the findings file
## =========================================================================

if (do_stage("analyse")) {
  hr("STAGE analyse")
  source("dev/isdm-gate-analyse.R")
}
