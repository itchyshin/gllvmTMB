source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
o  <- readRDS("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/p1.rds")
cl <- o$cell; Y <- cl$Y; n <- cl$n; p <- cl$p; q <- cl$q

## EVA objective for Bernoulli-logit GLLVM (Korhonen, Nikula & Hui 2023 form).
## b(x)=log(1+e^x), b''(x)=s(x)(1-s(x)).  AGENT-INFERRED functional form,
## VALIDATED below by reproducing gllvm's own reported logL.
eva_obj <- function(Y, Lam, beta0, M, A) {
  eta <- sweep(M %*% t(Lam), 2, beta0, "+")            # n x p
  V   <- t(apply(A, 1, function(Ai) diag(Lam %*% Ai %*% t(Lam))))  # n x p
  bpp <- plogis(eta) * (1 - plogis(eta))
  dat <- sum(Y * eta - log1p(exp(eta)) - 0.5 * bpp * V)
  ent <- sum(apply(A, 1, function(Ai) 0.5 * determinant(Ai, logarithm=TRUE)$modulus -
                                      0.5 * sum(diag(Ai)))) +
         (-0.5) * sum(M^2) + n * q / 2
  dat + ent
}
## VA (Jaakkola-Jordan / Polya-Gamma) lower bound, for contrast.
va_obj <- function(Y, Lam, beta0, M, A) {
  eta <- sweep(M %*% t(Lam), 2, beta0, "+")
  V   <- t(apply(A, 1, function(Ai) diag(Lam %*% Ai %*% t(Lam))))
  xi  <- sqrt(eta^2 + V)                                # optimal JJ variational param
  lam <- (plogis(xi) - 0.5) / (2 * xi)
  dat <- sum((Y - 0.5) * eta + log(plogis(xi)) - 0.5 * xi - lam * (eta^2 + V - xi^2))
  ent <- sum(apply(A, 1, function(Ai) 0.5 * determinant(Ai, logarithm=TRUE)$modulus -
                                      0.5 * sum(diag(Ai)))) +
         (-0.5) * sum(M^2) + n * q / 2
  dat + ent
}

for (nm in c("EVA","VA")) {
  f <- o[[nm]]
  L <- gllvm::getLoadings(f)
  val <- eva_obj(Y, L, f$params$beta0, as.matrix(f$lvs), f$A)
  cat(sprintf("%-4s  gllvm logL = %12.5f   my EVA obj = %12.5f   diff = %.3e\n",
              nm, f$logL, val, val - f$logL))
}
cat("\n== VALIDATION: does my EVA reconstruction reproduce gllvm's EVA logL? ==\n")

f <- o$EVA; L <- gllvm::getLoadings(f); M <- as.matrix(f$lvs); A <- f$A; b0 <- f$params$beta0
cat("\n== SCALING RAY: multiply the FITTED loadings+intercepts by s, keep M and A fixed ==\n")
cat(" s      EVA objective      VA(JJ) objective    attenuation\n")
for (s in c(0.001, 0.01, 0.1, 0.5, 1, 2, 10, 100)) {
  Ls <- L * s; bs <- b0 * s
  cat(sprintf("%7.3f  %16.4f  %16.4f  %12.4g\n", s,
              eva_obj(Y, Ls, bs, M, A), va_obj(Y, Ls, bs, M, A),
              att(Ls %*% t(Ls), cl$Sig_true)))
}

cat("\n== SCALING RAY from the TRUTH: Lam = true Lt * s, M = true u, A = I ==\n")
Atrue <- array(0, c(n,q,q)); for (i in 1:n) Atrue[i,,] <- diag(q) * 0.5
cat(" s      EVA objective      VA(JJ) objective    attenuation\n")
for (s in c(0.25, 0.5, 1, 2, 5, 10, 50, 200, 1000, 1e4)) {
  Ls <- cl$Lt * s; bs <- cl$b * s
  cat(sprintf("%9.1f  %16.4f  %16.4f  %12.4g\n", s,
              eva_obj(Y, Ls, bs, cl$u, Atrue), va_obj(Y, Ls, bs, cl$u, Atrue),
              att(Ls %*% t(Ls), cl$Sig_true)))
}
