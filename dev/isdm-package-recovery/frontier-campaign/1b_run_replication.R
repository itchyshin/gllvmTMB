## Replication-axis campaign (design Amendment A1) -- one process = one (r, E, rep-chunk).
## Usage: Rscript 1b_run_replication.R <bundle.rds> <outdir> <r> <E> <rep_from> <rep_to>
## Range r varied on the FROZEN grid/mesh; c_ref(r) keeps predictor-scale truth
## constant; per-level truth recomputed from constants, never transcribed.
suppressMessages({library(TMB); library(Matrix)})

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 6)
bundle <- readRDS(args[1]); outdir <- args[2]
r <- as.numeric(args[3]); E <- as.numeric(args[4])
rep_from <- as.integer(args[5]); rep_to <- as.integer(args[6])
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

R_LEVELS <- c(0.22, 0.165, 0.132, 0.11); E_LEVELS <- c(1, 2, 4)
r_index <- match(r, R_LEVELS); E_index <- match(E, E_LEVELS)
stopifnot(!is.na(r_index), !is.na(E_index))

b <- bundle; K <- b$constants; d0 <- b$data
dyn.load(TMB::dynlib("gllvmTMB"))

## ---- per-level truth and validation gate (amendment A1, discrete-anchored) ----
## The continuum normalisation c_ref = sqrt(4 pi) kappa drifts on a FIXED mesh
## as r shrinks (the gate caught SD 0.795 at r = 0.132). The field scale is
## therefore anchored to the MEASURED discrete cell-level marginal SD, exactly
## computed, with c_use(anchor) == c_ref so the anchor remains continuous with
## the sealed convention and the effort campaign.
disc_sd <- function(rr) {
  kk <- sqrt(8) / rr
  Q  <- kk^4 * d0$spde_M0 + 2 * kk^2 * d0$spde_M1 + d0$spde_M2
  ch <- tryCatch(chol(as.matrix(Q)), error = function(e) stop(
    sprintf("A1 gate (i) FAIL at r=%g: %s", rr, conditionMessage(e)), call. = FALSE))
  Qi <- chol2inv(ch)
  V_cell <- rowSums((b$A_unique %*% Qi) * b$A_unique)   # exact marginal variances
  list(chol = ch, kappa = kk, sd_cell = sqrt(mean(V_cell)))
}
anchor <- disc_sd(0.22)
target_sd <- sqrt(4 * pi) * anchor$kappa * anchor$sd_cell   # anchor realized unit SD
lvl <- disc_sd(r)
chol_r  <- lvl$chol
kappa_r <- lvl$kappa
c_use_r <- target_sd / lvl$sd_cell
rho_r   <- (sqrt(4 * pi) * kappa_r * lvl$sd_cell) / target_sd  # continuum drift factor
lam_bias_true <- c_use_r * unname(K$v_bias)
q_true <- log(kappa_r)
cat(sprintf(
  "A1 gates PASS r=%g: kappa=%.3f c_use=%.3f (continuum drift rho=%.3f) ||lam_bias||=%.3f q=%.4f target_SD=%.4f\n",
  r, kappa_r, c_use_r, rho_r, sqrt(sum(lam_bias_true^2)), q_true, target_sd))
c_ref_r <- c_use_r  # downstream code uses c_ref_r as the field scale

