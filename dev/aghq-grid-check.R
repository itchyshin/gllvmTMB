## Independent derivation and validation of the adaptive-GH quadrature form.
##
## WHY THIS FILE EXISTS. The first interface contract told .aghq_grid() to fold the
## adaptive exp(u'u) correction into the returned log-weights. That was MY error as
## orchestrator, and it has two consequences, the second worse than the first:
##   1. The returned weights no longer integrate a standard normal to 1, so the
##      obvious self-test (Gaussian moments) fails by construction -- measured
##      E[1] = 4.22 at k=9, d=1, and the error GROWS with k because the outermost
##      node's exp(u^2) is ~9e5 at k=11.
##   2. More seriously, the object becomes UNVALIDATABLE by any simple independent
##      check. That is exactly how the four silently-vacuous verifications already
##      found in this project survived.
##
## THE CORRECTED FORM, in importance-sampling coordinates, which keeps the weights
## plain (they sum to 1 and reproduce Gaussian moments exactly) and moves the
## adaptation into the template where the per-site quantities live.
##
## Target, for one unit:
##     L = INTEGRAL exp(loglik(z)) * phi_d(z) dz          phi_d = N(0, I_d) density
## Let zhat = argmax [ loglik(z) + log phi(z) ], and H = -Hessian of that at zhat,
## with Cholesky H = L_c %*% t(L_c).  Take the proposal q(z) = N(zhat, H^{-1}).
## Substituting z = zhat + t(solve(L_c)) %*% zeta makes (z-zhat)' H (z-zhat) = zeta'zeta,
## so with STANDARD-NORMAL GH nodes zeta_j and weights w_j (sum w_j = 1):
##
##     log L = logsumexp_j [ log w_j + loglik(z_j)
##                           - 0.5*sum(z_j^2) + 0.5*sum(zeta_j^2)
##                           - sum(log(diag(L_c))) ]
##
## Every (2*pi) term cancels between phi and q. At k = 1 this reduces EXACTLY to the
## Laplace approximation (zeta = 0, w = 1), which is the k=1 golden test, and nothing
## in it can overflow the way exp(u^2) does.

## ---- plain standard-normal Gauss-Hermite grid (Golub-Welsch) ------------------
gh1 <- function(k) {
  i <- seq_len(k - 1L)
  J <- matrix(0, k, k)
  J[cbind(i, i + 1L)] <- sqrt(i / 2)
  J[cbind(i + 1L, i)] <- sqrt(i / 2)
  e <- eigen(J, symmetric = TRUE)
  o <- order(e$values)
  u <- e$values[o]                       # physicists' nodes
  w <- (e$vectors[1L, o]^2) * sqrt(pi)   # physicists' weights, sum = sqrt(pi)
  ## probabilists'/standard-normal scale: z = sqrt(2) u, weight w/sqrt(pi), sum = 1
  list(z = sqrt(2) * u, w = w / sqrt(pi))
}

aghq_grid_plain <- function(d, k) {
  g <- gh1(k)
  idx <- as.matrix(do.call(expand.grid, rep(list(seq_len(k)), d)))
  nodes <- matrix(g$z[idx], nrow = nrow(idx), ncol = d)
  logw  <- rowSums(matrix(log(g$w)[idx], nrow = nrow(idx), ncol = d))
  list(nodes = nodes, logw = logw)
}

## ---- CHECK 1: the grid is a valid standard-normal rule -----------------------
cat("=== CHECK 1: Gaussian moments (must be ~0 error, and NOT grow with k) ===\n")
for (k in c(3L, 5L, 7L, 9L, 11L)) {
  g <- aghq_grid_plain(1L, k); w <- exp(g$logw); z <- g$nodes[, 1]
  cat(sprintf("k=%2d  sum(w)-1=%+.2e  E[z^2]-1=%+.2e  E[z^4]-3=%+.2e\n",
              k, sum(w) - 1, sum(w * z^2) - 1, sum(w * z^4) - 3))
}
g2 <- aghq_grid_plain(2L, 9L)
cat(sprintf("d=2,k=9  sum(w)-1=%+.2e  E[z1^2 z2^2]-1=%+.2e\n\n",
            sum(exp(g2$logw)) - 1,
            sum(exp(g2$logw) * g2$nodes[, 1]^2 * g2$nodes[, 2]^2) - 1))

