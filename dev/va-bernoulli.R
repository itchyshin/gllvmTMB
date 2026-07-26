#!/usr/bin/env Rscript
## dev/va-bernoulli.R -- does the Design-85 R3 VA objective work at
## n_trials = 1 (Bernoulli), once the scope-freeze guard is relaxed?
##
## Scratch/compile-and-look script, NOT a test file. Run with:
##   Rscript --vanilla dev/va-bernoulli.R
##
## The one number that matters is the ELBO's gap to the BRUTE-FORCE TRUE
## marginal log-likelihood at the SAME theta -- never the gap to Laplace.
## Laplace is itself an approximation and is measured here, not trusted.

options(warn = 1)
scratch_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad"

suppressPackageStartupMessages(library(devtools))
devtools::load_all(".", quiet = TRUE)
stopifnot(requireNamespace("statmod", quietly = TRUE))

proto_source <- normalizePath(file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"),
                              mustWork = TRUE)

# ---------------------------------------------------------------------------
# 1. Bernoulli fixture -- identical construction to the ground-truth probe
#    (seed 20260725, N = 60, T = 5, q = 2, n_trials = 1).
# ---------------------------------------------------------------------------
seed <- 20260725L
set.seed(seed)
q_true <- 2L; N <- 60L; Tt <- 5L; n_trials_k <- 1L

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
eta_true <- drop(X %*% beta_true) + rowSums(
  Lambda_true[trait_idx, , drop = FALSE] * score_true[unit_idx, , drop = FALSE]
)
y <- stats::rbinom(N * Tt, n_trials_k, stats::plogis(eta_true))
n_trials <- rep.int(n_trials_k, N * Tt)
cat(sprintf("Fixture: seed=%d Bernoulli(n_trials=1) N=%d T=%d q=%d cells=%d\n",
            seed, N, Tt, q_true, N * Tt))
cat("y table:\n"); print(table(y))

df <- data.frame(y = y,
                 trait = factor(sprintf("t%02d", trait_idx)),
                 unit = factor(sprintf("u%03d", unit_idx)))

# ---------------------------------------------------------------------------
# 2. Brute-force TRUE marginal log-likelihood machinery (verbatim reuse of the
#    va-elbo-bisect2.R / ground-truth-probe construction, H-ladder).
# ---------------------------------------------------------------------------
softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
Xrow_by_trait <- X[1:Tt, , drop = FALSE]
stopifnot(all(vapply(seq_len(N), function(i)
  all(X[((i - 1L) * Tt + 1L):(i * Tt), ] == Xrow_by_trait), logical(1))))
## n = 1 => log C(n, y) = 0 exactly for y in {0, 1}.
log_choose_vec <- lgamma(n_trials_k + 1) - lgamma(y + 1) -
  lgamma(n_trials_k - y + 1)
stopifnot(max(abs(log_choose_vec)) < 1e-12)

brute_force_true_loglik <- function(beta_v, Lambda_m, H_bf) {
  gh <- statmod::gauss.quad(H_bf, kind = "hermite")
  u1 <- sqrt(2) * gh$nodes
  logw1 <- log(gh$weights / sqrt(pi))
  lin_fixed_by_trait <- drop(Xrow_by_trait %*% beta_v)
  total <- 0
  for (i in seq_len(N)) {
    y_i <- y[((i - 1L) * Tt + 1L):(i * Tt)]
    log_integrand <- matrix(-Inf, H_bf, H_bf)
    for (a in seq_len(H_bf)) {
      for (b in seq_len(H_bf)) {
        eta_t <- lin_fixed_by_trait + drop(Lambda_m %*% c(u1[a], u1[b]))
        log_integrand[a, b] <-
          sum(y_i * eta_t - n_trials_k * softplus(eta_t)) + logw1[a] + logw1[b]
      }
    }
    mx <- max(log_integrand)
    total <- total + mx + log(sum(exp(log_integrand - mx)))
  }
  total
}

