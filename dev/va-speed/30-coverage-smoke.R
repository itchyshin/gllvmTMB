## SMOKE, not a measurement. Companion to
## docs/design/va-interval-coverage-campaign.md. Proves, on whatever machine
## it runs on, at ONE fast stand-in cell with a handful of seeds, that the
## coverage-campaign MECHANICS work end to end:
##   (1) intervals can be extracted for every arm (VA-Wald Sigma_jj; LA-Wald
##       Sigma_jj; LA-Profile V_j via the shipped, certified-route helper);
##   (2) every extracted interval is finite and correctly ordered
##       (lower <= estimate <= upper);
##   (3) a coverage indicator (does the interval contain the PLANTED truth)
##       computes cleanly for both engines;
##   (4) a degenerate or failed fit is DETECTED (flagged, excluded from the
##       "healthy" set) rather than silently scored as if it were healthy --
##       and the known VA-side gap (no Schur SE on `log_sigma`, so V_j is NOT
##       yet computable for the VA arm; see design doc item 21) is asserted
##       directly rather than assumed.
##
## No coverage NUMBER is claimed here -- n_seeds is a handful, chosen for
## speed, not power. The design doc's Tier 1/2/3 seed counts (1000/300/100)
## and its n-grid (50/150/400/5000) are the production plan; this smoke uses
## a smaller, faster q=1 stand-in cell purely to prove the pipeline runs.
##
## Do NOT run this while Totoro is busy with a timing campaign -- it is
## written to PARSE cleanly and to be ready to run later, not to run now.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat("== coverage smoke starting", format(Sys.time(), "%H:%M:%S"), "in", getwd(), "==\n")
flush.console()

loadavg <- function() {
  if (file.exists("/proc/loadavg")) {
    return(suppressWarnings(as.numeric(strsplit(
      trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +"
    )[[1]][1])))
  }
  s <- tryCatch(system("sysctl -n vm.loadavg", intern = TRUE, ignore.stderr = TRUE),
                error = function(e) character(0))
  if (!length(s)) return(NA_real_)
  suppressWarnings(as.numeric(strsplit(trimws(gsub("[{}]", "", s[1])), " +")[[1]][1]))
}
cat(sprintf("== load average at start: %s ==\n", format(loadavg())))

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
cat("== load_all done", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

## ---- ONE fast stand-in cell -------------------------------------------
## q = 1 deliberately: at q = 1, Sigma_jj = theta_rr_j^2 is a function of a
## SINGLE fixed parameter, so the existing (diagonal-only) `se_profile` gives
## an EXACT delta-method SE for Sigma_jj on the VA side with no need to
## extend `.va_r3_fixed_information_blocked()` to return the full
## covariance first -- that extension (needed for Sigma_jk at d >= 2, and
## for V_j once `log_sigma` joins `fixed_idx`) is named as Step-0 gate 0c in
## the design doc, not attempted here. This smoke cell is a mechanically
## clean stand-in for the design's production q = 2 primary cells (n in
## {150, 400}), not a substitute for them.
N0   <- 40L   # units -- small and fast; production cells use n in {50,150,400,5000}
T0   <- 6L    # traits -- production uses T = 8
Q0   <- 1L
PSI_LO <- 0.3; PSI_HI <- 0.5   # Failure-Mode-1 guard: psi > 0, never the psi=0 corner
N_SEEDS <- 4L
CI_LEVEL <- 0.95
Z <- stats::qnorm(0.5 + CI_LEVEL / 2)

sim_cell <- function(seed) {
  set.seed(seed)
  lam_true <- matrix(stats::runif(T0, 0.7, 1.3) * sample(c(-1, 1), T0, TRUE), T0, Q0)
  psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
  z <- stats::rnorm(N0)
  eta <- outer(z, lam_true[, 1])                       # N0 x T0
  y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
  d <- data.frame(y = as.numeric(t(y)),
                   trait = factor(rep(seq_len(T0), times = N0)),
                   unit  = factor(rep(seq_len(N0), each = T0)))
  list(d = d, lam_true = lam_true, psi_true = psi_true,
       sigma_jj_true = as.numeric(lam_true[, 1]^2),
       v_j_true = as.numeric(lam_true[, 1]^2) + psi_true)
}

## ---- VA-Wald: Sigma_jj via the shipped Schur-profile SE ---------------
fit_va <- function(b) {
  X <- unname(stats::model.matrix(~ 0 + factor(b$d$trait)))
  do.call(gllvmTMB:::.va_r3_fit, list(
    y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
    unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
    q = Q0, family = "gaussian_anchor", link = "identity",
    unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
    n_starts = 1L, H = 15L,
    control = list(eval.max = 600L, iter.max = 400L)
  ))
}

va_sigma_ci <- function(fit) {
  healthy <- isTRUE(fit$health$admitted) && identical(fit$status, "healthy")
  if (!healthy) {
    return(list(healthy = FALSE, status = fit$status %||% "unknown",
                sigma_jj = rep(NA_real_, T0), se = rep(NA_real_, T0),
                lower = rep(NA_real_, T0), upper = rep(NA_real_, T0),
                log_sigma_has_se = NA))
  }
  se_info <- gllvmTMB:::.va_r3_fixed_information_blocked(
    objective = fit$objective, par = fit$best$par, N = N0, q = Q0
  )
  if (is.null(se_info$se_profile)) {
    return(list(healthy = FALSE, status = se_info$status,
                sigma_jj = rep(NA_real_, T0), se = rep(NA_real_, T0),
                lower = rep(NA_real_, T0), upper = rep(NA_real_, T0),
                log_sigma_has_se = NA))
  }
  ## Design doc item 21, asserted directly: `log_sigma` (the Gaussian
  ## residual/psi parameter) must NOT appear in the Schur-profile SE names --
  ## if it ever does (e.g. after the Step-0c extension lands), V_j becomes
  ## computable for VA and this smoke's scope note is stale.
  log_sigma_has_se <- "log_sigma" %in% names(se_info$se_profile)
  par <- fit$best$par
  theta_rr <- par[names(par) == "theta_rr"]           # length T0 at q = 1
  se_theta <- se_info$se_profile[names(se_info$se_profile) == "theta_rr"]
  stopifnot(length(theta_rr) == T0, length(se_theta) == T0)
  sigma_jj <- theta_rr^2
  se_sigma_jj <- 2 * abs(theta_rr) * se_theta          # exact delta method at q = 1
  list(healthy = TRUE, status = "healthy",
       sigma_jj = sigma_jj, se = se_sigma_jj,
       lower = sigma_jj - Z * se_sigma_jj,
       upper = sigma_jj + Z * se_sigma_jj,
       log_sigma_has_se = log_sigma_has_se)
}

## ---- LA-Wald: Sigma_jj via the existing loading-delta-method machinery,
## generalised from vec(Lambda) to vec(Lambda %*% t(Lambda)); LA-Profile:
## V_j via the shipped, certified-route helper (no new code needed there). --
fit_la <- function(b) {
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(1 | unit, d = Q0, unique = FALSE),
    data = b$d, family = stats::gaussian(), unit = "unit",
    silent = TRUE
  )
}

