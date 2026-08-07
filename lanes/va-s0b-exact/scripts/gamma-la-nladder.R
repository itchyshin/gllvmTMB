#!/usr/bin/env Rscript
## Gamma LA n-ladder: does larger n rescue Laplace health on Design-110 gamma_log?
## Local: CORES <= 10. Totoro (HOST=Totoro / TOTORO=1): CORES <= 150.
## Reuse Gate-E/runtime 022b4eab checkout when REPO points at campaign checkout.
## No fence edits. Scores healthy / |g| / Sigma rel Frob; optional VA + gllvm.
## Dual scientific interest (note only; Arc-2 unchanged): VA ≤/≥ LA vs planted truth.

REPO <- Sys.getenv("REPO", "/private/tmp/gllvmtmb-va-gh-all-families")
OUT  <- Sys.getenv(
  "OUT",
  file.path(REPO, "lanes/va-s0b-exact/results/gamma-la-nladder-20260807")
)
HOST <- Sys.getenv("HOST", Sys.getenv("TOTORO", "local"))
on_totoro <- identical(tolower(HOST), "totoro") || identical(Sys.getenv("TOTORO"), "1")
max_cores <- if (on_totoro) 150L else 10L
default_cores <- if (on_totoro) 48L else 10L
CORES <- as.integer(Sys.getenv("CORES", as.character(default_cores)))
if (is.na(CORES) || CORES < 1L || CORES > max_cores) {
  stop("CORES must be in 1..", max_cores, " for host=", HOST, " (got ", CORES, ")")
}

N_GRID <- as.integer(strsplit(Sys.getenv("N_GRID", "120,250,500,1000"), ",")[[1]])
QS <- as.integer(strsplit(Sys.getenv("QS", "2"), ",")[[1]])
N_SEED <- as.integer(Sys.getenv("N_SEED", "6"))
SEEDS <- as.integer(Sys.getenv("SEED0", "92001")) + seq_len(N_SEED) - 1L
P <- as.integer(Sys.getenv("P", "8"))
DO_VA <- identical(Sys.getenv("DO_VA", "1"), "1")
DO_GLLVM <- identical(Sys.getenv("DO_GLLVM", "1"), "1")
PHASE <- Sys.getenv("PHASE", "full")  # smoke | full
GLLVMTMB_LIB <- Sys.getenv("GLLVMTMB_LIB", "")

Sys.setenv(
  OPENBLAS_NUM_THREADS = "1",
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1"
)

dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  if (nzchar(GLLVMTMB_LIB)) {
    .libPaths(c(GLLVMTMB_LIB, .libPaths()))
    library(gllvmTMB)
  } else {
    devtools::load_all(".", quiet = TRUE)
  }
  library(parallel)
})
has_gllvm <- requireNamespace("gllvm", quietly = TRUE)
if (DO_GLLVM && !has_gllvm) {
  message("gllvm not installed; skipping gllvm arm")
  DO_GLLVM <- FALSE
}
if (DO_VA) invisible(gllvmTMB:::.va_r3_load_dll())
cat(sprintf(
  "host=%s cores=%d/%d repo=%s gllvm=%s lib=%s\n",
  if (on_totoro) "Totoro" else "local", CORES, max_cores, REPO,
  DO_GLLVM, if (nzchar(GLLVMTMB_LIB)) GLLVMTMB_LIB else "(load_all)"
))

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

rel_frob <- function(Shat, Strue) {
  if (!is.matrix(Shat) || !identical(dim(Shat), dim(Strue))) return(NA_real_)
  sqrt(sum((Shat - Strue)^2)) / sqrt(sum(Strue^2))
}

simulate_gamma <- function(seed, q, n, p = P) {
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
  mu <- exp(eta)
  y <- rgamma(n * p, shape = 2.5, scale = as.vector(mu) / 2.5)
  Y <- matrix(y, n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    data = dat, Y = Y, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda), n = n, p = p, q = q, seed = seed
  )
}

laplace_health <- function(fit, gradient_tolerance = 1e-3) {
  convergence <- as.integer(fit$opt$convergence %||% NA_integer_)
  objective <- as.numeric(fit$opt$objective %||% NA_real_)
  pd_hessian <- isTRUE(fit$sd_report$pdHess)
  ## FE-only: `obj$gr()` matches `opt$par` / `lfixed()`, not FE+RE
  ## `last.par.best` (campaign bug that zeroed Gamma LA healthy rates).
  gradient <- tryCatch({
    par <- fit$opt$par %||% fit$tmb_obj$par
    max(abs(fit$tmb_obj$gr(par)))
  }, error = function(e) Inf)
  healthy <- identical(convergence, 0L) && is.finite(objective) &&
    pd_hessian && is.finite(gradient) && gradient < gradient_tolerance
  list(
    healthy = healthy, convergence = convergence, objective = objective,
    pd_hessian = pd_hessian, max_gradient = as.numeric(gradient),
    gradient_tolerance = gradient_tolerance
  )
}

