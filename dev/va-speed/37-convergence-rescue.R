## Convergence-rescue test: does the VA-mode-seeded hybrid (script 34's route
## -- control$vgh_warm_start + vgh_warm_start_fixed + vgh_warm_start_z, seeded
## from a VA fit's beta/theta_rr/m) succeed where COLD Laplace struggles or
## fails outright?
##
## This is the SECOND hypothesis from today's task brief: convergence rescue
## may be worth more than any speedup, independent of whether the hybrid is
## faster. We do NOT touch the speed question here.
##
## Regimes tried (picked from docs/design/48-m3-4-boundary-regimes.md's
## "awkward" list, adapted to binomial-probit since that is the model this
## hybrid targets): rare/sparse events, high q relative to N, small N with
## large T, near-boundary variance components. Extreme n_trials is folded
## into the rare-event regime (n_trials = 1, i.e. Bernoulli).
##
## Multiple seeds per regime. No artificial iter.max/eval.max cap -- default
## control (iter.max = 1500, eval.max = 2000) is used throughout so a
## "failure" reflects genuine difficulty, not a starved budget. Per arm we
## record: converged (opt$convergence == 0), convergence code, message,
## iterations, max |gradient| (via the package's own fit_health build),
## time, and objective (for same-optimum comparison when BOTH arms convergene).
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

## ---------------------------------------------------------------------------
## DGP generator, parameterised by regime knobs.
##   N        -- number of units (sites)
##   T0       -- number of traits
##   Q0       -- latent rank
##   n_trials -- binomial n (1 = Bernoulli / rare-event regime uses this)
##   icpt_mean-- mean of the per-trait intercepts (controls event rate via
##               pnorm(icpt) -- very negative = rare events)
##   lam_sd   -- sd of the loadings (controls variance-component magnitude;
##               near 0 = near-boundary / near-singular Sigma)
mk <- function(seed, N, T0, Q0, n_trials, icpt_mean, lam_sd) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, lam_sd), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, icpt_mean, 0.3), "+")
  p <- pnorm(as.vector(eta))
  y <- rbinom(N * T0, n_trials, p)
  d <- data.frame(y = y, succ = y, fail = n_trials - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam), N = N, T0 = T0, Q0 = Q0, n_trials = n_trials,
       event_rate = mean(y / n_trials))
}

run_va <- function(b) gllvmTMB:::.va_r3_fit(
  y = b$d$y, n_trials = rep(b$n_trials, nrow(b$d)), X = b$X,
  unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait), q = b$Q0,
  family = "binomial_probit", link = "probit",
  unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  collapse_variational_cov = TRUE,
  control = list(eval.max = 800L, iter.max = 400L))

run_la_formula <- function(Q0) cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE)

run_la_cold <- function(b) gllvmTMB::gllvmTMB(
  run_la_formula(b$Q0), data = b$d, family = binomial(link = "probit"), unit = "unit")

## ---------------------------------------------------------------------------
## Monkeypatch (identical to scripts 33/34): swap `.vgh_build_warm_start`'s
## SOURCE for a VA-derived seed, restored on.exit even on error.
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

va_derived_seed <- function(fva, b) {
  nm <- names(fva$best$par)
  beta <- unname(fva$best$par[nm == "beta"])
  theta_rr <- unname(fva$best$par[nm == "theta_rr"])
  m_flat <- unname(fva$best$par[nm == "m"])
  N <- as.integer(b$N); Q0 <- as.integer(b$Q0)
  stopifnot(length(m_flat) == N * Q0)
  z_seed <- t(matrix(m_flat, nrow = N, ncol = Q0))
  stopifnot(identical(dim(z_seed), c(Q0, N)))
  list(theta_rr = theta_rr, b_fix = beta, z = z_seed, vgh_seconds = NA_real_, vgh_elbo = NA_real_)
}

