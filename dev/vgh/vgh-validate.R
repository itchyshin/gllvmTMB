## Validation ladder for the VGH engine.  Each check is designed to FAIL loudly
## if the mathematics in vgh-engine.R is wrong.
source("dev/vgh/vgh-engine.R")
`%||%` <- function(a, b) if (is.null(a)) b else a

pass <- function(tag, ok, detail = "") {
  cat(sprintf("%-4s %-46s %s\n", if (ok) "PASS" else "FAIL", tag, detail))
  if (!ok) assign("ANY_FAIL", TRUE, envir = .GlobalEnv)
}
ANY_FAIL <- FALSE

set.seed(20260729)

## ---------------------------------------------------------------------------
## CHECK 1 -- Gauss-Hermite rule integrates standard normal moments exactly.
## E[Z^k] for k = 0,2,4,6 should be 1, 1, 3, 15.
## ---------------------------------------------------------------------------
r <- vgh_gh_rule(15L)
mom_exact <- c(1, 1, 3, 15)
mom_gh <- sapply(c(0, 2, 4, 6), function(k) sum(r$w * r$z^k))
pass("GH rule: normal moments to k=6",
     max(abs(mom_gh - mom_exact)) < 1e-10,
     sprintf("max abs err %.2e", max(abs(mom_gh - mom_exact))))

## ---------------------------------------------------------------------------
## CHECK 2 -- the ONE-DIMENSIONAL COLLAPSE (C1) is real.
## Claim: for eta = c + lambda'u with u ~ N(a, A), E[b(eta)] equals the 1-D
## integral E[b(m + sZ)].  Test against brute-force d-dimensional Monte Carlo
## with a large sample, for d = 4 and the logit cumulant.
## ---------------------------------------------------------------------------
d <- 4L
lam <- rnorm(d); a <- rnorm(d)
Ahalf <- matrix(rnorm(d * d), d); A <- crossprod(Ahalf) / d + diag(0.3, d)
cc <- 0.4
m <- cc + sum(lam * a); s2 <- as.numeric(t(lam) %*% A %*% lam)
fam <- vgh_family("binomial")
B_1d <- vgh_moments(fam, matrix(m), matrix(s2), vgh_gh_rule(30L))$B

set.seed(1)
U <- matrix(rnorm(4e6 * d), ncol = d) %*% chol(A) + matrix(a, 4e6, d, byrow = TRUE)
B_mc <- mean(fam$b(cc + U %*% lam))
pass("C1: 1-D collapse == d-dim expectation (d=4)",
     abs(B_1d - B_mc) < 5e-4,
     sprintf("1D %.8f  MC %.8f  diff %.2e", B_1d, B_mc, abs(B_1d - B_mc)))

## ---------------------------------------------------------------------------
## CHECK 3 -- STEIN'S LEMMA (C2): dB/ds = s * E[b''(m + sZ)].
## Compare the analytic identity against a central finite difference in s.
## This is the identity the entire closed-form A_i update rests on.
## ---------------------------------------------------------------------------
rule <- vgh_gh_rule(30L)
Bs <- function(mm, ss) vgh_moments(fam, matrix(mm), matrix(ss^2), rule)$B
mm <- 0.7; ss <- 1.3; h <- 1e-5
fd <- (Bs(mm, ss + h) - Bs(mm, ss - h)) / (2 * h)
analytic <- ss * vgh_moments(fam, matrix(mm), matrix(ss^2), rule)$B2
pass("C2: Stein  dB/ds = s E[b'']",
     abs(fd - analytic) < 1e-7,
     sprintf("fd %.10f  stein %.10f  diff %.2e", fd, analytic, abs(fd - analytic)))

## ---------------------------------------------------------------------------
## CHECK 4 -- GAUSSIAN EXACTNESS.  For the gaussian-identity GLLVM the true
## posterior of u_i IS Gaussian, so the variational family CONTAINS it and the
## ELBO is TIGHT: at the optimum ELBO must equal the exact marginal
## log-likelihood  sum_i log N(y_i ; X beta, Lambda Lambda' + diag(phi)).
## If this fails, the ELBO or the KL term is wrong.
## ---------------------------------------------------------------------------
n <- 300L; m_resp <- 12L; dtrue <- 2L
Lam0 <- matrix(rnorm(m_resp * dtrue, 0, 0.8), m_resp, dtrue)
b0 <- rnorm(m_resp)
phi0 <- runif(m_resp, 0.5, 1.5)
U0 <- matrix(rnorm(n * dtrue), n, dtrue)
Yg <- matrix(b0, n, m_resp, byrow = TRUE) + U0 %*% t(Lam0) +
  matrix(rnorm(n * m_resp), n, m_resp) * matrix(sqrt(phi0), n, m_resp, byrow = TRUE)
