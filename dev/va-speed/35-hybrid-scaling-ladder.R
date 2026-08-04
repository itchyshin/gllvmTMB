## Does the VA->LA hybrid's saving GROW with N*q, as the LA-stage inner solve
## comes to dominate cost? Four arms per cell: VA alone, cold LA, hybrid
## (fixed-params-only, script 33's route), hybrid (fixed + z_B modes, script
## 34's route). Paired, interleaved, order-rotated across the four arms within
## each seed; untimed warm-up; load recorded; hybrid time INCLUDES the VA fit.
##
## Reports the quantity that actually bounds the hybrid: percent of the LA
## STAGE saved (cold-LA time vs. the hybrid's internal warm-started-gllvmTMB()
## call alone, excluding the VA sub-fit), alongside end-to-end speedup, at
## every (N, q) rung. Landed-on-optimum is checked at every rung, every seed.
##
## One (N, q) rung per process invocation (env vars LAD_N, LAD_Q), so the
## Totoro deploy can run several rungs in PARALLEL as separate single-threaded
## processes (well within the <=150-core budget) instead of serially.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

T0 <- 20L; NTR <- 6L
N0 <- as.integer(Sys.getenv("LAD_N", "250"))
Q0 <- as.integer(Sys.getenv("LAD_Q", "2"))
SEEDS <- seq_len(as.integer(Sys.getenv("LAD_SEEDS", "3")))
CAP <- as.numeric(Sys.getenv("LAD_CAP", "3600"))   ## per-arm setTimeLimit, seconds
OUT_RDS <- Sys.getenv("LAD_OUT", sprintf("dev/va-speed/35-ladder-N%d-q%d-result.rds", N0, Q0))

rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  s <- tryCatch(system("sysctl -n vm.loadavg", intern = TRUE, ignore.stderr = TRUE),
                error = function(e) character(0))
  if (!length(s)) return(NA_real_)
  suppressWarnings(as.numeric(strsplit(trimws(gsub("[{}]", "", s[1])), " +")[[1]][1]))
}

## DGP: same construction as scripts 33/34, generalised to q. Sigma_true is
## rank-Q0, magnitude set by sd = 0.8 loadings (all of the unit-level variance
## lives in the loadings tier -- unique = FALSE has no separate diagonal Psi).
mk <- function(seed, N, Q) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q, 0, 0.8), T0, Q); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q), N, Q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, succ = y, fail = NTR - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam), N = N, Q = Q)
}

run_va <- function(b) gllvmTMB:::.va_r3_fit(
  y = b$d$y, n_trials = rep(NTR, nrow(b$d)), X = b$X,
  unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait), q = b$Q,
  family = "binomial_probit", link = "probit",
  unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  collapse_variational_cov = TRUE,
  control = list(eval.max = 800L, iter.max = 400L))

run_la_formula <- function(Q) cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q, unique = FALSE)
run_la_cold <- function(b) gllvmTMB::gllvmTMB(
  run_la_formula(b$Q), data = b$d, family = binomial(link = "probit"), unit = "unit")

score_Sigma <- function(S, b) {
  rf <- rel_frob(S, b$Sigma_true)
  list(rf = rf, trace_hat = sum(diag(S)))
}
score_va <- function(f, b) {
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(f$best$par[names(f$best$par) == "theta_rr"], T0, b$Q)
  score_Sigma(L %*% t(L), b)
}
score_la <- function(f, b) {
  out <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "total", link_residual = "none"),
                  error = function(e) NULL)
  if (is.null(out) || is.null(out$Sigma)) return(list(rf = NA_real_, trace_hat = NA_real_))
  S <- as.matrix(out$Sigma)
  if (!identical(dim(S), dim(b$Sigma_true))) return(list(rf = NA_real_, trace_hat = NA_real_))
  score_Sigma(S, b)
}

## ---------------------------------------------------------------------------
## Monkeypatch (identical strategy to scripts 33/34): swap
## `.vgh_build_warm_start`'s SOURCE for a VA-derived seed, restored on.exit.
ns <- asNamespace("gllvmTMB")
orig_vgh_build <- get(".vgh_build_warm_start", envir = ns)
va_seed_holder <- new.env()
mock_vgh_build_warm_start <- function(tmb_data, family_name, maxit = 3L, verbose = FALSE) va_seed_holder$seed
patch_on <- function() {
  unlockBinding(".vgh_build_warm_start", ns)
  assign(".vgh_build_warm_start", mock_vgh_build_warm_start, envir = ns)
  lockBinding(".vgh_build_warm_start", ns)
}
patch_off <- function() {
  unlockBinding(".vgh_build_warm_start", ns)
  assign(".vgh_build_warm_start", orig_vgh_build, envir = ns)
  lockBinding(".vgh_build_warm_start", ns)
}

