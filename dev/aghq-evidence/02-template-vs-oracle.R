## THE MISSING TEST: the TEMPLATE's AGHQ objective against a brute-force oracle, on a
## NON-GAUSSIAN integrand. Gaussian exactness cannot see node-placement errors, because
## after the adaptive transform a gaussian integrand IS the GH kernel and any correctly
## normalised rule reproduces it at every k.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet=TRUE))
source("dev/aghq-r-reference.R")

## Tiny model so the per-site integral can be done exactly by stats::integrate().
set.seed(5); n <- 6L; p <- 3L; q <- 1L
Lt <- matrix(rnorm(p*q, 0, 0.8), p, q); u <- matrix(rnorm(n*q), n, q); b <- rnorm(p, 0.3, 0.4)
eta <- sweep(u %*% t(Lt), 2, b, "+")
Y <- matrix(rbinom(n*p, 1, plogis(eta)), n, p)
colnames(Y) <- paste0("sp", 1:p); df <- as.data.frame(Y); df$site <- factor(1:n)
fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = 1, unique = FALSE)",
                          paste(colnames(Y), collapse=", ")))

## Independent oracle: exact marginal nll by 1-D numerical integration per site.
sp <- function(x) pmax(x,0) + log1p(exp(-abs(x)))
oracle_nll <- function(bv, Lv) {
  tot <- 0
  for (i in 1:n) {
    f <- function(z) sapply(z, function(zz) {
      e <- bv + Lv * zz; exp(sum(Y[i,]*e - sp(e))) })
    tot <- tot + log(integrate(function(z) f(z)*dnorm(z), -Inf, Inf, rel.tol=1e-12)$value)
  }
  -tot
}

la <- suppressWarnings(gllvmTMB(fml, data=df, family=binomial()))
bh <- as.vector(la$opt$par[names(la$opt$par)=="b_fix"])
Lh <- as.vector(la$report$Lambda_B[1:p, 1, drop=TRUE])
truth <- oracle_nll(bh, Lh)
cat(sprintf("=== all three evaluated at the SAME parameters (the Laplace optimum) ===\n"))
cat(sprintf("  brute-force oracle (integrate)  : %.10f\n", truth))
cat(sprintf("  gllvmTMB Laplace objective      : %.10f   err %+.3e\n",
            la$opt$objective, la$opt$objective - truth))
parref <- c(bh, Lh)
for (k in c(1L,3L,5L,9L,15L,25L)) {
  v <- ref_nll(parref, Y, 1L, k)
  cat(sprintf("  R reference   k=%-2d              : %.10f   err %+.3e\n", k, v, v - truth))
}
cat("\n=== now the TEMPLATE, same data, its own optimum reported for context ===\n")
for (k in c(1L,3L,9L,25L)) {
  g <- suppressWarnings(try(gllvmTMB(fml, data=df, family=binomial(),
        control=gllvmTMBcontrol(aghq=k, aghq_n_adapt=60L)), silent=TRUE))
  if (inherits(g,"try-error")) { cat(sprintf("  k=%-2d ERROR\n", k)); next }
  bg <- as.vector(g$opt$par[names(g$opt$par)=="b_fix"])
  Lg <- as.vector(g$report$Lambda_B[1:p, 1, drop=TRUE])
  ## The decisive number: evaluate the ORACLE at the template's own optimum, and
  ## compare with the objective the template REPORTS there. If the template's
  ## objective is not the marginal likelihood, these disagree.
  cat(sprintf("  k=%-2d template obj %.6f | oracle at template's par %.6f | GAP %+.4f\n",
              k, g$opt$objective, oracle_nll(bg, Lg), g$opt$objective - oracle_nll(bg, Lg)))
}
