## dev/isdm-plumbing.R
##
## Integrated species distribution model (ISDM) plumbing check for gllvmTMB.
## One ecological intensity per cell i:  log(mu_i) = b0 + x_i*b + xi_i
##
## PO arm (thinned point pattern):
##   Y_po_i ~ Poisson(lambda_i),  log(lambda_i) = log(A_i) + b0 + x_i*b + xi_i + a0 + w_i*alpha
## PA arm (derived from the same Poisson process, area a_i):
##   cloglog(p_i) = log(a_i) + b0 + x_i*b + xi_i,  Y_pa_i ~ Bernoulli(p_i)
##
## b0 and b are THE SAME parameters in both arms; cloglog is the
## change-of-support link and is compulsory.
##
## DGP constraints honoured (see task brief):
##  1. Same latent unit: PA site i and PO cell i share the SAME xi_i (both are
##     row-pairs of `cell`).
##  2. Area units: PA survey area a_i = 1 for every site (log(a_i) = 0, a legal
##     ZERO offset on the binomial rows -- R/offset.R:148 refuses a NONZERO
##     offset on non-count families but allows zero). PO cell areas A_i vary
##     across cells (Uniform(50, 200)) and are expressed in the SAME area
##     units as the PA plots (i.e. "how many PA-survey-plots' worth of area
##     cell i is") -- NOT independently rescaled. This is what exercises the
##     offset machinery honestly instead of letting a0 silently absorb a unit
##     mismatch.
##  3. The intensity is constant within a cell by construction: PO and PA data
##     are generated directly on the fitting grid, not aggregated from a
##     continuous field.
##
## Uses the INSTALLED gllvmTMB (do not devtools::load_all()).
## Self-contained, seeded, re-runnable. Run with:
##   Rscript dev/isdm-plumbing.R
##
## Lane rule: this worktree only. Do not touch R/, src/, tests/. Do not
## git add -A / commit / open a PR.

suppressPackageStartupMessages(library(gllvmTMB))
cat("gllvmTMB version loaded:", as.character(packageVersion("gllvmTMB")), "\n")
cat("R version:", R.version.string, "\n\n")

hr <- function(x) cat("\n", strrep("=", 12), x, strrep("=", 12), "\n", sep = "")

## =========================================================================
## Shared DGP
## =========================================================================
## Planted truth used throughout T2-T4:
TRUE_B0     <- 0.0
TRUE_B      <- 0.4
TRUE_A0     <- -3.0
TRUE_ALPHA  <- 0.3
TRUE_LAMBDA <- 0.5   # loading on the shared latent factor
TRUE_SIGU   <- 1.0   # SD of the raw latent score u

sim_isdm <- function(seed, n_cell = 400, b0 = TRUE_B0, b = TRUE_B, a0 = TRUE_A0,
                      alpha = TRUE_ALPHA, lambda_load = TRUE_LAMBDA, sigma_u = TRUE_SIGU) {
  set.seed(seed)
  x <- rnorm(n_cell)
  w <- rnorm(n_cell)             # PO-only bias covariate
  A <- runif(n_cell, 50, 200)    # PO cell areas, in PA-survey-plot units
  a <- rep(1, n_cell)            # PA survey area = 1 plot, for every site
  u <- rnorm(n_cell, 0, sigma_u) # shared raw latent score, ONE per cell
  xi <- lambda_load * u          # shared latent deviation, ONE per cell

  eta_po <- log(A) + b0 + x * b + xi + a0 + w * alpha
  y_po <- rpois(n_cell, exp(eta_po))
  eta_pa <- log(a) + b0 + x * b + xi   # log(a) = 0
  p_pa <- 1 - exp(-exp(eta_pa))
  y_pa <- rbinom(n_cell, 1, p_pa)

  df_po <- data.frame(cell = seq_len(n_cell), trait = factor("sp1"), source = factor("po"),
                       x = x, w = w, value = y_po, off = log(A))
  df_pa <- data.frame(cell = seq_len(n_cell), trait = factor("sp1"), source = factor("pa"),
                       x = x, w = 0, value = y_pa, off = log(a))
  df <- rbind(df_po, df_pa)
  df <- df[order(df$cell), ]
  df$cell <- factor(df$cell)
  df$is_po <- as.numeric(df$source == "po")

  list(df = df, x = x, w = w, A = A, a = a, u = u, xi = xi, y_po = y_po, y_pa = y_pa,
       b0 = b0, b = b, a0 = a0, alpha = alpha, lambda_load = lambda_load,
       sigma_u = sigma_u, n_cell = n_cell)
}

