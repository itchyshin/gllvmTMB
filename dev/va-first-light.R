#!/usr/bin/env Rscript
## dev/va-first-light.R -- Design 85 VA prototype first-light diagnostic.
##
## GOAL: not a feature. One diagnostic number: does the R3 Gaussian-VA
## prototype's ELBO look broadly right against three oracles fit on the
## SAME data (gllvmTMB Laplace, gllvm VA, glmmTMB rr()+diag() Laplace)?
##
## This is a scratch/compile-and-look script, not a test file. Run with:
##   Rscript --vanilla dev/va-first-light.R
##
## Scratch working files (compiled TMB DLL, RDS) go under the session
## scratchpad, never under /tmp directly and never committed.

options(warn = 1)
scratch_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad"

suppressPackageStartupMessages({
  library(devtools)
})

cat("== Loading gllvmTMB from source (this worktree) ==\n")
devtools::load_all(".", quiet = TRUE)

stopifnot(requireNamespace("gllvm", quietly = TRUE))
stopifnot(requireNamespace("glmmTMB", quietly = TRUE))

# ---------------------------------------------------------------------------
# 1. Data-generating process
# ---------------------------------------------------------------------------
## Family choice: MULTI-TRIAL binomial (n_trials = 12), NOT Bernoulli/sparse
## binary. This is forced by the prototype's own admission gate, not a free
## choice: .va_r3_validate_data() requires family %in% c("binomial",
## "gaussian_anchor"), and for "binomial" requires n_trials >= 2 everywhere
## (R/va-r3-proto.R:203-215; inst/tmb/gllvmTMB_va_r3.cpp:142-148 enforces the
## same at the C++ level). A Bernoulli (n_trials = 1) fixture would be
## rejected outright, so multi-trial binomial-logit is the only family this
## prototype can be driven on among the count/binary families, and it is
## also the family the NO-GO pilot itself used (tools/va-r3-pilot.R).
##
## Structure: ordinary latent(unique = FALSE) i.e. loadings-only rr(), NO
## Psi/diag term -- again forced by .va_r3_validate_data()'s explicit
## rejection of unique = TRUE / psi / structured / provider / lv / missing
## (R/va-r3-proto.R:196-201). So the oracle formulas below use rr() alone
## on the glmmTMB/gllvmTMB side, never rr() + diag().
##
## Size: d = q = 2, N = 80 units x T = 6 traits, complete grid (N*T = 480
## complete unit-trait cells, as R3 requires -- every cell present exactly
## once). This mirrors tools/va-r3-pilot.R's own q2 cell (N=60, T=4,
## n_trials=12) scaled up slightly per the task's 60-100 x 6 traits target.
seed <- 20260725L
set.seed(seed)

q_true <- 2L
N <- 80L
Tt <- 6L
n_trials_k <- 12L

Lambda_true <- matrix(0, Tt, q_true)
for (j in seq_len(q_true)) {
  Lambda_true[j, j] <- 0.78 + 0.04 * j
  if (j < Tt) {
    rows <- seq.int(j + 1L, Tt)
    Lambda_true[rows, j] <- 0.30 * sin(rows + 1.7 * j)
  }
}
beta_true <- seq(-0.45, 0.45, length.out = Tt)

score_true <- matrix(stats::rnorm(N * q_true), N, q_true)
unit_idx <- rep(seq_len(N), each = Tt)
trait_idx <- rep(seq_len(Tt), N)
X <- stats::model.matrix(~ 0 + factor(trait_idx, levels = seq_len(Tt)))
stopifnot(qr(X)$rank == ncol(X))

eta <- drop(X %*% beta_true) + rowSums(
  Lambda_true[trait_idx, , drop = FALSE] * score_true[unit_idx, , drop = FALSE]
)
prob_true <- stats::plogis(eta)
y <- stats::rbinom(N * Tt, n_trials_k, prob_true)

