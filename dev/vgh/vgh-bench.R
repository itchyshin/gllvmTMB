## Head-to-head: VGH (pure R) vs gllvmTMB Laplace (compiled TMB), gaussian.
## For a gaussian-identity GLLVM Laplace is EXACT and the VGH ELBO is exact
## (validate.R check C-exact: rel 3.76e-13 at tol = 1e-12 / 102 sweeps, falling to
## 1.26e-15 -- ~5 ulp -- run to convergence), so both optimise the SAME objective.
## CORRECTED 2026-07-30: this line read "1.3e-12". That figure was measured while
## vgh_fit() returned a $elbo stale by one sweep; 70% of it (5.11e-09 of 7.28e-09
## absolute) WAS the staleness, not an ELBO/likelihood discrepancy. Fixed engine
## reads 3.76e-13 on the identical DGP and seeds. NOTE the figure is TOLERANCE
## DEPENDENT -- always quote it with its tol, since quoting it bare is what let it
## be mistaken for a fixed property of the ELBO. The d_ll column below is NOT
## affected: exact_ll() at :53 recomputes from the returned parameters and never
## reads $elbo.
## Timing is therefore a fair fight, and the attained exact log-likelihood is
## reported as proof neither side wins by stopping early.
## Handicap runs AGAINST VGH: interpreted R vs compiled C++ with AD.
suppressPackageStartupMessages(library(gllvmTMB))
source("dev/vgh/vgh-engine.R")
set.seed(20260729)

sim <- function(n, m, d) {
  Lam <- matrix(rnorm(m*d, 0, 0.8), m, d); b0 <- rnorm(m)
  phi <- rep(1.0, m)                      # homoscedastic: both models can fit it
  U <- matrix(rnorm(n*d), n, d)
  list(Y = matrix(b0, n, m, byrow=TRUE) + U %*% t(Lam) +
         matrix(rnorm(n*m), n, m), Lambda = Lam)
}
exact_ll <- function(Y, mu, Lambda, phi) {
  S <- tcrossprod(Lambda) + diag(phi, length(phi))
  R <- sweep(Y, 2L, mu, "-"); ch <- chol(S)
  -0.5*(nrow(Y)*(ncol(Y)*log(2*pi) + 2*sum(log(diag(ch)))) +
        sum(backsolve(ch, t(R), transpose=TRUE)^2))
}
mkdf <- function(Y) { df <- as.data.frame(Y); names(df) <- paste0("t", seq_len(ncol(Y)))
  df$site <- factor(seq_len(nrow(Y))); df }
fit_la <- function(Y, d) {
  tn <- paste0("t", seq_len(ncol(Y)))
  fo <- stats::as.formula(sprintf("traits(%s) ~ 1 + latent(0 + trait | site, d = %d, unique = FALSE)",
                                  paste(tn, collapse=", "), d))
  suppressWarnings(gllvmTMB(fo, data = mkdf(Y), family = gaussian()))
}

cat("warm-up (untimed, absorbs any first-call/compile cost) ...\n")
w <- sim(60, 6, 2)
invisible(try(fit_la(w$Y, 2), silent=TRUE))
invisible(vgh_fit(w$Y, matrix(1,60,1), d=2, family="gaussian", maxit=20))
cat("done\n\n")

d <- 2L; m <- 20L
cat(sprintf("%6s %6s %10s %10s %9s %14s %14s %10s %7s\n",
            "n","m","LA_sec","VGH_sec","speedup","LA_logLik","VGH_logLik","d_ll","sweeps"))
res <- list()
for (n in c(200L, 500L, 1000L, 2000L, 4000L)) {
  D <- sim(n, m, d); Y <- D$Y
  t1 <- proc.time()[["elapsed"]]
  fl <- try(fit_la(Y, d), silent = TRUE)
  la_s <- proc.time()[["elapsed"]] - t1
  la_ll <- if (inherits(fl,"try-error")) NA_real_ else
           tryCatch(as.numeric(stats::logLik(fl)), error=function(e) NA_real_)
  t2 <- proc.time()[["elapsed"]]
  fv <- vgh_fit(Y, matrix(1,n,1), d=d, family="gaussian", maxit=1000, tol=1e-11)
  v_s <- proc.time()[["elapsed"]] - t2
  v_ll <- exact_ll(Y, as.vector(fv$Beta), fv$Lambda, fv$phi)
  cat(sprintf("%6d %6d %10.2f %10.2f %8.1fx %14.2f %14.2f %10.3f %7d\n",
              n, m, la_s, v_s, la_s/v_s, la_ll, v_ll, v_ll-la_ll, fv$sweeps))
  res[[length(res)+1L]] <- data.frame(n=n, m=m, la_sec=la_s, vgh_sec=v_s,
    speedup=la_s/v_s, la_ll=la_ll, vgh_ll=v_ll, d_ll=v_ll-la_ll, sweeps=fv$sweeps)
}
write.csv(do.call(rbind,res), "dev/vgh/vgh-bench-gaussian.csv", row.names=FALSE)
cat("\nd_ll > 0 => VGH attained a HIGHER exact log-likelihood than Laplace.\n")