la_sigma_ci <- function(fit) {
  ## `fit$sd_report$pdHess` is the package's own established robust
  ## convergence check (used the same way in R/loading-ci.R and
  ## R/extractors.R); `fit$opt$convergence` is deliberately NOT used here --
  ## the package's own `?gllvmTMBcontrol` documents it as misleading on the
  ## AGHQ/quadrature path ("records the optimiser's per-pass iteration cap").
  healthy <- isTRUE(fit$sd_report$pdHess)
  if (!healthy) {
    return(list(healthy = FALSE, sigma_jj = rep(NA_real_, T0),
                se = rep(NA_real_, T0), lower = rep(NA_real_, T0),
                upper = rep(NA_real_, T0)))
  }
  ## `.loading_delta_at_mle()` (R/loading-uncertainty-helpers.R) does NOT
  ## gate on confirmatory-vs-exploratory -- explicitly documented as such --
  ## so it is safe to call on this exploratory (unconstrained) fit even
  ## though the public `loading_ci()` would refuse it.
  delta <- gllvmTMB:::.loading_delta_at_mle(
    fit = fit, internal_level = "B", loading_scale = "raw"
  )
  Lambda_hat <- as.numeric(delta$Lambda)               # length T0 at q = 1
  cov_vec <- delta$cov_vec                              # T0 x T0
  sigma_jj <- Lambda_hat^2
  ## Numerical Jacobian of Sigma_jj = Lambda_j^2 w.r.t. vec(Lambda) --
  ## diagonal in this q = 1 case (Sigma_jj depends only on Lambda_j), built
  ## generically so the same code works unchanged once d >= 2 is added.
  eps <- 1e-6
  J <- matrix(0, T0, T0)
  for (p in seq_len(T0)) {
    bump <- Lambda_hat; bump[p] <- bump[p] + eps
    J[, p] <- (bump^2 - sigma_jj) / eps
  }
  cov_sigma <- J %*% cov_vec %*% t(J)
  se_sigma_jj <- sqrt(pmax(diag(cov_sigma), 0))
  list(healthy = TRUE, sigma_jj = sigma_jj, se = se_sigma_jj,
       lower = sigma_jj - Z * se_sigma_jj, upper = sigma_jj + Z * se_sigma_jj)
}

