## dev/va-speed/32-va-vs-quadrature-spread.R
##
## MEASUREMENT ONLY. Question: does VA (GH tier) UNDERSTATE the per-unit
## latent posterior spread, relative to the exact conditional posterior
## p(z_i | y_i, theta_hat) computed by direct 1-D numerical quadrature at
## the SAME theta_hat the VA fit converged to?
##
## Regime is deliberately tiny (per the task's hard compute constraint):
## N = 30 units, T = 6 traits, q = 1 latent dimension, Poisson-log family,
## eval_method = "gh" (the shipped default tier -- NOT Albert-Chib, where
## the variational covariance is already proven data-independent, commit
## 07af7df3). One seed, one fit, seconds.
##
## Method: because q = 1 and the model's likelihood factorises across units
## given theta = (beta, theta_rr) -- p(y, z | theta) = prod_i p(z_i) prod_j
## p(y_ij | z_i, theta) -- the exact conditional posterior for unit i is a
## clean 1-D integral:
##   p(z_i | y_i, theta_hat) propto N(z_i; 0, 1) * prod_j Poisson(y_ij; exp(beta_j + theta_rr_j * z_i))
## This is evaluated on a fine fixed grid (h = 0.002 over [-10, 10]) and its
## mean/SD are read out by direct (Riemann-sum) numerical integration -- no
## Laplace/normal approximation, no MCMC, exact to grid resolution. theta is
## held FIXED at the VA point estimate throughout: this isolates the
## q-approximation itself from estimation error in theta (see
## what_this_does_not_show in the caller's report).
##
## No campaign. No promotion. default_tier stays "gh"; nothing here touches
## the integration fence. Results stay local (D-50).
Sys.setenv(NOT_CRAN = "true")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
cat("== load_all done", format(Sys.time(), "%H:%M:%S"), "in", getwd(), "==\n")

elapsed <- function() proc.time()[["elapsed"]]

## ---------------------------------------------------------------------
## Regime
## ---------------------------------------------------------------------
N <- 30L; T <- 6L; Q <- 1L
FAMILY <- "poisson"; LINK <- "log"
EVAL_METHOD <- "gh"
H_QUAD_VA <- 15L        # VA's own Gauss-Hermite order (internal to the fit)
SEED <- 20260803L
cat(sprintf("== regime: N=%d T=%d q=%d family=%s link=%s eval_method=%s seed=%d ==\n",
            N, T, Q, FAMILY, LINK, EVAL_METHOD, SEED))

## ---------------------------------------------------------------------
## DGP: Poisson-log, heterogeneous per-trait loadings (some traits near-flat,
## some steep) so units differ genuinely in how much information their own
## data carry about z_i -- the condition under which gllvm's own Poisson
## probe (this session's recon) found informative, non-constant VA spread.
## ---------------------------------------------------------------------
set.seed(SEED)
theta_true <- runif(T, 0.3, 1.3) * sample(c(-1, 1), T, TRUE)
beta_true  <- rnorm(T, 0, 0.3)
z_true     <- rnorm(N)
eta_true   <- outer(z_true, theta_true) + matrix(beta_true, N, T, byrow = TRUE)
Y <- matrix(rpois(N * T, lambda = exp(eta_true)), N, T)
cat(sprintf("y range [%d, %d], mean %.2f\n", min(Y), max(Y), mean(Y)))

unit_id  <- rep(seq_len(N), each = T)
trait_id <- rep(seq_len(T), times = N)
y_vec    <- as.numeric(t(Y))          # unit-major, matches unit_id/trait_id above
X <- unname(stats::model.matrix(~ 0 + factor(trait_id, levels = seq_len(T))))
n_trials <- rep(1L, length(y_vec))    # unused by the poisson family branch

## ---------------------------------------------------------------------
## Untimed warm-up: trigger the TMB DLL compile / first MakeADFun on a tiny
## throwaway call, outside all timing, per the task's instruction.
## ---------------------------------------------------------------------
## n_starts = 4L (the package default): the health gate requires >= 3
## healthy starts to agree before it will call a fit "healthy" (see
## fit$health$minimum_healthy_starts below) -- n_starts = 1L trivially fails
## that gate (objective_agreement can't be assessed from a single start), as
## a first run of this script found. Still seconds at this N/T.
N_STARTS <- 4L
cat("== warm-up fit (untimed, compiles the TMB template) ==\n")
invisible(gllvmTMB:::.va_r3_fit(
  y = y_vec, n_trials = n_trials, X = X, unit_id = unit_id, trait_id = trait_id,
  q = Q, family = FAMILY, link = LINK, eval_method = EVAL_METHOD,
  n_starts = N_STARTS, H = H_QUAD_VA, control = list(eval.max = 300L, iter.max = 200L)
))
cat("== warm-up done ==\n")

