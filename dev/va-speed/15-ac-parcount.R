## Grace / structural profile of the Albert-Chib VA tier.
## PART 1: parameter counts only. No fitting, no timing.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

make_cell <- function(N0, T0, q0 = 1L, NTR = 6L, seed = 1L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                    trait = rep(seq_len(T0), each = N0))
  X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  list(d = d, X = X, N = N0, T = T0, q = q0, NTR = NTR,
       Sigma_true = lam %*% t(lam))
}

val_of <- function(cell, unique) {
  gllvmTMB:::.va_r3_validate_data(
    y = cell$d$y, n_trials = rep(cell$NTR, nrow(cell$d)), X = cell$X,
    unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
    family = "binomial_probit", link = "probit", unique = unique)
}

grid <- expand.grid(N = c(100L, 250L), unique = c(TRUE, FALSE))
grid$T <- ifelse(grid$N == 100L, 10L, 20L)

out <- list()
for (i in seq_len(nrow(grid))) {
  cell <- make_cell(grid$N[i], grid$T[i])
  v <- val_of(cell, grid$unique[i])
  obj_joint <- gllvmTMB:::.va_r3_make_objective(v, H = 15L, eval_method = "ac")
  obj_prof  <- gllvmTMB:::.va_r3_make_objective(v, H = 15L, eval_method = "ac",
                                                profile_variational = TRUE)
  tj <- table(names(obj_joint$par))
  tp <- table(names(obj_prof$par))
  lay <- v$tier_layout
  cat("\n================================================================\n")
  cat(sprintf("CELL  N=%d T=%d q=%d  unique=%s  n_trials=%d\n",
              grid$N[i], grid$T[i], cell$q, grid$unique[i], cell$NTR))
  cat(sprintf("tiers: %s | dim=%s | n_levels=%s | var_per_level=%s\n",
              paste(lay$label, collapse = "+"), paste(lay$dim, collapse = ","),
              paste(lay$n_levels, collapse = ","),
              paste(lay$variational_per_level, collapse = ",")))
  cat("-- JOINT objective (profile_variational = FALSE): obj$par --\n")
  print(tj); cat("TOTAL =", length(obj_joint$par), "\n")
  cat("-- PROFILED objective (profile_variational = TRUE): obj$par (outer only) --\n")
  print(tp); cat("TOTAL =", length(obj_prof$par), "\n")
  cat("-- inner/profiled block size =", length(obj_joint$par) - length(obj_prof$par), "\n")
  out[[i]] <- list(N = grid$N[i], T = grid$T[i], unique = grid$unique[i],
                   joint = tj, prof = tp,
                   n_joint = length(obj_joint$par), n_prof = length(obj_prof$par),
                   layout = lay[c("label","dim","n_levels","variational_per_level",
                                  "total_mean","total_off","total_theta","total_sd")])
}
saveRDS(out, "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/be8ed294-75c2-464f-89b6-e5bd73d27350/scratchpad/parcount.rds")
cat("\nPARCOUNT_DONE\n")
