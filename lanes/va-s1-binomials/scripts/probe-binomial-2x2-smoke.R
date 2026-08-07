#!/usr/bin/env Rscript
## Cheap local binomial 2×2 smoke (gllvmTMB VA/LA × gllvm VA/LA).
## Design-110-ish: n=120, p=8, q=2, unique=FALSE. ≤10 cores. D-50: /private/tmp.

REPO <- Sys.getenv("PROBE_REPO", "/private/tmp/gllvmtmb-va-gh-all-families")
OUT <- Sys.getenv("PROBE_OUT", "/private/tmp/va-s1-binomial-2x2-smoke-20260807")
CORES <- max(1L, min(as.integer(Sys.getenv("PILOT_CORES", "4")), 10L))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "2"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "10601")) + seq_len(N_SEED) - 1L
LINK <- Sys.getenv("PROBE_LINK", "logit") # logit|probit|cloglog
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
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
  logit = plogis,
  probit = pnorm,
  cloglog = function(z) 1 - exp(-exp(z)),
  stop("PROBE_LINK must be logit|probit|cloglog")
)
fam_gtmb <- binomial(link = LINK)

simulate_dgp <- function(seed, q = Q, n = N, p = P) {
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

score_gtmb <- function(fit, dgp, arm) {
  if (inherits(fit, "error")) {
    return(data.frame(arm = arm, ok = FALSE, healthy = FALSE, secs = NA_real_,
      beta_rmse = NA_real_, sigma_rf = NA_real_, err = conditionMessage(fit),
      stringsAsFactors = FALSE))
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
  bhat <- tryCatch(
    as.numeric(gllvmTMB:::.gllvmTMB_b_fix_values(fit)),
    error = function(e) NA_real_
  )
  Shat <- tryCatch({
    S <- extract_Sigma(fit, level = "unit", part = "shared")
    if (is.list(S)) Filter(is.matrix, S)[[1L]] else S
  }, error = function(e) NULL)
  if (is.null(Shat) && inherits(fit, "gllvmTMB_va")) {
    Shat <- fit$engine_result$report$Sigma_B %||% NULL
  }
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
  fit <- tryCatch(
    gllvmTMB(form, data = dgp$data, unit = "unit", family = fam_gtmb,
             control = gllvmTMBcontrol(integration = integration, se = TRUE),
             silent = TRUE),
    error = function(e) e
  )
  if (!inherits(fit, "error")) attr(fit, "secs") <- proc.time()[[3L]] - t0
  else {
    err <- fit
    attr(err, "secs") <- proc.time()[[3L]] - t0
    return(score_gtmb(err, dgp, paste0("gtmb_", integration)))
  }
  score_gtmb(fit, dgp, paste0("gtmb_", integration))
}

fit_gllvm <- function(dgp, method) {
  t0 <- proc.time()[[3L]]
  # gllvm binomial: family="binomial"; link via link= for non-logit when supported
  args <- list(y = dgp$Y, family = "binomial", num.lv = dgp$q, method = method,
               seed = as.integer(dgp$seed), trace = FALSE, sd.errors = FALSE,
               control.start = list(starting.val = "zero", n.init = 1))
  if (!identical(LINK, "logit")) args$link <- LINK
  f <- tryCatch(do.call(gllvm::gllvm, args), error = function(e) e)
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(data.frame(arm = paste0("gllvm_", method), ok = FALSE, healthy = FALSE,
      secs = secs, beta_rmse = NA_real_, sigma_rf = NA_real_,
      err = conditionMessage(f), stringsAsFactors = FALSE))
  }
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) sweep(th, 2L, sg, "*") else th
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  Sigma_hat <- if (nrow(L) == dgp$p) L %*% t(L) else NULL
  looks <- tryCatch(isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
                    error = function(e) FALSE)
  data.frame(
    arm = paste0("gllvm_", method), ok = TRUE, healthy = looks, secs = secs,
    beta_rmse = beta_rmse(as.numeric(f$params$beta0), dgp$beta),
    sigma_rf = rel_frob(Sigma_hat, dgp$Sigma),
    err = NA_character_, stringsAsFactors = FALSE
  )
}

one_job <- function(seed) {
  dgp <- simulate_dgp(seed)
  rows <- rbind(
    fit_gtmb(dgp, "va"),
    fit_gtmb(dgp, "laplace"),
    fit_gllvm(dgp, "VA"),
    fit_gllvm(dgp, "LA")
  )
  rows$seed <- seed
  rows$q <- dgp$q
  rows$link <- LINK
  rows$pass_abs <- is.finite(rows$beta_rmse) & is.finite(rows$sigma_rf) &
    rows$beta_rmse <= CAP_BETA & rows$sigma_rf <= CAP_SIG
  rows
}

cat(sprintf("binomial 2x2 smoke link=%s q=%d seeds=%s cores=%d\n",
            LINK, Q, paste(SEEDS, collapse = ","), CORES))
wu <- tryCatch(one_job(99991L), error = function(e) {
  cat("warm-up fail:", conditionMessage(e), "\n"); NULL
})
if (!is.null(wu)) print(wu[, c("arm", "healthy", "beta_rmse", "sigma_rf", "secs", "pass_abs")])

run_one <- function(i) {
  tryCatch(one_job(SEEDS[[i]]), error = function(e) {
    data.frame(arm = "ERROR", ok = FALSE, healthy = FALSE, secs = NA_real_,
      beta_rmse = NA_real_, sigma_rf = NA_real_, err = conditionMessage(e),
      seed = SEEDS[[i]], q = Q, link = LINK, pass_abs = FALSE,
      stringsAsFactors = FALSE)
  })
}

parts <- if (CORES <= 1L) lapply(seq_along(SEEDS), run_one) else
  mclapply(seq_along(SEEDS), run_one, mc.cores = CORES, mc.preschedule = FALSE)
raw <- do.call(rbind, parts)
write.csv(raw, file.path(OUT, "smoke-rows.csv"), row.names = FALSE)

summ <- aggregate(
  cbind(ok, healthy, beta_rmse, sigma_rf, secs, pass_abs) ~ arm + link + q,
  data = raw, FUN = function(z) mean(as.numeric(z), na.rm = TRUE)
)
write.csv(summ, file.path(OUT, "smoke-summary.csv"), row.names = FALSE)
cat("\n======== BINOMIAL 2x2 SMOKE ========\n")
print(summ, row.names = FALSE, digits = 4)
cat("wrote", OUT, "\n")
