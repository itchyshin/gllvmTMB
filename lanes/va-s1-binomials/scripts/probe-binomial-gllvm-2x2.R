#!/usr/bin/env Rscript
## Binomial 2×2 H2H — gllvmTMB VA/LA × gllvm VA/LA vs planted truth.
## Arc-2 had NO gllvm; this fills the flagship SDM gap (binomial).
## H fixed at 7 (reuse Totoro H-ladder: H7≈H5≈H9≈H61). Do not re-run H-ladder.
## Local ≤10 cores. D-50: /private/tmp only.

REPO <- Sys.getenv("PROBE_REPO", "/private/tmp/gllvmtmb-va-gh-all-families")
OUT <- Sys.getenv("PROBE_OUT", "/private/tmp/va-s1-binomial-gllvm-2x2-20260807")
CORES <- max(1L, min(as.integer(Sys.getenv("PILOT_CORES", "8")), 10L))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "24"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "10801")) + seq_len(N_SEED) - 1L
LINK <- Sys.getenv("PROBE_LINK", "logit")
QS <- as.integer(strsplit(Sys.getenv("PROBE_QS", "2,5"), ",", fixed = TRUE)[[1L]])
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
N <- 120L; P <- 8L
GRAD_TOL <- 1e-3
CAP_BETA <- 0.35; CAP_SIG <- 0.50

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
           MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(parallel)
})
stopifnot(requireNamespace("gllvm", quietly = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

link_fun <- switch(LINK,
  logit = plogis, probit = pnorm,
  cloglog = function(z) 1 - exp(-exp(z)),
  stop("bad PROBE_LINK")
)
fam_gtmb <- binomial(link = LINK)

simulate_dgp <- function(seed, q, n = N, p = P) {
  set.seed(seed)
  Lambda <- matrix(rnorm(p * q, 0, 0.25), p, q)
  for (k in seq_len(q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(n * q), n, q)
  beta <- seq(-0.5, 0.5, length.out = p)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  Y <- matrix(rbinom(n * p, 1L, link_fun(eta)), n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)), stringsAsFactors = FALSE
  )
  list(seed = seed, n = n, p = p, q = q, data = dat, Y = Y,
       beta = beta, Sigma = Lambda %*% t(Lambda))
}

rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  sqrt(sum((Shat - Strue)^2)) / sqrt(sum(Strue^2))
}
beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}

score_gtmb <- function(fit, dgp, arm) {
  if (inherits(fit, "error")) {
    return(data.frame(
      arm = arm, ok = FALSE, healthy = FALSE, secs = attr(fit, "secs") %||% NA_real_,
      beta_rmse = NA_real_, sigma_rf = NA_real_,
      err = conditionMessage(fit), stringsAsFactors = FALSE
    ))
  }
  secs <- attr(fit, "secs") %||% NA_real_
  healthy <- if (inherits(fit, "gllvmTMB_va")) {
    identical(fit$status, "healthy")
  } else {
    conv <- as.integer(fit$opt$convergence %||% NA_integer_)
    pd <- isTRUE(fit$sd_report$pdHess)
    g <- tryCatch({
      par <- fit$opt$par %||% fit$tmb_obj$par
      max(abs(fit$tmb_obj$gr(par)))
    }, error = function(e) Inf)
    identical(conv, 0L) && isTRUE(pd) && is.finite(g) && g < GRAD_TOL
  }
  bhat <- if (inherits(fit, "gllvmTMB_va")) {
    as.numeric(fit$fitted$parameters[names(fit$fitted$parameters) == "beta"])
  } else {
    tryCatch({
      b <- fit$report$b_fixed %||% fit$report$beta
      if (is.null(b)) {
        pl <- fit$tmb_obj$env$parList(fit$opt$par %||% fit$tmb_obj$par)
        b <- pl$b_fixed
      }
      as.numeric(b)[seq_len(dgp$p)]
    }, error = function(e) NA_real_)
  }
  ## Prefer report Sigma_B (campaign-aligned); avoid extract_Sigma link-implicit diag.
  Shat <- tryCatch({
    if (inherits(fit, "gllvmTMB_va")) {
      fit$engine_result$report$Sigma_B %||% NULL
    } else {
      fit$report$Sigma_B %||% {
        Lam <- fit$report$Lambda_B %||% fit$report$lambda_B
        if (!is.null(Lam)) Lam %*% t(Lam) else NULL
      }
    }
  }, error = function(e) NULL)
  data.frame(
    arm = arm, ok = TRUE, healthy = isTRUE(healthy), secs = secs,
    beta_rmse = beta_rmse(bhat, dgp$beta),
    sigma_rf = rel_frob(Shat, dgp$Sigma),
    err = NA_character_, stringsAsFactors = FALSE
  )
}

