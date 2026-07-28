## A standalone, R-side ADAPTIVE-GH reference fitter for the bernoulli-logit
## loadings-only GLLVM:  traits(...) ~ 1 + latent(1 | site, d = q, unique = FALSE)
##
## PURPOSE. Two jobs, and it is worth being explicit that they are different:
##   (1) UNBLOCK H4 — answer "does AGHQ fix the 59/70 degenerate fits?" without
##       waiting on the TMB template. The H4 cells are tiny (n = 40, p = 8, q = 2),
##       so a slow reference fitter is entirely adequate.
##   (2) Serve as an INDEPENDENT MODEL-LEVEL ORACLE for the template. It shares no
##       code with src/gllvmTMB.cpp — the densities, the mode-finding and the
##       quadrature are all rewritten here from the model definition. If the oracle
##       shared code with the thing under test, the test would be vacuous.
##
## It is NOT a shipping route and must never become one: it duplicates one family
## in R, which is precisely the drift risk the template design exists to avoid.
##
## The quadrature form is the corrected one derived and validated in
## dev/aghq-grid-check.R (plain standard-normal weights; adaptation applied here,
## not folded into the weights):
##
##   log L_i = logsumexp_j [ log w_j + loglik_i(z_j)
##                           - 0.5*||z_j||^2 + 0.5*||zeta_j||^2 - sum(log diag(L_c)) ]
##
## with z_j = zhat_i + solve(t(L_c)) %*% zeta_j, and H_i = L_c L_c' the conditional
## precision at the mode. At k = 1 this IS the Laplace approximation, exactly.

## ---- grid (plain standard-normal Gauss-Hermite, Golub-Welsch) -----------------
.gh1 <- function(k) {
  i <- seq_len(k - 1L)
  J <- matrix(0, k, k)
  J[cbind(i, i + 1L)] <- sqrt(i / 2); J[cbind(i + 1L, i)] <- sqrt(i / 2)
  e <- eigen(J, symmetric = TRUE); o <- order(e$values)
  list(z = sqrt(2) * e$values[o], w = (e$vectors[1L, o]^2))
}
ref_grid <- function(d, k) {
  g <- .gh1(k)
  idx <- as.matrix(do.call(expand.grid, rep(list(seq_len(k)), d)))
  list(nodes = matrix(g$z[idx], nrow = nrow(idx), ncol = d),
       logw  = rowSums(matrix(log(g$w)[idx], nrow = nrow(idx), ncol = d)))
}

## ---- numerically stable log(1 + exp(x)) --------------------------------------
## NOT optional here, and worth flagging for the template too. The degenerate fits
## this reference exists to study carry Lambda entries of ~1.5e3 and b_fix of ~36,
## so eta reaches the thousands and a naive log1p(exp(eta)) returns Inf -> NaN for
## EVERY node, silently turning the whole objective into NaN rather than erroring.
## The first run of this file did exactly that.
.softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

## ---- parameter packing -------------------------------------------------------
## Lambda is p x q, lower-triangular-constrained for identifiability (the same
## convention the package uses: Lambda[i, j] = 0 for j > i), giving
## p*q - q*(q-1)/2 free entries. Lambda itself is identified only up to a q x q
## rotation, so NOTHING here ever compares Lambda across fits -- Sigma = Lambda
## Lambda' is the identified functional.
ref_lambda_index <- function(p, q) which(lower.tri(matrix(0, p, q), diag = TRUE), arr.ind = FALSE)
ref_build_lambda <- function(lam_free, p, q) {
  L <- matrix(0, p, q); L[ref_lambda_index(p, q)] <- lam_free; L
}
ref_npar <- function(p, q) p + length(ref_lambda_index(p, q))

## ---- per-site conditional mode and curvature (Newton, q-dimensional) ---------
## f(z) = loglik_i(z) + log phi(z);  we return zhat and H = -f''(zhat).
## A PLAIN Newton diverges here, and it is worth recording why, because the same
## regime is what the whole 59/70 question is about. On a degenerate fit the loading
## entries reach ~1.5e3, so |eta| reaches the hundreds; then W = mu(1-mu) underflows
## to zero, the Hessian collapses to the prior (H -> I), and the gradient is still of
## order 1.5e3. The undamped step is therefore ~1.5e3 and the iteration flies off.
## Measured consequence of the undamped version: the k=1 objective came back as
## 1.28e6 against gllvmTMB's 188.96 -- not a small discrepancy, a different planet.
## Backtracking on the actual objective fixes it.
ref_site_mode <- function(z0, Y_i, b, L, maxit = 200L, tol = 1e-10) {
  f <- function(z) {                       # the log integrand, up to constants
    eta <- as.vector(b + L %*% z)
    sum(Y_i * eta - .softplus(eta)) - 0.5 * sum(z^2)
  }
  z <- z0; fz <- f(z)
  for (it in seq_len(maxit)) {
    eta <- as.vector(b + L %*% z)
    mu  <- plogis(eta)
    g   <- as.vector(crossprod(L, Y_i - mu)) - z
    W   <- mu * (1 - mu)
    H   <- crossprod(L * sqrt(W)) + diag(length(z))
    step <- tryCatch(solve(H, g), error = function(e) g)
    ## backtracking line search: never accept a step that does not improve f
    s <- 1; ok <- FALSE
    for (bt in seq_len(50L)) {
      zn <- z + s * step; fn <- f(zn)
      if (is.finite(fn) && fn >= fz) { ok <- TRUE; break }
      s <- s / 2
    }
    if (!ok) break                          # already at a maximum to machine precision
    moved <- max(abs(zn - z)); z <- zn; fz <- fn
    if (moved < tol) break
  }
  eta <- as.vector(b + L %*% z); mu <- plogis(eta); W <- mu * (1 - mu)
  list(zhat = z, H = crossprod(L * sqrt(W)) + diag(length(z)))
}

