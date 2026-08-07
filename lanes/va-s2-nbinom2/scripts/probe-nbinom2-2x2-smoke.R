#!/usr/bin/env Rscript
## NB2 (nbinom2) local 2×2 smoke — Design-110 geometry; Process C hybrid.
## Arms: gllvmTMB VA-GH H=7 / gllvmTMB LA / gllvm VA / gllvm LA
## Registry: Design-110 family_id 5 = NB2/log → GH (no closed-form ELBO).
## n=120 p=8 q=2 unique=FALSE; warm DLL outside timed cells; se=FALSE;
## matched starts (gtmb VA n_starts=1; gllvm n.init=1).
## Local ≤10 cores. No Totoro. D-50: /private/tmp only. No PASS claim from smoke.

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-s2-nbinom2-2x2-smoke-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "16"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "11201")) + seq_len(N_SEED) - 1L
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
N_STARTS <- as.integer(Sys.getenv("PROBE_N_STARTS", "1"))
PHI_TRUE <- as.numeric(Sys.getenv("PROBE_PHI", "1.5"))
N <- 120L
P <- 8L
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-3"))
CAP_BETA <- 0.35
CAP_SIG <- 0.50
FAMILY_ID <- 5L ## nbinom2

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1"
)
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(parallel)
})
stopifnot(requireNamespace("gllvm", quietly = TRUE))
## Warm DLL outside per-seed timer (VA speed retraction lesson).
invisible(gllvmTMB:::.va_r3_load_dll())
cat("gllvm:", as.character(packageVersion("gllvm")), "\n")
cat("repo:", REPO, " out:", OUT, "\n")
cat(sprintf(
  "n=%d p=%d q=%d H=%d n_starts=%d seeds=%d cores=%d phi=%g\n",
  N, P, Q, VA_H, N_STARTS, N_SEED, CORES, PHI_TRUE
))

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

simulate_dgp <- function(seed, q = Q, n = N, p = P, phi = PHI_TRUE) {
  ## Design-110 loadings-only DGP (Σ = ΛΛ'); NB2 size = phi (Var = μ + μ²/φ).
  set.seed(seed)
  stopifnot(p >= q)
  Lambda <- matrix(rnorm(p * q, 0, 0.25), p, q)
  for (k in seq_len(q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(n * q), n, q)
  beta <- seq(-0.25, 0.25, length.out = p)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  mu <- exp(eta)
  Y <- matrix(rnbinom(n * p, mu = as.vector(mu), size = phi), n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    seed = seed, n = n, p = p, q = q, phi = phi,
    data = dat, Y = Y, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda)
  )
}

frob_norm <- function(A) {
  if (!is.matrix(A)) return(NA_real_)
  sqrt(sum(A^2))
}

rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  den <- frob_norm(Strue)
  if (!is.finite(den) || den <= 0) return(NA_real_)
  frob_norm(Shat - Strue) / den
}

sigma_collapsed <- function(Shat, Strue, tol = 1e-8) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA)
  den <- frob_norm(Strue)
  if (!is.finite(den) || den <= 0) return(NA)
  isTRUE(frob_norm(Shat) < tol * den)
}

beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}

fail_arm <- function(arm, err, secs = NA_real_) {
  list(
    arm = arm, ok = FALSE, healthy = FALSE, secs = secs,
    beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    frob_Shat = NA_real_, sigma_collapse = NA,
    phi_mean = NA_real_, max_g_fe = NA_real_,
    max_abs_loading = NA_real_, err = err
  )
}

score_arm <- function(arm, beta_hat, Sigma_hat, dgp, healthy, secs,
                      phi_mean = NA_real_, max_g_fe = NA_real_,
                      max_abs_loading = NA_real_, err = NA_character_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  fS <- if (is.matrix(Sigma_hat)) frob_norm(Sigma_hat) else NA_real_
  list(
    arm = arm,
    ok = is.finite(br) && is.finite(sr),
    healthy = isTRUE(healthy),
    secs = secs,
    beta_rmse = br,
    sigma_rel_frob = sr,
    frob_Shat = fS,
    sigma_collapse = sigma_collapsed(Sigma_hat, dgp$Sigma),
    phi_mean = phi_mean,
    max_g_fe = max_g_fe,
    max_abs_loading = max_abs_loading,
    err = err
  )
}