## ---- CHECK 2: the adaptive formula against a brute-force integral -------------
## A deliberately NON-Gaussian integrand, so Laplace is visibly wrong and the
## quadrature has something real to fix: T bernoulli-logit observations sharing one
## latent z. This is the per-site integral of the actual model, at q = 1.
loglik_site <- function(z, y, b, lam) sum(y * (b + lam * z) - log1p(exp(b + lam * z)))

aghq_site <- function(k, y, b, lam) {
  f  <- function(z) loglik_site(z, y, b, lam) + dnorm(z, log = TRUE)
  ## conditional mode and curvature, found independently of any package code
  op <- optimize(function(z) -f(z), interval = c(-40, 40), tol = 1e-12)
  zh <- op$minimum
  h  <- 1e-4
  H  <- -(f(zh + h) - 2 * f(zh) + f(zh - h)) / h^2      # scalar Hessian of -f
  Lc <- sqrt(H)
  g  <- aghq_grid_plain(1L, k)
  zeta <- g$nodes[, 1]
  zj   <- zh + zeta / Lc                                 # L^{-T} zeta, scalar case
  br   <- g$logw + vapply(zj, loglik_site, 0, y = y, b = b, lam = lam) -
          0.5 * zj^2 + 0.5 * zeta^2 - log(Lc)
  m <- max(br); m + log(sum(exp(br - m)))
}

set.seed(1)
y <- rbinom(4L, 1L, 0.5); b <- 0.3; lam <- 2.5
truth <- log(integrate(function(z) exp(vapply(z, loglik_site, 0, y = y, b = b, lam = lam)) *
                         dnorm(z), -Inf, Inf, rel.tol = 1e-12)$value)
cat("=== CHECK 2: adaptive AGHQ vs stats::integrate() oracle ===\n")
cat(sprintf("brute-force log L = %.12f\n", truth))
for (k in c(1L, 3L, 5L, 7L, 9L, 15L, 25L))
  cat(sprintf("  k=%2d  log L = %.12f   error = %+.3e\n",
              k, aghq_site(k, y, b, lam), aghq_site(k, y, b, lam) - truth))

## ---- CHECK 3: k = 1 must BE the Laplace approximation ------------------------
f  <- function(z) loglik_site(z, y, b, lam) + dnorm(z, log = TRUE)
op <- optimize(function(z) -f(z), interval = c(-40, 40), tol = 1e-12); zh <- op$minimum
h <- 1e-4; H <- -(f(zh + h) - 2 * f(zh) + f(zh - h)) / h^2
lap <- f(zh) + 0.5 * log(2 * pi) - 0.5 * log(H)
cat(sprintf("\n=== CHECK 3: k=1 vs closed-form Laplace ===\n  Laplace = %.12f\n  k=1     = %.12f\n  diff    = %+.3e  (must be ~0)\n",
            lap, aghq_site(1L, y, b, lam), aghq_site(1L, y, b, lam) - lap))

## ---- CHECK 4: the test can fail ----------------------------------------------
cat(sprintf("\n=== CHECK 4: deliberately wrong grid (weights unnormalised) ===\n"))
bad <- local({
  g <- aghq_grid_plain(1L, 9L); g$logw <- g$logw + 1     # break normalisation
  zeta <- g$nodes[, 1]; Lc <- sqrt(H); zj <- zh + zeta / Lc
  br <- g$logw + vapply(zj, loglik_site, 0, y = y, b = b, lam = lam) -
        0.5 * zj^2 + 0.5 * zeta^2 - log(Lc)
  m <- max(br); m + log(sum(exp(br - m)))
})
cat(sprintf("  broken k=9 error = %+.3e  (must be LARGE, else the check is vacuous)\n",
            bad - truth))
