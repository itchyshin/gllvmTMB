#!/usr/bin/env Rscript
## dev/three-engine-demo.R
##
## GAUSS TASK: a small, honest DEMONSTRATION comparing three engines on
## Bernoulli-logit data with KNOWN truth (Lambda_true / Sigma_true = Lambda Lambda^T):
##
##   A) gllvmTMB Laplace  -- the production route, via the public gllvmTMB()
##      entry point, formula path `latent(1 | site, d = q, unique = FALSE)`.
##      `gllvmTMB_wide()` CANNOT suppress the Psi diagonal and is therefore
##      NOT a matched comparator here -- a known trap, avoided by construction.
##   B) gllvmTMB VA        -- our internal engine, via
##      gllvmTMB:::.approximation_engine_fit(engine = "va_r3", ...).
##      eval_method = "auto" resolves to "jj" for binomial (the current
##      family-adaptive default, commit 51d1fa81), so this is what a caller
##      gets by default, not a bound-isolation exercise.
##   C) gllvm's own VA/EVA -- gllvm::gllvm(), method = "VA" (gllvm silently
##      falls back to its extended/EVA variant for families where plain VA
##      is not implemented; we record whatever gllvm itself reports).
##
## This is a DEMONSTRATION, not a validation study: one DGP, 5 seeds, 2 n
## cells. See dev/three-engine-demo.md for the full honesty section.
##
## Provenance: the simulate/fit-arm pattern (DGP, rel_frobenius,
## attenuation_ratio, the gllvm Lambda_hat = theta %*% diag(sigma.lv)
## reconstruction, and the va_r3 4-start fairness match on gllvm's
## control.start) is reused from dev/controlled-gh-vs-jj.R (this repo,
## same session lineage). Internal research only. No @export, no
## testthat. Never call an ELBO a likelihood.

