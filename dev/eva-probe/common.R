## Exact DGP copy from dev/totoro-grid/run-grid.R lines 49-58 (bernoulli branch)
suppressMessages(library(gllvm))
Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1", MKL_NUM_THREADS="1")

make_cell <- function(n, p, q, seed, family = "bernoulli") {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- if (family == "poisson") matrix(rpois(n * p, exp(eta)), n, p)
       else                     matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  list(Y = Y, Lt = Lt, u = u, b = b, eta = eta, Sig_true = Lt %*% t(Lt),
       n = n, p = p, q = q, seed = seed)
}
relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")
att <- function(S, St) sum(diag(S)) / sum(diag(St))

## reconstruction EXACTLY as run-grid.R:109-110
recon_gridline <- function(fit, q) as.matrix(fit$params$theta) %*% diag(fit$params$sigma.lv, q, q)
