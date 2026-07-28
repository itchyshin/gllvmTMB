## TEST C -- does the q = 1 AGHQ result transfer to q = 2?
##
## dev/aghq-scope-accuracy-crux.md measured, at q = 1, n = 2000, T = 20:
##   Laplace (k=1) attenuation 0.8968 -> AGHQ (k=15) 0.9507, c_full ~ 1.0295
## and named this the biggest blocker on the whole AGHQ-Laplace proposal:
##
##   "TEST C -- the q = 2 transfer check (the one that closes my biggest
##    blocker). Prediction: c_full in the 1.02-1.04 band, as at q = 1.
##    KILL RULE: if q = 2 c_full < 1.01, the headline does not transfer and
##    the proposal is dead regardless of TEST A/B."
##
## Ayumi's cell is q = 2, so a q = 1-only result cannot carry the claim.
##
## This is a SELF-CONTAINED estimator, not the package's: the point is to
## compare AGHQ against its own k = 1 special case, which IS exactly Laplace,
## on identical data. That identity is asserted below rather than assumed.
##
## Generalisation from the q = 1 probe:
##   u_i in R^q, Lambda is T x q (lower-triangular for identifiability)
##   Newton:  g_i = u_i - Lambda'(y_i - p_i)
##            H_i = I_q + Lambda' diag(p_i(1-p_i)) Lambda
##   AGHQ:    u = u_hat + sqrt(2) R^{-1} x,  R'R = H_i,  tensor grid k^q
##   log marginal_i = -log det(R_i) - (q/2) log(pi) + logsumexp_j(...) - h0_i

set.seed(1)
Q  <- 2L
TT <- 20L
NN <- as.integer(Sys.getenv("NN", "2000"))
KK <- as.integer(Sys.getenv("KK", "9"))
SEEDS <- as.integer(strsplit(Sys.getenv("SEEDS", "11,12,13,14,15"), ",")[[1]])
LAMBDA_SD <- 0.7 / sqrt(Q)   # keep Lambda'Lambda per axis matched to the q=1 run

## ---- Gauss-Hermite (physicists') via Golub-Welsch -------------------------
gh_rule <- function(k) {
  if (k == 1L) return(list(x = 0, w = sqrt(pi)))
  J <- matrix(0, k, k)
  off <- sqrt(seq_len(k - 1L) / 2)
  J[cbind(seq_len(k - 1L), 2:k)] <- off
  J[cbind(2:k, seq_len(k - 1L))] <- off
  e <- eigen(J, symmetric = TRUE)
  o <- order(e$values)
  list(x = e$values[o], w = sqrt(pi) * (e$vectors[1, o])^2)
}
## Tensor product grid over q dimensions.
gh_tensor <- function(k, q) {
  r <- gh_rule(k)
  idx <- as.matrix(expand.grid(rep(list(seq_along(r$x)), q)))
  list(X = matrix(r$x[idx], nrow = nrow(idx), ncol = q),
       lw = rowSums(matrix(log(r$w[idx]), nrow = nrow(idx), ncol = q)))
}

pack <- function(bet, Lam) c(bet, Lam[lower.tri(Lam, diag = TRUE)[, seq_len(Q)] &
                                     row(Lam) >= col(Lam)])
lam_index <- which(row(matrix(0, TT, Q)) >= col(matrix(0, TT, Q)))
unpack <- function(par) {
  bet <- par[seq_len(TT)]
  Lam <- matrix(0, TT, Q)
  Lam[lam_index] <- par[TT + seq_along(lam_index)]
  list(bet = bet, Lam = Lam)
}

simulate_cell <- function(seed) {
  set.seed(seed)
  Lam <- matrix(0, TT, Q)
  Lam[lam_index] <- rnorm(length(lam_index), sd = LAMBDA_SD)
  bet <- rnorm(TT, sd = 0.3)
  U <- matrix(rnorm(NN * Q), NN, Q)
  eta <- sweep(U %*% t(Lam), 2, bet, "+")
  Y <- matrix(rbinom(NN * TT, 1L, plogis(eta)), NN, TT)
  list(Y = Y, Lam = Lam, bet = bet)
}

