#!/usr/bin/env Rscript
## PoisG Σ scale test (cloglog): does Σ̂ collapse die with n or p?
##
## Grid: n ∈ {120,400,1000} (PROBE_N_GRID), p=8 default, q=2, trials=1,
##       unique=FALSE. Optional wider smoke via PROBE_P=20 / PROBE_N_GRID=500.
## Arms: gtmb_poisg, gllvm_va; optional gtmb_gh, gtmb_la (PROBE_DO_REF=1).
## Seeds 8–12; local ≤10 cores. No fence/auto flip.
##
## Metrics: β RMSE, Σ rel Frob, frob_Shat / trace_ratio, collapse/runaway,
##          pass_abs (β≤0.35 & Σrf≤0.50).

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-s1-poisg-nladder-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "10"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "11201")) + seq_len(N_SEED) - 1L
N_GRID <- as.integer(strsplit(Sys.getenv("PROBE_N_GRID", "120,400,1000"), ",")[[1L]])
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
P <- as.integer(Sys.getenv("PROBE_P", "8"))
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
DO_REF <- identical(Sys.getenv("PROBE_DO_REF", "1"), "1")
## default = gllvm package starts (Σ-recovery question); zero collapses both.
GLLVM_START <- Sys.getenv("PROBE_GLLVM_START", "default")
stopifnot(GLLVM_START %in% c("zero", "default"))
CAP_BETA <- 0.35
CAP_SIG <- 0.50
RUNAWAY_MULT <- as.numeric(Sys.getenv("RUNAWAY_MULT", "2"))
COLLAPSE_TOL <- as.numeric(Sys.getenv("COLLAPSE_TOL", "1e-8"))

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

cat("PoisG n-ladder cloglog\n")
cat("repo:", REPO, " out:", OUT, "\n")
cat("n=", paste(N_GRID, collapse = ","),
    " p=", P, " q=", Q, " seeds=", N_SEED,
    " cores=", CORES, " ref=", DO_REF, "\n", sep = "")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

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

sigma_collapsed <- function(Shat, Strue, tol = COLLAPSE_TOL) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA)
  den <- frob_norm(Strue)
  if (!is.finite(den) || den <= 0) return(NA)
  isTRUE(frob_norm(Shat) < tol * den)
}

sigma_runaway <- function(Shat, Strue, mult = RUNAWAY_MULT) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA)
  den <- frob_norm(Strue)
  if (!is.finite(den) || den <= 0) return(NA)
  isTRUE(frob_norm(Shat) > mult * den)
}

beta_rmse <- function(bhat, btrue) {
  if (length(bhat) != length(btrue) || any(!is.finite(bhat))) return(NA_real_)
  sqrt(mean((bhat - btrue)^2))
}

trace_ratio <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  den <- sum(diag(Strue))
  if (!is.finite(den) || den <= 0) return(NA_real_)
  sum(diag(Shat)) / den
}

simulate_dgp <- function(seed, n, q = Q, p = P) {
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

fail_arm <- function(arm, err, secs = NA_real_) {
  list(
    arm = arm, ok = FALSE, secs = secs,
    beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    frob_Shat = NA_real_, sigma_trace = NA_real_,
    trace_ratio = NA_real_,
    sigma_collapse = NA, sigma_runaway = NA,
    err = err
  )
}

score_arm <- function(arm, beta_hat, Sigma_hat, dgp, secs, err = NA_character_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  fS <- if (is.matrix(Sigma_hat)) frob_norm(Sigma_hat) else NA_real_
  tr <- if (is.matrix(Sigma_hat)) sum(diag(Sigma_hat)) else NA_real_
  list(
    arm = arm,
    ok = is.finite(br) && is.finite(sr),
    secs = secs,
    beta_rmse = br,
    sigma_rel_frob = sr,
    frob_Shat = fS,
    sigma_trace = tr,
    trace_ratio = trace_ratio(Sigma_hat, dgp$Sigma),
    sigma_collapse = sigma_collapsed(Sigma_hat, dgp$Sigma),
    sigma_runaway = sigma_runaway(Sigma_hat, dgp$Sigma),
    err = err
  )
}

sigma_from_r3 <- function(fit, p, q) {
  S <- fit$report$Sigma_B %||% NULL
  if (is.matrix(S)) return(S)
  Lam <- fit$report$Lambda %||% fit$report$Lambda_B %||% NULL
  if (is.matrix(Lam)) return(Lam %*% t(Lam))
  th <- tryCatch({
    par <- fit$best$par %||% fit$par
    as.numeric(par[names(par) == "theta_rr"])
  }, error = function(e) NULL)
  if (is.null(th) || !length(th)) return(NULL)
  L <- tryCatch(
    gllvmTMB:::.va_r3_unpack_theta_rr(th, p, q),
    error = function(e) NULL
  )
  if (is.null(L)) NULL else L %*% t(L)
}

fit_gtmb_va <- function(dgp, eval_method) {
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
      unique = FALSE,
      n_starts = 4L,
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm(arm, conditionMessage(fit), secs))
  }
  par <- fit$best$par
  bhat <- unname(par[names(par) == "beta"])
  Sigma_hat <- sigma_from_r3(fit, dgp$p, dgp$q)
  score_arm(arm, bhat, Sigma_hat, dgp, secs, err = fit$status %||% NA_character_)
}