gtmb_la_health <- function(fit, tol = GRAD_TOL) {
  ## FE-only |g| (S0b retracts full last.par.best gr as LA health).
  ## With se=FALSE there is often no sd_report/pdHess — skip PD when absent.
  conv <- as.integer(fit$opt$convergence %||% NA_integer_)
  has_sd <- !is.null(fit$sd_report) && !is.null(fit$sd_report$pdHess)
  pd <- if (has_sd) isTRUE(fit$sd_report$pdHess) else NA
  obj <- fit$tmb_obj
  fe <- fit$opt$par %||% obj$par
  g_fe <- tryCatch(max(abs(as.numeric(obj$gr(fe)))), error = function(e) Inf)
  healthy_fe <- identical(conv, 0L) && is.finite(g_fe) && g_fe < tol &&
    (is.na(pd) || isTRUE(pd))
  list(
    conv = conv, pd = pd, max_g_fe = as.numeric(g_fe),
    healthy_fe = isTRUE(healthy_fe)
  )
}

## ---- gllvmTMB VA — private GH H=7 via .va_r3_fit (n_starts matched) --------
fit_gtmb_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  ns <- asNamespace("gllvmTMB")
  engine <- get(".va_r3_fit", envir = ns)
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  result <- tryCatch(
    engine(
      y = dat$value,
      n_trials = rep.int(1, n_obs),
      X = X,
      unit_id = as.integer(dat$unit),
      trait_id = as.integer(dat$trait),
      q = dgp$q,
      N = dgp$n,
      T = dgp$p,
      H = VA_H,
      eval_method = "gh",
      family_codes = rep.int(FAMILY_ID, n_obs),
      link_ids = rep.int(0L, n_obs),
      n_ordinal_cuts_per_trait = integer(dgp$p),
      ordinal_offset_per_trait = integer(dgp$p),
      ordinal_log_increments_start = numeric(),
      fixed_tweedie_power = NULL,
      fixed_student_df = NULL,
      match_laplace_residual_sd = FALSE,
      n_starts = N_STARTS,
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(result, "error")) {
    return(fail_arm("gtmb_va", conditionMessage(result), secs))
  }
  best <- result$best %||% list()
  par <- best$par %||% NULL
  beta_hat <- if (!is.null(par) && !is.null(names(par))) {
    as.numeric(par[names(par) == "beta"])
  } else {
    NA_real_
  }
  Sigma_hat <- result$report$Sigma_B %||% NULL
  if (is.null(Sigma_hat)) {
    Lam <- result$report$Lambda_B %||% result$report$lambda_B
    if (!is.null(Lam)) Sigma_hat <- Lam %*% t(Lam)
  }
  phi_hat <- NA_real_
  if (!is.null(par) && !is.null(names(par))) {
    lp <- as.numeric(par[names(par) == "log_phi_nbinom2"])
    if (length(lp) && all(is.finite(lp))) phi_hat <- mean(exp(lp))
  }
  max_abs_L <- if (is.matrix(result$report$Lambda_B %||% NULL)) {
    max(abs(result$report$Lambda_B))
  } else {
    NA_real_
  }
  healthy <- identical(result$status, "healthy")
  score_arm(
    "gtmb_va", beta_hat, Sigma_hat, dgp, healthy, secs,
    phi_mean = phi_hat,
    max_g_fe = as.numeric(best$max_abs_gradient %||% NA_real_),
    max_abs_loading = max_abs_L,
    err = if (healthy) NA_character_ else paste0("status=", result$status %||% "NULL")
  )
}