suppressPackageStartupMessages({
  library(stats)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath(getwd(), mustWork = TRUE)
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
if (!requireNamespace("gllvm", quietly = TRUE)) {
  stop("This script requires the gllvm package for the C-arm comparator.", call. = FALSE)
}
if (!requireNamespace("numDeriv", quietly = TRUE)) {
  stop("This script requires numDeriv for the profile-Hessian degeneracy check.", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))
source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
va_eva_source_private_engines(root, envir = .GlobalEnv)

# ---------------------------------------------------------------------------
# Data-generating process: Bernoulli-logit, q = 2, known Lambda_true/beta_true.
# Identical DGP to dev/controlled-gh-vs-jj.R / dev/bound-vs-estimates-recovery.R
# for continuity.
# ---------------------------------------------------------------------------
simulate_bernoulli_gllvm <- function(n_units, n_traits, q, seed,
                                     lambda_sd = 0.7, beta_sd = 0.3) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  Lambda_true <- matrix(rnorm(n_traits * q, sd = lambda_sd), n_traits, q,
                        dimnames = list(trait_names, paste0("LV", seq_len(q))))
  beta_true <- rnorm(n_traits, mean = 0, sd = beta_sd)
  Z_true <- matrix(rnorm(n_units * q), n_units, q)
  eta <- matrix(beta_true, n_units, n_traits, byrow = TRUE) + Z_true %*% t(Lambda_true)
  Y <- matrix(rbinom(n_units * n_traits, size = 1, prob = plogis(eta)),
             n_units, n_traits, dimnames = list(NULL, trait_names))
  Sigma_true <- Lambda_true %*% t(Lambda_true)
  list(Y = Y, Lambda_true = Lambda_true, beta_true = beta_true,
       Sigma_true = Sigma_true, trait_names = trait_names,
       n_units = n_units, n_traits = n_traits, q = q, seed = seed)
}

rel_frobenius <- function(Sigma_hat, Sigma_true) {
  norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")
}
attenuation_ratio <- function(Sigma_hat, Sigma_true) {
  sum(diag(Sigma_hat)) / sum(diag(Sigma_true))
}

# ---------------------------------------------------------------------------
# Independent degeneracy check shared by all three arms: a PROFILE Hessian
# restricted to the "global" structural parameters (regression intercepts +
# loadings), holding every per-unit/per-observation parameter fixed at its
# reported optimum. For Laplace this is much cruder than TMB's own pdHess
## (which is the properly Laplace-integrated marginal Hessian of the fixed
## effects); for the two VA engines it is the best available check without
## touching R/src, because neither engine declares a random/fixed TMB split
## -- every per-unit variational parameter is nominally "fixed" to TMB, so a
## naive full joint Hessian would be enormous and would NOT equal a profile
## Hessian either. Restricting to the global block and holding the rest at
## the optimum is a genuinely weaker check than Laplace's pdHess (it ignores
## curvature coupling to the per-unit block) -- see the honesty section in
## the companion .md. Sign only (min eigenvalue > 0) is reported, never a
## magnitude, because the three objectives (profiled Laplace likelihood,
## GH/JJ ELBO, gllvm's own VA objective) are not on a comparable numeric scale.
.profile_hessian_min_eig <- function(fn, par_full, idx) {
  if (!length(idx)) {
    return(NA_real_)
  }
  sub_fn <- function(g) {
    p <- par_full
    p[idx] <- g
    fn(p)
  }
  H <- tryCatch(numDeriv::hessian(sub_fn, par_full[idx]), error = function(e) NULL)
  if (is.null(H) || !all(is.finite(H))) {
    return(NA_real_)
  }
  eig <- tryCatch(eigen(H, symmetric = TRUE, only.values = TRUE)$values,
                  error = function(e) NA_real_)
  min(eig)
}

# ---------------------------------------------------------------------------
# Arm A: gllvmTMB Laplace, Psi-suppressed matched comparator.
# Two variants per seed: se = FALSE (point-only timing) and se = TRUE
# (canonical run: recovery, convergence honesty, point+SE timing).
# ---------------------------------------------------------------------------
fit_arm_A <- function(sim, se) {
  n <- sim$n_units; q <- sim$q
  df <- as.data.frame(sim$Y)
  df$site <- factor(seq_len(n))
  fml <- stats::as.formula(paste0(
    "traits(", paste(sim$trait_names, collapse = ", "), ") ~ 1 + latent(1 | site, d = ",
    q, ", unique = FALSE)"
  ))
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvmTMB(fml, data = df, family = stats::binomial(),
            control = gllvmTMBcontrol(se = se)),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  base <- list(ok = FALSE, error = NA_character_, elapsed = elapsed,
              opt_convergence = NA_integer_, pdHess = NA, grad_max = NA_real_,
              hess_min_eig = NA_real_, rel_frob = NA_real_, atten = NA_real_,
              Lambda_hat = NULL, Sigma_hat = NULL)
  if (inherits(fit, "arm_error")) {
    base$error <- fit$error_message
    return(base)
  }
  base$opt_convergence <- fit$opt$convergence
  ## Gradient of the fixed-effect (Laplace-profiled) parameter block is
  ## available regardless of whether sdreport ran.
  base$grad_max <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))),
                            error = function(e) NA_real_)
  if (isTRUE(se)) {
    base$pdHess <- fit$sd_report$pdHess %||% NA
  }
  Sigma_out <- tryCatch(extract_Sigma_B(fit), error = function(e) NULL)
  ord <- tryCatch(extract_ordination(fit, level = "unit"),
                  error = function(e) NULL)
  if (is.null(Sigma_out) || is.null(ord) || is.null(ord$loadings)) {
    base$error <- "no Sigma_B / loadings extractable"
    return(base)
  }
  base$ok <- TRUE
  base$Sigma_hat <- Sigma_out$Sigma_B
  base$Lambda_hat <- ord$loadings
  base$rel_frob <- rel_frobenius(base$Sigma_hat, sim$Sigma_true)
  base$atten <- attenuation_ratio(base$Sigma_hat, sim$Sigma_true)
  base
}