fit_gtmb <- function(dgp, integration) {
  t0 <- proc.time()[[3L]]
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)", dgp$q))
  ctrl <- if (identical(integration, "va")) {
    gllvmTMBcontrol(integration = "va", va_H = VA_H, va_eval_method = "gh", se = FALSE)
  } else {
    gllvmTMBcontrol(integration = "laplace", se = TRUE)
  }
  fit <- tryCatch(
    gllvmTMB(form, data = dgp$data, unit = "unit", family = fam_gtmb,
             control = ctrl, silent = TRUE),
    error = function(e) e
  )
  attr(fit, "secs") <- proc.time()[[3L]] - t0
  score_gtmb(fit, dgp, paste0("gtmb_", integration))
}

fit_gllvm <- function(dgp, method) {
  t0 <- proc.time()[[3L]]
  args <- list(
    y = dgp$Y, family = "binomial", num.lv = dgp$q, method = method,
    seed = as.integer(dgp$seed), trace = FALSE, sd.errors = FALSE,
    control.start = list(starting.val = "zero", n.init = 1)
  )
  if (!identical(LINK, "logit")) args$link <- LINK
  f <- tryCatch(do.call(gllvm::gllvm, args), error = function(e) e)
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(data.frame(
      arm = paste0("gllvm_", method), ok = FALSE, healthy = FALSE, secs = secs,
      beta_rmse = NA_real_, sigma_rf = NA_real_, err = conditionMessage(f),
      stringsAsFactors = FALSE
    ))
  }
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) sweep(th, 2L, sg, "*") else th
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  Sigma_hat <- if (nrow(L) == dgp$p) L %*% t(L) else NULL
  looks <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  data.frame(
    arm = paste0("gllvm_", method), ok = TRUE, healthy = looks, secs = secs,
    beta_rmse = beta_rmse(as.numeric(f$params$beta0), dgp$beta),
    sigma_rf = rel_frob(Sigma_hat, dgp$Sigma),
    err = NA_character_, stringsAsFactors = FALSE
  )
}

one_job <- function(seed, q) {
  dgp <- simulate_dgp(seed, q)
  rows <- rbind(
    fit_gtmb(dgp, "va"),
    fit_gtmb(dgp, "laplace"),
    fit_gllvm(dgp, "VA"),
    fit_gllvm(dgp, "LA")
  )
  rows$seed <- seed
  rows$q <- q
  rows$link <- LINK
  rows$va_H <- VA_H
  rows$pass_abs <- is.finite(rows$beta_rmse) & is.finite(rows$sigma_rf) &
    rows$beta_rmse <= CAP_BETA & rows$sigma_rf <= CAP_SIG
  rows
}

jobs <- expand.grid(seed = SEEDS, q = QS, KEEP.OUT.ATTRS = FALSE)
cat(sprintf(
  "binomial gllvm 2x2 link=%s H=%d seeds=%d qs=%s jobs=%d cores=%d\n",
  LINK, VA_H, N_SEED, paste(QS, collapse = ","), nrow(jobs), CORES
))
print(one_job(99971L, QS[[1L]])[, c("arm", "healthy", "beta_rmse", "sigma_rf", "secs", "pass_abs")])

