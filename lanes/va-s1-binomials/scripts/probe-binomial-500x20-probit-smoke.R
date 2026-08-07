#!/usr/bin/env Rscript
## Probit n=500 p=20 q=2 smoke — abs Σ usable?
## Arms: gtmb GH, gtmb AC, gtmb LA (opt), gllvm VA (opt). H=7 unique=FALSE.
## Design-110-shaped DGP. Totoro-safe: env REPO/OUT; one warm .va_r3_load_dll.
## D-50: raw CSV stays under PROBE_OUT (not git).

REPO <- Sys.getenv("PROBE_REPO", unset = Sys.getenv("REPO", unset = getwd()))
OUT <- Sys.getenv("PROBE_OUT", unset = file.path(tempdir(), "va-s1-500x20-probit"))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

CORES <- min(
  as.integer(Sys.getenv("PROBE_CORE_CAP", unset = Sys.getenv("PILOT_CORES", unset = "12"))),
  as.integer(Sys.getenv("PILOT_CORES", unset = "12"))
)
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "12"))
SEED0 <- as.integer(Sys.getenv("PROBE_SEED0", "11001"))
SEEDS <- SEED0 + seq_len(N_SEED) - 1L
N <- as.integer(Sys.getenv("PROBE_N", "500"))
P <- as.integer(Sys.getenv("PROBE_P", "20"))
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
CAP_BETA <- as.numeric(Sys.getenv("PROBE_CAP_BETA", "0.35"))
CAP_SIG <- as.numeric(Sys.getenv("PROBE_CAP_SIG", "0.50"))
DO_LA <- identical(Sys.getenv("PROBE_DO_LA", "1"), "1")
DO_GLLVM <- identical(Sys.getenv("PROBE_DO_GLLVM", "1"), "1")
LINK <- Sys.getenv("PROBE_LINK", "probit")

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1"
)
setwd(REPO)
suppressPackageStartupMessages({
  pkgload::load_all(".", quiet = TRUE)
  library(parallel)
})
## One warm compile on master before fork workers (avoid per-worker recompile).
invisible(gllvmTMB:::.va_r3_load_dll())
if (isTRUE(DO_GLLVM)) {
  stopifnot(requireNamespace("gllvm", quietly = TRUE))
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
frob <- function(A) sqrt(sum(A^2))
rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  den <- frob(Strue)
  if (!is.finite(den) || den <= 0) return(NA_real_)
  frob(Shat - Strue) / den
}