# ---------------------------------------------------------------------------
# Arm B: gllvmTMB VA (va_r3), eval_method = "auto" (-> "jj" for binomial).
# No SE machinery exists for this engine -- a structural gap, recorded as
# such, never faked.
# ---------------------------------------------------------------------------
fit_arm_B <- function(sim) {
  n <- sim$n_units; p <- sim$n_traits; q <- sim$q
  long <- data.frame(
    unit = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(sim$trait_names, each = n), levels = sim$trait_names),
    value = as.vector(sim$Y)
  )
  X <- stats::model.matrix(~ 0 + trait, long)
  unit_id <- as.integer(long$unit)
  trait_id <- as.integer(long$trait)
  y <- long$value
  n_trials <- rep(1L, length(y))

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    .approximation_engine_fit(
      engine = "va_r3", y = y, n_trials = n_trials, X = X,
      unit_id = unit_id, trait_id = trait_id, q = q,
      family = "binomial", link = "logit", H = 15L, silent = TRUE,
      eval_method = "auto"
    ),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  base <- list(ok = FALSE, error = NA_character_, elapsed = elapsed,
              status = NA_character_, health_admitted = NA, grad_max = NA_real_,
              hess_min_eig = NA_real_, rel_frob = NA_real_, atten = NA_real_,
              Lambda_hat = NULL, Sigma_hat = NULL, se_available = FALSE)
  if (inherits(fit, "arm_error")) {
    base$error <- fit$error_message
    return(base)
  }
  raw <- fit$engine_result
  base$status <- fit$status %||% NA_character_
  base$health_admitted <- raw$health$admitted %||% NA
  base$grad_max <- raw$best$max_abs_gradient %||% NA_real_
  Lambda_hat <- raw$report$Lambda
  Sigma_hat <- raw$report$Sigma_B
  if (is.null(Lambda_hat) || is.null(Sigma_hat)) {
    base$error <- "no Lambda/Sigma_B in report"
    return(base)
  }
  ## Profile-Hessian degeneracy check on the global block (beta, theta_rr),
  ## holding the per-unit variational parameters fixed at the optimum.
  nm <- names(raw$best$par)
  global_idx <- which(nm %in% c("beta", "theta_rr"))
  base$hess_min_eig <- .profile_hessian_min_eig(raw$objective$fn, raw$best$par, global_idx)
  base$ok <- TRUE
  base$Lambda_hat <- Lambda_hat
  base$Sigma_hat <- Sigma_hat
  base$rel_frob <- rel_frobenius(Sigma_hat, sim$Sigma_true)
  base$atten <- attenuation_ratio(Sigma_hat, sim$Sigma_true)
  base
}

