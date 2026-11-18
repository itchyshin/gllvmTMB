## Frontier campaign -- stage 1: one replicate = one fit = one RDS row.
## Usage:  Rscript 1_run_frontier.R <bundle.rds> <outdir> <E> <rep_from> <rep_to>
## Fields, residuals, and responses are REDRAWN per replicate (design D.2).
## Seed scheme (design): base = 20260815 + 10000*level_index + rep; five
## sub-streams drawn deterministically from the base.
suppressMessages({library(TMB); library(Matrix)})

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 5)
bundle <- readRDS(args[1]); outdir <- args[2]
E <- as.numeric(args[3]); rep_from <- as.integer(args[4]); rep_to <- as.integer(args[5])
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

LEVELS <- c(0.5, 1, 1.5, 2, 3, 4, 8, 16)
level_index <- match(E, LEVELS); stopifnot(!is.na(level_index))

b <- bundle; K <- b$constants
dyn.load(TMB::dynlib("gllvmTMB"))

sub_seeds <- function(base) { set.seed(base); sample.int(.Machine$integer.max, 5L) }
node_draw <- function(seed) {
  set.seed(seed); as.double(backsolve(b$chol_q, rnorm(nrow(b$chol_q))))
}

run_one <- function(E, rep) {
  base <- 20260815L + 10000L * level_index + rep
  sd5  <- sub_seeds(base)
  t_all <- proc.time()[3]
  row <- list(schema = "PAPER1_GBIF_EFFORT_FRONTIER_V1_ROW_V1",
              E = E, rep = rep, base_seed = base, sub_seeds = sd5,
              error = NA_character_)
  out <- tryCatch({
    unit_eco  <- b$c_ref * as.double(b$A_unique %*% node_draw(sd5[1]))
    unit_bias <- b$c_ref * as.double(b$A_unique %*% node_draw(sd5[2]))
    set.seed(sd5[3])
    resid <- sapply(K$psi_sd, function(sd) rnorm(b$n_cells, sd = sd))
    eta_e_cs <- sweep(outer(b$x_cell, K$beta), 2L, K$alpha, "+") +
      outer(unit_eco, K$v_ecological) + resid
    eta_b_cs <- outer(unit_bias, K$v_bias)
    eta_e <- eta_e_cs[cbind(b$cellIx, b$spIx)]
    eta_b <- eta_b_cs[cbind(b$cellIx, b$spIx)]
    fb    <- b$b_cell[b$cellIx] * b$gamma_row
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

    t_h <- proc.time()[3]
    hs <- .Machine$double.eps^(1/3) * pmax(1, abs(th))
    H <- matrix(0, 22, 22)
    for (j in 1:22) {
      tp <- th; tp[j] <- tp[j] + hs[j]; tm <- th; tm[j] <- tm[j] - hs[j]
      H[, j] <- (as.vector(obj$gr(tp)) - as.vector(obj$gr(tm))) / (2 * hs[j])
    }
    H <- (H + t(H)) / 2; t_h <- proc.time()[3] - t_h
    ev  <- eigen(H, symmetric = TRUE, only.values = TRUE)$values
    evS <- eigen(H[20:22, 20:22], symmetric = TRUE, only.values = TRUE)$values

    t_sd <- proc.time()[3]
    sdr <- tryCatch(sdreport(obj, getJointPrecision = FALSE), error = function(e) NULL)
    t_sd <- proc.time()[3] - t_sd
    se <- if (!is.null(sdr)) sqrt(diag(sdr$cov.fixed)) else rep(NA_real_, 22)
    pd_sdr <- if (!is.null(sdr)) isTRUE(sdr$pdHess) else NA

    lam <- th[20:22]
    sign_flip <- sum(lam * b$truth$lambda_bias) < 0
    if (sign_flip) lam <- -lam
    list(conv = opt$convergence, objective = opt$objective,
         iterations = opt$iterations, time_fit = t_fit, time_hess = t_h,
         time_sdreport = t_sd, theta = th, se = se, max_g = max(abs(g)),
         pd_fd = all(ev > 0), pd_sdr = pd_sdr, min_ev = min(ev),
         min_ev_slope = min(evS), sign_flip = sign_flip,
         lam_norm = sqrt(sum(lam^2)),
         cos_truth = sum(lam * b$truth$lambda_bias) /
           (sqrt(sum(lam^2)) * sqrt(sum(b$truth$lambda_bias^2))),
         gamma_hat = th[10:12], q_hat = th[16],
         counts_gbif = sum(yg), session = utils::sessionInfo()$R.version$version.string)
  }, error = function(e) { row$error <<- conditionMessage(e); NULL })
  row <- c(row, out %||% list())
  row$time_total <- proc.time()[3] - t_all
  saveRDS(row, file.path(outdir, sprintf("E%s_rep%03d.rds", format(E), rep)))
  row
}
`%||%` <- function(a, b) if (is.null(a)) b else a

for (r in rep_from:rep_to) {
  row <- run_one(E, r)
  cat(sprintf("E=%g rep=%d | %s | conv %s | fit %.1fs hess %.1fs sdr %.1fs | pd_fd %s | ||lam|| %s | cos %s | q %s | counts %s\n",
      E, r,
      if (is.na(row$error)) "ok" else paste("ERROR:", row$error),
      row$conv %||% "-", row$time_fit %||% NA, row$time_hess %||% NA,
      row$time_sdreport %||% NA,
      row$pd_fd %||% "-",
      if (!is.null(row$lam_norm)) sprintf("%.3f", row$lam_norm) else "-",
      if (!is.null(row$cos_truth)) sprintf("%.3f", row$cos_truth) else "-",
      if (!is.null(row$q_hat)) sprintf("%.4f", row$q_hat) else "-",
      row$counts_gbif %||% "-"))
}
writeLines(capture.output(sessionInfo()), file.path(outdir, "sessionInfo.txt"))
