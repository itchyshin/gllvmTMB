## Research-only block coordinate-ascent variational engine (VGH).
##
## This file deliberately contains no roxygen export tags and creates no
## gllvmTMB class.  The objective is a quadrature-evaluated ELBO -- the SAME
## objective as R/va-r3-proto.R, verified against the compiled TMB template to
## 4.7e-15 across 46 comparisons -- not a marginal likelihood.  It is kept
## separate from fit_multi() and the shipped gllvmTMB TMB template so that it
## cannot become an accidental user-facing fitting route.
##
## What differs from .va_r3_* is ONLY how the objective is maximised.  va_r3
## hands all N*(2q + q(q-1)/2) variational coordinates to a general-purpose
## optimiser in one flat vector; this engine solves each block instead:
##
##   * the variational covariance has a closed-form stationary point,
##         S_i^{-1} = I_q + Lambda' W_i Lambda,   W_i = diag(E_q[b''] / phi),
##     which follows from dB/ds = s * E[b''(m + sZ)] (Stein/Price); and
##   * the ELBO Hessian in the variational mean is exactly -S_i^{-1}, so the
##     Newton step costs nothing beyond S_i, which is already in hand; and
##   * given the variational block the ELBO separates across responses, so the
##     model step is T independent (p + q)-dimensional Fisher-scoring problems.
##
## No optimiser therefore ever sees more than (p + q) coordinates at once.
##
## The mathematics is NOT new.  The one-dimensional collapse and the closed-form
## covariance are Ormerod & Wand (2012, JCGS) Appendix A.3; see also Opper &
## Archambeau (2009) and Hui et al. (2017) Step 3 for the probit special case.
## Only the optimisation architecture is this package's.
##
## Conventions inherited from .va_r3_*: long-format data contract, bare
## stop(..., call. = FALSE) guards, dot-prefixed internal names, no cli.


## --- Quadrature ------------------------------------------------------------
## PROBABILISTS' convention: nodes/weights approximate E[f(Z)], Z ~ N(0, 1), so
## sum(weights) == 1.  This differs from .va_r3_gh_rule(), which is PHYSICISTS'
## (sum(weights) == sqrt(pi)) and admits only H in {15, 25, 61}.  The two rules
## are the same rule -- z = sqrt(2) * x, w / sqrt(pi) -- and were verified
## node-for-node by agreeing on the *discretisation error itself* at H = 15,
## where neither is converged (3.4e-12).  This engine admits any Q >= 1 because
## Q = 9 was measured sufficient for recovery, which the {15, 25, 61}
## restriction would forbid.
.vgh_gh_rule <- function(Q) {
  if (length(Q) != 1L || !is.numeric(Q) || !is.finite(Q) ||
      Q != as.integer(Q) || Q < 1L || Q > 201L) {
    stop("Q must be one integer in 1..201.", call. = FALSE)
  }
  Q <- as.integer(Q)
  if (Q == 1L) return(list(z = 0, w = 1, order = 1L))
  k <- seq_len(Q - 1L)
  J <- diag(0, Q)
  off <- sqrt(k / 2)
  J[cbind(k, k + 1L)] <- off
  J[cbind(k + 1L, k)] <- off
  e <- eigen(J, symmetric = TRUE)
  ord <- order(e$values)
  w <- (e$vectors[1L, ord])^2
  list(z = sqrt(2) * e$values[ord], w = w / sum(w), order = Q)
}


