## Warm-start the shipped Laplace engine from the VA prototype ("superfast LA").
##
## Insertion point (per docs/design/va-warmstart-la-recon.md): the shipped engine
## already has a tested "seed theta_rr_B / (opt-in) b_fix right before MakeADFun,
## skip z_B by default" hook -- control$vgh_warm_start -- wired to VGH's own
## internal solve via the internal .vgh_build_warm_start(). That function is not
## exported and its call site is a single line inside R/fit-multi.R
## (`.vgh_build_warm_start(tmb_data, vgh_fam, maxit=..., verbose=...)`). Rather
## than re-implement the copy-into-tmb_params / z_B-skip-by-default / shape-check
## / "never trust a start without checking it landed" logic that block already
## has and has already been measured (R/fit-multi.R:4253-4321), this script
## SWAPS ONLY THE SOURCE: it monkeypatches `.vgh_build_warm_start` inside the
## gllvmTMB namespace, for the duration of this script only (restored via
## on.exit even on error), to return a VA-derived seed instead of running VGH's
## own solve. This is a SCRIPT-LEVEL runtime patch, not a package-file edit --
## no file under R/ or src/ is touched.
##
## theta_rr packing is IDENTICAL between VA and the shipped engine (verified in
## the recon by direct comparison of R/va-r3-proto.R:27-48 against
## src/gllvmTMB.cpp:945-968 -- both diagonal-first, column-major strict-lower,
## raw scale, same length formula) so, UNLIKE the VGH case, no rotation
## transform is needed: VA already fits directly in the same triangular-loadings
## parameterisation the shipped engine expects.
##
## THE SCAR TISSUE (dev/va-speed/25-WARM-ROUTE-PSI-FINDING.md): log-scale
## variance coordinates are an attracting boundary near 0 and must be RESET, not
## transferred. In this exact matched cell (unique = FALSE) there is no such
## coordinate at all -- log_sd_tier (VA) / theta_diag_B (shipped) are both
## length-0/mapped-off -- so the "reset" step is a no-op here, and the script
## below asserts and prints that fact rather than silently skipping it.
##
## z_B is deliberately NOT seeded (control$vgh_warm_start_z stays FALSE, the
## shipped default): VGH's own measurement found seeding the analogous random
## effect coordinate harmful (0.39x vs 4.43x, R/fit-multi.R:4279-4284), and that
## is the working hypothesis carried in here, not yet independently retested.
##
## Paired, interleaved, order-rotated across THREE arms per seed: VA alone,
## cold LA, hybrid (VA + warm-started LA, hybrid time INCLUDES the VA fit).
## Untimed warm-up first. Small local fits only (N=250, T=20, q=2, 3 seeds).
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

NTR <- 6L; T0 <- 20L; Q0 <- 2L
CAP <- as.numeric(Sys.getenv("LA_CAP", "900"))
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  s <- tryCatch(system("sysctl -n vm.loadavg", intern = TRUE, ignore.stderr = TRUE),
                error = function(e) character(0))
  if (!length(s)) return(NA_real_)
  suppressWarnings(as.numeric(strsplit(trimws(gsub("[{}]", "", s[1])), " +")[[1]][1]))
}

## DGP: plants a REAL Sigma_true = lam %*% t(lam) (rank Q0, magnitude set by
## sd = 0.8 loadings) -- this IS the "variance" a collapsed fit would fail to
## recover, since this matched cell (unique = FALSE) has no separate diagonal
## Psi tier: all of the unit-level variance lives in the loadings.
mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, succ = y, fail = NTR - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam), N = N)
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

score_Sigma <- function(S, b) {
  rf <- rel_frob(S, b$Sigma_true)
  list(rf = rf, trace_hat = sum(diag(S)), trace_true = sum(diag(b$Sigma_true)))
}
score_va <- function(f, b) {
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(f$best$par[names(f$best$par) == "theta_rr"], T0, Q0)
  score_Sigma(L %*% t(L), b)
}
score_la <- function(f, b) {
  out <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "total",
                                          link_residual = "none"),
                  error = function(e) NULL)
  if (is.null(out) || is.null(out$Sigma)) return(list(rf = NA_real_, trace_hat = NA_real_, trace_true = sum(diag(b$Sigma_true))))
  S <- as.matrix(out$Sigma)
  if (!identical(dim(S), dim(b$Sigma_true))) return(list(rf = NA_real_, trace_hat = NA_real_, trace_true = sum(diag(b$Sigma_true))))
  score_Sigma(S, b)
}

