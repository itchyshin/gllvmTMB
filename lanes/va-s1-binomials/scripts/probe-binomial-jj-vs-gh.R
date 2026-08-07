#!/usr/bin/env Rscript
## Binomial logit JJ vs GH dig — same Design-110 seeds as scientific 2×2.
## Arms on identical data:
##   gtmb_va_gh  — private R3 eval_method="gh" H=7
##   gtmb_va_jj  — private R3 eval_method="jj" (binomial-logit JJ/PG bound)
##   gtmb_la / gllvm_va / gllvm_la
## Scorers: β RMSE vs planted; Σ rel Frob via Sigma_B (not extract_Sigma).
## Abs caps: β≤0.35, Σ≤0.50. Local ≤10 cores. No public fence / H change.
##
## Metrics glossary (chat + audit):
##   β RMSE  = sqrt(mean((β̂ − β_true)²)) vs Design-110 planted FE
##   Σ rf    = ‖Σ̂−Σ_true‖_F / ‖Σ_true‖_F ; Σ=ΛΛ′ (loadings-only)
##   pass_abs = β≤0.35 AND Σ rf≤0.50
##   Δ        = ours − gllvm_va (positive = we are worse)

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-s1-binomial-jj-vs-gh-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "24"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "10801")) + seq_len(N_SEED) - 1L
LINK <- "logit"
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
cat("gllvm:", as.character(packageVersion("gllvm")), "\n")
cat("repo:", REPO, " out:", OUT, " cores:", CORES,
    " seeds:", N_SEED, " qs:", paste(QS, collapse = ","),
    " link:", LINK, " H:", VA_H, "\n")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

link_fun <- plogis
link_id <- 0L
fam_gtmb <- binomial(link = "logit")

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
    conv = conv,
    pd = pd,
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

## Private R3 VA — eval_method in {"gh","jj"}; H inert for JJ but kept for logs
fit_gtmb_va <- function(dgp, eval_method) {
  arm <- paste0("gtmb_va_", eval_method)
  t0 <- proc.time()[[3L]]
  ns <- asNamespace("gllvmTMB")
  engine <- get(".approximation_engine_va_r3_fit", envir = ns)
  wrap <- get(".va_route_build_fit", envir = ns)
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
      eval_method = eval_method,
      family_codes = rep.int(1L, n_obs),
      link_ids = rep.int(link_id, n_obs),
      n_ordinal_cuts_per_trait = integer(dgp$p),
      ordinal_offset_per_trait = integer(dgp$p),
      ordinal_log_increments_start = numeric(),
      fixed_tweedie_power = NULL,
      fixed_student_df = NULL,
      match_laplace_residual_sd = FALSE,
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(result, "error")) {
    return(fail_arm(arm, conditionMessage(result), secs))
  }
  fit <- wrap(
    result,
    call = match.call(),
    q = dgp$q, p = dgp$p, n = dgp$n,
    eval_method = eval_method,
    family = "binomial_logit",
    link = LINK,
    beta_names = colnames(X)
  )
  beta_hat <- as.numeric(
    fit$fitted$parameters[names(fit$fitted$parameters) == "beta"]
  )
  Sigma_hat <- fit$engine_result$report$Sigma_B %||%
    result$report$Sigma_B %||% NULL
  healthy <- identical(fit$status, "healthy")
  out <- score_arm(
    arm, beta_hat, Sigma_hat, dgp, healthy, secs,
    err = if (healthy) NA_character_ else paste0("status=", fit$status %||% "NULL")
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
    } else {
      S
    }
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
  looks <- tryCatch(
    isTRUE(f$convergence) || identical(as.integer(f$convergence), 0L),
    error = function(e) FALSE
  )
  score_arm(arm, beta_hat, Sigma_hat, dgp, looks, secs)
}