truth_with_ladder <- function(beta_v, Lambda_m, label,
                              H_ladder = c(31L, 61L, 101L, 151L)) {
  vals <- vapply(H_ladder, function(H) {
    v <- brute_force_true_loglik(beta_v, Lambda_m, H)
    cat(sprintf("  [%s] H=%3d : true logLik = %.12f\n", label, H, v))
    v
  }, numeric(1))
  names(vals) <- paste0("H", H_ladder)
  spread <- max(vals[-1]) - min(vals[-1])
  cat(sprintf("  [%s] ladder spread over H in {61,101,151} = %.3e\n",
              label, spread))
  list(value = unname(vals[length(vals)]), ladder = vals, spread = spread)
}

# ---------------------------------------------------------------------------
# 3. VA prototype fit on the Bernoulli fixture (the previously-blocked case).
# ---------------------------------------------------------------------------
cat("\n== VA prototype (.va_r3_fit), Bernoulli, q = 2, H = 61 ==\n")
va_time <- system.time({
  va_fit <- .va_r3_fit(
    y = y, n_trials = n_trials, X = X,
    unit_id = unit_idx, trait_id = trait_idx, q = q_true,
    N = N, T = Tt, family = "binomial", link = "logit",
    H = 61L, rank_source = "fixed_fixture", source = proto_source,
    control = list(eval.max = 3000L, iter.max = 3000L)
  )
})
cat("VA status:", va_fit$status, "| elapsed:", va_time[["elapsed"]], "s\n")
str(va_fit$health)
elbo_va <- -va_fit$best$objective
beta_va <- unname(va_fit$best$par[names(va_fit$best$par) == "beta"])
Lambda_va <- va_fit$report$Lambda
cat(sprintf("ELBO at the VA optimum = %.10f\n", elbo_va))
cat("beta_VA:", sprintf("%.6f", beta_va), "\n")
cat("Lambda_VA:\n"); print(Lambda_va)

cat("\n== Brute-force TRUE log p(y; theta_VA) at the VA's OWN theta ==\n")
truth_va <- truth_with_ladder(beta_va, Lambda_va, "theta_VA")

# ---------------------------------------------------------------------------
# 4. gllvmTMB Laplace on the same fixture, and truth at ITS theta.
# ---------------------------------------------------------------------------
cat("\n== gllvmTMB Laplace (same fixture, rr()-only latent) ==\n")
fit_gt <- gllvmTMB(
  stats::as.formula(paste0(
    "y ~ 0 + trait + latent(0 + trait | unit, d = ", q_true, ", unique = FALSE)")),
  data = df, family = stats::binomial(), unit = "unit",
  control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
)
ll_laplace <- -fit_gt$opt$objective
opt_par <- fit_gt$opt$par
beta_lap <- unname(opt_par[names(opt_par) == "b_fix"])
Lambda_lap <- fit_gt$report$Lambda_B
Lambda_lap[row(Lambda_lap) < col(Lambda_lap)] <- 0
cat(sprintf("Laplace logLik = %.10f | convergence = %d\n",
            ll_laplace, fit_gt$opt$convergence))

cat("\n== Brute-force TRUE log p(y; theta_Laplace) at the LAPLACE theta ==\n")
truth_lap <- truth_with_ladder(beta_lap, Lambda_lap, "theta_Lap")

# ---------------------------------------------------------------------------
# 5. Apples-to-apples: the VA objective evaluated at the LAPLACE theta, so the
#    ELBO gap and the Laplace error are measured at the SAME parameter point.
# ---------------------------------------------------------------------------
cat("\n== ELBO at the FIXED Laplace theta (same-point comparison) ==\n")
va_fixed <- .va_r3_fit(
  y = y, n_trials = n_trials, X = X,
  unit_id = unit_idx, trait_id = trait_idx, q = q_true,
  N = N, T = Tt, family = "binomial", link = "logit",
  H = 61L, rank_source = "fixed_fixture", source = proto_source,
  fixed_global = list(beta = beta_lap,
                      theta_rr = .va_r3_pack_theta_rr(Lambda_lap, q_true)),
  control = list(eval.max = 3000L, iter.max = 3000L)
)
cat("fixed-theta VA status:", va_fixed$status, "\n")
elbo_at_lap <- -va_fixed$best$objective
cat(sprintf("ELBO at theta_Laplace = %.10f\n", elbo_at_lap))