fit_gtmb_la <- function(dgp) {
  t0 <- proc.time()[["elapsed"]]
  dat <- data.frame(
    unit = factor(dgp$data$unit),
    trait = factor(dgp$data$trait),
    value = dgp$data$y,
    stringsAsFactors = FALSE
  )
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    dgp$q
  ))
  fit <- tryCatch(
    gllvmTMB(
      form,
      data = dat,
      unit = "unit",
      family = binomial(link = "cloglog"),
      control = gllvmTMBcontrol(integration = "laplace", se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm("gtmb_la", conditionMessage(fit), secs))
  }
  beta_hat <- tryCatch({
    par <- fit$opt$par %||% fit$tmb_obj$par
    nm <- names(par)
    as.numeric(par[startsWith(nm, "b_fix") | nm == "b_fixed"])[seq_len(dgp$p)]
  }, error = function(e) NA_real_)
  Sigma_hat <- tryCatch({
    S <- fit$report$Sigma_B %||% NULL
    if (is.null(S)) {
      Lam <- fit$report$Lambda_B %||% fit$report$lambda_B
      if (!is.null(Lam)) Lam %*% t(Lam) else NULL
    } else S
  }, error = function(e) NULL)
  score_arm("gtmb_la", beta_hat, Sigma_hat, dgp, secs)
}

fit_gllvm_va <- function(dgp) {
  t0 <- proc.time()[["elapsed"]]
  args <- list(
    y = dgp$Y,
    family = binomial(link = "cloglog"),
    num.lv = dgp$q,
    method = "VA",
    seed = as.integer(dgp$seed),
    trace = FALSE,
    sd.errors = FALSE
  )
  if (identical(GLLVM_START, "zero")) {
    args$control.start <- list(starting.val = "zero", n.init = 1)
  }
  fit <- tryCatch(do.call(gllvm::gllvm, args), error = function(e) e)
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm("gllvm_va", conditionMessage(fit), secs))
  }
  bhat <- as.numeric(fit$params$beta0)
  th <- as.matrix(fit$params$theta)
  sg <- tryCatch(as.numeric(fit$params$sigma.lv), error = function(e) NULL)
  L <- if (!is.null(sg) && length(sg) == ncol(th)) {
    sweep(th, 2L, sg, "*")
  } else th
  if (ncol(L) > dgp$q) L <- L[, seq.int(ncol(L) - dgp$q + 1L, ncol(L)), drop = FALSE]
  if (nrow(L) != dgp$p) {
    return(fail_arm(
      "gllvm_va",
      sprintf("theta dim %s vs p=%d", paste(dim(L), collapse = "x"), dgp$p),
      secs
    ))
  }
  score_arm("gllvm_va", bhat, L %*% t(L), dgp, secs, err = "ok")
}

