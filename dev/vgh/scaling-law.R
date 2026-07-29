## THE decisive measurement: what is the scaling exponent in n?
## Mission control (640 cells, 2026-07-26/27) measured the existing VA as
## "roughly quadratic in n against Laplace's linear", not completing beyond
## n ~ 2500.  The block-coordinate architecture never optimises the per-unit
## variational parameters, so it should be LINEAR.  Fit the exponent and see.
## Binomial-logit, so Gauss-Hermite actually fires (unlike the gaussian arm).
suppressPackageStartupMessages(library(gllvmTMB))
source("dev/vgh/vgh-engine.R")
set.seed(20260729)

sim_binom <- function(n, m, d) {
  Lam <- matrix(rnorm(m*d, 0, 0.7), m, d); b0 <- rnorm(m, 0, 0.5)
  U <- matrix(rnorm(n*d), n, d)
  P <- plogis(matrix(b0, n, m, byrow=TRUE) + U %*% t(Lam))
  list(Y = matrix(rbinom(n*m, 1, P), n, m), Lambda = Lam)
}
mkdf <- function(Y) { df <- as.data.frame(Y); names(df) <- paste0("t", seq_len(ncol(Y)))
  df$site <- factor(seq_len(nrow(Y))); df }
fit_la <- function(Y, d) {
  tn <- paste0("t", seq_len(ncol(Y)))
  fo <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(0 + trait | site, d = %d, unique = FALSE)",
    paste(tn, collapse=", "), d))
  suppressWarnings(gllvmTMB(fo, data = mkdf(Y), family = binomial()))
}
relerr <- function(Lt, Lh) norm(tcrossprod(Lh)-tcrossprod(Lt),"F")/norm(tcrossprod(Lt),"F")

cat("warm-up (untimed)...\n"); w <- sim_binom(80, 6, 2)
invisible(try(fit_la(w$Y, 2), silent=TRUE))
invisible(vgh_fit(w$Y, matrix(1,80,1), d=2, family="binomial", maxit=20)); cat("done\n\n")

d <- 2L; m <- 20L; Q <- 15L
grid <- c(250L, 500L, 1000L, 2000L, 4000L, 8000L)
cat(sprintf("%7s %9s %9s %9s %9s %9s\n","n","LA_sec","VGH_sec","speedup","LA_err","VGH_err"))
res <- list()
for (n in grid) {
  D <- sim_binom(n, m, d)
  t1 <- proc.time()[["elapsed"]]
  fl <- try(fit_la(D$Y, d), silent=TRUE)
  la <- proc.time()[["elapsed"]] - t1
  la_e <- if (inherits(fl,"try-error")) NA_real_ else tryCatch({
    L <- fl$sdr_summary; NA_real_ }, error=function(e) NA_real_)
  t2 <- proc.time()[["elapsed"]]
  fv <- vgh_fit(D$Y, matrix(1,n,1), d=d, family="binomial", Q=Q, maxit=300, tol=1e-9)
  vs <- proc.time()[["elapsed"]] - t2
  cat(sprintf("%7d %9.2f %9.2f %8.1fx %9s %9.4f\n", n, la, vs, la/vs, "-",
              relerr(D$Lambda, fv$Lambda)))
  res[[length(res)+1L]] <- data.frame(n=n, la_sec=la, vgh_sec=vs,
    vgh_err=relerr(D$Lambda, fv$Lambda), sweeps=fv$sweeps)
}
out <- do.call(rbind, res)
write.csv(out, "dev/vgh/scaling-law.csv", row.names=FALSE)
cat("\n--- fitted scaling exponents (slope of log time vs log n) ---\n")
cat(sprintf("  VGH     : %.3f\n", coef(lm(log(vgh_sec) ~ log(n), out))[2]))
ok <- is.finite(out$la_sec) & out$la_sec > 0
cat(sprintf("  Laplace : %.3f\n", coef(lm(log(la_sec) ~ log(n), out[ok,]))[2]))
cat("\n1.0 = linear, 2.0 = quadratic. Mission control measured the EXISTING VA\n")
cat("at ~2.0 and Laplace at ~1.0, with VA not completing beyond n ~ 2500.\n")
