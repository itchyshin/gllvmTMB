#!/usr/bin/env Rscript
## Timed Laplace vs AGHQ(+ridge). Warm DLL outside timer. Flush per seed.
## Naming: Laplace / AGHQ / VA-GH — never "LA-GH".
## Default cell: n=1000 p=8 q=2 probit (500×20 AGHQ too slow for smoke).
REPO <- Sys.getenv("PROBE_REPO", "/private/tmp/gllvmtmb-va-gh-all-families")
OUT <- Sys.getenv("PROBE_OUT", "/private/tmp/va-s1-la-vs-aghq-timed-20260807b")
CORES <- max(1L, min(as.integer(Sys.getenv("PILOT_CORES", "4")), 10L))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "8"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "11101")) + seq_len(N_SEED) - 1L
LINK <- Sys.getenv("PROBE_LINK", "probit")
N <- as.integer(Sys.getenv("PROBE_N", "1000"))
P <- as.integer(Sys.getenv("PROBE_P", "8"))
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
AGHQ_K <- as.integer(Sys.getenv("PROBE_AGHQ_K", "9"))
DO_NORIDGE <- identical(Sys.getenv("PROBE_DO_NORIDGE", "0"), "1")
CAP_BETA <- 0.35; CAP_SIG <- 0.50
RUNAWAY_ABS <- 6; RUNAWAY_REL <- 2; COLLAPSE_TR <- 1e-6
say <- function(...) { cat(..., "\n", sep = ""); flush.console(); flush(stdout()) }

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
           MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  pkgload::load_all(".", quiet = TRUE)
  library(parallel)
})
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
link_inv <- function(link) switch(link, logit = plogis, probit = pnorm,
  cloglog = function(z) 1 - exp(-exp(z)), stop(link))

simulate_dgp <- function(seed, n = N, p = P, q = Q) {
  set.seed(seed)
  Lambda <- matrix(rnorm(p * q, 0, 0.25), p, q)
  for (k in seq_len(q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(n * q), n, q)
  beta <- seq(-0.25, 0.25, length.out = p)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  Y <- matrix(rbinom(n * p, 1L, link_inv(LINK)(eta)), n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)), stringsAsFactors = FALSE
  )
  list(seed = seed, n = n, p = p, q = q, link = LINK, data = dat, Y = Y,
       beta = beta, Lambda = Lambda, Sigma = Lambda %*% t(Lambda))
}
rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  sqrt(sum((Shat - Strue)^2)) / sqrt(sum(Strue^2))
}
beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}
empty_row <- function(dgp, arm, secs, err = NA_character_) {
  data.frame(seed = dgp$seed, n = dgp$n, p = dgp$p, q = dgp$q, link = dgp$link,
    arm = arm, ok = FALSE, beta_rmse = NA_real_, sigma_rf = NA_real_,
    pass_abs = FALSE, secs = secs, aghq_used = NA, ridge_tau = NA_real_,
    aghq_k = NA_integer_, max_abs_lambda = NA_real_, atten_F = NA_real_,
    tr_sigma = NA_real_, runaway = FALSE, collapse = FALSE,
    err = err, stringsAsFactors = FALSE)
}
score_fit <- function(fit, dgp, arm, secs) {
  if (inherits(fit, "error")) return(empty_row(dgp, arm, secs, conditionMessage(fit)))
  bhat <- tryCatch(as.numeric(coef(fit)), error = function(e) NA_real_)
  if (length(bhat) != dgp$p) {
    bhat <- tryCatch({
      par <- fit$opt$par %||% fit$tmb_obj$par
      nm <- names(par)
      as.numeric(par[startsWith(nm, "b_fix") | nm == "b_fixed"])[seq_len(dgp$p)]
    }, error = function(e) NA_real_)
  }
  Lam <- tryCatch({
    fit$report$Lambda_B %||% fit$report$lambda_B
  }, error = function(e) NULL)
  Shat <- tryCatch({
    S <- fit$report$Sigma_B
    if (is.null(S) && !is.null(Lam)) Lam %*% t(Lam) else S
  }, error = function(e) NULL)
  br <- beta_rmse(bhat, dgp$beta); sr <- rel_frob(Shat, dgp$Sigma)
  ok <- is.finite(br) && is.finite(sr)
  max_abs_l <- if (!is.null(Lam)) max(abs(Lam)) else NA_real_
  atten <- if (!is.null(Lam)) {
    sqrt(sum(Lam^2)) / sqrt(sum(dgp$Lambda^2))
  } else NA_real_
  tr_s <- if (!is.null(Shat)) sum(diag(Shat)) else NA_real_
  runaway <- isTRUE(is.finite(max_abs_l) && max_abs_l >= RUNAWAY_ABS) ||
    isTRUE(is.finite(atten) && atten >= RUNAWAY_REL)
  collapse <- isTRUE(is.finite(tr_s) && tr_s < COLLAPSE_TR)
  aghq_used <- isTRUE(fit$aghq$used) || isTRUE(fit$aghq$aghq_used)
  ridge_tau <- tryCatch({
    as.numeric(fit$aghq$ridge_tau %||% fit$aghq$tau %||%
                 fit$aghq$ridge %||% NA_real_)
  }, error = function(e) NA_real_)
  aghq_k <- tryCatch(as.integer(fit$aghq$k %||% fit$aghq$aghq %||% NA_integer_),
                     error = function(e) NA_integer_)
  data.frame(seed = dgp$seed, n = dgp$n, p = dgp$p, q = dgp$q, link = dgp$link,
    arm = arm, ok = ok, beta_rmse = br, sigma_rf = sr,
    pass_abs = ok && br <= CAP_BETA && sr <= CAP_SIG,
    secs = secs, aghq_used = aghq_used, ridge_tau = ridge_tau,
    aghq_k = aghq_k, max_abs_lambda = max_abs_l, atten_F = atten,
    tr_sigma = tr_s, runaway = runaway, collapse = collapse,
    err = NA_character_, stringsAsFactors = FALSE)
}
form_of <- function(q) as.formula(sprintf(
  "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)", q))

