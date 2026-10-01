## DGP for the auto-d recovery study (design.md section D).
## sim_dataset(family, n_units, n_traits, d, seed) -> long data.frame with
## unit, trait (factors), value; attr "redraws" = number of degenerate redraws.
sim_dataset <- function(family, n_units, n_traits, d, seed) {
  stopifnot(family %in% c("gaussian", "poisson", "binomial", "nbinom2"))
  set.seed(seed)
  count <- family %in% c("poisson", "nbinom2")
  draw <- function() {
    Lambda <- matrix(stats::rnorm(n_traits * d), n_traits, d)
    beta <- if (count) stats::runif(n_traits, 0, 1) else stats::runif(n_traits, -0.5, 0.5)
    Z <- matrix(stats::rnorm(n_units * d), n_units, d)
    eta <- matrix(beta, n_units, n_traits, byrow = TRUE) + Z %*% t(Lambda)
    Y <- switch(family,
      gaussian = eta + matrix(stats::rnorm(n_units * n_traits, sd = 0.5), n_units, n_traits),
      poisson  = matrix(stats::rpois(n_units * n_traits, exp(eta)), n_units, n_traits),
      binomial = matrix(stats::rbinom(n_units * n_traits, 1L, stats::plogis(eta)), n_units, n_traits),
      nbinom2  = matrix(stats::rnbinom(n_units * n_traits, size = 2, mu = exp(eta)), n_units, n_traits)
    )
    Y
  }
  degenerate <- function(Y) {
    switch(family,
      gaussian = FALSE,
      binomial = any(colSums(Y) == 0 | colSums(Y) == nrow(Y)),
      any(colSums(Y) == 0)
    )
  }
  redraws <- 0L
  Y <- draw()
  while (degenerate(Y) && redraws < 20L) {
    redraws <- redraws + 1L
    Y <- draw()
  }
  units <- sprintf("u%04d", seq_len(n_units))
  traits <- sprintf("t%02d", seq_len(n_traits))
  dat <- data.frame(
    unit = factor(rep(units, times = n_traits), levels = units),
    trait = factor(rep(traits, each = n_units), levels = traits),
    value = as.vector(Y)
  )
  attr(dat, "redraws") <- redraws
  attr(dat, "degenerate_after_redraws") <- degenerate(Y)
  dat
}
