suppressMessages({library(TMB); library(Matrix)})
setwd("/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde")
V3 <- "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3"
s <- readRDS(file.path(V3, "v2-materialized-state.rds")); d <- s$data
dyn.load("src/gllvmTMB.so")
obj <- MakeADFun(data = d, parameters = s$parameters, map = s$map,
                 random = s$random, DLL = "gllvmTMB", silent = TRUE)
th <- unname(s$theta)
f  <- obj$fn(th)
cat(sprintf("replay objective diff: %.3e   (provenance gate)\n", abs(f - s$objective)))

## plan step 1: close the name check positionally
nm <- unname(names(obj$par))
po <- sub("\\[[0-9]+\\]$", "", as.character(s$parameter_order))
cat("obj$par blocks:", paste(unique(nm), collapse = ", "), "\n")
cat("positional block match vs parameter_order:", identical(nm, po), "\n\n")

r   <- obj$report(obj$env$last.par)
eta <- as.vector(r$eta)
G   <- d$Z_spde_lat[, 2] == 1
mu  <- exp(eta)                       # GBIF branch: Poisson, log link
X   <- d$X_fix

cat("=== S1 FALSIFIER: I_s at the fitted Laplace modes ===\n")
I <- numeric(3)
for (k in 1:3) {
  idx  <- which(G & X[, k] == 1)
  b    <- X[idx, 9 + k]
  I[k] <- sum(mu[idx] * b^2)
  cat(sprintf("  sp%d: sum(mu) = %8.2f   I = %8.2f\n", k, sum(mu[idx]), I[k]))
}
cat(sprintf("\n  MIN AT MODES = %.2f     bar = 130  ->  %s\n",
            min(I), if (min(I) >= 130) "MEETS" else "FAILS"))
cat(sprintf("  earlier estimates:  RE=0  125.30   |  prior-corrected  142.06\n"))

## how much of the predictor does the latent actually contribute on GBIF rows?
eta_fix <- as.vector(X %*% s$theta[1:12]) + d$offset_vec
cat(sprintf("\n  latent contribution to eta on GBIF rows: sd = %.4f, range [%.3f, %.3f]\n",
            sd(eta[G] - eta_fix[G]), min(eta[G] - eta_fix[G]), max(eta[G] - eta_fix[G])))
saveRDS(list(I = I, eta = eta, G = G), "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/5175b5d1-4ea3-4ee8-92c1-a3642cba0648/scratchpad/s1-result.rds")
suppressMessages({library(TMB); library(Matrix)})
setwd("/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde")
V3 <- "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3"
s <- readRDS(file.path(V3, "v2-materialized-state.rds")); d <- s$data
dyn.load("src/gllvmTMB.so")
obj <- MakeADFun(data = d, parameters = s$parameters, map = s$map,
                 random = s$random, DLL = "gllvmTMB", silent = TRUE)
th <- unname(s$theta); stopifnot(abs(obj$fn(th) - s$objective) < 1e-8)

mkH <- function(scale) {
  hs <- scale * pmax(1, abs(th))
  H <- matrix(0, 22, 22)
  for (j in 1:22) {
    tp <- th; tp[j] <- tp[j] + hs[j]; tm <- th; tm[j] <- tm[j] - hs[j]
    H[, j] <- (as.vector(obj$gr(tp)) - as.vector(obj$gr(tm))) / (2 * hs[j])
  }
  (H + t(H)) / 2
}

cat("=== is the negative eigenvalue REAL or finite-difference noise? ===\n")
cat("  step        min eigenvalue      2nd smallest     max\n")
Hs <- list()
for (sc in c(1e-3, 1e-4, .Machine$double.eps^(1/3), 1e-6)) {
  H <- mkH(sc); Hs[[format(sc)]] <- H
  ev <- sort(eigen(H, symmetric = TRUE)$values)
  cat(sprintf("  %-10.3e  %+.6e   %+.6e   %.4e\n", sc, ev[1], ev[2], max(ev)))
}

cat("\n=== spectrum at the design step (eps^(1/3)) ===\n")
H <- Hs[[format(.Machine$double.eps^(1/3))]]
e <- eigen(H, symmetric = TRUE); ev <- sort(e$values)
cat("  five SMALLEST eigenvalues:\n"); print(signif(ev[1:5], 5))
cat(sprintf("  n negative: %d of 22\n", sum(ev < 0)))

## characterise the near-null direction properly
vmin <- e$vectors[, which.min(e$values)]
lam  <- s$theta[20:22]
u <- rep(0, 22); u[16] <- 1; u[20:22] <- lam;  u <- u/sqrt(sum(u^2))
cat(sprintf("\n  |cos(vmin, u-direction)| = %.4f\n", abs(sum(vmin * u))))
cat(sprintf("  weight of vmin on coords 20:22 (GBIF slope loadings) = %.4f\n", sum(vmin[20:22]^2)))
cat(sprintf("  weight of vmin on coord 16 (log_kappa)               = %.4f\n", vmin[16]^2))
cat(sprintf("  weight of vmin on coords 17:19 (intercept loadings)  = %.4f\n", sum(vmin[17:19]^2)))

## does the near-null direction change Sigma = lambda lambda^T ?
dl <- vmin[20:22]
S0 <- lam %*% t(lam)
S1 <- (lam + 1e-4*dl) %*% t(lam + 1e-4*dl)
cat(sprintf("\n  relative change in Sigma along vmin (eps 1e-4): %.4e\n",
            max(abs(S1 - S0))/max(abs(S0))))
cat(sprintf("  |lambda_slope| = %.6f   (intercept block |lambda| = %.4f)\n",
            sqrt(sum(lam^2)), sqrt(sum(s$theta[17:19]^2))))
