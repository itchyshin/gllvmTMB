## Throwaway probe: verify the theta_rr_B -> Lambda_B fill map empirically.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/arc0/lib.R")
arc0_load()

p <- 8L; q <- 2L
dat <- arc0_data(40L, p, q, 1L)
t0 <- Sys.time()
fit <- arc0_fit(dat)
cat("fit seconds:", as.numeric(difftime(Sys.time(), t0, units = "secs")), "\n")

cat("names(opt$par):", paste(unique(names(fit$opt$par)), collapse = ", "), "\n")
cat("length opt$par:", length(fit$opt$par), "\n")
cat("objective:", fit$opt$objective, " convergence:", fit$opt$convergence, "\n")
cat("fn(opt$par):", fit$tmb_obj$fn(unname(fit$opt$par)), "\n")
cat("fn(tmb_obj$par):", fit$tmb_obj$fn(fit$tmb_obj$par), "\n")

## --- my candidate map ------------------------------------------------------
## 0-based (i, j); returns 1-based index into theta_rr_B.
pack_idx <- function(i, j, p, rank) {
  if (j > i) return(NA_integer_)
  if (i == j) return(j + 1L)
  rank + (j * p - ((j + 1L) * j) %/% 2L + i - 1L - j) + 1L
}
lambda_from_theta <- function(th, p, q) {
  L <- matrix(0, p, q)
  for (j in 0:(q - 1L)) for (i in 0:(p - 1L)) {
    k <- pack_idx(i, j, p, q)
    if (!is.na(k)) L[i + 1L, j + 1L] <- th[k]
  }
  L
}

th <- unname(fit$opt$par[names(fit$opt$par) == "theta_rr_B"])
cat("length theta_rr_B:", length(th), " expected:", p * q - q * (q - 1) / 2, "\n")
Lhat <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
Lmine <- lambda_from_theta(th, p, q)
cat("max |L_report - L_mine| at optimum:", max(abs(Lhat - Lmine)), "\n")
print(round(Lhat, 4))

## --- perturbation check: change ONE theta entry, predict where L moves -----
for (k in c(1L, 2L, 3L, 9L, 15L)) {
  pp <- unname(fit$opt$par)
  ix <- which(names(fit$opt$par) == "theta_rr_B")[k]
  pp[ix] <- pp[ix] + 0.137
  invisible(fit$tmb_obj$fn(pp))         # sets last.par (inner solve at pp)
  Lrep <- fit$tmb_obj$report()$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  thp <- pp[which(names(fit$opt$par) == "theta_rr_B")]
  Lpred <- lambda_from_theta(thp, p, q)
  d <- which(abs(Lrep - Lhat) > 1e-10, arr.ind = TRUE)
  cat(sprintf("theta[%2d] +0.137 -> report moved at (%s); max|pred-rep| = %.3e\n",
              k, paste(sprintf("%d,%d", d[, 1], d[, 2]), collapse = " "),
              max(abs(Lpred - Lrep))))
}

tr <- arc0_trailing(fit, p, q)
sp <- arc0_spectrum(fit, p, q)
cat("eigs:", paste(signif(sp$ev, 6), collapse = " "), "\n")
cat("trailing val:", tr$val, " u'Sigma u:",
    as.numeric(t(tr$vec) %*% (Lhat %*% t(Lhat)) %*% tr$vec), "\n")
cat("||Lambda||_F:", sp$frob, "\n")
saveRDS(list(par = fit$opt$par, obj = fit$opt$objective), "/tmp/arc0-probe.rds")