## Build the VA-derived seed. `seed_z` controls whether the z_B mode seed
## (script 34's extension) is included; theta_rr/b_fix are always seeded
## (script 33's route). log-scale variance coordinates (the AC->GH scar
## tissue) are RESET, never transferred -- this matched cell has none.
va_derived_seed <- function(fva, b, seed_z) {
  nm <- names(fva$best$par)
  beta <- unname(fva$best$par[nm == "beta"])
  theta_rr <- unname(fva$best$par[nm == "theta_rr"])
  out <- list(theta_rr = theta_rr, b_fix = beta, vgh_seconds = NA_real_, vgh_elbo = NA_real_)
  if (seed_z) {
    m_flat <- unname(fva$best$par[nm == "m"])
    stopifnot(length(m_flat) == b$N * b$Q)
    z_seed <- t(matrix(m_flat, nrow = b$N, ncol = b$Q))
    stopifnot(identical(dim(z_seed), c(b$Q, b$N)))
    out$z <- z_seed
  }
  out
}

## Runs VA then the warm-started LA, TIMING THE TWO STAGES SEPARATELY so we
## can report "percent of the LA stage saved" (cold-LA vs. la_secs here),
## while the arm's own wall time (measured by the caller) is va_secs+la_secs
## and legitimately includes the VA fit.
run_hybrid <- function(b, seed_z) {
  t0 <- proc.time()[["elapsed"]]
  fva <- run_va(b)
  va_secs <- proc.time()[["elapsed"]] - t0
  seed <- va_derived_seed(fva, b, seed_z)
  va_seed_holder$seed <- seed
  control <- gllvmTMB::gllvmTMBcontrol()
  control$vgh_warm_start <- TRUE
  control$vgh_warm_start_fixed <- TRUE
  control$vgh_warm_start_z <- seed_z
  t0 <- proc.time()[["elapsed"]]
  fla <- gllvmTMB::gllvmTMB(run_la_formula(b$Q), data = b$d, family = binomial(link = "probit"),
                            unit = "unit", control = control)
  la_secs <- proc.time()[["elapsed"]] - t0
  list(fit = fla, fva = fva, va_secs = va_secs, la_secs = la_secs)
}