family_list_joint <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(family_list_joint, "family_var") <- "source"

## =========================================================================
## T1 -- ANALYTIC CROSS-CHECK (fixed-effects-only, exact NLL)
## =========================================================================
hr("T1: analytic cross-check (fixed-effects-only, no latent() term)")

set.seed(11)
n_cell_t1 <- 300
x1 <- rnorm(n_cell_t1)
w1 <- rnorm(n_cell_t1)
A1 <- runif(n_cell_t1, 50, 200)
a1 <- rep(1, n_cell_t1)

b0_t1 <- 0.2; b_t1 <- 0.5; a0_t1 <- -1.0; alpha_t1 <- 0.3

eta_po1 <- log(A1) + b0_t1 + x1 * b_t1 + a0_t1 + w1 * alpha_t1
y_po1 <- rpois(n_cell_t1, exp(eta_po1))
eta_pa1 <- log(a1) + b0_t1 + x1 * b_t1
p_pa1 <- 1 - exp(-exp(eta_pa1))
y_pa1 <- rbinom(n_cell_t1, 1, p_pa1)

df_po1 <- data.frame(cell = seq_len(n_cell_t1), trait = factor("sp1"), source = factor("po"),
                      x = x1, w = w1, value = y_po1, off = log(A1))
df_pa1 <- data.frame(cell = seq_len(n_cell_t1), trait = factor("sp1"), source = factor("pa"),
                      x = x1, w = 0, value = y_pa1, off = log(a1))
df1 <- rbind(df_po1, df_pa1)
df1 <- df1[order(df1$cell), ]
df1$cell <- factor(df1$cell)
df1$is_po <- as.numeric(df1$source == "po")

fit1 <- gllvmTMB(
  value ~ 1 + x + is_po + is_po:w + offset(off),
  data   = df1, trait = "trait", unit = "cell",
  family = family_list_joint, silent = TRUE
)

cat("fit1$opt$convergence:", fit1$opt$convergence, "\n")
cat("fit1$sd_report$pdHess:", fit1$sd_report$pdHess, "\n")
cat("fit1$random (should be empty -- fixed-effects only, exact NLL):\n")
print(fit1$random)
cat("\nfit1$X_fix_names (parameter ordering for b_fix):\n")
print(fit1$X_fix_names)
cat("fit1$opt$par (fitted, same order):\n")
print(fit1$opt$par)

## Independent R computation of the joint NLL at a given parameter vector,
## using the SAME formulas as the DGP.
r_nll <- function(par_vec) {
  b0h <- par_vec[1]; bh <- par_vec[2]; a0h <- par_vec[3]; alphah <- par_vec[4]
  lambda_po <- exp(log(A1) + b0h + x1 * bh + a0h + w1 * alphah)
  p_pa_h <- 1 - exp(-exp(log(a1) + b0h + x1 * bh))
  -sum(dpois(y_po1, lambda_po, log = TRUE)) - sum(dbinom(y_pa1, 1, p_pa_h, log = TRUE))
}

check_pt <- function(par_vec, label) {
  fn_tmb <- fit1$tmb_obj$fn(par_vec)
  nll_R  <- r_nll(par_vec)
  cat(sprintf("%-12s par=(%7.3f,%7.3f,%7.3f,%7.3f)  TMB=%.8f  R=%.8f  diff=%.3e\n",
              label, par_vec[1], par_vec[2], par_vec[3], par_vec[4], fn_tmb, nll_R, fn_tmb - nll_R))
}

hr("T1 results: TMB obj$fn() vs independent R NLL at 4 parameter vectors")
check_pt(c(b0_t1, b_t1, a0_t1, alpha_t1), "true")
check_pt(c(0, 0, 0, 0), "zero")
check_pt(c(1, -1, 2, -0.5), "arbitrary")
check_pt(fit1$opt$par, "fitted-opt")

