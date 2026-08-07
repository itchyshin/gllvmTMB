#!/usr/bin/env Rscript
## Four-arm known-truth probe (standing gllvm comparator rule 2026-08-07).
## Arms: gllvmTMB VA / gllvmTMB LA / gllvm VA / gllvm LA
## Cells: poisson + gamma; q in {2,5}; Design-110 DGP (n=120, p=8).
## Scores β RMSE and Σ rel Frobenius vs planted truth; always records wall times.
##
## Model-match caveats (document, do not paper over):
## - DGP Σ = ΛΛ' (loadings-only / unique=FALSE). Both packages' num.lv / latent
##   unique=FALSE paths are loadings-only — matched on Ψ absence.
## - gllvm family must be string "gamma" (Gamma(link="log") is rejected).
## - Gamma shape/φ parameterisation may differ; primary estimands remain β, Σ.
## - gllvm q=5 residual starts often fail; use starting.val="zero".
##
## Compute: Totoro preferred. Local ≤10 cores (PILOT_CORES). D-50: outputs stay
## under /private/tmp + Totoro; never git-stage raw CSVs.

REPO <- Sys.getenv(
  "PROBE_REPO",
  unset = "/private/tmp/gllvmtmb-va-gh-all-families"
)
OUT <- Sys.getenv(
  "PROBE_OUT",
  unset = "/private/tmp/va-gllvm-h2h-4arm-20260807"
)
CORES <- as.integer(Sys.getenv("PILOT_CORES", "8"))
CORES <- max(1L, min(CORES, as.integer(Sys.getenv("PROBE_CORE_CAP", "64"))))
N_SEED <- as.integer(Sys.getenv("PROBE_N_SEED", "8"))
SEEDS <- 91001L + seq_len(N_SEED) - 1L
QS <- as.integer(strsplit(Sys.getenv("PROBE_QS", "2,5"), ",", fixed = TRUE)[[1L]])
CELLS <- strsplit(Sys.getenv("PROBE_CELLS", "poisson,gamma"), ",", fixed = TRUE)[[1L]]
CELLS <- trimws(CELLS)
N <- 120L
P <- 8L
CAP_BETA <- 0.35
CAP_SIG <- 0.50

dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
setwd(REPO)
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(parallel)
})
stopifnot(requireNamespace("gllvm", quietly = TRUE))
cat("gllvm version:", as.character(packageVersion("gllvm")), "\n")
cat("repo:", REPO, "\n")
cat("out:", OUT, "\n")
invisible(gllvmTMB:::.va_r3_load_dll())

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

family_id_of <- function(cell) {
  switch(cell, poisson = 2L, gamma = 4L, stop("unsupported cell: ", cell))
}

family_object_of <- function(cell) {
  switch(cell, poisson = poisson(link = "log"), gamma = Gamma(link = "log"),
         stop("unsupported cell: ", cell))
}

gllvm_family_of <- function(cell) {
  ## String form required for gamma; Gamma() object is rejected by gllvm 2.0.13.
  if (identical(cell, "poisson")) "poisson" else "gamma"
}

simulate_dgp <- function(seed, q, cell, n = N, p = P) {
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
  y <- if (identical(cell, "poisson")) {
    rpois(n * p, mu)
  } else {
    rgamma(n * p, shape = 2.5, scale = as.vector(mu) / 2.5)
  }
  Y <- matrix(y, n, p)
  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(Y)),
    stringsAsFactors = FALSE
  )
  list(
    cell = cell, seed = seed, data = dat, Y = Y, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda), n = n, p = p, q = q,
    family_id = family_id_of(cell),
    shape_true = if (identical(cell, "gamma")) 2.5 else NA_real_
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

score_arm <- function(beta_hat, Sigma_hat, dgp, err = NA_character_,
                      shape_mean = NA_real_, secs = NA_real_) {
  br <- beta_rmse(beta_hat, dgp$beta)
  sr <- rel_frob(Sigma_hat, dgp$Sigma)
  list(
    ok = is.finite(br) && is.finite(sr),
    beta_rmse = br,
    sigma_rel_frob = sr,
    shape_mean = shape_mean,
    secs = secs,
    err = err
  )
}

fail_arm <- function(err, secs = NA_real_) {
  list(
    ok = FALSE, beta_rmse = NA_real_, sigma_rel_frob = NA_real_,
    shape_mean = NA_real_, secs = secs, err = err
  )
}