## ---------------------------------------------------------------------------
## The monkeypatch: swap .vgh_build_warm_start's SOURCE (VGH's own internal
## solve) for a VA-derived seed, for the duration of main(). Everything
## downstream of the call site (copy into tmb_params, skip z_B by default,
## shape checks, the "did it actually land" stop()) is untouched, tested,
## shipped code (R/fit-multi.R:4253-4321).
ns <- asNamespace("gllvmTMB")
orig_vgh_build <- get(".vgh_build_warm_start", envir = ns)
va_seed_holder <- new.env()

mock_vgh_build_warm_start <- function(tmb_data, family_name, maxit = 3L, verbose = FALSE) {
  va_seed_holder$seed
}

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

## Build the VA-sourced seed. Explicitly RESETS (does not transfer) any
## log-scale variance coordinate -- the AC->GH scar tissue's exact failure mode
## -- and reports whether this cell actually had one to reset.
va_derived_seed <- function(fva, va_secs) {
  nm <- names(fva$best$par)
  beta <- unname(fva$best$par[nm == "beta"])
  theta_rr <- unname(fva$best$par[nm == "theta_rr"])
  log_sd_tier <- unname(fva$best$par[nm == "log_sd_tier"])
  if (length(log_sd_tier) > 0L) {
    cat(sprintf("  [reset] VA log_sd_tier has length %d -- these are the AC->GH boundary-risk coordinates and are DELIBERATELY DROPPED, not transferred.\n", length(log_sd_tier)))
  } else {
    cat("  [reset] no active log-scale variance tier in this matched cell (unique = FALSE) -- nothing to reset (confirms recon Sec.3).\n")
  }
  list(theta_rr = theta_rr, b_fix = beta, vgh_seconds = va_secs, vgh_elbo = NA_real_)
}

run_hybrid <- function(b) {
  fva <- run_va(b)
  seed <- va_derived_seed(fva, NA_real_)  ## va_secs filled by caller for provenance only
  va_seed_holder$seed <- seed
  control <- gllvmTMB::gllvmTMBcontrol()
  control$vgh_warm_start <- TRUE
  control$vgh_warm_start_fixed <- TRUE   ## also seed b_fix (beta), opt-in per VGH precedent
  control$vgh_warm_start_z <- FALSE      ## explicit: do NOT seed z_B (VGH finding: harmful)
  fla <- gllvmTMB::gllvmTMB(run_la_formula, data = b$d, family = binomial(link = "probit"),
                            unit = "unit", control = control)
  list(fit = fla, fva = fva)
}

