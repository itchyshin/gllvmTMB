## ---------------------------------------------------------------------------
## VGH -- Variational Gauss-Hermite GLLVM engine (research prototype)
##
## Reference implementation of a block coordinate-ascent variational
## approximation for the GLLVM
##
##     eta_ij = x_i' beta_j + u_i' lambda_j,   u_i ~ N(0, I_d),
##     y_ij | u_i ~ ExpFam(eta_ij; phi_j),     log p = (y eta - b(eta))/phi + c(y, phi)
##
## Design rests on three exact structural facts (see 00-vgh-derivation.md):
##
##   (C1) THE ONE-DIMENSIONAL COLLAPSE.  Under q(u_i) = N(a_i, A_i), eta_ij is
##        univariate normal with mean m_ij = x_i'beta_j + a_i'lambda_j and
##        variance s2_ij = lambda_j' A_i lambda_j.  So the only intractable
##        term is a ONE-dimensional Gaussian integral B(m,s) = E[b(m + s Z)],
##        whatever d is.  Exact quadrature is therefore affordable for every
##        family; no per-family closed form and no Taylor expansion is needed.
##
##   (C2) STEIN'S LEMMA CLOSES THE VARIANCE BLOCK.  dB/ds = s * E[b''(m + sZ)],
##        so the stationarity condition for A_i is the closed form
##            A_i^{-1} = I_d + Lambda' W_i Lambda,   W_i = diag(B2_ij / phi_j),
##        and the ELBO Hessian in a_i is exactly -A_i^{-1}, so the Newton step
##        a_i <- a_i + A_i g_i costs nothing beyond A_i, which we already have.
##
##   (C3) EVERY BLOCK IS A GEMM.  With A_i vectorised into an n x d^2 matrix and
##        the loading outer products into an m x d^2 matrix, both s2 and the
##        precision update are single matrix products.  The M-step decouples
##        across responses j into m independent (p+d)-dimensional Fisher-scoring
##        problems.  There is no global gradient vector, no AD tape, no line
##        search over a large parameter block, and no log-determinant
##        derivative -- which is the term that dominates Laplace's outer gradient.
##
## Everything here is base R (Golub-Welsch quadrature included) so it runs with
## no compilation.  Speed claims in this file are STRUCTURAL claims about flop
## counts and computational shape; the measured comparison lives in
## vgh-bench.R and must be read there, not assumed from this header.
## ---------------------------------------------------------------------------


# --- Gauss-Hermite nodes for the PROBABILISTS' normal ------------------------
# Returns nodes z and weights w with sum(w) = 1 approximating E[f(Z)], Z ~ N(0,1).
# Golub-Welsch: eigendecomposition of the symmetric tridiagonal Jacobi matrix.
vgh_gh_rule <- function(Q) {
  stopifnot(Q >= 1L)
  if (Q == 1L) return(list(z = 0, w = 1))
  k <- seq_len(Q - 1L)
  J <- diag(0, Q)
  off <- sqrt(k / 2)
  J[cbind(k, k + 1L)] <- off
  J[cbind(k + 1L, k)] <- off
  e <- eigen(J, symmetric = TRUE)
  ord <- order(e$values)
  x <- e$values[ord]
  w <- (e$vectors[1L, ord])^2          # already sums to 1 for the normalised rule
  list(z = sqrt(2) * x, w = w / sum(w)) # substitution z = sqrt(2) x
}


