#!/usr/bin/env Rscript
## 500×20 cloglog vs probit GH H2H — abs Σ usable?
## Design-110-shaped DGP; unique=FALSE; H=7; trials=1; q=2.
## Primary arms: gtmb cloglog GH + gtmb probit GH (same seeds).
## Optional: LA / gllvm VA / poisg (cloglog only; skipped if DLL lacks it).
## Totoro-safe: env REPO/OUT; one warm .va_r3_load_dll. D-50: raw under PROBE_OUT.

REPO <- Sys.getenv("PROBE_REPO", unset = Sys.getenv("REPO", unset = getwd()))
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = file.path(tempdir(), "va-s1-500x20-cloglog-probit-h2h")
)
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
RUNAWAY_MULT <- as.numeric(Sys.getenv("PROBE_RUNAWAY_MULT", "2"))
DO_LA <- identical(Sys.getenv("PROBE_DO_LA", "1"), "1")
DO_GLLVM <- identical(Sys.getenv("PROBE_DO_GLLVM", "0"), "1")
DO_POISG <- identical(Sys.getenv("PROBE_DO_POISG", "0"), "1")
## Comma list; default both primary links for fair H2H.
LINKS <- strsplit(Sys.getenv("PROBE_LINKS", "probit,cloglog"), ",", fixed = TRUE)[[1L]]
LINKS <- trimws(LINKS)
LINKS <- LINKS[nzchar(LINKS)]
stopifnot(all(LINKS %in% c("probit", "cloglog", "logit")))

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1"
)
setwd(REPO)
suppressPackageStartupMessages({
  pkgload::load_all(".", quiet = TRUE)
  library(parallel)
})
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
link_inv <- function(link) {
  switch(
    link,
    logit = plogis,
    probit = pnorm,
    cloglog = function(eta) pmax(0, pmin(1, 1 - exp(-exp(eta)))),
    stop("bad link: ", link)
  )
}
fam_r3 <- function(link) {
  switch(
    link,
    logit = "binomial",
    probit = "binomial_probit",
    cloglog = "binomial_cloglog",
    stop("bad link")
  )
}
sigma_collapsed <- function(Shat, Strue, tol = 1e-8) {
  if (!is.matrix(Shat)) return(NA)
  fs <- frob(Shat)
  ft <- frob(Strue)
  is.finite(fs) && is.finite(ft) && ft > 0 && fs / ft < tol
}
sigma_runaway <- function(Shat, Strue, mult = RUNAWAY_MULT) {
  if (!is.matrix(Shat)) return(NA)
  fs <- frob(Shat)
  ft <- frob(Strue)
  is.finite(fs) && is.finite(ft) && ft > 0 && fs > mult * ft
}

simulate_dgp <- function(seed, link) {
  set.seed(seed)
  Lambda <- matrix(rnorm(P * Q, 0, 0.25), P, Q)
  for (k in seq_len(Q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(N * Q), N, Q)
  beta <- seq(-0.25, 0.25, length.out = P)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  Y <- matrix(rbinom(N * P, 1L, link_inv(link)(eta)), N, P)
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
    beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    frob_Shat = NA_real_, frob_Strue = NA_real_,
    sigma_collapse = FALSE, sigma_runaway = FALSE,
    secs = secs, pass_abs = FALSE, err = err, stringsAsFactors = FALSE
  )
}

score_row <- function(seed, link, arm, ok, healthy, bhat, Shat, Strue, beta, secs, err = NA_character_) {
  br <- if (length(bhat) == length(beta) && all(is.finite(bhat))) {
    sqrt(mean((bhat - beta)^2))
  } else NA_real_
  sr <- rel_frob(Shat, Strue)
  fs <- if (is.matrix(Shat)) frob(Shat) else NA_real_
  ft <- frob(Strue)
  col <- isTRUE(sigma_collapsed(Shat, Strue))
  run <- isTRUE(sigma_runaway(Shat, Strue))
  data.frame(
    seed = seed, link = link, arm = arm, ok = ok, healthy = healthy,
    beta_rmse = br, sigma_rel_frob = sr,
    frob_Shat = fs, frob_Strue = ft,
    sigma_collapse = col, sigma_runaway = run,
    secs = secs,
    pass_abs = isTRUE(ok) && is.finite(br) && is.finite(sr) &&
      br <= CAP_BETA && sr <= CAP_SIG,
    err = err, stringsAsFactors = FALSE
  )
}

