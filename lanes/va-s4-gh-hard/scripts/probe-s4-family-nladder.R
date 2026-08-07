#!/usr/bin/env Rscript
## S4 GH-hard / hybrid family n-ladder (Design 110).
## PROBE_FAMILY ∈ {tweedie, student, truncated_poisson, ordinal_probit, delta_gamma}
## Grid: n ∈ {120,400,1000} (default), p=8, q=2, unique=FALSE loadings-only.
## Arms: gtmb LA ± VA-GH H=7 ± gllvm as feasible per family.
## Matched n_starts=1, se=FALSE, warm DLL outside timers.
## Totoro OK. D-50: /private/tmp + Totoro only. No fence / PASS claim.
##
## truncated = Design-110 family_id 10 zero-truncated Poisson (NOT Tobit /
## truncated-Gaussian). truncated_nbinom2 is a sibling cell, not this probe.

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
FAMILY <- Sys.getenv("PROBE_FAMILY", unset = "tweedie")
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = sprintf("/private/tmp/va-s4-%s-nladder-20260807",
                  gsub("_", "-", FAMILY))
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "10"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "12"))
SEEDS <- as.integer(Sys.getenv("PROBE_SEED0", "11401")) + seq_len(N_SEED) - 1L
N_GRID <- as.integer(strsplit(Sys.getenv("PROBE_N_GRID", "120,400,1000"), ",")[[1L]])
Q <- as.integer(Sys.getenv("PROBE_Q", "2"))
P <- as.integer(Sys.getenv("PROBE_P", "8"))
VA_H <- as.integer(Sys.getenv("PROBE_VA_H", "7"))
N_STARTS <- as.integer(Sys.getenv("PROBE_N_STARTS", "1"))
GLLVM_VA_NS <- as.integer(strsplit(
  Sys.getenv("PROBE_GLLVM_VA_NS", "120"), ","
)[[1L]])
DO_GLLVM_LA <- identical(Sys.getenv("PROBE_DO_GLLVM_LA", "1"), "1")
DO_GLLVM_VA <- identical(Sys.getenv("PROBE_DO_GLLVM_VA", "1"), "1")
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-3"))
CAP_BETA <- 0.35
CAP_SIG <- 0.50
RUNAWAY_MULT <- as.numeric(Sys.getenv("RUNAWAY_MULT", "2"))
TWEEDIE_P <- as.numeric(Sys.getenv("PROBE_TWEEDIE_P", "1.5"))
TWEEDIE_PHI <- as.numeric(Sys.getenv("PROBE_TWEEDIE_PHI", "0.7"))
STUDENT_DF <- as.numeric(Sys.getenv("PROBE_STUDENT_DF", "5"))
STUDENT_SIGMA <- as.numeric(Sys.getenv("PROBE_STUDENT_SIGMA", "0.8"))
DELTA_SHAPE <- as.numeric(Sys.getenv("PROBE_DELTA_SHAPE", "2.5"))
ORDINAL_CUTS <- as.numeric(strsplit(
  Sys.getenv("PROBE_ORDINAL_CUTS", "0,0.8"), ","
)[[1L]])