run_i <- function(i) {
  tryCatch(
    one_job(jobs$seed[[i]], as.integer(jobs$q[[i]])),
    error = function(e) data.frame(
      arm = "ERROR", ok = FALSE, healthy = FALSE, secs = NA_real_,
      beta_rmse = NA_real_, sigma_rf = NA_real_, err = conditionMessage(e),
      seed = jobs$seed[[i]], q = jobs$q[[i]], link = LINK, va_H = VA_H,
      pass_abs = FALSE, stringsAsFactors = FALSE
    )
  )
}

t0 <- proc.time()[[3L]]
parts <- if (CORES <= 1L) lapply(seq_len(nrow(jobs)), run_i) else
  mclapply(seq_len(nrow(jobs)), run_i, mc.cores = CORES, mc.preschedule = FALSE)
raw <- do.call(rbind, parts)
wall <- proc.time()[[3L]] - t0
write.csv(raw, file.path(OUT, "seed-rows-long.csv"), row.names = FALSE)

summ <- do.call(rbind, lapply(split(raw, list(raw$q, raw$arm), drop = TRUE), function(sub) {
  fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rf)
  data.frame(
    link = LINK, q = sub$q[[1L]], arm = sub$arm[[1L]], n = nrow(sub),
    ok = mean(sub$ok), healthy = mean(sub$healthy),
    beta = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
    sigma = if (any(fin)) mean(sub$sigma_rf[fin]) else NA_real_,
    pass_abs = mean(sub$pass_abs),
    secs = mean(sub$secs, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
summ <- summ[order(summ$q, summ$arm), ]
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)

## Paired Δ: gtmb_va vs gllvm_VA and gtmb_va vs gtmb_laplace
wide_arm <- function(arm) {
  sub <- raw[raw$arm == arm, c("seed", "q", "beta_rmse", "sigma_rf", "healthy", "pass_abs", "secs")]
  names(sub)[-(1:2)] <- paste0(names(sub)[-(1:2)], "_", arm)
  sub
}
paired <- Reduce(function(a, b) merge(a, b, by = c("seed", "q")),
                 lapply(c("gtmb_va", "gtmb_laplace", "gllvm_VA", "gllvm_LA"), wide_arm))
paired$d_beta_vs_gllvmVA <- paired$beta_rmse_gtmb_va - paired$beta_rmse_gllvm_VA
paired$d_sigma_vs_gllvmVA <- paired$sigma_rf_gtmb_va - paired$sigma_rf_gllvm_VA
paired$d_beta_vs_gtmbLA <- paired$beta_rmse_gtmb_va - paired$beta_rmse_gtmb_laplace
paired$d_sigma_vs_gtmbLA <- paired$sigma_rf_gtmb_va - paired$sigma_rf_gtmb_laplace
write.csv(paired, file.path(OUT, "paired.csv"), row.names = FALSE)

cat("\n======== BINOMIAL gllvm 2x2 SUMMARY ========\n")
print(summ, row.names = FALSE, digits = 4)
cat("\nPaired mean Δ (ours−comparator) gtmb_va vs gllvm_VA / gtmb_LA:\n")
for (qq in sort(unique(paired$q))) {
  sub <- paired[paired$q == qq, ]
  cat(sprintf(
    " q=%d  vs gllvmVA: dβ=%.4f dΣ=%.4f | vs gtmbLA: dβ=%.4f dΣ=%.4f | n=%d\n",
    qq,
    mean(sub$d_beta_vs_gllvmVA, na.rm = TRUE),
    mean(sub$d_sigma_vs_gllvmVA, na.rm = TRUE),
    mean(sub$d_beta_vs_gtmbLA, na.rm = TRUE),
    mean(sub$d_sigma_vs_gtmbLA, na.rm = TRUE),
    nrow(sub)
  ))
}
cat(sprintf("\nwall=%.1fs wrote %s\n", wall, OUT))