simulate_dgp <- function(seed, link = LINK) {
  set.seed(seed)
  Lambda <- matrix(rnorm(P * Q, 0, 0.25), P, Q)
  for (k in seq_len(Q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(N * Q), N, Q)
  beta <- seq(-0.25, 0.25, length.out = P)
  link_fun <- if (identical(link, "logit")) plogis else pnorm
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  Y <- matrix(rbinom(N * P, 1L, link_fun(eta)), N, P)
  dat <- data.frame(
    unit = factor(rep(seq_len(N), each = P)),
    trait = factor(rep(sprintf("t%02d", seq_len(P)), times = N)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    seed = seed, n = N, p = P, q = Q, link = link, data = dat, Y = Y,
    beta = beta, Lambda = Lambda, Sigma = Lambda %*% t(Lambda)
  )
}

beta_from_r3 <- function(raw, p) {
  b <- tryCatch({
    par <- raw$best$par %||% raw$par
    as.numeric(par[names(par) == "beta"])
  }, error = function(e) NA_real_)
  if (length(b) == p && all(is.finite(b))) return(b)
  tryCatch(as.numeric(raw$report$beta)[seq_len(p)], error = function(e) NA_real_)
}

sigma_from_r3 <- function(raw, p, q) {
  S <- tryCatch(raw$report$Sigma_B, error = function(e) NULL)
  if (is.matrix(S) && identical(dim(S), c(p, p))) return(S)
  th <- tryCatch(raw$best$par %||% raw$par, error = function(e) NULL)
  if (is.null(th)) return(NULL)
  Lam <- tryCatch(gllvmTMB:::.va_r3_unpack_theta_rr(th, p, q), error = function(e) NULL)
  if (is.null(Lam)) return(NULL)
  Lam %*% t(Lam)
}

empty_row <- function(seed, link, arm, secs, err) {
  data.frame(
    seed = seed, link = link, arm = arm, ok = FALSE, healthy = FALSE,
    beta_rmse = NA_real_, sigma_rel_frob = NA_real_, secs = secs,
    pass_abs = FALSE, err = err, stringsAsFactors = FALSE
  )
}

fit_va <- function(dgp, eval_method) {
  arm <- paste0("gtmb_va_", eval_method)
  fam_r3 <- if (identical(dgp$link, "logit")) "binomial" else "binomial_probit"
  t0 <- proc.time()[[3L]]
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  raw <- tryCatch(
    gllvmTMB:::.va_r3_fit(
      y = dat$value, n_trials = rep.int(1, nrow(dat)), X = X,
      unit_id = as.integer(dat$unit), trait_id = as.integer(dat$trait),
      q = dgp$q, N = dgp$n, T = dgp$p, family = fam_r3, link = dgp$link,
      unique = FALSE, H = VA_H, eval_method = eval_method, silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(raw, "error")) {
    return(empty_row(dgp$seed, dgp$link, arm, secs, conditionMessage(raw)))
  }
  bhat <- beta_from_r3(raw, dgp$p)
  Shat <- sigma_from_r3(raw, dgp$p, dgp$q)
  br <- if (length(bhat) == dgp$p && all(is.finite(bhat))) {
    sqrt(mean((bhat - dgp$beta)^2))
  } else NA_real_
  sr <- rel_frob(Shat, dgp$Sigma)
  healthy <- identical(raw$status, "healthy")
  data.frame(
    seed = dgp$seed, link = dgp$link, arm = arm, ok = healthy, healthy = healthy,
    beta_rmse = br, sigma_rel_frob = sr, secs = secs,
    pass_abs = isTRUE(healthy) && is.finite(br) && is.finite(sr) &&
      br <= CAP_BETA && sr <= CAP_SIG,
    err = if (healthy) NA_character_ else paste0("status=", raw$status %||% "NULL"),
    stringsAsFactors = FALSE
  )
}

fit_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)", Q
  ))
  fit <- tryCatch(
    gllvmTMB(
      form, data = dgp$data, unit = "unit", family = binomial(link = dgp$link),
      control = gllvmTMBcontrol(integration = "laplace", se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(empty_row(dgp$seed, dgp$link, "gtmb_la", secs, conditionMessage(fit)))
  }
  bhat <- tryCatch(as.numeric(coef(fit)), error = function(e) NA_real_)
  if (length(bhat) != dgp$p) {
    bhat <- tryCatch({
      par <- fit$opt$par %||% fit$tmb_obj$par
      nm <- names(par)
      as.numeric(par[startsWith(nm, "b_fix") | nm == "b_fixed"])[seq_len(dgp$p)]
    }, error = function(e) NA_real_)
  }
  Shat <- tryCatch({
    S <- fit$report$Sigma_B
    if (is.null(S)) {
      Lam <- fit$report$Lambda_B %||% fit$report$lambda_B
      if (!is.null(Lam)) Lam %*% t(Lam) else NULL
    } else S
  }, error = function(e) NULL)
  br <- if (length(bhat) == dgp$p && all(is.finite(bhat))) {
    sqrt(mean((bhat - dgp$beta)^2))
  } else NA_real_
  sr <- rel_frob(Shat, dgp$Sigma)
  ok <- is.finite(br) && is.finite(sr)
  data.frame(
    seed = dgp$seed, link = dgp$link, arm = "gtmb_la", ok = ok, healthy = ok,
    beta_rmse = br, sigma_rel_frob = sr, secs = secs,
    pass_abs = ok && br <= CAP_BETA && sr <= CAP_SIG,
    err = NA_character_, stringsAsFactors = FALSE
  )
}

fit_gllvm_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  fam <- if (identical(dgp$link, "probit")) binomial(link = "probit") else binomial(link = "logit")
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y, family = fam, num.lv = dgp$q, method = "VA",
      starting.val = "res", seed = as.integer(dgp$seed),
      trace = FALSE, sd.errors = FALSE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(empty_row(dgp$seed, dgp$link, "gllvm_va", secs, conditionMessage(f)))
  }
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) >= dgp$q) {
    sweep(th[, seq_len(dgp$q), drop = FALSE], 2L, sg[seq_len(dgp$q)], "*")
  } else {
    th[, seq_len(min(dgp$q, ncol(th))), drop = FALSE]
  }
  br <- sqrt(mean((as.numeric(f$params$beta0) - dgp$beta)^2))
  sr <- rel_frob(L %*% t(L), dgp$Sigma)
  looks <- isTRUE(f$convergence) || identical(as.character(f$convergence), "TRUE")
  data.frame(
    seed = dgp$seed, link = dgp$link, arm = "gllvm_va", ok = looks, healthy = looks,
    beta_rmse = br, sigma_rel_frob = sr, secs = secs,
    pass_abs = isTRUE(looks) && is.finite(br) && is.finite(sr) &&
      br <= CAP_BETA && sr <= CAP_SIG,
    err = NA_character_, stringsAsFactors = FALSE
  )
}