trait_fac <- factor(sprintf("t%02d", trait_idx))
unit_fac <- factor(sprintf("u%03d", unit_idx))
df <- data.frame(
  succ = y, fail = n_trials_k - y,
  trait = trait_fac, unit = unit_fac
)

cat(sprintf(
  "DGP: seed=%d, family=binomial(n_trials=%d), q=%d, N=%d, T=%d, N*T=%d\n",
  seed, n_trials_k, q_true, N, Tt, N * Tt
))

# ---------------------------------------------------------------------------
# 2. Fit 1: VA prototype (R3), fixed known rank q = 2
# ---------------------------------------------------------------------------
cat("\n== Fit 1/4: VA prototype (.va_r3_fit), q =", q_true, "==\n")
proto_source <- normalizePath(
  file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"), mustWork = TRUE
)

va_time <- system.time({
  va_fit <- .va_r3_fit(
    y = y, n_trials = rep.int(n_trials_k, N * Tt), X = X,
    unit_id = unit_idx, trait_id = trait_idx, q = q_true,
    N = N, T = Tt, family = "binomial", link = "logit",
    H = 61L, rank_source = "fixed_fixture",
    source = proto_source,
    control = list(eval.max = 3000L, iter.max = 3000L)
  )
})
cat("VA status:", va_fit$status, "| elapsed:", va_time[["elapsed"]], "s\n")
cat("VA health:\n"); str(va_fit$health)

# ---------------------------------------------------------------------------
# 3. Fit 2: gllvmTMB Laplace (own engine, same rr()-only formula)
# ---------------------------------------------------------------------------
cat("\n== Fit 2/4: gllvmTMB Laplace ==\n")
gt_form <- stats::as.formula(
  paste0("cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = ",
         q_true, ", unique = FALSE)")
)
gt_time <- system.time({
  fit_gt <- tryCatch(
    gllvmTMB(gt_form, data = df, family = stats::binomial(), unit = "unit",
             control = gllvmTMBcontrol(n_init = 1L, se = FALSE)),
    warning = function(w) { message("gllvmTMB warning: ", conditionMessage(w)); w }
  )
})
if (inherits(fit_gt, "condition") && !inherits(fit_gt, "gllvmTMB_multi")) {
  stop("gllvmTMB Laplace fit failed outright: ", conditionMessage(fit_gt))
}
cat("gllvmTMB convergence:", fit_gt$opt$convergence,
    "| elapsed:", gt_time[["elapsed"]], "s\n")
ll_laplace <- -fit_gt$opt$objective
cat("gllvmTMB logLik:", ll_laplace, "\n")

# ---------------------------------------------------------------------------
# 4. Fit 3: gllvm (default method = "VA"), same DGP via Y/Ntrials matrices
# ---------------------------------------------------------------------------
cat("\n== Fit 3/4: gllvm (method = VA) ==\n")
Y_mat <- matrix(y, nrow = N, ncol = Tt, byrow = TRUE)
N_mat <- matrix(n_trials_k, nrow = N, ncol = Tt)
gllvm_time <- system.time({
  fit_gllvm <- tryCatch(
    gllvm::gllvm(y = Y_mat, num.lv = q_true, family = "binomial",
                 link = "logit", Ntrials = N_mat, method = "VA",
                 seed = 1, sd.errors = FALSE),
    error = function(e) e
  )
})
if (inherits(fit_gllvm, "error")) {
  cat("gllvm fit ERRORED:", conditionMessage(fit_gllvm), "\n")
  ll_gllvm <- NA_real_
} else {
  cat("gllvm convergence:", fit_gllvm$convergence,
      "| elapsed:", gllvm_time[["elapsed"]], "s\n")
  ll_gllvm <- fit_gllvm$logL
  cat("gllvm logL:", ll_gllvm, "\n")
}