## --- Families --------------------------------------------------------------
## Each entry supplies the cumulant b() and, where a closed form for the
## Gaussian expectation exists, analytic B / B1 / B2.  `exact = TRUE` bypasses
## the quadrature entirely -- there is then no approximation error at all.
## Family codes match .va_r3_validate_data(): 0 gaussian_anchor, 1 binomial,
## 2 poisson.  nbinom2 (code 3) is deliberately NOT admitted here yet.
.vgh_family <- function(family_name) {
  switch(family_name,
    gaussian_anchor = list(
      name = "gaussian_anchor", link = "identity", exact = TRUE,
      ## b(eta) = eta^2 / 2  =>  E[b] = (m^2 + s^2) / 2, exactly
      moments = function(m, s2) list(B = (m^2 + s2) / 2, B1 = m,
                                     B2 = array(1, dim(m)))
    ),
    poisson = list(
      name = "poisson", link = "log", exact = TRUE,
      ## b(eta) = exp(eta)  =>  E[b] = exp(m + s^2/2), the log-normal mean
      moments = function(m, s2) {
        B <- exp(pmin(m + s2 / 2, 700))
        list(B = B, B1 = B, B2 = B)
      }
    ),
    binomial = list(
      name = "binomial", link = "logit", exact = FALSE,
      b  = function(eta) ifelse(eta > 30, eta, log1p(exp(pmin(eta, 30)))),
      b1 = function(eta) stats::plogis(eta),
      b2 = function(eta) { p <- stats::plogis(eta); p * (1 - p) }
    ),
    stop("VGH admits only the gaussian_anchor, binomial and poisson families.",
         call. = FALSE)
  )
}

