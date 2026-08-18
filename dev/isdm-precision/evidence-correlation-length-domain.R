env_surface <- function(n_side, ell, seed, side = 1) {
  set.seed(seed)
  gx <- seq(0, side, length.out = n_side)
  g <- expand.grid(lon = gx, lat = gx)
  d <- as.matrix(dist(g)); S <- exp(-d / ell)
  z <- as.numeric(t(chol(S + diag(1e-6, nrow(S)))) %*% rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g
}
cor_length <- function(x, y, z, n_bin = 30, frac = 0.5) {
  d <- as.matrix(dist(cbind(x, y)))
  cp <- outer(z - mean(z), z - mean(z)) / var(z)
  ut <- upper.tri(d)
  brk <- seq(0, quantile(d[ut], frac), length.out = n_bin + 1)
  bin <- cut(d[ut], brk, include.lowest = TRUE)
  rho <- tapply(cp[ut], bin, mean)
  hmid <- (brk[-1] + brk[-length(brk)]) / 2
  ok <- !is.na(rho)
  stats::approx(rho[ok], hmid[ok], xout = exp(-1))$y
}
cat("--- ratio phi/domain-side is what matters ---\n")
for (r in c(0.05, 0.10, 0.25, 0.40)) {
  # hold the RATIO fixed, vary absolute scale: if it's a domain effect, ratio governs
  est1 <- sapply(1:6, function(s) cor_length(  # side = 1
    (g <- env_surface(30, ell = r*1, seed = s, side = 1))$lon, g$lat, g$env))
  est4 <- sapply(1:6, function(s) cor_length(  # side = 4, phi scaled up 4x
    (g <- env_surface(30, ell = r*4, seed = s, side = 4))$lon, g$lat, g$env))
  cat(sprintf("phi/side = %.2f  ->  est/phi = %.2f (side 1) , %.2f (side 4)\n",
              r, mean(est1)/(r*1), mean(est4)/(r*4)))
}