row_from_arm <- function(a, dgp) {
  data.frame(
    seed = dgp$seed, n = dgp$n, p = dgp$p, q = dgp$q,
    arm = a$arm,
    ok = isTRUE(a$ok),
    beta_rmse = as.numeric(a$beta_rmse %||% NA_real_),
    sigma_rel_frob = as.numeric(a$sigma_rel_frob %||% NA_real_),
    frob_Shat = as.numeric(a$frob_Shat %||% NA_real_),
    sigma_trace = as.numeric(a$sigma_trace %||% NA_real_),
    trace_ratio = as.numeric(a$trace_ratio %||% NA_real_),
    sigma_collapse = isTRUE(a$sigma_collapse),
    sigma_runaway = isTRUE(a$sigma_runaway),
    secs = as.numeric(a$secs %||% NA_real_),
    pass_abs = isTRUE(a$ok) &&
      is.finite(a$beta_rmse) && is.finite(a$sigma_rel_frob) &&
      a$beta_rmse <= CAP_BETA && a$sigma_rel_frob <= CAP_SIG,
    err = as.character(a$err %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

one_job <- function(seed, n) {
  dgp <- simulate_dgp(seed, n, Q, P)
  arms <- list(
    tryCatch(fit_gtmb_va(dgp, "poisg"), error = function(e) {
      fail_arm("gtmb_poisg", conditionMessage(e))
    }),
    tryCatch(fit_gllvm_va(dgp), error = function(e) {
      fail_arm("gllvm_va", conditionMessage(e))
    })
  )
  if (DO_REF) {
    arms <- c(
      arms,
      list(
        tryCatch(fit_gtmb_va(dgp, "gh"), error = function(e) {
          fail_arm("gtmb_gh", conditionMessage(e))
        }),
        tryCatch(fit_gtmb_la(dgp), error = function(e) {
          fail_arm("gtmb_la", conditionMessage(e))
        })
      )
    )
  }
  do.call(rbind, lapply(arms, function(a) row_from_arm(a, dgp)))
}

summarise_raw <- function(raw) {
  do.call(rbind, lapply(
    split(raw, list(raw$n, raw$p, raw$arm), drop = TRUE),
    function(sub) {
      fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
      data.frame(
        n = sub$n[[1L]],
        p = sub$p[[1L]],
        q = sub$q[[1L]],
        arm = sub$arm[[1L]],
        n_seed = nrow(sub),
        n_ok = sum(fin),
        beta_rmse_med = if (any(fin)) median(sub$beta_rmse[fin]) else NA_real_,
        beta_rmse_mean = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
        sigma_rel_frob_med = if (any(fin)) median(sub$sigma_rel_frob[fin]) else NA_real_,
        sigma_rel_frob_mean = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
        frob_Shat_med = if (any(fin)) median(sub$frob_Shat[fin], na.rm = TRUE) else NA_real_,
        sigma_trace_med = median(sub$sigma_trace, na.rm = TRUE),
        trace_ratio_med = median(sub$trace_ratio, na.rm = TRUE),
        frac_collapse = mean(sub$sigma_collapse),
        frac_runaway = mean(sub$sigma_runaway),
        pass_abs = if (any(fin)) mean(sub$pass_abs[fin]) else NA_real_,
        secs_med = median(sub$secs, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    }
  ))
}

jobs <- expand.grid(seed = SEEDS, n = N_GRID, KEEP.OUT.ATTRS = FALSE)
cat("Jobs:", nrow(jobs), " (= seeds x n); arms/job ≈",
    if (DO_REF) 4L else 2L, "\n")

t_wall0 <- proc.time()[["elapsed"]]
rows <- if (CORES > 1L) {
  parallel::mclapply(seq_len(nrow(jobs)), function(i) {
    one_job(jobs$seed[[i]], jobs$n[[i]])
  }, mc.cores = CORES)
} else {
  lapply(seq_len(nrow(jobs)), function(i) {
    one_job(jobs$seed[[i]], jobs$n[[i]])
  })
}
wall <- proc.time()[["elapsed"]] - t_wall0
raw <- do.call(rbind, rows)
write.csv(raw, file.path(OUT, "ladder-raw.csv"), row.names = FALSE)

summ <- summarise_raw(raw)
summ <- summ[order(summ$n, summ$arm), , drop = FALSE]
write.csv(summ, file.path(OUT, "ladder-summary.csv"), row.names = FALSE)

cat("\n=== PoisG cloglog n-ladder summary (wall=", round(wall, 1), "s) ===\n", sep = "")
print(summ[, c(
  "n", "p", "arm", "n_ok", "beta_rmse_med", "sigma_rel_frob_med",
  "sigma_trace_med", "frob_Shat_med", "frac_collapse", "frac_runaway",
  "pass_abs", "secs_med"
)])
cat("\nWrote", file.path(OUT, "ladder-raw.csv"), "\n")
cat("Wrote", file.path(OUT, "ladder-summary.csv"), "\n")