fam_spec <- switch(
  FAMILY,
  tweedie = list(
    family_id = 6L, link_id = 0L, label = "tweedie_log",
    gllvm_family = "tweedie", gllvm_la = TRUE, gllvm_va = TRUE,
    la_family = quote(tweedie(p = TWEEDIE_P)),
    fixed_tweedie_power = TWEEDIE_P, fixed_student_df = NULL
  ),
  student = list(
    family_id = 9L, link_id = 0L, label = "student_identity",
    gllvm_family = NA_character_, gllvm_la = FALSE, gllvm_va = FALSE,
    la_family = quote(student(df = STUDENT_DF)),
    fixed_tweedie_power = NULL, fixed_student_df = STUDENT_DF
  ),
  truncated_poisson = list(
    family_id = 10L, link_id = 0L, label = "truncated_poisson_log",
    gllvm_family = NA_character_, gllvm_la = FALSE, gllvm_va = FALSE,
    la_family = quote(truncated_poisson()),
    fixed_tweedie_power = NULL, fixed_student_df = NULL
  ),
  ordinal_probit = list(
    family_id = 14L, link_id = 0L, label = "ordinal_probit",
    gllvm_family = "ordinal", gllvm_la = FALSE, gllvm_va = TRUE,
    la_family = quote(ordinal_probit()),
    fixed_tweedie_power = NULL, fixed_student_df = NULL
  ),
  delta_gamma = list(
    family_id = 13L, link_id = 0L, label = "delta_gamma_log",
    gllvm_family = NA_character_, gllvm_la = FALSE, gllvm_va = FALSE,
    la_family = quote(delta_gamma()),
    fixed_tweedie_power = NULL, fixed_student_df = NULL
  ),
  stop(sprintf(
    "PROBE_FAMILY must be tweedie|student|truncated_poisson|ordinal_probit|delta_gamma (got %s)",
    FAMILY
  ))
)

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1"
)
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  ## quiet student()/tweedie() constructor notes during LA fits
  options(cli.default_handler = function(...) invisible(NULL))
  devtools::load_all(".", quiet = TRUE)
  library(parallel)
})
if (isTRUE(fam_spec$gllvm_la) || isTRUE(fam_spec$gllvm_va)) {
  stopifnot(requireNamespace("gllvm", quietly = TRUE))
}
if (identical(FAMILY, "tweedie")) {
  stopifnot(requireNamespace("tweedie", quietly = TRUE))
}
invisible(gllvmTMB:::.va_r3_load_dll())
cat("family:", FAMILY, "(", fam_spec$label, ")\n")
cat("gllvm:", if (requireNamespace("gllvm", quietly = TRUE))
  as.character(packageVersion("gllvm")) else "NA", "\n")
cat("repo:", REPO, " out:", OUT, "\n")
cat(sprintf(
  "n=%s p=%d q=%d H=%d n_starts=%d seeds=%d cores=%d gllvm_la=%s gllvm_va=%s\n",
  paste(N_GRID, collapse = ","), P, Q, VA_H, N_STARTS, N_SEED, CORES,
  fam_spec$gllvm_la && DO_GLLVM_LA, fam_spec$gllvm_va && DO_GLLVM_VA
))

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

ztpois_draw <- function(mu_vec) {
  out <- stats::rpois(length(mu_vec), lambda = mu_vec)
  bad <- which(out < 1L | !is.finite(out))
  tries <- 0L
  while (length(bad) && tries < 100L) {
    tries <- tries + 1L
    out[bad] <- stats::rpois(length(bad), lambda = mu_vec[bad])
    bad <- which(out < 1L | !is.finite(out))
  }
  if (length(bad)) stop("ztpois_draw failed to clear zeros/nonfinite", call. = FALSE)
  as.integer(out)
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
  ## ordinal / truncated need slightly stronger signal at small n
  if (FAMILY %in% c("ordinal_probit", "truncated_poisson", "delta_gamma")) {
    beta <- seq(-0.15, 0.35, length.out = p)
  }
  if (FAMILY == "student") {
    beta <- seq(-0.5, 0.5, length.out = p)
  }
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  mu <- exp(eta)
  Y <- matrix(NA_real_, n, p)
  if (FAMILY == "tweedie") {
    Y[] <- tweedie::rtweedie(
      n * p, mu = as.vector(mu), phi = TWEEDIE_PHI, power = TWEEDIE_P
    )
  } else if (FAMILY == "student") {
    Y[] <- as.vector(eta) + STUDENT_SIGMA * stats::rt(n * p, df = STUDENT_DF)
  } else if (FAMILY == "truncated_poisson") {
    Y[] <- ztpois_draw(as.vector(mu))
  } else if (FAMILY == "ordinal_probit") {
    cuts <- ORDINAL_CUTS
    ystar <- as.vector(eta) + stats::rnorm(n * p)
    Y[] <- 1L + rowSums(outer(ystar, cuts, ">"))
    ## ensure each trait sees all K categories
    K <- length(cuts) + 1L
    for (t in seq_len(p)) {
      attempt <- 0L
      while (length(unique(Y[, t])) < K && attempt < 200L) {
        attempt <- attempt + 1L
        ystar_t <- eta[, t] + stats::rnorm(n)
        Y[, t] <- 1L + rowSums(outer(ystar_t, cuts, ">"))
      }
      if (length(unique(Y[, t])) < K) {
        stop(sprintf("ordinal DGP trait %d missing categories (seed=%d)", t, seed),
             call. = FALSE)
      }
    }
  } else if (FAMILY == "delta_gamma") {
    occ <- matrix(stats::rbinom(n * p, 1L, stats::plogis(as.vector(eta))), n, p)
    shape <- DELTA_SHAPE
    pos <- matrix(
      stats::rgamma(n * p, shape = shape, scale = as.vector(mu) / shape),
      n, p
    )
    Y <- occ * pos
  } else {
    stop("unknown FAMILY")
  }
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    seed = seed, n = n, p = p, q = q,
    data = dat, Y = Y, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda)
  )
}

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

