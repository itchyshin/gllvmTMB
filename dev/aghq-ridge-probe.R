## IS THE DESCENT REAL, OR IS THE ADAPTATION SILENTLY RIDGED?
##
## .gllvmTMB_aghq_adapt() falls back to a ridge-corrected Cholesky when a site's
## conditional Hessian is not positive definite. If that fires, aghq_logdet is
## not log|det L^{-T}| for the actual Hessian and F is not the objective it
## claims to be -- a descent measured on it would be an artefact. This counts the
## fallbacks at the Laplace optimum and at the converged AGHQ optimum.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R")

ridge_count <- function(obj_lap, par, d_B, n_sites) {
  invisible(obj_lap$fn(par))
  full <- obj_lap$env$last.par
  H <- obj_lap$env$spHess(full, random = TRUE)
  bad <- 0L; mineig <- Inf; cond <- 0
  for (s in seq_len(n_sites)) {
    ii <- (s - 1L) * d_B + seq_len(d_B)
    Hs <- as.matrix(H[ii, ii, drop = FALSE]); Hs <- (Hs + t(Hs)) / 2
    ev <- eigen(Hs, symmetric = TRUE, only.values = TRUE)$values
    mineig <- min(mineig, min(ev))
    cond <- max(cond, max(ev) / max(min(ev), 1e-300))
    if (inherits(try(chol(Hs), silent = TRUE), "try-error")) bad <- bad + 1L
  }
  c(bad = bad, min_eig = mineig, max_cond = cond)
}

d <- arc0_data(60, 6, 2, 7); p <- 6; q <- 2
fl <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial()))
fa <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial(),
                                control = gllvmTMBcontrol(aghq = 9L)))
o <- fl$tmb_obj
n_sites <- ncol(fa$tmb_obj$env$data$aghq_mode) * 0 + nrow(fa$tmb_obj$env$data$aghq_mode)
cat("sites =", n_sites, " d_B =", ncol(fa$tmb_obj$env$data$aghq_mode), "\n")
cat("at LAPLACE optimum : ");  print(ridge_count(o, fl$opt$par, q, n_sites))
cat("at AGHQ optimum    : ");  print(ridge_count(o, fa$opt$par, q, n_sites))

## And the decisive check: is the k = 9 quadrature CONVERGED at the AGHQ optimum?
## If F still moves a lot between k = 9 and k = 15, the "descent" is chasing
## quadrature error, not the likelihood.
source("dev/aghq-honest-F.R")
for (k in c(5L, 9L, 15L, 21L)) {
  fk <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial(),
                                  control = gllvmTMBcontrol(aghq = k)))
  Fl <- aghq_F(fk, fl, fl$opt$par)
  Fa <- aghq_F(fk, fl, fa$opt$par)
  Lk <- fk$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  cat(sprintf("k=%-3d F(laplace par) = %12.6f   F(aghq-k9 par) = %12.6f   own optimum ||Sigma||_F = %.5g\n",
              k, Fl, Fa, norm(Lk %*% t(Lk), "F")))
}