fit_la <- function(dgp) {
  form <- as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
    dgp$q
  ))
  control <- gllvmTMBcontrol(integration = "laplace", se = TRUE)
  t0 <- proc.time()[[3L]]
  fit <- tryCatch(
    gllvmTMB(
      form, data = dgp$data, unit = "unit", family = Gamma(link = "log"),
      control = control, silent = TRUE
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) {
    return(list(
      arm = "gtmb_la", ok = FALSE, healthy = FALSE, elapsed = elapsed,
      conv = NA_integer_, pdHess = NA, max_g = NA_real_,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      err = conditionMessage(fit)
    ))
  }
  h <- laplace_health(fit)
  bhat <- tryCatch(
    as.numeric(gllvmTMB:::.gllvmTMB_b_fix_values(fit)),
    error = function(e) rep(NA_real_, dgp$p)
  )
  Shat <- tryCatch({
    S <- gllvmTMB::extract_Sigma(fit, level = "unit", part = "shared")
    if (is.list(S)) {
      mats <- Filter(is.matrix, S)
      if (length(mats)) mats[[1L]] else NULL
    } else S
  }, error = function(e) NULL)
  list(
    arm = "gtmb_la", ok = TRUE, healthy = isTRUE(h$healthy), elapsed = elapsed,
    conv = h$convergence, pdHess = isTRUE(h$pd_hessian), max_g = h$max_gradient,
    beta_rmse = sqrt(mean((bhat - dgp$beta)^2)),
    sigma_rel_frob = rel_frob(Shat, dgp$Sigma),
    err = NA_character_
  )
}