run_hybrid <- function(b) {
  fva <- tryCatch(run_va(b), error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  if (inherits(fva, "err")) return(structure(list(m = paste0("VA sub-fit failed: ", fva$m)), class = "err"))
  seed <- va_derived_seed(fva, b)
  va_seed_holder$seed <- seed
  control <- gllvmTMB::gllvmTMBcontrol()
  control$vgh_warm_start <- TRUE
  control$vgh_warm_start_fixed <- TRUE
  control$vgh_warm_start_z <- TRUE
  fla <- gllvmTMB::gllvmTMB(run_la_formula(b$Q0), data = b$d, family = binomial(link = "probit"),
                            unit = "unit", control = control)
  list(fit = fla, fva = fva)
}

## ---------------------------------------------------------------------------
## Diagnostics extraction, robust to a fit object that may lack pieces
## (e.g. sdreport failed but opt succeeded).
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

diag_from_fit <- function(f) {
  conv <- tryCatch(f$opt$convergence, error = function(e) NA_integer_) %||% NA_integer_
  msg  <- tryCatch(f$opt$message, error = function(e) NA_character_) %||% NA_character_
  iter <- tryCatch(f$opt$iterations, error = function(e) NA_integer_) %||% NA_integer_
  obj  <- tryCatch(f$opt$objective, error = function(e) NA_real_) %||% NA_real_
  maxgrad <- tryCatch({
    fh <- gllvmTMB:::.gllvmTMB_build_fit_health(f)
    fh$max_gradient %||% NA_real_
  }, error = function(e) NA_real_) %||% NA_real_
  pdh <- (tryCatch(f$sd_report$pdHess, error = function(e) NA)) %||% NA
  list(converged = isTRUE(conv == 0), conv_code = conv, message = msg,
       iterations = iter, max_grad = maxgrad, pdHess = pdh, objective = obj)
}

score_Sigma <- function(f, b) {
  out <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "total", link_residual = "none"),
                  error = function(e) NULL)
  if (is.null(out) || is.null(out$Sigma)) return(list(rf = NA_real_, trace_hat = NA_real_, trace_true = sum(diag(b$Sigma_true))))
  S <- as.matrix(out$Sigma)
  if (!identical(dim(S), dim(b$Sigma_true))) return(list(rf = NA_real_, trace_hat = NA_real_, trace_true = sum(diag(b$Sigma_true))))
  list(rf = rel_frob(S, b$Sigma_true), trace_hat = sum(diag(S)), trace_true = sum(diag(b$Sigma_true)))
}

## ---------------------------------------------------------------------------
## Regime definitions. Each cell: N, T0, Q0, n_trials, icpt_mean, lam_sd, label.
regimes <- list(
  RARE_EVENTS   = list(N = 300, T0 = 10, Q0 = 2, n_trials = 1L,  icpt_mean = -1.9, lam_sd = 0.5,
                        note = "Bernoulli, intercept -1.9 -> sparse (few-percent) event rate, softened from full separation"),
  HIGH_Q_LOW_N  = list(N = 20,  T0 = 25, Q0 = 7,  n_trials = 6L, icpt_mean = 0.0,  lam_sd = 0.8,
                        note = "q=7 with only N=20 units -- rank close to N, few obs per latent dim"),
  SMALL_N_BIG_T = list(N = 8,   T0 = 80, Q0 = 2,  n_trials = 6L, icpt_mean = 0.0,  lam_sd = 0.8,
                        note = "N=8 units, T=80 traits -- extreme aspect ratio, thin per-unit info"),
  NEAR_BOUNDARY = list(N = 150, T0 = 15, Q0 = 2,  n_trials = 6L, icpt_mean = 0.0,  lam_sd = 0.01,
                        note = "loadings sd=0.01 -- Sigma_true near-singular, variance near the zero boundary")
)
SEEDS <- as.integer(strsplit(Sys.getenv("RESCUE_SEEDS", "1,2,3"), ",")[[1]])
REGIME_FILTER <- Sys.getenv("RESCUE_REGIMES", "")
if (nzchar(REGIME_FILTER)) {
  keep <- strsplit(REGIME_FILTER, ",")[[1]]
  regimes <- regimes[keep]
}