main <- function() {
  patch_on()
  on.exit(patch_off(), add = TRUE)

  cat("== warm-up (untimed) ==\n"); flush.console()
  wu <- mk(999L, 40L)
  invisible(tryCatch(run_va(wu), error = function(e) cat("  VA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_la_cold(wu), error = function(e) cat("  LA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_hybrid(wu), error = function(e) cat("  Hybrid warm-up error:", conditionMessage(e), "\n")))
  cat("== warm-up done ==\n\n"); flush.console()

  N0 <- as.integer(Sys.getenv("WARM_N", "250"))
  SEEDS <- seq_len(as.integer(Sys.getenv("WARM_SEEDS", "3")))
  arms <- c("VA", "LA", "Hybrid")
  cat(sprintf("%-5s %-7s %9s %10s %10s %12s %12s %6s %6s %s\n",
              "seed", "arm", "secs", "rel_frob", "trace_hat", "objective", "landed", "load", "n_ok", "status"))
  res <- list()
  for (s in SEEDS) {
    b <- mk(s, N0)
    ## Rotate the order across the 3 arms by seed so no arm always goes first.
    rot <- (s - 1L) %% 3L
    ord <- arms[((seq_along(arms) - 1L + rot) %% length(arms)) + 1L]
    for (arm in ord) {
      la <- loadavg(); t0 <- proc.time()[["elapsed"]]
      setTimeLimit(elapsed = CAP, transient = TRUE)
      out <- tryCatch({
        if (arm == "VA") list(f = run_va(b), landed = NA)
        else if (arm == "LA") list(f = run_la_cold(b), landed = NA)
        else {
          h <- run_hybrid(b)
          list(f = h$fit, landed = isTRUE(h$fit$start_provenance$vgh_warm_start))
        }
      }, error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
      setTimeLimit(elapsed = Inf)
      secs <- proc.time()[["elapsed"]] - t0
      if (inherits(out, "err")) {
        st <- if (grepl("time limit", out$m)) "DID-NOT-COMPLETE" else paste0("ERROR: ", substr(out$m, 1, 60))
        cat(sprintf("%-5d %-7s %9.2f %10s %10s %12s %12s %6.1f %s\n", s, arm, secs, "NA", "NA", "NA", "NA", la, st)); flush.console()
        res[[length(res) + 1]] <- data.frame(seed = s, arm = arm, secs = secs, rf = NA_real_,
                                              trace_hat = NA_real_, obj = NA_real_, landed = NA,
                                              load = la, status = st)
        next
      }
      f <- out$f
      sc <- tryCatch(if (arm == "VA") score_va(f, b) else score_la(f, b),
                     error = function(e) list(rf = NA_real_, trace_hat = NA_real_))
      obj <- tryCatch(if (arm == "VA") f$best$objective else f$opt$objective, error = function(e) NA_real_)
      cat(sprintf("%-5d %-7s %9.2f %10.5f %10.4f %12.3f %12s %6.1f     ok\n",
                  s, arm, secs, sc$rf, sc$trace_hat, obj, as.character(out$landed), la)); flush.console()
      res[[length(res) + 1]] <- data.frame(seed = s, arm = arm, secs = secs, rf = sc$rf,
                                            trace_hat = sc$trace_hat, obj = obj,
                                            landed = as.character(out$landed), load = la, status = "ok")
    }
  }
  r <- do.call(rbind, res)

  cat(sprintf("\nSigma_true trace (planted variance) = %.4f\n", sum(diag(mk(1L, N0)$Sigma_true))))

  cat("\n--- medians by arm ---\n")
  ok <- r[r$status == "ok", ]
  if (nrow(ok)) print(aggregate(cbind(secs, rf, trace_hat, obj) ~ arm, ok, median), row.names = FALSE, digits = 6)

  cat("\n--- per-seed same-optimum check: Hybrid vs cold LA ---\n")
  for (s in SEEDS) {
    la_row <- ok[ok$seed == s & ok$arm == "LA", ]
    hy_row <- ok[ok$seed == s & ok$arm == "Hybrid", ]
    if (nrow(la_row) == 1L && nrow(hy_row) == 1L) {
      d_obj <- hy_row$obj - la_row$obj
      d_rf <- hy_row$rf - la_row$rf
      cat(sprintf("  seed %d: LA obj=%.4f rf=%.5f | Hybrid obj=%.4f rf=%.5f | delta_obj=%+.4f delta_rf=%+.5f %s\n",
                  s, la_row$obj, la_row$rf, hy_row$obj, hy_row$rf, d_obj, d_rf,
                  if (abs(d_obj) < 1e-2 && abs(d_rf) < 5e-3) "SAME OPTIMUM" else "DIFFERENT -- FLAG"))
    } else {
      cat(sprintf("  seed %d: missing LA or Hybrid row (status not 'ok' for one arm) -- cannot compare\n", s))
    }
  }

  va_med <- median(ok$secs[ok$arm == "VA"]); la_med <- median(ok$secs[ok$arm == "LA"])
  hy_med <- median(ok$secs[ok$arm == "Hybrid"])
  cat(sprintf("\nmedians: VA %.2fs, cold LA %.2fs, Hybrid %.2fs\n", va_med, la_med, hy_med))
  if (is.finite(hy_med) && is.finite(la_med))
    cat(sprintf("Hybrid vs cold LA: %.2fx %s\n", max(hy_med, la_med) / min(hy_med, la_med),
                if (hy_med < la_med) "FASTER" else "SLOWER"))
  cat(sprintf("load median %.1f spread %.1f (paired+interleaved, so the RATIO survives ambient load)\n",
              median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE))))
  cat("\nWARMSTART_DONE\n")
  r
}

result <- main()
saveRDS(result, "dev/va-speed/33-va-warmstart-la-result.rds")
