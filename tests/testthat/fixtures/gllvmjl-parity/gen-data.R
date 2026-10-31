## Writes the six response tables used by the gllvmTMB <-> GLLVModels.jl
## cross-engine parity tests (test-gllvmjl-parity-fixtures.R). NOT run by the
## test suite; provenance only. Run from this directory:
##   Rscript gen-data.R
## then regenerate the Julia reference values with gen-reference.jl.
##
## Every table is long format (site, trait, y), p = 5 traits, n = 100 sites,
## simulated from a rank-2 latent model eta = beta + Lambda z (z ~ N(0, I_2)).
## Responses are written with 10 significant digits; the tests read the files
## back, so both engines fit the same bytes.

p <- 5L
n <- 100L
tr <- paste0("t", seq_len(p))
beta <- c(0.6, 0.2, -0.3, 0.4, 0.0)
Lambda <- cbind(c(0.9, -0.6, 0.7, 0.5, -0.4),
                c(0.0, 0.5, -0.4, 0.6, 0.7))

set.seed(20261031L)
z <- matrix(rnorm(n * 2L), n, 2L)
eta <- z %*% t(Lambda) + matrix(beta, n, p, byrow = TRUE) # n x p
mu <- exp(eta)

rtweedie <- function(mu, phi, pw) {
  lam <- mu^(2 - pw) / (phi * (2 - pw))
  shape <- (2 - pw) / (pw - 1)
  scale <- phi * (pw - 1) * mu^(pw - 1)
  N <- rpois(length(mu), lam)
  ifelse(N == 0, 0, rgamma(length(mu), shape = N * shape, scale = scale))
}

Y <- list(
  gaussian = eta + matrix(rnorm(n * p, sd = 0.5), n, p),
  poisson  = matrix(rpois(n * p, mu), n, p),
  nbinom2  = matrix(rnbinom(n * p, mu = mu, size = 2), n, p),
  binomial = matrix(rbinom(n * p, 1L, plogis(eta)), n, p),
  zip      = matrix(rpois(n * p, mu), n, p) *
             matrix(rbinom(n * p, 1L, 0.75), n, p),
  tweedie  = matrix(rtweedie(as.vector(mu), 1.0, 1.5), n, p)
)

for (fam in names(Y)) {
  d <- data.frame(site = rep(seq_len(n), each = p),
                  trait = rep(tr, n),
                  y = signif(as.vector(t(Y[[fam]])), 10))
  write.csv(d, sprintf("data-%s.csv", fam), row.names = FALSE)
}