la_vj_ci <- function(fit) {
  healthy <- isTRUE(fit$sd_report$pdHess)
  if (!healthy) {
    return(data.frame(trait = character(0), estimate = numeric(0),
                       lower = numeric(0), upper = numeric(0)))
  }
  gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- run the handful of seeds ------------------------------------------
rows <- vector("list", N_SEEDS)
for (s in seq_len(N_SEEDS)) {
  la <- loadavg()
  b <- sim_cell(20260800L + s)

  va_fit <- tryCatch(fit_va(b), error = function(e) {
    cat(sprintf("  seed %d VA-fit ERROR: %s\n", s, conditionMessage(e))); NULL
  })
  va_ci <- if (is.null(va_fit)) {
    list(healthy = FALSE, status = "fit_error", sigma_jj = rep(NA_real_, T0),
         se = rep(NA_real_, T0), lower = rep(NA_real_, T0),
         upper = rep(NA_real_, T0), log_sigma_has_se = NA)
  } else va_sigma_ci(va_fit)

  la_fit <- tryCatch(fit_la(b), error = function(e) {
    cat(sprintf("  seed %d LA-fit ERROR: %s\n", s, conditionMessage(e))); NULL
  })
  la_sig <- if (is.null(la_fit)) {
    list(healthy = FALSE, sigma_jj = rep(NA_real_, T0), se = rep(NA_real_, T0),
         lower = rep(NA_real_, T0), upper = rep(NA_real_, T0))
  } else la_sigma_ci(la_fit)
  la_vj <- if (is.null(la_fit)) {
    data.frame(trait = character(0), estimate = numeric(0),
               lower = numeric(0), upper = numeric(0))
  } else tryCatch(la_vj_ci(la_fit), error = function(e) {
    cat(sprintf("  seed %d LA-profile ERROR: %s\n", s, conditionMessage(e)))
    data.frame(trait = character(0), estimate = numeric(0),
               lower = numeric(0), upper = numeric(0))
  })

  va_cover <- if (va_ci$healthy) {
    (b$sigma_jj_true >= va_ci$lower) & (b$sigma_jj_true <= va_ci$upper)
  } else rep(NA, T0)
  la_cover <- if (la_sig$healthy) {
    (b$sigma_jj_true >= la_sig$lower) & (b$sigma_jj_true <= la_sig$upper)
  } else rep(NA, T0)
  la_vj_cover <- if (nrow(la_vj) == T0) {
    (b$v_j_true >= la_vj$lower) & (b$v_j_true <= la_vj$upper)
  } else rep(NA, T0)

  ok_order_va <- if (va_ci$healthy) all(va_ci$lower <= va_ci$sigma_jj &
                                        va_ci$sigma_jj <= va_ci$upper) else NA
  ok_order_la <- if (la_sig$healthy) all(la_sig$lower <= la_sig$sigma_jj &
                                         la_sig$sigma_jj <= la_sig$upper) else NA
  ok_order_vj <- if (nrow(la_vj) == T0) all(la_vj$lower <= la_vj$estimate &
                                            la_vj$estimate <= la_vj$upper,
                                            na.rm = TRUE) else NA
  ok_finite_va <- if (va_ci$healthy) all(is.finite(va_ci$lower) & is.finite(va_ci$upper)) else NA
  ok_finite_la <- if (la_sig$healthy) all(is.finite(la_sig$lower) & is.finite(la_sig$upper)) else NA
  ok_finite_vj <- if (nrow(la_vj) == T0) all(is.finite(la_vj$lower) & is.finite(la_vj$upper), na.rm = TRUE) else NA

  cat(sprintf(
    "seed %2d  load=%5.1f  VA[healthy=%s order=%s finite=%s log_sigma_se=%s]  LA[healthy=%s order=%s finite=%s]  Vj[n=%d order=%s finite=%s]\n",
    s, la, va_ci$healthy, ok_order_va, ok_finite_va,
    if (isTRUE(va_ci$healthy)) va_ci$log_sigma_has_se else NA,
    la_sig$healthy, ok_order_la, ok_finite_la,
    nrow(la_vj), ok_order_vj, ok_finite_vj
  ))
  flush.console()

  rows[[s]] <- list(va_ci = va_ci, la_sig = la_sig, la_vj = la_vj,
                     va_cover = va_cover, la_cover = la_cover,
                     la_vj_cover = la_vj_cover,
                     ok_order_va = ok_order_va, ok_order_la = ok_order_la,
                     ok_order_vj = ok_order_vj,
                     ok_finite_va = ok_finite_va, ok_finite_la = ok_finite_la,
                     ok_finite_vj = ok_finite_vj)
}

## ---- PASS/FAIL ----------------------------------------------------------
any_va_healthy <- any(vapply(rows, function(r) isTRUE(r$va_ci$healthy), logical(1)))
any_la_healthy <- any(vapply(rows, function(r) isTRUE(r$la_sig$healthy), logical(1)))
any_vj_computed <- any(vapply(rows, function(r) nrow(r$la_vj) == T0, logical(1)))

order_ok <- all(vapply(rows, function(r) {
  isTRUE(r$ok_order_va) || is.na(r$ok_order_va)
}, logical(1))) &&
  all(vapply(rows, function(r) {
    isTRUE(r$ok_order_la) || is.na(r$ok_order_la)
  }, logical(1))) &&
  all(vapply(rows, function(r) {
    isTRUE(r$ok_order_vj) || is.na(r$ok_order_vj)
  }, logical(1)))

finite_ok <- all(vapply(rows, function(r) {
  isTRUE(r$ok_finite_va) || is.na(r$ok_finite_va)
}, logical(1))) &&
  all(vapply(rows, function(r) {
    isTRUE(r$ok_finite_la) || is.na(r$ok_finite_la)
  }, logical(1))) &&
  all(vapply(rows, function(r) {
    isTRUE(r$ok_finite_vj) || is.na(r$ok_finite_vj)
  }, logical(1)))

coverage_computes <- any(vapply(rows, function(r) any(!is.na(r$va_cover)), logical(1))) &&
  any(vapply(rows, function(r) any(!is.na(r$la_cover)), logical(1))) &&
  any(vapply(rows, function(r) any(!is.na(r$la_vj_cover)), logical(1)))

## The one thing this smoke exists to catch: a degenerate/failed fit must
## show up as `healthy = FALSE` / NA coverage, never as a finite CI silently
## scored as if nothing went wrong. There is no engineered-degenerate seed
## here (a handful of ordinary draws is not guaranteed to produce one), so
## this checks the MECHANISM is wired -- every non-healthy fit in the loop
## above already produced all-NA CI/coverage rather than a spurious number,
## which is exactly what the check below re-asserts.
degeneracy_handled <- all(vapply(rows, function(r) {
  va_ok <- isTRUE(r$va_ci$healthy) || (all(is.na(r$va_ci$lower)) && all(is.na(r$va_cover)))
  la_ok <- isTRUE(r$la_sig$healthy) || (all(is.na(r$la_sig$lower)) && all(is.na(r$la_cover)))
  va_ok && la_ok
}, logical(1)))

log_sigma_gap_confirmed <- any(vapply(rows, function(r) {
  isTRUE(r$va_ci$healthy) && isFALSE(r$va_ci$log_sigma_has_se)
}, logical(1))) || !any_va_healthy   # vacuously fine if no VA fit was healthy

cat("\n---- summary ----\n")
cat(sprintf("any VA-Wald healthy fit:      %s\n", any_va_healthy))
cat(sprintf("any LA-Wald healthy fit:      %s\n", any_la_healthy))
cat(sprintf("any LA-Profile V_j computed:  %s\n", any_vj_computed))
cat(sprintf("every interval correctly ordered (lower<=est<=upper) or NA: %s\n", order_ok))
cat(sprintf("every interval finite or NA:  %s\n", finite_ok))
cat(sprintf("coverage indicator computes for VA/LA/Vj: %s\n", coverage_computes))
cat(sprintf("degenerate/failed fits produce NA, never a spurious finite CI: %s\n", degeneracy_handled))
cat(sprintf("design item 21 (VA has no log_sigma Schur SE) reproduced: %s\n", log_sigma_gap_confirmed))

ok <- any_va_healthy && any_la_healthy && any_vj_computed &&
  order_ok && finite_ok && coverage_computes && degeneracy_handled &&
  log_sigma_gap_confirmed

cat(sprintf("\nCOVERAGE-SMOKE %s\n", if (isTRUE(ok)) "PASS" else "FAIL"))
