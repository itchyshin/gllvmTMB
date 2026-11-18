## Does a raster-only recipe recover the KNOWN correlation length?
env_surface <- function(n_side, ell = 0.25, seed = 1) {
  set.seed(seed)
  gx <- seq(0, 1, length.out = n_side)
  g <- expand.grid(lon = gx, lat = gx)
  d <- as.matrix(dist(g)); S <- exp(-d / ell)
  z <- as.numeric(t(chol(S + diag(1e-6, nrow(S)))) %*% rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g
}

## THE RECIPE (candidate for the article): empirical correlogram on the raster,
## read off the distance where correlation falls to 1/e.
cor_length <- function(x, y, z, n_bin = 30) {
  d <- as.matrix(dist(cbind(x, y)))
  cp <- outer(z - mean(z), z - mean(z)) / var(z)
  ut <- upper.tri(d)
  brk <- seq(0, quantile(d[ut], 0.5), length.out = n_bin + 1)
  bin <- cut(d[ut], brk, include.lowest = TRUE)
  rho <- tapply(cp[ut], bin, mean)
  hmid <- (brk[-1] + brk[-length(brk)]) / 2
  ok <- !is.na(rho)
  stats::approx(rho[ok], hmid[ok], xout = exp(-1))$y   # d where rho = 1/e
}

for (true_ell in c(0.10, 0.25, 0.40)) {
  est <- sapply(1:6, function(s) {
    g <- env_surface(30, ell = true_ell, seed = s)
    cor_length(g$lon, g$lat, g$env)
  })
  cat(sprintf("true phi = %.2f   recipe = %.3f  (sd %.3f over 6 surfaces)\n",
              true_ell, mean(est), sd(est)))
}
