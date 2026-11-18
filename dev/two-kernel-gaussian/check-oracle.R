# Deterministic oracle self-check, not a package fit or recovery experiment.
source('dev/two-kernel-gaussian/oracle.R')
nside <- 3L
A <- 0.6^abs(outer(seq_len(nside), seq_len(nside), '-'))
I <- diag(nside)
K <- list(rbind(cbind(A, .45 * A), cbind(.45 * A, A)),
          rbind(cbind(I, -.25 * I), cbind(-.25 * I, I)))
cells <- expand.grid(species = seq_len(6L), trait = seq_len(4L))
keep <- with(cells, (species <= 3L & trait <= 2L) |
               (species > 3L & trait > 2L))
keep[2L] <- FALSE # one additional missing within-guild cell
cells <- cells[keep, , drop = FALSE]
species <- cells$species; trait <- cells$trait
X <- diag(4)[trait, , drop = FALSE]
y <- sin(seq_along(species) * .7)
beta <- c(.2, -.3, .5, -.1)
L <- list(matrix(c(.35, -.2, .5, .1), ncol = 1L),
          matrix(c(-.25, .45, .15, -.4), ncol = 1L))
a <- list(log(c(.3, .4, .25, .35)), log(c(.2, .32, .38, .22)))
sigma <- .12
evaluate <- function(beta, L, a, kernels = K, ridge = c(1e-8, 1e-8), sd = sigma) {
  two_kernel_oracle(y, X, species, trait, kernels, L, a, beta, sd, ridge)
}
base <- evaluate(beta, L, a)
p <- c(beta, unlist(L), unlist(a))
objective <- function(p) evaluate(p[1:4], list(matrix(p[5:8]), matrix(p[9:12])),
                                 list(p[13:16], p[17:20]))$nll
numeric_gradient <- function(h) vapply(seq_along(p), function(i) {
  plus <- minus <- p; plus[i] <- plus[i] + h; minus[i] <- minus[i] - h
  (objective(plus) - objective(minus)) / (2 * h)
}, numeric(1))
analytic <- unname(two_kernel_gradient_vector(base$gradient))
g1 <- numeric_gradient(1e-5); g2 <- numeric_gradient(5e-6)
stopifnot(length(analytic) == length(p), max(abs(analytic - g1)) < 1e-6,
          max(abs(g1 - g2)) < 1e-6, length(y) == 11L)
names(analytic) <- names(g1) <- paste0('coordinate_', seq_along(p))
stopifnot(two_kernel_compare_native(base, base$nll, g1, analytic)$pass)
bad_gradient <- g1; bad_gradient[1] <- bad_gradient[1] + .01
stopifnot(!two_kernel_compare_native(base, base$nll, bad_gradient, analytic)$pass,
          !two_kernel_compare_native(base, base$nll + .01, g1, analytic)$pass)
sign_flip <- L; sign_flip[[1]] <- -sign_flip[[1]]
stopifnot(max(abs(base$covariance - evaluate(beta, sign_flip, a)$covariance)) < 1e-14)
partial_flip <- L; partial_flip[[1]][1, 1] <- -partial_flip[[1]][1, 1]
permuted_K <- K; ord <- c(2L, 1L, 3L, 4L, 5L, 6L)
permuted_K[[1]] <- K[[1]][ord, ord]
permuted_L <- L; permuted_L[[1]] <- L[[1]][c(2L, 1L, 3L, 4L), , drop = FALSE]
mutations <- list(
  omit_psi1 = evaluate(beta, L, list(rep(log(1e-100), 4), a[[2]])),
  omit_psi2 = evaluate(beta, L, list(a[[1]], rep(log(1e-100), 4))),
  omit_floor = evaluate(beta, L, a, sd = 1e-100),
  double_floor = evaluate(beta, L, a, sd = sigma * sqrt(2)),
  no_ridge1 = evaluate(beta, L, a, ridge = c(0, 1e-8)),
  no_ridge2 = evaluate(beta, L, a, ridge = c(1e-8, 0)),
  wrong_species_order = evaluate(beta, L, a, kernels = permuted_K),
  wrong_trait_order = evaluate(beta, permuted_L, a),
  wrong_partial_sign = evaluate(beta, partial_flip, a)
)
delta <- vapply(mutations, function(z) max(abs(z$covariance - base$covariance)), numeric(1))
stopifnot(all(delta > 1e-12))
cat(sprintf('ORACLE_SELF_CHECK_PASS n=%d gradient_gap=%.3g step_gap=%.3g min_mutation=%.3g\n',
            length(y), max(abs(analytic - g1)), max(abs(g1 - g2)), min(delta)))
