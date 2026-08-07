#!/usr/bin/env Rscript
## Systematic binomial link dig: logit (JJ/GH) vs probit (GH/AC) vs gllvm.
## Same Design-110 cell shape as scientific 2×2; scorers vs planted truth.
##
## PROBE_LINK=logit|probit (default logit)
## Private R3 via .va_r3_fit (supports jj / gh / ac). No public fence change.
## Local ≤10 cores. D-50: /private/tmp only.
##
## Glossary:
##   β RMSE     = RMSE of FE β̂ vs planted Design-110 truth (not SE, not vs gllvm)
##   Σ rel Frob = ‖Σ̂−Σ_true‖_F / ‖Σ_true‖_F ; Σ=ΛΛ′ loadings-only
##   pass_abs   = β≤0.35 AND Σ≤0.50
##   Our VA ≠ gllvm VA; AC≈gllvm on probit; GH=quadrature; JJ=logit bound

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
LINK <- Sys.getenv("PROBE_LINK", "logit")
stopifnot(LINK %in% c("logit", "probit"))
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = sprintf("/private/tmp/va-s1-binomial-%s-systematic-20260807", LINK)
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "24"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "10801")) + seq_len(N_SEED) - 1L
QS <- as.integer(strsplit(Sys.getenv("PROBE_QS", "2"), ",", fixed = TRUE)[[1L]])
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
N <- 120L
P <- 8L
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-3"))
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
invisible(gllvmTMB:::.va_r3_load_dll())

link_fun <- if (identical(LINK, "logit")) plogis else pnorm
link_id <- if (identical(LINK, "logit")) 0L else 1L
fam_r3 <- if (identical(LINK, "logit")) "binomial" else "binomial_probit"
fam_gtmb <- binomial(link = LINK)
va_tiers <- if (identical(LINK, "logit")) c("gh", "jj") else c("gh", "ac")

cat("=== CELL CARD ===\n")
cat(sprintf(
  paste0(
    " family=binomial link=%s | n=%d p=%d q=%s n_trials=1 unique=FALSE\n",
    " seeds=%d..%d H=%d engine=private .va_r3_fit (not public fence path for VA)\n",
    " arms: gtmb_va_{%s} + gtmb_la + gllvm_va + gllvm_la\n",
    " scorers: β=FE vs planted; Σ=Sigma_B / ΛΛ′ vs planted ΛΛ′\n"
  ),
  LINK, N, P, paste(QS, collapse = ","),
  SEEDS[[1L]], SEEDS[[length(SEEDS)]], VA_H,
  paste(va_tiers, collapse = ",")
))
cat("gllvm:", as.character(packageVersion("gllvm")),
    " cores:", CORES, " out:", OUT, "\n")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