fit_va <- function(dgp, eval_method) {
  arm <- paste0("gtmb_va_", eval_method)
  t0 <- proc.time()[[3L]]
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  raw <- tryCatch(
    gllvmTMB:::.va_r3_fit(
      y = dat$value, n_trials = rep.int(1, nrow(dat)), X = X,
      unit_id = as.integer(dat$unit), trait_id = as.integer(dat$trait),
      q = dgp$q, N = dgp$n, T = dgp$p, family = fam_r3(dgp$link),
      link = dgp$link, unique = FALSE, H = VA_H,
      eval_method = eval_method, silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(raw, "error")) {
    return(empty_row(dgp$seed, dgp$link, arm, secs, conditionMessage(raw)))
  }
  healthy <- identical(raw$status, "healthy")
  score_row(
    dgp$seed, dgp$link, arm, healthy, healthy,
    beta_from_r3(raw, dgp$p), sigma_from_r3(raw, dgp$p, dgp$q),
    dgp$Sigma, dgp$beta, secs,
    err = if (healthy) NA_character_ else paste0("status=", raw$status %||% "NULL")
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
  ok <- length(bhat) == dgp$p && all(is.finite(bhat)) && is.matrix(Shat)
  score_row(dgp$seed, dgp$link, "gtmb_la", ok, ok, bhat, Shat, dgp$Sigma, dgp$beta, secs)
}

fit_gllvm_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  fam <- binomial(link = dgp$link)
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
  looks <- isTRUE(f$convergence) || identical(as.character(f$convergence), "TRUE")
  score_row(
    dgp$seed, dgp$link, "gllvm_va", looks, looks,
    as.numeric(f$params$beta0), L %*% t(L), dgp$Sigma, dgp$beta, secs
  )
}

one_seed <- function(seed) {
  rows <- list()
  for (link in LINKS) {
    dgp <- simulate_dgp(seed, link)
    rows[[length(rows) + 1L]] <- fit_va(dgp, "gh")
    if (identical(link, "probit")) {
      ## AC is probit-only; cheap comparator, default off via DO_AC env if needed
      if (identical(Sys.getenv("PROBE_DO_AC", "0"), "1")) {
        rows[[length(rows) + 1L]] <- fit_va(dgp, "ac")
      }
    }
    if (identical(link, "cloglog") && isTRUE(DO_POISG)) {
      rows[[length(rows) + 1L]] <- fit_va(dgp, "poisg")
    }
    if (DO_LA) rows[[length(rows) + 1L]] <- fit_la(dgp)
    if (DO_GLLVM) rows[[length(rows) + 1L]] <- fit_gllvm_va(dgp)
  }
  do.call(rbind, rows)
}

cat(sprintf(
  "H2H links=%s n=%d p=%d q=%d seeds=%d..%d cores=%d H=%d LA=%s gllvm=%s poisg=%s OUT=%s\n",
  paste(LINKS, collapse = "+"), N, P, Q, SEEDS[[1]], SEEDS[[length(SEEDS)]],
  CORES, VA_H, DO_LA, DO_GLLVM, DO_POISG, OUT
))
flush.console()

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

summ <- do.call(rbind, lapply(split(long, paste(long$link, long$arm, sep = "|")), function(sub) {
  fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
  data.frame(
    link = sub$link[[1]],
    arm = sub$arm[[1]],
    n = N, p = P, q = Q,
    n_seed = nrow(sub),
    n_ok = sum(sub$ok),
    beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
    beta_med = if (any(fin)) median(sub$beta_rmse[fin]) else NA_real_,
    sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
    sigma_med = if (any(fin)) median(sub$sigma_rel_frob[fin]) else NA_real_,
    pass_abs = if (any(fin)) mean(sub$pass_abs[fin]) else NA_real_,
    frac_collapse = mean(sub$sigma_collapse, na.rm = TRUE),
    frac_runaway = mean(sub$sigma_runaway, na.rm = TRUE),
    secs_mean = mean(sub$secs, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
summ <- summ[order(summ$link, summ$arm), , drop = FALSE]
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)
print(summ, row.names = FALSE, digits = 4)

## Paired cloglog GH − probit GH on shared seeds (if both present)
gh <- long[long$arm == "gtmb_va_gh", , drop = FALSE]
if (all(c("probit", "cloglog") %in% unique(gh$link))) {
  pr <- gh[gh$link == "probit", c("seed", "beta_rmse", "sigma_rel_frob", "pass_abs")]
  cl <- gh[gh$link == "cloglog", c("seed", "beta_rmse", "sigma_rel_frob", "pass_abs")]
  names(pr)[-1] <- paste0("probit_", names(pr)[-1])
  names(cl)[-1] <- paste0("cloglog_", names(cl)[-1])
  paired <- merge(pr, cl, by = "seed")
  write.csv(paired, file.path(OUT, "paired-gh.csv"), row.names = FALSE)
  cat("\n=== Paired GH (cloglog − probit) mean Δ ===\n")
  cat(sprintf(
    "dβ=%.4f  dΣ=%.4f  pass_clog=%.2f  pass_prob=%.2f  n=%d\n",
    mean(paired$cloglog_beta_rmse - paired$probit_beta_rmse, na.rm = TRUE),
    mean(paired$cloglog_sigma_rel_frob - paired$probit_sigma_rel_frob, na.rm = TRUE),
    mean(paired$cloglog_pass_abs, na.rm = TRUE),
    mean(paired$probit_pass_abs, na.rm = TRUE),
    nrow(paired)
  ))
}

cat("\nWrote ", file.path(OUT, "summary.csv"), "\n", sep = "")