Xg <- matrix(1, n, 1)

fit_g <- vgh_fit(Yg, Xg, d = dtrue, family = "gaussian", maxit = 400, tol = 1e-12)

exact_ll <- function(Y, X, Beta, Lambda, phi) {
  S <- tcrossprod(Lambda) + diag(phi)
  Rr <- Y - X %*% Beta
  ch <- chol(S)
  qf <- sum(backsolve(ch, t(Rr), transpose = TRUE)^2)
  -0.5 * (nrow(Y) * (ncol(Y) * log(2 * pi) + 2 * sum(log(diag(ch)))) + qf)
}
ll_exact <- exact_ll(Yg, Xg, fit_g$Beta, fit_g$Lambda, fit_g$phi)
rel <- abs(fit_g$elbo - ll_exact) / abs(ll_exact)
pass("C-exact: gaussian ELBO == exact marginal loglik",
     rel < 1e-8,
     sprintf("ELBO %.6f  exact %.6f  rel %.2e", fit_g$elbo, ll_exact, rel))

## ---------------------------------------------------------------------------
## CHECK 5 -- MONOTONICITY.  Block coordinate ascent with backtracking must
## never decrease the ELBO.  A single decrease means a block update is wrong.
## ---------------------------------------------------------------------------
fit_mono <- vgh_fit(Yg, Xg, d = dtrue, family = "gaussian", maxit = 60,
                    tol = 0, trace_elbo = TRUE)
dif <- diff(fit_mono$elbo_path)
pass("Monotone ELBO (gaussian)",
     all(dif > -1e-6),
     sprintf("min increment %.3e over %d sweeps", min(dif), length(dif)))

set.seed(7)
np <- 250L; mp <- 15L
Lp <- matrix(rnorm(mp * 2, 0, 0.6), mp, 2)
bp <- rnorm(mp, 0.5, 0.4)
Up <- matrix(rnorm(np * 2), np, 2)
Yp <- matrix(rpois(np * mp, exp(matrix(bp, np, mp, byrow = TRUE) + Up %*% t(Lp))),
             np, mp)
fit_p <- vgh_fit(Yp, matrix(1, np, 1), d = 2, family = "poisson", maxit = 60,
                 tol = 0, trace_elbo = TRUE)
difp <- diff(fit_p$elbo_path)
pass("Monotone ELBO (poisson)",
     all(difp > -1e-6),
     sprintf("min increment %.3e", min(difp)))

set.seed(11)
nb <- 300L; mb <- 15L
Lb <- matrix(rnorm(mb * 2, 0, 0.9), mb, 2)
bb <- rnorm(mb, 0, 0.5)
Ub <- matrix(rnorm(nb * 2), nb, 2)
Yb <- matrix(rbinom(nb * mb, 1,
       stats::plogis(matrix(bb, nb, mb, byrow = TRUE) + Ub %*% t(Lb))), nb, mb)
fit_b <- vgh_fit(Yb, matrix(1, nb, 1), d = 2, family = "binomial", maxit = 60,
                 tol = 0, trace_elbo = TRUE)
difb <- diff(fit_b$elbo_path)
pass("Monotone ELBO (binomial-logit, GH)",
     all(difb > -1e-6),
     sprintf("min increment %.3e", min(difb)))

## ---------------------------------------------------------------------------
## CHECK 6 -- QUADRATURE ORDER.  How many GH nodes do we actually need for the
## logit cumulant?  Compare B, B1, B2 at Q against a Q = 80 reference over a
## grid of (m, s) covering realistic and extreme values.
## ---------------------------------------------------------------------------
grid <- expand.grid(m = seq(-6, 6, by = 0.5), s = c(0.25, 0.5, 1, 2, 4))
ref <- vgh_moments(fam, matrix(grid$m), matrix(grid$s^2), vgh_gh_rule(80L))
cat("\n  GH order study (binomial-logit cumulant, vs Q=80 reference)\n")
cat("     Q     max|dB|     max|dB1|    max|dB2|\n")
for (Qq in c(5, 9, 11, 15, 21, 31)) {
  ap <- vgh_moments(fam, matrix(grid$m), matrix(grid$s^2), vgh_gh_rule(Qq))
  cat(sprintf("  %4d   %.3e   %.3e   %.3e\n", Qq,
              max(abs(ap$B - ref$B)), max(abs(ap$B1 - ref$B1)),
              max(abs(ap$B2 - ref$B2))))
}