# ---------------------------------------------------------------------------
# 5. Fit 4: glmmTMB rr() (loadings-only, matching R3's no-Psi restriction)
# ---------------------------------------------------------------------------
cat("\n== Fit 4/4: glmmTMB rr() Laplace ==\n")
gm_form <- stats::as.formula(
  paste0("cbind(succ, fail) ~ 0 + trait + rr(0 + trait | unit, d = ", q_true, ")")
)
glmmtmb_time <- system.time({
  fit_glmmtmb <- tryCatch(
    glmmTMB::glmmTMB(gm_form, data = df, family = stats::binomial(),
                     REML = FALSE),
    warning = function(w) { message("glmmTMB warning: ", conditionMessage(w)); w }
  )
})
if (inherits(fit_glmmtmb, "condition") && !inherits(fit_glmmtmb, "glmmTMB")) {
  stop("glmmTMB fit failed outright: ", conditionMessage(fit_glmmtmb))
}
ll_glmmtmb <- as.numeric(stats::logLik(fit_glmmtmb))
cat("glmmTMB convergence code:", fit_glmmtmb$fit$convergence,
    "| elapsed:", glmmtmb_time[["elapsed"]], "s\n")
cat("glmmTMB logLik:", ll_glmmtmb, "\n")

# ---------------------------------------------------------------------------
# 6. Sign reconciliation and comparison table
# ---------------------------------------------------------------------------
## Design 85 sec. 10 warning: the VA prototype's TMB objective (obj$fn, what
## nlminb/.va_r3_fit's `$best$objective` minimizes) is NEGATIVE ELBO -- see
## inst/tmb/gllvmTMB_va_r3.cpp:301-304 ("Type negative_elbo = -elbo; ...
## return negative_elbo;"). It is NOT a negative log-likelihood in the same
## sense as fit_gt$opt$objective (which IS glmmTMB/gllvmTMB's usual negative
## marginal log-likelihood under Laplace). To compare on a common "higher is
## better, log-scale" axis, flip the VA objective's sign to get the ELBO
## itself (a lower bound on the true log-likelihood), then compare directly
## to the two Laplace logLik values and gllvm's reported logL.
va_elbo <- if (!is.null(va_fit$best)) -va_fit$best$objective else NA_real_

cat("\n================ COMPARISON TABLE ================\n")
tab <- data.frame(
  method = c("VA prototype (ELBO)", "gllvmTMB (Laplace logLik)",
             "gllvm (VA logL)", "glmmTMB rr() (Laplace logLik)"),
  objective = c(va_elbo, ll_laplace, ll_gllvm, ll_glmmtmb)
)
print(tab, digits = 6)

gap_model <- ll_laplace - ll_glmmtmb          # same method -> should be ~0
gap_method <- ll_gllvm - ll_laplace           # VA package vs Laplace
gap_elbo_laplace <- va_elbo - ll_laplace      # ELBO vs its own Laplace anchor

cat("\n-- Gaps --\n")
cat(sprintf("gllvmTMB - glmmTMB (same method, model check):        %+.6f\n", gap_model))
cat(sprintf("gllvm    - gllvmTMB (method check, VA vs Laplace):    %+.6f\n", gap_method))
cat(sprintf("VA-ELBO  - gllvmTMB (ELBO vs its own Laplace anchor): %+.6f\n", gap_elbo_laplace))
cat(sprintf("\nIs the ELBO BELOW the Laplace logLik (expected for a valid lower bound)? %s\n",
            if (is.na(gap_elbo_laplace)) "NA (VA did not admit)" else if (gap_elbo_laplace <= 0) "YES" else "NO -- RED FLAG"))

cat("\n== Raw objects for the results write-up ==\n")
saveRDS(list(va_fit = va_fit, fit_gt_opt = fit_gt$opt, fit_gllvm_summary = if (!inherits(fit_gllvm, "error")) fit_gllvm[c("logL","convergence")] else fit_gllvm,
             fit_glmmtmb_ll = ll_glmmtmb, tab = tab, seed = seed),
        file.path(scratch_dir, "va-first-light-fits.rds"))
cat("Saved raw fit summary to", file.path(scratch_dir, "va-first-light-fits.rds"), "\n")
cat("\nDONE.\n")