simulate_dgp <- function(seed, q, n = N, p = P) {
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
  Y <- matrix(rbinom(n * p, 1L, link_fun(eta)), n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    seed = seed, n = n, p = p, q = q, data = dat, Y = Y,
    beta = beta, Lambda = Lambda, Sigma = Lambda %*% t(Lambda)
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
  g_fe <- tryCatch(max(abs(as.numeric(obj$gr(fe)))), error = function(e) Inf)
  list(
    max_g_fe = as.numeric(g_fe),
    healthy_fe = identical(conv, 0L) && isTRUE(pd) &&
      is.finite(g_fe) && g_fe < tol
  )
}

fail_arm <- function(arm, err, secs = NA_real_) {
  list(
    arm = arm, ok = FALSE, healthy = FALSE, healthy_fe = FALSE,
    secs = secs, beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    max_g_fe = NA_real_, err = err
  )
}

score_arm <- function(arm, beta_hat, Sigma_hat, dgp, healthy, secs,
                      max_g_fe = NA_real_, err = NA_character_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  list(
    arm = arm,
    ok = is.finite(br) && is.finite(sr),
    healthy = isTRUE(healthy),
    healthy_fe = isTRUE(healthy),
    secs = secs,
    beta_rmse = br,
    sigma_rel_frob = sr,
    max_g_fe = max_g_fe,
    err = err
  )
}

sigma_from_r3 <- function(raw, p, q) {
  S <- raw$report$Sigma_B %||% NULL
  if (is.matrix(S)) return(S)
  Lam <- raw$report$Lambda_B %||% raw$report$lambda_B %||% NULL
  if (is.matrix(Lam)) return(Lam %*% t(Lam))
  th <- tryCatch({
    par <- raw$best$par %||% raw$par
    as.numeric(par[names(par) == "theta_rr"])
  }, error = function(e) NULL)
  if (is.null(th) || !length(th)) return(NULL)
  L <- tryCatch(
    gllvmTMB:::.va_r3_unpack_theta_rr(th, p, q),
    error = function(e) NULL
  )
  if (is.null(L)) NULL else L %*% t(L)
}

beta_from_r3 <- function(raw, p) {
  b <- tryCatch({
    par <- raw$best$par %||% raw$par
    as.numeric(par[names(par) == "beta"])
  }, error = function(e) NA_real_)
  if (length(b) == p && all(is.finite(b))) return(b)
  tryCatch(as.numeric(raw$report$beta)[seq_len(p)], error = function(e) NA_real_)
}

## Private R3 VA (.va_r3_fit) — exposes jj / gh / ac
fit_gtmb_va <- function(dgp, eval_method) {
  arm <- paste0("gtmb_va_", eval_method)
  t0 <- proc.time()[[3L]]
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  raw <- tryCatch(
    gllvmTMB:::.va_r3_fit(
      y = dat$value,
      n_trials = rep.int(1, n_obs),
      X = X,
      unit_id = as.integer(dat$unit),
      trait_id = as.integer(dat$trait),
      q = dgp$q,
      N = dgp$n,
      T = dgp$p,
      family = fam_r3,
      link = LINK,
      unique = FALSE,
      H = VA_H,
      eval_method = eval_method,
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(raw, "error")) {
    return(fail_arm(arm, conditionMessage(raw), secs))
  }
  beta_hat <- beta_from_r3(raw, dgp$p)
  Sigma_hat <- sigma_from_r3(raw, dgp$p, dgp$q)
  healthy <- identical(raw$status, "healthy")
  out <- score_arm(
    arm, beta_hat, Sigma_hat, dgp, healthy, secs,
    err = if (healthy) NA_character_ else paste0("status=", raw$status %||% "NULL")
  )
  if (!healthy) out$ok <- FALSE
  out
}

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
      family = fam_gtmb,
      control = gllvmTMBcontrol(integration = "laplace", se = TRUE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm("gtmb_la", conditionMessage(fit), secs))
  }
  h <- gtmb_health(fit)
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
  Sigma_hat <- tryCatch({
    S <- fit$report$Sigma_B %||% NULL
    if (is.null(S)) {
      Lam <- fit$report$Lambda_B %||% fit$report$lambda_B
      if (!is.null(Lam)) Lam %*% t(Lam) else NULL
    } else S
  }, error = function(e) NULL)
  score_arm(
    "gtmb_la", beta_hat, Sigma_hat, dgp, h$healthy_fe, secs,
    max_g_fe = h$max_g_fe
  )
}

