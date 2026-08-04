## Step-0 pilot for docs/design/va-interval-coverage-campaign.md (gate 0d).
## Production-scale DGP (T=8, d=q=2, per-trait beta_j, psi ~ U(0.3,0.5)),
## measures per-cell HEALTHY YIELD, per-seed/per-arm wall-clock, and whether
## each arm can produce the interval the design asks it for. NOT a coverage
## measurement -- n_seeds here is the design's own Step-0 number (30), sized
## for feasibility triage, not power.
##
## Usage: Rscript 40-step0-pilot.R <N0> <n_seeds> <cell_tag> <seed_offset>
## e.g.   Rscript 40-step0-pilot.R 150 30 primary_n150 0

args <- commandArgs(trailingOnly = TRUE)
N0        <- as.integer(args[[1]])
N_SEEDS   <- as.integer(args[[2]])
CELL_TAG  <- args[[3]]
SEED_OFF  <- if (length(args) >= 4) as.integer(args[[4]]) else 0L

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== Step-0 pilot cell=%s N0=%d n_seeds=%d starting %s ==\n",
            CELL_TAG, N0, N_SEEDS, format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
cat("== load_all done", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

## Warm-up: compile/load the VA-R3 TMB DLL ONCE, in this (parent) process,
## before mclapply forks. .va_r3_load_dll() keys its build directory off
## tempdir() and the source checksum; a forked child inherits both the
## compiled .so path AND the fact that it is already dyn.load()-ed, so this
## avoids every one of the N_SEEDS forked children racing to compile the
## SAME .cpp into the SAME build directory concurrently (observed in local
## testing with 2 concurrent workers before this warm-up was added).
invisible(gllvmTMB:::.va_r3_load_dll())
cat("== VA-R3 DLL warm-loaded", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

## ---- production DGP (design doc "DGP" section) -------------------------
T0 <- 8L
Q0 <- 2L
PSI_LO <- 0.3; PSI_HI <- 0.5
CI_LEVEL <- 0.95
Z <- stats::qnorm(0.5 + CI_LEVEL / 2)

sim_cell <- function(seed) {
  set.seed(seed)
  ## Lambda: diagonal ~ U(0.7,1.3); lower-tri off-diag ~ U(-0.5,0.5);
  ## remaining (T-d) rows ~ N(0, 0.7^2) per entry.
  Lambda <- matrix(0, T0, Q0)
  for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
  if (Q0 >= 2) {
    for (k in 1:(Q0 - 1)) {
      for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
    }
  }
  if (T0 > Q0) {
    for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
  }
  psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
  beta_true <- stats::rnorm(T0, 0, 0.5)

  z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
  x <- stats::rnorm(N0)
  eta <- outer(x, beta_true) + z %*% t(Lambda)      # N0 x T0
  y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)

  d <- data.frame(
    y = as.numeric(t(y)),
    trait = factor(rep(seq_len(T0), times = N0)),
    unit  = factor(rep(seq_len(N0), each = T0)),
    x     = rep(x, each = T0)
  )
  Sigma_true <- Lambda %*% t(Lambda)
  list(d = d, Lambda_true = Lambda, psi_true = psi_true, beta_true = beta_true,
       sigma_jj_true = diag(Sigma_true),
       v_j_true = diag(Sigma_true) + psi_true)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- one seed, all arms --------------------------------------------------
run_seed <- function(seed_id) {
  t0 <- Sys.time()
  b <- sim_cell(seed_id)
  timing <- list()
  health <- list()

  ## VA-Wald --------------------------------------------------------------
  Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  ## columns: T0 trait intercepts + T0 trait:x slopes -- matches per-trait
  ## beta_j (design's (0+trait):x idiom, the correct term for planted
  ## per-trait slopes -- see design doc "Per-trait slopes").
  t_va0 <- Sys.time()
  va_fit <- tryCatch(
    do.call(gllvmTMB:::.va_r3_fit, list(
      y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = Xva,
      unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
      q = Q0, family = "gaussian_anchor", link = "identity",
      unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
      n_starts = 4L,
      control = list(eval.max = 2000L, iter.max = 2000L)
    )),
    error = function(e) { attr(e, "va_fit_error") <- TRUE; e }
  )
  timing$va_fit_s <- as.numeric(difftime(Sys.time(), t_va0, units = "secs"))

  va_healthy <- !inherits(va_fit, "error") &&
    isTRUE(va_fit$health$admitted) && identical(va_fit$status, "healthy")
  health$va_status <- if (inherits(va_fit, "error")) {
    paste0("fit_error: ", conditionMessage(va_fit))
  } else (va_fit$status %||% "unknown")

  va_sigma <- NULL
  va_log_sigma_has_se <- NA
  va_gradnorm <- NA_real_
  t_va_se0 <- Sys.time()
  if (va_healthy) {
    va_gradnorm <- tryCatch(
      max(abs(as.numeric(va_fit$objective$gr(va_fit$best$par)))),
      error = function(e) NA_real_
    )
    se_info <- tryCatch(
      gllvmTMB:::.va_r3_fixed_information_blocked(
        objective = va_fit$objective, par = va_fit$best$par, N = N0, q = Q0
      ),
      error = function(e) NULL
    )
    va_log_sigma_has_se <- if (!is.null(se_info) && !is.null(se_info$se_profile)) {
      "log_sigma" %in% names(se_info$se_profile)
    } else NA
    va_sigma <- tryCatch(
      gllvmTMB:::.va_wald_loadings_ci(va_fit, T = T0, level = CI_LEVEL),
      error = function(e) { attr(e, "loadings_ci_error") <- TRUE; e }
    )
  }
  timing$va_se_s <- as.numeric(difftime(Sys.time(), t_va_se0, units = "secs"))
  va_sigma_ok <- !is.null(va_sigma) && !inherits(va_sigma, "error")
  health$va_sigma_status <- if (inherits(va_sigma, "error")) {
    paste0("loadings_ci_error: ", conditionMessage(va_sigma))
  } else if (va_sigma_ok) "ok" else "not_attempted"

  ## LA-Wald + LA-Profile ---------------------------------------------------
  t_la0 <- Sys.time()
  la_fit <- tryCatch(
    gllvmTMB::gllvmTMB(
      ## `unique = TRUE`, not FALSE. The DGP PLANTS psi_j ~ U(PSI_LO, PSI_HI),
      ## and the scored estimand is V_j = Sigma_jj + psi_j -- so a loadings-only
      ## tier cannot represent the truth it is being scored against. Under the old
      ## `unique = FALSE` the fit carried no theta_diag_B, `.total_variance_spec()`
      ## silently took psi_j = 0, and the arm reported Sigma_jj under the name V_j:
      ## point-estimate gaps tracked the planted psi_j almost exactly and coverage
      ## fell 0.517 -> 0.300 -> 0.096. That silent substitution is now a hard error
      ## (coverage blocker 2, 2a174fb9); this is the matching design fix.
      y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = TRUE),
      data = b$d, family = stats::gaussian(), unit = "unit", silent = TRUE
    ),
    error = function(e) { attr(e, "la_fit_error") <- TRUE; e }
  )
  timing$la_fit_s <- as.numeric(difftime(Sys.time(), t_la0, units = "secs"))
  la_healthy <- !inherits(la_fit, "error") &&
    isTRUE(la_fit$sd_report$pdHess %||% FALSE)
  health$la_status <- if (inherits(la_fit, "error")) {
    paste0("fit_error: ", conditionMessage(la_fit))
  } else if (la_healthy) "healthy" else "not_pdHess"

  la_sigma <- NULL
  t_la_se0 <- Sys.time()
  if (la_healthy) {
    delta <- tryCatch(
      gllvmTMB:::.loading_delta_at_mle(fit = la_fit, internal_level = "B",
                                       loading_scale = "raw"),
      error = function(e) { attr(e, "delta_error") <- TRUE; e }
    )
    if (!inherits(delta, "error")) {
      Lambda_hat <- matrix(delta$Lambda, T0, Q0)
      cov_vec <- delta$cov_vec
      sigma_jj <- rowSums(Lambda_hat^2)
      eps <- 1e-6
      J <- matrix(0, T0, T0 * Q0)
      Lam_vec <- as.numeric(Lambda_hat)
      for (p in seq_len(T0 * Q0)) {
        bump <- Lam_vec; bump[p] <- bump[p] + eps
        Bm <- matrix(bump, T0, Q0)
        J[, p] <- (rowSums(Bm^2) - sigma_jj) / eps
      }
      cov_sigma <- J %*% cov_vec %*% t(J)
      se_sigma_jj <- sqrt(pmax(diag(cov_sigma), 0))
      la_sigma <- list(sigma_jj = sigma_jj, se = se_sigma_jj,
                       lower = sigma_jj - Z * se_sigma_jj,
                       upper = sigma_jj + Z * se_sigma_jj)
    } else {
      la_sigma <- delta
    }
  }
  timing$la_se_s <- as.numeric(difftime(Sys.time(), t_la_se0, units = "secs"))
  la_sigma_ok <- !is.null(la_sigma) && !inherits(la_sigma, "error")
  health$la_sigma_status <- if (inherits(la_sigma, "error")) {
    paste0("delta_error: ", conditionMessage(la_sigma))
  } else if (la_sigma_ok) "ok" else "not_attempted"

  la_vj <- NULL
  t_prof0 <- Sys.time()
  if (la_healthy) {
    la_vj <- tryCatch(
      gllvmTMB:::.profile_ci_total_variance(la_fit, tier = "unit"),
      error = function(e) { attr(e, "profile_error") <- TRUE; e }
    )
  }
  timing$la_profile_s <- as.numeric(difftime(Sys.time(), t_prof0, units = "secs"))
  la_vj_ok <- !is.null(la_vj) && !inherits(la_vj, "error") && nrow(la_vj) == T0
  health$la_vj_status <- if (inherits(la_vj, "error")) {
    paste0("profile_error: ", conditionMessage(la_vj))
  } else if (la_vj_ok) "ok" else "not_attempted"

  ## coverage indicators ----------------------------------------------------
  va_cover <- if (va_sigma_ok) {
    (b$sigma_jj_true >= va_sigma$lower[va_sigma$row == va_sigma$col]) &
      (b$sigma_jj_true <= va_sigma$upper[va_sigma$row == va_sigma$col])
  } else rep(NA, T0)
  la_cover <- if (la_sigma_ok) {
    (b$sigma_jj_true >= la_sigma$lower) & (b$sigma_jj_true <= la_sigma$upper)
  } else rep(NA, T0)
  la_vj_cover <- if (la_vj_ok) {
    (b$v_j_true >= la_vj$lower) & (b$v_j_true <= la_vj$upper)
  } else rep(NA, T0)

  ## numerical-health record (design doc "Degeneracy and failure handling") -
  psi_ratio <- if (va_healthy) {
    par <- va_fit$best$par
    ls <- par[names(par) == "log_sigma"]
    if (length(ls) == T0) exp(2 * ls) / b$psi_true else rep(NA_real_, T0)
  } else rep(NA_real_, T0)

  list(
    seed = seed_id, timing = timing, health = health,
    va_healthy = va_healthy, la_healthy = la_healthy,
    va_sigma_ok = va_sigma_ok, la_sigma_ok = la_sigma_ok, la_vj_ok = la_vj_ok,
    va_log_sigma_has_se = va_log_sigma_has_se,
    va_gradnorm = va_gradnorm,
    psi_ratio_range = if (all(is.na(psi_ratio))) c(NA, NA) else range(psi_ratio, na.rm = TRUE),
    va_cover = va_cover, la_cover = la_cover, la_vj_cover = la_vj_cover,
    total_s = as.numeric(difftime(Sys.time(), t0, units = "secs"))
  )
}

## ---- run all seeds, in parallel (single-threaded R workers) -------------
seed_ids <- 20260800L + SEED_OFF + seq_len(N_SEEDS)
n_cores <- min(N_SEEDS, as.integer(Sys.getenv("PILOT_CORES", "30")))
cat(sprintf("== running %d seeds on %d cores ==\n", N_SEEDS, n_cores)); flush.console()

results <- mclapply(seed_ids, function(s) {
  tryCatch(run_seed(s), error = function(e) {
    list(seed = s, error = conditionMessage(e))
  })
}, mc.cores = n_cores, mc.preschedule = FALSE)

saveRDS(results, sprintf("dev/va-speed/40-step0-pilot-%s.rds", CELL_TAG))

## ---- summarise -------------------------------------------------------
ok <- function(r) is.null(r$error)
n_ok <- sum(vapply(results, ok, logical(1)))
cat(sprintf("\n== %d/%d seeds returned without a harness-level error ==\n", n_ok, N_SEEDS))

get_num <- function(field) vapply(results, function(r) {
  if (!ok(r)) return(NA_real_)
  r[[field]] %||% NA_real_
}, numeric(1))
get_bool <- function(field) vapply(results, function(r) {
  if (!ok(r)) return(NA)
  isTRUE(r[[field]])
}, logical(1))

va_healthy_v <- get_bool("va_healthy")
la_healthy_v <- get_bool("la_healthy")
va_sigma_ok_v <- get_bool("va_sigma_ok")
la_sigma_ok_v <- get_bool("la_sigma_ok")
la_vj_ok_v <- get_bool("la_vj_ok")

cat(sprintf("VA-Wald healthy yield:     %d/%d = %.3f\n", sum(va_healthy_v, na.rm=TRUE), N_SEEDS, mean(va_healthy_v, na.rm=TRUE)))
cat(sprintf("LA-Wald healthy yield:     %d/%d = %.3f\n", sum(la_healthy_v, na.rm=TRUE), N_SEEDS, mean(la_healthy_v, na.rm=TRUE)))
cat(sprintf("VA Sigma_jj CI produced:   %d/%d = %.3f\n", sum(va_sigma_ok_v, na.rm=TRUE), N_SEEDS, mean(va_sigma_ok_v, na.rm=TRUE)))
cat(sprintf("LA Sigma_jj CI produced:   %d/%d = %.3f\n", sum(la_sigma_ok_v, na.rm=TRUE), N_SEEDS, mean(la_sigma_ok_v, na.rm=TRUE)))
cat(sprintf("LA-Profile V_j produced:   %d/%d = %.3f\n", sum(la_vj_ok_v, na.rm=TRUE), N_SEEDS, mean(la_vj_ok_v, na.rm=TRUE)))

va_log_sigma_has_se_v <- vapply(results, function(r) if (!ok(r)) NA else isTRUE(r$va_log_sigma_has_se), logical(1))
cat(sprintf("VA se_profile carries log_sigma (any healthy seed): %s\n",
            any(va_log_sigma_has_se_v, na.rm = TRUE)))

va_fit_t <- get_num("total_s")  # placeholder; real per-arm timings below
timing_field <- function(f) vapply(results, function(r) {
  if (!ok(r)) return(NA_real_)
  r$timing[[f]] %||% NA_real_
}, numeric(1))

for (f in c("va_fit_s", "va_se_s", "la_fit_s", "la_se_s", "la_profile_s")) {
  v <- timing_field(f)
  cat(sprintf("timing %-14s median=%.2fs mean=%.2fs range=[%.2f, %.2f]s (n=%d finite)\n",
              f, stats::median(v, na.rm=TRUE), mean(v, na.rm=TRUE),
              suppressWarnings(min(v, na.rm=TRUE)), suppressWarnings(max(v, na.rm=TRUE)),
              sum(is.finite(v))))
}

va_grad <- get_num("va_gradnorm")
cat(sprintf("VA gradient norm at optimum (healthy fits): median=%.3g max=%.3g\n",
            stats::median(va_grad, na.rm=TRUE), suppressWarnings(max(va_grad, na.rm=TRUE))))

## coverage (descriptive only -- 30 seeds is far below the 2*MCSE detection floor)
cov_mean <- function(field) {
  m <- do.call(rbind, lapply(results, function(r) {
    if (!ok(r) || is.null(r[[field]])) return(rep(NA, T0))
    r[[field]]
  }))
  mean(m, na.rm = TRUE)
}
cat(sprintf("descriptive mean VA Sigma_jj coverage (NOT a calibrated estimate, n=%d seeds): %.3f\n",
            N_SEEDS, cov_mean("va_cover")))
cat(sprintf("descriptive mean LA Sigma_jj coverage (NOT a calibrated estimate, n=%d seeds): %.3f\n",
            N_SEEDS, cov_mean("la_cover")))
cat(sprintf("descriptive mean LA-Profile V_j coverage (NOT a calibrated estimate, n=%d seeds): %.3f\n",
            N_SEEDS, cov_mean("la_vj_cover")))

status_table <- function(field) {
  s <- vapply(results, function(r) if (!ok(r)) paste0("harness_error: ", r$error) else (r$health[[field]] %||% "NA"), character(1))
  table(s)
}
cat("\n-- VA status table --\n"); print(status_table("va_status"))
cat("\n-- LA status table --\n"); print(status_table("la_status"))
cat("\n-- LA-Profile status table --\n"); print(status_table("la_vj_status"))

cat(sprintf("\n== Step-0 pilot cell=%s DONE %s ==\n", CELL_TAG, format(Sys.time(), "%H:%M:%S")))