fail_arm <- function(arm, err, secs = NA_real_) {
  list(
    arm = arm, ok = FALSE, healthy = FALSE, secs = secs,
    beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    frob_Shat = NA_real_, sigma_collapse = NA, sigma_runaway = NA,
    max_g_fe = NA_real_, max_abs_loading = NA_real_, err = err
  )
}

score_arm <- function(arm, beta_hat, Sigma_hat, dgp, healthy, secs,
                      max_g_fe = NA_real_, max_abs_loading = NA_real_,
                      err = NA_character_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  fS <- if (is.matrix(Sigma_hat)) frob_norm(Sigma_hat) else NA_real_
  list(
    arm = arm,
    ok = is.finite(br) && is.finite(sr),
    healthy = isTRUE(healthy),
    secs = secs,
    beta_rmse = br,
    sigma_rel_frob = sr,
    frob_Shat = fS,
    sigma_collapse = sigma_collapsed(Sigma_hat, dgp$Sigma),
    sigma_runaway = sigma_runaway(Sigma_hat, dgp$Sigma),
    max_g_fe = max_g_fe,
    max_abs_loading = max_abs_loading,
    err = err
  )
}

gtmb_la_health <- function(fit, tol = GRAD_TOL) {
  conv <- as.integer(fit$opt$convergence %||% NA_integer_)
  has_sd <- !is.null(fit$sd_report) && !is.null(fit$sd_report$pdHess)
  pd <- if (has_sd) isTRUE(fit$sd_report$pdHess) else NA
  obj <- fit$tmb_obj
  fe <- fit$opt$par %||% obj$par
  g_fe <- tryCatch(max(abs(as.numeric(obj$gr(fe)))), error = function(e) Inf)
  healthy_fe <- identical(conv, 0L) && is.finite(g_fe) && g_fe < tol &&
    (is.na(pd) || isTRUE(pd))
  list(
    conv = conv, pd = pd, max_g_fe = as.numeric(g_fe),
    healthy_fe = isTRUE(healthy_fe)
  )
}

extract_sigma <- function(report) {
  S <- report$Sigma_B %||% NULL
  if (is.null(S)) {
    Lam <- report$Lambda_B %||% report$lambda_B
    if (!is.null(Lam)) S <- Lam %*% t(Lam)
  }
  S
}

