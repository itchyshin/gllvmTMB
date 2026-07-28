## GAUSSIAN EXACTNESS -- the check that proves the quadrature.
##
## Laplace is EXACT for a gaussian latent-linear model, so AGHQ must reproduce
## the Laplace objective with no free parameters, and the agreement must be
## INDEPENDENT of k (k = 1 agreement would only prove plumbing, because k = 1
## IS Laplace; k = 3 and k = 9 agreeing is the real statement).
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))

gdata <- function(n = 60, p = 6, q = 2, seed = 3) {
  set.seed(seed)
  Lt  <- matrix(stats::rnorm(p * q, 0, 0.6), p, q)
  u   <- matrix(stats::rnorm(n * q), n, q)
  b   <- stats::rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- eta + matrix(stats::rnorm(n * p, 0, 0.5), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, Lt = Lt,
       fml = stats::as.formula(sprintf(
         "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
         paste(colnames(Y), collapse = ", "), q)))
}

d <- gdata()
la <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::gaussian()))
cat("=== GAUSSIAN EXACTNESS (must be ~0 and k-INDEPENDENT) ===\n")
cat(sprintf("  laplace nll = %.10f\n", la$opt$objective))
for (k in c(3L, 9L)) {
  ctl <- gllvmTMBcontrol(aghq = k)
  fk <- suppressWarnings(gllvmTMB(d$fml, data = d$df,
                                  family = stats::gaussian(), control = ctl))
  cat(sprintf("  k=%-2d delta = %.6g   passes=%s  used=%s\n",
              k, fk$opt$objective - la$opt$objective,
              fk$aghq$passes %||% NA, fk$aghq$used))
}