## ---- AGHQ negative log-likelihood; k = 1 is EXACTLY Laplace ---------------
nll_aghq_q <- function(par, Y, grid, newton_it = 10L) {
  pu <- unpack(par); bet <- pu$bet; Lam <- pu$Lam
  n <- nrow(Y)
  U <- matrix(0, n, Q)
  for (it in seq_len(newton_it)) {
    eta <- sweep(U %*% t(Lam), 2, bet, "+")
    p <- plogis(eta)
    G <- U - (Y - p) %*% Lam                       # n x q
    W <- p * (1 - p)                               # n x T
    for (i in seq_len(n)) {
      H <- diag(Q) + crossprod(Lam, Lam * W[i, ])
      U[i, ] <- U[i, ] - solve(H, G[i, ])
    }
  }
  eta <- sweep(U %*% t(Lam), 2, bet, "+")
  p <- plogis(eta); W <- p * (1 - p)

  ## Across ALL units, one u each (Y is n x T, aligned row-wise).
  hfun_all <- function(Umat) {
    e <- sweep(Umat %*% t(Lam), 2, bet, "+")
    0.5 * rowSums(Umat^2) -
      rowSums(Y * e - log1p(exp(pmin(e, 30))) - pmax(e - 30, 0))
  }
  ## For ONE unit i across many nodes: y_i must broadcast down the rows.
  hfun_i <- function(Umat, i) {
    e <- sweep(Umat %*% t(Lam), 2, bet, "+")
    0.5 * rowSums(Umat^2) -
      rowSums(sweep(e, 2, Y[i, ], "*") - log1p(exp(pmin(e, 30))) -
                pmax(e - 30, 0))
  }
  h0 <- hfun_all(U)

  nnode <- nrow(grid$X)
  acc <- matrix(-Inf, n, nnode)
  logdetR <- numeric(n)
  for (i in seq_len(n)) {
    H <- diag(Q) + crossprod(Lam, Lam * W[i, ])
    R <- chol(H)                                   # H = R'R, R upper
    logdetR[i] <- sum(log(diag(R)))
    ## u = u_hat + sqrt(2) R^{-1} x
    shift <- sqrt(2) * t(backsolve(R, t(grid$X)))  # nnode x q
    Ui <- sweep(shift, 2, U[i, ], "+")
    acc[i, ] <- grid$lw + rowSums(grid$X^2) - (hfun_i(Ui, i) - h0[i])
  }
  m <- apply(acc, 1, max)
  ls <- m + log(rowSums(exp(acc - m)))
  ll <- -logdetR - (Q / 2) * log(pi) + ls - h0
  -sum(ll)
}

fit_arm <- function(Y, k, start, maxit = 300L) {
  grid <- gh_tensor(k, Q)
  optim(start, nll_aghq_q, Y = Y, grid = grid, method = "BFGS",
        control = list(maxit = maxit, reltol = 1e-10))
}

atten <- function(Lam_hat, Lam_true) {
  sum(diag(Lam_hat %*% t(Lam_hat))) / sum(diag(Lam_true %*% t(Lam_true)))
}

cat(sprintf("TEST C: q=%d  n=%d  T=%d  k=%d (%d tensor nodes)  seeds=%s\n\n",
            Q, NN, TT, KK, KK^Q, paste(SEEDS, collapse = ",")))

rows <- list()
OUT <- Sys.getenv("OUTCSV", "/private/tmp/gllvmtmb-va-wiring-20260726/dev/aghq-crux-q2-transfer.csv")
for (sd_i in SEEDS) {
  cell <- simulate_cell(sd_i)
  start <- c(rep(0, TT), rep(0.3, length(lam_index)))

  t0 <- proc.time()[["elapsed"]]
  fLA <- fit_arm(cell$Y, 1L, start)
  t_la <- proc.time()[["elapsed"]] - t0

  t0 <- proc.time()[["elapsed"]]
  fAG <- fit_arm(cell$Y, KK, fLA$par)      # warm start, as the cost model assumes
  t_ag <- proc.time()[["elapsed"]] - t0

  aLA <- atten(unpack(fLA$par)$Lam, cell$Lam)
  aAG <- atten(unpack(fAG$par)$Lam, cell$Lam)
  c_full <- sqrt(aAG / aLA)

  rows[[length(rows) + 1L]] <- data.frame(
    seed = sd_i, atten_LA = aLA, atten_AGHQ = aAG, c_full = c_full,
    obj_LA = fLA$value, obj_AGHQ = fAG$value,
    t_la = round(t_la, 1), t_ag = round(t_ag, 1),
    cost_ratio = round(t_ag / t_la, 2)
  )
  utils::write.csv(do.call(rbind, rows), OUT, row.names = FALSE)
  cat(sprintf("seed %d  atten LA=%.4f  AGHQ=%.4f  c_full=%.4f  cost=%.2fx\n",
              sd_i, aLA, aAG, c_full, t_ag / t_la)); flush(stdout())
}

d <- do.call(rbind, rows)
cat("\n================= TEST C VERDICT =================\n")
cat(sprintf("mean atten LA   : %.4f\n", mean(d$atten_LA)))
cat(sprintf("mean atten AGHQ : %.4f\n", mean(d$atten_AGHQ)))
cat(sprintf("mean c_full     : %.4f   (q=1 reference: 1.0295)\n", mean(d$c_full)))
cat(sprintf("median cost     : %.2fx  (q=1 reference: 1.67x)\n", median(d$cost_ratio)))
cat(sprintf("seeds with c_full > 1 : %d/%d\n", sum(d$c_full > 1), nrow(d)))
cat("\nKILL RULE: c_full < 1.01 at q=2 => the headline does NOT transfer.\n")
cat(sprintf("VERDICT: %s\n",
            if (mean(d$c_full) < 1.01) "DEAD -- does not transfer" else
            if (mean(d$c_full) <= 1.04) "TRANSFERS -- inside the predicted 1.02-1.04 band" else
            "TRANSFERS, and stronger than predicted"))