fit_gtmb_va <- function(dgp) {
  t0 <- proc.time()[[3L]]
  ns <- asNamespace("gllvmTMB")
  engine <- get(".va_r3_fit", envir = ns)
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  args <- list(
    y = dat$value,
    n_trials = rep.int(1, n_obs),
    X = X,
    unit_id = as.integer(dat$unit),
    trait_id = as.integer(dat$trait),
    q = dgp$q,
    N = dgp$n,
    T = dgp$p,
    H = VA_H,
    eval_method = "gh",
    family_codes = rep.int(fam_spec$family_id, n_obs),
    link_ids = rep.int(fam_spec$link_id, n_obs),
    ## NULL → VA auto-infers ordinal cut metadata from y; do NOT pass
    ## integer(T)/numeric() or length(increments) fails after K inference.
    n_ordinal_cuts_per_trait = NULL,
    ordinal_offset_per_trait = NULL,
    ordinal_log_increments_start = NULL,
    fixed_tweedie_power = fam_spec$fixed_tweedie_power,
    fixed_student_df = fam_spec$fixed_student_df,
    match_laplace_residual_sd = FALSE,
    n_starts = N_STARTS,
    silent = TRUE
  )
  ## fixed_* expect length-T vectors when set
  if (!is.null(args$fixed_tweedie_power)) {
    args$fixed_tweedie_power <- rep(as.numeric(args$fixed_tweedie_power), dgp$p)
  }
  if (!is.null(args$fixed_student_df)) {
    args$fixed_student_df <- rep(as.numeric(args$fixed_student_df), dgp$p)
  }
  result <- tryCatch(do.call(engine, args), error = function(e) e)
  secs <- proc.time()[[3L]] - t0
  if (inherits(result, "error")) {
    return(fail_arm("gtmb_va", conditionMessage(result), secs))
  }
  best <- result$best %||% list()
  par <- best$par %||% NULL
  beta_hat <- if (!is.null(par) && !is.null(names(par))) {
    as.numeric(par[names(par) == "beta"])
  } else {
    NA_real_
  }
  Sigma_hat <- extract_sigma(result$report %||% list())
  max_abs_L <- if (is.matrix(result$report$Lambda_B %||% NULL)) {
    max(abs(result$report$Lambda_B))
  } else {
    NA_real_
  }
  healthy <- identical(result$status, "healthy")
  score_arm(
    "gtmb_va", beta_hat, Sigma_hat, dgp, healthy, secs,
    max_g_fe = as.numeric(best$max_abs_gradient %||% NA_real_),
    max_abs_loading = max_abs_L,
    err = if (healthy) NA_character_ else paste0("status=", result$status %||% "NULL")
  )
}

fit_gtmb_la <- function(dgp) {
  t0 <- proc.time()[[3L]]
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    dgp$q
  ))
  fam <- eval(fam_spec$la_family)
  fit <- tryCatch(
    gllvmTMB(
      form,
      data = dgp$data,
      unit = "unit",
      family = fam,
      control = gllvmTMBcontrol(integration = "laplace", se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(fail_arm("gtmb_la", conditionMessage(fit), secs))
  }
  h <- gtmb_la_health(fit)
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
  Sigma_hat <- tryCatch(extract_sigma(fit$report %||% list()), error = function(e) NULL)
  max_abs_L <- if (is.matrix(fit$report$Lambda_B %||% NULL)) {
    max(abs(fit$report$Lambda_B))
  } else {
    NA_real_
  }
  score_arm(
    "gtmb_la", beta_hat, Sigma_hat, dgp, h$healthy_fe, secs,
    max_g_fe = h$max_g_fe, max_abs_loading = max_abs_L
  )
}

fit_gllvm <- function(dgp, method) {
  arm <- paste0("gllvm_", tolower(method))
  if (is.na(fam_spec$gllvm_family)) {
    return(fail_arm(arm, "gllvm family not available for this cell", NA_real_))
  }
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y,
      family = fam_spec$gllvm_family,
      num.lv = dgp$q,
      method = method,
      seed = as.integer(dgp$seed),
      trace = FALSE,
      sd.errors = FALSE,
      control.start = list(starting.val = "zero", n.init = 1)
    ),
    error = function(e) e
  )
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
  score_arm(
    arm, beta_hat, Sigma_hat, dgp, looks, secs,
    max_abs_loading = max(abs(L))
  )
}

