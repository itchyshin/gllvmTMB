d96_log1pexp <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))
d96_loading_from_free <- function(x, traits = 6L) {
  stopifnot(traits >= 2L, length(x) == 2L * traits - 1L)
  L <- matrix(0, traits, 2L); L[1, 1] <- exp(x[1]); L[2, ] <- c(x[2], exp(x[3]))
  if (traits > 2L) L[3:traits, ] <- matrix(x[4:length(x)], traits - 2L, 2L, byrow = TRUE)
  L
}
d96_gh <- local({ cache <- NULL; function(order = 61L) { if (!is.null(cache)) return(cache); j <- seq_len(order - 1L); J <- matrix(0, order, order); J[cbind(j, j + 1L)] <- sqrt(j / 2); J[cbind(j + 1L, j)] <- sqrt(j / 2); e <- eigen(J, symmetric = TRUE); cache <<- list(z = sqrt(2) * e$values, w = e$vectors[1, ]^2); cache } })
d96_marginal_probability <- function(beta, loading_free) {
  L <- d96_loading_from_free(loading_free, length(beta)); h <- d96_gh()
  vapply(seq_along(beta), function(t) sum(h$w * plogis(beta[t] + sqrt(sum(L[t, ]^2)) * h$z)), numeric(1))
}
d96_start <- function(label, y) {
  b <- qlogis(pmin(.95, pmax(.05, colMeans(y))))
  loading <- switch(label,
    A = c(log(.45), 0, log(.45), 0, 0, 0, 0, 0, 0, 0, 0),
    B = c(log(.80), .10, log(.70), .20, -.15, .20, -.15, .20, -.15, .20, -.15),
    C = c(log(.25), -.30, log(.30), -.15, .20, -.15, .20, -.15, .20, -.15, .20))
  list(beta = b, loading_free = loading, mean = matrix(0, nrow(y), 2L), log_sd = matrix(log(.8), nrow(y), 2L))
}
d96_fixture <- function(label) {
  spec <- switch(label, strong = list(n = 160L, scale = 1, seed = 96002L), moderate = list(n = 240L, scale = .65, seed = 96003L))
  beta <- c(-.50, -.20, .10, .40, -.30, .25)
  L0 <- rbind(c(.85, 0), c(.25, .75), c(-.40, .35), c(.50, -.20), c(-.20, -.50), c(.35, .25))
  set.seed(spec$seed); u <- matrix(rnorm(spec$n * 2L), spec$n, 2L); L <- spec$scale * L0
  probability <- plogis(sweep(u %*% t(L), 2L, beta, "+")); y <- matrix(rbinom(length(probability), 1L, as.vector(probability)), spec$n, nrow(L))
  list(label = label, y = y, u = u, beta = beta, loading = L, probability = probability, seed = spec$seed, scale = spec$scale)
}
d96_health <- function(x) isTRUE(x$phase1_convergence == 0L) && isTRUE(x$phase2_convergence == 0L) && is.finite(x$objective) && is.finite(x$gradient_max) && x$gradient_max < 1e-4 && is.finite(x$eigen[2]) && x$eigen[2] > 0