## ---- gllvmTMB VA (Design-110 private GH H=7 engine) -----------------------
fit_gtmb_va <- function(dgp) {
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
      H = 7L,
      eval_method = "gh",
      family_codes = rep.int(dgp$family_id, n_obs),
      link_ids = rep.int(0L, n_obs),
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
  if (inherits(result, "error")) return(fail_arm(conditionMessage(result), secs))
  fit <- wrap(
    result,
    call = match.call(),
    q = dgp$q, p = dgp$p, n = dgp$n,
    eval_method = "gh",
    family = paste0(dgp$cell, "_log"),
    link = "log",
    beta_names = colnames(X)
  )
  beta_hat <- as.numeric(
    fit$fitted$parameters[names(fit$fitted$parameters) == "beta"]
  )
  Sigma_hat <- fit$engine_result$report$Sigma_B %||%
    result$report$Sigma_B %||% NULL
  shape_hat <- NA_real_
  if (identical(dgp$cell, "gamma")) {
    lp <- as.numeric(
      fit$fitted$parameters[names(fit$fitted$parameters) == "log_phi_gamma"]
    )
    if (length(lp)) shape_hat <- mean(exp(lp))
  }
  out <- score_arm(beta_hat, Sigma_hat, dgp, shape_mean = shape_hat, secs = secs)
  if (!identical(fit$status, "healthy")) {
    out$ok <- FALSE
    out$err <- paste0("status=", fit$status %||% "NULL")
  }
  out
}

## ---- gllvmTMB Laplace (public formula API, unique=FALSE) ------------------
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
      family = family_object_of(dgp$cell),
      control = gllvmTMBcontrol(integration = "laplace", se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  secs <- proc.time()[[3L]] - t0
  if (inherits(fit, "error")) return(fail_arm(conditionMessage(fit), secs))
  beta_hat <- tryCatch(
    as.numeric(
      get(".gllvmTMB_b_fix_values", envir = asNamespace("gllvmTMB"))(fit)
    ),
    error = function(e) {
      ## Fallback: fixed-effect vector from TMB
      par <- fit$tmb_obj$env$last.par.best %||% fit$tmb_obj$par
      pl <- fit$tmb_obj$env$parList(par)
      as.numeric(pl$b_fix %||% NA)
    }
  )
  Sigma_hat <- tryCatch({
    S <- extract_Sigma(fit, level = "unit", part = "shared")
    if (is.list(S)) {
      mats <- Filter(is.matrix, S)
      if (length(mats)) mats[[1L]] else NULL
    } else {
      S
    }
  }, error = function(e) NULL)
  shape_hat <- NA_real_
  if (identical(dgp$cell, "gamma")) {
    shape_hat <- tryCatch({
      par <- fit$tmb_obj$env$last.par.best %||% fit$tmb_obj$par
      pl <- fit$tmb_obj$env$parList(par)
      mean(exp(as.numeric(pl$log_phi_gamma)))
    }, error = function(e) NA_real_)
  }
  score_arm(beta_hat, Sigma_hat, dgp, shape_mean = shape_hat, secs = secs)
}

## ---- gllvm CRAN VA / LA ---------------------------------------------------
fit_gllvm <- function(dgp, method) {
  t0 <- proc.time()[[3L]]
  f <- tryCatch(
    gllvm::gllvm(
      y = dgp$Y,
      family = gllvm_family_of(dgp$cell),
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
  if (inherits(f, "error")) return(fail_arm(conditionMessage(f), secs))
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
      sprintf("theta dim %s vs p=%d", paste(dim(L), collapse = "x"), dgp$p),
      secs
    ))
  }
  Sigma_hat <- L %*% t(L)
  shape_hat <- NA_real_
  if (identical(dgp$cell, "gamma")) {
    phi <- tryCatch(as.numeric(f$params$phi), error = function(e) NA_real_)
    if (length(phi) && all(is.finite(phi))) shape_hat <- mean(phi)
  }
  score_arm(beta_hat, Sigma_hat, dgp, shape_mean = shape_hat, secs = secs)
}

one_job <- function(seed, q, cell) {
  dgp <- simulate_dgp(seed, q, cell)
  arms <- list(
    gtmb_va = tryCatch(fit_gtmb_va(dgp), error = function(e) fail_arm(conditionMessage(e))),
    gtmb_la = tryCatch(fit_gtmb_la(dgp), error = function(e) fail_arm(conditionMessage(e))),
    gllvm_va = tryCatch(fit_gllvm(dgp, "VA"), error = function(e) fail_arm(conditionMessage(e))),
    gllvm_la = tryCatch(fit_gllvm(dgp, "LA"), error = function(e) fail_arm(conditionMessage(e)))
  )
  row <- data.frame(
    cell = cell, seed = seed, q = q, n = N, p = P,
    stringsAsFactors = FALSE
  )
  for (nm in names(arms)) {
    a <- arms[[nm]]
    row[[paste0(nm, "_ok")]] <- isTRUE(a$ok)
    row[[paste0(nm, "_beta_rmse")]] <- as.numeric(a$beta_rmse %||% NA_real_)
    row[[paste0(nm, "_sigma_rel_frob")]] <- as.numeric(a$sigma_rel_frob %||% NA_real_)
    row[[paste0(nm, "_shape_mean")]] <- as.numeric(a$shape_mean %||% NA_real_)
    row[[paste0(nm, "_secs")]] <- as.numeric(a$secs %||% NA_real_)
    row[[paste0(nm, "_err")]] <- as.character(a$err %||% NA_character_)
  }
  row
}