## ---- gllvmTMB Laplace — public formula API; se=FALSE ----------------------
fit_gtmb_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    dgp$q
  ))
  fit <- tryCatch(
    gllvmTMB(
      form,
      data = dgp$data,
      unit = "unit",
      family = nbinom2(),
      control = gllvmTMBcontrol(integration = "laplace", se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm("gtmb_la", conditionMessage(fit), secs))
  }
  h <- gtmb_la_health(fit)
  beta_hat <- tryCatch({
    ns <- asNamespace("gllvmTMB")
    if (exists(".gllvmTMB_b_fixed_values", envir = ns, inherits = FALSE)) {
      as.numeric(get(".gllvmTMB_b_fixed_values", envir = ns)(fit))
    } else {
      as.numeric(coef(fit))
    }
  }, error = function(e) NA_real_)
  if (length(beta_hat) != dgp$p || any(!is.finite(beta_hat))) {
    beta_hat <- tryCatch({
      par <- fit$opt$par %||% fit$tmb_obj$par
      nm <- names(par)
      as.numeric(par[startsWith(nm, "b_fix") | nm == "b_fixed"])[seq_len(dgp$p)]
    }, error = function(e) NA_real_)
  }
  ## Loadings-only Σ_B vs planted ΛΛ' (do not use extract_Sigma shared+Ψ path).
  Sigma_hat <- tryCatch({
    S <- fit$report$Sigma_B %||% NULL
    if (is.null(S)) {
      Lam <- fit$report$Lambda_B %||% fit$report$lambda_B
      if (!is.null(Lam)) Lam %*% t(Lam) else NULL
    } else {
      S
    }
  }, error = function(e) NULL)
  max_abs_L <- if (is.matrix(fit$report$Lambda_B %||% NULL)) {
    max(abs(fit$report$Lambda_B))
  } else if (is.matrix(Sigma_hat)) {
    NA_real_
  } else {
    NA_real_
  }
  phi_hat <- tryCatch({
    par <- fit$opt$par %||% fit$tmb_obj$par
    nm <- names(par)
    lp <- as.numeric(par[grepl("log_phi_nbinom2|log_phi", nm)])
    if (length(lp) && all(is.finite(lp))) mean(exp(lp)) else NA_real_
  }, error = function(e) NA_real_)
  score_arm(
    "gtmb_la", beta_hat, Sigma_hat, dgp, h$healthy_fe, secs,
    phi_mean = phi_hat, max_g_fe = h$max_g_fe,
    max_abs_loading = max_abs_L
  )
}

## ---- gllvm CRAN — family="negative.binomial" ------------------------------
fit_gllvm <- function(dgp, method) {
  arm <- paste0("gllvm_", tolower(method))
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y,
      family = "negative.binomial",
      num.lv = dgp$q,
      method = method,
      seed = as.integer(dgp$seed),
      trace = FALSE,
      sd.errors = FALSE,
      control.start = list(starting.val = "zero", n.init = 1)
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(fail_arm(arm, conditionMessage(f), secs))
  }
  beta_hat <- as.numeric(f$params$beta0)
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) {
    sweep(th, 2L, sg, "*")
  } else {
    th
  }
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  if (nrow(L) != dgp$p) {
    return(fail_arm(
      arm,
      sprintf("theta dim %s vs p=%d", paste(dim(L), collapse = "x"), dgp$p),
      secs
    ))
  }
  Sigma_hat <- L %*% t(L)
  ## gllvm NB phi is often dispersion (Var = μ + φμ²) = 1/size; report raw mean.
  phi_raw <- tryCatch(as.numeric(f$params$phi), error = function(e) NA_real_)
  phi_mean <- if (length(phi_raw) && all(is.finite(phi_raw))) {
    mean(phi_raw)
  } else {
    NA_real_
  }
  looks <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  score_arm(
    arm, beta_hat, Sigma_hat, dgp, looks, secs,
    phi_mean = phi_mean,
    max_abs_loading = max(abs(L))
  )
}

