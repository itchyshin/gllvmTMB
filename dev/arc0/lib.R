## dev/arc0/lib.R -- shared fixture for Arc 0.
##
## Question: are the campaign's 59/70 silently-degenerate Laplace fits genuine
## optima of models the data does not identify, or failed optimisations?
##
## Every interface fact below was verified against a live fit on 2026-07-28
## BEFORE any harness was written. The traps are recorded at the bottom.

ARC0_ROOT <- "/private/tmp/gllvmtmb-arc0-identifiability"

arc0_load <- function() {
  suppressMessages(devtools::load_all(ARC0_ROOT, quiet = TRUE))
}

## Byte-identical to the DGP in dev/lambda-spectrum-vs-degeneracy.R, so a cell
## regenerated here IS the cell that was fitted in the campaign. (n, p, q, seed)
## fully determines the dataset: the draw order below must not change.
arc0_data <- function(n, p, q, seed) {
  set.seed(seed)
  Lt  <- matrix(stats::rnorm(p * q, 0, 0.6), p, q)
  u   <- matrix(stats::rnorm(n * q), n, q)
  b   <- stats::rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  fml <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt, b = b, Y = Y, Sigma_true = Lt %*% t(Lt))
}

## n_init > 1 runs native multi-start: restart 1 is unjittered, restarts 2..K
## start from obj$par + rnorm(sd = init_jitter). Every restart is recorded in
## fit$restart_history (objective, convergence, iterations, success, selected).
arc0_fit <- function(dat, n_init = 1L, init_jitter = 0) {
  args <- list(dat$fml, data = dat$df, family = stats::binomial())
  if (n_init > 1L) {
    args$control <- gllvmTMBcontrol(n_init = as.integer(n_init),
                                    init_jitter = init_jitter)
  }
  suppressWarnings(tryCatch(do.call(gllvmTMB, args), error = function(e) NULL))
}

## Sigma_B = Lambda Lambda', reported on the q non-trivial eigenvalues.
arc0_spectrum <- function(fit, p, q) {
  L  <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  ev <- sort(eigen(L %*% t(L), symmetric = TRUE, only.values = TRUE)$values,
             decreasing = TRUE)[seq_len(q)]
  list(L = L, ev = ev, ratio = min(ev) / max(ev), frob = norm(L, "F"))
}

## Trailing eigenvector of Sigma_B -- the least-supported direction in trait
## space, and the direction Arc 0 profiles along.
arc0_trailing <- function(fit, p, q) {
  L <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  e <- eigen(L %*% t(L), symmetric = TRUE)
  list(vec = e$vectors[, q], val = e$values[q])
}

## Rotation-invariant distance between two fits of the same cell. Lambda itself
## is only identified up to a q x q rotation under unique = FALSE, so Lambda
## must never be compared directly; Sigma_B is the identified functional.
arc0_sigma_dist <- function(fitA, fitB, p, q) {
  A <- arc0_spectrum(fitA, p, q)$L; A <- A %*% t(A)
  B <- arc0_spectrum(fitB, p, q)$L; B <- B %*% t(B)
  norm(A - B, "F") / max(norm(A, "F"), norm(B, "F"), 1e-12)
}

## ---------------------------------------------------------------------------
## VERIFIED INTERFACE FACTS -- and three traps that already cost a wrong result.
##
## 1. The TMB object is fit$tmb_obj, NOT fit$obj (fit$obj is NULL).
## 2. fit$tmb_obj$par is the STARTING vector, not the optimum. The optimum is
##    fit$opt$par, and fit$tmb_obj$fn(fit$opt$par) == fit$opt$objective. On the
##    n=40/q=2/seed=1 degenerate cell those differ by 39.5 nll units, so a ray
##    or profile built on tmb_obj$par silently probes the WRONG POINT.
## 3. names(fit$opt$par) is only {"b_fix", "theta_rr_B"}; theta_rr_B holds the
##    p*q - q(q-1)/2 free loading entries (15 at p=8, q=2).
## 4. fit$report$Lambda_B is p x q AT THE OPTIMUM; fit$report$Sigma_B also exists.
## 5. fit$opt$convergence, isTRUE(fit$sd_report$pdHess), .gllvmTMB_boundary_flags(fit).
## 6. A fit takes ~5 s at n=40, q=2.
##
## What a live probe of the n=40/q=2/seed=1 degenerate cell showed:
##   b_fix[4] = 35.9 (fitted p = 1 - 4e-16) with Lambda[4, ] = (-1553.6, -171.2),
##   ||Lambda||_F = 1564 against a true 2.30. The reported optimum sits at
##   effectively infinite parameter values. That is the fact Arc 0 must explain.
##
## What it is NOT: a pre-fit scan of all 281 bernoulli campaign cells found
## ZERO with an all-0 or all-1 species, so ordinary marginal separation is
## refuted (0/70). Any divergence is CONDITIONAL on the latent field.
