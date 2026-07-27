#!/usr/bin/env Rscript
## dev/controlled-gh-vs-jj.R
##
## FISHER TASK: the CONTROLLED recovery experiment separating THE BOUND from
## THE IMPLEMENTATION.
##
## Prior finding (dev/bound-vs-estimates-recovery.R / dev/bound-vs-estimates.md,
## this repo, this session): gllvmTMB's Gauss-Hermite VA (va_r3, H=15) recovers
## Sigma_B WORSE than gllvm's method="VA" (Jaakkola-Jordan/Polya-Gamma bound) --
## median relative Frobenius 2.19 vs 0.87 at n=60, 0.90 vs 0.55 at n=100. That
## comparison confounds the BOUND (GH vs JJ) with the IMPLEMENTATION (our
## optimiser/starts/gates vs gllvm's). This script removes the confound by
## adding a same-engine JJ arm (eval_method = "jj", added this session to
## R/va-r3-proto.R / inst/tmb/gllvmTMB_va_r3.cpp), giving FOUR arms on the
## IDENTICAL simulated matrix:
##
##   A: ours,  GH   (.approximation_engine_fit(engine="va_r3", eval_method="gh"))
##   B: ours,  JJ   (.approximation_engine_fit(engine="va_r3", eval_method="jj"))
##   C: gllvm, JJ   (gllvm::gllvm(method="VA"))
##   D: gllvmTMB Laplace, Psi-suppressed (latent(1|site, d=q, unique=FALSE))
##
## Decisive contrasts:
##   1. A vs B (same engine, different bound) isolates THE BOUND.
##   2. B vs C (same bound, different engine) isolates THE IMPLEMENTATION.
##   3. D's silent-failure rate: clean convergence + pdHess=TRUE landing on a
##      degenerate loading.
##
## Internal research only. No @export, no method= argument, no testthat.
## Never call an ELBO a likelihood.

suppressPackageStartupMessages({
  library(stats)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath(getwd(), mustWork = TRUE)
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))
source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
va_eva_source_private_engines(root, envir = .GlobalEnv)

if (!requireNamespace("gllvm", quietly = TRUE)) {
  stop("This script requires the gllvm package for the JJ-engine comparator arm.",
       call. = FALSE)
}

# ---------------------------------------------------------------------------
# Data-generating process: Bernoulli-logit, q = 2, known Lambda_true/beta_true
# (identical DGP to dev/bound-vs-estimates-recovery.R for continuity with the
# prior 3-arm run.)
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
# Ours (va_r3), one runner parameterised by eval_method -- Arms A and B are
# the SAME code path with only eval_method differing, by construction. This
# is what makes the A-vs-B contrast clean: no other knob moves.
# ---------------------------------------------------------------------------
fit_arm_ours <- function(sim, eval_method) {
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
      eval_method = eval_method
    ),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0

  if (inherits(fit, "arm_error")) {
    return(list(ok = FALSE, error = fit$error_message, elapsed = elapsed,
               status = NA_character_, rel_frob = NA_real_, atten = NA_real_))
  }
  Sigma_hat <- fit$engine_result$report$Sigma_B
  if (is.null(Sigma_hat)) {
    return(list(ok = FALSE, error = "no Sigma_B in report", elapsed = elapsed,
               status = fit$status %||% NA_character_,
               rel_frob = NA_real_, atten = NA_real_))
  }
  list(ok = TRUE, error = NA_character_, elapsed = elapsed,
       status = fit$status %||% NA_character_,
       rel_frob = rel_frobenius(Sigma_hat, sim$Sigma_true),
       atten = attenuation_ratio(Sigma_hat, sim$Sigma_true))
}

# ---------------------------------------------------------------------------
# Arm C: gllvm::gllvm(method = "VA") -- the JJ / Polya-Gamma bound, gllvm's
# own optimiser/starts/gates.
# ---------------------------------------------------------------------------
fit_arm_C <- function(sim) {
  q <- sim$q
  ## Match va_r3's internal 4-start search (both A and B run 4 starts
  ## unconditionally -- see R/va-r3-proto.R `starts <- lapply(1:4, ...)`) so
  ## no arm gets more optimisation effort than another. gllvm's own default
  ## (control.start$n.init = 1) reliably diverges to degenerate loadings on
  ## Bernoulli-logit VA (verified in the prior 3-arm run: LV1 loadings up to
  ## +/-4600 with n.init = 1, seed 20261786) -- a fairness fix, not a
  ## tune-away.
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvm::gllvm(y = sim$Y, family = "binomial", link = "logit",
                num.lv = q, method = "VA", sd.errors = FALSE,
                seed = sim$seed,
                control.start = list(n.init = 4, jitter.var = 0.2)),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0

  if (inherits(fit, "arm_error")) {
    return(list(ok = FALSE, error = fit$error_message, elapsed = elapsed,
               status = NA_character_, rel_frob = NA_real_, atten = NA_real_))
  }
  theta <- fit$params$theta
  sigma_lv <- fit$params$sigma.lv
  if (is.null(theta)) {
    return(list(ok = FALSE, error = "no params$theta in fit", elapsed = elapsed,
               status = NA_character_, rel_frob = NA_real_, atten = NA_real_))
  }
  ## gllvm's theta carries a fixed identifiability constraint; sigma.lv
  ## rescales each latent axis. Fitted linear-predictor loading is
  ## theta %*% diag(sigma.lv). See dev/bound-vs-estimates.md pitfall #1.
  Lambda_hat <- if (!is.null(sigma_lv)) theta %*% diag(sigma_lv, nrow = q, ncol = q) else theta
  Sigma_hat <- Lambda_hat %*% t(Lambda_hat)
  list(ok = TRUE, error = NA_character_, elapsed = elapsed,
       status = if (isTRUE(fit$convergence)) "converged" else "not_converged",
       rel_frob = rel_frobenius(Sigma_hat, sim$Sigma_true),
       atten = attenuation_ratio(Sigma_hat, sim$Sigma_true))
}

