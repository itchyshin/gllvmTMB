## Writes the extra response tables used by the gllvmTMB <-> GLLVModels.jl
## cross-engine parity tests (test-gllvmjl-parity-extra.R): fixed-effect
## covariates, a random site effect, a count offset, and K = 3. NOT run by the
## test suite; provenance only. Run from this directory:
##   Rscript gen-data-extra.R
## then regenerate the Julia reference values with gen-reference-extra.jl.
##
## Every table is long format (site, trait, y, plus the covariate columns).
## Responses are written with 10 significant digits; covariates and offsets
## with 10 as well. The tests read the files back, so both engines fit the
## same bytes.
##
##   xcov-<family>   p = 5, n = 100, eta = beta + 0.5 x1 - 0.4 x2 + Lambda z
##                   (rank 2); x1, x2 are site-level N(0, 1) covariates with
##                   one coefficient shared by all traits.
##   rowre-<family>  p = 5, n = 150, eta = beta + rho_s + Lambda z (rank 2),
##                   rho_s ~ N(0, 0.7^2) one random intercept per site.
##   offset-<family> p = 5, n = 100, eta = off + beta + Lambda z (rank 2),
##                   off varies by (site, trait): a log exposure.
##   k3-<family>     p = 6, n = 150, eta = beta + Lambda z (rank 3).

tr <- function(p) paste0("t", seq_len(p))
Lambda2 <- cbind(c(0.9, -0.6, 0.7, 0.5, -0.4),
                 c(0.0, 0.5, -0.4, 0.6, 0.7))
beta5 <- c(0.6, 0.2, -0.3, 0.4, 0.0)

write_long <- function(name, Y, extra = NULL) {
  n <- nrow(Y)
  p <- ncol(Y)
  d <- data.frame(site = rep(seq_len(n), each = p),
                  trait = rep(tr(p), n),
                  y = signif(as.vector(t(Y)), 10))
  if (!is.null(extra)) for (nm in names(extra)) d[[nm]] <- signif(extra[[nm]], 10)
  write.csv(d, sprintf("data-%s.csv", name), row.names = FALSE)
}

draw <- function(fam, eta, sd = 0.5, size = 2, pi_zip = 0.75) {
  n <- nrow(eta)
  p <- ncol(eta)
  mu <- exp(eta)
  switch(fam,
    gaussian = eta + matrix(rnorm(n * p, sd = sd), n, p),
    poisson  = matrix(rpois(n * p, mu), n, p),
    nbinom2  = matrix(rnbinom(n * p, mu = mu, size = size), n, p),
    binomial = matrix(rbinom(n * p, 1L, plogis(eta)), n, p),
    zip      = matrix(rpois(n * p, mu), n, p) *
               matrix(rbinom(n * p, 1L, pi_zip), n, p)
  )
}

set.seed(20261101L)

## --- xcov ---------------------------------------------------------------
n <- 100L
p <- 5L
z <- matrix(rnorm(n * 2L), n, 2L)
x1 <- rnorm(n)
x2 <- rnorm(n)
eta <- z %*% t(Lambda2) + matrix(beta5, n, p, byrow = TRUE) +
  matrix(0.5 * x1 - 0.4 * x2, n, p)
for (fam in c("gaussian", "poisson", "nbinom2", "binomial", "zip")) {
  write_long(paste0("xcov-", fam), draw(fam, eta),
             list(x1 = rep(x1, each = p), x2 = rep(x2, each = p)))
}

## --- rowre --------------------------------------------------------------
n <- 150L
z <- matrix(rnorm(n * 2L), n, 2L)
rho <- rnorm(n, sd = 0.7)
eta <- z %*% t(Lambda2) + matrix(beta5, n, p, byrow = TRUE) +
  matrix(rho, n, p)
for (fam in c("poisson", "binomial")) {
  write_long(paste0("rowre-", fam), draw(fam, eta))
}

## --- offset -------------------------------------------------------------
n <- 100L
z <- matrix(rnorm(n * 2L), n, 2L)
off <- matrix(rnorm(n * p, mean = 0.3, sd = 0.5), n, p)
eta <- z %*% t(Lambda2) + matrix(beta5, n, p, byrow = TRUE) + off
for (fam in c("poisson", "nbinom2")) {
  write_long(paste0("offset-", fam), draw(fam, eta),
             list(off = as.vector(t(off))))
}

## --- k3 -----------------------------------------------------------------
n <- 150L
p <- 6L
Lambda3 <- cbind(c(0.9, -0.6, 0.7, 0.5, -0.4, 0.3),
                 c(0.0, 0.7, -0.4, 0.6, 0.7, -0.5),
                 c(0.0, 0.0, 0.6, -0.5, 0.4, 0.8))
beta6 <- c(0.6, 0.2, -0.3, 0.4, 0.0, 0.3)
z <- matrix(rnorm(n * 3L), n, 3L)
eta <- z %*% t(Lambda3) + matrix(beta6, n, p, byrow = TRUE)
for (fam in c("gaussian", "poisson")) {
  write_long(paste0("k3-", fam), draw(fam, eta))
}
