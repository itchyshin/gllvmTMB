source("dev/phylo-coef-public/helpers.R")
devtools::load_all(quiet = TRUE)
K <- matrix(c(1.2, 0.35, 0.35, 0.8), 2L, 2L,
            dimnames = list(c("a", "b"), c("a", "b")))
dat <- data.frame(trait = factor(c("a", "b"), levels = c("a", "b")))
src <- gllvmTMB:::.resolve_phylo_coef_spectral_source(NULL, K, dat, "trait")
for (rho in c(0.11, 0.53, 0.89)) {
  s <- (1 - rho) + rho * src$lambda
  Q <- diag(1 / src$d) %*% src$U %*% diag(1 / s) %*%
    t(src$U) %*% diag(1 / src$d)
  K_rho <- rho * K + (1 - rho) * diag(diag(K))
  assert(max(abs(Q - solve(K_rho))) < 1e-10,
         "spectral precision differs from covariance mixture")
  logdet <- 2 * sum(log(src$d)) + sum(log(s))
  truth <- as.numeric(determinant(K_rho, logarithm = TRUE)$modulus)
  assert(abs(logdet - truth) < 1e-10,
         "spectral log determinant differs from covariance mixture")
}
src_text <- read_all(c("R/fit-multi.R", "src/gllvmTMB.cpp",
                       "docs/design/131-response-column-coefficient-foundation.md"))
for (needle in c("eta_column_coef_rho", "column_coef_source_lambda",
                 "rho K + (1-rho) diag(K)")) {
  assert(grepl(needle, src_text, fixed = TRUE), "missing alignment token: %s", needle)
}
cat("symbolic alignment verified\n")
