## Adversarial check: does the near-exact VA warm start actually reduce
## outer nlminb ITERATION COUNT at the exact matched cell used by the
## 38-41 profiling campaign (N=250, T=20, q=2, binomial-probit, unique=FALSE)?
## The profile's own "large optimizer share (58%) vs small end-to-end saving
## (~13%)" reconciliation is offered as inference, NOT measured. This script
## measures opt$iterations / opt$evaluations directly, cold vs warm-started
## (fixed+loadings+z_B seeded from VA), paired per seed, installed package.
## NOTE: uses devtools::load_all() on the worktree, NOT library(gllvmTMB), because
## the VA warm-start machinery this script exercises (.va_r3_fit's
## family="binomial_probit"/eval_method="ac"/collapse_variational_cov= args, used
## throughout scripts 33-37) does not exist with that signature in the currently
## INSTALLED package on Totoro (confirmed: args(gllvmTMB:::.va_r3_fit) under
## library(gllvmTMB) restricts family to c("binomial","poisson","gaussian_anchor",
## "nbinom2") with no "binomial_probit", eval_method to c("auto","jj","gh") with no
## "ac", and has no collapse_variational_cov argument at all -- the installed
## package ships a materially OLDER va_r3_fit than the worktree). This matches the
## same devtools::load_all(".") approach scripts 33-37 already use, so this script
## is directly comparable to theirs -- but it means the outer nlminb/sdreport
## machinery here is not the byte-identical installed build the 38-41 profile
## campaign tested. Script 38's header asserts the worktree's only uncommitted
## change (R/va-r3-proto.R) does not touch fit-multi.R/MakeADFun/sdreport
## sequencing, so this is expected to be immaterial for THIS script's question
## (outer iteration count) -- but that assertion is not independently
## re-verified here.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

NTR <- 6L; T0 <- 20L; Q0 <- 2L; N0 <- 250L

mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, succ = y, fail = NTR - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))), N = N)
}

run_va <- function(b) gllvmTMB:::.va_r3_fit(
  y = b$d$y, n_trials = rep(NTR, nrow(b$d)), X = b$X,
  unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait), q = Q0,
  family = "binomial_probit", link = "probit",
  unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  collapse_variational_cov = TRUE,
  control = list(eval.max = 800L, iter.max = 400L))

run_la_formula <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE)
run_la_cold <- function(b) gllvmTMB::gllvmTMB(
  run_la_formula, data = b$d, family = binomial(link = "probit"), unit = "unit")

ns <- asNamespace("gllvmTMB")
orig_vgh_build <- get(".vgh_build_warm_start", envir = ns)
va_seed_holder <- new.env()
mock_vgh_build_warm_start <- function(tmb_data, family_name, maxit = 3L, verbose = FALSE) va_seed_holder$seed
patch_on <- function() { unlockBinding(".vgh_build_warm_start", ns); assign(".vgh_build_warm_start", mock_vgh_build_warm_start, envir = ns); lockBinding(".vgh_build_warm_start", ns) }
patch_off <- function() { unlockBinding(".vgh_build_warm_start", ns); assign(".vgh_build_warm_start", orig_vgh_build, envir = ns); lockBinding(".vgh_build_warm_start", ns) }

run_hybrid <- function(b) {
  fva <- run_va(b)
  nm <- names(fva$best$par)
  beta <- unname(fva$best$par[nm == "beta"])
  theta_rr <- unname(fva$best$par[nm == "theta_rr"])
  m_flat <- unname(fva$best$par[nm == "m"])
  z_seed <- t(matrix(m_flat, nrow = b$N, ncol = Q0))
  va_seed_holder$seed <- list(theta_rr = theta_rr, b_fix = beta, z = z_seed, vgh_seconds = NA_real_, vgh_elbo = NA_real_)
  control <- gllvmTMB::gllvmTMBcontrol()
  control$vgh_warm_start <- TRUE
  control$vgh_warm_start_fixed <- TRUE
  control$vgh_warm_start_z <- TRUE
  gllvmTMB::gllvmTMB(run_la_formula, data = b$d, family = binomial(link = "probit"),
                      unit = "unit", control = control)
}

cat("== untimed warm-up ==\n"); flush.console()
wu <- mk(999L, 40L)
invisible(run_la_cold(wu))
patch_on(); invisible(tryCatch(run_hybrid(wu), error = function(e) cat("warmup hybrid err:", conditionMessage(e), "\n"))); patch_off()
cat("== warm-up done ==\n\n"); flush.console()

SEEDS <- 1:4
res <- list()
for (s in SEEDS) {
  b <- mk(s, N0)
  rot <- (s - 1L) %% 2L
  arms <- if (rot == 0) c("LA", "Hybrid") else c("Hybrid", "LA")
  for (arm in arms) {
    la <- loadavg(); t0 <- proc.time()[["elapsed"]]
    if (arm == "LA") {
      f <- run_la_cold(b)
    } else {
      patch_on(); f <- run_hybrid(b); patch_off()
    }
    secs <- proc.time()[["elapsed"]] - t0
    it <- f$opt$iterations; ev <- f$opt$evaluations
    cat(sprintf("seed %d arm %-7s secs %7.3f iterations %5d evaluations %s conv %d load %.2f\n",
                s, arm, secs, it, paste(ev, collapse = "/"), f$opt$convergence, la))
    flush.console()
    res[[length(res) + 1]] <- data.frame(seed = s, arm = arm, secs = secs, iterations = it,
                                          conv = f$opt$convergence, load = la)
  }
}
r <- do.call(rbind, res)
cat("\n--- full table ---\n"); print(r, row.names = FALSE)

cat("\n--- paired deltas (Hybrid - LA), per seed ---\n")
for (s in SEEDS) {
  la_row <- r[r$seed == s & r$arm == "LA", ]
  hy_row <- r[r$seed == s & r$arm == "Hybrid", ]
  cat(sprintf("seed %d: LA iter=%d secs=%.2f | Hybrid iter=%d secs=%.2f | d_iter=%+d d_secs=%+.2f\n",
              s, la_row$iterations, la_row$secs, hy_row$iterations, hy_row$secs,
              hy_row$iterations - la_row$iterations, hy_row$secs - la_row$secs))
}
saveRDS(r, "dev/va-speed/42-iter-count-check-result.rds")
cat("\nDONE.\n")