cat("\nsum(lgamma(y_po1 + 1)) [reference for the Poisson normalising constant]:",
    sum(lgamma(y_po1 + 1)), "\n")
cat("(dpois(..., log = TRUE) already includes -lgamma(y+1); TMB is checked\n")
cat(" against that full NLL above, not a constant-dropped version.)\n")

## ---- Diagnose the 'fitted-opt' gap (-1212) -------------------------------
## The default single-restart fit1 has pdHess = FALSE and a wildly wrong
## `opt$par` (b0 ~ -33.6, is_po ~ +32.8, summing to ~ -0.8 ~ true b0+a0):
## a degenerate local optimum, NOT a converged fit. That -1212 gap at
## "fitted-opt" is investigated below rather than taken at face value.
hr("T1 diagnostic: why does 'fitted-opt' disagree, and is fit1 even converged?")

cat("fit1 diagnostic: this is NOT a converged fit despite opt$convergence == 0.\n")
cat("pdHess:", fit1$sd_report$pdHess, "-- already a red flag on its own.\n\n")

cat("Sweeping b0 downward (b, a0, alpha held at truth) shows TMB and the naive\n")
cat("R NLL track EXACTLY until b0 gets extreme enough to push the cloglog PA\n")
cat("probability p below 1e-12, at which point they diverge:\n")
b0_sweep <- c(0.2, -2, -5, -10, -15, -20, -25, -28, -30, -31, -32, -33, fit1$opt$par[1])
for (b0_try in b0_sweep) {
  par_try <- c(b0_try, b_t1, a0_t1, alpha_t1)
  fn_tmb <- fit1$tmb_obj$fn(par_try)
  lambda_po_t <- exp(log(A1) + par_try[1] + x1 * par_try[2] + par_try[3] + w1 * par_try[4])
  mu_pa_t <- exp(log(a1) + par_try[1] + x1 * par_try[2])
  ll_pa_t <- ifelse(y_pa1 == 1, log(-expm1(-mu_pa_t)), -mu_pa_t)  # numerically stable, UNCLAMPED
  nll_R_t <- -sum(dpois(y_po1, lambda_po_t, log = TRUE)) - sum(ll_pa_t)
  cat(sprintf("  b0=%9.4f  TMB=%14.4f  R(unclamped,stable)=%14.4f  diff=%12.4f\n",
              b0_try, fn_tmb, nll_R_t, fn_tmb - nll_R_t))
}

cat("\nTraced to src/gllvmTMB.cpp:2192-2195 -- the binomial kernel clamps p to\n")
cat("[1e-12, 1-1e-12] before dbinom(), a documented numerical-safety guard\n")
cat("('Numerical safety: clip away from 0/1 to prevent log(0)'), applied\n")
cat("identically on EVERY row regardless of link. Replicating that SAME clamp\n")
cat("in the independent R computation at fit1$opt$par:\n")
par_bad <- fit1$opt$par
lambda_po_bad <- exp(log(A1) + par_bad[1] + x1 * par_bad[2] + par_bad[3] + w1 * par_bad[4])
mu_pa_bad <- exp(log(a1) + par_bad[1] + x1 * par_bad[2])
p_bad <- 1 - exp(-mu_pa_bad)
p_clamped <- pmin(pmax(p_bad, 1e-12), 1 - 1e-12)
nll_clamped <- -sum(dpois(y_po1, lambda_po_bad, log = TRUE)) - sum(dbinom(y_pa1, 1, p_clamped, log = TRUE))
cat(sprintf("  R NLL with the SAME [1e-12, 1-1e-12] clamp: %.6f\n", nll_clamped))
cat(sprintf("  TMB fn() at the same point:                 %.6f\n", fit1$tmb_obj$fn(par_bad)))
cat(sprintf("  diff: %.3e  (numerical-precision only)\n", nll_clamped - fit1$tmb_obj$fn(par_bad)))
cat("This closes the gap to numerical precision: the clamp, not a dispatch\n")
cat("error, fully explains the earlier 'fitted-opt' mismatch.\n")

