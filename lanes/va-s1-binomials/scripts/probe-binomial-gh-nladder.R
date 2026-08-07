#!/usr/bin/env Rscript
## Binomial GH large-N ladder: logit (GH/JJ) + probit (GH/AC) + cloglog (GH)
## vs LA + gllvm. Question: as n↑, does GH noise die / recovery improve?
##
## PROBE_LINK=logit|probit|cloglog|both|all  (default both = logit+probit)
## PROBE_APPEND=1  rbind onto existing seed-rows-long.csv (same OUT_ROOT)
## N_GRID e.g. 120,400,1000  (add 2000 only if cheap)
## Same seeds per n. Private R3. Local ≤10 cores. No fence change.
##
## Arms per link (measurement only; logit GH fix PARKED):
##   logit:   GH, JJ, LA; gllvm VA (+ LA if PROBE_DO_GLLVM_LA)
##   probit:  GH, AC, LA; gllvm VA (+ LA)
##   cloglog: GH, LA;     gllvm VA (+ LA)
##
## Metrics:
##   β RMSE, Σ rel Frob (loadings-only), frob_Shat, collapse/runaway flags
##   trace_ratio = tr(Σ̂)/tr(Σ_true); eta_var when R3 scores available
##   paired Δ vs gllvm VA; pass_abs (β≤0.35 & Σrf≤0.50)

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT_ROOT <- Sys.getenv(
  "PROBE_OUT_ROOT",
  unset = "/private/tmp/va-s1-binomial-gh-nladder-20260807"
)
LINK_REQ <- Sys.getenv("PROBE_LINK", "both")
APPEND <- identical(Sys.getenv("PROBE_APPEND", "0"), "1")
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "12"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "10901")) + seq_len(N_SEED) - 1L
N_GRID <- as.integer(strsplit(Sys.getenv("PROBE_N_GRID", "120,400,1000"), ",")[[1L]])
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
P <- as.integer(Sys.getenv("PROBE_P", "8"))
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
DO_GLLVM_LA <- identical(Sys.getenv("PROBE_DO_GLLVM_LA", "1"), "1")
## zero = historical ladder (often collapses gllvm VA on logit);
## default = gllvm package starts (fair JJ↔gllvm same-family compare).
GLLVM_START <- Sys.getenv("PROBE_GLLVM_START", "zero")
stopifnot(GLLVM_START %in% c("zero", "default"))
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-3"))
CAP_BETA <- 0.35
CAP_SIG <- 0.50
RUNAWAY_MULT <- as.numeric(Sys.getenv("RUNAWAY_MULT", "2"))

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1"
)
dir.create(OUT_ROOT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(parallel)
})
stopifnot(requireNamespace("gllvm", quietly = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

LINKS <- if (identical(LINK_REQ, "both")) {
  c("logit", "probit")
} else if (identical(LINK_REQ, "all")) {
  c("logit", "probit", "cloglog")
} else {
  stopifnot(LINK_REQ %in% c("logit", "probit", "cloglog"))
  LINK_REQ
}

va_tiers_for <- function(link) {
  switch(link,
    logit = c("gh", "jj"),
    probit = c("gh", "ac"),
    cloglog = "gh",
    stop("unknown link: ", link)
  )
}

fam_r3_for <- function(link) {
  switch(link,
    logit = "binomial",
    probit = "binomial_probit",
    cloglog = "binomial_cloglog",
    stop("unknown link: ", link)
  )
}

link_inv <- function(link) {
  switch(link,
    logit = stats::plogis,
    probit = stats::pnorm,
    cloglog = function(eta) pmax(0, pmin(1, 1 - exp(-exp(eta)))),
    stop("unknown link: ", link)
  )
}

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

sigma_collapsed <- function(Shat, Strue, tol = 1e-8) {
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

simulate_dgp <- function(seed, n, q = Q, p = P, link) {
  set.seed(seed)
  stopifnot(p >= q)
  link_fun <- link_inv(link)
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
    seed = seed, n = n, p = p, q = q, link = link,
    data = dat, Y = Y, beta = beta, Lambda = Lambda,
    scores = scores, Sigma = Lambda %*% t(Lambda),
    eta_var_true = stats::var(as.numeric(eta))
  )
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
    frob_Shat = NA_real_, frob_Strue = NA_real_,
    trace_ratio = NA_real_, eta_var = NA_real_,
    sigma_collapse = NA, sigma_runaway = NA,
    max_g_fe = NA_real_, err = err
  )
}

score_arm <- function(arm, beta_hat, Sigma_hat, dgp, healthy, secs,
                      max_g_fe = NA_real_, err = NA_character_,
                      eta_var = NA_real_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  fS <- if (is.matrix(Sigma_hat)) frob_norm(Sigma_hat) else NA_real_
  fT <- frob_norm(dgp$Sigma)
  list(
    arm = arm,
    ok = is.finite(br) && is.finite(sr),
    healthy = isTRUE(healthy),
    healthy_fe = isTRUE(healthy),
    secs = secs,
    beta_rmse = br,
    sigma_rel_frob = sr,
    frob_Shat = fS,
    frob_Strue = fT,
    trace_ratio = trace_ratio(Sigma_hat, dgp$Sigma),
    eta_var = eta_var,
    sigma_collapse = sigma_collapsed(Sigma_hat, dgp$Sigma),
    sigma_runaway = sigma_runaway(Sigma_hat, dgp$Sigma),
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

lambda_from_r3 <- function(raw, p, q) {
  Lam <- raw$report$Lambda_B %||% raw$report$lambda_B %||% NULL
  if (is.matrix(Lam)) return(Lam)
  th <- tryCatch({
    par <- raw$best$par %||% raw$par
    as.numeric(par[names(par) == "theta_rr"])
  }, error = function(e) NULL)
  if (is.null(th) || !length(th)) return(NULL)
  tryCatch(
    gllvmTMB:::.va_r3_unpack_theta_rr(th, p, q),
    error = function(e) NULL
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

eta_var_from_r3 <- function(raw, dgp) {
  Lam <- lambda_from_r3(raw, dgp$p, dgp$q)
  M <- tryCatch(as.matrix(raw$latent$scores), error = function(e) NULL)
  if (is.null(Lam) || is.null(M)) return(NA_real_)
  if (!identical(dim(M), c(dgp$n, dgp$q))) return(NA_real_)
  den <- dgp$eta_var_true
  if (!is.finite(den) || den <= 0) return(NA_real_)
  stats::var(as.numeric(M %*% t(Lam))) / den
}

fit_gtmb_va <- function(dgp, eval_method) {
  arm <- paste0("gtmb_va_", eval_method)
  fam_r3 <- fam_r3_for(dgp$link)
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
      link = dgp$link,
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
    err = if (healthy) NA_character_ else paste0("status=", raw$status %||% "NULL"),
    eta_var = eta_var_from_r3(raw, dgp)
  )
  if (!healthy) out$ok <- FALSE
  out
}

fit_gtmb_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  fam_gtmb <- binomial(link = dgp$link)
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
    sd.errors = FALSE
  )
  if (identical(GLLVM_START, "zero")) {
    args$control.start <- list(starting.val = "zero", n.init = 1)
  }
  if (!identical(dgp$link, "logit")) args$link <- dgp$link
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
  ## eta_var from gllvm lvs when available
  eta_v <- NA_real_
  lvs <- tryCatch(as.matrix(f$lvs), error = function(e) NULL)
  if (!is.null(lvs) && identical(dim(lvs), c(dgp$n, dgp$q))) {
    den <- dgp$eta_var_true
    if (is.finite(den) && den > 0) {
      eta_v <- stats::var(as.numeric(lvs %*% t(L))) / den
    }
  }
  score_arm(arm, beta_hat, L %*% t(L), dgp, looks, secs, eta_var = eta_v)
}

row_from_arm <- function(a, dgp) {
  data.frame(
    seed = dgp$seed, n = dgp$n, p = dgp$p, q = dgp$q, link = dgp$link,
    va_H = VA_H, arm = a$arm,
    ok = isTRUE(a$ok),
    healthy = isTRUE(a$healthy),
    healthy_fe = isTRUE(a$healthy_fe),
    beta_rmse = as.numeric(a$beta_rmse %||% NA_real_),
    sigma_rel_frob = as.numeric(a$sigma_rel_frob %||% NA_real_),
    frob_Shat = as.numeric(a$frob_Shat %||% NA_real_),
    frob_Strue = as.numeric(a$frob_Strue %||% NA_real_),
    trace_ratio = as.numeric(a$trace_ratio %||% NA_real_),
    eta_var = as.numeric(a$eta_var %||% NA_real_),
    sigma_collapse = isTRUE(a$sigma_collapse),
    sigma_runaway = isTRUE(a$sigma_runaway),
    secs = as.numeric(a$secs %||% NA_real_),
    max_g_fe = as.numeric(a$max_g_fe %||% NA_real_),
    pass_abs = isTRUE(a$ok) &&
      is.finite(a$beta_rmse) && is.finite(a$sigma_rel_frob) &&
      a$beta_rmse <= CAP_BETA && a$sigma_rel_frob <= CAP_SIG,
    err = as.character(a$err %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

one_job <- function(seed, n, link) {
  dgp <- simulate_dgp(seed, n, Q, P, link)
  va_tiers <- va_tiers_for(link)
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
  if (DO_GLLVM_LA) {
    arms$gllvm_la <- tryCatch(fit_gllvm(dgp, "LA"), error = function(e) {
      fail_arm("gllvm_la", conditionMessage(e))
    })
  }
  do.call(rbind, lapply(arms, function(a) row_from_arm(a, dgp)))
}

summarise_raw <- function(raw) {
  do.call(rbind, lapply(
    split(raw, list(raw$link, raw$n, raw$arm), drop = TRUE),
    function(sub) {
      fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
      data.frame(
        link = sub$link[[1L]],
        n = sub$n[[1L]],
        q = sub$q[[1L]],
        arm = sub$arm[[1L]],
        n_seed = nrow(sub),
        n_ok = sum(fin),
        ok = mean(sub$ok),
        healthy_fe = mean(sub$healthy_fe),
        beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
        sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
        frob_Shat = if (any(fin)) mean(sub$frob_Shat[fin], na.rm = TRUE) else NA_real_,
        trace_ratio = mean(sub$trace_ratio, na.rm = TRUE),
        eta_var = mean(sub$eta_var, na.rm = TRUE),
        frac_collapse = mean(sub$sigma_collapse),
        frac_runaway = mean(sub$sigma_runaway),
        pass_abs = if (any(fin)) {
          mean(sub$beta_rmse[fin] <= CAP_BETA & sub$sigma_rel_frob[fin] <= CAP_SIG)
        } else NA_real_,
        secs_mean = mean(sub$secs, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    }
  ))
}

paired_deltas <- function(raw) {
  out <- list()
  for (lk in unique(as.character(raw$link))) {
    va_tiers <- va_tiers_for(lk)
    for (nn in sort(unique(raw$n[raw$link == lk]))) {
      sub <- raw[raw$link == lk & raw$n == nn, ]
      wide_arm <- function(arm) {
        s <- sub[sub$arm == arm, c(
          "seed", "beta_rmse", "sigma_rel_frob", "trace_ratio", "eta_var",
          "sigma_runaway", "pass_abs", "secs"
        )]
        names(s)[-1L] <- paste0(names(s)[-1L], "_", arm)
        s
      }
      arms <- unique(as.character(sub$arm))
      arms <- arms[arms != "ERROR"]
      if (!("gllvm_va" %in% arms)) next
      paired <- Reduce(
        function(a, b) merge(a, b, by = "seed"),
        lapply(arms, wide_arm)
      )
      for (em in va_tiers) {
        a <- paste0("gtmb_va_", em)
        if (!(a %in% arms)) next
        out[[length(out) + 1L]] <- data.frame(
          link = lk, n = nn, tier = em,
          d_beta = mean(
            paired[[paste0("beta_rmse_", a)]] - paired$beta_rmse_gllvm_va,
            na.rm = TRUE
          ),
          d_sigma = mean(
            paired[[paste0("sigma_rel_frob_", a)]] -
              paired$sigma_rel_frob_gllvm_va,
            na.rm = TRUE
          ),
          d_trace = mean(
            paired[[paste0("trace_ratio_", a)]] - paired$trace_ratio_gllvm_va,
            na.rm = TRUE
          ),
          n_seed = nrow(paired),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

## ---- run ----
cat("=== CELL CARD (n-ladder) ===\n")
cat(sprintf(
  paste0(
    " family=binomial links=%s | n=%s p=%d q=%d trials=1 unique=FALSE\n",
    " seeds=%d..%d H=%d private .va_r3_fit | gllvm LA=%s | gllvm_start=%s | append=%s\n",
    " arms logit: GH+JJ+LA+gllvm; probit: GH+AC+LA+gllvm; cloglog: GH+LA+gllvm\n"
  ),
  paste(LINKS, collapse = ","), paste(N_GRID, collapse = ","), P, Q,
  SEEDS[[1L]], SEEDS[[length(SEEDS)]], VA_H, DO_GLLVM_LA, GLLVM_START, APPEND
))
cat("gllvm:", as.character(packageVersion("gllvm")),
    " cores:", CORES, " out:", OUT_ROOT, "\n")

jobs <- expand.grid(
  seed = SEEDS, n = N_GRID, link = LINKS,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)

cat(sprintf("== warm-up %s ==\n", format(Sys.time(), "%H:%M:%S")))
wu <- tryCatch(
  one_job(99981L, N_GRID[[1L]], LINKS[[1L]]),
  error = function(e) {
    cat("warm-up error:", conditionMessage(e), "\n")
    NULL
  }
)
if (!is.null(wu)) {
  print(wu[, c(
    "arm", "ok", "beta_rmse", "sigma_rel_frob", "trace_ratio",
    "eta_var", "sigma_runaway", "secs"
  )])
}

cat(sprintf(
  "== n-ladder start jobs=%d cores=%d ==\n",
  nrow(jobs), CORES
))

run_i <- function(i) {
  tryCatch(
    one_job(jobs$seed[[i]], as.integer(jobs$n[[i]]), jobs$link[[i]]),
    error = function(e) data.frame(
      seed = jobs$seed[[i]], n = as.integer(jobs$n[[i]]), p = P, q = Q,
      link = jobs$link[[i]], va_H = VA_H, arm = "ERROR",
      ok = FALSE, healthy = FALSE, healthy_fe = FALSE,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      frob_Shat = NA_real_, frob_Strue = NA_real_,
      trace_ratio = NA_real_, eta_var = NA_real_,
      sigma_collapse = FALSE, sigma_runaway = FALSE,
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
raw_new <- do.call(rbind, parts)
wall <- proc.time()[[3L]] - t0

seed_path <- file.path(OUT_ROOT, "seed-rows-long.csv")
if (APPEND && file.exists(seed_path)) {
  old <- utils::read.csv(seed_path, stringsAsFactors = FALSE)
  ## Drop any prior rows for links we just re-ran (idempotent re-append).
  old <- old[!(old$link %in% LINKS), , drop = FALSE]
  raw <- rbind(old, raw_new)
  cat(sprintf(
    "append: kept %d prior rows + %d new → %d\n",
    nrow(old), nrow(raw_new), nrow(raw)
  ))
} else {
  raw <- raw_new
}
write.csv(raw, seed_path, row.names = FALSE)
## Also keep the just-run slice for audit trails.
write.csv(
  raw_new,
  file.path(OUT_ROOT, sprintf("seed-rows-%s.csv", paste(LINKS, collapse = "-"))),
  row.names = FALSE
)

summ <- summarise_raw(raw)
summ <- summ[order(summ$link, summ$n, summ$arm), ]
write.csv(summ, file.path(OUT_ROOT, "ladder-summary.csv"), row.names = FALSE)

paired <- paired_deltas(raw)
if (!is.null(paired)) {
  write.csv(paired, file.path(OUT_ROOT, "paired-delta-vs-gllvm.csv"),
            row.names = FALSE)
}

cat("\n======== N-LADDER SUMMARY ========\n")
cat("beta RMSE / Sigma rf / trace_ratio / eta_var / frac_runaway / pass_abs / secs\n")
print(as.data.frame(summ[, c(
  "link", "n", "arm", "n_ok", "beta_rmse", "sigma_rel_frob",
  "trace_ratio", "eta_var", "frac_runaway", "frac_collapse",
  "pass_abs", "healthy_fe", "secs_mean"
)]), row.names = FALSE, digits = 4)

if (!is.null(paired)) {
  cat("\nPaired mean Δ vs gllvm_va (positive = we worse):\n")
  print(paired, row.names = FALSE, digits = 4)
}
cat(sprintf("\nwall=%.1fs wrote %s\n", wall, OUT_ROOT))