# ---------------------------------------------------------------------------
# Arm C: gllvm::gllvm(). n.init = 4 / jitter.var = 0.2 matches va_r3's
# internal 4-start search (fairness fix from dev/controlled-gh-vs-jj.R --
# gllvm's own default n.init = 1 reliably diverges to degenerate loadings on
# Bernoulli-logit VA). Two variants per seed: sd.errors = FALSE (point-only
# timing) and sd.errors = TRUE (canonical: recovery, convergence honesty,
# point+SE timing).
# ---------------------------------------------------------------------------
fit_arm_C <- function(sim, sd.errors) {
  q <- sim$q
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvm::gllvm(y = sim$Y, family = "binomial", link = "logit",
                num.lv = q, method = "VA", sd.errors = sd.errors,
                seed = sim$seed,
                control.start = list(n.init = 4, jitter.var = 0.2)),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0
  base <- list(ok = FALSE, error = NA_character_, elapsed = elapsed,
              convergence = NA, method_used = NA_character_, sd_ok = NA,
              grad_max = NA_real_, hess_min_eig = NA_real_,
              rel_frob = NA_real_, atten = NA_real_,
              Lambda_hat = NULL, Sigma_hat = NULL)
  if (inherits(fit, "arm_error")) {
    base$error <- fit$error_message
    return(base)
  }
  base$convergence <- isTRUE(fit$convergence)
  base$method_used <- fit$method %||% NA_character_
  if (isTRUE(sd.errors)) {
    base$sd_ok <- !is.null(fit$sd) && !anyNA(unlist(fit$sd))
  }
  base$grad_max <- tryCatch(max(abs(fit$TMBfn$gr(fit$TMBfn$par))),
                            error = function(e) NA_real_)
  theta <- fit$params$theta
  sigma_lv <- fit$params$sigma.lv
  if (is.null(theta)) {
    base$error <- "no params$theta in fit"
    return(base)
  }
  ## gllvm's theta carries a fixed identifiability constraint; sigma.lv
  ## rescales each latent axis. Fitted linear-predictor loading is
  ## theta %*% diag(sigma.lv). See dev/bound-vs-estimates.md pitfall #1.
  Lambda_hat <- if (!is.null(sigma_lv)) theta %*% diag(sigma_lv, nrow = q, ncol = q) else theta
  Sigma_hat <- Lambda_hat %*% t(Lambda_hat)
  ## Profile-Hessian degeneracy check on the global block (b, lambda, sigmaLV).
  nm <- names(fit$TMBfn$par)
  global_idx <- which(nm %in% c("b", "lambda", "sigmaLV"))
  base$hess_min_eig <- .profile_hessian_min_eig(fit$TMBfn$fn, fit$TMBfn$par, global_idx)
  base$ok <- TRUE
  base$Lambda_hat <- Lambda_hat
  base$Sigma_hat <- Sigma_hat
  base$rel_frob <- rel_frobenius(Sigma_hat, sim$Sigma_true)
  base$atten <- attenuation_ratio(Sigma_hat, sim$Sigma_true)
  base
}

# ---------------------------------------------------------------------------
# SMOKE FIRST: one tiny cell, one seed, all arms, confirm real non-NA output.
# ---------------------------------------------------------------------------
cat("=== SMOKE TEST (n=30, p=6, q=2, seed=1) ===\n")
smoke <- simulate_bernoulli_gllvm(30L, 6L, 2L, seed = 1L)
smoke_A <- fit_arm_A(smoke, se = TRUE)
cat(sprintf("A: ok=%s rel_frob=%s pdHess=%s grad_max=%s\n",
           smoke_A$ok, smoke_A$rel_frob, smoke_A$pdHess, smoke_A$grad_max))
smoke_B <- fit_arm_B(smoke)
cat(sprintf("B: ok=%s rel_frob=%s health=%s grad_max=%s hess_min_eig=%s\n",
           smoke_B$ok, smoke_B$rel_frob, smoke_B$health_admitted, smoke_B$grad_max,
           smoke_B$hess_min_eig))
smoke_C <- fit_arm_C(smoke, sd.errors = TRUE)
cat(sprintf("C: ok=%s rel_frob=%s convergence=%s method=%s hess_min_eig=%s\n",
           smoke_C$ok, smoke_C$rel_frob, smoke_C$convergence, smoke_C$method_used,
           smoke_C$hess_min_eig))
if (!isTRUE(smoke_A$ok) || !isTRUE(smoke_B$ok) || !isTRUE(smoke_C$ok)) {
  stop("Smoke test failed: at least one arm did not return a usable fit. ",
       "Aborting before scaling up -- see the printed diagnostics above.",
       call. = FALSE)
}
cat("Smoke test passed for all three arms.\n\n")

# ---------------------------------------------------------------------------
# Main grid: n in {150, 400}, 8 traits, q = 2, 5 seeds. Interleaved A/B/C
# order within each seed (never all of one arm's reps before another's) so
# no single arm is unfairly penalised by a within-session first-fit cost.
# ---------------------------------------------------------------------------
cells <- list(
  list(n_units = 150L, n_traits = 8L),
  list(n_units = 400L, n_traits = 8L)
)
q <- 2L
n_seeds <- 5L
base_seed <- 20260727L

