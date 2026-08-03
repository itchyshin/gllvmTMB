## Grace / PART 2: outer-iteration counts and the log_L_diag collapse test.
## COUNTS ONLY -- no wall-clock is reported anywhere.
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

CTRL <- list(eval.max = 200L, iter.max = 100L)   # the 10-seed-cell control

run_one <- function(N0, T0, unq, profiled) {
  cell <- make_cell(N0, T0)
  v <- gllvmTMB:::.va_r3_validate_data(
    y = cell$d$y, n_trials = rep(cell$NTR, nrow(cell$d)), X = cell$X,
    unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
    family = "binomial_probit", link = "probit", unique = unq)
  obj <- gllvmTMB:::.va_r3_make_objective(
    v, H = 15L, eval_method = "ac", profile_variational = profiled)
  npar <- length(obj$par)
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr, control = CTRL)
  ## full parameter vector, variational block included
  full <- if (profiled) { obj$fn(opt$par); obj$env$last.par } else opt$par
  gr <- obj$gr(opt$par)
  lay <- v$tier_layout
  nm <- names(full)
  lld <- full[nm == "log_L_diag"]
  th  <- full[nm == "theta_rr"]
  sdt <- full[nm == "log_sd_tier"]
  Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(th, cell$T, cell$q)

  tiers <- list()
  for (k in seq_len(lay$n_tiers)) {
    mo <- lay$m_offset[k]; nk <- lay$n_levels[k]; dk <- lay$dim[k]
    blk <- matrix(lld[mo + seq_len(nk * dk)], nrow = nk, ncol = dk) # level fast, coord slow
    ## (4.1) prediction: 1/s^2 = 1 + sum_j n_ij (loading_j)^2 on that coordinate
    pred <- if (lay$kind[k] == "dense") {
      rep(-0.5 * log(1 + cell$NTR * sum(Lam[, 1]^2)), dk)      # q = 1
    } else {
      -0.5 * log(1 + cell$NTR * exp(2 * sdt)^1)                # sd_t^2 = exp(2*log_sd)
    }
    tiers[[k]] <- data.frame(
      cell = sprintf("N=%d,T=%d", N0, T0), unique = unq,
      route = if (profiled) "profiled" else "joint",
      tier = lay$label[k], kind = lay$kind[k], dim = dk, n_levels = nk,
      coord = seq_len(dk),
      mean = apply(blk, 2, mean), sd = apply(blk, 2, stats::sd),
      min = apply(blk, 2, min), max = apply(blk, 2, max),
      range = apply(blk, 2, function(z) diff(range(z))),
      pred_4_1 = pred,
      abs_dev_from_pred = abs(apply(blk, 2, mean) - pred),
      stringsAsFactors = FALSE)
  }
  list(
    hdr = data.frame(
      cell = sprintf("N=%d,T=%d", N0, T0), unique = unq,
      route = if (profiled) "profiled" else "joint",
      npar_outer = npar, npar_full = length(full),
      iterations = opt$iterations,
      eval_fn = unname(opt$evaluations[["function"]]),
      eval_gr = unname(opt$evaluations[["gradient"]]),
      convergence = opt$convergence, objective = opt$objective,
      max_abs_grad = max(abs(gr)), stringsAsFactors = FALSE),
    tiers = do.call(rbind, tiers))
}

grid <- rbind(
  expand.grid(N = 100L, unq = c(TRUE, FALSE), profiled = c(TRUE, FALSE)),
  expand.grid(N = 250L, unq = c(TRUE, FALSE), profiled = c(TRUE, FALSE)))
grid$T <- ifelse(grid$N == 100L, 10L, 20L)
## put the 10,560-parameter joint fit last so everything else lands first
grid$big <- grid$N == 250L & grid$unq & !grid$profiled
grid <- grid[order(grid$big, grid$profiled == FALSE, grid$N), ]

H <- list(); TT <- list()
for (i in seq_len(nrow(grid))) {
  lab <- sprintf("N=%d T=%d unique=%s route=%s", grid$N[i], grid$T[i],
                 grid$unq[i], if (grid$profiled[i]) "profiled" else "joint")
  cat("\n########## ", lab, "\n", sep = "")
  r <- tryCatch(run_one(grid$N[i], grid$T[i], grid$unq[i], grid$profiled[i]),
                error = function(e) { cat("ERROR: ", conditionMessage(e), "\n"); NULL })
  if (is.null(r)) next
  print(r$hdr, row.names = FALSE)
  cat("-- log_L_diag spread across units, per tier-coordinate --\n")
  tt <- r$tiers
  show <- tt[, c("tier","coord","mean","sd","range","pred_4_1","abs_dev_from_pred")]
  if (nrow(show) > 8) { print(utils::head(show, 4), row.names = FALSE)
                        cat("   ... (", nrow(show), " coords total)\n", sep="")
                        print(utils::tail(show, 2), row.names = FALSE) }
  else print(show, row.names = FALSE)
  cat(sprintf("   MAX sd across all coords = %.3e | MAX range = %.3e | MAX |mean-pred(4.1)| = %.3e\n",
              max(tt$sd), max(tt$range), max(tt$abs_dev_from_pred)))
  H[[length(H)+1]] <- r$hdr; TT[[length(TT)+1]] <- tt
  saveRDS(list(hdr = do.call(rbind, H), tiers = do.call(rbind, TT)),
          file.path(SCR, "fitcount.rds"))
}
cat("\nFITCOUNT_DONE\n")