## E[b(eta)], E[b'(eta)], E[b''(eta)] elementwise over the N x T matrices of
## variational means and variances.  The ONLY place the family enters.
.vgh_moments <- function(fam, m, s2, rule) {
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


## --- Batched linear algebra over units --------------------------------------
## Inverting N small matrices in an R loop would dominate the runtime and
## defeat the architecture, so q <= 3 gets closed-form cofactor inverses
## evaluated across all units at once.  Input is N x q^2 holding vec(P_i).
## There is no house equivalent for this; it is written fresh.
.vgh_batch_inv <- function(P, q) {
  n <- nrow(P)
  if (q == 1L) {
    dt <- P[, 1]
    return(list(Ainv = matrix(1 / dt, ncol = 1L), logdet = log(dt)))
  }
  if (q == 2L) {
    p11 <- P[, 1]; p21 <- P[, 2]; p12 <- P[, 3]; p22 <- P[, 4]
    dt <- p11 * p22 - p12 * p21
    return(list(Ainv = cbind(p22, -p21, -p12, p11) / dt, logdet = log(dt)))
  }
  if (q == 3L) {
    p11 <- P[, 1]; p21 <- P[, 2]; p31 <- P[, 3]
    p12 <- P[, 4]; p22 <- P[, 5]; p32 <- P[, 6]
    p13 <- P[, 7]; p23 <- P[, 8]; p33 <- P[, 9]
    c11 <- p22 * p33 - p23 * p32; c12 <- p13 * p32 - p12 * p33
    c13 <- p12 * p23 - p13 * p22; c21 <- p23 * p31 - p21 * p33
    c22 <- p11 * p33 - p13 * p31; c23 <- p13 * p21 - p11 * p23
    c31 <- p21 * p32 - p22 * p31; c32 <- p12 * p31 - p11 * p32
    c33 <- p11 * p22 - p12 * p21
    dt <- p11 * c11 + p12 * c21 + p13 * c31
    return(list(Ainv = cbind(c11, c21, c31, c12, c22, c32, c13, c23, c33) / dt,
                logdet = log(dt)))
  }
  Ainv <- matrix(0, n, q * q); ld <- numeric(n)
  for (i in seq_len(n)) {
    ch <- chol(matrix(P[i, ], q, q))
    Ainv[i, ] <- as.vector(chol2inv(ch))
    ld[i] <- 2 * sum(log(diag(ch)))
  }
  list(Ainv = Ainv, logdet = ld)
}

## Row i of (S_i %*% v_i), with S_i stored as vec.
.vgh_batch_mv <- function(Svec, V, q) {
  out <- matrix(0, nrow(V), q)
  for (k in seq_len(q)) {
    idx <- (seq_len(q) - 1L) * q + k
    out[, k] <- rowSums(Svec[, idx, drop = FALSE] * V)
  }
  out
}

## vec(lambda_t lambda_t') for every trait -- T x q^2.
.vgh_loading_outer <- function(Lambda, q) {
  if (q == 1L) return(matrix(Lambda[, 1]^2, ncol = 1L))
  t(apply(Lambda, 1L, function(l) as.vector(tcrossprod(l))))
}


## --- ELBO -------------------------------------------------------------------
## ELBO = sum_it [ (y n^{-1} weighted data term) ] + sum_i KL-negative.
## The data term is written for the exponential-family form
##   log p = (y*eta - n_trials*b(eta)) / phi + c(y, phi),
## so n_trials multiplies the cumulant and phi is the trait dispersion.  The
## constant c(y, phi) is dropped: it does not depend on any parameter this
## engine estimates, so it shifts the ELBO but never the optimum.  It is
## therefore NOT comparable to a log-likelihood, by construction.
.vgh_elbo_parts <- function(Y, NT, M, S2, amean, Svec, logdetS, phi, fam, rule, q) {
  n <- nrow(Y)
  mom <- .vgh_moments(fam, M, S2, rule)
  phimat <- rep(phi, each = n)
  didx <- (seq_len(q) - 1L) * q + seq_len(q)
  trS <- rowSums(Svec[, didx, drop = FALSE])
  data_term <- rowSums((Y * M - NT * mom$B) / phimat)
  kl_term <- 0.5 * (logdetS - trS - rowSums(amean^2) + q)
  list(unit = data_term + kl_term, total = sum(data_term) + sum(kl_term),
       mom = mom)
}


## --- Variational block: closed-form S_i, damped Newton in the mean ----------
## The S_i stationarity is a fixed point (W_i depends on S_i through s2), and
## the Newton step in the mean is UNDAMPED Newton -- for a log link that
## overshoots through exp() and can DECREASE the ELBO.  So the proposal is
## damped along a path that keeps the precision positive definite,
##   P(t) = (1-t) P + t P*,   a(t) = a + t S* g,
## and because the variational objective SEPARATES over units, each unit
## backtracks independently and the whole search stays vectorised.
.vgh_update_variational <- function(Y, NT, XB, Lambda, phi, amean, fam, rule,
                                    q, Pvec, n_inner = 2L, max_halving = 10L) {
  n <- nrow(Y)
  L2 <- .vgh_loading_outer(Lambda, q)
  phimat <- rep(phi, each = n)
  Idvec <- matrix(as.vector(diag(q)), n, q * q, byrow = TRUE)
  if (is.null(Pvec)) Pvec <- Idvec

  inv <- .vgh_batch_inv(Pvec, q)
  Svec <- inv$Ainv; logdetS <- -inv$logdet

  for (it in seq_len(n_inner)) {
    M <- XB + amean %*% t(Lambda)
    S2 <- pmax(Svec %*% t(L2), 0)
    f0 <- .vgh_elbo_parts(Y, NT, M, S2, amean, Svec, logdetS, phi, fam, rule, q)
    mom <- f0$mom
    W <- (NT * mom$B2) / phimat

    ## closed-form proposal: S_i^{-1} = I + Lambda' W_i Lambda -- ONE GEMM
    Pstar <- Idvec + W %*% L2
    invs <- .vgh_batch_inv(Pstar, q)
    G <- (((Y - NT * mom$B1)) / phimat) %*% Lambda - amean
    stepdir <- .vgh_batch_mv(invs$Ainv, G, q)

    tvec <- rep(1, n)
    accepted <- rep(FALSE, n)
    aNew <- amean; SNew <- Svec; ldNew <- logdetS; PNew <- Pvec
    for (h in seq_len(max_halving)) {
      if (all(accepted)) break
      Pt <- (1 - tvec) * Pvec + tvec * Pstar
      it2 <- .vgh_batch_inv(Pt, q)
      aT <- amean + tvec * stepdir
      Mt <- XB + aT %*% t(Lambda)
      S2t <- pmax(it2$Ainv %*% t(L2), 0)
      f1 <- .vgh_elbo_parts(Y, NT, Mt, S2t, aT, it2$Ainv, -it2$logdet,
                            phi, fam, rule, q)$unit
      good <- !accepted & is.finite(f1) & (f1 >= f0$unit - 1e-12)
      if (any(good)) {
        aNew[good, ] <- aT[good, , drop = FALSE]
        SNew[good, ] <- it2$Ainv[good, , drop = FALSE]
        ldNew[good] <- -it2$logdet[good]
        PNew[good, ] <- Pt[good, , drop = FALSE]
        accepted[good] <- TRUE
      }
      tvec[!accepted] <- tvec[!accepted] / 2
    }
    amean <- aNew; Svec <- SNew; logdetS <- ldNew; Pvec <- PNew
  }

  list(amean = amean, Svec = Svec, logdetS = logdetS, Pvec = Pvec)
}


## --- Model block: T independent Fisher-scoring problems ---------------------
## Given the variational block the ELBO separates across responses.  The
## expected information in lambda_t is sum_i W_it (a_i a_i' + S_i) =
## sum_i W_it E_q[u_i u_i'], the exact Fisher information under q -- so this is
## true Fisher scoring, not a heuristic.  Backtracking on the exact per-response
## ELBO contribution keeps it monotone.
.vgh_update_model <- function(Y, NT, X, Beta, Lambda, phi, amean, Svec,
                              fam, rule, q, max_halving = 12L) {
  n <- nrow(Y); Tt <- ncol(Y); p <- ncol(X)
  L2 <- .vgh_loading_outer(Lambda, q)
  R <- Svec + if (q == 1L) matrix(amean[, 1]^2, ncol = 1L) else
    t(apply(amean, 1L, function(a) as.vector(tcrossprod(a))))

  M <- X %*% Beta + amean %*% t(Lambda)
  S2 <- pmax(Svec %*% t(L2), 0)
  mom <- .vgh_moments(fam, M, S2, rule)
  Z <- cbind(X, amean)

  for (j in seq_len(Tt)) {
    w <- NT[, j] * mom$B2[, j]
    resid <- Y[, j] - NT[, j] * mom$B1[, j]
    Slam <- matrix(0, n, q)
    for (k in seq_len(q)) {
      idx <- (seq_len(q) - 1L) * q + k
      Slam[, k] <- Svec[, idx, drop = FALSE] %*% Lambda[j, ]
    }
    g <- c(crossprod(X, resid),
           crossprod(amean, resid) - crossprod(Slam, w)) / phi[j]

    Info <- crossprod(Z * sqrt(pmax(w, 0)))
    Ill <- matrix(colSums(R * w), q, q)
    ii <- p + seq_len(q)
    Info[ii, ii] <- Info[ii, ii] - crossprod(amean * sqrt(pmax(w, 0))) + Ill
    Info <- (Info + t(Info)) / 2 / phi[j] + diag(1e-8, p + q)

    delta <- tryCatch(solve(Info, g), error = function(e) rep(0, p + q))
    theta0 <- c(Beta[, j], Lambda[j, ])
    f0 <- .vgh_obj_j(Y[, j], NT[, j], X, amean, Svec, theta0, phi[j], fam,
                     rule, p, q)
    tstep <- 1
    for (h in seq_len(max_halving)) {
      theta1 <- theta0 + tstep * delta
      f1 <- .vgh_obj_j(Y[, j], NT[, j], X, amean, Svec, theta1, phi[j], fam,
                       rule, p, q)
      if (is.finite(f1) && f1 >= f0) {
        Beta[, j] <- theta1[seq_len(p)]
        Lambda[j, ] <- theta1[p + seq_len(q)]
        break
      }
      tstep <- tstep / 2
    }
  }
  list(Beta = Beta, Lambda = Lambda)
}

## Per-response ELBO contribution; used only by the backtracking line search.
.vgh_obj_j <- function(yj, ntj, X, amean, Svec, theta, phij, fam, rule, p, q) {
  bj <- theta[seq_len(p)]; lj <- theta[p + seq_len(q)]
  mj <- as.vector(X %*% bj + amean %*% lj)
  s2j <- pmax(as.vector(Svec %*% as.vector(tcrossprod(lj))), 0)
  mom <- .vgh_moments(fam, matrix(mj, ncol = 1), matrix(s2j, ncol = 1), rule)
  sum((yj * mj - ntj * mom$B) / phij)
}


## --- SQUAREM acceleration ---------------------------------------------------
## Block coordinate ascent zigzags in the tail because S_i depends on
## Lambda' W_i Lambda and Lambda depends on S_i.  Measured cost of that zigzag:
## 34 of 36 Poisson fits hit a 200-sweep cap, and converging properly took
## 432-5000+ sweeps.  SQUAREM (Varadhan & Roland 2008) extrapolates along the
## fixed-point map using two ordinary steps:
##   r = F(x) - x,  v = F(F(x)) - F(x) - r,  alpha = -||r|| / ||v||,
##   x' = x - 2 alpha r + alpha^2 v
## and is made unconditionally safe here by evaluating the ELBO at the
## extrapolated point and halving alpha back toward -1 on any decrease, falling
## back to the plain double step.  The ELBO is cheap and monotone, so the guard
## costs one evaluation and can never make things worse.
##
## Acceleration is applied to the MODEL parameters only; the variational block
## is re-solved at whatever point is accepted, so the extrapolation never
## produces an inconsistent (theta, q) pair.
.vgh_squarem_alpha <- function(r, v) {
  nv <- sqrt(sum(v * v))
  if (!is.finite(nv) || nv < 1e-300) return(-1)
  a <- -sqrt(sum(r * r)) / nv
  if (!is.finite(a)) return(-1)
  min(a, -1)
}


## --- Data contract ----------------------------------------------------------
## Mirrors .va_r3_validate_data()'s long-format contract.  Following the EVA
## precedent (R/eva-proto.R), the validator's SHAPE is duplicated rather than
## reusing R3's wholesale -- each engine's admitted surface differs -- while the
## small shared primitive .va_r3_normalise_index() is called directly.
.vgh_validate_data <- function(y, n_trials, X, unit_id, trait_id, q,
                               N = NULL, T = NULL,
                               family = "binomial", link = "logit",
                               unique = FALSE, psi = FALSE,
                               structured = FALSE, provider = NULL,
                               lv = FALSE, missing = FALSE,
                               gaussian_sd = 1) {
  if (length(q) != 1L || !is.numeric(q) || !is.finite(q) ||
      q != as.integer(q) || q < 1L || q > 6L) {
    stop("q must be one integer in 1..6.", call. = FALSE)
  }
  q <- as.integer(q)
  if (!is.matrix(X) || !is.numeric(X) || nrow(X) != length(y) ||
      ncol(X) < 1L || any(!is.finite(X))) {
    stop("X must be a finite numeric matrix with one row per response and at least one column.",
         call. = FALSE)
  }
  if (qr(X)$rank != ncol(X)) {
    stop("X must have full column rank.", call. = FALSE)
  }
  if (length(unit_id) != length(y) || length(trait_id) != length(y) ||
      length(n_trials) != length(y)) {
    stop("y, n_trials, unit_id, trait_id, and the rows of X must have equal length.",
         call. = FALSE)
  }
  if (is.null(N)) N <- length(unique(unit_id))
  if (is.null(T)) T <- length(unique(trait_id))
  N <- as.integer(N); T <- as.integer(T)
  if (!is.finite(N) || !is.finite(T) || N < 1L || T < 1L) {
    stop("N and T must be positive integers.", call. = FALSE)
  }
  if (q > T) stop("q must not exceed T.", call. = FALSE)

  ## One combined admission guard, matching .va_r3_validate_data():196-201.
  if (!identical(unique, FALSE) || !identical(psi, FALSE) ||
      !identical(structured, FALSE) || !is.null(provider) ||
      !identical(lv, FALSE) || !identical(missing, FALSE)) {
    stop("VGH admits only ordinary latent(..., unique = FALSE) data with no Psi, structured/provider, lv, or missing-data marker.",
         call. = FALSE)
  }

  unit_id <- .va_r3_normalise_index(unit_id, N, "unit_id")
  trait_id <- .va_r3_normalise_index(trait_id, T, "trait_id")
  cell <- unit_id * T + trait_id
  if (length(y) != N * T || length(unique(cell)) != N * T ||
      !identical(sort(cell), 0:(N * T - 1L))) {
    stop("VGH requires exactly one complete observation for every unit-trait cell.",
         call. = FALSE)
  }

  fam_code <- switch(family, gaussian_anchor = 0L, binomial = 1L, poisson = 2L,
                     stop("VGH admits only the gaussian_anchor, binomial and poisson families.",
                          call. = FALSE))
  wanted <- switch(family, gaussian_anchor = "identity", binomial = "logit",
                   poisson = "log")
  if (!identical(link, wanted)) {
    stop("VGH admits only the ", family, " ", wanted, " link.", call. = FALSE)
  }

  if (!is.numeric(y) || any(!is.finite(y))) {
    stop("y must be finite and numeric.", call. = FALSE)
  }
  if (identical(family, "binomial")) {
    n_trials <- as.integer(n_trials)
    if (any(!is.finite(n_trials)) || any(n_trials < 1L) ||
        any(y < 0) || any(y > n_trials) || any(y != as.integer(y))) {
      stop("binomial y must be integer counts in 0..n_trials with n_trials >= 1.",
           call. = FALSE)
    }
  } else {
    n_trials <- rep.int(1L, length(y))
  }
  if (identical(family, "poisson") &&
      (any(y < 0) || any(y != as.integer(y)))) {
    stop("poisson y must be non-negative integer counts.", call. = FALSE)
  }
  if (identical(family, "gaussian_anchor") &&
      (length(gaussian_sd) != 1L || !is.finite(gaussian_sd) ||
       gaussian_sd <= 0)) {
    stop("gaussian_sd must be one positive finite scalar.", call. = FALSE)
  }

  list(y = y, n_trials = n_trials, X = unname(X), unit_id = unit_id,
       trait_id = trait_id, N = N, T = T, q = q, family = fam_code,
       family_name = family, link = link, gaussian_sd = gaussian_sd)
}

## Long (one row per unit-trait cell) -> the wide N x T matrices the engine
## works in.  X is assumed constant within a unit, which the complete-grid
## requirement above makes checkable; the first row of each unit is taken and
## the assumption is verified rather than trusted.
.vgh_long_to_wide <- function(v) {
  N <- v$N; T <- v$T
  ## R matrices are COLUMN-major: element (i, j) of an N x T matrix sits at
  ## linear index (j - 1) * N + i.  unit_id and trait_id are 0-based here, so
  ## the correct linear index is trait_id * N + unit_id + 1.  Using the
  ## row-major form (unit_id * T + trait_id + 1) silently TRANSPOSES the data
  ## across units and traits whenever N != T, and scrambles it even when
  ## N == T -- it does not error, it just fits the wrong dataset.
  idx <- v$trait_id * N + v$unit_id + 1L
  Y <- matrix(NA_real_, N, T); Y[idx] <- v$y
  NT <- matrix(NA_real_, N, T); NT[idx] <- v$n_trials
  if (anyNA(Y) || anyNA(NT)) {
    stop("VGH internal: the unit-trait grid is incomplete after reshaping.",
         call. = FALSE)
  }
  first <- match(seq_len(N) - 1L, v$unit_id)
  Xw <- v$X[first, , drop = FALSE]
  ord <- order(v$unit_id)
  chk <- v$X[ord, , drop = FALSE]
  expand <- Xw[rep(seq_len(N), each = T), , drop = FALSE]
  if (max(abs(chk - expand)) > 1e-10) {
    stop("VGH requires X to be constant within a unit; per-trait covariates are not admitted.",
         call. = FALSE)
  }
  list(Y = Y, NT = NT, X = Xw)
}


## --- Warm start -------------------------------------------------------------
## Eigendecomposition of the link-scale residual covariance, mirroring
## .va_r3_warm_theta_rr()'s factor-analytic start and gllvm's
## starting.val = "res".
.vgh_init <- function(Y, NT, X, fam, q, gaussian_sd) {
  n <- nrow(Y); Tt <- ncol(Y)
  Z <- switch(fam$name,
    gaussian_anchor = Y,
    poisson = log(Y + 0.5),
    binomial = stats::qlogis((Y + 0.5) / (NT + 1)))
  Beta <- qr.solve(X, Z)
  Rz <- Z - X %*% Beta
  Sc <- crossprod(Rz) / max(n - 1, 1)
  ev <- eigen((Sc + t(Sc)) / 2, symmetric = TRUE)
  lam <- pmax(ev$values[seq_len(q)], 1e-6)
  Lambda <- ev$vectors[, seq_len(q), drop = FALSE] %*% diag(sqrt(lam), q)
  Lambda <- Lambda * 0.5
  phi <- if (identical(fam$name, "gaussian_anchor")) {
    rep(gaussian_sd^2, Tt)
  } else {
    rep(1, Tt)
  }
  list(Beta = Beta, Lambda = Lambda, amean = matrix(0, n, q), phi = phi)
}


## --- Driver -----------------------------------------------------------------
## Convergence is judged on the ELBO increment PER OBSERVATION.  A criterion
## relative to |ELBO| loosens as N grows -- exactly backwards -- and that is
## what capped 34 of 36 Poisson fits in the 2026-07-29 matched grid.
.vgh_fit <- function(y, n_trials, X, unit_id, trait_id, q,
                     N = NULL, T = NULL,
                     family = "binomial", link = "logit",
                     unique = FALSE, psi = FALSE, structured = FALSE,
                     provider = NULL, lv = FALSE, missing = FALSE,
                     gaussian_sd = 1,
                     Q = 15L, maxit = 2000L, tol = 1e-10,
                     n_inner = 2L, accelerate = TRUE, trace = FALSE) {
  v <- .vgh_validate_data(y, n_trials, X, unit_id, trait_id, q, N, T,
                          family, link, unique, psi, structured, provider,
                          lv, missing, gaussian_sd)
  w <- .vgh_long_to_wide(v)
  fam <- .vgh_family(v$family_name)
  rule <- .vgh_gh_rule(Q)
  Y <- w$Y; NT <- w$NT; Xw <- w$X
  n <- nrow(Y); Tt <- ncol(Y); p <- ncol(Xw)
  n_obs <- n * Tt

  init <- .vgh_init(Y, NT, Xw, fam, v$q, v$gaussian_sd)
  Beta <- init$Beta; Lambda <- init$Lambda
  amean <- init$amean; phi <- init$phi
  Pvec <- NULL

  ## One full sweep: variational block, then the T-separable model block.
  ## Returns the new model parameters and carries the variational state.
  state <- list(amean = amean, Pvec = Pvec)
  sweep_once <- function(Beta, Lambda) {
    XB <- Xw %*% Beta
    vb <- .vgh_update_variational(Y, NT, XB, Lambda, phi, state$amean, fam,
                                  rule, v$q, state$Pvec, n_inner)
    state$amean <<- vb$amean; state$Pvec <<- vb$Pvec
    ms <- .vgh_update_model(Y, NT, Xw, Beta, Lambda, phi, vb$amean, vb$Svec,
                            fam, rule, v$q)
    list(Beta = ms$Beta, Lambda = ms$Lambda, Svec = vb$Svec,
         logdetS = vb$logdetS)
  }
  elbo_at <- function(Beta, Lambda, Svec, logdetS) {
    M <- Xw %*% Beta + state$amean %*% t(Lambda)
    S2 <- pmax(Svec %*% t(.vgh_loading_outer(Lambda, v$q)), 0)
    .vgh_elbo_parts(Y, NT, M, S2, state$amean, Svec, logdetS, phi, fam,
                    rule, v$q)$total
  }
  pack <- function(B, L) c(as.vector(B), as.vector(L))
  unpack <- function(th) list(Beta = matrix(th[seq_len(p * Tt)], p, Tt),
                              Lambda = matrix(th[p * Tt + seq_len(Tt * v$q)],
                                              Tt, v$q))

  prev <- -Inf; path <- numeric(0); sweeps <- 0L; accel_used <- 0L
  t0 <- proc.time()[["elapsed"]]

  for (outer in seq_len(maxit)) {
    th0 <- pack(Beta, Lambda)
    s1 <- sweep_once(Beta, Lambda); sweeps <- sweeps + 1L
    th1 <- pack(s1$Beta, s1$Lambda)
    cur <- s1

    if (isTRUE(accelerate)) {
      s2 <- sweep_once(s1$Beta, s1$Lambda); sweeps <- sweeps + 1L
      th2 <- pack(s2$Beta, s2$Lambda)
      e2 <- elbo_at(s2$Beta, s2$Lambda, s2$Svec, s2$logdetS)
      cur <- s2
      r <- th1 - th0; vv <- th2 - th1 - r
      alpha <- .vgh_squarem_alpha(r, vv)
      if (alpha < -1) {
        for (h in seq_len(8L)) {
          thp <- th0 - 2 * alpha * r + alpha^2 * vv
          if (all(is.finite(thp))) {
            up <- unpack(thp)
            sp <- sweep_once(up$Beta, up$Lambda); sweeps <- sweeps + 1L
            ep <- elbo_at(sp$Beta, sp$Lambda, sp$Svec, sp$logdetS)
            if (is.finite(ep) && ep >= e2) {
              cur <- sp; accel_used <- accel_used + 1L
              break
            }
          }
          alpha <- (alpha - 1) / 2
          if (alpha >= -1.0000001) break
        }
      }
    }

    Beta <- cur$Beta; Lambda <- cur$Lambda
    if (identical(fam$name, "gaussian_anchor")) {
      ## dispersion is FIXED at gaussian_sd^2 by the contract, as in va_r3
      phi <- rep(v$gaussian_sd^2, Tt)
    }
    e <- elbo_at(Beta, Lambda, cur$Svec, cur$logdetS)
    path <- c(path, e)
    if (isTRUE(trace)) {
      cat(sprintf("outer %4d  sweeps %5d  ELBO %.10f\n", outer, sweeps, e))
    }
    ## PER-OBSERVATION increment: scale-free in N and T.
    if (is.finite(prev) && (e - prev) / n_obs < tol && e >= prev) break
    prev <- e
  }

  structure(list(
    Beta = Beta, Lambda = Lambda, phi = phi,
    amean = state$amean, Svec = cur$Svec,
    elbo = prev, elbo_path = path,
    outer = outer, sweeps = sweeps, accelerations = accel_used,
    converged = (outer < maxit),
    family = v$family_name, link = v$link, q = v$q, Q = rule$order,
    N = n, T = Tt,
    objective_type = "ELBO_GH",
    research_only = TRUE,
    model_selection_comparable = FALSE,
    seconds = proc.time()[["elapsed"]] - t0
  ), class = "vgh_fit")
}