# ---------------------------------------------------------------------------
# Arm D: gllvmTMB Laplace, Psi-suppressed (matched call)
# ---------------------------------------------------------------------------
fit_arm_D <- function(sim) {
  n <- sim$n_units; p <- sim$n_traits; q <- sim$q
  df <- as.data.frame(sim$Y)
  df$site <- factor(seq_len(n))
  fml <- stats::as.formula(paste0(
    "traits(", paste(sim$trait_names, collapse = ", "), ") ~ 1 + latent(1 | site, d = ",
    q, ", unique = FALSE)"
  ))

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvmTMB(fml, data = df, family = binomial()),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "arm_error")
  )
  elapsed <- proc.time()[["elapsed"]] - t0

  if (inherits(fit, "arm_error")) {
    return(list(ok = FALSE, error = fit$error_message, elapsed = elapsed,
               status = NA_character_, rel_frob = NA_real_, atten = NA_real_,
               pdHess = NA))
  }
  ord <- tryCatch(extract_ordination(fit, level = "unit"),
                  error = function(e) structure(list(error_message = conditionMessage(e)),
                                                class = "arm_error"))
  pdHess <- fit$sd_report$pdHess %||% NA
  if (inherits(ord, "arm_error") || is.null(ord$loadings)) {
    return(list(ok = FALSE,
               error = if (inherits(ord, "arm_error")) ord$error_message else "no loadings",
               elapsed = elapsed, status = NA_character_,
               rel_frob = NA_real_, atten = NA_real_, pdHess = pdHess))
  }
  Lambda_hat <- ord$loadings
  Sigma_hat <- Lambda_hat %*% t(Lambda_hat)
  rel_frob <- rel_frobenius(Sigma_hat, sim$Sigma_true)
  list(ok = TRUE, error = NA_character_, elapsed = elapsed,
       status = if (isTRUE(pdHess)) "pd_hessian" else NA_character_,
       rel_frob = rel_frob,
       atten = attenuation_ratio(Sigma_hat, sim$Sigma_true),
       pdHess = pdHess)
}

# ---------------------------------------------------------------------------
# Grid: (n=60,p=12) and (n=100,p=20), q=2, 10 seeds per cell -- IDENTICAL DGP
# and seed formula to dev/bound-vs-estimates-recovery.R for continuity.
# ---------------------------------------------------------------------------
cells <- list(
  list(n_units = 60L, n_traits = 12L),
  list(n_units = 100L, n_traits = 20L)
)
q <- 2L
n_seeds <- 10L
base_seed <- 20260726L

results <- list()
row_i <- 0L

for (cell in cells) {
  for (rep_idx in seq_len(n_seeds)) {
    seed <- base_seed + rep_idx * 1000L + cell$n_units
    cat(sprintf("[n=%d p=%d seed=%d] simulating...\n", cell$n_units, cell$n_traits, seed))
    sim <- simulate_bernoulli_gllvm(cell$n_units, cell$n_traits, q, seed)

    res_A <- fit_arm_ours(sim, eval_method = "gh")
    cat(sprintf("  A (ours, GH):  ok=%s status=%s rel_frob=%.3f atten=%.3f time=%.2fs\n",
               res_A$ok, res_A$status %||% res_A$error, res_A$rel_frob, res_A$atten, res_A$elapsed))

    res_B <- fit_arm_ours(sim, eval_method = "jj")
    cat(sprintf("  B (ours, JJ):  ok=%s status=%s rel_frob=%.3f atten=%.3f time=%.2fs\n",
               res_B$ok, res_B$status %||% res_B$error, res_B$rel_frob, res_B$atten, res_B$elapsed))

    res_C <- fit_arm_C(sim)
    cat(sprintf("  C (gllvm, JJ): ok=%s status=%s rel_frob=%.3f atten=%.3f time=%.2fs\n",
               res_C$ok, res_C$status %||% res_C$error, res_C$rel_frob, res_C$atten, res_C$elapsed))

    res_D <- fit_arm_D(sim)
    cat(sprintf("  D (Laplace):   ok=%s status=%s pdHess=%s rel_frob=%.3f atten=%.3f time=%.2fs\n",
               res_D$ok, res_D$status %||% res_D$error, res_D$pdHess, res_D$rel_frob, res_D$atten, res_D$elapsed))

    for (arm_name in c("A", "B", "C", "D")) {
      res <- get(paste0("res_", arm_name))
      row_i <- row_i + 1L
      results[[row_i]] <- data.frame(
        n_units = cell$n_units, n_traits = cell$n_traits, q = q,
        seed = seed, rep = rep_idx, arm = arm_name,
        ok = res$ok, status = res$status %||% NA_character_,
        error = res$error %||% NA_character_,
        pdHess = if (arm_name == "D") res$pdHess %||% NA else NA,
        rel_frob = res$rel_frob, atten = res$atten, elapsed_sec = res$elapsed,
        stringsAsFactors = FALSE
      )
    }
  }
}

out <- do.call(rbind, results)
csv_path <- file.path(root, "dev", "controlled-gh-vs-jj.csv")
write.csv(out, csv_path, row.names = FALSE)
cat("\nWrote", csv_path, "\n")

saveRDS(out, file.path(root, "dev", "controlled-gh-vs-jj.rds"))
cat("Wrote", file.path(root, "dev", "controlled-gh-vs-jj.rds"), "\n")