## ---------------------------------------------------------------------------
main <- function() {
  patch_on(); on.exit(patch_off(), add = TRUE)

  cat(sprintf("== rung N=%d q=%d T=%d seeds=%s cap=%.0fs ==\n", N0, Q0, T0,
              paste(SEEDS, collapse = ","), CAP))
  cat("== warm-up (untimed) ==\n"); flush.console()
  wu <- mk(999L, min(40L, N0), Q0)
  invisible(tryCatch(run_va(wu), error = function(e) cat("  VA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_la_cold(wu), error = function(e) cat("  LA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_hybrid(wu, seed_z = FALSE), error = function(e) cat("  Hybrid-fixed warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_hybrid(wu, seed_z = TRUE), error = function(e) cat("  Hybrid-modes warm-up error:", conditionMessage(e), "\n")))
  cat("== warm-up done ==\n\n"); flush.console()

  arms <- c("VA", "LA", "HybridFixed", "HybridModes")
  cat(sprintf("%-5s %-12s %9s %10s %10s %12s %12s %10s %10s %6s %s\n",
              "seed", "arm", "secs", "va_secs", "la_secs", "rel_frob", "objective", "landed", "same_opt", "load", "status"))
  res <- list()
  for (s in SEEDS) {
    b <- mk(s, N0, Q0)
    rot <- (s - 1L) %% 4L
    ord <- arms[((seq_along(arms) - 1L + rot) %% length(arms)) + 1L]
    for (arm in ord) {
      la_load <- loadavg(); t0 <- proc.time()[["elapsed"]]
      setTimeLimit(elapsed = CAP, transient = TRUE)
      out <- tryCatch({
        if (arm == "VA") list(f = run_va(b), va_secs = NA_real_, la_secs = NA_real_, landed = NA)
        else if (arm == "LA") list(f = run_la_cold(b), va_secs = NA_real_, la_secs = NA_real_, landed = NA)
        else {
          h <- run_hybrid(b, seed_z = (arm == "HybridModes"))
          landed <- isTRUE(h$fit$start_provenance$vgh_warm_start) &&
            (arm != "HybridModes" || isTRUE(h$fit$start_provenance$vgh_warm_start_z))
          list(f = h$fit, va_secs = h$va_secs, la_secs = h$la_secs, landed = landed)
        }
      }, error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
      setTimeLimit(elapsed = Inf)
      secs <- proc.time()[["elapsed"]] - t0
      if (inherits(out, "err")) {
        st <- if (grepl("time limit", out$m)) "DID-NOT-COMPLETE" else paste0("ERROR: ", substr(out$m, 1, 60))
        cat(sprintf("%-5d %-12s %9.2f %10s %10s %10s %12s %12s %10s %6.1f %s\n",
                    s, arm, secs, "NA", "NA", "NA", "NA", "NA", "NA", la_load, st)); flush.console()
        res[[length(res) + 1]] <- data.frame(N = N0, Q = Q0, seed = s, arm = arm, secs = secs,
                                              va_secs = NA_real_, la_secs = NA_real_, rf = NA_real_,
                                              trace_hat = NA_real_, obj = NA_real_, landed = NA,
                                              load = la_load, status = st)
        next
      }
      f <- out$f
      sc <- tryCatch(if (arm == "VA") score_va(f, b) else score_la(f, b),
                     error = function(e) list(rf = NA_real_, trace_hat = NA_real_))
      obj <- tryCatch(if (arm == "VA") f$best$objective else f$opt$objective, error = function(e) NA_real_)
      cat(sprintf("%-5d %-12s %9.2f %10.2f %10.2f %10.5f %12.3f %12s %10s %6.1f     ok\n",
                  s, arm, secs, out$va_secs, out$la_secs, sc$rf, obj, as.character(out$landed), "-", la_load)); flush.console()
      res[[length(res) + 1]] <- data.frame(N = N0, Q = Q0, seed = s, arm = arm, secs = secs,
                                            va_secs = out$va_secs, la_secs = out$la_secs, rf = sc$rf,
                                            trace_hat = sc$trace_hat, obj = obj,
                                            landed = as.character(out$landed), load = la_load, status = "ok")
    }
  }
  r <- do.call(rbind, res)

  cat(sprintf("\nSigma_true trace (planted variance) = %.4f\n", sum(diag(mk(SEEDS[1], N0, Q0)$Sigma_true))))
  cat("\n--- medians by arm ---\n")
  ok <- r[r$status == "ok", ]
  if (nrow(ok)) print(aggregate(cbind(secs, va_secs, la_secs, rf, obj) ~ arm, ok, median, na.action = na.pass), row.names = FALSE, digits = 6)

  cat("\n--- per-seed same-optimum check: Hybrid arms vs cold LA ---\n")
  for (s in SEEDS) {
    la_row <- ok[ok$seed == s & ok$arm == "LA", ]
    for (harm in c("HybridFixed", "HybridModes")) {
      hy_row <- ok[ok$seed == s & ok$arm == harm, ]
      if (nrow(la_row) == 1L && nrow(hy_row) == 1L) {
        d_obj <- hy_row$obj - la_row$obj
        d_rf <- hy_row$rf - la_row$rf
        cat(sprintf("  seed %d [%s]: LA obj=%.4f rf=%.5f | %s obj=%.4f rf=%.5f | delta_obj=%+.4f delta_rf=%+.5f %s\n",
                    s, harm, la_row$obj, la_row$rf, harm, hy_row$obj, hy_row$rf, d_obj, d_rf,
                    if (abs(d_obj) < 1e-2 && abs(d_rf) < 5e-3) "SAME OPTIMUM" else "DIFFERENT -- FLAG"))
      } else {
        cat(sprintf("  seed %d [%s]: missing LA or %s row -- cannot compare\n", s, harm, harm))
      }
    }
  }

  cat("\n--- LA-stage saving and end-to-end speedup (the quantities that bound the hybrid) ---\n")
  la_med <- median(ok$secs[ok$arm == "LA"], na.rm = TRUE)
  va_med <- median(ok$secs[ok$arm == "VA"], na.rm = TRUE)
  for (harm in c("HybridFixed", "HybridModes")) {
    hy <- ok[ok$arm == harm, ]
    la_stage_med <- median(hy$la_secs, na.rm = TRUE)
    hy_total_med <- median(hy$secs, na.rm = TRUE)
    pct_la_saved <- 100 * (la_med - la_stage_med) / la_med
    speedup <- la_med / hy_total_med
    cat(sprintf("[N=%d q=%d] %-12s: LA-stage saved %.1f%% (cold LA %.2fs -> hybrid LA-stage %.2fs); end-to-end %.2fx (cold LA %.2fs vs hybrid-total %.2fs, VA alone %.2fs)\n",
                N0, Q0, harm, pct_la_saved, la_med, la_stage_med, speedup, la_med, hy_total_med, va_med))
  }
  cat(sprintf("\nload median %.1f spread %.1f (paired+interleaved, so the RATIO survives ambient load)\n",
              median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE))))
  cat("\nLADDER_RUNG_DONE\n")
  r
}

result <- main()
saveRDS(result, OUT_RDS)
