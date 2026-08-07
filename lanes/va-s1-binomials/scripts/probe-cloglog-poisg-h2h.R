#!/usr/bin/env Rscript
## Cheap H2H: Design-110-ish cloglog — GH vs PoisG vs gllvm VA.
## Expectation: β may be usable; Σ often still poor. Report honestly.
## Local ≤10 cores. No public fence change.

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-s1-binomial-poisg-h2h-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "12"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "11001")) + seq_len(N_SEED) - 1L
Q <- 2L
N <- 120L
P <- 8L
VA_H <- 7L

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
invisible(gllvmTMB:::.va_r3_load_dll(rebuild = TRUE))
cat("gllvm:", as.character(packageVersion("gllvm")), "\n")
cat("repo:", REPO, " out:", OUT, " cores:", CORES,
    " seeds:", N_SEED, "\n")

rel_frob <- function(A, B) {
  if (!is.matrix(A) || !is.matrix(B) || !identical(dim(A), dim(B))) {
    return(NA_real_)
  }
  den <- sqrt(sum(B^2))
  if (!is.finite(den) || den < 1e-12) return(NA_real_)
  sqrt(sum((A - B)^2)) / den
}

beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}

simulate_dgp <- function(seed, q = Q, n = N, p = P) {
  set.seed(seed)
  Lambda <- matrix(rnorm(p * q, 0, 0.25), p, q)
  for (k in seq_len(q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(n * q), n, q)
  beta <- seq(-0.25, 0.25, length.out = p)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  prob <- pmin(pmax(1 - exp(-exp(eta)), 1e-8), 1 - 1e-8)
  Y <- matrix(rbinom(n * p, 1L, prob), n, p)
  dat <- data.frame(
    y = as.vector(Y),
    unit = rep(seq_len(n), times = p),
    trait = rep(seq_len(p), each = n)
  )
  list(
    seed = seed, n = n, p = p, q = q, data = dat, Y = Y,
    beta = beta, Lambda = Lambda, Sigma = Lambda %*% t(Lambda)
  )
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

fit_gtmb <- function(dgp, eval_method) {
  arm <- paste0("gtmb_", eval_method)
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvmTMB:::.va_r3_fit(
      y = dgp$data$y,
      n_trials = rep(1, nrow(dgp$data)),
      X = unname(model.matrix(
        ~ 0 + factor(dgp$data$trait, levels = seq_len(dgp$p))
      )),
      unit_id = dgp$data$unit,
      trait_id = dgp$data$trait,
      q = dgp$q,
      family = "binomial_cloglog",
      H = VA_H,
      eval_method = eval_method,
      n_starts = 4L,
      silent = TRUE
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    return(data.frame(
      seed = dgp$seed, arm = arm, ok = FALSE, elapsed = elapsed,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      sigma_trace = NA_real_, elbo = NA_real_,
      status = conditionMessage(fit),
      stringsAsFactors = FALSE
    ))
  }
  par <- fit$best$par
  bhat <- unname(par[names(par) == "beta"])
  Sigma_hat <- fit$report$Sigma_B
  if (is.null(Sigma_hat) && !is.null(fit$report$Lambda)) {
    L <- as.matrix(fit$report$Lambda)
    Sigma_hat <- L %*% t(L)
  }
  data.frame(
    seed = dgp$seed, arm = arm,
    ok = is.finite(fit$report$elbo),
    elapsed = elapsed,
    beta_rmse = beta_rmse(bhat, dgp$beta),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    sigma_trace = if (is.null(Sigma_hat)) NA_real_ else sum(diag(Sigma_hat)),
    elbo = as.numeric(fit$report$elbo %||% NA_real_),
    status = fit$status %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

fit_gllvm_va <- function(dgp) {
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y, family = binomial(link = "cloglog"),
      num.lv = dgp$q, method = "VA", seed = dgp$seed
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    return(data.frame(
      seed = dgp$seed, arm = "gllvm_va", ok = FALSE, elapsed = elapsed,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      sigma_trace = NA_real_, elbo = NA_real_,
      status = conditionMessage(fit),
      stringsAsFactors = FALSE
    ))
  }
  bhat <- as.numeric(fit$params$beta0)
  theta <- as.matrix(fit$params$theta)
  ## Drop any non-LV columns if present; keep last q.
  if (ncol(theta) > dgp$q) {
    theta <- theta[, seq.int(ncol(theta) - dgp$q + 1L, ncol(theta)),
                   drop = FALSE]
  }
  Sigma_hat <- theta %*% t(theta)
  data.frame(
    seed = dgp$seed, arm = "gllvm_va", ok = TRUE, elapsed = elapsed,
    beta_rmse = beta_rmse(bhat, dgp$beta),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    sigma_trace = sum(diag(Sigma_hat)),
    elbo = as.numeric(fit$logL %||% NA_real_),
    status = "ok",
    stringsAsFactors = FALSE
  )
}

run_seed <- function(seed) {
  dgp <- simulate_dgp(seed)
  rbind(
    fit_gtmb(dgp, "gh"),
    fit_gtmb(dgp, "poisg"),
    fit_gllvm_va(dgp)
  )
}

cat("Running", N_SEED, "seeds x 3 arms...\n")
rows <- if (CORES > 1L) {
  parallel::mclapply(SEEDS, run_seed, mc.cores = CORES)
} else {
  lapply(SEEDS, run_seed)
}
tab <- do.call(rbind, rows)
write.csv(tab, file.path(OUT, "h2h-raw.csv"), row.names = FALSE)

ok <- tab[isTRUE(tab$ok) | tab$ok %in% TRUE, , drop = FALSE]
if (!nrow(ok)) ok <- tab
arms <- unique(tab$arm)
flat <- do.call(rbind, lapply(arms, function(a) {
  sub <- tab[tab$arm == a, , drop = FALSE]
  fin_b <- is.finite(sub$beta_rmse)
  fin_s <- is.finite(sub$sigma_rel_frob)
  data.frame(
    arm = a,
    n_attempt = nrow(sub),
    n_ok = sum(sub$ok),
    beta_rmse_median = median(sub$beta_rmse[fin_b], na.rm = TRUE),
    beta_rmse_mean = mean(sub$beta_rmse[fin_b], na.rm = TRUE),
    sigma_rel_frob_median = median(sub$sigma_rel_frob[fin_s], na.rm = TRUE),
    sigma_rel_frob_mean = mean(sub$sigma_rel_frob[fin_s], na.rm = TRUE),
    sigma_trace_median = median(sub$sigma_trace, na.rm = TRUE),
    elapsed_median = median(sub$elapsed, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
write.csv(flat, file.path(OUT, "h2h-summary.csv"), row.names = FALSE)

cat("\n=== H2H summary (cloglog; Σ caveat expected) ===\n")
print(flat)
cat("\nWrote", file.path(OUT, "h2h-raw.csv"), "\n")