sub_seeds <- function(base) { set.seed(base); sample.int(.Machine$integer.max, 5L) }
node_draw <- function(seed) {
  set.seed(seed); as.double(backsolve(chol_r, rnorm(nrow(chol_r))))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

run_one <- function(rep) {
  base <- 20260816L + 100000L * r_index + 10000L * E_index + rep
  sd5  <- sub_seeds(base)
  t_all <- proc.time()[3]
  row <- list(schema = "PAPER1_REPLICATION_AXIS_A1_ROW_V1",
              r = r, E = E, rep = rep, base_seed = base,
              q_true = q_true, lam_norm_true = sqrt(sum(lam_bias_true^2)),
              error = NA_character_)
  out <- tryCatch({
    unit_eco  <- c_ref_r * as.double(b$A_unique %*% node_draw(sd5[1]))
    unit_bias <- c_ref_r * as.double(b$A_unique %*% node_draw(sd5[2]))
    set.seed(sd5[3])
    resid <- sapply(K$psi_sd, function(sd) rnorm(b$n_cells, sd = sd))
    eta_e_cs <- sweep(outer(b$x_cell, K$beta), 2L, K$alpha, "+") +
      outer(unit_eco, K$v_ecological) + resid
    eta_b_cs <- outer(unit_bias, K$v_bias)
    eta_e <- eta_e_cs[cbind(b$cellIx, b$spIx)]
    eta_b <- eta_b_cs[cbind(b$cellIx, b$spIx)]
    fb    <- b$b_cell[b$cellIx] * b$gamma_row
    dE <- d0
    mu_g <- E * b$support * exp(eta_e + fb + eta_b)
    set.seed(sd5[4]); yg <- rpois(sum(b$gbif), mu_g[b$gbif])
    set.seed(sd5[5]); yp <- rbinom(sum(!b$gbif), 1L,
                                   -expm1(-b$support[!b$gbif] * exp(eta_e[!b$gbif])))
    dE$y[b$gbif]  <- as.double(yg); dE$y[!b$gbif] <- as.double(yp)
    dE$offset_vec[b$gbif] <- d0$offset_vec[b$gbif] + log(E)

    obj <- MakeADFun(data = dE, parameters = b$parameters, map = b$map,
                     random = b$random, DLL = "gllvmTMB", silent = TRUE)
    t_fit <- proc.time()[3]
    opt <- nlminb(obj$par, obj$fn, obj$gr,
                  control = list(iter.max = 500, eval.max = 1000))
    t_fit <- proc.time()[3] - t_fit
    th <- opt$par; g <- as.vector(obj$gr(th))
    hs <- .Machine$double.eps^(1/3) * pmax(1, abs(th))
    H <- matrix(0, 22, 22)
    for (j in 1:22) {
      tp <- th; tp[j] <- tp[j] + hs[j]; tm <- th; tm[j] <- tm[j] - hs[j]
      H[, j] <- (as.vector(obj$gr(tp)) - as.vector(obj$gr(tm))) / (2 * hs[j])
    }
    H <- (H + t(H)) / 2
    ev <- eigen(H, symmetric = TRUE, only.values = TRUE)$values
    sdr <- tryCatch(sdreport(obj, getJointPrecision = FALSE), error = function(e) NULL)
    se <- if (!is.null(sdr)) sqrt(diag(sdr$cov.fixed)) else rep(NA_real_, 22)
    lam <- th[20:22]
    sign_flip <- sum(lam * lam_bias_true) < 0
    if (sign_flip) lam <- -lam
    list(conv = opt$convergence, objective = opt$objective,
         iterations = opt$iterations, time_fit = t_fit,
         theta = th, se = se, max_g = max(abs(g)),
         pd_fd = all(ev > 0), min_ev = min(ev), sign_flip = sign_flip,
         lam_norm = sqrt(sum(lam^2)),
         cos_truth = sum(lam * lam_bias_true) /
           (sqrt(sum(lam^2)) * sqrt(sum(lam_bias_true^2))),
         gamma_hat = th[10:12], q_hat = th[16],
         counts_gbif = sum(yg))
  }, error = function(e) { row$error <<- conditionMessage(e); NULL })
  row <- c(row, out %||% list())
  row$time_total <- proc.time()[3] - t_all
  saveRDS(row, file.path(outdir, sprintf("r%s_E%s_rep%03d.rds",
                                         format(r), format(E), rep)))
  row
}

for (rp in rep_from:rep_to) {
  row <- run_one(rp)
  cat(sprintf("r=%g E=%g rep=%d | %s | conv %s | pd %s | ||lam|| %s (truth %.2f) | cos %s | q %s (truth %.3f)\n",
      r, E, rp, if (is.na(row$error)) "ok" else paste("ERROR:", row$error),
      row$conv %||% "-", row$pd_fd %||% "-",
      if (!is.null(row$lam_norm)) sprintf("%.3f", row$lam_norm) else "-",
      row$lam_norm_true,
      if (!is.null(row$cos_truth)) sprintf("%.3f", row$cos_truth) else "-",
      if (!is.null(row$q_hat)) sprintf("%.4f", row$q_hat) else "-", row$q_true))
}
