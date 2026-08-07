#!/usr/bin/env Rscript
## Gamma Laplace head-to-head: gllvmTMB LA vs gllvm LA (primary).
## Optional VA×2 when DO_VA=1 (q=5 VA is slow — default off for local probes).
##
## Health (post abaf7802): FE-only |g| via opt$par / lfixed(), plus buggy
## full-vector |g| for contrast. Never grade health on last.par.best.
##
## DGP: Design-110 exact (n=120, p=8, Σ=ΛΛ', unique=FALSE, shape=2.5).
## Caps: β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50.
## Compute: local ≤10 cores. D-50: raw CSV under /private/tmp only.

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-gamma-la-h2h-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, 10L))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "24"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "93001")) + seq_len(N_SEED) - 1L
QS <- as.integer(strsplit(Sys.getenv("PROBE_QS", "2,5"), ",", fixed = TRUE)[[1L]])
DO_VA <- identical(Sys.getenv("DO_VA", "0"), "1")
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-3"))
N <- 120L
P <- 8L
SHAPE <- 2.5
CAP_BETA <- 0.35
CAP_SIG <- 0.50

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
if (DO_VA) invisible(gllvmTMB:::.va_r3_load_dll())
cat("gllvm:", as.character(packageVersion("gllvm")), "\n")
cat("repo:", REPO, " out:", OUT, " cores:", CORES,
    " seeds:", N_SEED, " qs:", paste(QS, collapse = ","),
    " DO_VA:", DO_VA, "\n")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

simulate_dgp <- function(seed, q, n = N, p = P, shape = SHAPE) {
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
  Y <- matrix(
    rgamma(n * p, shape = shape, scale = as.vector(exp(eta)) / shape),
    n, p
  )
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    seed = seed, n = n, p = p, q = q, shape = shape,
    data = dat, Y = Y, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda)
  )
}

rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  sqrt(sum((Shat - Strue)^2)) / sqrt(sum(Strue^2))
}

beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}

gtmb_health <- function(fit, tol = GRAD_TOL) {
  conv <- as.integer(fit$opt$convergence %||% NA_integer_)
  pd <- isTRUE(fit$sd_report$pdHess)
  obj <- fit$tmb_obj
  fe <- fit$opt$par %||% obj$par
  full <- obj$env$last.par.best
  g_fe <- tryCatch(max(abs(as.numeric(obj$gr(fe)))), error = function(e) Inf)
  g_full <- tryCatch(max(abs(as.numeric(obj$gr(full)))), error = function(e) Inf)
  list(
    conv = conv,
    pd = pd,
    max_g_fe = as.numeric(g_fe),
    max_g_full = as.numeric(g_full),
    healthy_fe = identical(conv, 0L) && isTRUE(pd) &&
      is.finite(g_fe) && g_fe < tol,
    healthy_proxy = identical(conv, 0L) && isTRUE(pd),
    healthy_bug = identical(conv, 0L) && isTRUE(pd) &&
      is.finite(g_full) && g_full < tol
  )
}