# --- Families ---------------------------------------------------------------
# Each family supplies b, b', b'' and, where an exact closed form for the
# Gaussian expectation exists, analytic B / B1 / B2.  `exact = TRUE` means the
# quadrature is bypassed entirely -- no approximation error at all.
vgh_family <- function(name) {
  switch(name,

    gaussian = list(
      name = "gaussian", link = "identity", exact = TRUE, has_phi = TRUE,
      # b(eta) = eta^2/2  =>  E[b] = (m^2 + s^2)/2 exactly
      moments = function(m, s2) list(B = (m^2 + s2) / 2, B1 = m, B2 = array(1, dim(m))),
      cfun = function(y, phi) -y^2 / (2 * rep(phi, each = nrow(y))) -
        0.5 * log(2 * pi * rep(phi, each = nrow(y)))
    ),

    poisson = list(
      name = "poisson", link = "log", exact = TRUE, has_phi = FALSE,
      # b(eta) = exp(eta)  =>  E[b] = exp(m + s^2/2) exactly (lognormal mean)
      moments = function(m, s2) { B <- exp(m + s2 / 2); list(B = B, B1 = B, B2 = B) },
      cfun = function(y, phi) -lgamma(y + 1)
    ),

    binomial = list(
      name = "binomial", link = "logit", exact = FALSE, has_phi = FALSE,
      # b(eta) = log(1 + exp(eta)); no closed form -> Gauss-Hermite.
      # b'  = plogis(eta), b'' = plogis(eta) * (1 - plogis(eta)).
      b    = function(eta) ifelse(eta > 30, eta, log1p(exp(pmin(eta, 30)))),
      b1   = function(eta) stats::plogis(eta),
      b2   = function(eta) { p <- stats::plogis(eta); p * (1 - p) },
      cfun = function(y, phi) 0
    ),

    stop("unsupported family: ", name)
  )
}


# --- The (m, s) moment map --------------------------------------------------
# Returns B = E[b(eta)], B1 = E[b'(eta)], B2 = E[b''(eta)] elementwise over the
# n x m matrices m and s2.  Analytic where the family provides it, otherwise
# Q-node Gauss-Hermite.  This is the ONLY place the family enters.
vgh_moments <- function(fam, m, s2, rule) {
  if (isTRUE(fam$exact)) return(fam$moments(m, s2))
  s <- sqrt(pmax(s2, 0))
  B <- B1 <- B2 <- array(0, dim(m))
  for (q in seq_along(rule$z)) {
    eta <- m + s * rule$z[q]
    wq <- rule$w[q]
    B  <- B  + wq * fam$b(eta)
    B1 <- B1 + wq * fam$b1(eta)
    B2 <- B2 + wq * fam$b2(eta)
  }
  list(B = B, B1 = B1, B2 = B2)
}


# --- ELBO -------------------------------------------------------------------
# ELBO = sum_ij [ (y m - B)/phi + c(y,phi) ] + 0.5 sum_i [ logdet A_i - tr A_i
#                                                          - a_i'a_i + d ]
vgh_elbo <- function(Y, fam, M, S2, amean, Avec, phi, rule, logdetA) {
  n <- nrow(Y); d <- ncol(amean)
  mom <- vgh_moments(fam, M, S2, rule)
  phimat <- rep(phi, each = n)
  ll <- sum((Y * M - mom$B) / phimat) + sum(fam$cfun(Y, phi))
  # trace of A_i is the sum of its diagonal entries, read off the vec
  didx <- (seq_len(d) - 1L) * d + seq_len(d)
  trA <- rowSums(Avec[, didx, drop = FALSE])
  kl <- 0.5 * sum(logdetA - trA - rowSums(amean^2) + d)
  list(value = ll + kl, mom = mom)
}