one_seed <- function(seed) {
  rows <- list()
  dgp <- simulate_dgp(seed, LINK)
  rows[[length(rows) + 1L]] <- fit_va(dgp, "gh")
  rows[[length(rows) + 1L]] <- fit_va(dgp, "ac")
  if (DO_LA) rows[[length(rows) + 1L]] <- fit_la(dgp)
  if (DO_GLLVM) rows[[length(rows) + 1L]] <- fit_gllvm_va(dgp)
  do.call(rbind, rows)
}

cat(sprintf(
  "SMOKE %s n=%d p=%d q=%d seeds=%d..%d cores=%d H=%d LA=%s gllvmVA=%s OUT=%s\n",
  LINK, N, P, Q, SEEDS[[1]], SEEDS[[length(SEEDS)]], CORES, VA_H, DO_LA, DO_GLLVM, OUT
))
flush.console()

## Warm one seed on master (DLL already loaded); then parallel fork inherits.
invisible(one_seed(SEEDS[[1L]]))
cat("warm-up done (seed reused in grid)\n")
flush.console()

rows <- mclapply(SEEDS, one_seed, mc.cores = CORES, mc.preschedule = FALSE)
ok_l <- vapply(rows, function(x) is.data.frame(x), logical(1))
if (!all(ok_l)) {
  bad <- SEEDS[!ok_l]
  msgs <- vapply(rows[!ok_l], function(x) {
    if (inherits(x, "try-error")) as.character(x) else paste(class(x), collapse = ",")
  }, character(1))
  stop("seed failures: ", paste(sprintf("%s:%s", bad, msgs), collapse = " | "))
}
long <- do.call(rbind, rows)
write.csv(long, file.path(OUT, "seed-rows.csv"), row.names = FALSE)

summ <- do.call(rbind, lapply(split(long, long$arm), function(sub) {
  fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
  data.frame(
    arm = sub$arm[[1]],
    link = sub$link[[1]],
    n = N, p = P, q = Q,
    n_seed = nrow(sub),
    n_ok = sum(sub$ok),
    beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
    sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
    sigma_med = if (any(fin)) median(sub$sigma_rel_frob[fin]) else NA_real_,
    pass_abs = if (any(fin)) mean(sub$pass_abs[fin]) else NA_real_,
    frac_sigma_le_cap = if (any(fin)) mean(sub$sigma_rel_frob[fin] <= CAP_SIG) else NA_real_,
    secs_mean = mean(sub$secs, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)
print(summ)
cat("\nWrote ", file.path(OUT, "summary.csv"), "\n", sep = "")