one_job <- function(seed) {
  dgp <- simulate_dgp(seed)
  arms <- list(
    tryCatch(fit_gtmb_va(dgp), error = function(e) fail_arm("gtmb_va", conditionMessage(e))),
    tryCatch(fit_gtmb_la(dgp), error = function(e) fail_arm("gtmb_la", conditionMessage(e))),
    tryCatch(fit_gllvm(dgp, "VA"), error = function(e) fail_arm("gllvm_va", conditionMessage(e))),
    tryCatch(fit_gllvm(dgp, "LA"), error = function(e) fail_arm("gllvm_la", conditionMessage(e)))
  )
  rows <- lapply(arms, function(a) {
    data.frame(
      seed = seed, q = dgp$q, n = dgp$n, p = dgp$p,
      arm = a$arm,
      ok = isTRUE(a$ok),
      healthy = isTRUE(a$healthy),
      beta_rmse = as.numeric(a$beta_rmse %||% NA_real_),
      sigma_rel_frob = as.numeric(a$sigma_rel_frob %||% NA_real_),
      frob_Shat = as.numeric(a$frob_Shat %||% NA_real_),
      sigma_collapse = as.logical(a$sigma_collapse %||% NA),
      phi_mean = as.numeric(a$phi_mean %||% NA_real_),
      max_g_fe = as.numeric(a$max_g_fe %||% NA_real_),
      max_abs_loading = as.numeric(a$max_abs_loading %||% NA_real_),
      secs = as.numeric(a$secs %||% NA_real_),
      pass_abs = isTRUE(a$ok) &&
        is.finite(a$beta_rmse) && is.finite(a$sigma_rel_frob) &&
        a$beta_rmse <= CAP_BETA && a$sigma_rel_frob <= CAP_SIG,
      err = as.character(a$err %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

cat(sprintf("== warm-up %s ==\n", format(Sys.time(), "%H:%M:%S")))
wu <- tryCatch(one_job(99951L), error = function(e) {
  cat("warm-up fail:", conditionMessage(e), "\n"); NULL
})
if (!is.null(wu)) {
  print(wu[, c("arm", "ok", "healthy", "beta_rmse", "sigma_rel_frob",
               "secs", "pass_abs", "phi_mean")], digits = 4)
}

cat(sprintf("== probe start %s ==\n", format(Sys.time(), "%H:%M:%S")))
run_one <- function(i) {
  tryCatch(one_job(SEEDS[[i]]), error = function(e) {
    data.frame(
      seed = SEEDS[[i]], q = Q, n = N, p = P, arm = "ERROR",
      ok = FALSE, healthy = FALSE, beta_rmse = NA_real_,
      sigma_rel_frob = NA_real_, frob_Shat = NA_real_,
      sigma_collapse = NA, phi_mean = NA_real_, max_g_fe = NA_real_,
      max_abs_loading = NA_real_, secs = NA_real_, pass_abs = FALSE,
      err = conditionMessage(e), stringsAsFactors = FALSE
    )
  })
}

parts <- if (CORES <= 1L) {
  lapply(seq_along(SEEDS), run_one)
} else {
  mclapply(seq_along(SEEDS), run_one, mc.cores = CORES, mc.preschedule = FALSE)
}
raw <- do.call(rbind, parts)
write.csv(raw, file.path(OUT, "smoke-rows.csv"), row.names = FALSE)

arm_levels <- c("gtmb_va", "gtmb_la", "gllvm_va", "gllvm_la")
raw$arm <- factor(raw$arm, levels = arm_levels)

summ_list <- lapply(arm_levels, function(nm) {
  sub <- raw[as.character(raw$arm) == nm, , drop = FALSE]
  fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
  secs_ok <- is.finite(sub$secs)
  la_secs <- raw$secs[as.character(raw$arm) == "gtmb_la" &
                        raw$seed %in% sub$seed]
  la_mean <- mean(la_secs, na.rm = TRUE)
  data.frame(
    arm = nm,
    n_seed = nrow(sub),
    n_ok = sum(fin),
    n_healthy = sum(isTRUE(sub$healthy) | sub$healthy == TRUE, na.rm = TRUE),
    beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
    sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
    frac_sigma_gt_0.5 = if (any(fin)) mean(sub$sigma_rel_frob[fin] > CAP_SIG) else NA_real_,
    pass_abs = if (any(fin)) mean(sub$pass_abs[fin]) else NA_real_,
    frac_collapse = if (any(!is.na(sub$sigma_collapse))) {
      mean(sub$sigma_collapse, na.rm = TRUE)
    } else {
      NA_real_
    },
    max_abs_loading_mean = mean(sub$max_abs_loading, na.rm = TRUE),
    phi_mean = mean(sub$phi_mean, na.rm = TRUE),
    secs_mean = if (any(secs_ok)) mean(sub$secs[secs_ok]) else NA_real_,
    secs_median = if (any(secs_ok)) stats::median(sub$secs[secs_ok]) else NA_real_,
    secs_ratio_vs_gtmb_la = if (any(secs_ok) && is.finite(la_mean) && la_mean > 0) {
      mean(sub$secs[secs_ok]) / la_mean
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
})
summ <- do.call(rbind, summ_list)
write.csv(summ, file.path(OUT, "smoke-summary.csv"), row.names = FALSE)

cat("\n======== NB2 2x2 SMOKE (n=120 p=8 q=2; abs caps β≤0.35 / Σ≤0.50) ========\n")
cat("NOTE: smoke only — do NOT claim PASS/FAIL from this panel.\n")
print(summ, row.names = FALSE, digits = 4)

cat("\n======== cost ratios vs gtmb_la ========\n")
print(summ[, c("arm", "secs_mean", "secs_median", "secs_ratio_vs_gtmb_la")],
      row.names = FALSE, digits = 4)

cat("\nWrote:", file.path(OUT, "smoke-rows.csv"), "\n")
cat("Wrote:", file.path(OUT, "smoke-summary.csv"), "\n")
cat(sprintf("== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
