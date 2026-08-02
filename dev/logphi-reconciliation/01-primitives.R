## Double-precision R transcriptions of the two log Phi implementations.
## Both `direct` branches call R's pnorm(), which is the same Rmath routine
## TMB's pnorm() resolves to for Type = double.

ship_logphi <- function(x) {                      # src/gllvmTMB.cpp:71
  cut  <- -20
  xa   <- pmin(x, cut)                            # min(x, -20)
  inv2 <- 1 / (xa * xa)
  series <- 1 - inv2 * (1 - 3 * inv2 * (1 - 5 * inv2 * (1 - 7 * inv2)))
  tail <- -0.5 * xa * xa - log(-xa) - 0.5 * log(2 * pi) + log(series)
  xd   <- pmax(x, cut)                            # max(x, -20)
  direct <- log(pnorm(xd))
  ifelse(x < cut, tail, direct)
}

va_mills_cf <- function(z, K = 20) {
  cc <- 0
  for (k in K:1) cc <- k / (z + cc)
  cc
}

va_logphi <- function(x) {                        # inst/tmb/gllvmTMB_va_r3.cpp:182
  z0 <- 10
  z  <- pmax(-x, z0)
  tail <- -0.5 * z * z - 0.5 * log(2 * pi) - log(z + va_mills_cf(z))
  xd <- pmax(x, -z0)
  direct <- log(pnorm(xd))
  ifelse(x < -z0, tail, direct)
}

## gll_log1mexp (src/gllvmTMB.cpp:50) -- log(1 - exp(log_p)), log_p <= 0
gll_log1mexp <- function(log_p) {
  u <- -log_p
  series <- log(u - u * u / 2 + u * u * u / 6)
  direct <- log(1 - exp(log_p))
  ifelse(u < 1e-6, series, direct)
}

## gll_log_pnorm_diff (src/gllvmTMB.cpp:106) -- log(Phi(a) - Phi(b)), a > b
gll_log_pnorm_diff <- function(a, b, lp = ship_logphi) {
  la <- lp(a); lb <- lp(b); lna <- lp(-a); lnb <- lp(-b)
  left  <- la  + gll_log1mexp(lb  - la)
  right <- lnb + gll_log1mexp(lna - lnb)
  ifelse(a + b <= 0, left, right)
}

## Naive TMB logspace_sub(x, y) = log(exp(x) - exp(y)), x > y
logspace_sub_naive <- function(a, b, lp = ship_logphi) {
  la <- lp(a); lb <- lp(b)
  la + log1p(-exp(lb - la))
}
