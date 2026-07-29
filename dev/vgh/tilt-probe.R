## Toy-scale probe of the exponential-tilting / sufficient-statistic identity.
##
## CLAIM.  With no unit covariates (one covariate profile, K = 1 -- the pure
## ordination setting, and the setting of the simulation campaign), write
##
##   log p(y_i | u) = kappa_i + t_i'u - B(u) + c(y_i),
##      t_i = Lambda' D_phi^{-1} y_i  in R^d      <- data enters ONLY here
##      B(u) = sum_j b(c_j + lambda_j'u)/phi_j    <- contains no y at all
##
## Therefore  p(y_i) = exp(kappa_i + c(y_i)) * M_nu(t_i),  where nu(du) =
## exp(-B(u)) N(u; 0, I) du is ONE measure shared by every unit.  Discretise nu
## ONCE on a d-dimensional grid, and every unit's marginal log-likelihood is
##
##   log p(y_i) = kappa_i + c(y_i) + logsumexp_g ( log omega_g + t_i' u_g )
##
## i.e. ONE (n x d)(d x G) GEMM plus a log-sum-exp.  No per-unit mode-finding,
## no Hessian, no log-determinant, no AD.  If this is accurate it is not an
## approximation to Laplace -- it is the EXACT marginal likelihood, computed
## without Laplace.
##
## This probe checks the identity against a per-unit high-order reference, and
## checks where it BREAKS (the tilt-conditioning question, which is the crux).

set.seed(20260729)

gh1 <- function(Q) {                       # probabilists' 1-D Gauss-Hermite
  k <- seq_len(Q - 1L); J <- diag(0, Q)
  J[cbind(k, k+1L)] <- sqrt(k/2); J[cbind(k+1L, k)] <- sqrt(k/2)
  e <- eigen(J, symmetric = TRUE); o <- order(e$values)
  list(z = sqrt(2) * e$values[o], w = (e$vectors[1L, o])^2 / sum((e$vectors[1L, ])^2))
}

# d-dimensional product grid over N(0, tau^2 I), with importance weights so the
# rule still integrates against the N(0, I) prior.  tau > 1 widens the grid to
# cover strongly tilted posteriors -- this is the knob the crux depends on.
grid_nd <- function(Q, d, tau = 1) {
  r <- gh1(Q)
  nodes <- as.matrix(expand.grid(rep(list(r$z * tau), d)))
  lw <- rowSums(sapply(seq_len(d), function(k) log(r$w)[match(nodes[, k]/tau, r$z)]))
  # reweight from N(0,tau^2) to N(0,1):  w * dnorm(u,0,1)/dnorm(u,0,tau)
  lw <- lw + rowSums(-nodes^2/2 + nodes^2/(2*tau^2)) + d*log(tau)
  list(u = nodes, logw = lw)
}

## ---- simulate a Poisson GLLVM with NO covariates --------------------------
n <- 400L; m <- 25L; d <- 2L
Lam <- matrix(rnorm(m*d, 0, 0.55), m, d)
b0  <- rnorm(m, 1.0, 0.4)
U   <- matrix(rnorm(n*d), n, d)
Eta <- matrix(b0, n, m, byrow = TRUE) + U %*% t(Lam)
Y   <- matrix(rpois(n*m, exp(Eta)), n, m)

## ---- REFERENCE: per-unit d-dimensional quadrature, high order -------------
ref_loglik <- function(Y, b0, Lam, Q = 60L) {
  r <- gh1(Q)
  nodes <- as.matrix(expand.grid(rep(list(r$z), ncol(Lam))))
  lw <- rowSums(sapply(seq_len(ncol(Lam)), function(k) log(r$w)[match(nodes[,k], r$z)]))
  Etag <- matrix(b0, nrow(nodes), length(b0), byrow = TRUE) + nodes %*% t(Lam)
  out <- numeric(nrow(Y))
  for (i in seq_len(nrow(Y))) {
    lk <- lw + as.vector(Etag %*% Y[i, ]) - rowSums(exp(Etag)) - sum(lgamma(Y[i,]+1))
    mx <- max(lk); out[i] <- mx + log(sum(exp(lk - mx)))
  }
  out
}

## ---- TILTED: one shared grid, one GEMM ------------------------------------
tilt_loglik <- function(Y, b0, Lam, Q, tau) {
  g <- grid_nd(Q, ncol(Lam), tau)
  Etag <- matrix(b0, nrow(g$u), length(b0), byrow = TRUE) + g$u %*% t(Lam)
  logomega <- g$logw - rowSums(exp(Etag))        # -B(u_g), computed ONCE
  Tmat <- Y %*% Lam                              # n x d sufficient statistics
  S <- Tmat %*% t(g$u)                           # THE GEMM: n x G
  S <- sweep(S, 2L, logomega, "+")
  mx <- apply(S, 1L, max)
  kappa <- as.vector(Y %*% b0) - rowSums(lgamma(Y + 1))
  kappa + mx + log(rowSums(exp(S - mx)))
}

cat("Exponential-tilting identity vs per-unit reference (Poisson, d=2, n=400, m=25)\n\n")
ref <- ref_loglik(Y, b0, Lam, Q = 60L)
cat(sprintf("  reference total loglik (per-unit Q=60 grid): %.6f\n\n", sum(ref)))
cat(sprintf("  %4s %5s %16s %16s %10s\n", "Q", "tau", "max|per-unit err|",
            "total loglik err", "grid G"))
for (tau in c(1, 1.5, 2, 3)) {
  for (Q in c(20L, 40L, 60L)) {
    tl <- tilt_loglik(Y, b0, Lam, Q, tau)
    cat(sprintf("  %4d %5.1f %16.2e %16.2e %10d\n",
                Q, tau, max(abs(tl - ref)), sum(tl) - sum(ref), Q^2))
  }
}

## ---- TIMING: shared-grid GEMM vs per-unit loop ----------------------------
cat("\n  timing at Q=40, tau=2 (the accurate setting):\n")
t1 <- proc.time()[["elapsed"]]; invisible(tilt_loglik(Y, b0, Lam, 40L, 2)); t1 <- proc.time()[["elapsed"]] - t1
t2 <- proc.time()[["elapsed"]]; invisible(ref_loglik(Y, b0, Lam, 40L));    t2 <- proc.time()[["elapsed"]] - t2
cat(sprintf("    shared-grid (one GEMM) : %.4f s\n    per-unit loop          : %.4f s\n    ratio                  : %.1fx\n",
            t1, t2, t2/t1))

## ---- THE CRUX: how far does the tilt stretch? -----------------------------
Tm <- Y %*% Lam
cat(sprintf("\n  tilt magnitude ||t_i||: median %.1f, max %.1f  (mean count %.1f)\n",
            median(sqrt(rowSums(Tm^2))), max(sqrt(rowSums(Tm^2))), mean(Y)))
cat("  -- large ||t|| concentrates the tilted measure at the grid edge, which is\n")
cat("     where this identity is expected to fail.  Rerun with larger b0 to probe.\n")
