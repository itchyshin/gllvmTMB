## ---------------------------------------------------------------------------
## The correlation-length recipe's accuracy surface, with EXTENT and
## RESOLUTION varied independently.
##
## Why this script exists. The earlier experiment
## (evidence-correlation-length-domain.R) compared side = 1, phi = r against
## side = 4, phi = 4r on the same 30 x 30 lattice. Scaling side and phi
## together holds phi/cell-spacing fixed as well as phi/side, so the two
## columns agreeing shows only that the recipe is scale-equivariant in units
## -- trivially true of any function of distances -- and cannot attribute the
## bias to extent rather than resolution. (Fisher review F6a.)
##
## Here phi/side and the lattice size n_side are crossed, which separates
## them: phi/spacing = (phi/side) * (n_side - 1).
##
## Also recorded per cell: the per-surface sd, the fraction of surfaces
## returning phi_hat ABOVE truth (so "the error is always downward" can be
## stated as the central tendency it is, with its spread), and the fraction
## on which the recipe REFUSES to answer.
##
## The Cholesky factor depends only on (n_side, phi), not on the seed, so it
## is computed once per cell and reused across seeds.
##
## Run from the package root:
##   Rscript dev/isdm-precision/generate-cor-length-grid.R
## ---------------------------------------------------------------------------
source("dev/isdm-precision/cor-length-recipe.R")

n_seed <- 12
n_sides <- c(21, 41, 61)
ratios  <- c(0.02, 0.05, 0.10, 0.25, 0.40)

out <- list()
for (ns in n_sides) {
  gx <- seq(0, 1, length.out = ns)
  g  <- expand.grid(lon = gx, lat = gx)
  dm <- as.matrix(dist(g))
  for (r in ratios) {
    S <- exp(-dm / r)                      # side = 1, so phi = r
    L <- t(chol(S + diag(1e-6, nrow(S))))
    for (s in seq_len(n_seed)) {
      set.seed(s)
      z <- as.numeric(L %*% rnorm(nrow(g)))
      z <- as.numeric(scale(z))
      est <- tryCatch(cor_length(g$lon, g$lat, z),
                      error = function(e) NA_real_)
      out[[length(out) + 1]] <- data.frame(
        n_side = ns, phi = r, spacing = 1 / (ns - 1),
        phi_over_side = r, phi_over_spacing = r * (ns - 1),
        seed = s, phi_hat = est, row.names = NULL)
    }
    cat(sprintf("n_side %3d  phi/side %.2f  phi/spacing %5.2f  done\n",
                ns, r, r * (ns - 1)))
  }
}
res <- do.call(rbind, out)
attr(res, "recipe") <- paste(deparse(cor_length), collapse = "\n")
saveRDS(res, "dev/isdm-precision/cor-length-grid.rds")
cat("saved", nrow(res), "rows to dev/isdm-precision/cor-length-grid.rds\n")
