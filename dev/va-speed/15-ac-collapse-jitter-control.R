## Grace / PART 3: THE CONFOUND CONTROL.
## .va_r3_default_parameters(start_id = 1) sets log_L_diag = rep(0, n_mean) --
## IDENTICAL for every unit. A symmetric start could in principle be preserved
## by a symmetric optimiser, so "they agree at the end" would prove nothing.
## Here every unit gets a DIFFERENT starting log_L_diag (and a different m), on
## the JOINT route (profile_variational = FALSE) so no inner Newton solver can
## impose structure. If they reconverge to one value per tier-coordinate, the
## collapse is a property of the OPTIMUM, not of the start.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
SCR <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/be8ed294-75c2-464f-89b6-e5bd73d27350/scratchpad"

make_cell <- function(N0, T0, q0 = 1L, NTR = 6L, seed = 1L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                    trait = rep(seq_len(T0), each = N0))
  X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  list(d = d, X = X, N = N0, T = T0, q = q0, NTR = NTR)
}

run_jit <- function(N0, T0, unq, jit_sd = 0.5) {
  cell <- make_cell(N0, T0)
  v <- gllvmTMB:::.va_r3_validate_data(
    y = cell$d$y, n_trials = rep(cell$NTR, nrow(cell$d)), X = cell$X,
    unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
    family = "binomial_probit", link = "probit", unique = unq)
  p <- gllvmTMB:::.va_r3_default_parameters(v, 1L)
  set.seed(99L)
  p$log_L_diag <- rnorm(length(p$log_L_diag), 0, jit_sd)  # PER-UNIT, asymmetric
  p$m          <- rnorm(length(p$m), 0, 0.3)
  start_sd <- stats::sd(p$log_L_diag)
  obj <- gllvmTMB:::.va_r3_make_objective(v, H = 15L, eval_method = "ac",
                                          parameters = p,
                                          profile_variational = FALSE)
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr,
                       control = list(eval.max = 3000L, iter.max = 1500L))
  full <- opt$par; nm <- names(full)
  lld <- full[nm == "log_L_diag"]
  Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(full[nm == "theta_rr"], cell$T, cell$q)
  sdt <- full[nm == "log_sd_tier"]
  lay <- v$tier_layout
  cat(sprintf("\n## N=%d T=%d unique=%s  JOINT route, ASYMMETRIC start (sd(log_L_diag@start)=%.3f)\n",
              N0, T0, unq, start_sd))
  cat(sprintf("   npar=%d  iterations=%d  fn=%d  gr=%d  conv=%d  obj=%.6f  max|grad|=%.3e\n",
              length(obj$par), opt$iterations, opt$evaluations[["function"]],
              opt$evaluations[["gradient"]], opt$convergence, opt$objective,
              max(abs(obj$gr(opt$par)))))
  res <- list()
  for (k in seq_len(lay$n_tiers)) {
    mo <- lay$m_offset[k]; nk <- lay$n_levels[k]; dk <- lay$dim[k]
    blk <- matrix(lld[mo + seq_len(nk * dk)], nrow = nk, ncol = dk)
    pred <- if (lay$kind[k] == "dense") rep(-0.5*log(1 + cell$NTR*sum(Lam[,1]^2)), dk)
            else -0.5*log(1 + cell$NTR*exp(2*sdt))
    res[[k]] <- data.frame(tier = lay$label[k], coord = seq_len(dk),
                           mean = colMeans(blk), sd = apply(blk, 2, stats::sd),
                           range = apply(blk, 2, function(z) diff(range(z))),
                           pred_4_1 = pred,
                           dev = abs(colMeans(blk) - pred))
  }
  r <- do.call(rbind, res)
  print(if (nrow(r) > 6) rbind(head(r, 3), tail(r, 2)) else r, row.names = FALSE)
  cat(sprintf("   START sd = %.3e  ->  FINAL max sd across coords = %.3e | max range = %.3e | max |mean - pred(4.1)| = %.3e\n",
              start_sd, max(r$sd), max(r$range), max(r$dev)))
  invisible(r)
}

out <- list()
for (unq in c(FALSE, TRUE)) out[[as.character(unq)]] <- run_jit(100L, 10L, unq)
saveRDS(out, file.path(SCR, "jitter.rds"))
cat("\nJITTER_DONE\n")