# --- Batched symmetric inverse over n units, vectorised ---------------------
# Inverting n small matrices in an R loop would dominate the runtime and defeat
# the whole point, so d <= 3 gets closed-form cofactor inverses evaluated across
# all units at once.  Input is n x d^2 holding vec(P_i); returns vec(P_i^{-1})
# and log det P_i.
vgh_batch_inv <- function(P, d) {
  n <- nrow(P)
  if (d == 1L) {
    dt <- P[, 1]
    return(list(Ainv = matrix(1 / dt, ncol = 1L), logdet = log(dt)))
  }
  if (d == 2L) {
    p11 <- P[, 1]; p21 <- P[, 2]; p12 <- P[, 3]; p22 <- P[, 4]
    dt <- p11 * p22 - p12 * p21
    A <- cbind(p22, -p21, -p12, p11) / dt
    return(list(Ainv = A, logdet = log(dt)))
  }
  if (d == 3L) {
    p11 <- P[, 1]; p21 <- P[, 2]; p31 <- P[, 3]
    p12 <- P[, 4]; p22 <- P[, 5]; p32 <- P[, 6]
    p13 <- P[, 7]; p23 <- P[, 8]; p33 <- P[, 9]
    c11 <- p22 * p33 - p23 * p32
    c12 <- p13 * p32 - p12 * p33
    c13 <- p12 * p23 - p13 * p22
    c21 <- p23 * p31 - p21 * p33
    c22 <- p11 * p33 - p13 * p31
    c23 <- p13 * p21 - p11 * p23
    c31 <- p21 * p32 - p22 * p31
    c32 <- p12 * p31 - p11 * p32
    c33 <- p11 * p22 - p12 * p21
    dt <- p11 * c11 + p12 * c21 + p13 * c31
    A <- cbind(c11, c21, c31, c12, c22, c32, c13, c23, c33) / dt
    return(list(Ainv = A, logdet = log(dt)))
  }
  # d >= 4: fall back to a loop (rare in practice for GLLVMs)
  Ainv <- matrix(0, n, d * d); ld <- numeric(n)
  for (i in seq_len(n)) {
    ch <- chol(matrix(P[i, ], d, d))
    Ainv[i, ] <- as.vector(chol2inv(ch))
    ld[i] <- 2 * sum(log(diag(ch)))
  }
  list(Ainv = Ainv, logdet = ld)
}

# batched matrix-vector product: row i of (A_i %*% v_i), A_i stored as vec
vgh_batch_mv <- function(Avec, V, d) {
  out <- matrix(0, nrow(V), d)
  for (k in seq_len(d)) {
    idx <- (seq_len(d) - 1L) * d + k
    out[, k] <- rowSums(Avec[, idx, drop = FALSE] * V)
  }
  out
}

# per-unit contribution to the ELBO, given the variational block -- used by the
# damped-step line search.  Separable over i, so backtracking is PER UNIT.
vgh_unit_obj <- function(Y, M, S2, amean, Avec, logdetA, phi, fam, rule, d) {
  mom <- vgh_moments(fam, M, S2, rule)
  phimat <- rep(phi, each = nrow(Y))
  didx <- (seq_len(d) - 1L) * d + seq_len(d)
  trA <- rowSums(Avec[, didx, drop = FALSE])
  rowSums((Y * M - mom$B) / phimat) +
    0.5 * (logdetA - trA - rowSums(amean^2) + d)
}