recovery_rows <- list()
timing_rows <- list()
row_i <- 0L
trow_i <- 0L

for (cell in cells) {
  for (rep_idx in seq_len(n_seeds)) {
    seed <- base_seed + rep_idx * 1000L + cell$n_units
    cat(sprintf("[n=%d p=%d seed=%d] simulating...\n", cell$n_units, cell$n_traits, seed))
    sim <- simulate_bernoulli_gllvm(cell$n_units, cell$n_traits, q, seed)

    ## --- point-only timing pass (A, C) + point-only fit (B has no SE) ---
    A_pt <- fit_arm_A(sim, se = FALSE)
    B_res <- fit_arm_B(sim)
    C_pt <- fit_arm_C(sim, sd.errors = FALSE)

    ## --- canonical pass (A, C): recovery + convergence honesty + point+SE timing ---
    A_se <- fit_arm_A(sim, se = TRUE)
    C_se <- fit_arm_C(sim, sd.errors = TRUE)

    cl_A <- if (isTRUE(A_se$ok)) compare_loadings(A_se$Lambda_hat, sim$Lambda_true) else NULL
    cl_B <- if (isTRUE(B_res$ok)) compare_loadings(B_res$Lambda_hat, sim$Lambda_true) else NULL
    cl_C <- if (isTRUE(C_se$ok)) compare_loadings(C_se$Lambda_hat, sim$Lambda_true) else NULL

    cat(sprintf("  A (Laplace): ok=%s rel_frob=%.3f atten=%.3f pdHess=%s grad_max=%.2e hess_min_eig=%s t_pt=%.2fs t_se=%.2fs\n",
               A_se$ok, A_se$rel_frob, A_se$atten, A_se$pdHess, A_se$grad_max,
               format(A_se$hess_min_eig), A_pt$elapsed, A_se$elapsed))
    cat(sprintf("  B (our VA):  ok=%s rel_frob=%.3f atten=%.3f health=%s grad_max=%.2e hess_min_eig=%s t_pt=%.2fs t_se=NA(no SE)\n",
               B_res$ok, B_res$rel_frob, B_res$atten, B_res$health_admitted, B_res$grad_max,
               format(B_res$hess_min_eig), B_res$elapsed))
    cat(sprintf("  C (gllvm):   ok=%s rel_frob=%.3f atten=%.3f convergence=%s grad_max=%.2e hess_min_eig=%s t_pt=%.2fs t_se=%.2fs\n",
               C_se$ok, C_se$rel_frob, C_se$atten, C_se$convergence, C_se$grad_max,
               format(C_se$hess_min_eig), C_pt$elapsed, C_se$elapsed))

    for (arm_name in c("A", "B", "C")) {
      res <- switch(arm_name, A = A_se, B = B_res, C = C_se)
      cl <- switch(arm_name, A = cl_A, B = cl_B, C = cl_C)
      row_i <- row_i + 1L
      recovery_rows[[row_i]] <- data.frame(
        n_units = cell$n_units, n_traits = cell$n_traits, q = q,
        seed = seed, rep = rep_idx, arm = arm_name,
        ok = res$ok,
        rel_frob = res$rel_frob %||% NA_real_,
        atten = res$atten %||% NA_real_,
        cl_frobenius = if (!is.null(cl)) cl$frobenius else NA_real_,
        cl_cor_mean = if (!is.null(cl)) mean(cl$cor_per_factor) else NA_real_,
        self_report_ok = switch(arm_name,
          A = identical(res$opt_convergence, 0L) && isTRUE(res$pdHess),
          B = isTRUE(res$health_admitted),
          C = isTRUE(res$convergence)),
        grad_max = res$grad_max %||% NA_real_,
        hess_min_eig = res$hess_min_eig %||% NA_real_,
        pd_hessian = if (arm_name == "A") isTRUE(res$pdHess) else isTRUE(res$hess_min_eig > 0),
        se_available = switch(arm_name, A = TRUE, B = FALSE, C = isTRUE(res$sd_ok)),
        error = res$error %||% NA_character_,
        stringsAsFactors = FALSE
      )
    }
    for (arm_name in c("A", "C")) {
      pt <- switch(arm_name, A = A_pt, C = C_pt)
      se_ <- switch(arm_name, A = A_se, C = C_se)
      trow_i <- trow_i + 1L
      timing_rows[[trow_i]] <- data.frame(
        n_units = cell$n_units, n_traits = cell$n_traits, seed = seed, rep = rep_idx,
        arm = arm_name, elapsed_point = pt$elapsed, elapsed_point_se = se_$elapsed,
        stringsAsFactors = FALSE
      )
    }
    trow_i <- trow_i + 1L
    timing_rows[[trow_i]] <- data.frame(
      n_units = cell$n_units, n_traits = cell$n_traits, seed = seed, rep = rep_idx,
      arm = "B", elapsed_point = B_res$elapsed, elapsed_point_se = NA_real_,
      stringsAsFactors = FALSE
    )
  }
}