cat("\nSeparately, does the TRUE optimum actually recover with more restarts?\n")
fit1_multi <- gllvmTMB(
  value ~ 1 + x + is_po + is_po:w + offset(off),
  data = df1, trait = "trait", unit = "cell", family = family_list_joint, silent = TRUE,
  control = gllvmTMBcontrol(n_init = 8, init_jitter = 1.0)
)
cat("n_init = 8, init_jitter = 1.0:\n")
cat("  convergence:", fit1_multi$opt$convergence, " pdHess:", fit1_multi$sd_report$pdHess, "\n")
cat("  opt$par:\n"); print(fit1_multi$opt$par)
cat("  objective:", fit1_multi$opt$objective, " (vs default-start's", fit1$opt$objective,
    "and the true-par NLL", fit1$tmb_obj$fn(c(b0_t1, b_t1, a0_t1, alpha_t1)), ")\n")
cat("This recovers b0, b, a0, alpha close to the planted (0.2, 0.5, -1.0, 0.3)\n")
cat("with pdHess = TRUE, confirming fit1's default single-restart run was a\n")
cat("genuine local-optimum failure (echoing the prior probe's T3 footgun --\n")
cat("mixed-family raw-y OLS starting values), not evidence against T1.\n")

## =========================================================================
## T2 -- BETA RECOVERY, one species, joint PO+PA fit, 20 seeds
## =========================================================================
hr("T2: beta recovery, joint fit, 20 seeds, n_cell = 400")

fit_joint <- function(sim) {
  gllvmTMB(
    value ~ 1 + x + is_po + is_po:w + offset(off) +
      latent(0 + trait | cell, d = 1, unique = FALSE),
    data = sim$df, trait = "trait", unit = "cell", cluster = "trait",
    family = family_list_joint, silent = TRUE
  )
}

N_SEEDS <- 20
N_CELL  <- 400
seeds   <- 1000 + seq_len(N_SEEDS)

run_recovery <- function(seeds, fit_fn, sim_fn, par_idx = 2, label) {
  b_hat <- rep(NA_real_, length(seeds))
  conv  <- rep(NA_integer_, length(seeds))
  pdh   <- rep(NA, length(seeds))
  errs  <- character(0)
  for (i in seq_along(seeds)) {
    sim <- sim_fn(seeds[i])
    fit <- tryCatch(fit_fn(sim), error = function(e) e)
    if (inherits(fit, "error")) {
      errs <- c(errs, sprintf("seed %d: %s", seeds[i], conditionMessage(fit)))
      next
    }
    conv[i]  <- fit$opt$convergence
    pdh[i]   <- fit$sd_report$pdHess
    b_hat[i] <- fit$opt$par[par_idx]
  }
  if (length(errs) > 0) {
    cat(label, "ERRORS:\n"); cat(paste(errs, collapse = "\n"), "\n")
  }
  n_ok <- sum(!is.na(b_hat))
  bias <- mean(b_hat, na.rm = TRUE) - TRUE_B
  mcse <- sd(b_hat, na.rm = TRUE) / sqrt(n_ok)
  cat(sprintf("\n[%s] n_ok=%d/%d  convergence table: ", label, n_ok, length(seeds)))
  print(table(conv))
  cat("pdHess table: "); print(table(pdh))
  cat(sprintf("planted b = %.3f\n", TRUE_B))
  cat(sprintf("mean(b_hat) = %.5f   SD(b_hat) = %.5f\n", mean(b_hat, na.rm = TRUE), sd(b_hat, na.rm = TRUE)))
  cat(sprintf("bias = %.5f   MCSE(bias) = %.5f\n", bias, mcse))
  cat("all b_hat:\n"); print(b_hat)
  invisible(list(b_hat = b_hat, conv = conv, pdh = pdh, bias = bias, mcse = mcse))
}

t0 <- Sys.time()
res_t2 <- run_recovery(seeds, fit_joint, function(s) sim_isdm(s, n_cell = N_CELL), par_idx = 2, label = "T2 joint")
t1 <- Sys.time()
cat(sprintf("\nT2 wall time: %.2f s for %d fits\n", as.numeric(t1 - t0, units = "secs"), N_SEEDS))

## =========================================================================
## T3 -- DOES THE PA ARM ACTUALLY CONTRIBUTE? (permute PA responses)
## =========================================================================
hr("T3: PA responses permuted across cells (design preserved, information destroyed)")

