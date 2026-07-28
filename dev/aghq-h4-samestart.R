## H4, CORRECTLY POSED: from an IDENTICAL sane start, where does each engine LAND?
##
## The earlier ranking test was under-powered by construction: it compared each
## objective at its fitted point against truth, but the fitted point is the MLE, so
## the likelihood beats truth there for ANY correctly-working estimator. 12/12
## "prefers the fitted point" was guaranteed before the run. Recorded as such.
##
## This version has no such flaw. Laplace is exactly k = 1 of the same code path, so
## both arms share the DGP, the objective machinery, the optimiser and the start, and
## differ ONLY in the node count. Any divergence in where they land is attributable to
## the quadrature and nothing else.
##
## PRE-REGISTERED, before the run: H4 is supported iff, from the same sane starts,
## the k=9 arm lands at a materially smaller ||Lambda||_F and rel_frob than the k=1
## arm ON DEGENERATE CELLS, *while the matched healthy controls show no comparable
## shift*. If the healthy controls move as much, the statistic is measuring the node
## count rather than the defect, and H4 is dead -- which is how the three previous
## hypotheses died.
source(file.path(Sys.getenv("H4_SRC", "."), "aghq-r-reference.R"))

## DGP, byte-identical to dev/arc0/lib.R and to the campaign that produced the 59/70.
mk <- function(n, p, q, seed) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  list(Y = Y, Lt = Lt, b = b, Sigma_true = Lt %*% t(Lt))
}

## Sane, feasible, engine-agnostic starts. b from the empirical logit (always finite --
## a pre-fit scan of all 281 campaign cells found ZERO saturated species); loadings
## drawn at the DGP's own scale. start_id 1 is deterministic so both arms are
## guaranteed to see the identical point.
make_start <- function(Y, q, start_id) {
  p <- ncol(Y); n <- nrow(Y)
  pr <- pmin(pmax(colMeans(Y), 1 / (4 * n)), 1 - 1 / (4 * n))
  nfree <- length(ref_lambda_index(p, q))
  if (start_id == 1L) return(c(qlogis(pr), rep(0.3, nfree)))
  set.seed(10000L + start_id)
  c(qlogis(pr), rnorm(nfree, 0, 0.6))
}

run_cell <- function(n, p, q, seed, grp, KS = c(1L, 9L), n_start = 3L) {
  d <- mk(n, p, q, seed)
  out <- list()
  for (s in seq_len(n_start)) {
    st <- make_start(d$Y, q, s)
    for (K in KS) {
      t0 <- Sys.time()
      fk <- tryCatch(ref_fit(d$Y, q, K, start = st), error = function(e) NULL)
      if (is.null(fk)) next
      out[[length(out) + 1L]] <- data.frame(
        grp = grp, n = n, p = p, q = q, seed = seed, start_id = s, k = K,
        nll = fk$objective, convergence = fk$convergence,
        frob = norm(fk$Lambda, "F"), frob_true = norm(d$Lt, "F"),
        rel_frob = ref_rel_frob(fk$Sigma, d$Sigma_true),
        max_abs_b = max(abs(fk$b)),
        elapsed_s = as.numeric(Sys.time() - t0, units = "secs"),
        stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}
