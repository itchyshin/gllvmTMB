## Does the warm route's psi collapse come from the BOUNDARY START, as the
## mechanism in 25-WARM-ROUTE-PSI-FINDING.md predicts?
##
## The mechanism says: stage 2 inherits AC's collapsed `log_sd_tier`, and because
## d f/d(log sigma) = (d f/d sigma) * sigma, the gradient there is scaled by sigma
## itself, so psi ~ 0 is a near-flat attractor a local optimiser cannot leave.
##
## If that is right, then handing stage 2 the warm LOADINGS/MEANS but resetting
## ONLY `log_sd_tier` to its ordinary default (log 0.3) should recover psi while
## keeping most of the speed. If psi still collapses, the mechanism is wrong and
## the cause lies elsewhere -- either outcome is informative.
##
## Three arms, interleaved and order-rotated. PROBE, not a promotion.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; PSI <- 0.6
rf <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}
mk <- function(seed) { set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, .8), T0, q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0 * q0), N0, q0); u <- matrix(rnorm(N0 * T0, 0, PSI), N0, T0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, .3), "+") + u
  d <- data.frame(y = rbinom(N0 * T0, NTR, pnorm(as.vector(eta))),
                  unit = rep(1:N0, times = T0), trait = rep(1:T0, each = N0))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = 1:T0))), lam = lam) }
args_for <- function(b) list(y = b$d$y, n_trials = rep(NTR, nrow(b$d)), X = b$X,
  unit_id = b$d$unit, trait_id = b$d$trait, q = q0, family = "binomial_probit",
  link = "probit", unique = TRUE, profile_variational = TRUE)
score <- function(par, b) { L <- gllvmTMB:::.va_r3_unpack_theta_rr(par[names(par) == "theta_rr"], T0, q0)
  list(rf = rf(L %*% t(L), b$lam %*% t(b$lam)), psi = median(exp(par[names(par) == "log_sd_tier"]))) }

## The candidate repair, written out here rather than edited into the package so
## the package stays untouched until this is shown to work.
fit_warm_reset <- function(A, H = 15L, ctl = list(eval.max = 800L, iter.max = 400L),
                           reset = TRUE) {
  ac_args <- A; ac_args$eval_method <- "ac"; ac_args$n_starts <- 1L
  ac_args$H <- H; ac_args$control <- ctl
  ac <- do.call(gllvmTMB:::.va_r3_fit, ac_args)
  start <- ac$best$par
  if (reset) {
    ## Reset ONLY the variance-tier coordinates back off the boundary. The warm
    ## loadings (theta_rr), fixed effects (beta) and variational block are kept.
    idx <- which(names(start) == "log_sd_tier")
    start[idx] <- log(0.3)
  }
  vd <- do.call(gllvmTMB:::.va_r3_validate_data,
                A[intersect(names(A), names(formals(gllvmTMB:::.va_r3_validate_data)))])
  obj <- gllvmTMB:::.va_r3_make_objective(vd, H = H, eval_method = "gh")
  stopifnot(identical(names(obj$par), names(start)))
  fit <- stats::nlminb(start = start, objective = obj$fn, gradient = obj$gr, control = ctl)
  list(best = list(par = fit$par, objective = fit$objective,
                   iterations = fit$iterations, convergence = fit$convergence))
}

cat(sprintf("%-5s %-11s %8s %6s %10s %9s %9s %6s\n",
            "seed", "arm", "secs", "iters", "objective", "rel_frob", "psi", "load"))
res <- list(); ARMS <- c("cold", "warm", "warm_reset")
for (s in 1:3) {
  b <- mk(s); A <- args_for(b)
  ord <- ARMS[(( seq_along(ARMS) + s - 2L) %% length(ARMS)) + 1L]  # rotate order by seed
  for (arm in ord) {
    la <- loadavg(); t0 <- proc.time()[["elapsed"]]
    f <- switch(arm,
      cold = do.call(gllvmTMB:::.va_r3_fit, c(A, list(eval_method = "gh", n_starts = 1L,
              H = 15L, control = list(eval.max = 800L, iter.max = 400L)))),
      warm = fit_warm_reset(A, reset = FALSE),
      warm_reset = fit_warm_reset(A, reset = TRUE))
    secs <- proc.time()[["elapsed"]] - t0
    sc <- score(f$best$par, b)
    cat(sprintf("%-5d %-11s %8.1f %6s %10.2f %9.5f %9.4f %6.1f\n", s, arm, secs,
        paste(f$best$iterations, collapse = ","), f$best$objective, sc$rf, sc$psi, la))
    flush.console()
    res[[length(res) + 1]] <- data.frame(seed = s, arm = arm, secs = secs,
      obj = f$best$objective, rf = sc$rf, psi = sc$psi, load = la)
  }
}
r <- do.call(rbind, res)
cat("\n--- medians by arm ---\n")
print(aggregate(cbind(secs, obj, rf, psi) ~ arm, r, median), row.names = FALSE, digits = 6)
cat(sprintf("\ntruth psi = %.1f\n", PSI))
cat("\nDoes the reset recover psi? ",
    if (median(r$psi[r$arm == "warm_reset"]) > 0.3) "YES -- mechanism CONFIRMED"
    else "NO -- mechanism WRONG, cause lies elsewhere", "\n")
cat(sprintf("speed vs cold: warm %.1fx, warm_reset %.1fx\n",
            median(r$secs[r$arm == "cold"]) / median(r$secs[r$arm == "warm"]),
            median(r$secs[r$arm == "cold"]) / median(r$secs[r$arm == "warm_reset"])))
cat(sprintf("load median %.1f, spread %.1f; other R procs at close: %d\n",
            median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE)),
            {ps <- system("ps ax -o pid=,command=", intern = TRUE)
             h <- grep("^\\s*[0-9]+\\s+\\S*/bin/exec/R\\b", ps, value = TRUE)
             sum(as.integer(sub("^\\s*([0-9]+).*$", "\\1", h)) != Sys.getpid(), na.rm = TRUE)}))
cat("\nRESET_PROBE_DONE\n")
