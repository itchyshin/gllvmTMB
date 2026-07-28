## H4, the decisive form: does AGHQ RANK the degenerate optimum below the truth,
## where Laplace ranks it above? This needs no optimiser at all, so it cannot be
## confounded by optimiser failure -- which is exactly what stalled the first probe.
##
## Laplace's reported optimum has ||Lambda||_F = 1564 against a true 2.30. If Laplace
## scores that point BETTER than the truth while AGHQ scores it WORSE, then the
## degenerate optimum is an artefact of the one-node approximation (H4), and the
## deliverable is an estimator fix rather than an identifiability warning.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet=TRUE))
source("dev/arc0/lib.R"); source("dev/aghq-r-reference.R")

## Lambda is identified only up to a q x q rotation, so the TRUE loading matrix must be
## rotated into the same lower-triangular convention before its parameters can be
## compared. A Givens rotation zeroing Lt[1, 2] does it and leaves Sigma untouched.
to_lower <- function(Lt) {
  q <- ncol(Lt); if (q == 1L) return(Lt)
  v <- Lt[1, ]; nv <- sqrt(sum(v^2)); u <- v / nv
  V <- cbind(u, c(-u[2], u[1]))
  Ln <- Lt %*% V
  stopifnot(abs(Ln[1, 2]) < 1e-10,
            max(abs(Ln %*% t(Ln) - Lt %*% t(Lt))) < 1e-8)   # Sigma preserved
  Ln
}

cell <- function(n, p, q, seed, lab, K = 9L) {
  d   <- arc0_data(n, p, q, seed)
  fit <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial()))
  L0  <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  b0  <- as.vector(fit$opt$par[names(fit$opt$par) == "b_fix"])
  par_hat <- c(b0, L0[lower.tri(L0, diag = TRUE)])

  Ltr <- to_lower(d$Lt)
  par_true <- c(d$b, Ltr[lower.tri(Ltr, diag = TRUE)])

  g1 <- ref_grid(q, 1L); gK <- ref_grid(q, K)
  out <- data.frame(
    lab = lab, n = n, p = p, q = q, seed = seed, k = K,
    la_at_hat   = ref_nll(par_hat,  d$Y, q, 1L, g1),
    la_at_true  = ref_nll(par_true, d$Y, q, 1L, g1),
    ghq_at_hat  = ref_nll(par_hat,  d$Y, q, K,  gK),
    ghq_at_true = ref_nll(par_true, d$Y, q, K,  gK),
    frob_hat = norm(L0, "F"), frob_true = norm(d$Lt, "F"),
    rel_frob_hat = ref_rel_frob(L0 %*% t(L0), d$Sigma_true))
  out$la_prefers  <- ifelse(out$la_at_hat  < out$la_at_true,  "degenerate", "TRUTH")
  out$ghq_prefers <- ifelse(out$ghq_at_hat < out$ghq_at_true, "degenerate", "TRUTH")
  out
}

cells <- list(c(40,8,2,1,"degenerate"), c(40,8,2,2,"degenerate"), c(40,8,2,4,"degenerate"),
              c(40,8,2,5,"degenerate"), c(40,8,2,6,"degenerate"), c(40,8,2,7,"degenerate"),
              c(100,8,2,1,"healthy"),   c(100,8,2,2,"healthy"),   c(100,8,2,3,"healthy"),
              c(100,8,2,4,"healthy"),   c(100,8,2,5,"healthy"),   c(100,8,2,6,"healthy"))
res <- do.call(rbind, lapply(cells, function(z)
  cell(as.integer(z[1]), as.integer(z[2]), as.integer(z[3]), as.integer(z[4]), z[5])))
write.csv(res, "dev/aghq-h4-ranking.csv", row.names = FALSE)

cat("\n=== which objective prefers which point? ===\n")
for (i in seq_len(nrow(res))) with(res[i,], cat(sprintf(
  "%-10s n=%3d seed=%d | LA: hat %9.3f vs true %9.3f -> %-10s | AGHQ k=%d: hat %9.3f vs true %9.3f -> %-10s | ||L||hat %8.4g\n",
  lab, n, seed, la_at_hat, la_at_true, la_prefers, k, ghq_at_hat, ghq_at_true, ghq_prefers, frob_hat)))
cat("\n=== summary ===\n")
print(table(group = res$lab, LA_prefers = res$la_prefers))
print(table(group = res$lab, AGHQ_prefers = res$ghq_prefers))