# --- One variational sweep: A_i in closed form, a_i by damped Newton --------
# The A_i stationarity (C2) is a fixed point, and the Newton step in a_i is
# undamped Newton -- for a log link that overshoots through exp() and can DECREASE
# the ELBO.  So the proposal is damped along a path that keeps the precision
# positive definite:  P(t) = (1-t) P + t P*,  a(t) = a + t A* g.  Because the
# variational objective separates over units, each unit backtracks independently
# and the whole search is vectorised.
vgh_update_variational <- function(Y, X, Beta, Lambda, phi, amean, fam, rule,
                                   n_inner = 2L, Pvec = NULL, max_halving = 10L) {
  n <- nrow(Y); d <- ncol(Lambda); m <- nrow(Lambda)
  L2 <- if (d == 1L) matrix(Lambda[, 1]^2, ncol = 1L) else
    t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))
  XB <- X %*% Beta
  phimat <- rep(phi, each = n)
  Idvec <- matrix(as.vector(diag(d)), n, d * d, byrow = TRUE)

  if (is.null(Pvec)) Pvec <- Idvec        # start from the prior precision
  inv <- vgh_batch_inv(Pvec, d)
  Avec <- inv$Ainv; logdetA <- -inv$logdet

  for (it in seq_len(n_inner)) {
    M <- XB + amean %*% t(Lambda)
    S2 <- pmax(Avec %*% t(L2), 0)
    f0 <- vgh_unit_obj(Y, M, S2, amean, Avec, logdetA, phi, fam, rule, d)

    mom <- vgh_moments(fam, M, S2, rule)
    W <- mom$B2 / phimat

    # (C2) proposal: A_i^{-1} = I + Lambda' W_i Lambda -- ONE GEMM (W %*% L2)
    Pstar <- Idvec + W %*% L2
    invs <- vgh_batch_inv(Pstar, d)
    G <- ((Y - mom$B1) / phimat) %*% Lambda - amean
    stepdir <- vgh_batch_mv(invs$Ainv, G, d)

    # damped path, per-unit backtracking
    tvec <- rep(1, n)
    accepted <- rep(FALSE, n)
    aNew <- amean; AvecNew <- Avec; ldNew <- logdetA
    for (h in seq_len(max_halving)) {
      act <- !accepted
      if (!any(act)) break
      Pt <- (1 - tvec) * Pvec + tvec * Pstar
      it2 <- vgh_batch_inv(Pt, d)
      aT <- amean + tvec * stepdir
      Mt <- XB + aT %*% t(Lambda)
      S2t <- pmax(it2$Ainv %*% t(L2), 0)
      f1 <- vgh_unit_obj(Y, Mt, S2t, aT, it2$Ainv, -it2$logdet, phi, fam, rule, d)
      good <- act & is.finite(f1) & (f1 >= f0 - 1e-12)
      if (any(good)) {
        aNew[good, ] <- aT[good, , drop = FALSE]
        AvecNew[good, ] <- it2$Ainv[good, , drop = FALSE]
        ldNew[good] <- -it2$logdet[good]
        Pvec[good, ] <- Pt[good, , drop = FALSE]
        accepted[good] <- TRUE
      }
      tvec[!accepted] <- tvec[!accepted] / 2
    }
    amean <- aNew; Avec <- AvecNew; logdetA <- ldNew
  }

  M <- XB + amean %*% t(Lambda)
  S2 <- pmax(Avec %*% t(L2), 0)
  list(amean = amean, Avec = Avec, logdetA = logdetA, M = M, S2 = S2, Pvec = Pvec)
}


# --- M-step: m independent Fisher-scoring problems in (beta_j, lambda_j) -----
# The ELBO decouples completely across responses given the variational
# parameters.  The expected information in lambda_j is
#     sum_i B2_ij ( a_i a_i' + A_i ) / phi_j = sum_i B2_ij E_q[u_i u_i'] / phi_j
# which is the exact Fisher information under q -- so this is true Fisher
# scoring, not a heuristic.  Backtracking on the exact ELBO keeps it monotone.
vgh_update_model <- function(Y, X, Beta, Lambda, phi, amean, Avec, logdetA,
                             fam, rule, max_step_halving = 12L) {
  n <- nrow(Y); m <- ncol(Y); p <- ncol(X); d <- ncol(Lambda)
  L2 <- if (d == 1L) matrix(Lambda[, 1]^2, ncol = 1L) else
    t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))

  # R[i, ] = vec(a_i a_i' + A_i) = vec(E_q[u_i u_i'])
  R <- if (d == 1L) Avec + matrix(amean[, 1]^2, ncol = 1L) else
    Avec + t(apply(amean, 1L, function(a) as.vector(tcrossprod(a))))

  M  <- X %*% Beta + amean %*% t(Lambda)
  S2 <- Avec %*% t(L2)
  mom <- vgh_moments(fam, M, S2, rule)

  Z <- cbind(X, amean)                                   # n x (p+d)
  for (j in seq_len(m)) {
    b2j <- mom$B2[, j]
    resid <- Y[, j] - mom$B1[, j]

    # gradient: d/dbeta = sum_i x_i r_i ; d/dlambda = sum_i (r_i a_i - B2_ij A_i lambda_j)
    # A_i %*% lambda_j for every unit at once: an R-level loop over i here would
    # be n*m tiny matrix products per sweep and dominates everything else.
    Alam <- matrix(0, n, d)
    for (k in seq_len(d)) {
      idx <- (seq_len(d) - 1L) * d + k
      Alam[, k] <- Avec[, idx, drop = FALSE] %*% Lambda[j, ]
    }
    g <- c(crossprod(X, resid),
           crossprod(amean, resid) - crossprod(Alam, b2j)) / phi[j]

    # expected information
    Ipp <- crossprod(Z * sqrt(b2j))                      # (p+d) x (p+d)
    Ill <- matrix(colSums(R * b2j), d, d)                # sum_i B2 E_q[uu']
    Info <- Ipp
    Info[p + seq_len(d), p + seq_len(d)] <-
      Info[p + seq_len(d), p + seq_len(d)] - crossprod(amean * sqrt(b2j)) + Ill
    Info <- Info / phi[j]
    Info <- (Info + t(Info)) / 2 + diag(1e-8, p + d)

    delta <- tryCatch(solve(Info, g), error = function(e) rep(0, p + d))
    theta0 <- c(Beta[, j], Lambda[j, ])

    # backtracking on the exact per-response ELBO contribution
    f0 <- vgh_obj_j(Y[, j], X, amean, Avec, L2, theta0, phi[j], fam, rule, p, d, j)
    ok <- FALSE
    tstep <- 1
    for (h in seq_len(max_step_halving)) {
      theta1 <- theta0 + tstep * delta
      f1 <- vgh_obj_j(Y[, j], X, amean, Avec, L2, theta1, phi[j], fam, rule, p, d, j)
      if (is.finite(f1) && f1 >= f0) { ok <- TRUE; break }
      tstep <- tstep / 2
    }
    if (ok) {
      Beta[, j] <- theta1[seq_len(p)]
      Lambda[j, ] <- theta1[p + seq_len(d)]
    }
  }
  list(Beta = Beta, Lambda = Lambda)
}