fit_va <- function(dgp) {
  ns <- asNamespace("gllvmTMB")
  engine <- get(".approximation_engine_va_r3_fit", envir = ns)
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  t0 <- proc.time()[[3L]]
  result <- tryCatch(
    engine(
      y = dat$value, n_trials = rep.int(1, n_obs), X = X,
      unit_id = as.integer(dat$unit), trait_id = as.integer(dat$trait),
      q = dgp$q, N = dgp$n, T = dgp$p, H = 7L, eval_method = "gh",
      family_codes = rep.int(4L, n_obs), link_ids = rep.int(0L, n_obs),
      n_ordinal_cuts_per_trait = integer(dgp$p),
      ordinal_offset_per_trait = integer(dgp$p),
      ordinal_log_increments_start = numeric(),
      fixed_tweedie_power = NULL, fixed_student_df = NULL,
      match_laplace_residual_sd = FALSE, silent = TRUE
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[[3L]] - t0
  if (inherits(result, "error")) {
    return(list(
      arm = "gtmb_va", ok = FALSE, healthy = FALSE, elapsed = elapsed,
      conv = NA_integer_, pdHess = NA, max_g = NA_real_,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      err = conditionMessage(result)
    ))
  }
  beta_hat <- as.numeric(
    result$fitted$parameters[names(result$fitted$parameters) == "beta"]
  )
  Sigma_hat <- result$engine_result$report$Sigma_B %||%
    result$report$Sigma_B %||% NULL
  healthy <- identical(result$status, "healthy") ||
    identical(result$engine_result$status, "healthy")
  max_g <- as.numeric(
    result$diagnostics$max_abs_gradient %||%
      result$engine_result$diagnostics$max_abs_gradient %||% NA_real_
  )
  list(
    arm = "gtmb_va", ok = TRUE, healthy = isTRUE(healthy), elapsed = elapsed,
    conv = NA_integer_, pdHess = NA, max_g = max_g,
    beta_rmse = sqrt(mean((beta_hat - dgp$beta)^2)),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    err = NA_character_
  )
}

fit_gllvm <- function(dgp, method = c("LA", "VA")) {
  method <- match.arg(method)
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y, family = "gamma", num.lv = dgp$q, method = method,
      sd.errors = FALSE, seed = as.integer(dgp$seed), trace = FALSE,
      control.start = list(starting.val = "zero", n.init = 1)
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[[3L]] - t0
  arm <- paste0("gllvm_", tolower(method))
  if (inherits(f, "error")) {
    return(list(
      arm = arm, ok = FALSE, healthy = FALSE, elapsed = elapsed,
      conv = NA_integer_, pdHess = NA, max_g = NA_real_,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      err = conditionMessage(f)
    ))
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
  Sigma_hat <- if (nrow(L) == dgp$p) L %*% t(L) else NULL
  conv <- tryCatch(as.integer(f$convergence), error = function(e) NA_integer_)
  list(
    arm = arm, ok = TRUE,
    healthy = isTRUE(conv == 0L) || isTRUE(isTRUE(f$convergence)),
    elapsed = elapsed, conv = conv, pdHess = NA, max_g = NA_real_,
    beta_rmse = sqrt(mean((beta_hat - dgp$beta)^2)),
    sigma_rel_frob = rel_frob(Sigma_hat, dgp$Sigma),
    err = NA_character_
  )
}

row_from <- function(res, meta) {
  data.frame(
    phase = PHASE, cell = "gamma_log", seed = meta$seed, q = meta$q,
    n = meta$n, p = meta$p, arm = res$arm,
    ok = isTRUE(res$ok), healthy = isTRUE(res$healthy),
    elapsed = as.numeric(res$elapsed),
    conv = as.integer(res$conv %||% NA_integer_),
    pdHess = as.logical(res$pdHess %||% NA),
    max_g = as.numeric(res$max_g %||% NA_real_),
    beta_rmse = as.numeric(res$beta_rmse %||% NA_real_),
    sigma_rel_frob = as.numeric(res$sigma_rel_frob %||% NA_real_),
    err = as.character(res$err %||% NA_character_),
    stringsAsFactors = FALSE
  )
}

one_cell <- function(seed, q, n) {
  dgp <- simulate_gamma(seed, q, n)
  meta <- list(seed = seed, q = q, n = n, p = P)
  rows <- list(row_from(fit_la(dgp), meta))
  if (DO_VA) rows[[length(rows) + 1L]] <- row_from(fit_va(dgp), meta)
  if (DO_GLLVM) {
    rows[[length(rows) + 1L]] <- row_from(fit_gllvm(dgp, "LA"), meta)
    rows[[length(rows) + 1L]] <- row_from(fit_gllvm(dgp, "VA"), meta)
  }
  do.call(rbind, rows)
}

if (identical(PHASE, "smoke")) {
  cat(sprintf("SMOKE cores=%d n=120 q=2 seed=%d\n", CORES, SEEDS[[1]]))
  r <- one_cell(SEEDS[[1]], 2L, 120L)
  print(r[, c("arm", "healthy", "max_g", "sigma_rel_frob", "elapsed", "err")])
  write.csv(r, file.path(OUT, "smoke.csv"), row.names = FALSE)
  quit(save = "no", status = 0)
}

grid <- expand.grid(seed = SEEDS, q = QS, n = N_GRID, KEEP.OUT.ATTRS = FALSE)
cat(sprintf(
  "FULL cores=%d jobs=%d seeds=%d n={%s} q={%s} VA=%s gllvm=%s\n",
  CORES, nrow(grid), N_SEED, paste(N_GRID, collapse = ","),
  paste(QS, collapse = ","), DO_VA, DO_GLLVM
))

run_one <- function(i) {
  one_cell(grid$seed[[i]], as.integer(grid$q[[i]]), as.integer(grid$n[[i]]))
}

t_wall0 <- proc.time()[[3L]]
if (CORES == 1L) {
  parts <- lapply(seq_len(nrow(grid)), run_one)
} else {
  parts <- mclapply(seq_len(nrow(grid)), run_one, mc.cores = CORES)
}
bad <- vapply(parts, inherits, logical(1), what = "try-error")
if (any(bad)) {
  message("failures: ", sum(bad))
  parts[bad] <- lapply(which(bad), function(i) {
    data.frame(
      phase = PHASE, cell = "gamma_log", seed = grid$seed[[i]], q = grid$q[[i]],
      n = grid$n[[i]], p = P, arm = "ERROR", ok = FALSE, healthy = FALSE,
      elapsed = NA_real_, conv = NA_integer_, pdHess = NA, max_g = NA_real_,
      beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
      err = as.character(parts[[i]]), stringsAsFactors = FALSE
    )
  })
}
out <- do.call(rbind, parts)
wall <- proc.time()[[3L]] - t_wall0
write.csv(out, file.path(OUT, "ladder-raw.csv"), row.names = FALSE)

tab <- do.call(rbind, lapply(unique(out$arm), function(a) {
  do.call(rbind, lapply(QS, function(qq) {
    do.call(rbind, lapply(N_GRID, function(nn) {
      x <- out[out$arm == a & out$q == qq & out$n == nn, ]
      # |g| and abs Σ scored on completed fits (ok); healthy_rate separate
      done <- x[isTRUE(x$ok) | x$ok %in% TRUE, , drop = FALSE]
      if (!nrow(done)) done <- x[FALSE, , drop = FALSE]
      data.frame(
        arm = a, q = qq, n = nn, n_fit = nrow(x),
        n_ok = sum(x$ok, na.rm = TRUE),
        healthy_rate = mean(x$healthy, na.rm = TRUE),
        n_healthy = sum(x$healthy, na.rm = TRUE),
        med_max_g = median(done$max_g, na.rm = TRUE),
        med_sigma = median(done$sigma_rel_frob, na.rm = TRUE),
        med_beta_rmse = median(done$beta_rmse, na.rm = TRUE),
        med_elapsed = median(x$elapsed, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    }))
  }))
}))
write.csv(tab, file.path(OUT, "ladder-summary.csv"), row.names = FALSE)
cat(sprintf("\nWall seconds: %.1f\n", wall))
cat("NOTE: dual criterion interest VA vs LA vs truth recorded; Arc-2 unchanged.\n")
print(tab)
saveRDS(
  list(
    raw = out, summary = tab, wall = wall, cores = CORES,
    note = "dual_VA_LA_truth_interest; Arc-2 unchanged; Gate-E 022b4eab"
  ),
  file.path(OUT, "ladder.rds")
)