sim_isdm_permuted <- function(seed, n_cell = N_CELL) {
  sim <- sim_isdm(seed, n_cell = n_cell)
  set.seed(seed + 500000L)  # distinct permutation stream, still reproducible
  perm <- sample(seq_len(n_cell))
  df <- sim$df
  is_pa <- df$source == "pa"
  ## permute the PA rows' `value` across cells; `cell` order is 1..n_cell for
  ## both po and pa row-blocks by construction (df is cell-sorted then
  ## po/pa within cell), so a direct index permutation on the pa subset
  ## reassigns y_pa across cells while leaving every covariate untouched.
  pa_idx <- which(is_pa)
  df$value[pa_idx] <- df$value[pa_idx][perm]
  sim$df <- df
  sim
}

t0 <- Sys.time()
res_t3 <- run_recovery(seeds, fit_joint, sim_isdm_permuted, par_idx = 2, label = "T3 PA-permuted")
t1 <- Sys.time()
cat(sprintf("\nT3 wall time: %.2f s for %d fits\n", as.numeric(t1 - t0, units = "secs"), N_SEEDS))

hr("T3 vs T2 comparison")
cat(sprintf("T2 (joint, PA intact):    mean(b_hat) = %.5f  bias = %.5f  MCSE = %.5f\n",
            mean(res_t2$b_hat, na.rm = TRUE), res_t2$bias, res_t2$mcse))
cat(sprintf("T3 (joint, PA permuted):  mean(b_hat) = %.5f  bias = %.5f  MCSE = %.5f\n",
            mean(res_t3$b_hat, na.rm = TRUE), res_t3$bias, res_t3$mcse))
cat(sprintf("Difference in mean b_hat (T3 - T2): %.5f\n",
            mean(res_t3$b_hat, na.rm = TRUE) - mean(res_t2$b_hat, na.rm = TRUE)))
## Two-sample comparison (Welch t-test) to check whether the permuted-PA
## estimates are statistically distinguishable from the intact-PA estimates.
tt <- t.test(res_t2$b_hat, res_t3$b_hat)
cat("Welch two-sample t-test on b_hat, T2 vs T3:\n")
print(tt)

## =========================================================================
## T4 -- ARM COMPARISON: PO-only vs PA-only vs joint
## =========================================================================
hr("T4: PO-only and PA-only arm comparison")

fit_po_only <- function(sim) {
  df_po <- sim$df[sim$df$source == "po", ]
  gllvmTMB(
    value ~ 1 + x + w + offset(off) + latent(0 + trait | cell, d = 1, unique = FALSE),
    data = df_po, trait = "trait", unit = "cell", cluster = "trait",
    family = poisson(), silent = TRUE
  )
}

fit_pa_only <- function(sim) {
  df_pa <- sim$df[sim$df$source == "pa", ]
  gllvmTMB(
    value ~ 1 + x + offset(off) + latent(0 + trait | cell, d = 1, unique = FALSE),
    data = df_pa, trait = "trait", unit = "cell", cluster = "trait",
    family = binomial(link = "cloglog"), silent = TRUE
  )
}

## PO-only: X_fix_names order is (Intercept), x, w -- b is column 2 (index 2).
## PA-only: X_fix_names order is (Intercept), x -- b is column 2 (index 2).
t0 <- Sys.time()
res_po <- run_recovery(seeds, fit_po_only, function(s) sim_isdm(s, n_cell = N_CELL), par_idx = 2, label = "T4 PO-only")
t1 <- Sys.time()
cat(sprintf("\nT4 PO-only wall time: %.2f s for %d fits\n", as.numeric(t1 - t0, units = "secs"), N_SEEDS))

t0 <- Sys.time()
res_pa <- run_recovery(seeds, fit_pa_only, function(s) sim_isdm(s, n_cell = N_CELL), par_idx = 2, label = "T4 PA-only")
t1 <- Sys.time()
cat(sprintf("\nT4 PA-only wall time: %.2f s for %d fits\n", as.numeric(t1 - t0, units = "secs"), N_SEEDS))

