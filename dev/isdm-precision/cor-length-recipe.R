## ---------------------------------------------------------------------------
## The correlation-length recipe shipped to readers in
## vignettes/articles/isdm-spatial-precision.Rmd.
##
## KEEP IN SYNC with the `cor-length-recipe` chunk in that article. The
## article compares its own deparse() against the copy stored in
## cor-length-grid.rds and says so on the page if they have drifted, so a
## silent divergence between "the function we measured" and "the function we
## ship" cannot happen unnoticed.
## ---------------------------------------------------------------------------

## phi = the distance at which the covariate's own spatial correlation falls
## to 1/e. NOTE n_sub: this builds a dense n x n distance matrix, so it takes
## a SUBSAMPLE of cells, never a whole raster.
cor_length <- function(x, y, z, n_bin = 30, n_sub = 2000, seed = 1) {
  if (length(x) > n_sub) {
    ## Subsample reproducibly WITHOUT clobbering the caller's RNG stream. A
    ## bare set.seed() here would silently change every random draw the user
    ## makes afterwards -- the same species of invisible damage this article
    ## is about.
    old <- if (exists(".Random.seed", .GlobalEnv))
      get(".Random.seed", .GlobalEnv) else NULL
    set.seed(seed)
    i <- sample.int(length(x), n_sub)
    if (is.null(old)) rm(".Random.seed", envir = .GlobalEnv) else
      assign(".Random.seed", old, envir = .GlobalEnv)
    x <- x[i]; y <- y[i]; z <- z[i]
  }
  d   <- as.matrix(dist(cbind(x, y)))
  cp  <- outer(z - mean(z), z - mean(z)) / var(z)
  ut  <- upper.tri(d)
  brk <- seq(0, quantile(d[ut], 0.5), length.out = n_bin + 1)
  rho <- tapply(cp[ut], cut(d[ut], brk, include.lowest = TRUE), mean)
  h   <- (brk[-1] + brk[-length(brk)]) / 2
  ok  <- !is.na(rho); rho <- rho[ok]; h <- h[ok]

  ## Walk outward to the FIRST crossing of 1/e and interpolate there.
  ## approx(rho, h, xout = 1/e) would sort on the correlations, and an
  ## empirical correlogram is not monotone -- that silently re-pairs
  ## distances with correlations they did not come from.
  below <- which(rho < exp(-1))
  if (!length(below))
    stop("cor_length(): the correlogram never falls to 1/e within half the ",
         "maximum inter-point distance. phi is too long to measure on this ",
         "extent -- your covariate is smoother than your map is wide. ",
         "Use a larger region, and do not substitute the largest distance ",
         "you can see.", call. = FALSE)
  k <- below[1]
  if (k == 1L)
    stop("cor_length(): correlation is already below 1/e in the first ",
         "distance bin, so phi is shorter than the spacing between the cells ",
         "supplied. Supply finer cells; do NOT read the returned bin ",
         "midpoint as phi.", call. = FALSE)
  h[k - 1] + (rho[k - 1] - exp(-1)) / (rho[k - 1] - rho[k]) * (h[k] - h[k - 1])
}