fit_gllvm <- function(dgp, method) {
  arm <- paste0("gllvm_", tolower(method))
  t0 <- proc.time()[[3L]]
  args <- list(
    y = dgp$Y,
    family = "binomial",
    num.lv = dgp$q,
    method = method,
    seed = as.integer(dgp$seed),
    trace = FALSE,
    sd.errors = FALSE,
    control.start = list(starting.val = "zero", n.init = 1)
  )
  if (!identical(LINK, "logit")) args$link <- LINK
  f <- tryCatch(do.call(gllvm::gllvm, args), error = function(e) e)
  secs <- proc.time()[[3L]] - t0
  if (inherits(f, "error")) {
    return(fail_arm(arm, conditionMessage(f), secs))
  }
  beta_hat <- as.numeric(f$params$beta0)
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(as.numeric(f$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) {
    sweep(th, 2L, sg, "*")
  } else th
  if (ncol(L) > dgp$q) L <- L[, seq_len(dgp$q), drop = FALSE]
  if (nrow(L) != dgp$p) {
    return(fail_arm(
      arm,
      sprintf("theta dim %s vs p=%d", paste(dim(L), collapse = "x"), dgp$p),
      secs
    ))
  }
  looks <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  score_arm(arm, beta_hat, L %*% t(L), dgp, looks, secs)
}

one_job <- function(seed, q) {
  dgp <- simulate_dgp(seed, q)
  arms <- lapply(va_tiers, function(em) {
    tryCatch(fit_gtmb_va(dgp, em), error = function(e) {
      fail_arm(paste0("gtmb_va_", em), conditionMessage(e))
    })
  })
  names(arms) <- paste0("gtmb_va_", va_tiers)
  arms$gtmb_la <- tryCatch(fit_gtmb_la(dgp), error = function(e) {
    fail_arm("gtmb_la", conditionMessage(e))
  })
  arms$gllvm_va <- tryCatch(fit_gllvm(dgp, "VA"), error = function(e) {
    fail_arm("gllvm_va", conditionMessage(e))
  })
  arms$gllvm_la <- tryCatch(fit_gllvm(dgp, "LA"), error = function(e) {
    fail_arm("gllvm_la", conditionMessage(e))
  })
  rows <- lapply(arms, function(a) {
    data.frame(
      seed = seed, q = q, link = LINK, va_H = VA_H, n = N, p = P,
      arm = a$arm,
      ok = isTRUE(a$ok),
      healthy = isTRUE(a$healthy),
      healthy_fe = isTRUE(a$healthy_fe),
      beta_rmse = as.numeric(a$beta_rmse %||% NA_real_),
      sigma_rel_frob = as.numeric(a$sigma_rel_frob %||% NA_real_),
      secs = as.numeric(a$secs %||% NA_real_),
      max_g_fe = as.numeric(a$max_g_fe %||% NA_real_),
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
wu <- tryCatch(one_job(99971L, QS[[1L]]), error = function(e) {
  cat("warm-up error:", conditionMessage(e), "\n")
  NULL
})
if (!is.null(wu)) {
  print(wu[, c("arm", "ok", "healthy_fe", "beta_rmse", "sigma_rel_frob",
               "secs", "pass_abs")])
}

jobs <- expand.grid(seed = SEEDS, q = QS, KEEP.OUT.ATTRS = FALSE)
cat(sprintf(
  "== systematic start link=%s H=%d seeds=%d qs=%s jobs=%d cores=%d ==\n",
  LINK, VA_H, N_SEED, paste(QS, collapse = ","), nrow(jobs), CORES
))

run_i <- function(i) {
  tryCatch(
    one_job(jobs$seed[[i]], as.integer(jobs$q[[i]])),
    error = function(e) data.frame(
      seed = jobs$seed[[i]], q = jobs$q[[i]], link = LINK, va_H = VA_H,
      n = N, p = P, arm = "ERROR", ok = FALSE, healthy = FALSE,
      healthy_fe = FALSE, beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      secs = NA_real_, max_g_fe = NA_real_, pass_abs = FALSE,
      err = conditionMessage(e), stringsAsFactors = FALSE
    )
  )
}

t0 <- proc.time()[[3L]]
parts <- if (CORES <= 1L) {
  lapply(seq_len(nrow(jobs)), run_i)
} else {
  mclapply(seq_len(nrow(jobs)), run_i, mc.cores = CORES, mc.preschedule = FALSE)
}
raw <- do.call(rbind, parts)
wall <- proc.time()[[3L]] - t0
write.csv(raw, file.path(OUT, "seed-rows-long.csv"), row.names = FALSE)

summ <- do.call(rbind, lapply(split(raw, list(raw$q, raw$arm), drop = TRUE), function(sub) {
  fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
  data.frame(
    link = LINK, q = sub$q[[1L]], arm = sub$arm[[1L]], n = nrow(sub),
    n_ok = sum(fin),
    ok = mean(sub$ok),
    healthy_fe = mean(sub$healthy_fe),
    beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
    sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
    pass_abs = if (any(fin)) {
      mean(sub$beta_rmse[fin] <= CAP_BETA & sub$sigma_rel_frob[fin] <= CAP_SIG)
    } else NA_real_,
    secs_mean = mean(sub$secs, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
summ <- summ[order(summ$q, summ$arm), ]
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)

wide_arm <- function(arm) {
  sub <- raw[raw$arm == arm, c(
    "seed", "q", "beta_rmse", "sigma_rel_frob", "healthy_fe", "pass_abs", "secs"
  )]
  names(sub)[-(1:2)] <- paste0(names(sub)[-(1:2)], "_", arm)
  sub
}
arm_names <- unique(as.character(raw$arm))
arm_names <- arm_names[arm_names != "ERROR"]
paired <- Reduce(
  function(a, b) merge(a, b, by = c("seed", "q")),
  lapply(arm_names, wide_arm)
)

## Paired Δ vs gllvm_va for each VA tier
for (em in va_tiers) {
  a <- paste0("gtmb_va_", em)
  paired[[paste0("d_beta_", em, "_vs_gllvm_va")]] <-
    paired[[paste0("beta_rmse_", a)]] - paired$beta_rmse_gllvm_va
  paired[[paste0("d_sigma_", em, "_vs_gllvm_va")]] <-
    paired[[paste0("sigma_rel_frob_", a)]] - paired$sigma_rel_frob_gllvm_va
}
write.csv(paired, file.path(OUT, "paired.csv"), row.names = FALSE)

cat("\n======== SYSTEMATIC SUMMARY ========\n")
cat("β RMSE vs planted; Σ rf loadings-only; abs 0.35/0.50; Δ = ours − gllvm_va\n")
print(summ, row.names = FALSE, digits = 4)

cat("\nPaired mean Δ vs gllvm_va (positive = we worse):\n")
for (qq in sort(unique(paired$q))) {
  sub <- paired[paired$q == qq, ]
  bits <- vapply(va_tiers, function(em) {
    sprintf(
      "%s: dβ=%+.4f dΣ=%+.4f",
      toupper(em),
      mean(sub[[paste0("d_beta_", em, "_vs_gllvm_va")]], na.rm = TRUE),
      mean(sub[[paste0("d_sigma_", em, "_vs_gllvm_va")]], na.rm = TRUE)
    )
  }, character(1))
  cat(sprintf(" q=%d  %s | n=%d\n", qq, paste(bits, collapse = " | "), nrow(sub)))
}
cat(sprintf("\nwall=%.1fs wrote %s\n", wall, OUT))