## ---------------------------------------------------------------------
## Timed fit.
## ---------------------------------------------------------------------
t0 <- elapsed()
fit <- gllvmTMB:::.va_r3_fit(
  y = y_vec, n_trials = n_trials, X = X, unit_id = unit_id, trait_id = trait_id,
  q = Q, family = FAMILY, link = LINK, eval_method = EVAL_METHOD,
  n_starts = N_STARTS, H = H_QUAD_VA, control = list(eval.max = 800L, iter.max = 500L)
)
t1 <- elapsed()
cat(sprintf("== fit done in %.3fs, status = %s, resolved eval_method = %s ==\n",
            t1 - t0, fit$status, fit$eval_method))
stopifnot(identical(fit$status, "healthy"))
stopifnot(identical(fit$eval_method, "gh"))

par <- fit$best$par
beta_hat  <- unname(par[names(par) == "beta"])
theta_hat <- unname(par[names(par) == "theta_rr"])
stopifnot(length(beta_hat) == T, length(theta_hat) == T)
cat("beta_hat: ", paste(sprintf("%.3f", beta_hat), collapse = ", "), "\n")
cat("theta_hat:", paste(sprintf("%.3f", theta_hat), collapse = ", "), "\n")

va_scores <- as.numeric(fit$latent$scores[, 1])
va_se     <- as.numeric(fit$latent$se[, 1])
cat(sprintf("VA per-unit se: range [%.4f, %.4f], mean %.4f, sd(across units) %.4f\n",
            min(va_se), max(va_se), mean(va_se), stats::sd(va_se)))
cat(sprintf("  (a near-zero sd(across units) would reproduce the AC-tier constancy;\n"))
cat(sprintf("   this fit is eval_method=gh, so no such constancy is asserted a priori.)\n"))

## ---------------------------------------------------------------------
## Exact per-unit conditional posterior p(z_i | y_i, theta_hat) by direct
## 1-D quadrature (fine fixed grid, Riemann sum). theta HELD FIXED at
## theta_hat throughout -- see what_this_does_not_show.
## ---------------------------------------------------------------------
grid <- seq(-10, 10, by = 0.002)
h <- diff(grid)[1]
G <- length(grid)
eta_grid <- outer(grid, theta_hat) + matrix(beta_hat, G, T, byrow = TRUE)  # G x T
logprior <- stats::dnorm(grid, 0, 1, log = TRUE)

quad_mean <- numeric(N)
quad_sd   <- numeric(N)
for (i in seq_len(N)) {
  y_i <- Y[i, ]
  loglik <- rowSums(stats::dpois(matrix(rep(y_i, each = G), G, T), exp(eta_grid), log = TRUE))
  logpost <- loglik + logprior
  m <- max(logpost)
  w <- exp(logpost - m)
  Zc <- sum(w)
  mu <- sum(grid * w) / Zc
  v  <- sum((grid - mu)^2 * w) / Zc
  quad_mean[i] <- mu
  quad_sd[i]   <- sqrt(v)
}
cat(sprintf("Quadrature per-unit sd: range [%.4f, %.4f], mean %.4f, sd(across units) %.4f\n",
            min(quad_sd), max(quad_sd), mean(quad_sd), stats::sd(quad_sd)))

## Sanity check: VA point estimates m_i should track the quadrature
## posterior mean reasonably well if the fit converged sensibly.
cor_scores <- stats::cor(va_scores, quad_mean)
cat(sprintf("cor(VA m_i, quadrature posterior mean) = %.4f (sanity check, not the target metric)\n",
            cor_scores))

## ---------------------------------------------------------------------
## The actual question: ratio = VA se / quadrature sd.
## ---------------------------------------------------------------------
ratio <- va_se / quad_sd
cat("\n=== RESULT: ratio = VA_se / quadrature_sd, per unit ===\n")
cat(sprintf("N = %d units\n", N))
cat(sprintf("ratio: mean %.4f, median %.4f, sd %.4f, range [%.4f, %.4f]\n",
            mean(ratio), stats::median(ratio), stats::sd(ratio), min(ratio), max(ratio)))
cat(sprintf("n(ratio < 1) = %d / %d  (VA narrower than quadrature)\n", sum(ratio < 1), N))
cat(sprintf("n(ratio > 1) = %d / %d  (VA wider than quadrature)\n", sum(ratio > 1), N))
## One-sample test against ratio = 1 on log(ratio), purely descriptive at
## this N -- not a claim of a calibrated p-value at N = 30, single seed.
lr <- log(ratio)
tt <- stats::t.test(lr, mu = 0)
cat(sprintf("t.test(log(ratio), mu=0): mean log-ratio %.4f, 95%% CI [%.4f, %.4f], p = %.4g\n",
            mean(lr), tt$conf.int[1], tt$conf.int[2], tt$p.value))

cat("\nfull per-unit table (unit, y_sum, va_se, quad_sd, ratio):\n")
tab <- data.frame(unit = seq_len(N), y_sum = rowSums(Y),
                  va_se = round(va_se, 4), quad_sd = round(quad_sd, 4),
                  ratio = round(ratio, 4))
print(tab, row.names = FALSE)

cat("\n== script done", format(Sys.time(), "%H:%M:%S"), "==\n")