hr("T4 summary table: b recovery across arms")
cat(sprintf("%-18s %10s %10s %10s\n", "arm", "mean(b_hat)", "bias", "MCSE"))
cat(sprintf("%-18s %10.5f %10.5f %10.5f\n", "joint (T2)", mean(res_t2$b_hat, na.rm = TRUE), res_t2$bias, res_t2$mcse))
cat(sprintf("%-18s %10.5f %10.5f %10.5f\n", "PO-only", mean(res_po$b_hat, na.rm = TRUE), res_po$bias, res_po$mcse))
cat(sprintf("%-18s %10.5f %10.5f %10.5f\n", "PA-only", mean(res_pa$b_hat, na.rm = TRUE), res_pa$bias, res_pa$mcse))
cat("Note: PO-only's intercept column is (b0+a0) confounded, NOT b0 alone;\n")
cat("b is still separately identified and is what is scored above.\n")

## ---- explicit combined-intercept confound check for PO-only, seed 1001 ---
hr("T4: PO-only intercept confound illustration (seed 1001)")
sim_illustration <- sim_isdm(1001, n_cell = N_CELL)
fit_po_illustration <- fit_po_only(sim_illustration)
cat("PO-only fit$X_fix_names:\n"); print(fit_po_illustration$X_fix_names)
cat("PO-only fit$opt$par:\n"); print(fit_po_illustration$opt$par)
cat(sprintf("planted b0 + a0 = %.3f + %.3f = %.3f  (compare to PO-only intercept above)\n",
            TRUE_B0, TRUE_A0, TRUE_B0 + TRUE_A0))

## ---- the diag_B_skip trap check (R/fit-multi.R:4976) --------------------
hr("T4: diag_B_skip trap check on PA-only fits")
cat("Our PA-only fits above used latent(..., unique = FALSE), so there is no\n")
cat("per-trait Psi (theta_diag_B) at all, and the trap has nothing to pin.\n")
cat("diag_B_skip for the seed-1001 PA-only (unique = FALSE) fit:\n")
df_pa_illustration <- sim_illustration$df[sim_illustration$df$source == "pa", ]
fit_pa_illustration_uF <- fit_pa_only(sim_illustration)
print(fit_pa_illustration_uF$tmb_data$diag_B_skip)

cat("\nFor comparison, refitting the SAME PA-only data with the package's\n")
cat("DEFAULT latent(unique = TRUE) (i.e. WITHOUT our unique = FALSE choice):\n")
fit_pa_default_uT <- tryCatch(
  gllvmTMB(
    value ~ 1 + x + offset(off) + latent(0 + trait | cell, d = 1),
    data = df_pa_illustration, trait = "trait", unit = "cell", cluster = "trait",
    family = binomial(link = "cloglog"), silent = TRUE
  ),
  error = function(e) e
)
if (inherits(fit_pa_default_uT, "error")) {
  cat("ERROR:\n"); print(fit_pa_default_uT)
} else {
  cat("convergence:", fit_pa_default_uT$opt$convergence,
      " pdHess:", fit_pa_default_uT$sd_report$pdHess, "\n")
  cat("diag_B_skip:", fit_pa_default_uT$tmb_data$diag_B_skip, "(1 = trap fired, Psi pinned to 1e-6)\n")
  cat("opt$par:\n"); print(fit_pa_default_uT$opt$par)
}

cat("\nFor comparison, the JOINT fit (PO+PA) with the package's DEFAULT\n")
cat("latent(unique = TRUE) on the SAME seed-1001 data (all rows, not PA-only):\n")
fit_joint_default_uT <- tryCatch(
  gllvmTMB(
    value ~ 1 + x + is_po + is_po:w + offset(off) + latent(0 + trait | cell, d = 1),
    data = sim_illustration$df, trait = "trait", unit = "cell", cluster = "trait",
    family = family_list_joint, silent = TRUE
  ),
  error = function(e) e
)
if (inherits(fit_joint_default_uT, "error")) {
  cat("ERROR:\n"); print(fit_joint_default_uT)
} else {
  cat("convergence:", fit_joint_default_uT$opt$convergence,
      " pdHess:", fit_joint_default_uT$sd_report$pdHess, "\n")
  cat("diag_B_skip:", fit_joint_default_uT$tmb_data$diag_B_skip, "(0 = trap did NOT fire; poisson rows present)\n")
}

hr("DONE")