# per-response objective, used only by the backtracking line search
vgh_obj_j <- function(yj, X, amean, Avec, L2, theta, phij, fam, rule, p, d, j) {
  bj <- theta[seq_len(p)]; lj <- theta[p + seq_len(d)]
  mj <- as.vector(X %*% bj + amean %*% lj)
  s2j <- as.vector(Avec %*% as.vector(tcrossprod(lj)))
  s2j <- pmax(s2j, 0)
  mom <- vgh_moments(fam, matrix(mj, ncol = 1), matrix(s2j, ncol = 1), rule)
  sum((yj * mj - mom$B) / phij)
}


# --- Dispersion (gaussian only, closed form) --------------------------------
# phi_j = mean_i [ (y_ij - m_ij)^2 + s2_ij ]; pool = TRUE shares one phi across
# all traits (Y/M/S2 are n x m rectangular, so mean(colMeans(X)) == mean(X)
# exactly -- the direct mean is used).  Floored so a well-fitting trait cannot
# drive phi to zero.
vgh_update_phi <- function(Y, M, S2, pool = FALSE, phi_floor = 1e-8) {
  resid2 <- (Y - M)^2 + S2
  phi <- if (pool) rep(mean(resid2), ncol(Y)) else colMeans(resid2)
  pmax(phi, phi_floor)
}


# --- Spectral warm start ----------------------------------------------------
# Eigendecomposition of the (link-scale) residual covariance.  For gaussian this
# is the exact moment estimator of Lambda; for other families it is a cheap and
# well-conditioned starting point that removes most of the outer iterations.
vgh_init <- function(Y, X, fam, d, pool = FALSE) {
  n <- nrow(Y); m <- ncol(Y); p <- ncol(X)
  Z <- switch(fam$name,
    gaussian = Y,
    poisson  = log(Y + 0.5),
    binomial = stats::qlogis((Y + 0.5) / 2))
  Beta <- qr.solve(X, Z)
  Rz <- Z - X %*% Beta
  Sc <- crossprod(Rz) / max(n - 1, 1)
  ev <- eigen((Sc + t(Sc)) / 2, symmetric = TRUE)
  lam <- pmax(ev$values[seq_len(d)], 1e-6)
  Lambda <- ev$vectors[, seq_len(d), drop = FALSE] %*% diag(sqrt(lam), d)
  Lambda <- Lambda * 0.5   # shrink: VA is better behaved starting inside
  phi0 <- if (fam$has_phi) pmax(diag(Sc) - rowSums(Lambda^2), 1e-3) else rep(1, m)
  if (pool) phi0 <- rep(mean(phi0), m)   # pool the STARTING phi too
  list(Beta = Beta, Lambda = Lambda,
       amean = matrix(0, n, d),
       phi = phi0)
}