arm_row <- function(a, seed, n) {
  data.frame(
    family = FAMILY,
    seed = seed, n = n, p = P, q = Q,
    arm = a$arm,
    ok = isTRUE(a$ok),
    healthy = isTRUE(a$healthy),
    beta_rmse = as.numeric(a$beta_rmse %||% NA_real_),
    sigma_rel_frob = as.numeric(a$sigma_rel_frob %||% NA_real_),
    frob_Shat = as.numeric(a$frob_Shat %||% NA_real_),
    sigma_collapse = as.logical(a$sigma_collapse %||% NA),
    sigma_runaway = as.logical(a$sigma_runaway %||% NA),
    max_g_fe = as.numeric(a$max_g_fe %||% NA_real_),
    max_abs_loading = as.numeric(a$max_abs_loading %||% NA_real_),
    secs = as.numeric(a$secs %||% NA_real_),
    pass_abs = isTRUE(a$ok) &&
      is.finite(a$beta_rmse) && is.finite(a$sigma_rel_frob) &&
      a$beta_rmse <= CAP_BETA && a$sigma_rel_frob <= CAP_SIG,
    err = as.character(a$err %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

one_job <- function(seed, n) {
  dgp <- simulate_dgp(seed, n = n)
  arms <- list(
    tryCatch(fit_gtmb_va(dgp), error = function(e) fail_arm("gtmb_va", conditionMessage(e))),
    tryCatch(fit_gtmb_la(dgp), error = function(e) fail_arm("gtmb_la", conditionMessage(e)))
  )
  if (isTRUE(fam_spec$gllvm_la) && isTRUE(DO_GLLVM_LA)) {
    arms <- c(arms, list(
      tryCatch(fit_gllvm(dgp, "LA"), error = function(e) fail_arm("gllvm_la", conditionMessage(e)))
    ))
  }
  if (isTRUE(fam_spec$gllvm_va) && isTRUE(DO_GLLVM_VA) && (n %in% GLLVM_VA_NS)) {
    arms <- c(arms, list(
      tryCatch(fit_gllvm(dgp, "VA"), error = function(e) fail_arm("gllvm_va", conditionMessage(e)))
    ))
  }
  ## ordinal: gllvm LA unsupported — run gllvm VA at all n when enabled
  if (identical(FAMILY, "ordinal_probit") &&
        isTRUE(fam_spec$gllvm_va) && isTRUE(DO_GLLVM_VA) &&
        !(n %in% GLLVM_VA_NS)) {
    arms <- c(arms, list(
      tryCatch(fit_gllvm(dgp, "VA"), error = function(e) fail_arm("gllvm_va", conditionMessage(e)))
    ))
  }
  do.call(rbind, lapply(arms, arm_row, seed = seed, n = n))
}

jobs <- expand.grid(seed = SEEDS, n = N_GRID, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
jobs <- jobs[order(jobs$n, jobs$seed), , drop = FALSE]

cat(sprintf("== warm-up %s ==\n", format(Sys.time(), "%H:%M:%S")))
wu <- tryCatch(one_job(99951L, N_GRID[[1L]]), error = function(e) {
  cat("warm-up fail:", conditionMessage(e), "\n"); NULL
})
if (!is.null(wu)) {
  print(wu[, c("arm", "n", "ok", "healthy", "beta_rmse", "sigma_rel_frob",
               "secs", "pass_abs")], digits = 4)
}

cat(sprintf("== ladder start %s jobs=%d ==\n", format(Sys.time(), "%H:%M:%S"), nrow(jobs)))
run_one <- function(i) {
  tryCatch(one_job(jobs$seed[[i]], jobs$n[[i]]), error = function(e) {
    data.frame(
      family = FAMILY,
      seed = jobs$seed[[i]], n = jobs$n[[i]], p = P, q = Q, arm = "ERROR",
      ok = FALSE, healthy = FALSE, beta_rmse = NA_real_,
      sigma_rel_frob = NA_real_, frob_Shat = NA_real_,
      sigma_collapse = NA, sigma_runaway = NA,
      max_g_fe = NA_real_, max_abs_loading = NA_real_, secs = NA_real_,
      pass_abs = FALSE, err = conditionMessage(e), stringsAsFactors = FALSE
    )
  })
}

parts <- if (CORES <= 1L) {
  lapply(seq_len(nrow(jobs)), run_one)
} else {
  mclapply(seq_len(nrow(jobs)), run_one, mc.cores = CORES, mc.preschedule = FALSE)
}
raw <- do.call(rbind, parts)
write.csv(raw, file.path(OUT, "ladder-raw.csv"), row.names = FALSE)

arm_levels <- c("gtmb_va", "gtmb_la", "gllvm_la", "gllvm_va")
raw$arm <- factor(as.character(raw$arm), levels = arm_levels)

summ_list <- list()
for (nn in N_GRID) {
  for (nm in arm_levels) {
    sub <- raw[as.character(raw$arm) == nm & raw$n == nn, , drop = FALSE]
    if (!nrow(sub)) next
    fin <- is.finite(sub$beta_rmse) & is.finite(sub$sigma_rel_frob)
    secs_ok <- is.finite(sub$secs)
    la_sub <- raw[as.character(raw$arm) == "gtmb_la" & raw$n == nn &
                    raw$seed %in% sub$seed, , drop = FALSE]
    la_mean <- mean(la_sub$secs, na.rm = TRUE)
    summ_list[[length(summ_list) + 1L]] <- data.frame(
      family = FAMILY,
      n = nn,
      arm = nm,
      n_seed = nrow(sub),
      n_ok = sum(fin),
      n_healthy = sum(isTRUE(sub$healthy) | sub$healthy == TRUE, na.rm = TRUE),
      beta_rmse = if (any(fin)) mean(sub$beta_rmse[fin]) else NA_real_,
      sigma_rel_frob = if (any(fin)) mean(sub$sigma_rel_frob[fin]) else NA_real_,
      sigma_rel_frob_med = if (any(fin)) stats::median(sub$sigma_rel_frob[fin]) else NA_real_,
      frac_sigma_le_0.5 = if (any(fin)) mean(sub$sigma_rel_frob[fin] <= CAP_SIG) else NA_real_,
      pass_abs = if (any(fin)) mean(sub$pass_abs[fin]) else NA_real_,
      frac_collapse = if (any(!is.na(sub$sigma_collapse))) {
        mean(sub$sigma_collapse, na.rm = TRUE)
      } else {
        NA_real_
      },
      frac_runaway = if (any(!is.na(sub$sigma_runaway))) {
        mean(sub$sigma_runaway, na.rm = TRUE)
      } else {
        NA_real_
      },
      max_abs_loading_mean = mean(sub$max_abs_loading, na.rm = TRUE),
      secs_mean = if (any(secs_ok)) mean(sub$secs[secs_ok]) else NA_real_,
      secs_median = if (any(secs_ok)) stats::median(sub$secs[secs_ok]) else NA_real_,
      secs_ratio_vs_gtmb_la = if (any(secs_ok) && is.finite(la_mean) && la_mean > 0) {
        mean(sub$secs[secs_ok]) / la_mean
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}
summ <- do.call(rbind, summ_list)
write.csv(summ, file.path(OUT, "ladder-summary.csv"), row.names = FALSE)

cat(sprintf(
  "\n======== S4 %s n-ladder (p=8 q=2; abs caps β≤0.35 / Σ≤0.50) ========\n",
  FAMILY
))
cat("NOTE: ladder evidence only — do NOT claim package PASS/FAIL.\n")
print(summ, row.names = FALSE, digits = 4)

cat("\nWrote:", file.path(OUT, "ladder-raw.csv"), "\n")
cat("Wrote:", file.path(OUT, "ladder-summary.csv"), "\n")
cat(sprintf("== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