fit_gtmb_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    dgp$q
  ))
  fit <- tryCatch(
    gllvmTMB(
      form, data = dgp$data, unit = "unit", family = Gamma(link = "log"),
      control = gllvmTMBcontrol(integration = "laplace", se = TRUE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(list(
      arm = "gtmb_la", ok = FALSE, secs = secs, err = conditionMessage(fit),
      conv = NA_integer_, pd = NA, max_g_fe = NA_real_, max_g_full = NA_real_,
      healthy_fe = FALSE, healthy_proxy = FALSE, healthy_bug = FALSE,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_, shape_mean = NA_real_
    ))
  }
  h <- gtmb_health(fit)
  bhat <- tryCatch(
    as.numeric(gllvmTMB:::.gllvmTMB_b_fix_values(fit)),
    error = function(e) {
      pl <- fit$tmb_obj$env$parList(fit$opt$par %||% fit$tmb_obj$par)
      as.numeric(pl$b_fixed %||% NA)
    }
  )
  Shat <- tryCatch({
    S <- extract_Sigma(fit, level = "unit", part = "shared")
    if (is.list(S)) {
      mats <- Filter(is.matrix, S)
      if (length(mats)) mats[[1L]] else NULL
    } else S
  }, error = function(e) NULL)
  shape_hat <- tryCatch({
    pl <- fit$tmb_obj$env$parList(
      fit$tmb_obj$env$last.par.best %||% fit$opt$par
    )
    mean(exp(as.numeric(pl$log_phi_gamma)))
  }, error = function(e) NA_real_)
  list(
    arm = "gtmb_la", ok = TRUE, secs = secs, err = NA_character_,
    conv = h$conv, pd = h$pd, max_g_fe = h$max_g_fe, max_g_full = h$max_g_full,
    healthy_fe = h$healthy_fe, healthy_proxy = h$healthy_proxy,
    healthy_bug = h$healthy_bug,
    beta_rmse = beta_rmse(bhat, dgp$beta),
    sigma_rel_frob = rel_frob(Shat, dgp$Sigma),
    shape_mean = shape_hat
  )
}

fit_gllvm_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y, family = "gamma", num.lv = dgp$q, method = "LA",
      seed = as.integer(dgp$seed), trace = FALSE, sd.errors = FALSE,
      control.start = list(starting.val = "zero", n.init = 1)
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(list(
      arm = "gllvm_la", ok = FALSE, secs = secs, err = conditionMessage(f),
      conv = NA_integer_, pd = NA, max_g_fe = NA_real_, max_g_full = NA_real_,
      healthy_fe = FALSE, healthy_proxy = FALSE, healthy_bug = FALSE,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_, shape_mean = NA_real_
    ))
  }
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) {
    sweep(th, 2L, sg, "*")
  } else {
    th
  }
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  Sigma_hat <- if (nrow(L) == dgp$p) L %*% t(L) else NULL
  conv_flag <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  phi <- tryCatch(as.numeric(f$params$phi), error = function(e) NA_real_)
  list(
    arm = "gllvm_la", ok = TRUE, secs = secs, err = NA_character_,
    conv = as.integer(conv_flag), pd = NA,
    max_g_fe = NA_real_, max_g_full = NA_real_,
    healthy_fe = conv_flag, healthy_proxy = conv_flag, healthy_bug = conv_flag,
    beta_rmse = beta_rmse(as.numeric(f$params$beta0), dgp$beta),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    shape_mean = if (length(phi) && all(is.finite(phi))) mean(phi) else NA_real_
  )
}

fit_gtmb_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  ns <- asNamespace("gllvmTMB")
  engine <- get(".approximation_engine_va_r3_fit", envir = ns)
  wrap <- get(".va_route_build_fit", envir = ns)
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  result <- tryCatch(
    engine(
      y = dat$value, n_trials = rep.int(1, n_obs), X = X,
      unit_id = as.integer(dat$unit), trait_id = as.integer(dat$trait),
      q = dgp$q, N = dgp$n, T = dgp$p, H = 7L, eval_method = "gh",
      family_codes = rep.int(4L, n_obs), link_ids = rep.int(0L, n_obs),
      n_ordinal_cuts_per_trait = integer(dgp$p),
      ordinal_offset_per_trait = integer(dgp$p),
      ordinal_log_increments_start = numeric(),
      fixed_tweedie_power = NULL, fixed_student_df = NULL,
      match_laplace_residual_sd = FALSE, silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(result, "error")) {
    return(list(
      arm = "gtmb_va", ok = FALSE, secs = secs, err = conditionMessage(result),
      conv = NA_integer_, pd = NA, max_g_fe = NA_real_, max_g_full = NA_real_,
      healthy_fe = FALSE, healthy_proxy = FALSE, healthy_bug = FALSE,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_, shape_mean = NA_real_
    ))
  }
  fit <- wrap(
    result, call = match.call(), q = dgp$q, p = dgp$p, n = dgp$n,
    eval_method = "gh", family = "gamma_log", link = "log",
    beta_names = colnames(X)
  )
  beta_hat <- as.numeric(
    fit$fitted$parameters[names(fit$fitted$parameters) == "beta"]
  )
  Sigma_hat <- fit$engine_result$report$Sigma_B %||%
    result$report$Sigma_B %||% NULL
  healthy <- identical(fit$status, "healthy")
  list(
    arm = "gtmb_va", ok = is.finite(beta_rmse(beta_hat, dgp$beta)),
    secs = secs, err = if (healthy) NA_character_ else paste0("status=", fit$status),
    conv = NA_integer_, pd = NA, max_g_fe = NA_real_, max_g_full = NA_real_,
    healthy_fe = healthy, healthy_proxy = healthy, healthy_bug = healthy,
    beta_rmse = beta_rmse(beta_hat, dgp$beta),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    shape_mean = NA_real_
  )
}

