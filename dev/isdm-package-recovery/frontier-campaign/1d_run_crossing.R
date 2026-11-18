## Domain-growth campaign (A2) -- one process = one (scale, E, rep-chunk).
## Usage: Rscript 1c_run_domain.R <bundle_sX.rds> <outdir> <E> <rep_from> <rep_to>
suppressMessages({library(TMB); library(Matrix)})

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5)
b <- readRDS(args[1]); outdir <- args[2]
E <- as.numeric(args[3]); rep_from <- as.integer(args[4]); rep_to <- as.integer(args[5])
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

S_LEVELS <- c(2.5, 3, 4, 5.5, 7.5); E_LEVELS <- c(1, 2)
s_index <- match(b$scale, S_LEVELS); E_index <- match(E, E_LEVELS)
stopifnot(!is.na(s_index), !is.na(E_index))
K <- b$constants
lam_true <- b$truth$lambda_bias; q_true <- b$truth$q
dyn.load(TMB::dynlib("gllvmTMB"))

sub_seeds <- function(base) { set.seed(base); sample.int(.Machine$integer.max, 5L) }
node_draw <- function(seed) {
  set.seed(seed); as.double(backsolve(b$chol_q, rnorm(nrow(b$chol_q))))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

run_one <- function(rep) {
  base <- 20260818L + 100000L * s_index + 10000L * E_index + rep
  sd5  <- sub_seeds(base)
  t_all <- proc.time()[3]
  row <- list(schema = "PAPER1_CROSSING_A3_ROW_V1",
              scale = b$scale, n_cell = b$n_cell, n_nodes = b$n_nodes,
              E = E, rep = rep, base_seed = base,
              q_true = q_true, lam_norm_true = sqrt(sum(lam_true^2)),
              error = NA_character_)
  out <- tryCatch({
    unit_eco  <- b$c_use * as.double(b$A_cells %*% node_draw(sd5[1]))
    unit_bias <- b$c_use * as.double(b$A_cells %*% node_draw(sd5[2]))
    set.seed(sd5[3])
    resid <- sapply(K$psi_sd, function(sd) rnorm(b$n_cell, sd = sd))
    eta_e_cs <- sweep(outer(b$x_cell, K$beta), 2L, K$alpha, "+") +
      outer(unit_eco, K$v_ecological) + resid
    eta_b_cs <- outer(unit_bias, K$v_bias)
    eta_e <- eta_e_cs[cbind(b$cellIx, b$spIx)]
    eta_b <- eta_b_cs[cbind(b$cellIx, b$spIx)]
    fb    <- b$b_cell[b$cellIx] * b$gamma_row
    fb[!b$gbif] <- 0
    dE <- b$data
    mu_g <- E * b$support * exp(eta_e + fb + eta_b)
    set.seed(sd5[4]); yg <- rpois(sum(b$gbif), mu_g[b$gbif])
    set.seed(sd5[5]); yp <- rbinom(sum(!b$gbif), 1L,
                                   -expm1(-b$support[!b$gbif] * exp(eta_e[!b$gbif])))
    dE$y[b$gbif]  <- as.double(yg); dE$y[!b$gbif] <- as.double(yp)
    dE$offset_vec[b$gbif] <- b$data$offset_vec[b$gbif] + log(E)

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
    sign_flip <- sum(lam * lam_true) < 0
    if (sign_flip) lam <- -lam
    list(conv = opt$convergence, objective = opt$objective,
         iterations = opt$iterations, time_fit = t_fit,
         theta = th, se = se, max_g = max(abs(g)),
         pd_fd = all(ev > 0), min_ev = min(ev), sign_flip = sign_flip,
         lam_norm = sqrt(sum(lam^2)),
         cos_truth = sum(lam * lam_true) /
           (sqrt(sum(lam^2)) * sqrt(sum(lam_true^2))),
         gamma_hat = th[10:12], q_hat = th[16],
         counts_gbif = sum(yg))
  }, error = function(e) { row$error <<- conditionMessage(e); NULL })
  row <- c(row, out %||% list())
  row$time_total <- proc.time()[3] - t_all
  ## A3 pre-run criterion (iii): per-process peak RSS from /proc (Linux)
  row$rss_hwm_mb <- tryCatch({
    v <- grep("VmHWM", readLines("/proc/self/status"), value = TRUE)
    as.numeric(gsub("[^0-9]", "", v)) / 1024
  }, error = function(e) NA_real_)
  saveRDS(row, file.path(outdir, sprintf("s%s_E%s_rep%03d.rds",
                                         format(b$scale), format(E), rep)))
  row
}

for (rp in rep_from:rep_to) {
  row <- run_one(rp)
  cat(sprintf("s=%g E=%g rep=%d | %s | conv %s | %5.1fs | pd %s | ||lam|| %s (truth %.2f) | cos %s | q %s\n",
      b$scale, E, rp, if (is.na(row$error)) "ok" else paste("ERROR:", row$error),
      row$conv %||% "-", row$time_total %||% NA, row$pd_fd %||% "-",
      if (!is.null(row$lam_norm)) sprintf("%.3f", row$lam_norm) else "-",
      row$lam_norm_true,
      if (!is.null(row$cos_truth)) sprintf("%.3f", row$cos_truth) else "-",
      if (!is.null(row$q_hat)) sprintf("%.4f", row$q_hat) else "-"))
}