cat(sprintf("== warm-up %s ==\n", format(Sys.time(), "%H:%M:%S")))
wu <- tryCatch(one_job(99901L, 2L, CELLS[[1L]]), error = function(e) {
  cat("warm-up error:", conditionMessage(e), "\n"); NULL
})
if (!is.null(wu)) {
  cat("warm-up ok flags:",
      paste(sprintf("%s=%s",
                    c("gtmb_va", "gtmb_la", "gllvm_va", "gllvm_la"),
                    unlist(wu[c("gtmb_va_ok", "gtmb_la_ok", "gllvm_va_ok", "gllvm_la_ok")])),
            collapse = " "), "\n")
}

cat(sprintf("== probe start seeds=%d cores=%d cells=%s qs=%s ==\n",
            N_SEED, CORES, paste(CELLS, collapse = ","), paste(QS, collapse = ",")))

jobs <- expand.grid(
  seed = SEEDS, q = QS, cell = CELLS,
  stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
)

rows <- if (CORES <= 1L) {
  lapply(seq_len(nrow(jobs)), function(i) {
    tryCatch(
      one_job(jobs$seed[[i]], jobs$q[[i]], jobs$cell[[i]]),
      error = function(e) {
        data.frame(
          cell = jobs$cell[[i]], seed = jobs$seed[[i]], q = jobs$q[[i]],
          n = N, p = P,
          gtmb_va_ok = FALSE, gtmb_la_ok = FALSE,
          gllvm_va_ok = FALSE, gllvm_la_ok = FALSE,
          gtmb_va_beta_rmse = NA_real_, gtmb_la_beta_rmse = NA_real_,
          gllvm_va_beta_rmse = NA_real_, gllvm_la_beta_rmse = NA_real_,
          gtmb_va_sigma_rel_frob = NA_real_, gtmb_la_sigma_rel_frob = NA_real_,
          gllvm_va_sigma_rel_frob = NA_real_, gllvm_la_sigma_rel_frob = NA_real_,
          gtmb_va_shape_mean = NA_real_, gtmb_la_shape_mean = NA_real_,
          gllvm_va_shape_mean = NA_real_, gllvm_la_shape_mean = NA_real_,
          gtmb_va_secs = NA_real_, gtmb_la_secs = NA_real_,
          gllvm_va_secs = NA_real_, gllvm_la_secs = NA_real_,
          gtmb_va_err = conditionMessage(e), gtmb_la_err = NA_character_,
          gllvm_va_err = NA_character_, gllvm_la_err = NA_character_,
          stringsAsFactors = FALSE
        )
      }
    )
  })
} else {
  mclapply(seq_len(nrow(jobs)), function(i) {
    tryCatch(
      one_job(jobs$seed[[i]], jobs$q[[i]], jobs$cell[[i]]),
      error = function(e) {
        data.frame(
          cell = jobs$cell[[i]], seed = jobs$seed[[i]], q = jobs$q[[i]],
          n = N, p = P,
          gtmb_va_ok = FALSE, gtmb_la_ok = FALSE,
          gllvm_va_ok = FALSE, gllvm_la_ok = FALSE,
          gtmb_va_beta_rmse = NA_real_, gtmb_la_beta_rmse = NA_real_,
          gllvm_va_beta_rmse = NA_real_, gllvm_la_beta_rmse = NA_real_,
          gtmb_va_sigma_rel_frob = NA_real_, gtmb_la_sigma_rel_frob = NA_real_,
          gllvm_va_sigma_rel_frob = NA_real_, gllvm_la_sigma_rel_frob = NA_real_,
          gtmb_va_shape_mean = NA_real_, gtmb_la_shape_mean = NA_real_,
          gllvm_va_shape_mean = NA_real_, gllvm_la_shape_mean = NA_real_,
          gtmb_va_secs = NA_real_, gtmb_la_secs = NA_real_,
          gllvm_va_secs = NA_real_, gllvm_la_secs = NA_real_,
          gtmb_va_err = conditionMessage(e), gtmb_la_err = NA_character_,
          gllvm_va_err = NA_character_, gllvm_la_err = NA_character_,
          stringsAsFactors = FALSE
        )
      }
    )
  }, mc.cores = CORES, mc.preschedule = FALSE)
}