fit_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  fit <- tryCatch(
    gllvmTMB(form_of(dgp$q), data = dgp$data, unit = "unit",
             family = binomial(link = dgp$link),
             control = gllvmTMBcontrol(integration = "laplace", se = FALSE,
                                       warn_runaway = FALSE),
             silent = TRUE), error = function(e) e)
  score_fit(fit, dgp, "gtmb_la", proc.time()[[3L]] - t0)
}
fit_aghq <- function(dgp, ridge = TRUE) {
  arm <- if (ridge) "gtmb_aghq_ridge" else "gtmb_aghq_noridge"
  ## Shipped AGHQ path: aghq=k turns ridge default τ=2 ON; Inf disables.
  ctrl <- if (ridge) {
    gllvmTMBcontrol(aghq = AGHQ_K, se = FALSE, warn_runaway = FALSE)
  } else {
    gllvmTMBcontrol(aghq = AGHQ_K, aghq_ridge = Inf, se = FALSE,
                    warn_runaway = FALSE)
  }
  t0 <- proc.time()[[3L]]
  fit <- tryCatch(
    gllvmTMB(form_of(dgp$q), data = dgp$data, unit = "unit",
             family = binomial(link = dgp$link), control = ctrl, silent = TRUE),
    error = function(e) e)
  score_fit(fit, dgp, arm, proc.time()[[3L]] - t0)
}
one_seed <- function(seed) {
  dgp <- simulate_dgp(seed)
  say(sprintf("  seed=%d LA...", seed))
  rows <- list(fit_la(dgp))
  say(sprintf("  seed=%d AGHQ+ridge k=%d...", seed, AGHQ_K))
  rows <- c(rows, list(fit_aghq(dgp, TRUE)))
  if (DO_NORIDGE) {
    say(sprintf("  seed=%d AGHQ no-ridge...", seed))
    rows <- c(rows, list(fit_aghq(dgp, FALSE)))
  }
  do.call(rbind, rows)
}
append_rows <- function(rows, path) {
  hdr <- !file.exists(path)
  write.table(rows, path, sep = ",", row.names = FALSE, col.names = hdr,
              append = !hdr, quote = TRUE)
}

say(sprintf("== Laplace vs AGHQ timed n=%d p=%d q=%d link=%s seeds=%d cores=%d k=%d ==",
            N, P, Q, LINK, N_SEED, CORES, AGHQ_K))