## ---------------------------------------------------------------------------
## CHECK 7 -- EVA IS A TRUNCATION OF VGH.  The extended variational
## approximation replaces E[b(m + sZ)] by the second-order Taylor expansion
## b(m) + (s^2/2) b''(m).  If that claim is right, EVA's error is exactly the
## tail of the Taylor series and must grow like s^4 * b''''(m).  Quantify it --
## this tells us WHEN exact quadrature buys accuracy and when it does not.
## ---------------------------------------------------------------------------
eva_B <- function(mm, s2) fam$b(mm) + 0.5 * s2 * fam$b2(mm)
cat("\n  EVA (2nd-order Taylor) error vs exact quadrature, logit cumulant\n")
cat("      s     max|EVA - exact|   at m\n")
for (sv in c(0.25, 0.5, 1, 1.5, 2, 3, 4)) {
  mg <- seq(-6, 6, by = 0.05)
  ex <- vgh_moments(fam, matrix(mg), matrix(rep(sv^2, length(mg))), vgh_gh_rule(80L))$B
  ev <- eva_B(mg, sv^2)
  k <- which.max(abs(ev - ex))
  cat(sprintf("  %5.2f   %.6f          %+.2f\n", sv, max(abs(ev - ex)), mg[k]))
}

## ---------------------------------------------------------------------------
## CHECK 8 -- PARAMETER RECOVERY.  Loadings are identified only up to rotation,
## so compare Lambda Lambda' (rotation invariant) and Procrustes-aligned Lambda.
## ---------------------------------------------------------------------------
recov <- function(Ltrue, Lhat) {
  sv <- svd(crossprod(Ltrue, Lhat))
  Rot <- tcrossprod(sv$v, sv$u)
  list(aligned = Lhat %*% t(Rot),
       cov_relerr = norm(tcrossprod(Lhat) - tcrossprod(Ltrue), "F") /
                    norm(tcrossprod(Ltrue), "F"))
}
## NOTE: fit_p and fit_b above were run with maxit = 60, tol = 0 deliberately,
## to expose every ELBO increment for the monotonicity checks.  They are NOT
## converged, so they must not be used to judge recovery -- doing so reports a
## failure of the test harness as if it were a failure of the engine.  Refit to
## convergence here.
fit_gc <- fit_g                                        # already tol = 1e-12
fit_pc <- vgh_fit(Yp, matrix(1, np, 1), d = 2, family = "poisson",
                  maxit = 500, tol = 1e-10)
fit_bc <- vgh_fit(Yb, matrix(1, nb, 1), d = 2, family = "binomial",
                  maxit = 500, tol = 1e-10)

rg <- recov(Lam0, fit_gc$Lambda)
pass("Recovery: gaussian Lambda Lambda' rel err < 0.15",
     rg$cov_relerr < 0.15, sprintf("rel Frobenius err %.4f", rg$cov_relerr))
rp <- recov(Lp, fit_pc$Lambda)
pass("Recovery: poisson Lambda Lambda' rel err < 0.35",
     rp$cov_relerr < 0.35,
     sprintf("rel Frobenius err %.4f (%d sweeps)", rp$cov_relerr, fit_pc$sweeps))
rb <- recov(Lb, fit_bc$Lambda)
## Binomial is REPORTED, NOT GATED, on purpose.  It is the weakest cell: n = 300,
## m = 15 Bernoulli.  Design 102's 2,304-attempt campaign found VA loading-
## covariance relative error 0.67-3.36 at N = 240 for sparse binary, so a gate
## here would encode an expectation the method has never met.
cat(sprintf("  (binomial Lambda Lambda' rel Frobenius err %.4f, %d sweeps -- reported, not gated)\n",
            rb$cov_relerr, fit_bc$sweeps))

cat("\n")
if (ANY_FAIL) { cat("RESULT: at least one check FAILED\n"); quit(status = 1) }
cat("RESULT: all gated checks passed\n")