fit_gllvm_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y, family = "gamma", num.lv = dgp$q, method = "VA",
      seed = as.integer(dgp$seed), trace = FALSE, sd.errors = FALSE,
      control.start = list(starting.val = "zero", n.init = 1)
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(list(
      arm = "gllvm_va", ok = FALSE, secs = secs, err = conditionMessage(f),
      conv = NA_integer_, pd = NA, max_g_fe = NA_real_, max_g_full = NA_real_,
      healthy_fe = FALSE, healthy_proxy = FALSE, healthy_bug = FALSE,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_, shape_mean = NA_real_
    ))
  }
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) sweep(th, 2L, sg, "*") else th
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  Sigma_hat <- if (nrow(L) == dgp$p) L %*% t(L) else NULL
  conv_flag <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  list(
    arm = "gllvm_va", ok = TRUE, secs = secs, err = NA_character_,
    conv = as.integer(conv_flag), pd = NA,
    max_g_fe = NA_real_, max_g_full = NA_real_,
    healthy_fe = conv_flag, healthy_proxy = conv_flag, healthy_bug = conv_flag,
    beta_rmse = beta_rmse(as.numeric(f$params$beta0), dgp$beta),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    shape_mean = NA_real_
  )
}

row_from <- function(res, dgp) {
  data.frame(
    cell = "gamma", seed = dgp$seed, q = dgp$q, n = dgp$n, p = dgp$p,
    arm = res$arm, ok = isTRUE(res$ok),
    healthy_fe = isTRUE(res$healthy_fe),
    healthy_proxy = isTRUE(res$healthy_proxy),
    healthy_bug = isTRUE(res$healthy_bug),
    conv = as.integer(res$conv %||% NA_integer_),
    pd = as.logical(res$pd %||% NA),
    max_g_fe = as.numeric(res$max_g_fe %||% NA_real_),
    max_g_full = as.numeric(res$max_g_full %||% NA_real_),
    beta_rmse = as.numeric(res$beta_rmse %||% NA_real_),
    sigma_rel_frob = as.numeric(res$sigma_rel_frob %||% NA_real_),
    shape_mean = as.numeric(res$shape_mean %||% NA_real_),
    secs = as.numeric(res$secs %||% NA_real_),
    err = as.character(res$err %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

one_job <- function(seed, q) {
  dgp <- simulate_dgp(seed, q)
  rows <- list(
    row_from(fit_gtmb_la(dgp), dgp),
    row_from(fit_gllvm_la(dgp), dgp)
  )
  if (DO_VA) {
    rows[[length(rows) + 1L]] <- row_from(fit_gtmb_va(dgp), dgp)
    rows[[length(rows) + 1L]] <- row_from(fit_gllvm_va(dgp), dgp)
  }
  do.call(rbind, rows)
}

cat(sprintf("== warm-up %s ==\n", format(Sys.time(), "%H:%M:%S")))
wu <- tryCatch(one_job(99901L, 2L), error = function(e) {
  cat("warm-up error:", conditionMessage(e), "\n"); NULL
})
if (!is.null(wu)) {
  print(wu[, c("arm", "healthy_fe", "healthy_proxy", "max_g_fe", "max_g_full",
               "beta_rmse", "sigma_rel_frob", "secs")])
}

jobs <- expand.grid(seed = SEEDS, q = QS, KEEP.OUT.ATTRS = FALSE)
cat(sprintf("== probe start jobs=%d cores=%d ==\n", nrow(jobs), CORES))

run_one <- function(i) {
  tryCatch(
    one_job(jobs$seed[[i]], as.integer(jobs$q[[i]])),
    error = function(e) {
      data.frame(
        cell = "gamma", seed = jobs$seed[[i]], q = jobs$q[[i]], n = N, p = P,
        arm = "ERROR", ok = FALSE, healthy_fe = FALSE, healthy_proxy = FALSE,
        healthy_bug = FALSE, conv = NA_integer_, pd = NA,
        max_g_fe = NA_real_, max_g_full = NA_real_,
        beta_rmse = NA_real_, sigma_rel_frob = NA_real_, shape_mean = NA_real_,
        secs = NA_real_, err = conditionMessage(e), stringsAsFactors = FALSE
      )
    }
  )
}

t0 <- proc.time()[[3L]]
parts <- if (CORES <= 1L) {
  lapply(seq_len(nrow(jobs)), run_one)
} else {
  mclapply(seq_len(nrow(jobs)), run_one, mc.cores = CORES, mc.preschedule = FALSE)
}
raw <- do.call(rbind, parts)
wall <- proc.time()[[3L]] - t0
write.csv(raw, file.path(OUT, "seed-rows-long.csv"), row.names = FALSE)

## Wide LA pair for paired deltas
la_g <- raw[raw$arm == "gtmb_la", ]
la_l <- raw[raw$arm == "gllvm_la", ]
key <- c("seed", "q")
paired <- merge(
  la_g[, c(key, "ok", "healthy_fe", "healthy_proxy", "healthy_bug",
           "max_g_fe", "max_g_full", "beta_rmse", "sigma_rel_frob", "secs")],
  la_l[, c(key, "ok", "healthy_fe", "beta_rmse", "sigma_rel_frob", "secs")],
  by = key, suffixes = c("_gtmb", "_gllvm")
)
paired$d_beta <- paired$beta_rmse_gtmb - paired$beta_rmse_gllvm
paired$d_sigma <- paired$sigma_rel_frob_gtmb - paired$sigma_rel_frob_gllvm
paired$pass_gtmb <- is.finite(paired$beta_rmse_gtmb) & is.finite(paired$sigma_rel_frob_gtmb) &
  paired$beta_rmse_gtmb <= CAP_BETA & paired$sigma_rel_frob_gtmb <= CAP_SIG
paired$pass_gllvm <- is.finite(paired$beta_rmse_gllvm) & is.finite(paired$sigma_rel_frob_gllvm) &
  paired$beta_rmse_gllvm <= CAP_BETA & paired$sigma_rel_frob_gllvm <= CAP_SIG
write.csv(paired, file.path(OUT, "paired-la.csv"), row.names = FALSE)

summarise_q <- function(qq) {
  sub <- paired[paired$q == qq, , drop = FALSE]
  fin <- is.finite(sub$beta_rmse_gtmb) & is.finite(sub$beta_rmse_gllvm) &
    is.finite(sub$sigma_rel_frob_gtmb) & is.finite(sub$sigma_rel_frob_gllvm)
  data.frame(
    cell = "gamma", q = qq, n_seed = nrow(sub), n_paired = sum(fin),
    gtmb_healthy_fe = mean(sub$healthy_fe_gtmb),
    gtmb_healthy_proxy = mean(sub$healthy_proxy),
    gtmb_healthy_bug = mean(sub$healthy_bug),
    gtmb_med_g_fe = median(sub$max_g_fe, na.rm = TRUE),
    gtmb_med_g_full = median(sub$max_g_full, na.rm = TRUE),
    gllvm_healthy = mean(sub$healthy_fe_gllvm),
    gtmb_beta = if (any(fin)) mean(sub$beta_rmse_gtmb[fin]) else NA_real_,
    gllvm_beta = if (any(fin)) mean(sub$beta_rmse_gllvm[fin]) else NA_real_,
    d_beta = if (any(fin)) mean(sub$d_beta[fin]) else NA_real_,
    gtmb_sigma = if (any(fin)) mean(sub$sigma_rel_frob_gtmb[fin]) else NA_real_,
    gllvm_sigma = if (any(fin)) mean(sub$sigma_rel_frob_gllvm[fin]) else NA_real_,
    d_sigma = if (any(fin)) mean(sub$d_sigma[fin]) else NA_real_,
    pass_gtmb = mean(sub$pass_gtmb),
    pass_gllvm = mean(sub$pass_gllvm),
    gtmb_secs = mean(sub$secs_gtmb, na.rm = TRUE),
    gllvm_secs = mean(sub$secs_gllvm, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summ <- do.call(rbind, lapply(QS, summarise_q))
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)

cat("\n======== GAMMA LA H2H (FE health; abs caps β≤0.35 / Σ≤0.50) ========\n")
print(summ, row.names = FALSE, digits = 4)
cat(sprintf("\nwall=%.1fs wrote %s\n", wall, OUT))
cat(sprintf("== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