## ---- the AGHQ objective ------------------------------------------------------
## k = 1 gives Laplace exactly. Returns the NEGATIVE log-likelihood.
## `cache` is an environment holding the previous call's per-site modes. Warm-starting
## the inner Newton from them is the difference between this being usable and not: the
## parameters move only slightly between optimiser evaluations, so the mode barely
## moves, and a cold start from 0 re-walks the whole (heavily backtracked) path every
## time. Measured cold: a single fit did not finish in 2 minutes.
ref_nll <- function(par, Y, q, k, grid = NULL, cache = NULL) {
  n <- nrow(Y); p <- ncol(Y)
  b <- par[seq_len(p)]
  L <- ref_build_lambda(par[-seq_len(p)], p, q)
  if (is.null(grid)) grid <- ref_grid(q, k)
  zeta <- grid$nodes; logw <- grid$logw
  half_zeta2 <- 0.5 * rowSums(zeta^2)
  warm <- if (!is.null(cache) && !is.null(cache$modes)) cache$modes else matrix(0, n, q)
  new_modes <- warm
  total <- 0
  for (i in seq_len(n)) {
    Y_i <- Y[i, ]
    m <- ref_site_mode(warm[i, ], Y_i, b, L)
    new_modes[i, ] <- m$zhat
    Lc <- tryCatch(t(chol(m$H)), error = function(e) NULL)   # H = Lc %*% t(Lc)
    if (is.null(Lc)) return(NA_real_)
    ## z_j = zhat + solve(t(Lc)) %*% zeta_j   -> rows of zeta %*% solve(Lc)
    Z <- sweep(zeta %*% solve(Lc), 2, m$zhat, "+")
    eta <- sweep(Z %*% t(L), 2, b, "+")                       # k^q x p
    ll  <- as.vector(eta %*% Y_i - rowSums(.softplus(eta)))
    br  <- logw + ll - 0.5 * rowSums(Z^2) + half_zeta2 - sum(log(diag(Lc)))
    mx <- max(br)
    total <- total + mx + log(sum(exp(br - mx)))
  }
  if (!is.null(cache)) cache$modes <- new_modes
  -total
}

## ---- fit ---------------------------------------------------------------------
## start: optionally warm-start from a Laplace fit's parameters (recommended --
## the AGHQ surface is the same shape, so this saves most of the optimiser time).
ref_fit <- function(Y, q, k, start = NULL, optimizer = c("nlminb", "lbfgsb"),
                    maxit = 500L) {
  optimizer <- match.arg(optimizer)
  p <- ncol(Y)
  if (is.null(start)) {
    pr <- pmin(pmax(colMeans(Y), 1 / (4 * nrow(Y))), 1 - 1 / (4 * nrow(Y)))
    start <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(p, q))))
  }
  grid <- ref_grid(q, k)
  cache <- new.env(parent = emptyenv())
  fn <- function(par) { v <- ref_nll(par, Y, q, k, grid, cache); if (!is.finite(v)) 1e10 else v }
  t0 <- Sys.time()
  if (optimizer == "nlminb") {
    op <- stats::nlminb(start, fn, control = list(iter.max = maxit, eval.max = 4L * maxit))
    par <- op$par; obj <- op$objective; conv <- op$convergence
  } else {
    ## factr is NOT optional: with optim's default, lbfgsb terminates in ~24 ms at
    ## an objective 125-151 worse while reporting convergence = 0 (3/3 reps).
    op <- stats::optim(start, fn, method = "L-BFGS-B",
                       control = list(maxit = maxit, factr = 1e-12 / .Machine$double.eps))
    par <- op$par; obj <- op$value; conv <- op$convergence
  }
  L <- ref_build_lambda(par[-seq_len(p)], p, q)
  list(par = par, objective = obj, convergence = conv, k = k,
       b = par[seq_len(p)], Lambda = L, Sigma = L %*% t(L),
       elapsed_s = as.numeric(Sys.time() - t0, units = "secs"))
}

## ---- the identified error functional ----------------------------------------
## Relative Frobenius error of Sigma against truth. Rotation-invariant, because it
## is computed on Sigma = Lambda Lambda' and never on Lambda.
ref_rel_frob <- function(Sigma_hat, Sigma_true)
  norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")