say("comparator: shipped Laplace (unpenalised) vs aghq=k with default ridge τ=2")
say("starts: each path's shipped defaults (LA n_init=1; AGHQ aghq_multistart=TRUE)")
say("se=FALSE; warm excluded from secs")

say("== WARM-UP tiny n=60 (untimed) ==")
t_warm0 <- proc.time()[[3L]]
oldN <- N; N <<- 60L
invisible(tryCatch({
  d <- simulate_dgp(99001L)
  print(fit_la(d)[, c("arm", "secs", "ok")])
  print(fit_aghq(d, TRUE)[, c("arm", "secs", "ok", "aghq_used", "ridge_tau")])
}, error = function(e) say("warm fail: ", conditionMessage(e))))
N <<- oldN
say(sprintf("warm wall=%.1fs (excluded)", proc.time()[[3L]] - t_warm0))

rows_path <- file.path(OUT, "seed-rows.csv")
if (file.exists(rows_path)) file.remove(rows_path)

say(sprintf("== TIMED seeds=%s cores=%d ==", paste(SEEDS, collapse = ","), CORES))
t_all0 <- proc.time()[[3L]]
if (CORES <= 1L) {
  parts <- lapply(SEEDS, function(s) {
    r <- tryCatch(one_seed(s), error = function(e) {
      say("seed fail: ", conditionMessage(e))
      empty_row(list(seed = s, n = N, p = P, q = Q, link = LINK), "FAIL", NA_real_,
                conditionMessage(e))
    })
    append_rows(r, rows_path)
    say(sprintf("  flushed seed=%d", s))
    r
  })
} else {
  cl <- parallel::makeCluster(CORES, type = "PSOCK")
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterExport(cl, c("REPO", "N", "P", "Q", "LINK", "AGHQ_K", "DO_NORIDGE",
    "CAP_BETA", "CAP_SIG", "RUNAWAY_ABS", "RUNAWAY_REL", "COLLAPSE_TR",
    "simulate_dgp", "rel_frob", "beta_rmse", "empty_row", "score_fit",
    "form_of", "fit_la", "fit_aghq", "one_seed", "%||%", "link_inv", "say"),
    envir = environment())
  invisible(parallel::clusterEvalQ(cl, {
    Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
               MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1")
    setwd(REPO)
    suppressPackageStartupMessages(pkgload::load_all(".", quiet = TRUE))
    NULL
  }))
  ## Parallel seeds; master merges + flushes as workers return.
  parts <- vector("list", length(SEEDS))
  done <- integer(0)
  ## Use parLapply for simplicity (workers finish independently).
  parts <- parallel::parLapply(cl, SEEDS, function(s) {
    tryCatch(one_seed(s), error = function(e) {
      empty_row(list(seed = s, n = N, p = P, q = Q, link = LINK), "FAIL", NA_real_,
                conditionMessage(e))
    })
  })
  for (r in parts) append_rows(r, rows_path)
  parallel::stopCluster(cl)
  on.exit(NULL)
}
out <- do.call(rbind, parts)
write.csv(out, rows_path, row.names = FALSE)
mn <- function(z) mean(as.numeric(z), na.rm = TRUE)
sm <- aggregate(cbind(ok, beta_rmse, sigma_rf, pass_abs, secs,
                      runaway, collapse) ~ arm, out, mn)
la_secs <- sm$secs[sm$arm == "gtmb_la"]
sm$ratio_vs_la <- if (length(la_secs) && is.finite(la_secs) && la_secs > 0) {
  sm$secs / la_secs
} else NA_real_
## annotate ridge/k from rows
ann <- aggregate(cbind(aghq_used = as.numeric(aghq_used),
                       ridge_tau = ridge_tau) ~ arm, out, mn)
sm <- merge(sm, ann, by = "arm", all.x = TRUE)
write.csv(sm, file.path(OUT, "summary.csv"), row.names = FALSE)
say("======== SUMMARY (means; warm excluded) ========")
print(sm, row.names = FALSE, digits = 4)
say(sprintf("geometry: n=%d p=%d q=%d link=%s aghq_k=%d ridge=default(τ=2 when AGHQ on)",
            N, P, Q, LINK, AGHQ_K))
say(sprintf("wall_all=%.1fs wrote %s", proc.time()[[3L]] - t_all0, OUT))
say("== done ", format(Sys.time(), "%H:%M:%S"), " ==")