recovery <- do.call(rbind, recovery_rows)
timing <- do.call(rbind, timing_rows)

csv_path <- file.path(root, "dev", "three-engine-demo-recovery.csv")
write.csv(recovery, csv_path, row.names = FALSE)
cat("\nWrote", csv_path, "\n")

timing_csv_path <- file.path(root, "dev", "three-engine-demo-timing.csv")
write.csv(timing, timing_csv_path, row.names = FALSE)
cat("Wrote", timing_csv_path, "\n")

saveRDS(list(recovery = recovery, timing = timing),
       file.path(root, "dev", "three-engine-demo.rds"))
cat("Wrote", file.path(root, "dev", "three-engine-demo.rds"), "\n")

# ---------------------------------------------------------------------------
# Summary tables (medians across the 5 seeds per cell/arm).
# ---------------------------------------------------------------------------
cat("\n=== RECOVERY / CONVERGENCE SUMMARY (median over seeds) ===\n")
agg <- stats::aggregate(
  cbind(rel_frob, atten, cl_frobenius, cl_cor_mean, grad_max) ~ n_units + arm,
  data = recovery, FUN = function(x) stats::median(x, na.rm = TRUE)
)
ok_rate <- stats::aggregate(cbind(ok, self_report_ok, pd_hessian) ~ n_units + arm,
                            data = recovery, FUN = mean)
summary_recovery <- merge(agg, ok_rate, by = c("n_units", "arm"))
print(summary_recovery[order(summary_recovery$n_units, summary_recovery$arm), ])

cat("\n=== TIMING SUMMARY (median seconds over seeds) ===\n")
## na.action = na.pass: arm B has no point+SE variant (elapsed_point_se is
## entirely NA for that arm), and aggregate()'s default na.action = na.omit
## would silently DROP arm B's rows from the whole table rather than just
## report NA for the column that does not apply to it.
timing_summary <- stats::aggregate(
  cbind(elapsed_point, elapsed_point_se) ~ n_units + arm,
  data = timing, FUN = function(x) stats::median(x, na.rm = TRUE),
  na.action = stats::na.pass
)
print(timing_summary[order(timing_summary$n_units, timing_summary$arm), ])

summary_csv <- file.path(root, "dev", "three-engine-demo-summary.csv")
write.csv(summary_recovery, summary_csv, row.names = FALSE)
cat("\nWrote", summary_csv, "\n")
timing_summary_csv <- file.path(root, "dev", "three-engine-demo-timing-summary.csv")
write.csv(timing_summary, timing_summary_csv, row.names = FALSE)
cat("Wrote", timing_summary_csv, "\n")