out <- do.call(rbind, rows)
write.csv(out, file.path(OUT, "seed-rows.csv"), row.names = FALSE)

arm_names <- c("gtmb_va", "gtmb_la", "gllvm_va", "gllvm_la")

summarise_cell_q <- function(cc, qq) {
  sub <- out[out$cell == cc & out$q == qq, , drop = FALSE]
  row <- data.frame(
    cell = cc, q = qq, n_seed = nrow(sub),
    stringsAsFactors = FALSE
  )
  for (nm in arm_names) {
    br <- sub[[paste0(nm, "_beta_rmse")]]
    sr <- sub[[paste0(nm, "_sigma_rel_frob")]]
    secs <- sub[[paste0(nm, "_secs")]]
    fin <- is.finite(br) & is.finite(sr)
    row[[paste0(nm, "_n_ok")]] <- sum(fin)
    row[[paste0(nm, "_beta_rmse")]] <- if (any(fin)) mean(br[fin]) else NA_real_
    row[[paste0(nm, "_sigma_rel_frob")]] <- if (any(fin)) mean(sr[fin]) else NA_real_
    row[[paste0(nm, "_frac_sigma_gt_0.5")]] <- if (any(fin)) mean(sr[fin] > CAP_SIG) else NA_real_
    row[[paste0(nm, "_pass_abs")]] <- if (any(fin)) {
      mean(br[fin] <= CAP_BETA & sr[fin] <= CAP_SIG)
    } else {
      NA_real_
    }
    row[[paste0(nm, "_secs_mean")]] <- mean(secs, na.rm = TRUE)
    row[[paste0(nm, "_shape_mean")]] <- mean(sub[[paste0(nm, "_shape_mean")]], na.rm = TRUE)
  }
  row
}

summ <- do.call(
  rbind,
  lapply(CELLS, function(cc) do.call(rbind, lapply(QS, function(qq) summarise_cell_q(cc, qq))))
)
write.csv(summ, file.path(OUT, "summary.csv"), row.names = FALSE)

## Long form for easy reading / plotting
long_rows <- list()
for (nm in arm_names) {
  long_rows[[nm]] <- data.frame(
    cell = out$cell,
    seed = out$seed,
    q = out$q,
    arm = nm,
    ok = out[[paste0(nm, "_ok")]],
    beta_rmse = out[[paste0(nm, "_beta_rmse")]],
    sigma_rel_frob = out[[paste0(nm, "_sigma_rel_frob")]],
    shape_mean = out[[paste0(nm, "_shape_mean")]],
    secs = out[[paste0(nm, "_secs")]],
    err = out[[paste0(nm, "_err")]],
    stringsAsFactors = FALSE
  )
}
long <- do.call(rbind, long_rows)
write.csv(long, file.path(OUT, "seed-rows-long.csv"), row.names = FALSE)

cat("\n======== 4-ARM SUMMARY (Design-110 DGP; abs caps β≤0.35 / Σ≤0.50) ========\n")
## Compact print: key columns only
keep <- c(
  "cell", "q", "n_seed",
  "gtmb_va_n_ok", "gtmb_va_beta_rmse", "gtmb_va_sigma_rel_frob", "gtmb_va_secs_mean",
  "gtmb_la_n_ok", "gtmb_la_beta_rmse", "gtmb_la_sigma_rel_frob", "gtmb_la_secs_mean",
  "gllvm_va_n_ok", "gllvm_va_beta_rmse", "gllvm_va_sigma_rel_frob", "gllvm_va_secs_mean",
  "gllvm_la_n_ok", "gllvm_la_beta_rmse", "gllvm_la_sigma_rel_frob", "gllvm_la_secs_mean"
)
print(summ[, intersect(keep, names(summ)), drop = FALSE], row.names = FALSE, digits = 4)

cat("\n======== gllvm PERFORMANCE (secs mean; always report) ========\n")
perf <- summ[, c(
  "cell", "q",
  "gllvm_va_n_ok", "gllvm_va_secs_mean", "gllvm_va_beta_rmse", "gllvm_va_sigma_rel_frob",
  "gllvm_la_n_ok", "gllvm_la_secs_mean", "gllvm_la_beta_rmse", "gllvm_la_sigma_rel_frob"
), drop = FALSE]
print(perf, row.names = FALSE, digits = 4)

cat("\nWrote:", file.path(OUT, "seed-rows.csv"), "\n")
cat("Wrote:", file.path(OUT, "seed-rows-long.csv"), "\n")
cat("Wrote:", file.path(OUT, "summary.csv"), "\n")
cat(sprintf("== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