# ---------------------------------------------------------------------------
# 6. The scoreboard.
# ---------------------------------------------------------------------------
cat("\n===================== SCOREBOARD (Bernoulli) =====================\n")
cat(sprintf("TRUTH  at theta_VA       : %.10f\n", truth_va$value))
cat(sprintf("ELBO   at theta_VA       : %.10f\n", elbo_va))
cat(sprintf("  ELBO - TRUTH (same th) : %+.10f  <- must be <= 0\n",
            elbo_va - truth_va$value))
cat(sprintf("TRUTH  at theta_Laplace  : %.10f\n", truth_lap$value))
cat(sprintf("Laplace at theta_Laplace : %.10f\n", ll_laplace))
cat(sprintf("  LAPLACE - TRUTH        : %+.10f\n",
            ll_laplace - truth_lap$value))
cat(sprintf("ELBO   at theta_Laplace  : %.10f\n", elbo_at_lap))
cat(sprintf("  ELBO - TRUTH (same th) : %+.10f  <- must be <= 0\n",
            elbo_at_lap - truth_lap$value))
cat(sprintf("max true logLik seen     : %.10f (at %s)\n",
            max(truth_va$value, truth_lap$value),
            if (truth_va$value >= truth_lap$value) "theta_VA" else "theta_Laplace"))
cat("=================================================================\n")

# ---------------------------------------------------------------------------
# 7. Negative test: the separation guard must refuse, with a typed message.
# ---------------------------------------------------------------------------
cat("\n== Separation guard: refusals and non-refusals ==\n")
try_fit <- function(yy) {
  tryCatch({
    .va_r3_validate_data(y = yy, n_trials = n_trials, X = X,
                         unit_id = unit_idx, trait_id = trait_idx,
                         q = q_true, N = N, T = Tt)
    "ACCEPTED"
  }, error = function(e) paste("REFUSED:", conditionMessage(e)))
}
y_zero <- y; y_zero[trait_idx == 1L] <- 0L        # trait 1 all zeros
y_one  <- y; y_one[trait_idx == 1L]  <- 1L        # trait 1 all ones
y_edge <- y_zero; y_edge[which(trait_idx == 1L)[1]] <- 1L  # 1/60: finite MLE
cat("separated (trait 1 all 0) ->", try_fit(y_zero), "\n\n")
cat("separated (trait 1 all 1) ->", try_fit(y_one), "\n\n")
cat("extreme but finite (trait 1 = 1/60) ->", try_fit(y_edge), "\n")
cat("unmodified fixture ->", try_fit(y), "\n")
sep <- try_fit(y_zero)

cat("\n== Regression check: n_trials >= 2 still accepted (validator only) ==\n")
ok <- tryCatch({
  .va_r3_validate_data(y = pmin(y + 3L, 12L), n_trials = rep.int(12L, N * Tt),
                       X = X, unit_id = unit_idx, trait_id = trait_idx,
                       q = q_true, N = N, T = Tt)
  "accepted"
}, error = function(e) paste("REJECTED:", conditionMessage(e)))
cat("n_trials = 12 fixture ->", ok, "\n")

saveRDS(list(seed = seed, N = N, Tt = Tt, q = q_true,
             y = y, elbo_va = elbo_va, beta_va = beta_va,
             Lambda_va = Lambda_va, truth_va = truth_va,
             ll_laplace = ll_laplace, beta_lap = beta_lap,
             Lambda_lap = Lambda_lap, truth_lap = truth_lap,
             elbo_at_lap = elbo_at_lap,
             va_status = va_fit$status, va_health = va_fit$health,
             separation_message = sep),
        file.path(scratch_dir, "va-bernoulli-results.rds"))
cat("\nDONE.\n")