main <- function() {
  patch_on(); on.exit(patch_off(), add = TRUE)

  cat("== warm-up (untimed) ==\n"); flush.console()
  wu <- mk(999L, 40L, 15L, 2L, 6L, 0, 0.8)
  invisible(tryCatch(run_va(wu), error = function(e) cat("  VA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_la_cold(wu), error = function(e) cat("  LA warm-up error:", conditionMessage(e), "\n")))
  invisible(tryCatch(run_hybrid(wu), error = function(e) cat("  Hybrid warm-up error:", conditionMessage(e), "\n")))
  cat("== warm-up done ==\n\n"); flush.console()

  rows <- list()
  for (rname in names(regimes)) {
    rg <- regimes[[rname]]
    cat(sprintf("\n########## REGIME %s: %s ##########\n", rname, rg$note))
    cat(sprintf("N=%d T=%d q=%d n_trials=%d icpt_mean=%.2f lam_sd=%.2f\n",
                rg$N, rg$T0, rg$Q0, rg$n_trials, rg$icpt_mean, rg$lam_sd))
    for (s in SEEDS) {
      b <- mk(s, rg$N, rg$T0, rg$Q0, rg$n_trials, rg$icpt_mean, rg$lam_sd)
      cat(sprintf("-- seed %d (event_rate=%.4f) --\n", s, b$event_rate))
      ## order-rotate LA-cold vs Hybrid across seeds
      arms <- if ((s %% 2L) == 0L) c("LA", "Hybrid") else c("Hybrid", "LA")
      out_by_arm <- list()
      for (arm in arms) {
        la_load <- loadavg(); t0 <- proc.time()[["elapsed"]]
        setTimeLimit(elapsed = 900, transient = TRUE)
        res <- tryCatch({
          if (arm == "LA") list(f = run_la_cold(b))
          else { h <- run_hybrid(b); if (inherits(h, "err")) h else list(f = h$fit, fva = h$fva) }
        }, error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
        if (!inherits(res, "err") && is.null(res$f)) {
          res <- structure(list(m = "hybrid produced a NULL fit (see run_hybrid internal error)"), class = "err")
        }
        setTimeLimit(elapsed = Inf)
        secs <- proc.time()[["elapsed"]] - t0
        if (inherits(res, "err")) {
          cat(sprintf("  [%s] ERROR after %.1fs: %s\n", arm, secs, substr(res$m, 1, 150)))
          out_by_arm[[arm]] <- list(ok = FALSE, secs = secs, err = res$m)
          next
        }
        f <- res$f
        dg <- diag_from_fit(f)
        sc <- score_Sigma(f, b)
        cat(sprintf("  [%s] %.1fs conv=%s(code=%s) iters=%s maxgrad=%s pdHess=%s obj=%.3f rel_frob=%.5f trace_hat=%.4f trace_true=%.4f msg=%s\n",
                    arm, secs, dg$converged, dg$conv_code, dg$iterations,
                    if (is.na(dg$max_grad)) "NA" else sprintf("%.2e", dg$max_grad),
                    dg$pdHess, dg$objective, sc$rf, sc$trace_hat, sc$trace_true, substr(as.character(dg$message), 1, 60)))
        out_by_arm[[arm]] <- list(ok = TRUE, secs = secs, dg = dg, rf = sc$rf, landed = if (arm == "Hybrid")
          isTRUE(f$start_provenance$vgh_warm_start) && isTRUE(f$start_provenance$vgh_warm_start_z) else NA)
        rows[[length(rows) + 1L]] <- data.frame(
          regime = rname, seed = s, arm = arm, secs = secs, event_rate = b$event_rate,
          ok = out_by_arm[[arm]]$ok, converged = dg$converged, conv_code = dg$conv_code,
          iterations = dg$iterations, max_grad = dg$max_grad, pdHess = as.character(dg$pdHess),
          objective = dg$objective, rel_frob = sc$rf, trace_hat = sc$trace_hat, trace_true = sc$trace_true,
          load = la_load, message = as.character(dg$message))
      }
      ## same-optimum check if both arms produced a fit object (regardless of "converged" flag)
      la_r <- out_by_arm[["LA"]]; hy_r <- out_by_arm[["Hybrid"]]
      if (!is.null(la_r) && !is.null(hy_r) && isTRUE(la_r$ok) && isTRUE(hy_r$ok)) {
        d_obj <- hy_r$dg$objective - la_r$dg$objective
        d_rf  <- hy_r$rf - la_r$rf
        same <- is.finite(d_obj) && is.finite(d_rf) && abs(d_obj) < 1e-2 && abs(d_rf) < 5e-3
        cat(sprintf("  >> seed %d same-optimum(LA vs Hybrid): delta_obj=%+.4f delta_rf=%+.5f -- %s\n",
                    s, d_obj, d_rf, if (same) "SAME OPTIMUM" else "DIFFERENT -- FLAG"))
      } else if (!is.null(la_r) && !is.null(hy_r)) {
        cat(sprintf("  >> seed %d: LA ok=%s, Hybrid ok=%s -- one/both failed, see errors/convergence above\n",
                    s, isTRUE(la_r$ok), isTRUE(hy_r$ok)))
      }
    }
  }

  r <- do.call(rbind, rows)
  cat("\n\n================ SUMMARY ================\n")
  print(r, row.names = FALSE)

  cat("\n--- RESCUE CANDIDATES (LA failed/non-converged, Hybrid converged) ---\n")
  for (rname in unique(r$regime)) {
    for (s in unique(r$seed[r$regime == rname])) {
      la_row <- r[r$regime == rname & r$seed == s & r$arm == "LA", ]
      hy_row <- r[r$regime == rname & r$seed == s & r$arm == "Hybrid", ]
      la_bad <- nrow(la_row) == 0L || !isTRUE(la_row$ok) || !isTRUE(la_row$converged)
      hy_good <- nrow(hy_row) == 1L && isTRUE(hy_row$ok) && isTRUE(hy_row$converged)
      if (la_bad && hy_good) {
        cat(sprintf("  RESCUED: regime=%s seed=%d -- LA %s, Hybrid converged (code=%s, iters=%s)\n",
                    rname, s,
                    if (nrow(la_row) == 0L) "produced no row (error)" else sprintf("converged=%s code=%s", la_row$converged, la_row$conv_code),
                    hy_row$conv_code, hy_row$iterations))
      }
    }
  }

  cat("\n--- HYBRID-FAILED CASES (LA succeeded, Hybrid failed/non-converged) ---\n")
  for (rname in unique(r$regime)) {
    for (s in unique(r$seed[r$regime == rname])) {
      la_row <- r[r$regime == rname & r$seed == s & r$arm == "LA", ]
      hy_row <- r[r$regime == rname & r$seed == s & r$arm == "Hybrid", ]
      la_good <- nrow(la_row) == 1L && isTRUE(la_row$ok) && isTRUE(la_row$converged)
      hy_bad <- nrow(hy_row) == 0L || !isTRUE(hy_row$ok) || !isTRUE(hy_row$converged)
      if (la_good && hy_bad) {
        cat(sprintf("  HYBRID FAILED: regime=%s seed=%d -- LA converged, Hybrid %s\n",
                    rname, s,
                    if (nrow(hy_row) == 0L) "produced no row (error)" else sprintf("converged=%s code=%s", hy_row$converged, hy_row$conv_code)))
      }
    }
  }

  cat("\nCONVERGENCE_RESCUE_DONE\n")
  r
}

result <- main()
saveRDS(result, "dev/va-speed/37-convergence-rescue-result.rds")