one_job <- function(seed, q) {
  dgp <- simulate_dgp(seed, q)
  arms <- list(
    gtmb_va_gh = tryCatch(fit_gtmb_va(dgp, "gh"), error = function(e) {
      fail_arm("gtmb_va_gh", conditionMessage(e))
    }),
    gtmb_va_jj = tryCatch(fit_gtmb_va(dgp, "jj"), error = function(e) {
      fail_arm("gtmb_va_jj", conditionMessage(e))
    }),
    gtmb_la = tryCatch(fit_gtmb_la(dgp), error = function(e) {
      fail_arm("gtmb_la", conditionMessage(e))
    }),
    gllvm_va = tryCatch(fit_gllvm(dgp, "VA"), error = function(e) {
      fail_arm("gllvm_va", conditionMessage(e))
    }),
    gllvm_la = tryCatch(fit_gllvm(dgp, "LA"), error = function(e) {
      fail_arm("gllvm_la", conditionMessage(e))
    })
  )
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
  "== binomial JJ vs GH start H=%d seeds=%d qs=%s jobs=%d cores=%d ==\n",
  VA_H, N_SEED, paste(QS, collapse = ","), nrow(jobs), CORES
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
    frac_sigma_gt_0.5 = if (any(fin)) mean(sub$sigma_rel_frob[fin] > CAP_SIG) else NA_real_,
    pass_abs = if (any(fin)) {
      mean(sub$beta_rmse[fin] <= CAP_BETA & sub$sigma_rel_frob[fin] <= CAP_SIG)
    } else {
      NA_real_
    },
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
arm_names <- c("gtmb_va_gh", "gtmb_va_jj", "gtmb_la", "gllvm_va", "gllvm_la")
paired <- Reduce(
  function(a, b) merge(a, b, by = c("seed", "q")),
  lapply(arm_names, wide_arm)
)
paired$d_beta_gh_vs_gllvm_va <- paired$beta_rmse_gtmb_va_gh - paired$beta_rmse_gllvm_va
paired$d_sigma_gh_vs_gllvm_va <- paired$sigma_rel_frob_gtmb_va_gh - paired$sigma_rel_frob_gllvm_va
paired$d_beta_jj_vs_gllvm_va <- paired$beta_rmse_gtmb_va_jj - paired$beta_rmse_gllvm_va
paired$d_sigma_jj_vs_gllvm_va <- paired$sigma_rel_frob_gtmb_va_jj - paired$sigma_rel_frob_gllvm_va
paired$d_beta_jj_vs_gh <- paired$beta_rmse_gtmb_va_jj - paired$beta_rmse_gtmb_va_gh
paired$d_sigma_jj_vs_gh <- paired$sigma_rel_frob_gtmb_va_jj - paired$sigma_rel_frob_gtmb_va_gh
write.csv(paired, file.path(OUT, "paired.csv"), row.names = FALSE)

cat("\n======== BINOMIAL JJ vs GH SCIENTIFIC SUMMARY ========\n")
cat("Abs caps: β RMSE ≤ 0.35 ; Σ rel Frob ≤ 0.50\n")
cat("β = RMSE vs planted Design-110 truth; Σ = ‖Σ̂−Σ‖_F/‖Σ‖_F loadings-only\n")
print(summ, row.names = FALSE, digits = 4)

cat("\nPaired mean Δ vs gllvm_va (positive = we worse):\n")
for (qq in sort(unique(paired$q))) {
  sub <- paired[paired$q == qq, ]
  cat(sprintf(
    paste0(
      " q=%d  GH−gllvm_va: dβ=%+.4f dΣ=%+.4f |",
      " JJ−gllvm_va: dβ=%+.4f dΣ=%+.4f |",
      " JJ−GH: dβ=%+.4f dΣ=%+.4f | n=%d\n"
    ),
    qq,
    mean(sub$d_beta_gh_vs_gllvm_va, na.rm = TRUE),
    mean(sub$d_sigma_gh_vs_gllvm_va, na.rm = TRUE),
    mean(sub$d_beta_jj_vs_gllvm_va, na.rm = TRUE),
    mean(sub$d_sigma_jj_vs_gllvm_va, na.rm = TRUE),
    mean(sub$d_beta_jj_vs_gh, na.rm = TRUE),
    mean(sub$d_sigma_jj_vs_gh, na.rm = TRUE),
    nrow(sub)
  ))
}
cat(sprintf("\nwall=%.1fs wrote %s\n", wall, OUT))
