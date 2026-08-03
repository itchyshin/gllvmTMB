## Grace / PART 4: UNCAPPED outer-iteration counts.
## The 10-seed-cell control (eval.max=200, iter.max=100) CENSORS the joint route
## and even the unique=TRUE profiled route -- they return convergence=1 at the
## cap. These are the honest to-convergence counts.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
SCR <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/be8ed294-75c2-464f-89b6-e5bd73d27350/scratchpad"
CTRL <- list(eval.max = 5000L, iter.max = 3000L)

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

go <- function(N0, T0, unq, profiled) {
  cell <- make_cell(N0, T0)
  v <- gllvmTMB:::.va_r3_validate_data(
    y = cell$d$y, n_trials = rep(cell$NTR, nrow(cell$d)), X = cell$X,
    unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
    family = "binomial_probit", link = "probit", unique = unq)
  obj <- gllvmTMB:::.va_r3_make_objective(v, H = 15L, eval_method = "ac",
                                          profile_variational = profiled)
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr, control = CTRL)
  full <- if (profiled) { obj$fn(opt$par); obj$env$last.par } else opt$par
  nm <- names(full); lld <- full[nm == "log_L_diag"]
  Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(full[nm == "theta_rr"], cell$T, cell$q)
  sdt <- full[nm == "log_sd_tier"]; lay <- v$tier_layout
  sds <- c(); rgs <- c(); devs <- c()
  for (k in seq_len(lay$n_tiers)) {
    mo <- lay$m_offset[k]; nk <- lay$n_levels[k]; dk <- lay$dim[k]
    blk <- matrix(lld[mo + seq_len(nk * dk)], nrow = nk, ncol = dk)
    pred <- if (lay$kind[k] == "dense") rep(-0.5*log(1 + cell$NTR*sum(Lam[,1]^2)), dk)
            else -0.5*log(1 + cell$NTR*exp(2*sdt))
    sds <- c(sds, apply(blk, 2, stats::sd))
    rgs <- c(rgs, apply(blk, 2, function(z) diff(range(z))))
    devs <- c(devs, abs(colMeans(blk) - pred))
  }
  data.frame(cell = sprintf("N=%d,T=%d", N0, T0), unique = unq,
             route = if (profiled) "profiled" else "joint",
             npar_outer = length(obj$par), npar_full = length(full),
             iterations = opt$iterations,
             fn = unname(opt$evaluations[["function"]]),
             gr = unname(opt$evaluations[["gradient"]]),
             conv = opt$convergence, objective = opt$objective,
             max_abs_grad = max(abs(obj$gr(opt$par))),
             max_sd_lld = max(sds), max_range_lld = max(rgs),
             max_dev_pred = max(devs), stringsAsFactors = FALSE)
}

jobs <- list(
  list(100L, 10L, FALSE, TRUE), list(100L, 10L, TRUE,  TRUE),
  list(250L, 20L, FALSE, TRUE), list(250L, 20L, TRUE,  TRUE),
  list(100L, 10L, FALSE, FALSE), list(100L, 10L, TRUE,  FALSE),
  list(250L, 20L, FALSE, FALSE))
acc <- list()
for (j in jobs) {
  r <- tryCatch(go(j[[1]], j[[2]], j[[3]], j[[4]]),
                error = function(e) { cat("ERR ", conditionMessage(e), "\n"); NULL })
  if (is.null(r)) next
  print(r, row.names = FALSE); cat("\n")
  acc[[length(acc)+1]] <- r
  saveRDS(do.call(rbind, acc), file.path(SCR, "uncapped.rds"))
}
cat("\n===== FULL TABLE =====\n"); print(do.call(rbind, acc), row.names = FALSE)
cat("\nUNCAPPED_DONE\n")