# --- Driver -----------------------------------------------------------------
#' @param Y n x m response matrix
#' @param X n x p fixed-effect design (include the intercept column)
#' @param d latent dimension
#' @param family "gaussian", "poisson" or "binomial"
#' @param Q Gauss-Hermite nodes (ignored for families with an exact form)
#' @param maxit maximum coordinate-ascent sweeps
#' @param tol relative ELBO convergence tolerance
#' @param phi_pool pool gaussian dispersion to one shared value across traits
vgh_fit <- function(Y, X = matrix(1, nrow(Y), 1), d = 2L, family = "gaussian",
                    Q = 15L, maxit = 200L, tol = 1e-8, verbose = FALSE,
                    n_inner = 2L, trace_elbo = FALSE, phi_pool = FALSE) {
  fam <- vgh_family(family)
  rule <- vgh_gh_rule(Q)
  init <- vgh_init(Y, X, fam, d, pool = phi_pool)
  Beta <- init$Beta; Lambda <- init$Lambda; amean <- init$amean; phi <- init$phi

  elbo_path <- numeric(0)
  prev <- -Inf
  Pvec <- NULL
  t0 <- proc.time()[["elapsed"]]

  for (sweep in seq_len(maxit)) {
    v <- vgh_update_variational(Y, X, Beta, Lambda, phi, amean, fam, rule,
                                n_inner, Pvec = Pvec)
    amean <- v$amean; Pvec <- v$Pvec

    mstep <- vgh_update_model(Y, X, Beta, Lambda, phi, amean, v$Avec, v$logdetA,
                              fam, rule)
    Beta <- mstep$Beta; Lambda <- mstep$Lambda

    # refresh moments at the new (Beta, Lambda) before the phi update / ELBO
    L2 <- if (d == 1L) matrix(Lambda[, 1]^2, ncol = 1L) else
      t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))
    M <- X %*% Beta + amean %*% t(Lambda)
    S2 <- v$Avec %*% t(L2)
    if (fam$has_phi) phi <- vgh_update_phi(Y, M, S2, pool = phi_pool)

    e <- vgh_elbo(Y, fam, M, S2, amean, v$Avec, phi, rule, v$logdetA)
    elbo_path <- c(elbo_path, e$value)
    if (verbose) cat(sprintf("sweep %3d  ELBO %.8f\n", sweep, e$value))
    if (is.finite(prev) && abs(e$value - prev) < tol * (abs(prev) + 1)) break
    prev <- e$value
  }

  # `prev` is the PREVIOUS sweep's ELBO: the test above breaks BEFORE
  # `prev <- e$value` runs, so on a converged fit -- the normal path -- it is
  # stale by one sweep relative to the Beta/Lambda/phi/amean returned. (When
  # maxit is exhausted the trailing assignment happens to make them agree,
  # which is why this hid.) `e$value` is the ELBO at exactly the returned
  # tuple and is already computed, so reporting it costs nothing.  `e` is
  # undefined only when maxit < 1 and no sweep ever ran.  Back-ported from
  # R/va-vgh.R, which carries the same fix.
  elbo_out <- if (exists("e", inherits = FALSE)) e$value else prev

  structure(list(
    Beta = Beta, Lambda = Lambda, phi = phi,
    amean = amean, Avec = v$Avec,
    elbo = elbo_out, elbo_path = if (trace_elbo) elbo_path else NULL,
    sweeps = sweep, family = family, d = d, Q = Q, phi_pool = phi_pool,
    seconds = proc.time()[["elapsed"]] - t0
  ), class = "vgh_fit")
}
